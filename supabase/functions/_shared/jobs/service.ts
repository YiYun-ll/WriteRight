import { gradeTranslation, validateTranslationReport } from "../grading/translation.ts";
import { makeContext } from "../grading/context.ts";
import { GradingFailed, runGrading } from "../grading/run.ts";
import type { GradingContext, GradingReport, ModelAdapter } from "../grading/types.ts";
import { validateReport } from "../grading/validation.ts";
import type { JobStore } from "./store.ts";
import { gradePhotos } from "../grading/photo-grading.ts";
import type { PhotoContext, PhotoGradingReport } from "../grading/photo-types.ts";

export interface SubmitGradingInput {
  idemKey: string;
  task: {
    id: string;
    part: "A" | "B" | "T";
    title?: string;
    prompt: string;
    referenceTranslation?: string;
    requirements: { id: string; text: string }[];
    revision: number;
    confirmed: boolean;
    chartFacts?: GradingContext["task"]["chartFacts"];
  };
  submission: { id: string; originalText: string };
}

export async function submitGrading(
  store: JobStore,
  userID: string,
  input: SubmitGradingInput,
  modelID: string,
): Promise<Record<string, unknown>> {
  validateInput(input);
  const context = await makeContext({
    part: input.task.part,
    originalText: input.submission.originalText,
    task: {
      prompt: input.task.prompt,
      ...(input.task.referenceTranslation !== undefined
        ? { referenceTranslation: input.task.referenceTranslation }
        : {}),
      requirements: input.task.requirements,
      revision: input.task.revision,
      confirmed: input.task.confirmed,
      chartFacts: input.task.chartFacts ?? [],
    },
  }, modelID);
  const job = await store.enqueue(userID, input, context);
  return await statusForJob(store, userID, job.id);
}

export async function statusForJob(
  store: JobStore,
  userID: string,
  jobID: string,
): Promise<Record<string, unknown>> {
  const job = await store.job(jobID);
  if (!job || job.user_id !== userID) throw new Error("JOB_NOT_FOUND");
  const report = job.status === "completed" ? await store.report(job.id) : null;
  return {
    jobId: job.id,
    status: job.status,
    stage: job.stage,
    report,
    errorCode: job.error_code,
  };
}

export async function processNextJob(store: JobStore, adapter: ModelAdapter): Promise<string> {
  const claimed = await store.claim();
  if (!claimed) return "empty";
  let job = claimed;
  try {
    const submission = await store.submission(job.submission_id);
    if (job.context_json.source === "photo_grading_v2") {
      const context = job.context_json as unknown as PhotoContext;
      if (
        !submission || submission.user_id !== job.user_id ||
        submission.content_hash !== context.contentHash || submission.original_text !== "" ||
        !context.images?.length
      ) throw new Error("JOB_SNAPSHOT_MISMATCH");
      if (!job.stage_results.evaluate) {
        const images = [];
        for (const source of context.images) {
          images.push(await store.photo(source.path, source.checksum, job.user_id));
        }
        const { report, usage } = await gradePhotos(context, images, adapter);
        job = await store.saveStage(job, "evaluate", {
          report,
          usageKey: job.lease_token,
          attempts: [usage],
        }, "correct");
      }
      const result = job.stage_results.evaluate as {
        report: PhotoGradingReport;
        attempts: Array<Record<string, unknown>>;
        usageKey: string;
      };
      await store.recordUsage(
        job,
        result.attempts.map((attempt) => ({ ...attempt, usageKey: result.usageKey })),
        context.modelID,
      );
      if (!job.stage_results.correct) {
        job = await store.saveStage(job, "correct", { ready: true }, "rewrite");
      }
      if (!job.stage_results.rewrite) {
        job = await store.saveStage(job, "rewrite", { ready: true }, "validate");
      }
      if (
        result.report.part !== context.part ||
        result.report.prompt_version !== context.promptVersion ||
        JSON.stringify(result.report.photo_review.text_sources ?? null) !==
          JSON.stringify(context.textInputs ?? null) ||
        result.report.photo_review.sources.length !== context.images.length ||
        result.report.photo_review.sources.some((source, index) =>
          source.path !== context.images[index]?.path ||
          source.checksum !== context.images[index]?.checksum
        )
      ) throw new Error("PHOTO_INTEGRITY_FAILED");
      if (context.part === "T") validateTranslationReport(result.report, context);
      await store.finish(job, result.report, []);
      return "completed";
    }
    const context = job.context_json as unknown as GradingContext;
    if (
      !submission || submission.user_id !== job.user_id ||
      context.contentHash !== submission.content_hash ||
      context.originalText !== submission.original_text ||
      !Array.isArray(context.sentences) || !context.task
    ) throw new Error("JOB_SNAPSHOT_MISMATCH");

    if (!job.stage_results.evaluate) {
      const { report, attempts } = context.part === "T"
        ? await gradeTranslation(context, [], adapter)
        : await runGrading(context, adapter);
      job = await store.saveStage(
        job,
        "evaluate",
        { report, attempts, usageKey: job.lease_token },
        "correct",
      );
    }
    const evaluation = job.stage_results.evaluate as {
      report?: GradingReport;
      attempts?: Array<Record<string, unknown>>;
      usageKey?: string;
    };
    const report = evaluation.report ?? job.stage_results.evaluate as unknown as GradingReport;
    if (evaluation.attempts) {
      await store.recordUsage(
        job,
        evaluation.attempts.map((a) => ({ ...a, usageKey: evaluation.usageKey })),
        context.modelID,
      );
    }
    if (!job.stage_results.correct) {
      job = await store.saveStage(job, "correct", { corrections: report.corrections }, "rewrite");
    }
    if (!job.stage_results.rewrite) {
      job = await store.saveStage(job, "rewrite", {
        rewrites: report.rewrites,
        review: report.review,
      }, "validate");
    }
    if (context.part === "T") validateTranslationReport(report, context);
    else validateReport(report, context);
    await store.finish(job, report, context.sentences);
    return "completed";
  } catch (error) {
    if (error instanceof GradingFailed) {
      try {
        await store.recordUsage(
          job,
          error.attempts as unknown as Array<Record<string, unknown>>,
          "deepseek-flash",
        );
      } catch {
        console.warn(JSON.stringify({ event: "usage_record_failed", jobId: job.id }));
      }
    }
    const code = error instanceof GradingFailed ? "GRADING_VALIDATION_FAILED" : safeCode(error);
    if (code === "LEASE_LOST") return "lease_lost";
    try {
      await store.fail(job, code, isRetryable(error));
    } catch (failure) {
      if (safeCode(failure) === "LEASE_LOST") return "lease_lost";
      throw failure;
    }
    return isRetryable(error) && job.attempts < job.max_attempts ? "retry" : "failed";
  }
}

function safeCode(error: unknown): string {
  if (error instanceof Error && /^[A-Z][A-Z0-9_]{1,80}$/.test(error.message)) return error.message;
  return "GRADING_INTERNAL_ERROR";
}

function isRetryable(error: unknown): boolean {
  if (!(error instanceof Error)) return false;
  const text = error instanceof GradingFailed
    ? error.attempts.flatMap((attempt) => attempt.errorCodes).join(" ")
    : error.message;
  if (
    /401|403|MISSING|INVALID_PROVIDER_URL|OUTPUT_LIMIT|OWNER_MISMATCH|SNAPSHOT_MISMATCH|PHOTO_INTEGRITY/
      .test(text)
  ) return false;
  return !/JOB_NOT_FOUND|SUBMISSION_CONFLICT|IDEMPOTENCY_CONFLICT/.test(text);
}

function validateInput(value: SubmitGradingInput): void {
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (
    !value || typeof value !== "object" || !uuid.test(value.idemKey ?? "") ||
    !value.task || !uuid.test(value.task.id ?? "") || !["A", "B", "T"].includes(value.task.part) ||
    (value.task.referenceTranslation !== undefined &&
      (typeof value.task.referenceTranslation !== "string" ||
        value.task.referenceTranslation.length > 20000)) ||
    typeof value.task.prompt !== "string" || typeof value.task.confirmed !== "boolean" ||
    !Number.isInteger(value.task.revision) || value.task.revision < 1 ||
    (value.task.title !== undefined &&
      (typeof value.task.title !== "string" || value.task.title.length > 200)) ||
    !Array.isArray(value.task.requirements) || value.task.requirements.length > 30 ||
    !value.task.requirements.every((p) =>
      p && typeof p.id === "string" && typeof p.text === "string" && p.text.length <= 2000
    ) ||
    !value.submission || !uuid.test(value.submission.id ?? "") ||
    typeof value.submission.originalText !== "string"
  ) {
    throw new Error("INVALID_SUBMISSION");
  }
}
