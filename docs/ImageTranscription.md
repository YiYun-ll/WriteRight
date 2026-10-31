> 当前产品已改为照片直接批改，见 docs/DirectPhotoGrading.md。本文件保留旧接口和核对流程的历史背景，不代表当前入口。

# 历史方案：图片直接交给 AI 读取

## 当前流程（2026-10-30 用户修订）

练习页以照片批改为主入口；题目/图表和作文分开上传，每类最多 4 张。图片导入、旋转不运行本地 OCR。调用 `POST /functions/v1/analyze-photos`（有效用户 token），输入 `{ part, taskImages, essayImages }`，图片为有预算的 JPEG data URL；正文上限 16,100,000 字符。模型按角色与页码清单直接阅读全部照片。

输出 `{ task: { prompt, parsed } | null, essayPages: [{ text, uncertain }], analysisVersion, modelID }`；页数必须对应作文图片，task 的结构沿用题面合同。无题图时 task 必须为 null，额外 score 等字段会被拒绝。无题或未确认题面只做语言批改。模型读取版本 WRITERIGHT_PHOTOS_V1，模型保持 deepseek-flash / https://api.deepseek.com。

发送前告知上传到服务端与 DeepSeek；结果先核对，确认后进入已有持久批改任务。首次模型读稿保留在 rawText，可编辑核对稿在 correctedText，来源 ai_photo；历史 Codable 文档新增可选来源/疑点字段保持兼容。原图与第一次模型读稿不因核对编辑被覆盖。

后端 48 项测试、原生 42 项回归与针对照片流程 4 项检查通过；界面测试使用合成模型响应，真实云端 11 项集成验证单独记录，真实手写图另验证 4 个指定数字锚点。两种证据不混称，不能据此宣称整体识图或评分准确率。云端配置见 CloudSetup.md。

## 历史 V1 接口与验收记录（保留兼容）

日期：2026-10-30。模型沿用用户选择的 `deepseek-flash`，Base URL `https://api.deepseek.com`。

官方视觉接口文档：https://api-docs.deepseek.com/guides/vision/ （本轮已读取并真实调用，支持 user message 的 image_url）。

## 接口

`POST /functions/v1/transcribe-image`，须有效用户 Bearer token 与公开客户端 key。

输入：`{ image: "data:image/jpeg;base64,..." }`（也接受 PNG）。只接受内联图片，不抓取任意 URL；单图字符串不超过 2,000,000 字符，HTTP 正文不超过 2,100,000 字符。

输出：`{ text, uncertain: string[], transcriberVersion: "WRITERIGHT_TRANSCRIPTION_V1", modelID }`。Schema：`supabase/functions/_shared/contracts/image-transcription.schema.json`。严格校验，不接受附带分数等额外字段。此接口不持久化图片或转录。

失败保留原图和现有转录。客户端登录后在扫描页逐页选择 AI 辅助转录，经发送确认后调用；核对界面并列展示原图、现有文本、可编辑 AI 文本和疑点。勾选已核对、替换待确认文字后方可采用。采用只改 correctedText，不改 rawText，不自动提交评分。题目原图仍通过已有 parse-task 解析并由用户确认；不能从作文推测题面。

## 实际验证与边界

- 合成相册图片在 iPhone 17 / iOS 26.2 模拟器经 PhotosPicker → Vision → 核对 → 真实模型报告通过。OCR 保留 `I has`；真实报告给出 8/10 并指出该问题。这不是人工评分准确性基线。
- 用户手写样本原图、macOS Vision 对比与真实 DeepSeek 输出只在 ignored `tests/private/handwriting-20261030/`。Vision 使用关闭语言纠正的 accurate 模式；手写年份漏字且未低置信提示。DeepSeek 读出年份更完整，但不能保证拼写完全忠实；均须核对。macOS 探针不等同于 iOS 手写流程已经通过。
- 真实接口集成：`node scripts/test-image-transcription-integration.mjs --live --image tests/private/handwriting-20261030/essay.jpg`。使用本地合成账号，测试后删除该测试账号；输出仅写在私有输入文件旁，不打印正文。
- 客户端 AI 候选核对界面已构建，尚待模拟器逐控件验收。原题/图表未提供，不对本次真实手写样本生成完整任务分数。
- 未部署到云端；需要部署对应函数后云端客户端才可用。

## 2026-10-30 第三轮补充

- 新 OCR 核对稿按行框的间距、缩进和书信边界整理段落，只改变布局空白；原 `rawText` 与原图保留。题面仍保留逐行形式。候选替换使用精确 UTF-16 行区间；检测到手动修改或 AI 采用后的文本偏离基线时拒绝按旧索引覆盖，并提示手动替换。
- AI 核对改为整屏、可放大原图，底部固定返回/采用操作，勾选核对且无待确认占位才能采用。模型请求期间禁用当前页编辑和删除，避免覆盖请求期间的编辑。
- 真实手写照片已经 iOS 模拟器 Vision 实际识别：本次归一化图片正确读出 2013/2015/4165/4692，并整理出段落。这与首轮 macOS 探针结果不同，不能把跨平台一次识别结果当整体准确率。已实际打开该手写图的 AI 核对界面，模型列出数字和搭配疑点；未对它生成完整任务评分，截图仅在 tests/private/。
- 合成样本完成真实客户端 AI 发送确认→真实模型返回→疑字拦截→编辑→勾选→采用→确认转录→真实 8/10 报告。读取本地库验证 rawText 仍保留 I has 的物理换行，correctedText 和正文使用明确采用的核对稿，未改写 rawText。
- DEBUG 专用 `-ui-test-scan` 可配 `WRITERIGHT_SCAN_FIXTURE` 读取标准化后位于 /tests/private/ 的本机文件。该路径不进入 Release，用于复现真实像素识别与 AI 核对；绕过系统相册选择器，不能把它当真实手写相册选择器已通过。首轮合成图片经真实 PhotosPicker 的证据仍单独保留。

## 2026-10-30 上传边界

本地 OCR 图像与上传副本分开。用例层的 `ImageUploadEncoder` 生成最多 1,400,000 字节 JPEG，Base64 加 data URL 前缀低于接口 2,000,000 字符上限。有限次压缩，最小尝试 1600 边长；极端噪声仍超限则提示裁边，不无限牺牲清晰度。原图、rawText 与核对稿不变。

透明 PNG 转 JPEG 使用白底，空图拒绝，不复制原图元数据。客户端 JSON 不转义 Base64 斜线。后端题面/转录共用规范 Base64、全 URL 字符预算、JPEG/PNG MIME/签名检查，拒绝伪图、异常 padding、末尾换行及 URL；这是轻量签名校验，不是完整解码器。

多图 PhotosPicker 使用 ordered 选择并串行处理。整个批次显示导入状态，不能在下一页仍加载时提前确认；部分加载失败说明缺失页并保留成功页。该分支已构建/编译，系统多选实际验收仍待完成。

## 2026-10-30 取消与临时文件

扫描工作由可取消 Task 持有。显式取消和离开扫描视图会取消等待；在加载/识别后、写文件和应用 AI/题面结果前检查取消状态，避免退出后继续套用结果。已经发送到服务端的请求不保证能撤回，本功能不承诺服务端退款或中止模型。

显式点击取消（含 Escape）会清理当前未采用页面的本地归一化副本，不删除系统相册原图或已有草稿图片。移除单页同样按页面 UUID 清理，失败时保留条目并显示错误。原图文件路径校验为精确 UUID.jpg，删除可重试且不跟随符号链接删除目标。交互式侧滑或进程中断遗留临时文件的全面回收仍是后续事项，不宣称所有退出路径都已清理。
