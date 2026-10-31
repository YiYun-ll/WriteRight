import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { analyzePhotos } from "../../supabase/functions/_shared/photo-analysis.ts";
import type { ModelAdapter } from "../../supabase/functions/_shared/grading/types.ts";
const image =
  "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZlQAAAABJRU5ErkJggg==";
const parsed = {
  part: "B",
  prompt_type: "chart",
  genre: "essay",
  required_points: [{ id: "x", description: "Describe the chart." }],
  chart_facts: [{
    id: "x",
    label: "visits",
    period: "2015",
    value: "781.1",
    unit: "million",
    confidence: "high",
    confirmed_by_user: true,
  }],
  word_requirement: { target: 150, min: null, max: null, source: "default_guideline" },
  uncertain_fields: [],
};
function fixture(value: unknown, count: number): ModelAdapter {
  return {
    complete: (request) => {
      assertEquals(request.images?.length, count);
      assertEquals(request.system.includes("不纠错"), true);
      return Promise.resolve({
        content: JSON.stringify(value),
        model: "fixture",
        promptTokens: 0,
        completionTokens: 0,
        latencyMs: 0,
      });
    },
  };
}
Deno.test("photo analysis sends both roles in order and keeps uncorrected text and uncertainty", async () => {
  const value = {
    task: { prompt: "Write about the chart.", parsed },
    essayPages: [{ text: "I has a book. [待确认]", uncertain: ["年份"] }, {
      text: "It are useful.",
      uncertain: [],
    }],
  };
  const response = await analyzePhotos({
    part: "B",
    taskImages: [image],
    essayImages: [image, image],
  }, fixture(value, 3));
  assertEquals(response.essayPages.map((p) => p.text), value.essayPages.map((p) => p.text));
  assertEquals(response.task?.parsed.chart_facts[0].confirmed_by_user, false);
  assertEquals(response.task?.parsed.required_points[0].id, "p1");
  assertEquals(response.analysisVersion, "WRITERIGHT_PHOTOS_V1");
});
Deno.test("photo analysis rejects fabricated task without task photos and page loss", async () => {
  for (
    const value of [
      {
        task: { prompt: "invented", parsed },
        essayPages: [{ text: "I has a book.", uncertain: [] }],
      },
      { task: null, essayPages: [{ text: " ", uncertain: [] }] },
      { task: null, essayPages: [{ text: "hello", uncertain: [] }], score: 15 },
      { task: null, essayPages: [] },
    ]
  ) {
    await assertRejects(
      () => analyzePhotos({ part: "B", taskImages: [], essayImages: [image] }, fixture(value, 1)),
      Error,
      "PHOTO_ANALYSIS_INVALID_RESPONSE",
    );
  }
  const result = await analyzePhotos(
    { part: "B", taskImages: [], essayImages: [image] },
    fixture({ task: null, essayPages: [{ text: "I has a book.", uncertain: [] }] }, 1),
  );
  assertEquals(result.task, null);
});
Deno.test("invalid photo input never invokes the model", async () => {
  let called = false;
  const adapter: ModelAdapter = {
    complete: () => {
      called = true;
      throw new Error("unexpected");
    },
  };
  for (
    const input of [
      { part: "A" as const, taskImages: [], essayImages: [] },
      { part: "A" as const, taskImages: ["https://example.com/image.jpg"], essayImages: [image] },
      { part: "A" as const, taskImages: [], essayImages: Array(5).fill(image) },
    ]
  ) await assertRejects(() => analyzePhotos(input, adapter), Error, "INVALID_PHOTO_INPUT");
  assertEquals(called, false);
});
Deno.test("photo analysis rejects type mismatch and invalid word range", async () => {
  for (
    const task of [{ ...parsed, part: "A" }, {
      ...parsed,
      word_requirement: { target: 100, min: 150, max: null, source: "question" },
    }]
  ) {
    await assertRejects(
      () =>
        analyzePhotos(
          { part: "B", taskImages: [image], essayImages: [image] },
          fixture({
            task: { prompt: "Write about the chart", parsed: task },
            essayPages: [{ text: "I has a book.", uncertain: [] }],
          }, 2),
        ),
      Error,
      "PHOTO_ANALYSIS_INVALID_RESPONSE",
    );
  }
});
