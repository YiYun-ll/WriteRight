import type { AdvancedAdvice, ModelEssay } from "./types.ts";
import { validRewriteStudy } from "./rewrite-study.ts";
export const DEVELOPMENT_PROMPT = `
新增 advanced_advice：在必改错误之外给2–4条具体进阶建议，至少覆盖句式表达(sentence)和篇章组织(structure)。每条包含 observation_zh（具体观察）、before（原稿短引用，保留错误；篇章可留空）、after（英文示例/段落提纲）、why_zh（为什么适合本题/本稿）、practice_zh（一个可执行练习）、page（照片句式引用对应作文页码；文字稿为null；篇章建议针对整篇时为null，指向具体段落时可引用真实作文页码）。句式建议讲清信息重心、主从关系、衔接、句长节奏或准确表达；篇章建议分析各段职责、论证链、过渡与首尾照应。不要泛泛要求高级词/复杂句，不把进阶练习计作原稿错误或借此扣分；原稿很成熟时给可选方向。原文难辨时少给或为空，不能猜测引用。
新增顶层 model_essay：只有题面/任务与关键事实足够支持full评分时，另行创作一篇对准本题最高档要求的独立英文示范，不能只复制或润色学生稿，不承诺真实考试满分，不给示范稿额外分数。字段 english、translation_zh（完整忠实中文译文）、highlights（1–3个逐字唯一英文句与reason_zh）、rationale_zh（中文说明布局、句式和适用之处）。符合本题体裁、字数、语域，原稿错误不作为范文事实来源，图表数据只以清晰题图为据；不捏造图表数值或题目事实。题目缺失/不清或language_only时必须null，不用作文反推题目。
评分先独立完成，再写上述材料。advanced_advice、model_essay、rewrite_study、review为平级顶层字段，不互相嵌套。`;

export function validDevelopment(
  advice: AdvancedAdvice[] | undefined,
  model: ModelEssay | null | undefined,
  full: boolean,
  essayReadable: boolean,
  original?: string,
  pages?: number,
  rewrites?: { minimal: string; enhanced: string },
): boolean {
  if (!Array.isArray(advice) || advice.length > 6) return false;
  if (
    essayReadable &&
    (!advice.some((x) => x.focus === "sentence") || !advice.some((x) => x.focus === "structure"))
  ) return false;
  for (const item of advice) {
    if (
      !item.observation_zh.trim() || !item.after.trim() || !item.why_zh.trim() ||
      !item.practice_zh.trim()
    ) return false;
    if (item.focus === "sentence") {
      if (!item.before.trim() || (original !== undefined && !original.includes(item.before))) {
        return false;
      }
      if (pages !== undefined && (!item.page || item.page > pages)) return false;
    } else if (item.page !== null && (pages === undefined || item.page > pages)) return false;
  }
  if (!full) return model === null;
  if (!model || !model.english.trim() || !model.rationale_zh.trim()) return false;
  if (rewrites) {
    const normalized = (text: string) => text.trim().replace(/\s+/g, " ");
    if (
      [rewrites.minimal, rewrites.enhanced, original ?? ""].some((text) =>
        normalized(text) === normalized(model.english)
      )
    ) return false;
  }
  return validRewriteStudy({
    minimal: model.english,
    enhanced: model.english,
    study: { minimal: model, enhanced: model },
  });
}
