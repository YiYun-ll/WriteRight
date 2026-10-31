import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { transcribeImage } from "../../supabase/functions/_shared/image-transcription.ts";
import type { ModelAdapter } from "../../supabase/functions/_shared/grading/types.ts";

const image =
  "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZlQAAAABJRU5ErkJggg==";
function adapter(content: string): ModelAdapter {
  return {
    complete: (input) => {
      assertEquals(input.images, [image]);
      assertEquals(input.system.includes("不纠错"), true);
      return Promise.resolve({
        content,
        model: "fixture",
        promptTokens: 0,
        completionTokens: 0,
        latencyMs: 0,
      });
    },
  };
}
Deno.test("image transcription preserves errors and exposes uncertainties without a score", async () => {
  const result = await transcribeImage(
    { image },
    adapter(JSON.stringify({ text: "I has a book. [待确认]", uncertain: ["年份不清"] })),
  );
  assertEquals(result.text, "I has a book. [待确认]");
  assertEquals(result.uncertain, ["年份不清"]);
  assertEquals(result.transcriberVersion, "WRITERIGHT_TRANSCRIPTION_V1");
});
Deno.test("image transcription rejects URL input, malformed output and unexpected score", async () => {
  await assertRejects(
    () => transcribeImage({ image: "https://example.com/private.jpg" }, adapter("{}")),
    Error,
    "INVALID_TRANSCRIPTION_IMAGE",
  );
  for (
    const content of [
      "bad JSON",
      '{"text":"","uncertain":[]}',
      '{"text":"hello","uncertain":[],"score":15}',
    ]
  ) {
    await assertRejects(
      () => transcribeImage({ image }, adapter(content)),
      Error,
      "TRANSCRIPTION_INVALID_RESPONSE",
    );
  }
});
