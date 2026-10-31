import { deletePrivatePhotos } from "../_shared/delete-private-photos.ts";
import { authenticatedUserID, errorResponse } from "../_shared/jobs/http.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response(null, { status: 405, headers: { Allow: "POST" } });
  }
  try {
    const id = await authenticatedUserID(request);
    const url = Deno.env.get("SUPABASE_URL")?.replace(/\/$/, "");
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !key) throw new Error("MISSING_SERVICE_CONFIG");
    const headers = {
      apikey: key,
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    };
    await deletePrivatePhotos(url, headers, id);
    const deleted = await fetch(`${url}/auth/v1/admin/users/${id}`, { method: "DELETE", headers });
    if (!deleted.ok && deleted.status !== 404) throw new Error("DELETE_FAILED");
    return Response.json({ deleted: true });
  } catch (error) {
    return errorResponse(error);
  }
});
