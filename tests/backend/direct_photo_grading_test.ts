import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  gradePhotos,
  PHOTO_PROMPT_VERSION,
  PHOTO_RUBRIC_VERSION,
} from "../../supabase/functions/_shared/grading/photo-grading.ts";
import { submitPhotos } from "../../supabase/functions/_shared/jobs/photo-submission.ts";
import { deletePrivatePhotos } from "../../supabase/functions/_shared/delete-private-photos.ts";
import type { PhotoContext } from "../../supabase/functions/_shared/grading/photo-types.ts";
import type { ModelAdapter } from "../../supabase/functions/_shared/grading/types.ts";
import type { JobStore } from "../../supabase/functions/_shared/jobs/store.ts";
function context(part: "A" | "B" = "A", task = true): PhotoContext {
  return {
    source: "photo_grading_v2",
    part,
    originalText: "",
    wordCount: 0,
    contentHash: "hash",
    task: {
      prompt: "",
      revision: 1,
      confirmed: task,
      requirements: [],
      chartFacts: [],
      fingerprint: task ? "fingerprint" : null,
    },
    images: [
      ...(task ? [{ role: "task" as const, page: 1, path: "user/task.jpg", checksum: "x" }] : []),
      { role: "essay", page: 1, path: "user/essay.jpg", checksum: "y" },
    ],
    modelID: "deepseek-flash",
    promptVersion: PHOTO_PROMPT_VERSION,
    rubricVersion: PHOTO_RUBRIC_VERSION[part],
  };
}
function assessment() {
  return {
    task_status: "readable",
    essay_status: "readable",
    score: { value: 8, range: [7, 9], confidence: "medium" },
    estimated_word_count: 100,
    overall_comment: "目的明确，先复核主谓一致。",
    strengths: ["称呼清楚。"],
    dimensions: ["内容与任务", "语言", "组织"].map((name) => ({
      name,
      level: "良好",
      explanation: "有可确认的依据。",
    })),
    task_checks: [{ requirement: "邀请", status: "passed", reason: "已表达邀请。" }],
    corrections: [{
      page: 1,
      original: "I has",
      corrected: "I have",
      reason: "主语为I。",
      category: "主谓一致",
      severity: "required",
    }],
    uncertainties: [] as {
      role: string;
      page: number | null;
      message: string;
      blocks_scoring: boolean;
    }[],
    rewrites: {
      minimal: "I have a book.",
      enhanced: "I have a useful book.",
    },
    rewrite_study: {
      minimal: {
        translation_zh: "我有一本书。",
        highlights: [{ text: "I have a book.", reason_zh: "主语与谓语搭配准确。" }],
      },
      enhanced: {
        translation_zh: "我有一本有用的书。",
        highlights: [{ text: "I have a useful book.", reason_zh: "补充有依据的修饰。" }],
      },
    },
    sentence_reviews: {
      coverage: "complete",
      notice_zh: "",
      items: [{
        index: 1,
        sentence_id: null,
        page: 1,
        original: "I has a book.",
        revised: "I have a book.",
        status: "required",
        reason_zh: "I与have搭配。",
      }],
    },
    advanced_advice: [
      {
        focus: "sentence",
        observation_zh: "信息重心",
        before: "I has",
        after: "I have a book.",
        why_zh: "先把主干写清楚，再衔接说明。",
        practice_zh: "用一个从句补充用途。",
        page: 1,
      },
      {
        focus: "structure",
        observation_zh: "段落职责",
        before: "",
        after: "Introduce the purpose, explain the details, then close politely.",
        why_zh: "让读者容易找到信息。",
        practice_zh: "为三段各写一句作用。",
        page: null,
      },
    ],
    model_essay: {
      english: "Reading opens a window to new ideas.",
      translation_zh: "阅读为新想法打开一扇窗。",
      highlights: [{ text: "Reading opens a window to new ideas.", reason_zh: "信息主干清楚。" }],
      rationale_zh: "合成示范。",
    },
    review: {
      top_issues: ["主谓一致"],
      expressions: [],
      practice_advice: "复核一句的主语与谓语。",
    },
  };
}
function adapter(value: unknown, expectedImages = ["task-image", "essay-image"]): ModelAdapter {
  return {
    complete(request) {
      assert(request.system.includes("不做中间转录") || request.system.includes("禁止先逐字转录"));
      assert(request.system.includes("简单而准确"));
      assertEquals(request.images, expectedImages);
      return Promise.resolve({
        content: JSON.stringify(value),
        model: "fixture",
        promptTokens: 5,
        completionTokens: 10,
        latencyMs: 1,
      });
    },
  };
}
Deno.test("direct photo report grades both images in one request without a transcript", async () => {
  const result = await gradePhotos(context(), ["task-image", "essay-image"], adapter(assessment()));
  assertEquals(result.report.schema_version, "2.3.0");
  assertEquals(result.report.score.value, 8);
  assertEquals(result.report.corrections, []);
  assertEquals(result.report.photo_review.corrections[0].original, "I has");
  assertEquals(result.report.photo_review.sources, context().images);
  assertEquals(result.report.prompt_version, PHOTO_PROMPT_VERSION);
  assertEquals("original_text" in result.report, false);
});
Deno.test("missing question and unreadable image never receive a complete task score", async () => {
  const missing = await gradePhotos(
    context("A", false),
    ["essay-image"],
    adapter(assessment(), ["essay-image"]),
  );
  assertEquals(missing.report.score.value, null);
  assertEquals(missing.report.task_checks, []);
  assertEquals(missing.report.photo_review.task_status, "missing");
  const value = assessment();
  value.essay_status = "unclear";
  value.uncertainties = [{ role: "essay", page: 1, message: "请补拍。", blocks_scoring: true }];
  const unclear = await gradePhotos(context(), ["task-image", "essay-image"], adapter(value));
  assertEquals(unclear.report.score.value, null);
  assertEquals(unclear.report.rewrites.minimal, "");
  assertEquals(unclear.report.photo_review.corrections, []);
  assertEquals(unclear.report.photo_review.strengths, []);
});
Deno.test("rubrics stay independent and invalid scores or invented page references are rejected", async () => {
  for (const kind of ["score", "page", "extra"]) {
    const value = assessment();
    if (kind === "score") {
      value.score.value = 14;
      value.score.range = [13, 15];
    }
    if (kind === "page") value.corrections[0].page = 2;
    if (kind === "extra") Object.assign(value, { transcript: "must not be accepted" });
    await assertRejects(
      () => gradePhotos(context(), ["task-image", "essay-image"], adapter(value)),
      Error,
      "PHOTO_GRADING_VALIDATION_FAILED",
    );
  }
  const value = assessment();
  value.score.value = 14;
  value.score.range = [13, 15];
  const b = await gradePhotos(context("B"), ["task-image", "essay-image"], adapter(value));
  assertEquals(b.report.score.max, 15);
  assertEquals(b.report.score.band, "优秀");
});
Deno.test("invalid photo upload is rejected before any storage or queue call", async () => {
  await assertRejects(
    () =>
      submitPhotos({} as JobStore, "user", {
        idemKey: crypto.randomUUID(),
        task: { id: crypto.randomUUID(), part: "A" },
        submission: { id: crypto.randomUUID() },
        taskImages: [],
        essayImages: ["https://example.com/a.jpg"],
      }, "deepseek-flash"),
    Error,
    "INVALID_PHOTO_SUBMISSION",
  );
});
Deno.test("account deletion visits nested folders and all pages before deleting", async () => {
  const deleted: string[] = [];
  let rootPages = 0;
  const transport = ((url: string, init: RequestInit) => {
    const body = JSON.parse(init.body as string);
    if (init.method === "DELETE") {
      deleted.push(...body.prefixes);
      return Promise.resolve(Response.json({}));
    }
    assertEquals(deleted.length, 0);
    if (body.prefix === "owner/") {
      rootPages++;
      return Promise.resolve(
        Response.json(
          body.offset === 0
            ? Array.from({ length: 100 }, (_, i) => ({ id: String(i), name: `${i}.jpg` }))
            : [{ id: null, name: "old-scans" }],
        ),
      );
    }
    assertEquals(body.prefix, "owner/old-scans/");
    assert(url.includes("essay-images"));
    return Promise.resolve(Response.json([{ id: "nested", name: "page.jpg" }]));
  }) as typeof fetch;
  await deletePrivatePhotos("https://example.com", {}, "owner", transport);
  assertEquals(rootPages, 2);
  assertEquals(deleted.length, 101);
  assert(deleted.includes("owner/old-scans/page.jpg"));
});

Deno.test("legacy photo snapshots keep V2 while new snapshots require bilingual study", async () => {
  const old = context();
  old.promptVersion = "WRITERIGHT_DIRECT_VISION_V2";
  old.rubricVersion = "KY_EN2_A_PHOTO_V2";
  const legacyValue = assessment();
  delete (legacyValue as { rewrite_study?: unknown }).rewrite_study;
  delete (legacyValue as { advanced_advice?: unknown }).advanced_advice;
  delete (legacyValue as { model_essay?: unknown }).model_essay;
  delete (legacyValue as { sentence_reviews?: unknown }).sentence_reviews;
  const legacy = await gradePhotos(old, ["task-image", "essay-image"], adapter(legacyValue));
  assertEquals(legacy.report.schema_version, "2.0.0");
  assertEquals(legacy.report.rewrites.study, undefined);
  await assertRejects(
    () => gradePhotos(context(), ["task-image", "essay-image"], adapter(legacyValue)),
    Error,
    "PHOTO_GRADING_VALIDATION_FAILED",
  );
});

Deno.test("accepted V4 photo snapshots keep the frozen feedback contract", async () => {
  const old = context();
  old.promptVersion = "WRITERIGHT_DIRECT_VISION_V4";
  const value = assessment();
  delete (value as { sentence_reviews?: unknown }).sentence_reviews;
  const result = await gradePhotos(old, ["task-image", "essay-image"], adapter(value));
  assertEquals(result.report.schema_version, "2.2.0");
  assertEquals(result.report.sentence_reviews, undefined);
});

Deno.test("mixed A/B accepts text task plus photo essay and photo task plus exact typed essay", async () => {
  for (const part of ["A", "B"] as const) {
    for (const typedEssay of [false, true]) {
      const ctx = context(part);
      ctx.promptVersion = "WRITERIGHT_DIRECT_MIXED_V1";
      ctx.textInputs = {
        task: typedEssay ? "" : "Write an invitation.",
        essay: typedEssay ? "I has a book." : "",
      };
      ctx.wordCount = typedEssay ? 4 : 0;
      ctx.images = ctx.images.filter((i) => i.role === (typedEssay ? "task" : "essay"));
      const value = assessment();
      if (typedEssay) {
        value.corrections = [];
        const item = value.sentence_reviews.items[0] as {
          sentence_id: string | null;
          page: number | null;
        };
        item.sentence_id = "s1";
        item.page = null;
        value.advanced_advice.forEach((x) => x.page = null);
      }
      const { report } = await gradePhotos(ctx, ["only-image"], adapter(value, ["only-image"]));
      assertEquals(report.schema_version, "2.4.0");
      assertEquals(report.grading_mode, "full");
      assertEquals(report.score.max, part === "A" ? 10 : 15);
      assertEquals(report.photo_review.text_sources, ctx.textInputs);
      if (typedEssay) assertEquals(report.word_count, 4);
    }
  }
});
