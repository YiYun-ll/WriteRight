import {
  MIXED_TRANSLATION_PROMPT_VERSION,
  TRANSLATION_PROMPT_VERSION,
  TRANSLATION_RUBRIC_VERSION,
} from "../grading/translation.ts";
import { countWords } from "../grading/context.ts";
import { isInlineImage } from "../inline-image.ts";
import {
  MIXED_PHOTO_PROMPT_VERSION,
  PHOTO_PROMPT_VERSION,
  PHOTO_RUBRIC_VERSION,
} from "../grading/photo-grading.ts";
import type { PhotoContext, PhotoSource } from "../grading/photo-types.ts";
import type { Part } from "../grading/types.ts";
import type { JobStore } from "./store.ts";
import { statusForJob } from "./service.ts";
export interface PhotoSubmissionInput {
  idemKey: string;
  task: { id: string; part: Part; referenceTranslation?: string };
  submission: { id: string };
  taskImages: string[];
  essayImages: string[];
  textInputs?: { task: string; essay: string };
}
export async function photoHash(text: string | Uint8Array): Promise<string> {
  const bytes = typeof text === "string" ? new TextEncoder().encode(text) : text;
  const hash = await crypto.subtle.digest("SHA-256", new Uint8Array(bytes).buffer);
  return Array.from(new Uint8Array(hash), (byte) => byte.toString(16).padStart(2, "0")).join("");
}
export function imageBytes(image: string): Uint8Array {
  return Uint8Array.from(atob(image.slice(image.indexOf(",") + 1)), (value) => value.charCodeAt(0));
}
export async function submitPhotos(
  store: JobStore,
  userID: string,
  input: PhotoSubmissionInput,
  modelID: string,
) {
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (
    !input || !uuid.test(input.idemKey ?? "") || !uuid.test(input.task?.id ?? "") ||
    !uuid.test(input.submission?.id ?? "") || !["A", "B", "T"].includes(input.task?.part) ||
    (input.task?.referenceTranslation !== undefined &&
      (typeof input.task.referenceTranslation !== "string" ||
        input.task.referenceTranslation.length > 20000)) ||
    !Array.isArray(input.taskImages) || input.taskImages.length > 4 ||
    !Array.isArray(input.essayImages) ||
    input.essayImages.length <
      ((typeof input.textInputs?.essay === "string" && input.textInputs.essay.trim()) ? 0 : 1) ||
    input.essayImages.length > 4 ||
    [...input.taskImages, ...input.essayImages].some((image) => !isInlineImage(image))
  ) throw new Error("INVALID_PHOTO_SUBMISSION");
  const text = input.textInputs;
  if (
    text !== undefined &&
    (!text || typeof text.task !== "string" || typeof text.essay !== "string" ||
      text.task.length > 20000 || text.essay.length > 30000 ||
      (!text.task.trim() && !text.essay.trim()) ||
      (text.task.trim() && input.taskImages.length > 0) ||
      (text.essay.trim() && input.essayImages.length > 0) ||
      input.taskImages.length + input.essayImages.length < 1)
  ) throw new Error("INVALID_PHOTO_SUBMISSION");
  const roleImages = [
    ...input.taskImages.map((image, index) => ({ image, role: "task" as const, page: index + 1 })),
    ...input.essayImages.map((image, index) => ({
      image,
      role: "essay" as const,
      page: index + 1,
    })),
  ];
  const batch = crypto.randomUUID();
  const sources: PhotoSource[] = [];
  for (const item of roleImages) {
    const checksum = await photoHash(imageBytes(item.image));
    const extension = item.image.startsWith("data:image/png") ? "png" : "jpg";
    sources.push({
      role: item.role,
      page: item.page,
      checksum,
      path: `${userID}/${batch}-${item.role}-${item.page}-${checksum}.${extension}`,
    });
  }
  const contentHash = await photoHash(
    [
      input.task.part,
      ...(input.task.referenceTranslation ? [input.task.referenceTranslation] : []),
      ...(text ? [`task-text:${text.task}`, `essay-text:${text.essay}`] : []),
      ...sources.map((item) => `${item.role}:${item.page}:${item.checksum}`),
    ].join(
      "\n",
    ),
  );
  const existing = await store.findJobByIdem(userID, input.idemKey);
  if (
    existing &&
    (existing.context_json.source !== "photo_grading_v2" ||
      existing.context_json.contentHash !== contentHash ||
      existing.submission_id !== input.submission.id.toLowerCase())
  ) throw new Error("IDEMPOTENCY_CONFLICT");
  if (existing && existing.status !== "failed") {
    return await statusForJob(store, userID, existing.id);
  }
  if (!existing) {
    await store.checkPhotoQuota(userID);
    const task = await store.task(input.task.id);
    if (task && task.user_id !== userID) throw new Error("TASK_OWNER_MISMATCH");
  }
  const context: PhotoContext = existing ? existing.context_json as unknown as PhotoContext : {
    source: "photo_grading_v2",
    part: input.task.part,
    originalText: "",
    wordCount: text?.essay ? countWords(text.essay) : 0,
    ...(text ? { textInputs: text } : {}),
    contentHash,
    task: {
      ...(input.task.referenceTranslation !== undefined
        ? { referenceTranslation: input.task.referenceTranslation }
        : {}),
      prompt: "",
      revision: 1,
      confirmed: input.taskImages.length > 0 || !!text?.task.trim(),
      requirements: [],
      chartFacts: [],
      fingerprint: input.taskImages.length
        ? await photoHash(
          [
            input.task.part,
            ...sources.filter((item) => item.role === "task").map((item) => item.checksum),
          ].join("\n"),
        )
        : text?.task.trim()
        ? await photoHash([input.task.part, `task-text:${text.task}`].join("\n"))
        : null,
    },
    images: sources,
    modelID,
    promptVersion: input.task.part === "T"
      ? (text ? MIXED_TRANSLATION_PROMPT_VERSION : TRANSLATION_PROMPT_VERSION)
      : (text ? MIXED_PHOTO_PROMPT_VERSION : PHOTO_PROMPT_VERSION),
    rubricVersion: input.task.part === "T"
      ? TRANSLATION_RUBRIC_VERSION
      : PHOTO_RUBRIC_VERSION[input.task.part],
  };
  const uploaded: string[] = [];
  let enqueueAttempted = false;
  try {
    if (!existing) {
      for (let index = 0; index < sources.length; index++) {
        await store.uploadPhoto(sources[index].path, roleImages[index].image);
        uploaded.push(sources[index].path);
      }
    }
    enqueueAttempted = true;
    const job = await store.enqueuePhotos(userID, {
      idemKey: input.idemKey,
      task: {
        id: input.task.id,
        part: input.task.part,
        title: `${
          input.task.part === "A" ? "小作文" : input.task.part === "T" ? "翻译" : "大作文"
        } · 照片练习`,
        ...(input.task.referenceTranslation !== undefined
          ? { referenceTranslation: input.task.referenceTranslation }
          : {}),
        prompt: "",
        requirements: [],
        revision: 1,
        confirmed: input.taskImages.length > 0 || !!text?.task.trim(),
      },
      submission: { id: input.submission.id, originalText: "" },
    }, context);
    const kept = new Set(
      (job.context_json as unknown as PhotoContext).images.map((item) => item.path),
    );
    const unused = uploaded.filter((path) => !kept.has(path));
    if (unused.length) await store.removePhotos(unused);
    return await statusForJob(store, userID, job.id);
  } catch (error) {
    // A lost enqueue response may have committed. Never remove possibly referenced snapshots.
    if (!enqueueAttempted && uploaded.length) await store.removePhotos(uploaded).catch(() => {});
    throw error;
  }
}
