export interface GradingJob {
  id: string;
  user_id: string;
  submission_id: string;
  status: "queued" | "running" | "completed" | "failed";
  stage: "evaluate" | "correct" | "rewrite" | "validate" | "done";
  attempts: number;
  max_attempts: number;
  idem_key: string;
  stage_results: Record<string, unknown>;
  error_code: string | null;
  context_json: Record<string, unknown>;
  lease_token: string;
}

export class StoreError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = "StoreError";
  }
}

export class JobStore {
  constructor(
    private readonly baseURL: string,
    private readonly serviceKey: string,
    private readonly fetcher: typeof fetch = fetch,
  ) {}

  async userID(accessToken: string): Promise<string | null> {
    const response = await this.fetcher(`${this.baseURL}/auth/v1/user`, {
      headers: this.headers({ Authorization: `Bearer ${accessToken}` }),
    });
    if (response.status === 401 || response.status === 403) {
      await response.body?.cancel();
      return null;
    }
    const data = await this.data<{ id?: string }>(response);
    return typeof data.id === "string" ? data.id : null;
  }

  async findJobByIdem(userID: string, key: string): Promise<GradingJob | null> {
    return await this.one(
      `/grading_jobs?user_id=eq.${encode(userID)}&idem_key=eq.${encode(key)}&select=*`,
    );
  }

  async job(id: string): Promise<GradingJob | null> {
    return await this.one(`/grading_jobs?id=eq.${encode(id)}&select=*`);
  }

  async enqueue(userID: string, input: unknown, context: unknown): Promise<GradingJob> {
    const rows = await this.request<GradingJob[]>("/rpc/enqueue_grading", {
      method: "POST",
      body: JSON.stringify({ p_user_id: userID, p_input: input, p_context: context }),
    });
    if (!rows[0]) throw new StoreError("ENQUEUE_FAILED");
    return rows[0];
  }

  async enqueuePhotos(userID: string, input: unknown, context: unknown): Promise<GradingJob> {
    const rows = await this.request<GradingJob[]>("/rpc/enqueue_photo_grading", {
      method: "POST",
      body: JSON.stringify({ p_user_id: userID, p_input: input, p_context: context }),
    });
    if (!rows[0]) throw new StoreError("ENQUEUE_FAILED");
    return rows[0];
  }

  async checkPhotoQuota(userID: string): Promise<void> {
    const since = new Date(Date.now() - 600_000).toISOString();
    const rows = await this.request<unknown[]>(
      `/grading_jobs?user_id=eq.${encode(userID)}&created_at=gt.${
        encode(since)
      }&select=id&limit=10`,
    );
    if (rows.length >= 10) throw new StoreError("RATE_LIMITED");
  }

  async uploadPhoto(path: string, image: string): Promise<void> {
    const type = image.startsWith("data:image/png") ? "image/png" : "image/jpeg";
    const body = Uint8Array.from(
      atob(image.slice(image.indexOf(",") + 1)),
      (value) => value.charCodeAt(0),
    );
    const response = await this.fetcher(`${this.baseURL}/storage/v1/object/essay-images/${path}`, {
      method: "POST",
      headers: this.headers({ "Content-Type": type, "x-upsert": "false" }),
      body,
    });
    await this.data(response);
  }

  async removePhotos(paths: string[]): Promise<void> {
    if (!paths.length) return;
    await this.data(
      await this.fetcher(`${this.baseURL}/storage/v1/object/essay-images`, {
        method: "DELETE",
        headers: this.headers(),
        body: JSON.stringify({ prefixes: paths }),
      }),
    );
  }

  async photo(path: string, checksum: string, userID: string): Promise<string> {
    if (!path.startsWith(userID + "/") || path.includes("..")) {
      throw new StoreError("PHOTO_OWNER_MISMATCH");
    }
    const response = await this.fetcher(`${this.baseURL}/storage/v1/object/essay-images/${path}`, {
      headers: this.headers(),
    });
    if (!response.ok) {
      await response.body?.cancel();
      throw new StoreError("PHOTO_IMAGE_UNAVAILABLE");
    }
    const data = new Uint8Array(await response.arrayBuffer());
    if (data.length > 1_500_000) throw new StoreError("PHOTO_INTEGRITY_FAILED");
    const hash = Array.from(
      new Uint8Array(await crypto.subtle.digest("SHA-256", data)),
      (byte) => byte.toString(16).padStart(2, "0"),
    ).join("");
    if (hash !== checksum) throw new StoreError("PHOTO_INTEGRITY_FAILED");
    let binary = "";
    for (let index = 0; index < data.length; index += 32768) {
      binary += String.fromCharCode(...data.subarray(index, index + 32768));
    }
    return `data:${path.endsWith(".png") ? "image/png" : "image/jpeg"};base64,${btoa(binary)}`;
  }

  async submission(id: string): Promise<Record<string, unknown> | null> {
    return await this.one(`/essay_submissions?id=eq.${encode(id)}&select=*`);
  }

  async task(id: string): Promise<Record<string, unknown> | null> {
    return await this.one(`/essay_tasks?id=eq.${encode(id)}&select=*`);
  }

  async claim(): Promise<GradingJob | null> {
    const rows = await this.request<GradingJob[]>("/rpc/claim_grading_job", {
      method: "POST",
      body: "{}",
    });
    return rows[0] ?? null;
  }

  async saveStage(
    job: GradingJob,
    stage: GradingJob["stage"],
    value: unknown,
    nextStage: GradingJob["stage"],
  ): Promise<GradingJob> {
    const rows = await this.request<GradingJob[]>("/rpc/advance_grading_job", {
      method: "POST",
      body: JSON.stringify({
        p_job_id: job.id,
        p_lease_token: job.lease_token,
        p_stage: stage,
        p_value: value,
        p_next: nextStage,
      }),
    });
    if (!rows[0]) throw new StoreError("LEASE_LOST");
    return rows[0];
  }

  async finish(job: GradingJob, report: unknown, sentences: unknown): Promise<void> {
    await this.request("/rpc/finish_grading_job", {
      method: "POST",
      body: JSON.stringify({
        p_job_id: job.id,
        p_lease_token: job.lease_token,
        p_report: report,
        p_sentences: sentences,
      }),
    });
  }

  async fail(job: GradingJob, code: string, retryable: boolean): Promise<void> {
    await this.request("/rpc/fail_grading_job", {
      method: "POST",
      body: JSON.stringify({
        p_job_id: job.id,
        p_lease_token: job.lease_token,
        p_code: code,
        p_retryable: retryable,
      }),
    });
  }

  async report(jobID: string): Promise<Record<string, unknown> | null> {
    return await this.one(`/grading_reports?job_id=eq.${encode(jobID)}&select=*`);
  }

  async recordUsage(
    job: GradingJob,
    attempts: Array<Record<string, unknown>>,
    modelID: string,
  ): Promise<void> {
    if (!attempts.length) return;
    await this.request("/grading_usage?on_conflict=job_id,attempt_key", {
      headers: { Prefer: "resolution=ignore-duplicates,return=minimal" },
      method: "POST",
      body: JSON.stringify(attempts.map((attempt, index) => ({
        attempt_key: `${attempt.usageKey ?? job.lease_token}:${index + 1}`,
        id: crypto.randomUUID(),
        user_id: job.user_id,
        job_id: job.id,
        model_id: typeof attempt.providerModel === "string" ? attempt.providerModel : modelID,
        prompt_tokens: attempt.promptTokens ?? 0,
        completion_tokens: attempt.completionTokens ?? 0,
      }))),
    });
  }

  private one<T>(path: string): Promise<T | null> {
    return this.request<T[]>(path).then((rows) => rows[0] ?? null);
  }

  private headers(extra: Record<string, string> = {}): Record<string, string> {
    return {
      apikey: this.serviceKey,
      Authorization: `Bearer ${this.serviceKey}`,
      "Content-Type": "application/json",
      ...extra,
    };
  }

  private async request<T>(path: string, init: RequestInit = {}): Promise<T> {
    const response = await this.fetcher(`${this.baseURL}/rest/v1${path}`, {
      ...init,
      headers: this.headers(init.headers as Record<string, string> | undefined),
    });
    return await this.data<T>(response);
  }

  private async data<T>(response: Response): Promise<T> {
    if (!response.ok) {
      const payload = await response.json().catch(() => ({}));
      const safe = new Set([
        "TASK_OWNER_MISMATCH",
        "SUBMISSION_CONFLICT",
        "IDEMPOTENCY_CONFLICT",
        "LEASE_LOST",
        "RATE_LIMITED",
        "IMMUTABLE_JOB_CONTEXT",
      ]);
      throw new StoreError(
        safe.has(payload?.message) ? payload.message : `STORE_HTTP_${response.status}`,
      );
    }
    if (response.status === 204) return undefined as T;
    const text = await response.text();
    return (text ? JSON.parse(text) : undefined) as T;
  }
}

function encode(value: string): string {
  return encodeURIComponent(value);
}
