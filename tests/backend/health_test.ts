import { handleHealth } from "../../supabase/functions/_shared/health.ts";

Deno.test("health probe returns a minimal JSON response without credentials", async () => {
  const response = handleHealth(new Request("http://localhost/health"));
  if (response.status !== 200) throw new Error("Health probe must respond successfully");
  if (!response.headers.get("content-type")?.includes("application/json")) {
    throw new Error("Health probe must be JSON");
  }
  const body = await response.json();
  if (body.status !== "ok" || body.service !== "essaypilot") {
    throw new Error("Unexpected health response");
  }
  if (Object.keys(body).sort().join(",") !== "schemaVersion,service,status") {
    throw new Error("Health probe exposed unexpected fields");
  }
});

Deno.test("health probe rejects writes", () => {
  const response = handleHealth(new Request("http://localhost/health", { method: "POST" }));
  if (response.status !== 405 || response.headers.get("allow") !== "GET") {
    throw new Error("Health probe must reject writes and advertise GET");
  }
});
