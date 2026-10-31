import { assert, assertEquals } from "jsr:@std/assert@1";
import { validSentenceReviews } from "../../supabase/functions/_shared/grading/sentence-review.ts";
import { segmentSentences } from "../../supabase/functions/_shared/grading/context.ts";
import type { SentenceReviews } from "../../supabase/functions/_shared/grading/types.ts";

const photo = (): SentenceReviews => ({
  coverage: "complete",
  notice_zh: "",
  items: [
    {
      index: 1,
      sentence_id: null,
      page: 1,
      original: "I has a book.",
      revised: "I have a book.",
      status: "required",
      reason_zh: "I与have搭配。",
    },
    {
      index: 2,
      sentence_id: null,
      page: 2,
      original: "It is useful.",
      revised: "It is useful.",
      status: "keep",
      reason_zh: "表达简洁清楚，保留原句。",
    },
  ],
});
Deno.test("sentence feedback keeps page order, honest uncertainty, and unchanged good sentences", () => {
  assert(validSentenceReviews(photo(), { pages: 2, readable: true }));
  const wrong = photo();
  wrong.items.reverse();
  assertEquals(validSentenceReviews(wrong, { pages: 2, readable: true }), false);
  const changed = photo();
  changed.items[1].revised = "It is very useful.";
  assertEquals(validSentenceReviews(changed, { pages: 2, readable: true }), false);
  const uncertain = photo();
  uncertain.items[1].status = "uncertain";
  uncertain.items[1].revised = null;
  assertEquals(validSentenceReviews(uncertain, { pages: 2, readable: true }), false);
  uncertain.coverage = "partial";
  uncertain.notice_zh = "第二页一词不清，请结合原图核对。";
  assert(validSentenceReviews(uncertain, { pages: 2, readable: true }));
});
Deno.test("sentence feedback covers every typed target with exact unchanged source", () => {
  const sentences = segmentSentences("I has a book. It is useful.");
  const review = photo();
  review.items.forEach((x, i) => {
    x.page = null;
    x.sentence_id = sentences[i].id;
  });
  assert(validSentenceReviews(review, { sentences }));
  review.items[0].original = "I have a book.";
  assertEquals(validSentenceReviews(review, { sentences }), false);
  review.items.pop();
  assertEquals(validSentenceReviews(review, { sentences }), false);
});
Deno.test("sentence feedback rejects silent numeric edits and false complete empty reports", () => {
  const review = photo();
  review.items[0].original = "It reached 15%.";
  review.items[0].revised = "It reached 50%.";
  assertEquals(validSentenceReviews(review, { pages: 2, readable: true }), false);
  assertEquals(
    validSentenceReviews({ coverage: "complete", notice_zh: "", items: [] }, { pages: 1 }),
    false,
  );
  assert(
    validSentenceReviews({
      coverage: "unreadable",
      notice_zh: "照片没有可辨识正文，请补拍。",
      items: [],
    }, { pages: 1, readable: false }),
  );
});
