import { assert, assertEquals } from "jsr:@std/assert@1";
import { validRewriteStudy } from "../../supabase/functions/_shared/grading/rewrite-study.ts";
import { buildPrompt } from "../../supabase/functions/_shared/grading/prompt.ts";
import { makeContext } from "../../supabase/functions/_shared/grading/context.ts";
import type { RewriteStudy } from "../../supabase/functions/_shared/grading/types.ts";
const version = () => ({
  translation_zh: "我们在2022年见面。",
  highlights: [{ text: "We met in 2022.", reason_zh: "年份与过去时一致。" }],
});
function sample(): { minimal: string; enhanced: string; study: RewriteStudy } {
  return {
    minimal: "😀 We met in 2022.",
    enhanced: "We met in 2022.",
    study: { minimal: version(), enhanced: version() },
  };
}
Deno.test("study anchors require exact unique nonoverlapping quotes and real translations", () => {
  assert(validRewriteStudy(sample()));
  const wrong = sample();
  wrong.study.minimal.highlights[0].text = "We met in 2023.";
  assertEquals(validRewriteStudy(wrong), false);
  const repeated = sample();
  repeated.minimal += " We met in 2022.";
  assertEquals(validRewriteStudy(repeated), false);
  const overlapping = sample();
  overlapping.study.minimal.highlights.push({ text: "met in 2022.", reason_zh: "重复范围" });
  assertEquals(validRewriteStudy(overlapping), false);
  const untranslated = sample();
  untranslated.study.enhanced.translation_zh = "English only.";
  assertEquals(validRewriteStudy(untranslated), false);
});
Deno.test("empty rewrites cannot retain invented translations or highlights; legacy absence is explicit", () => {
  assertEquals(validRewriteStudy({ minimal: "", enhanced: "" }), false);
  assert(validRewriteStudy({ minimal: "old", enhanced: "old" }, false));
  const empty = {
    minimal: "",
    enhanced: "",
    study: {
      minimal: { translation_zh: "", highlights: [] },
      enhanced: { translation_zh: "", highlights: [] },
    },
  };
  assert(validRewriteStudy(empty));
  empty.study.minimal.translation_zh = "不存在的译文";
  assertEquals(validRewriteStudy(empty), false);
});
Deno.test("new calibration is evidence based; accepted legacy jobs retain their prompt and contract", async () => {
  const ctx = await makeContext({
    part: "A",
    originalText: "I has a book.",
    task: { prompt: "Explain the reason.", revision: 1, confirmed: true, requirements: [] },
  });
  const fresh = buildPrompt(ctx);
  assert(fresh.system.includes("不默认从良好档开始"));
  assert(fresh.system.includes("不统一减1–2分"));
  assert(fresh.system.includes("translation_zh"));
  assertEquals(JSON.parse(fresh.user).metadata.schema_version, "1.3.0");
  ctx.promptVersion = "WRITERIGHT_GRADING_V1_2";
  const old = buildPrompt(ctx);
  assertEquals(old.system.includes("translation_zh"), false);
  assertEquals(JSON.parse(old.user).metadata.schema_version, "1.0.0");
});
