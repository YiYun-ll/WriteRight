/** Shared budget and lightweight signature check, not a full image decoder. */
export const MAX_INLINE_IMAGE_CHARACTERS = 2_000_000;

export function isInlineImage(value: unknown): value is string {
  if (typeof value !== "string" || value.length > MAX_INLINE_IMAGE_CHARACTERS) return false;
  const match = /^data:image\/(jpeg|png);base64,([A-Za-z0-9+/]+={0,2})$/.exec(value);
  if (!match || match[0] !== value || match[2].length % 4 !== 0) return false;
  let bytes: string;
  try {
    bytes = atob(match[2]);
    if (btoa(bytes) !== match[2]) return false;
  } catch {
    return false;
  }
  const signature = match[1] === "jpeg" ? [255, 216, 255] : [137, 80, 78, 71, 13, 10, 26, 10];
  return bytes.length >= signature.length &&
    signature.every((byte, i) => bytes.charCodeAt(i) === byte);
}
