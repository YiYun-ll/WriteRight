import { authenticatedUserID, errorResponse } from "../_shared/jobs/http.ts";
import { JobStore } from "../_shared/jobs/store.ts";
import { submitPhotos } from "../_shared/jobs/photo-submission.ts";
Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response(null, { status: 405, headers: { Allow: "POST" } });
  }
  try {
    const userID = await authenticatedUserID(request);
    const raw = await request.text();
    if (raw.length > 16_100_000) throw new Error("INVALID_BODY_SIZE");
    let input;
    try {
      input = JSON.parse(raw);
    } catch {
      throw new Error("INVALID_JSON");
    }
    const url = Deno.env.get("SUPABASE_URL"), key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !key) throw new Error("MISSING_SERVICE_CONFIG");
    return Response.json(
      await submitPhotos(
        new JobStore(url, key),
        userID,
        input,
        Deno.env.get("DEFAULT_GRADING_MODEL") ?? "deepseek-flash",
      ),
      { status: 202 },
    );
  } catch (error) {
    return errorResponse(error);
  }
});
