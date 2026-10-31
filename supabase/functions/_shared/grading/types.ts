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
    chartFacts?: {
      id: string;
      label: string;
      period: string | null;
      value: string;
      unit: string;
      confirmed_by_user: boolean;
    }[];
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
  schema_version: "1.0.0" | "1.1.0" | "2.0.0" | "2.1.0" | "2.2.0" | "1.2.0" | "1.3.0" | "2.3.0";
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
  rewrites: { minimal: string; enhanced: string; study?: RewriteStudy };
  sentence_reviews?: SentenceReviews;
  advanced_advice?: AdvancedAdvice[];
  model_essay?: ModelEssay | null;
  review: {
    top_issues: string[];
    expressions: { expression: string; meaning: string; usage: string }[];
    practice_advice: string;
  };
}

export interface CompletionRequest {
  maxOutputTokens?: number;
  system: string;
  user: string;
  images?: string[];
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

export interface RewriteStudyVersion {
  translation_zh: string;
  highlights: { text: string; reason_zh: string }[];
}
export interface RewriteStudy {
  minimal: RewriteStudyVersion;
  enhanced: RewriteStudyVersion;
}

export interface AdvancedAdvice {
  focus: "sentence" | "structure";
  observation_zh: string;
  before: string;
  after: string;
  why_zh: string;
  practice_zh: string;
  page: number | null;
}
export interface ModelEssay extends RewriteStudyVersion {
  english: string;
  rationale_zh: string;
}

export interface SentenceReviews {
  coverage: "complete" | "partial" | "unreadable";
  notice_zh: string;
  items: {
    index: number;
    sentence_id: string | null;
    page: number | null;
    original: string;
    revised: string | null;
    status: "required" | "optional" | "keep" | "uncertain";
    reason_zh: string;
  }[];
}
