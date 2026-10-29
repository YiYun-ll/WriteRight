import type { GradingContext, GradingInput, Part, Sentence } from "./types.ts";

export const PROMPT_VERSION = "WRITERIGHT_GRADING_V1_1";
export const RUBRIC_VERSION: Record<Part, string> = {
  A: "KY_EN2_A_V1",
  B: "KY_EN2_B_V1",
};

/** Reference count. Keep aligned with the native WordCounter; not an official exam rule. */
export function countWords(text: string): number {
  return text.match(
    /[A-Za-z]+(?:['’][A-Za-z]+)*(?:[-‑][A-Za-z]+(?:['’][A-Za-z]+)*)*|[0-9]+(?:[.,][0-9]+)*%?/g,
  )?.length ?? 0;
}

/** Server spans are authoritative for a report. JS offsets are UTF-16, as on NSString. */
export function segmentSentences(text: string): Sentence[] {
  const segmenter = new Intl.Segmenter("en", { granularity: "sentence" });
  const result: Sentence[] = [];
  let paragraphIndex = 0;
  for (const paragraph of text.matchAll(/[^\r\n]+/g)) {
    for (const item of segmenter.segment(paragraph[0])) {
      const original = item.segment.trim();
      if (!original) continue;
      const leading = item.segment.length - item.segment.trimStart().length;
      result.push({
        id: `s${result.length + 1}`,
        paragraphIndex,
        original,
        startUTF16: paragraph.index + item.index + leading,
        lengthUTF16: original.length,
      });
    }
    paragraphIndex++;
  }
  return result;
}

export async function makeContext(
  input: GradingInput,
  modelID = "deepseek-flash",
): Promise<GradingContext> {
  if (!input.originalText.trim() || input.originalText.length > 30_000) {
    throw new Error("INVALID_ESSAY_LENGTH");
  }
  if (
    !["A", "B"].includes(input.part) || !Number.isInteger(input.task.revision) ||
    input.task.revision < 1 || input.task.prompt.length > 20_000 ||
    input.task.requirements.length > 30 ||
    input.task.requirements.some((point) => !point.id || !point.text.trim()) ||
    new Set(input.task.requirements.map((point) => point.id)).size !==
      input.task.requirements.length
  ) throw new Error("INVALID_TASK");
  const hash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input.originalText));
  return {
    ...structuredClone(input),
    mode: input.task.confirmed && input.task.prompt.trim() ? "full" : "language_only",
    sentences: segmentSentences(input.originalText),
    wordCount: countWords(input.originalText),
    contentHash: Array.from(new Uint8Array(hash), (byte) => byte.toString(16).padStart(2, "0"))
      .join(""),
    rubricVersion: RUBRIC_VERSION[input.part],
    promptVersion: PROMPT_VERSION,
    modelID,
  };
}

export function scoreBand(part: Part, value: number): string {
  const boundaries = part === "A" ? [9, 7, 5, 3, 1] : [13, 10, 7, 4, 1];
  return ["优秀", "良好", "中等", "较差", "差"][boundaries.findIndex((min) => value >= min)] ??
    "无有效作答";
}
