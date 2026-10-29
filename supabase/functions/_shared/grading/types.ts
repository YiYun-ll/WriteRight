export type Part = "A" | "B";
export type GradingMode = "full" | "language_only";
export interface TaskPoint {
  id: string;
  text: string;
}
export interface GradingInput {
  part: Part;
  originalText: string;
  task: {
    prompt: string;
    revision: number;
    confirmed: boolean;
    requirements: TaskPoint[];
  };
}
export interface Sentence {
  id: string;
  paragraphIndex: number;
  original: string;
  startUTF16: number;
  lengthUTF16: number;
}
export interface GradingContext extends GradingInput {
  mode: GradingMode;
  sentences: Sentence[];
  wordCount: number;
  contentHash: string;
  rubricVersion: string;
  promptVersion: string;
  modelID: string;
}
export interface GradingReport {
  schema_version: "1.0.0";
  part: Part;
  grading_mode: GradingMode;
  score: {
    value: number | null;
    max: 10 | 15;
    band: string | null;
    range: [number, number] | null;
    confidence: "high" | "medium" | "low";
  };
  word_count: number;
  rubric_version: string;
  prompt_version: string;
  model_id: string;
  overall_comment: string;
  dimensions: {
    name: string;
    level: string;
    explanation: string;
    evidence_sentence_ids: string[];
  }[];
  task_checks: {
    point_id: string;
    status: "passed" | "partial" | "failed" | "uncertain";
    reason: string;
    evidence_sentence_ids: string[];
  }[];
  corrections: {
    sentence_id: string;
    original: string;
    minimal_corrected: string;
    category: string;
    severity: "required" | "optional";
    impact: "high" | "medium" | "low";
    reason_zh: string;
    optional_upgrade: string | null;
  }[];
  rewrites: { minimal: string; enhanced: string };
  review: {
    top_issues: string[];
    expressions: { expression: string; meaning: string; usage: string }[];
    practice_advice: string;
  };
}

export interface CompletionRequest {
  system: string;
  user: string;
}
export interface CompletionResult {
  content: string;
  model: string;
  promptTokens: number;
  completionTokens: number;
  latencyMs: number;
}
export interface ModelAdapter {
  complete(request: CompletionRequest): Promise<CompletionResult>;
}
