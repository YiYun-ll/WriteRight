import { assert, assertEquals } from "jsr:@std/assert@1";
import { validDevelopment } from "../../supabase/functions/_shared/grading/development.ts";
import type { AdvancedAdvice, ModelEssay } from "../../supabase/functions/_shared/grading/types.ts";
import { makeContext } from "../../supabase/functions/_shared/grading/context.ts";
import { buildPrompt } from "../../supabase/functions/_shared/grading/prompt.ts";

const advice = (): AdvancedAdvice[] => [
  {
    focus: "sentence",
    observation_zh: "主干",
    before: "I has",
    after: "I have a book.",
    why_zh: "主谓一致",
    practice_zh: "检查一句的主干",
    page: 1,
  },
  {
    focus: "structure",
    observation_zh: "段落职责",
    before: "",
    after: "State the purpose, then explain it.",
    why_zh: "让读者理解目的",
    practice_zh: "给每段写一句作用",
    page: null,
  },
];
const model = (): ModelEssay => ({
  english: "I have a book.",
  translation_zh: "我有一本书。",
  highlights: [{ text: "I have a book.", reason_zh: "主干清楚" }],
  rationale_zh: "先说明主题，再解释。",
});

Deno.test("development requires sentence and whole-essay practice with source references", () => {
  assert(validDevelopment(advice(), model(), true, true, undefined, 1));
  assertEquals(validDevelopment(advice().slice(0, 1), model(), true, true, undefined, 1), false);
  const wrong = advice();
  wrong[0].page = 2;
  assertEquals(validDevelopment(wrong, model(), true, true, undefined, 1), false);
  assertEquals(validDevelopment(advice(), model(), true, true, "Different source"), false);
});
Deno.test("independent example needs a task and exact Chinese study anchors", () => {
  assertEquals(validDevelopment(advice(), model(), false, true, undefined, 1), false);
  assert(validDevelopment(advice(), null, false, true, undefined, 1));
  assert(validDevelopment([], null, false, false));
  const wrong = model();
  wrong.highlights[0].text = "Not in the example.";
  assertEquals(validDevelopment(advice(), wrong, true, true, undefined, 1), false);
  const repeated = model();
  repeated.english += " I have a book.";
  assertEquals(validDevelopment(advice(), repeated, true, true, undefined, 1), false);
});
Deno.test("new learning prompt preserves calibrated scores and freezes V1_3", async () => {
  const ctx = await makeContext({
    part: "A",
    originalText: "I has a book.",
    task: { prompt: "Describe a book.", revision: 1, confirmed: true, requirements: [] },
  });
  const fresh = buildPrompt(ctx);
  assert(fresh.system.includes("model_essay"));
  assert(fresh.system.includes('"maxItems":0'));
  assert(fresh.system.includes("不能自造point_id"));
  assert(fresh.system.includes("不承诺真实考试满分"));
  ctx.promptVersion = "WRITERIGHT_GRADING_V1_4";
  assertEquals(buildPrompt(ctx).system.includes("sentence_reviews"), false);
  assertEquals(JSON.parse(buildPrompt(ctx).user).metadata.schema_version, "1.2.0");
  ctx.promptVersion = "WRITERIGHT_GRADING_V1_3";
  assertEquals(buildPrompt(ctx).system.includes("model_essay"), false);
  assertEquals(JSON.parse(buildPrompt(ctx).user).metadata.schema_version, "1.1.0");
});

Deno.test("new independent example cannot reuse a rewrite under another label", () => {
  assertEquals(
    validDevelopment(advice(), model(), true, true, undefined, 1, {
      minimal: "I have a book.",
      enhanced: "I have a useful book.",
    }),
    false,
  );
  assertEquals(
    validDevelopment(advice(), model(), true, true, undefined, 1, {
      minimal: " I have  a book. ",
      enhanced: "Another example.",
    }),
    false,
  );
});
