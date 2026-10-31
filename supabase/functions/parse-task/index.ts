import { authenticatedUserID, errorResponse } from "../_shared/jobs/http.ts";
import { DeepSeekAdapter } from "../_shared/grading/provider.ts";
import { parseTask } from "../_shared/task-parser.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response(null, { status: 405, headers: { Allow: "POST" } });
  }
  try {
    await authenticatedUserID(request);
    const raw = await request.text();
    if (raw.length > 8_100_000) throw new Error("INVALID_BODY_SIZE");
    let input;
    try {
      input = JSON.parse(raw);
    } catch {
      throw new Error("INVALID_JSON");
    }
    const adapter = new DeepSeekAdapter({
      apiKey: Deno.env.get("DEEPSEEK_API_KEY") ?? "",
      baseURL: Deno.env.get("DEEPSEEK_BASE_URL") ?? "https://api.deepseek.com",
      model: Deno.env.get("DEFAULT_PARSER_MODEL") ?? "deepseek-flash",
    });
    return Response.json(await parseTask(input, adapter));
  } catch (error) {
    return errorResponse(error);
  }
});
