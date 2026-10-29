/** Public health probe. Never return secrets, credentials, or user data here. */
export function handleHealth(request: Request): Response {
  if (request.method !== "GET") {
    return new Response(null, { status: 405, headers: { Allow: "GET" } });
  }
  return Response.json({ service: "essaypilot", status: "ok", schemaVersion: 1 });
}
