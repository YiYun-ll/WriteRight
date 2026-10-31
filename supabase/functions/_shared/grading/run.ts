import { buildPrompt } from "./prompt.ts";
import { ProviderError } from "./provider.ts";
import type { GradingContext, GradingReport, ModelAdapter } from "./types.ts";
import { ReportValidationError, validateReport } from "./validation.ts";

export interface AttemptRecord {
  attempt: number;
  durationMs: number;
  promptTokens: number;
  completionTokens: number;
  providerModel?: string;
  errorCodes: string[];
}
export class GradingFailed extends Error {
  constructor(readonly attempts: AttemptRecord[]) {
    super("GRADING_VALIDATION_FAILED");
    this.name = "GradingFailed";
  }
}

/** P3 engineering PoC. P5 will schedule durable, independently persisted stages around this boundary. */
export async function runGrading(
  context: GradingContext,
  adapter: ModelAdapter,
): Promise<{ report: GradingReport; attempts: AttemptRecord[] }> {
  const attempts: AttemptRecord[] = [];
  let repairCodes: string[] = [];
  for (let attempt = 1; attempt <= 2; attempt++) {
    const started = performance.now();
    const record: AttemptRecord = {
      attempt,
      durationMs: 0,
      promptTokens: 0,
      completionTokens: 0,
      errorCodes: [],
    };
    let terminal = false;
    try {
      const output = await adapter.complete(buildPrompt(context, repairCodes));
      Object.assign(record, {
        promptTokens: output.promptTokens,
        completionTokens: output.completionTokens,
        providerModel: output.model,
      });
      let parsed: unknown;
      try {
        parsed = JSON.parse(output.content);
      } catch {
        throw new ReportValidationError(["JSON"]);
      }
      if (typeof parsed === "object" && parsed !== null && !Array.isArray(parsed)) {
        if (
          ["WRITERIGHT_GRADING_V1_3", "WRITERIGHT_GRADING_V1_4", "WRITERIGHT_GRADING_V1_5"]
            .includes(context.promptVersion)
        ) {
          const object = parsed as Record<string, unknown>;
          if (object.rewrite_study && object.rewrites && typeof object.rewrites === "object") {
            (object.rewrites as Record<string, unknown>).study = object.rewrite_study;
            delete object.rewrite_study;
          }
        }
        // Program-owned fields never trust the model's word count, configuration, or identity.
        Object.assign(parsed, {
          schema_version: context.promptVersion === "WRITERIGHT_GRADING_V1_5"
            ? "1.3.0"
            : context.promptVersion === "WRITERIGHT_GRADING_V1_4"
            ? "1.2.0"
            : context.promptVersion === "WRITERIGHT_GRADING_V1_3"
            ? "1.1.0"
            : "1.0.0",
          word_count: context.wordCount,
          model_id: context.modelID,
          rubric_version: context.rubricVersion,
          prompt_version: context.promptVersion,
        });
      }
      const report = validateReport(parsed, context);
      record.durationMs = Math.round(performance.now() - started);
      attempts.push(record);
      return { report, attempts };
    } catch (error) {
      if (error instanceof ReportValidationError) record.errorCodes = error.codes;
      else if (error instanceof ProviderError) {
        record.errorCodes = [error.code];
        terminal = !error.retryable;
      } else {
        record.errorCodes = ["INTERNAL"];
        terminal = true;
      }
      record.durationMs = Math.round(performance.now() - started);
      attempts.push(record);
      repairCodes = record.errorCodes;
      if (terminal) break;
    }
  }
  throw new GradingFailed(attempts);
}
