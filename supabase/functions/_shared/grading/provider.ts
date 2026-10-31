import type { CompletionRequest, CompletionResult, ModelAdapter } from "./types.ts";

export class ProviderError extends Error {
  constructor(readonly code: string, readonly retryable: boolean) {
    super(code);
    this.name = "ProviderError";
  }
}

export class DeepSeekAdapter implements ModelAdapter {
  constructor(
    private readonly config: { apiKey: string; baseURL: string; model: string; timeoutMs?: number },
    private readonly request: typeof fetch = fetch,
  ) {
    const url = new URL(config.baseURL);
    if (url.protocol !== "https:" || url.username || url.password || url.search || url.hash) {
      throw new Error("INVALID_PROVIDER_URL");
    }
    if (!config.apiKey || !config.model) throw new Error("MISSING_PROVIDER_CONFIG");
  }

  async complete(input: CompletionRequest): Promise<CompletionResult> {
    const started = performance.now();
    let response: Response;
    try {
      response = await this.request(`${this.config.baseURL.replace(/\/$/, "")}/chat/completions`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${this.config.apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: this.config.model,
          messages: [{ role: "system", content: input.system }, {
            role: "user",
            content: input.images?.length
              ? [
                { type: "text", text: input.user },
                ...input.images.map((url) => ({ type: "image_url", image_url: { url } })),
              ]
              : input.user,
          }],
          response_format: { type: "json_object" },
          thinking: { type: "disabled" },
          stream: false,
          max_tokens: input.maxOutputTokens ?? 6500,
        }),
        signal: AbortSignal.timeout(this.config.timeoutMs ?? 45_000),
      });
    } catch {
      throw new ProviderError("PROVIDER_NETWORK_OR_TIMEOUT", true);
    }
    if (!response.ok) {
      await response.body?.cancel();
      throw new ProviderError(
        `PROVIDER_HTTP_${response.status}`,
        response.status === 429 || response.status >= 500,
      );
    }
    let data;
    try {
      data = await response.json();
    } catch {
      throw new ProviderError("PROVIDER_INVALID_ENVELOPE", true);
    }
    const choice = data?.choices?.[0];
    if (choice?.finish_reason !== "stop") throw new ProviderError("PROVIDER_INCOMPLETE", true);
    if (typeof choice?.message?.content !== "string" || !choice.message.content.trim()) {
      throw new ProviderError("PROVIDER_EMPTY_CONTENT", true);
    }
    if (choice.message.content.length > 160_000) {
      throw new ProviderError("PROVIDER_OUTPUT_LIMIT", false);
    }
    return {
      content: choice.message.content,
      model: typeof data.model === "string" ? data.model : this.config.model,
      promptTokens: Number.isInteger(data.usage?.prompt_tokens) ? data.usage.prompt_tokens : 0,
      completionTokens: Number.isInteger(data.usage?.completion_tokens)
        ? data.usage.completion_tokens
        : 0,
      latencyMs: Math.round(performance.now() - started),
    };
  }
}
