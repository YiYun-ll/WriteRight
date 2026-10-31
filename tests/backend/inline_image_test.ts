import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  isInlineImage,
  MAX_INLINE_IMAGE_CHARACTERS,
} from "../../supabase/functions/_shared/inline-image.ts";
import { transcribeImage } from "../../supabase/functions/_shared/image-transcription.ts";
import { parseTask } from "../../supabase/functions/_shared/task-parser.ts";
import type { ModelAdapter } from "../../supabase/functions/_shared/grading/types.ts";

const png =
  "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZlQAAAABJRU5ErkJggg==";
Deno.test("inline image rejects malformed base64, mismatched MIME and non-images", () => {
  assertEquals(isInlineImage(png), true);
  for (
    const input of [
      null,
      {},
      "https://example.com/a.jpg",
      "data:image/jpeg;base64,YQ==",
      "data:image/jpeg;base64,====",
      png.replace("png", "jpeg"),
      png + " ",
      png + "\n",
      png + "\r\n",
      png.slice(0, -1),
    ]
  ) {
    assertEquals(isInlineImage(input), false);
  }
});
Deno.test("inline image encoded budget includes the complete data URL", () => {
  assertEquals(
    isInlineImage("data:image/jpeg;base64,/9j/" + "A".repeat(MAX_INLINE_IMAGE_CHARACTERS)),
    false,
  );
});
Deno.test("invalid images never reach the paid provider in either image endpoint", async () => {
  let calls = 0;
  const adapter: ModelAdapter = {
    complete() {
      calls++;
      throw new Error("UNEXPECTED_MODEL_CALL");
    },
  };
  await assertRejects(
    () => transcribeImage({ image: "data:image/jpeg;base64,YQ==" }, adapter),
    Error,
    "INVALID_TRANSCRIPTION_IMAGE",
  );
  await assertRejects(
    () => parseTask({ part: "B", text: "", images: ["data:image/jpeg;base64,YQ=="] }, adapter),
    Error,
    "INVALID_PARSE_INPUT",
  );
  assertEquals(calls, 0);
});
