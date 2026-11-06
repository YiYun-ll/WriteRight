import { assert, assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";
import { makeContext } from "../../supabase/functions/_shared/grading/context.ts";
import {
  gradeTranslation,
  TRANSLATION_PROMPT_VERSION,
  TRANSLATION_RUBRIC_VERSION,
  type TranslationAssessment,
  translationTypoDeduction,
  validateTranslationReport,
} from "../../supabase/functions/_shared/grading/translation.ts";
import { gradePhotos } from "../../supabase/functions/_shared/grading/photo-grading.ts";
import { processNextJob, submitGrading } from "../../supabase/functions/_shared/jobs/service.ts";
import { submitPhotos } from "../../supabase/functions/_shared/jobs/photo-submission.ts";
import type {
  GradingReport,
  ModelAdapter,
} from "../../supabase/functions/_shared/grading/types.ts";
import type { PhotoContext } from "../../supabase/functions/_shared/grading/photo-types.ts";
import type { GradingJob, JobStore } from "../../supabase/functions/_shared/jobs/store.ts";

const english = "Reading opens doors. It helps us understand others.";
const student = "阅读打开大们。它帮助我们理解别人。";
async function context(confirmed = true) {
  return await makeContext({
    part: "T",
    originalText: student,
    task: {
      prompt: confirmed ? english : "",
      revision: 1,
      confirmed,
      requirements: [],
      referenceTranslation: "阅读开启新天地，让我们理解他人。",
    },
  });
}
function assessment(): TranslationAssessment {
  return {
    source_status: "readable",
    answer_status: "readable",
    coverage: "complete",
    notice_zh: "",
    overall_comment: "主干信息完整，注意中文用字。",
    accuracy: "两句核心意思准确。",
    completeness: "两句均已翻译。",
    fluency: "可以保留表达并修正错别字。",
    sentences: [
      {
        index: 1,
        source_page: null,
        answer_page: null,
        english: "Reading opens doors.",
        student: "阅读打开大们。",
        status: "reviewed",
        points: [{
          meaning: "阅读拓宽机会",
          max: 7,
          earned: 7,
          explanation: "比喻含义基本保留，非语义错字另计。",
        }],
        analysis: "doors是机会的比喻，不必逐字照抄参考译文。",
        structure: "Reading为主语，opens为谓语，doors为宾语。",
        revised: "阅读打开大门。",
      },
      {
        index: 2,
        source_page: null,
        answer_page: null,
        english: "It helps us understand others.",
        student: "它帮助我们理解别人。",
        status: "reviewed",
        points: [{
          meaning: "理解他人",
          max: 8,
          earned: 8,
          explanation: "指代与动作关系准确，保留。",
        }],
        analysis: "It指代阅读，help后可直接接动词原形。",
        structure: "help somebody do表示帮助某人做某事。",
        revised: "它帮助我们理解别人。",
      },
    ],
    typos: [{ original: "大们", corrected: "大门", reason: "不影响原意的中文错别字。" }],
    revised_translation: "阅读打开大门。它帮助我们理解别人。",
    changes: [{ text: "大门", reason_zh: "修正中文用字，保留原意。" }],
    top_issues: ["核对中文用字"],
    expressions: [
      { expression: "open doors", meaning: "带来机会", usage: "结合语境翻译比喻含义。" },
      {
        expression: "help somebody do",
        meaning: "帮助某人做某事",
        usage: "help后的宾语是动作执行者。",
      },
      {
        expression: "understand others",
        meaning: "理解他人",
        usage: "others作为代词，不必加名词。",
      },
    ],
    practice_advice: "重读中文译文，确认比喻含义和中文用字。",
  };
}
function adapter(
  a: unknown,
  capture?: (request: Parameters<ModelAdapter["complete"]>[0]) => void,
): ModelAdapter {
  return {
    complete: (request) => {
      capture?.(request);
      return Promise.resolve({
        content: JSON.stringify(a),
        model: "deepseek-flash",
        promptTokens: 10,
        completionTokens: 20,
        latencyMs: 1,
      });
    },
  };
}
function photoContext(task = true): PhotoContext {
  return {
    source: "photo_grading_v2",
    part: "T",
    originalText: "",
    wordCount: 0,
    contentHash: "synthetic",
    task: {
      prompt: "",
      revision: 1,
      confirmed: task,
      requirements: [],
      chartFacts: [],
      fingerprint: task ? "fingerprint" : null,
    },
    images: [
      ...(task ? [{ role: "task" as const, page: 1, path: "user/task.jpg", checksum: "a" }] : []),
      { role: "essay", page: 1, path: "user/answer.jpg", checksum: "b" },
    ],
    modelID: "deepseek-flash",
    promptVersion: TRANSLATION_PROMPT_VERSION,
    rubricVersion: TRANSLATION_RUBRIC_VERSION,
  };
}
Deno.test("translation owns independent rubric and deterministic quarter-point totals", async () => {
  const ctx = await context();
  assertEquals(ctx.rubricVersion, TRANSLATION_RUBRIC_VERSION);
  const { report } = await gradeTranslation(
    ctx,
    [],
    adapter(assessment(), (request) => {
      assert(request.system.includes("不重复"));
      assertEquals(JSON.parse(request.user).referenceTranslation, ctx.task.referenceTranslation);
      assertEquals(request.images, undefined);
    }),
  );
  assertEquals(report.score.value, 14.75);
  assertEquals(report.score.max, 15);
  assertEquals(report.schema_version, "3.0.0");
  assertEquals(report.translation_review?.sentences[0].student, "阅读打开大们。");
  assertEquals([0, 1, 2, 3, 4, 5, 6].map(translationTypoDeduction), [0, .25, .25, .5, .75, .75, 1]);
});
Deno.test("translation rejects wrong maximum, invented student text, uncovered sentences and false typo evidence", async () => {
  const ctx = await context();
  for (
    const mutate of [
      (a: TranslationAssessment) => {
        a.sentences[0].points[0].max = 8;
      },
      (a: TranslationAssessment) => {
        a.sentences[0].student = "阅读打开大门。";
      },
      (a: TranslationAssessment) => {
        a.sentences.pop();
      },
      (a: TranslationAssessment) => {
        a.typos[0].original = "不存在的错字";
      },
      (a: TranslationAssessment) => {
        a.sentences[0].points[0].earned = 7.1;
      },
      (a: TranslationAssessment) => {
        a.sentences[0].index = 2;
      },
    ]
  ) {
    const a = assessment();
    mutate(a);
    await assertRejects(
      () => gradeTranslation(ctx, [], adapter(a)),
      Error,
      "GRADING_VALIDATION_FAILED",
    );
  }
});
Deno.test("translation cannot change completed total, rewrite, or identity after evaluation", async () => {
  const ctx = await context();
  const { report } = await gradeTranslation(ctx, [], adapter(assessment()));
  for (
    const mutate of [
      (r: GradingReport) => {
        r.score.value = 15;
      },
      (r: GradingReport) => {
        r.rewrites.minimal = "伪造全文";
      },
      (r: GradingReport) => {
        r.model_id = "different";
      },
    ]
  ) {
    const copy = structuredClone(report);
    mutate(copy);
    assertThrows(() => validateTranslationReport(copy, ctx));
  }
});
Deno.test("missing source yields useful feedback without a total or guessed full revision", async () => {
  const a = assessment();
  a.source_status = "missing";
  a.coverage = "unreadable";
  a.notice_zh = "请补充英文原文。";
  a.sentences = [];
  a.typos = [];
  a.changes = [];
  a.revised_translation = "";
  const { report } = await gradeTranslation(await context(false), [], adapter(a));
  assertEquals(report.score.value, null);
  assertEquals(report.grading_mode, "language_only");
  a.source_status = "readable";
  const ctx = await context(false);
  await assertRejects(() => gradeTranslation(ctx, [], adapter(a)));
});
Deno.test("photo translation passes both image roles directly and preserves page references", async () => {
  const a = assessment();
  a.sentences.forEach((s) => {
    s.source_page = 1;
    s.answer_page = 1;
  });
  const { report } = await gradePhotos(
    photoContext(),
    ["task-image", "answer-image"],
    adapter(a, (request) => {
      assertEquals(request.images, ["task-image", "answer-image"]);
      assertEquals(JSON.parse(request.user).imageManifest, [{ role: "task", page: 1 }, {
        role: "essay",
        page: 1,
      }]);
    }),
  );
  assertEquals(report.score.value, 14.75);
  assertEquals(report.photo_review.sources.length, 2);
  a.sentences[0].answer_page = 2;
  await assertRejects(() => gradePhotos(photoContext(), ["task", "answer"], adapter(a)));
});
Deno.test("unreadable photo sentence blocks all scoring and typo charges", async () => {
  const a = assessment();
  a.coverage = "partial";
  a.notice_zh = "译文第1页有疑字，请补拍。";
  a.sentences[0].status = "uncertain";
  a.sentences[0].revised = "";
  a.sentences[0].points[0].earned = null;
  a.revised_translation = "";
  a.typos = [];
  a.changes = [];
  a.sentences.forEach((s) => {
    s.source_page = 1;
    s.answer_page = 1;
  });
  const { report } = await gradePhotos(photoContext(), ["task", "answer"], adapter(a));
  assertEquals(report.score.value, null);
  assertEquals(report.rewrites.minimal, "");
  a.sentences[0].points[0].earned = 0;
  await assertRejects(() => gradePhotos(photoContext(), ["task", "answer"], adapter(a)));
});
Deno.test("translation worker persists and revalidates the durable report", async () => {
  const ctx = await context();
  const job: GradingJob = {
    id: "job",
    submission_id: "submission",
    user_id: "user",
    status: "running",
    stage: "evaluate",
    attempts: 1,
    max_attempts: 3,
    idem_key: "idem",
    stage_results: {},
    error_code: null,
    context_json: ctx as unknown as Record<string, unknown>,
    lease_token: "lease",
  };
  let finished = false;
  const store = {
    claim: () => Promise.resolve(job),
    submission: () =>
      Promise.resolve({ user_id: "user", content_hash: ctx.contentHash, original_text: student }),
    saveStage: (_job: GradingJob, stage: string, value: unknown) => {
      job.stage_results[stage] = value;
      return Promise.resolve(job);
    },
    recordUsage: () => Promise.resolve(),
    finish: (_job: GradingJob, report: GradingReport) => {
      assertEquals(report.score.value, 14.75);
      finished = true;
      return Promise.resolve();
    },
    fail: () => {
      throw new Error("unexpected failure");
    },
  } as unknown as JobStore;
  assertEquals(await processNextJob(store, adapter(assessment())), "completed");
  assert(finished);
  assertEquals(
    await processNextJob(store, {
      complete: () => {
        throw new Error("must not bill twice");
      },
    }),
    "completed",
  );
});
Deno.test("translation text submission freezes reference in its job context", async () => {
  let captured = false;
  const store = {
    enqueue: (
      _u: string,
      _i: unknown,
      ctx: { part: string; task: { referenceTranslation: string } },
    ) => {
      assertEquals(ctx.part, "T");
      assertEquals(ctx.task.referenceTranslation, "参考数据");
      captured = true;
      return Promise.resolve({ id: "job" });
    },
    job: () => Promise.resolve({ id: "job", user_id: "user", status: "queued", stage: "evaluate" }),
  } as unknown as JobStore;
  await submitGrading(store, "user", {
    idemKey: "11111111-1111-4111-8111-111111111111",
    task: {
      id: "22222222-2222-4222-8222-222222222222",
      part: "T",
      prompt: english,
      referenceTranslation: "参考数据",
      requirements: [],
      revision: 1,
      confirmed: true,
    },
    submission: { id: "33333333-3333-4333-8333-333333333333", originalText: student },
  }, "deepseek-flash");
  assert(captured);
});
Deno.test("translation photo reference participates in idempotency snapshot", async () => {
  const input = {
    idemKey: "11111111-1111-4111-8111-111111111111",
    task: {
      id: "22222222-2222-4222-8222-222222222222",
      part: "T" as const,
      referenceTranslation: "参考甲",
    },
    submission: { id: "33333333-3333-4333-8333-333333333333" },
    taskImages: [],
    essayImages: ["data:image/jpeg;base64,/9j/2Q=="],
  };
  let saved: GradingJob | null = null;
  const store = {
    findJobByIdem: () => Promise.resolve(saved),
    checkPhotoQuota: () => Promise.resolve(),
    task: () => Promise.resolve(null),
    uploadPhoto: () => Promise.resolve(),
    removePhotos: () => Promise.resolve(),
    enqueuePhotos: (_u: string, _i: unknown, ctx: Record<string, unknown>) => {
      saved = {
        id: "job",
        user_id: "user",
        submission_id: input.submission.id,
        context_json: ctx,
        status: "queued",
      } as GradingJob;
      return Promise.resolve(saved);
    },
    job: () => Promise.resolve(saved),
  } as unknown as JobStore;
  await submitPhotos(store, "user", input, "deepseek-flash");
  input.task.referenceTranslation = "参考乙";
  await assertRejects(
    () => submitPhotos(store, "user", input, "deepseek-flash"),
    Error,
    "IDEMPOTENCY_CONFLICT",
  );
});

Deno.test("translation repairs malformed JSON once and rejects invalid five-sentence exercise allocation", async () => {
  const ctx = await context();
  let calls = 0;
  const model = adapter(assessment());
  const repaired = await gradeTranslation(ctx, [], {
    complete: (r) => {
      calls++;
      return calls === 1
        ? Promise.resolve({
          content: "{",
          model: "deepseek-flash",
          promptTokens: 3,
          completionTokens: 2,
          latencyMs: 1,
        })
        : model.complete(r);
    },
  });
  assertEquals(repaired.attempts.length, 2);
  const five = structuredClone(ctx);
  five.task.requirements = [{ id: "p1", text: "5句专项，每句3分" }];
  await assertRejects(() => gradeTranslation(five, [], model));
});

Deno.test("mixed translation grades either text source plus answer photos or source photos plus typed answer", async () => {
  for (const textRole of ["task", "essay"] as const) {
    const ctx = photoContext();
    ctx.promptVersion = "WRITERIGHT_TRANSLATION_MIXED_V1";
    ctx.textInputs = {
      task: textRole === "task" ? english : "",
      essay: textRole === "essay" ? student : "",
    };
    ctx.images = ctx.images.filter((i) => i.role !== textRole);
    const a = assessment();
    a.sentences.forEach((s) => {
      s.source_page = textRole === "task" ? null : 1;
      s.answer_page = textRole === "essay" ? null : 1;
    });
    const { report } = await gradePhotos(
      ctx,
      ["actual-image"],
      adapter(a, (r) => {
        assertEquals(JSON.parse(r.user).textInputs, ctx.textInputs);
        assertEquals(r.images, ["actual-image"]);
      }),
    );
    assertEquals(report.schema_version, "3.1.0");
    assertEquals(report.score.value, 14.75);
    assertEquals(report.photo_review.text_sources, ctx.textInputs);
    const changed = structuredClone(report);
    changed.photo_review.text_sources!.essay += "伪造";
    assertThrows(() => validateTranslationReport(changed, ctx));
    if (textRole === "essay") {
      a.sentences[0].student = "阅读打开大门。";
      await assertRejects(() => gradePhotos(ctx, ["image"], adapter(a)));
    }
  }
});

Deno.test("mixed submission freezes typed answer and rejects ambiguous role sources", async () => {
  const input = {
    idemKey: "11111111-1111-4111-8111-111111111111",
    task: { id: "22222222-2222-4222-8222-222222222222", part: "T" as const },
    submission: { id: "33333333-3333-4333-8333-333333333333" },
    taskImages: ["data:image/jpeg;base64,/9j/2Q=="],
    essayImages: [] as string[],
    textInputs: { task: "", essay: student },
  };
  let job: GradingJob | null = null;
  const store = {
    findJobByIdem: () => Promise.resolve(job),
    checkPhotoQuota: () => Promise.resolve(),
    task: () => Promise.resolve(null),
    uploadPhoto: () => Promise.resolve(),
    removePhotos: () => Promise.resolve(),
    enqueuePhotos: (_u: string, _i: unknown, ctx: Record<string, unknown>) => {
      assertEquals(ctx.textInputs, input.textInputs);
      job = {
        id: "job",
        user_id: "user",
        submission_id: input.submission.id,
        status: "queued",
        context_json: ctx,
      } as GradingJob;
      return Promise.resolve(job);
    },
    job: () => Promise.resolve(job),
  } as unknown as JobStore;
  await submitPhotos(store, "user", input, "deepseek-flash");
  input.textInputs.essay += "修改";
  await assertRejects(
    () => submitPhotos(store, "user", input, "deepseek-flash"),
    Error,
    "IDEMPOTENCY_CONFLICT",
  );
  input.textInputs.task = "同一侧同时传文字和图片";
  await assertRejects(
    () => submitPhotos(store, "user", input, "deepseek-flash"),
    Error,
    "INVALID_PHOTO_SUBMISSION",
  );
});
