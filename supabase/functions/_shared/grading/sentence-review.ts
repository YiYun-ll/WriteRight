import type { Sentence, SentenceReviews } from "./types.ts";

export const SENTENCE_REVIEW_PROMPT = `
sentence_reviews是最终报告的逐句学习反馈，不是中间转录或OCR。按作文原有页序/句序逐句给出original（忠实保留错误）、revised、status与具体中文reason_zh。不得把全篇重写结果拆句冒充原稿。
status=required表示必要语言修改，revised为保留原意的最小修正，并具体解释语法/搭配/衔接等原因；optional表示可选表达，解释为什么更清楚而非称原句有错；keep表示自然准确，revised必须逐字等于original，解释该句值得保留的具体原因；uncertain表示有字看不清，revised=null，只引用能确认的片段或留空并说明需要核对哪里，不将疑字计作错误。
照片项sentence_id=null、page为真实作文页码；index从1连续递增，页码不倒退。文字项按sentence_review_targets逐项覆盖，sentence_id和original逐字复制输入，page=null；称呼/落款若被输入分为独立项也说明格式作用。文字项必须和corrections保持一致，不能另造冲突修改；optional的最小稿仍保留原句。
完整可读的作文应覆盖所有句子，coverage=complete。最多40项；超过40句、部分无法定位或图像遗漏时coverage=partial，notice_zh清楚说明具体范围/疑点，不宣称全篇完成。完全不可读时coverage=unreadable、items=[]并说明需补拍。文字目标被截取时coverage=partial。每句都要有理由，避免同一句空泛评价反复复制；不为凑修改数将正确句判错，不静默修改事实/图表数值。
独立示范须从题面重新构思，不能照抄最小修改或表达增强，也不能只更换空白或标题。
sentence_reviews与advanced_advice、model_essay、rewrite_study、review为顶层平级字段。`;

export function sentenceReviewTargets(sentences: Sentence[]): Sentence[] {
  return sentences.slice(0, 40);
}

export function validSentenceReviews(
  review: SentenceReviews | undefined,
  source: { sentences?: Sentence[]; pages?: number; readable?: boolean },
): boolean {
  if (!review || !Array.isArray(review.items) || review.items.length > 40) return false;
  if (!["complete", "partial", "unreadable"].includes(review.coverage)) return false;
  if (review.coverage !== "complete" && !/[\p{Script=Han}]/u.test(review.notice_zh)) return false;
  if (
    review.coverage === "unreadable" && (review.items.length || source.sentences || source.readable)
  ) {
    return false;
  }
  if (!review.items.length && review.coverage !== "unreadable") return false;
  if (source.readable && !review.items.length) return false;
  const targets = source.sentences ? sentenceReviewTargets(source.sentences) : undefined;
  if (targets) {
    if (review.items.length !== targets.length) return false;
    if (review.coverage !== (source.sentences!.length > targets.length ? "partial" : "complete")) {
      return false;
    }
  }
  let previousPage = 0;
  for (const [index, item] of review.items.entries()) {
    if (!["required", "optional", "keep", "uncertain"].includes(item.status)) return false;
    if (item.index !== index + 1 || !/[\p{Script=Han}]/u.test(item.reason_zh)) return false;
    if (targets) {
      if (
        item.page !== null || item.sentence_id !== targets[index].id ||
        item.original !== targets[index].original
      ) return false;
    } else if (
      item.sentence_id !== null || !item.page || item.page > (source.pages ?? 0) ||
      item.page < previousPage
    ) return false;
    previousPage = item.page ?? 0;
    if (item.status === "uncertain") {
      if (item.revised !== null || review.coverage === "complete") return false;
    } else {
      if (!item.original.trim() || !item.revised?.trim()) return false;
      if (item.status === "keep" && item.revised !== item.original) return false;
      if (["required", "optional"].includes(item.status) && item.revised === item.original) {
        return false;
      }
      // Feedback cannot silently correct task facts while claiming to fix language.
      const numbers = (text: string) => text.match(/\d+(?:[.,]\d+)*(?:%)?/g)?.join("|") ?? "";
      if (numbers(item.original) !== numbers(item.revised!)) return false;
    }
  }
  return true;
}
