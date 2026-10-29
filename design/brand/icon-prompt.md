# WriteRight · 当前品牌资源

日期：2026-10-29。用户选择 A「一笔写对」，并确认采用 Times New Roman 风格衬线字标及直接替换。

生成方式：内置 image_gen；品牌展示稿、透明横版 Logo、App 图标均由编辑模式从已确认稿派生。没有使用 CLI/API fallback。

## 当前文件

- `writeright-identity-a-serif.png`：用户确认的品牌展示稿。
- `writeright-logo-horizontal.png`：透明背景横版 Logo（PNG，非矢量文件）。
- `writeright-icon-master.png`：独立 App 图标母图，橙色不透明底与米白 W/校对勾符号。
- `../../ios/EssayPilot/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`：1024×1024、不含 alpha 的 iOS App 图标。
- `../../ios/EssayPilot/Resources/Assets.xcassets/BrandMark.imageset/BrandMark.png`：256×256 的应用内图标。

仅使用 sips 做打包所需的尺寸转换。图标不预裁圆角，应用内和 iOS 分别施加显示遮罩。

应用内字标通过 SwiftUI 原生渲染 `TimesNewRomanPS-BoldMT`，标题为 WriteRight，保留 W/R 大写，并遵循动态字号与语义前景色。UI 使用可访问文本，不把字标烘焙进页面截图。

四份初稿及原始生成提示词见 `concepts-20261029/`；选定稿字体编辑见 `concepts-20261029/a-serif-edit-prompt.md`。旧纸页图标保留在 `archive/`，不再是当前品牌。

## App 图标派生提示词

```text
Use case: logo-brand, precise-object-edit.
Input image is the APPROVED WriteRight brand identity. Produce the FINAL PRODUCTION iOS app-icon master by extracting the white W/check fusion mark seen inside the small orange app icon at the bottom. Preserve the exact W geometry: rounded starting cap, two low valleys, rounded middle peak, long upward right terminal; same slope, optical proportions and silhouette as the approved small app icon. Do not invent a new W. Reproduce it faithfully as crisp flat ivory #FFF9F0 geometry.
Output ONE square 1024x1024 image with a completely opaque, perfectly flat persimmon orange #F17949 background running edge to edge. Place the ivory symbol centered with balanced generous margins, mark occupying roughly 68–72% of canvas width and 52–58% of canvas height. Do not include pre-rounded outer corners: iOS applies its own mask. No wordmark, no text, no secondary symbols, no layout board, no miniature examples, no border, no inset tile, no shadow, no gradients, no texture, no 3D. Only the approved ivory W mark on the full orange square.
```

## 透明横版 Logo 派生提示词

```text
Use case: logo-brand, precise-object-edit.
Input image is the approved WriteRight identity. Extract ONLY the main horizontal logo lockup: orange W/check-fusion symbol followed by the deep warm ink "WriteRight" classic Times New Roman–style bold upright serif wordmark. Preserve the exact approved symbol geometry, typography, capital W and R, character spacing, relative scale, alignment and symbol-to-wordmark spacing. This is production asset extraction, not a new logo design.
Remove the ivory presentation background and remove ALL small examples below. Output one clean horizontal lockup on a genuinely transparent background with alpha, tightly framed around the full logo while leaving a modest equal clear-space margin. Crisp antialiased opaque logo strokes, flat orange symbol and near-black warm ink letters; no texture, no gradients, no shadows, no backdrop, no checkerboard baked into the image, no text other than "WriteRight". Do not redraw or simplify the mark, change font, add elements, duplicate the logo, or cut off any serifs or descenders.
```
