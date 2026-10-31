import { DeepSeekAdapter } from "../grading/provider.ts";
import { processNextJob, statusForJob, submitGrading } from "./service.ts";
import { JobStore } from "./store.ts";

function store(): JobStore {
  const url = Deno.env.get("SUPABASE_URL")?.replace(/\/$/, "");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("MISSING_SERVICE_CONFIG");
  return new JobStore(url, key);
}

function bearer(request: Request): string | null {
  const value = request.headers.get("Authorization");
  return value?.startsWith("Bearer ") ? value.slice(7) : null;
}

export async function authenticatedUserID(request: Request): Promise<string> {
  const token = bearer(request);
  if (!token) throw new Error("AUTH_REQUIRED");
  const id = await store().userID(token);
  if (!id) throw new Error("SESSION_EXPIRED");
  return id;
}

export async function handleSubmitGrading(request: Request): Promise<Response> {
  if (request.method !== "POST") return methodNotAllowed("POST");
  try {
    const id = await authenticatedUserID(request);
    const raw = await request.text();
    if (raw.length > 200_000) throw new Error("INVALID_BODY_SIZE");
    let input;
    try {
      input = JSON.parse(raw);
    } catch {
      throw new Error("INVALID_JSON");
    }
    const result = await submitGrading(
      store(),
      id,
      input,
      Deno.env.get("DEFAULT_GRADING_MODEL") ?? "deepseek-flash",
    );
    return Response.json(result, { status: 202 });
  } catch (error) {
    return errorResponse(error);
  }
}

export async function handleGradingStatus(request: Request): Promise<Response> {
  if (request.method !== "GET") return methodNotAllowed("GET");
  try {
    const id = await authenticatedUserID(request);
    const jobID = new URL(request.url).searchParams.get("jobId") ?? "";
    if (!jobID) throw new Error("INVALID_JOB_ID");
    return Response.json(await statusForJob(store(), id, jobID));
  } catch (error) {
    return errorResponse(error);
  }
}

export async function handleGradingWorker(request: Request): Promise<Response> {
  if (request.method !== "POST") return methodNotAllowed("POST");
  try {
    const expected = Deno.env.get("WRITERIGHT_WORKER_TOKEN");
    if (!expected) throw new Error("MISSING_WORKER_CONFIG");
    const supplied = request.headers.get("x-worker-key") ?? "";
    if (!(await sameSecret(supplied, expected))) throw new Error("WORKER_UNAUTHORIZED");
    const adapter = new DeepSeekAdapter({
      apiKey: Deno.env.get("DEEPSEEK_API_KEY") ?? "",
      baseURL: Deno.env.get("DEEPSEEK_BASE_URL") ?? "https://api.deepseek.com",
      model: Deno.env.get("DEFAULT_GRADING_MODEL") ?? "deepseek-flash",
    });
    const results: string[] = [];
    for (let index = 0; index < 1; index++) {
      const result = await processNextJob(store(), adapter);
      results.push(result);
      if (result === "empty") break;
    }
    return Response.json({ results });
  } catch (error) {
    return errorResponse(error);
  }
}

async function sameSecret(left: string, right: string): Promise<boolean> {
  if (!left || left.length !== right.length) return false;
  const [a, b] = await Promise.all(
    [left, right].map(async (value) =>
      new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)))
    ),
  );
  return a.every((value, index) => value === b[index]);
}

function methodNotAllowed(method: string): Response {
  return new Response(null, { status: 405, headers: { Allow: method } });
}

export function errorResponse(error: unknown): Response {
  const code = error instanceof Error && /^[A-Z][A-Z0-9_]{1,80}$/.test(error.message)
    ? error.message
    : "INTERNAL_ERROR";
  const status =
    code === "AUTH_REQUIRED" || code === "SESSION_EXPIRED" || code === "WORKER_UNAUTHORIZED"
      ? 401
      : code === "JOB_NOT_FOUND"
      ? 404
      : code === "RATE_LIMITED"
      ? 429
      : code === "TASK_OWNER_MISMATCH"
      ? 404
      : code.endsWith("CONFLICT")
      ? 409
      : code.startsWith("INVALID") || code.startsWith("MISSING_TASK")
      ? 400
      : 500;
  return Response.json({ error: { code, message: publicMessage(code) } }, { status });
}

function publicMessage(code: string): string {
  const messages: Record<string, string> = {
    AUTH_REQUIRED: "请先登录。",
    SESSION_EXPIRED: "登录已失效，请重新登录。",
    WORKER_UNAUTHORIZED: "未授权。",
    JOB_NOT_FOUND: "批改任务不存在。",
    SUBMISSION_CONFLICT: "同一稿件标识已对应其他内容。",
    IDEMPOTENCY_CONFLICT: "提交标识已用于另一份稿件。",
  };
  return messages[code] ?? "请求未能完成，请稍后重试。";
}
