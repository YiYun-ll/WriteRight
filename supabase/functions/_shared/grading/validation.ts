import { Ajv2020 } from "npm:ajv@8.17.1/dist/2020.js";
import schema from "../contracts/report.schema.json" with { type: "json" };
import { scoreBand } from "./context.ts";
import type { GradingContext, GradingReport } from "./types.ts";

const ajv = new Ajv2020({ allErrors: true, strict: true, strictTuples: false });
const validateShape = ajv.compile<GradingReport>(schema);

/** Codes only: never include model output or essays in exception/log messages. */
export class ReportValidationError extends Error {
  constructor(readonly codes: string[]) {
    super(`REPORT_INVALID:${codes.join(",")}`);
    this.name = "ReportValidationError";
  }
}

const numberTokens = (text: string): string[] => text.match(/\d+(?:[.,]\d+)*(?:%)?/g) ?? [];

/** Accept unambiguous cardinal spelling in a rewrite ("at two" → "at 2"). */
function spelledNumberTokens(text: string): string[] {
  const values: Record<string, number> = {
    zero: 0,
    one: 1,
    two: 2,
    three: 3,
    four: 4,
    five: 5,
    six: 6,
    seven: 7,
    eight: 8,
    nine: 9,
    ten: 10,
    eleven: 11,
    twelve: 12,
    thirteen: 13,
    fourteen: 14,
    fifteen: 15,
    sixteen: 16,
    seventeen: 17,
    eighteen: 18,
    nineteen: 19,
    twenty: 20,
    thirty: 30,
    forty: 40,
    fifty: 50,
    sixty: 60,
    seventy: 70,
    eighty: 80,
    ninety: 90,
  };
  const pattern =
    /\b(?:(?:twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)(?:[ -](?:one|two|three|four|five|six|seven|eight|nine))?|zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen)\b/gi;
  return Array.from(
    text.matchAll(pattern),
    (match) =>
      String(match[0].toLowerCase().split(/[ -]/).reduce((sum, word) => sum + values[word], 0)),
  );
}

/** Minimal rewrite is composed only from required corrections, preserving all other bytes. */
export function composeMinimal(context: GradingContext, report: GradingReport): string {
  let text = context.originalText;
  const byID = new Map(context.sentences.map((sentence) => [sentence.id, sentence]));
  const edits = report.corrections.filter((item) => item.severity === "required")
    .map((item) => ({ item, span: byID.get(item.sentence_id)! }))
    .sort((a, b) => b.span.startUTF16 - a.span.startUTF16);
  for (const { item, span } of edits) {
    text = text.slice(0, span.startUTF16) + item.minimal_corrected +
      text.slice(span.startUTF16 + span.lengthUTF16);
  }
  return text;
}

export function validateReport(value: unknown, context: GradingContext): GradingReport {
  if (!validateShape(value)) {
    throw new ReportValidationError(["SCHEMA"]);
  }
  const report = structuredClone(value);
  const errors = new Set<string>();
  const max = context.part === "A" ? 10 : 15;
  if (
    report.part !== context.part || report.grading_mode !== context.mode ||
    report.score.max !== max || report.rubric_version !== context.rubricVersion ||
    report.prompt_version !== context.promptVersion || report.model_id !== context.modelID ||
    report.word_count !== context.wordCount
  ) errors.add("METADATA");
  const { value: score, band, range } = report.score;
  if (context.mode === "language_only") {
    if (score !== null || band !== null || range !== null) errors.add("LANGUAGE_ONLY_SCORE");
    if (report.task_checks.length) errors.add("UNCONFIRMED_TASK_CHECKS");
  } else {
    if (
      score === null || score > max || band !== scoreBand(context.part, score) ||
      range === null || range[0] > score || range[1] < score || range[1] > max
    ) errors.add("SCORE_BAND_RANGE");
  }
  const byID = new Map(context.sentences.map((sentence) => [sentence.id, sentence]));
  const validEvidence = (ids: string[]) => ids.every((id) => byID.has(id));
  if (report.dimensions.length !== 3) errors.add("DIMENSIONS");
  for (const item of report.dimensions) {
    if (!validEvidence(item.evidence_sentence_ids)) errors.add("SENTENCE_REFERENCE");
  }
  const points = new Set(context.task.requirements.map((point) => point.id));
  const checked = new Set<string>();
  for (const item of report.task_checks) {
    if (!points.has(item.point_id) || checked.has(item.point_id)) errors.add("TASK_REFERENCE");
    checked.add(item.point_id);
    if (!validEvidence(item.evidence_sentence_ids)) errors.add("SENTENCE_REFERENCE");
    if (item.status === "passed" && !item.evidence_sentence_ids.length) {
      errors.add("MISSING_EVIDENCE");
    }
  }
  if (context.mode === "full" && checked.size !== points.size) errors.add("MISSING_TASK_CHECK");
  const edited = new Set<string>();
  for (const item of report.corrections) {
    const sentence = byID.get(item.sentence_id);
    if (!sentence || item.original !== sentence.original) errors.add("ORIGINAL_MISMATCH");
    if (edited.has(item.sentence_id)) errors.add("DUPLICATE_CORRECTION");
    edited.add(item.sentence_id);
    if (!item.minimal_corrected.trim()) errors.add("EMPTY_CORRECTION");
    if (item.severity === "optional" && item.minimal_corrected !== item.original) {
      errors.add("OPTIONAL_CHANGED_MINIMAL");
    }
    if (item.severity === "required" && item.minimal_corrected === item.original) {
      errors.add("REQUIRED_UNCHANGED");
    }
    // Necessary language edits cannot silently alter numeric facts in that source sentence.
    if (numberTokens(item.original).join("|") !== numberTokens(item.minimal_corrected).join("|")) {
      errors.add("CORRECTION_NUMERIC_FACT");
    }
  }
  // Conservative guard, not a complete fact/semantic verifier. Human quality evaluation remains required.
  const factSource = context.originalText + "\n" + context.task.prompt;
  const sourceNumbers = new Set([...numberTokens(factSource), ...spelledNumberTokens(factSource)]);
  if (numberTokens(report.rewrites.enhanced).some((token) => !sourceNumbers.has(token))) {
    errors.add("REWRITE_NEW_NUMBER");
  }
  if (errors.size) throw new ReportValidationError([...errors]);
  report.rewrites.minimal = composeMinimal(context, report);
  return report;
}
