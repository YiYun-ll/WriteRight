import { authenticatedUserID, errorResponse } from "../_shared/jobs/http.ts";
import { DeepSeekAdapter } from "../_shared/grading/provider.ts";
import { analyzePhotos } from "../_shared/photo-analysis.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response(null, { status: 405, headers: { Allow: "POST" } });
  }
  try {
    await authenticatedUserID(request);
    const raw = await request.text();
    if (raw.length > 16_100_000) throw new Error("INVALID_BODY_SIZE");
    let input;
    try {
      input = JSON.parse(raw);
    } catch {
      throw new Error("INVALID_JSON");
    }
    const adapter = new DeepSeekAdapter({
      apiKey: Deno.env.get("DEEPSEEK_API_KEY") ?? "",
      baseURL: Deno.env.get("DEEPSEEK_BASE_URL") ?? "https://api.deepseek.com",
      model: Deno.env.get("DEFAULT_GRADING_MODEL") ?? "deepseek-flash",
      timeoutMs: 90_000,
    });
    return Response.json(await analyzePhotos(input, adapter));
  } catch (error) {
    return errorResponse(error);
  }
});
