import { makeContext, scoreBand } from "../../supabase/functions/_shared/grading/context.ts";
import type {
  CompletionRequest,
  CompletionResult,
  GradingContext,
  GradingReport,
  ModelAdapter,
} from "../../supabase/functions/_shared/grading/types.ts";
import {
  processNextJob,
  statusForJob,
  submitGrading,
  type SubmitGradingInput,
} from "../../supabase/functions/_shared/jobs/service.ts";
import { type GradingJob, JobStore } from "../../supabase/functions/_shared/jobs/store.ts";

const userA = "11111111-1111-4111-8111-111111111111";
const userB = "22222222-2222-4222-8222-222222222222";

function input(
  submissionID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
  key = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
): SubmitGradingInput {
  return {
    idemKey: key,
    task: {
      id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
      part: "A",
      title: "Synthetic",
      prompt: "Write about a book and explain why you like it.",
      requirements: [{ id: "p1", text: "Explain the reason" }],
      revision: 1,
      confirmed: true,
    },
    submission: { id: submissionID, originalText: "I has a book. I like it because it is useful." },
  };
}

async function fixture(context?: GradingContext): Promise<GradingReport> {
  const ctx = context ?? await makeContext({
    part: "A",
    originalText: "I has a book. I like it because it is useful.",
    task: {
      prompt: "Write about a book and explain why you like it.",
      requirements: [{ id: "p1", text: "Explain the reason" }],
      revision: 1,
      confirmed: true,
    },
  });
  return {
    schema_version: "1.0.0",
    part: "A",
    grading_mode: "full",
    score: { value: 7, max: 10, band: scoreBand("A", 7), range: [6, 8], confidence: "medium" },
    word_count: ctx.wordCount,
    rubric_version: ctx.rubricVersion,
    prompt_version: ctx.promptVersion,
    model_id: ctx.modelID,
    overall_comment: "Synthetic result",
    dimensions: ["内容与任务", "语言", "组织"].map((name) => ({
      name,
      level: "中等",
      explanation: "Synthetic",
      evidence_sentence_ids: ["s1"],
    })),
    task_checks: [{
      point_id: "p1",
      status: "partial",
      reason: "Synthetic",
      evidence_sentence_ids: ["s2"],
    }],
    corrections: [{
      sentence_id: "s1",
      original: ctx.sentences[0].original,
      minimal_corrected: "I have a book.",
      category: "主谓一致",
      severity: "required",
      impact: "medium",
      reason_zh: "Synthetic",
      optional_upgrade: null,
    }],
    rewrites: {
      minimal: "I have a book.\nI like it because it is useful.",
      enhanced: ctx.originalText,
      study: {
        minimal: {
          translation_zh: "我有一本书。我喜欢它，因为它很有用。",
          highlights: [{ text: "I have a book.", reason_zh: "正确的主谓搭配。" }],
        },
        enhanced: {
          translation_zh: "合成测试译文。",
          highlights: [{ text: ctx.sentences[0].original, reason_zh: "测试句子。" }],
        },
      },
    },
    sentence_reviews: {
      coverage: "complete",
      notice_zh: "",
      items: ctx.sentences.map((sentence, index) => ({
        index: index + 1,
        sentence_id: sentence.id,
        page: null,
        original: sentence.original,
        revised: index === 0 ? sentence.original.replace("has", "have") : sentence.original,
        status: index === 0 ? "required" as const : "keep" as const,
        reason_zh: index === 0 ? "主语I应与have搭配。" : "句子信息清楚，保留原句。",
      })),
    },
    advanced_advice: [
      {
        focus: "sentence",
        observation_zh: "清楚表达",
        before: ctx.sentences[0].original,
        after: "I have a book.",
        why_zh: "先写清主干。",
        practice_zh: "检查一句主谓。",
        page: null,
      },
      {
        focus: "structure",
        observation_zh: "层次",
        before: "",
        after: "State the point, then explain it.",
        why_zh: "段落各有职责。",
        practice_zh: "标记段落作用。",
        page: null,
      },
    ],
    model_essay: {
      english: "Reading opens a window to new ideas.",
      translation_zh: "我有一本书。",
      highlights: [{ text: "Reading opens a window to new ideas.", reason_zh: "主干清楚。" }],
      rationale_zh: "合成示范。",
    },
    review: { top_issues: [], expressions: [], practice_advice: "Practice" },
  };
}

class Adapter implements ModelAdapter {
  calls = 0;
  constructor(private readonly invalid = false) {}
  async complete(_request: CompletionRequest): Promise<CompletionResult> {
    this.calls++;
    return {
      content: this.invalid ? "{}" : JSON.stringify(await fixture()),
      model: "deepseek-flash",
      promptTokens: 10,
      completionTokens: 20,
      latencyMs: 1,
    };
  }
}

class MemoryBackend {
  jobs: GradingJob[] = [];
  tasks = new Map<string, Record<string, unknown>>();
  submissions = new Map<string, Record<string, unknown>>();
  reports: Record<string, unknown>[] = [];

  store(): JobStore {
    return new JobStore("http://local", "test-service", this.fetch);
  }

  fetch = async (input: string | URL | Request, init?: RequestInit): Promise<Response> => {
    await Promise.resolve();
    const url = new URL(
      typeof input === "string" ? input : input instanceof URL ? input : input.url,
    );
    const method = init?.method ?? "GET";
    const body = init?.body ? JSON.parse(String(init.body)) : null;
    const path = url.pathname.replace("/rest/v1", "");
    if (path === "/rpc/enqueue_grading") {
      const data = body.p_input;
      const existing = this.jobs.find((j) =>
        j.user_id === body.p_user_id && j.idem_key === data.idemKey
      );
      if (existing) {
        if (existing.submission_id !== data.submission.id) {
          return Response.json({ message: "IDEMPOTENCY_CONFLICT" }, { status: 409 });
        }
        return rows([existing]);
      }
      this.tasks.set(data.task.id, data.task);
      this.submissions.set(data.submission.id, {
        id: data.submission.id,
        user_id: body.p_user_id,
        task_id: data.task.id,
        original_text: data.submission.originalText,
        content_hash: body.p_context.contentHash,
      });
      const job: GradingJob = {
        id: data.idemKey,
        idem_key: data.idemKey,
        user_id: body.p_user_id,
        submission_id: data.submission.id,
        status: "queued",
        stage: "evaluate",
        attempts: 0,
        max_attempts: 3,
        stage_results: {},
        error_code: null,
        context_json: body.p_context,
        lease_token: "",
      };
      this.jobs.push(job);
      return rows([job]);
    }
    if (path === "/essay_submissions") {
      return rows(
        [...this.submissions.values()].filter((row) =>
          row.id === url.searchParams.get("id")?.slice(3)
        ),
      );
    }
    if (
      ["/rpc/advance_grading_job", "/rpc/finish_grading_job", "/rpc/fail_grading_job"].includes(
        path,
      )
    ) {
      const job = this.jobs.find((j) => j.id === body.p_job_id);
      if (!job || job.lease_token !== body.p_lease_token) {
        return Response.json({ message: "LEASE_LOST" }, { status: 409 });
      }
      if (path === "/rpc/advance_grading_job") {
        job.stage_results[body.p_stage] = body.p_value;
        job.stage = body.p_next;
        return rows([job]);
      }
      if (path === "/rpc/finish_grading_job") {
        this.reports.push({ job_id: job.id, report_json: body.p_report });
        job.status = "completed";
        job.stage = "done";
      } else {
        job.status = body.p_retryable && job.attempts < job.max_attempts ? "queued" : "failed";
        job.error_code = body.p_code;
      }
      return new Response(null, { status: 204 });
    }
    if (path === "/grading_jobs") {
      if (method === "PATCH") {
        const id = url.searchParams.get("id")?.slice(3);
        const job = this.jobs.find((row) => row.id === id);
        if (!job) throw new Error("Job not found");
        Object.assign(job, body);
        return rows([]);
      }
      const id = url.searchParams.get("id")?.slice(3);
      const userID = url.searchParams.get("user_id")?.slice(3);
      const key = url.searchParams.get("idem_key")?.slice(3);
      return rows(
        this.jobs.filter((row) =>
          (!id || row.id === id) && (!userID || row.user_id === userID) &&
          (!key || row.idem_key === key)
        ),
      );
    }
    if (path === "/rpc/claim_grading_job") {
      const job = this.jobs.find((row) =>
        (row.status === "queued" || row.status === "running") && row.attempts < row.max_attempts
      );
      if (!job) return rows([]);
      job.status = "running";
      job.lease_token = crypto.randomUUID();
      job.attempts++;
      return rows([job]);
    }
    if (path === "/grading_reports") {
      if (method === "POST") {
        const report = { ...body, id: `report-${this.reports.length + 1}` };
        this.reports.push(report);
        return rows([{ id: report.id }], 201);
      }
      const jobID = url.searchParams.get("job_id")?.slice(3);
      return rows(this.reports.filter((row) => row.job_id === jobID));
    }
    if (path === "/grading_usage") return rows([], 201);
    throw new Error(`Unhandled ${method} ${path}`);
  };
}

function rows(value: unknown, status = 200): Response {
  return Response.json(value, { status });
}

Deno.test("submission is idempotent and rejects key reuse for another submission", async () => {
  const backend = new MemoryBackend();
  const store = backend.store();
  const first = await submitGrading(store, userA, input(), "deepseek-flash");
  const second = await submitGrading(store, userA, input(), "deepseek-flash");
  if (first.jobId !== second.jobId || backend.jobs.length !== 1) {
    throw new Error("Duplicate job created");
  }
  let rejected = false;
  try {
    await submitGrading(
      store,
      userA,
      input("dddddddd-dddd-4ddd-8ddd-dddddddddddd"),
      "deepseek-flash",
    );
  } catch (error) {
    rejected = error instanceof Error && error.message === "IDEMPOTENCY_CONFLICT";
  }
  if (!rejected) throw new Error("Idempotency conflict was accepted");
});

Deno.test("worker persists all stages and completes a report", async () => {
  const backend = new MemoryBackend();
  const store = backend.store();
  await submitGrading(store, userA, input(), "deepseek-flash");
  const adapter = new Adapter();
  if (await processNextJob(store, adapter) !== "completed") throw new Error("Job did not complete");
  if (adapter.calls !== 1 || backend.reports.length !== 1) {
    throw new Error("Unexpected model or report count");
  }
  const job = backend.jobs[0];
  for (const stage of ["evaluate", "correct", "rewrite"]) {
    if (!job.stage_results[stage]) throw new Error(`Missing ${stage}`);
  }
  if (job.status !== "completed" || job.stage !== "done") throw new Error("Job is not done");
});

Deno.test("stage recovery does not repeat the paid model call", async () => {
  const backend = new MemoryBackend();
  const store = backend.store();
  await submitGrading(store, userA, input(), "deepseek-flash");
  backend.jobs[0].stage = "correct";
  backend.jobs[0].stage_results.evaluate = await fixture();
  const adapter = new Adapter();
  if (await processNextJob(store, adapter) !== "completed" || adapter.calls !== 0) {
    throw new Error("Recovery repeated model work");
  }
});

Deno.test("validation failures back off and become terminal at max attempts", async () => {
  const backend = new MemoryBackend();
  const store = backend.store();
  await submitGrading(store, userA, input(), "deepseek-flash");
  const adapter = new Adapter(true);
  if (await processNextJob(store, adapter) !== "retry") {
    throw new Error("First failure did not retry");
  }
  if (await processNextJob(store, adapter) !== "retry") {
    throw new Error("Second failure did not retry");
  }
  if (await processNextJob(store, adapter) !== "failed") {
    throw new Error("Final failure was not terminal");
  }
  if (backend.jobs[0].status !== "failed" || backend.reports.length !== 0) {
    throw new Error("Invalid report escaped");
  }
});

Deno.test("job status is isolated by authenticated user", async () => {
  const backend = new MemoryBackend();
  const store = backend.store();
  const submitted = await submitGrading(store, userA, input(), "deepseek-flash");
  let rejected = false;
  try {
    await statusForJob(store, userB, submitted.jobId as string);
  } catch (error) {
    rejected = error instanceof Error && error.message === "JOB_NOT_FOUND";
  }
  if (!rejected) throw new Error("Cross-user job status was exposed");
});

Deno.test("queued job evaluates the immutable task snapshot after an editable task changes", async () => {
  const backend = new MemoryBackend();
  const store = backend.store();
  await submitGrading(store, userA, input(), "deepseek-flash");
  backend.tasks.clear();
  const adapter = new Adapter();
  if (await processNextJob(store, adapter) !== "completed") {
    throw new Error("Snapshot depended on editable task");
  }
});
Deno.test("invalid runtime submission is rejected before any database writes", async () => {
  const backend = new MemoryBackend();
  try {
    await submitGrading(backend.store(), userA, {} as SubmitGradingInput, "deepseek-flash");
    throw new Error("Expected rejection");
  } catch (error) {
    if (
      !(error instanceof Error) || error.message !== "INVALID_SUBMISSION" || backend.jobs.length
    ) throw error;
  }
});
