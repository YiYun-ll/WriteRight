import { Buffer } from "node:buffer";
import {
  gradePhotos,
  PHOTO_PROMPT_VERSION,
  PHOTO_RUBRIC_VERSION,
} from "../supabase/functions/_shared/grading/photo-grading.ts";
import { DeepSeekAdapter } from "../supabase/functions/_shared/grading/provider.ts";
import type { PhotoContext } from "../supabase/functions/_shared/grading/photo-types.ts";
import { makeContext } from "../supabase/functions/_shared/grading/context.ts";
import { runGrading } from "../supabase/functions/_shared/grading/run.ts";
import { countWords } from "../supabase/functions/_shared/grading/context.ts";

if (!Deno.args.includes("--live")) {
  throw new Error(
    "Explicit --live required; uses paid model calls with private synthetic fixtures.",
  );
}
const adapter = new DeepSeekAdapter({
  apiKey: Deno.env.get("DEEPSEEK_API_KEY") ?? "",
  baseURL: "https://api.deepseek.com",
  model: "deepseek-flash",
});
if (Deno.args.includes("--typed")) {
  const context = await makeContext({
    part: "A",
    originalText:
      "Dear Alex,\n\nI has a book. Reading helps me understand the world. I would like to lend it to you because it explains everyday ideas clearly. Please let me know whether you would like to read it. We can discuss what we learn from it.\n\nYours,\nLi Ming",
    task: {
      prompt:
        "Write an email of about 100 words to Alex. Recommend a book without inventing its title or author, explain why it is worth reading, and offer to lend it. Sign Li Ming.",
      revision: 1,
      confirmed: true,
      requirements: [],
    },
  });
  const started = Date.now();
  let attempt = 0;
  const recording = {
    complete: async (request: Parameters<typeof adapter.complete>[0]) => {
      const output = await adapter.complete(request);
      await Deno.writeTextFile(
        `tests/private/development-live/raw-typed-${++attempt}.json`,
        output.content,
      );
      return output;
    },
  };
  let result;
  try {
    result = await runGrading(context, recording);
  } catch (error) {
    const safe = error as { attempts?: { errorCodes: string[] }[] };
    console.log(JSON.stringify({ typedFailureCodes: safe.attempts?.map((x) => x.errorCodes) }));
    throw error;
  }
  await Deno.writeTextFile(
    "tests/private/development-live/result-typed.json",
    JSON.stringify(result, null, 2),
  );
  if (!result.report.model_essay || !result.report.advanced_advice?.length) {
    throw new Error("Typed development acceptance failed");
  }
  const summary = {
    schema: result.report.schema_version,
    prompt: result.report.prompt_version,
    adviceCount: result.report.advanced_advice.length,
    sentenceCount: result.report.sentence_reviews?.items.length,
    coverage: result.report.sentence_reviews?.coverage,
    modelWords: countWords(result.report.model_essay.english),
    elapsedMs: Date.now() - started,
  };
  await Deno.writeTextFile(
    "artifacts/development-live/typed-checks.json",
    JSON.stringify(summary, null, 2),
  );
  console.log(JSON.stringify(summary));
  Deno.exit(0);
}
const checks = [];
const parts: ("A" | "B")[] = Deno.args.includes("--part=B") ? ["B"] : ["A", "B"];
for (const part of parts) {
  const input = await Promise.all(["task", "essay"].map(async (role) => {
    const data = await Deno.readFile(`tests/private/development-live/${role}-${part}.jpg`);
    return "data:image/jpeg;base64," + Buffer.from(data).toString("base64");
  }));
  const context: PhotoContext = {
    source: "photo_grading_v2",
    part,
    originalText: "",
    wordCount: 0,
    contentHash: "synthetic",
    task: {
      prompt: "",
      revision: 1,
      confirmed: true,
      requirements: [],
      chartFacts: [],
      fingerprint: "synthetic",
    },
    images: [{ role: "task", page: 1, path: "synthetic-task", checksum: "synthetic" }, {
      role: "essay",
      page: 1,
      path: "synthetic-essay",
      checksum: "synthetic",
    }],
    modelID: "deepseek-flash",
    promptVersion: PHOTO_PROMPT_VERSION,
    rubricVersion: PHOTO_RUBRIC_VERSION[part],
  };
  const started = Date.now();
  let attempt = 0;
  const recording = {
    complete: async (request: Parameters<typeof adapter.complete>[0]) => {
      const output = await adapter.complete(request);
      await Deno.writeTextFile(
        `tests/private/development-live/raw-${part}-${++attempt}.json`,
        output.content,
      );
      return output;
    },
  };
  const result = await gradePhotos(context, input, recording);
  await Deno.writeTextFile(
    `tests/private/development-live/result-${part}.json`,
    JSON.stringify(result, null, 2),
  );
  const report = result.report;
  if (
    report.grading_mode !== "full" || !report.model_essay || !report.advanced_advice?.some((x) =>
      x.focus === "sentence"
    ) || !report.advanced_advice.some((x) => x.focus === "structure")
  ) throw new Error("Development acceptance failed");
  const summary = {
    part,
    schema: report.schema_version,
    prompt: report.prompt_version,
    adviceCount: report.advanced_advice.length,
    sentenceCount: report.sentence_reviews?.items.length,
    coverage: report.sentence_reviews?.coverage,
    modelWords: countWords(report.model_essay.english),
    hasChinese: /[\p{Script=Han}]/u.test(report.model_essay.translation_zh),
    highlightCount: report.model_essay.highlights.length,
    elapsedMs: Date.now() - started,
  };
  checks.push(summary);
  console.log(JSON.stringify(summary));
}
await Deno.writeTextFile(
  `artifacts/development-live/${PHOTO_PROMPT_VERSION}-checks.json`,
  JSON.stringify(
    {
      timestamp: new Date().toISOString(),
      checks,
      note: "Engineering acceptance on synthetic images; no human score gold labels.",
    },
    null,
    2,
  ),
);
