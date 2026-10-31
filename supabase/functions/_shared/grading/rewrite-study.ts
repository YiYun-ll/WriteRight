import type { RewriteStudy } from "./types.ts";

/** Exact quote anchors are data, never markup; UTF-16 matches the native renderer. */
export function validRewriteStudy(
  rewrites: { minimal: string; enhanced: string; study?: RewriteStudy },
  required = true,
): boolean {
  if (!rewrites.study) return !required;
  for (const version of ["minimal", "enhanced"] as const) {
    const text = rewrites[version];
    const item = rewrites.study[version];
    if (!item || !Array.isArray(item.highlights) || item.highlights.length > 3) return false;
    if (!text.trim()) {
      if (item.translation_zh.trim() || item.highlights.length) return false;
      continue;
    }
    if (!/[\p{Script=Han}]/u.test(item.translation_zh) || !item.highlights.length) return false;
    const ranges: { start: number; end: number }[] = [];
    for (const highlight of item.highlights) {
      const quote = highlight.text;
      if (!quote.trim() || !highlight.reason_zh.trim()) return false;
      const start = text.indexOf(quote);
      if (start < 0 || text.indexOf(quote, start + 1) !== -1) return false;
      const end = start + quote.length;
      if (ranges.some((range) => start < range.end && end > range.start)) return false;
      ranges.push({ start, end });
    }
  }
  return true;
}
