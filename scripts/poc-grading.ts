import fixtures from "../tests/fixtures/grading/samples.json" with { type: "json" };
import { makeContext } from "../supabase/functions/_shared/grading/context.ts";
import { DeepSeekAdapter } from "../supabase/functions/_shared/grading/provider.ts";
import { GradingFailed, runGrading } from "../supabase/functions/_shared/grading/run.ts";
import type { GradingInput } from "../supabase/functions/_shared/grading/types.ts";

if (!Deno.args.includes("--live")) {
  console.error("Pass --live to run a limited paid API PoC against synthetic fixtures.");
  Deno.exit(2);
}
const apiKey = Deno.env.get("DEEPSEEK_API_KEY") ?? "";
const baseURL = Deno.env.get("DEEPSEEK_BASE_URL") ?? "https://api.deepseek.com";
const model = Deno.env.get("DEFAULT_GRADING_MODEL") ?? "deepseek-flash";
const adapter = new DeepSeekAdapter({ apiKey, baseURL, model });
const results = [];
const sampleIDs = Deno.args.find((arg) => arg.startsWith("--sample="))?.slice(9).split(",");
const outputPath = Deno.args.find((arg) => arg.startsWith("--output="))?.slice(9) ??
  "artifacts/grading-poc.json";
const selected = fixtures.filter((sample) => !sampleIDs || sampleIDs.includes(sample.id));
if (!selected.length) throw new Error("NO_MATCHING_SAMPLE");
for (const sample of selected) {
  const context = await makeContext(sample.input as GradingInput, model);
  try {
    const result = await runGrading(context, adapter);
    results.push({
      sampleID: sample.id,
      contentHash: context.contentHash,
      ...result,
      status: "passed",
    });
    console.log(
      JSON.stringify({
        sampleID: sample.id,
        status: "passed",
        score: result.report.score.value,
        attempts: result.attempts,
      }),
    );
  } catch (error) {
    const attempts = error instanceof GradingFailed ? error.attempts : [];
    results.push({ sampleID: sample.id, status: "failed", attempts });
    console.log(JSON.stringify({ sampleID: sample.id, status: "failed", attempts }));
  }
  await Deno.mkdir("artifacts", { recursive: true });
  await Deno.writeTextFile(
    outputPath,
    JSON.stringify(
      {
        generatedAt: new Date().toISOString(),
        model,
        dataset: "Synthetic engineering fixtures; no human quality labels or accuracy claims.",
        results,
      },
      null,
      2,
    ),
  );
}
if (results.some((result) => result.status === "failed")) Deno.exitCode = 1;
