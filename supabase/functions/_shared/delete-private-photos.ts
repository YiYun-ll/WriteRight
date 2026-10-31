/** Enumerate before deleting so pagination cannot skip objects as offsets move. */
export async function deletePrivatePhotos(
  baseURL: string,
  headers: Record<string, string>,
  userID: string,
  transport: typeof fetch = fetch,
) {
  const files: string[] = [];
  const pending = [`${userID}/`];
  const visited = new Set<string>();
  while (pending.length) {
    const prefix = pending.pop()!;
    if (visited.has(prefix)) continue;
    visited.add(prefix);
    for (let offset = 0;; offset += 100) {
      const result = await transport(`${baseURL}/storage/v1/object/list/essay-images`, {
        method: "POST",
        headers,
        body: JSON.stringify({
          prefix,
          limit: 100,
          offset,
          sortBy: { column: "name", order: "asc" },
        }),
      });
      if (!result.ok) throw new Error("DELETE_FAILED");
      const objects = await result.json() as { id: string | null; name: string }[];
      for (const object of objects) {
        if (
          !object.name || object.name.includes("/") || object.name === ".." || object.name === "."
        ) {
          throw new Error("DELETE_FAILED");
        }
        const path = prefix + object.name;
        if (object.id === null) pending.push(path + "/");
        else files.push(path);
      }
      if (objects.length < 100) break;
    }
  }
  for (let offset = 0; offset < files.length; offset += 100) {
    const removed = await transport(`${baseURL}/storage/v1/object/essay-images`, {
      method: "DELETE",
      headers,
      body: JSON.stringify({ prefixes: files.slice(offset, offset + 100) }),
    });
    if (!removed.ok) throw new Error("DELETE_FAILED");
  }
}
