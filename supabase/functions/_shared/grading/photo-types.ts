import type { GradingReport, Part } from "./types.ts";
export interface PhotoSource {
  role: "task" | "essay";
  page: number;
  path: string;
  checksum: string;
}
export interface PhotoReview {
  sources: PhotoSource[];
  task_fingerprint: string | null;
  task_status: "readable" | "missing" | "unclear";
  strengths: string[];
  uncertainties: {
    role: "task" | "essay";
    page: number | null;
    message: string;
    blocks_scoring: boolean;
  }[];
  corrections: {
    page: number;
    original: string;
    corrected: string;
    reason: string;
    category: string;
    severity: "required" | "optional";
  }[];
  word_count_estimated: boolean;
}
export interface PhotoContext {
  source: "photo_grading_v2";
  part: Part;
  originalText: "";
  wordCount: 0;
  contentHash: string;
  task: {
    prompt: "";
    revision: 1;
    confirmed: boolean;
    requirements: [];
    chartFacts: [];
    fingerprint: string | null;
  };
  images: PhotoSource[];
  modelID: string;
  promptVersion: string;
  rubricVersion: string;
}
export type PhotoGradingReport = GradingReport & { photo_review: PhotoReview };
