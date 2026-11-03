# 开发进度

日期：2026-11-03（Asia/Shanghai）；以下保留逐轮历史记录。产品名称：**WriteRight**，用户指定。代码模块：EssayPilot。私有仓库：WriteRight。

执行依据：[分阶段开发计划](../WriteRight_分阶段开发计划.md)。初版需求作为待实现规格保留，没有把规格当作完成证据。

截至 2026-11-03：P0–P8 主体已实现并有分项检查证据；照片批改采用题图/作文图一起直送 AI，历史 OCR 文档仅兼容读取。P9 完整真机与外部验收仍未完成。最新实现见文末「2026-11-03 账号中心与系统展示」，同日已把 0.2.0（4）覆盖安装到已连接的 iPhone 18 Pro。不能把下方早期 OCR/安装阻塞记录当成当前状态。

## 首页与练习（2026-10-29）

首页改为纸页：WriteRight 字标、距 2026-12-19 初试的整天倒计时、按剩余天数更换的短笺、最近一条收藏。考前显示天数；12 月 19 日当天显示「初试这一天」；次日起不再倒数。0 到 51 天各有一句短笺，51 天对应 10 月 29 日。更早的日子共用一句。没有收藏时不留空位。

练习承接原来的做事入口：小作文与大作文、批改任务、继续写、再写一稿、最近报告。设计规范里的信息架构已改。

验收：`npm run test:ios` 通过，29 项单测 + 8 项界面测试，结果 `artifacts/ios-tests-20261029-233004.xcresult`。浅色首页核对了「还有 51 天」和当天短笺；深色大字号核对了初试当天。练习里的写作、历史、账号和报告流程仍通过。

## 当前交付

| 阶段 | 状态 | 实际结果 |
| --- | --- | --- |
| P0 环境 | 已验证 | Xcode/iOS 模拟器、Cursor、Codex、Kimi、Supabase、私有仓库和 CI；见 `EnvironmentStatus.md` |
| P1 品牌与界面 | 已验证（模拟器） | WriteRight 显示名称、原创橙白图标、深浅色设计、首页/练习/历史/我的；`design/previews/` 有实际截图 |
| P2 本地写作 | 已验证（本机） | SwiftData 分版本库、Repository、题目 revision/确认、草稿自动保存、重启恢复、词数/分句、不可变提交快照、搜索/题型筛选、同题新稿、练习导出 |
| P3 模型契约 | 已验证（工程 PoC） | 独立 A/B Rubric、共享 Schema、DeepSeek Provider、UTF-16 合成、校验/有限重试；见 `P3_ModelValidation.md` |
| P4 账号与权限 | 已验证（本机/模拟器） | 邮箱 OTP、Keychain 会话、刷新/退出、账号分库、游客草稿显式迁移、核心云表、RLS、私有 Storage、邮箱变更 |
| P5 批改与报告 | 已验证（本机/模拟器） | 原子幂等提交、不可变任务快照、分阶段 Worker、租约/退避/定时恢复、A/B 真实报告、总览/逐句/修改稿/复盘 |
| P6 拍照与 OCR | 已验证（模拟器） | 拍照/相册/多页扫描入口、关闭语言纠正的 Vision 识别、低置信占位、原图定位、题目解析确认、提交约束、私有备份开关 |
| P7 同步 | 已验证（两份本地库） | 离线草稿上传、冲突副本、删除不复活、手动同步 |
| P8 复习与管理 | 已验证（本机） | 收藏去重、A/B 分开且样本不足不画趋势、同题对比、导出、删除失败保留本机数据 |
| P9 验收 | 待外部验收 | 验收表已写。人工评分按用户要求不做。真机安装被开发者磁盘镜像和签名身份挡住 |

## 本轮检查结果

- `npm test`：37 项通过，新增幂等冲突、不可变任务快照、阶段恢复、非法 JSON、退避与最大重试测试。
- `npm run test:db`：41 项 pgTAP 测试通过，新增原子入队、跨用户所有权、租约 fencing token、阶段持久化、报告与完成状态同事务测试。
- `npm run test:ios`：26 项单测 + 8 项 UI 测试通过（`artifacts/ios-tests-20261029-223803.xcresult`）。新增两份库的同步冲突与删除传播、收藏去重、成绩口径和删除失败保留草稿。
- `npm run check`：后端格式、Lint 和类型检查通过，包含删除账号函数。
- 已连接手机是 iPhone 18 Pro，系统 iOS 27.2。开发者模式已打开，但本机 Xcode 挂不上该系统的开发者磁盘镜像，钥匙串里也没有代码签名身份，所以没有安装到手机。
- `scripts/test-grading-integration.mjs --live`：真实集成全部通过，含重复提交、跨用户/匿名拒绝、Worker 鉴权、真实模型报告和原句区间；结果 `artifacts/p5-live-integration.json`。当前原子实现另完成 A/B 两次真实端到端验证。
- 本地 Mailpit 实际收到 6 位验证码，OTP 验证、token 刷新、退出和邮箱变更均通过；没有向真实邮箱发送邮件。
- iOS 工程构建成功，模拟器导航、写作、账号隔离、报告和重启恢复已验证。
- 真实模型 PoC 与 P5 调用均使用合成样本；没有把结构正确或模拟分数当作人工评分准确率。

## 本轮修正

- 题目、要点、正文统一焦点控制，键盘工具栏可收起所有输入框的键盘，确认按钮不会因测试点中键盘工具栏而误判成功。
- 保存失败保留编辑内容并允许重试；后续草稿编辑不能覆盖已提交快照。
- P4 使用 iOS 26 `glassEffect`，旧系统回退到 `regularMaterial`；登录页只保留必要输入、主操作和状态。
- P5 以幂等 UUID 作为 Job ID，在联网前持久化；任务快照不可变，后续题目编辑不会改变已接受 Job 的上下文。
- Worker 通过租约 fencing token 防止过期执行者写入；报告和完成状态原子提交，pg_cron/Vault 定时恢复只读取部署侧私密配置。
- 报告保存服务端 UTF-16 原句区间；总览、逐句、修改稿、复盘均使用真实报告数据，AI 估分和题面不完整状态清楚呈现。
- P6 在编辑页提供拍照作文和拍照题目。识别关闭语言纠正；置信度不足的字写成“[待确认]”，并保留候选和原图位置。未替换待确认文字、或转录未核对时不能提交。只导入题面照片不会自动确认题目。
- 构建产物 `MinimumOSVersion` 为 17.0。iOS 26 才使用液态玻璃，iOS 18.7.7 走原来的材质回退。

## 下一阶段与验收边界

阶段实现已经接到 P8。P9 不标记 V1 可用。验收表见 `docs/V1Acceptance.md`。人工评分基线按用户要求取消。

已连接的 yyyy 是 iPhone 18 Pro，系统为 iOS 27.2，不是 iOS 18.7.7。应用最低系统仍是 iOS 17。要装到这台手机，需要能挂载 iOS 27.2 开发者磁盘镜像的 Xcode，以及一个可用的开发签名身份。当前两者都不具备。

同步规则用两份本地库验证，数据库迁移 `20261029120000_p7_sync.sql` 本轮没有跑 pgTAP。正式 SMTP、手写多页和真机相机仍待外部条件。图片备份开关默认关闭。

## 品牌与视觉资源

- 图标主图：`design/brand/writeright-icon-master.png`；原始提示词与内置生成方式见 `design/brand/icon-prompt.md`。
- 实际界面：`design/previews/home-light.png`、`home-dark-accessibility.png`、`editor.png`。编辑页使用合成 XCTest 文本，没有真实作文。
- 设计约束见 `DesignSystem.md`：用间距、字体、位置与容器表达层级；保留短功能标签，去掉宣传副标题和技术徽章；错误、隐私、AI 不确定性仍须清楚。

## 品牌选定与替换（2026-10-29）

用户从四款候选中选择 A「一笔写对」，要求 WriteRight 字标采用 Times New Roman 风格，并明确同意直接替换。

- 已替换 AppIcon（1024×1024，不含 alpha）与应用内 BrandMark；旧纸页母图归档在 `design/brand/archive/`。
- 首页与“我的”使用 `BrandWordmark`，以 `TimesNewRomanPS-BoldMT` 原生渲染，语义颜色适应深浅色，支持动态字号及无障碍名称。
- 保存确认稿 `design/brand/writeright-identity-a-serif.png` 和透明横版 Logo `writeright-logo-horizontal.png`。内置 image_gen 的实际提示词见 `design/brand/icon-prompt.md` 及 `concepts-20261029/`。
- 替换后的工程构建成功；两项界面回归通过，包括浅色首页、我的页、深色大字号和导航。结果：`artifacts/ios-tests-20261029-164740.xcresult`。
- 更新实际截图：`design/previews/home-light.png`、`home-dark-accessibility.png`、`profile.png`。此次为品牌更新，产品阶段仍位于 P4 开始前。

## 夜间迭代首轮（2026-10-30 01:10，Asia/Shanghai）

用户授权夜间自主迭代，并提供真实手写作文。当前 heartbeat `writeright` 每小时接续本聊天，计划北京时间 08:00 后汇总并暂停；仅有实质变化时通知。未部署、未修改生产数据或账单。

### 已实现

- 首页暖纸白/柿橙/暖墨色板、装订日历、书信式短笺、可展开的休息页；练习纸页入口。52 个剩余日逐日重写为长短笺（0～51），早期与考后单独文案。首页定时/前台刷新跨日日期。
- 视觉实测发现的横向溢出已修复（LazyVStack 与简化日历布局）；日历装饰页眉在无障碍字号限制为 xxxLarge，正文继续放大。更新实际截图 `design/previews/home-light.png`、`practice-light.png`。
- 真实客户端提交失败定位为 unsigned Simulator 构建缺 Keychain entitlement（securityd -34018）。增加仅 simulator 的 application-identifier / keychain group；build/test 脚本使用本地 ad hoc 签名，无须开发者身份，未改真机签名材料。修复后同一任务真实提交成功。
- 增加 DEBUG 独立测试后端覆盖及独立 Keychain storageKey、调试起始 tab；Release 不读测试覆盖。真实验收用本地后端，不修改生产。
- AI 转录接口、Schema、DTO、模型层调用、扫描页发送确认与候选对照核对界面。明确采用才改 correctedText，rawText 保留；缺字/疑字需核对，不根据作文编造题面。详情 `docs/ImageTranscription.md`。
- 本地补应用已有 P7 迁移 `20261029120000_p7_sync.sql`，解决 sync pgTAP 未应用函数问题；未对远端执行。

### 本轮实际检查

- env:check 通过；后端 check 通过；后端测试 39 项通过；数据库测试 48 项通过；ios:generate 与 ios:build 通过。
- 合成图片由真实系统相册导入 → Vision OCR（保留学生 I has 错误）→ 人工点击确认 → 真实 DeepSeek 报告成功，98 词、8/10，报告指出主谓一致。截图 `acceptance-album-ocr.png`、`acceptance-live-report.png`。这是模拟器实际操作，不是 UITestGradingService 样例。
- `scripts/test-grading-integration.mjs --live` 8 项真实本地集成通过（鉴权、幂等、隔离、模型报告、原文区间）。
- 手写样本分别跑关闭语言纠正的 macOS Vision 探针与真实 deepseek-flash 图片转录；发现 Vision 将 2013 识别为 203，且未低置信标记。DeepSeek 年份更完整但不能视为完全忠实；私人原图和输出未入 Git。
- `scripts/test-image-transcription-integration.mjs --live --image tests/private/handwriting-20261030/essay.jpg`：真实鉴权图片转录、非空输出、疑点与无评分约束、匿名拒绝四项通过。
- `deno check supabase/functions/transcribe-image/index.ts` 通过；接口加入常规 check 命令。

### 必须继续的工作与边界

- 新一轮 `npm run test:ios` 尚未跑完任何用例：Xcode instruments deviceservice 的 `localDeviceConnectionWithError` / `failed to bless service hub` 在两个模拟器均复现。重启设备、服务与 ad hoc 签名未解除；不得将旧的 29+8 结果当本轮通过。已停止挂起测试进程。
- `LiveAcceptanceTests` 是新加入、需显式本地 fixture 的真实验收测试，已编译，尚未执行成功。`/tmp/writeright-acceptance.json` 只含本地 URL/公开 anon key，常规回归可 `-skip-testing:EssayPilotUITests/LiveAcceptanceTests`；不应把固定 OTP/Mock 报告当真实验收。
- 当前 CUA 元素索引操作可用；坐标操作出现 noWindowsAvailable。可用 DEBUG `-ui-test-tab profile/practice/history/home` 起始页。CLI 启动真实后端需 `SIMCTL_CHILD_WRITERIGHT_SUPABASE_URL` 与 `SIMCTL_CHILD_WRITERIGHT_SUPABASE_PUBLISHABLE_KEY`，并带 `-ui-test-live` 和 `-ui-test-store UUID`；该路径有独立 Keychain key，重启时沿用同一 UUID。
- 继续验收 AI 转录候选界面、真实手写 iOS 导入、报告四页与重启恢复；目前真实报告只核对总览。新界面浅/深与大字号还需继续逐页检查。
- 用户只提供作文图，缺原题与图表；不对该样本给完整任务分数。真实两页手写、真机相机、正式 SMTP 和云部署依然未通过，P9 不标记完成。
- 当前临时本地函数服务已启动（functions:serve）。`/tmp/writeright-worker.mjs` 以本地 secret 驱动 worker，每次限 140 轮后退出，禁止把该临时脚本或 key 输出入 Git。真实 App polling 不等于后台 worker 已部署；后续优先验证本地定时恢复与可复现验收脚本。

首轮收尾复核：最新 iOS 构建成功，后端 39 测试再次通过，`git diff --check` 无错误。独立 macOS Swift 可执行探针验证了 10/30=50 天、考试日/考后边界、52 封短笺均唯一且超过 70 字（不是 iOS XCTest 替代结果）。深色无障碍 XXXL 日历页眉已实际复核并保存 `home-dark-accessibility.png`。检查日志保存在 ignored `artifacts/night-20261030/`。后续继续以上未验收事项，不得把自动调试服务失败当成产品用例通过。

## 夜间第二轮与首页创意改造（2026-10-30 02:05，Asia/Shanghai）

用户在夜间迭代期间再次明确要求丰富首页视觉与情绪价值；本轮优先执行该新增要求。

### 已完成与实际验证

- 新增原生 Canvas「窗边书桌」：拱形窗、书本、铅笔、热饮蒸汽、绿植与暖光。深浅色分别使用月光/日光；插画不涉及位图下载，也不代表真实天气。装饰不进入 VoiceOver，静态画面无持续动画负担。
- 休息页升级为「今天，心里是什么天气？」三个实际选项；想写一点、有点累了、心有点乱分别更换陪伴文案与插画细节。没有打卡、得分、假统计或情绪数据落库。已在 iPhone 17 / iOS 26.2 模拟器实际点击并核对疲惫与心乱的回应与 selected 状态。
- 保留日历倒计时与 52 封长短笺。深色、常规字号与 Accessibility XXXL 实际查看；大字号心情按钮变单列，无横向截断。新增截图 `home-dark.png`、`home-mood-tired.png`、`home-mood-accessibility.png`，更新 `home-light.png`、`home-dark-accessibility.png`。
- 报告顶部改为可访问的四项按钮，大字号两列。用上轮真实 8/10 报告实际切换总览、逐句、修改稿和复盘；确认逐句原文/修改/理由和复盘建议均可读取。相同本地测试 UUID 再次启动仍恢复会话、98 词草稿与真实报告，修复后的 Keychain 持久化得到实际验证。新增 `acceptance-live-review.png`。
- 移除通用错误弹窗中仅重新读库的假「重试」。提交失败文案引导到批改任务的实际重试按钮；网络轮询错误改为任务内状态及「刷新」，避免两秒一次弹窗打断操作。连接状态在新账号/库打开时清空。
- `npm run ios:generate`、`npm run ios:build` 通过，最新构建日志保存在 `artifacts/night-20261030-round2/`；本轮前端改造未改后端契约。`git diff --check` 无错误。

### 后续重点

- XCTest deviceservice 阻碍仍未解除；本轮不反复重跑同一失败条件，不宣称自动 UI 回归全绿。
- 实际逐句报告发现：当前 OCR 每行直接换行，分句器把图像硬换行切为句片（如 I has / prepared），影响逐句阅读与评分证据质量。下轮应实现有几何依据的段落合并，同时保留 rawText 与原图，并重新设计逐行候选替换，不能只粗暴删除所有换行或静默改写已有提交。
- AI 转录客户端核对页与真实手写 iOS 导入仍需逐控件验收；本轮新增首页要求优先处理，没有将后端 AI 转录通过冒充客户端完成。原题未提供，仍不能对真实样本给完整任务分数。
- 无部署、无生产数据修改、无系统安全开关变更。按原夜间计划继续。

## 夜间第三轮：忠实转录与句子证据（2026-10-30 03:55，Asia/Shanghai）

### 本轮解决

- 新增纯 Foundation `OCRLayout`：为尚未确认的作文核对稿按行框几何间距/缩进/书信边界合并物理换行，只改空白；原 OCR rawText、原图、拼写与数字不自动改写。题面不合并。候选替换改用确切行区间，手动编辑或 AI 采用后拒绝旧行索引覆盖，保护编辑。
- 进一步修复原生/后端分句：空行分段，单个换行在同 UTF-16 长度的影子文本里作为空白分句，实际句子仍切自原文。即使 AI 返回物理换行，句子也不再被拆碎。评分上下文版本 `WRITERIGHT_GRADING_V1_2`，Rubric 不变；旧提交和报告均保留。
- AI 核对页整屏显示、原图可放大、底部固定返回/采用，提供收起键盘；未勾选或保留待确认字时不能采用。请求期间禁止编辑/删除当前页。空稿加入可访问的「导入作文照片」入口。
- 增加显式 DEBUG 私有图片像素验收入口，不进入 Release；该入口绕过 PhotosPicker，不冒充真实手写相册选择器通过。

### 本轮实际验收

- iPhone 17 / iOS 26.2 上实际导入真实手写图像并经 iOS Vision 识别：2013、2015、4165、4692 在本次结果中均保留，整理后检测到 3 处段落分隔。首轮 macOS 漏读 2013 不代表本次 iOS 也漏读；不能从一个样本建立通用准确率。
- 同一真实手写图通过客户端发送确认、真实模型返回并进入 AI 核对页，实际显示数字/搭配疑点，私人截图只在 ignored tests/private/handwriting-20261030/。没有原题与图表，没有生成真实样本完整任务评分。
- 合成 98 词样本实际完成新核对流程：OCR 保留 I has→真实 AI 返回→勾选仍因待确认字被拦截→修正候选→采用→确认转录→提交→真实 V1_2 8/10 报告。新报告 10 条完整句证据，I has prepared... 不再变成 I has 句片；截图 `acceptance-ai-transcript.png`、`acceptance-complete-sentence.png`。
- 直接只读本地 SQLite 核对合成稿：rawText 仍有 I has 的物理换行、correctedText 另存、确认状态正确、正文与采用稿一致；只记录布尔检查，不打印全文。实际读取新报告，验证 V1_2、完整错误句、无 I has 孤立片段。证据 `artifacts/night-20261030-round3/source-preservation.json` 与 `sentence-report.json`。
- `npm run test:ocr-layout`：6 项共享原生 XCTest 在 macOS 真正执行并通过（不依赖坏掉的 simulator deviceservice，不等同全套 iOS 测试）；`npm test`：41 项通过；`npm run check` 通过；工程生成与构建通过；`xcodebuild build-for-testing` 通过（仅编译，不当执行通过）。日志存 `artifacts/night-20261030-round3/`。
- CUA 的 AX setValue 仅改 UIKit 值时可能不触发绑定；本次通过真实输入事件核验待确认拦截，未把工具显示值当业务状态已更新。当前可用容器的 Scroll Down/Scroll Up 辅助操作进行表单滚动，无需失败的坐标控制。

### 后续与边界

- 真正的手写 PhotosPicker 选择仍未完成；本轮是私有像素路径→iOS Vision→AI 核对，不得混称。多页手写、拍照硬件、正式 SMTP、云端部署仍未验收。
- UI deviceservice 阻碍未解决，本轮没有反复启动同一挂起测试。后续可继续用可执行的 Foundation 测试与实际模拟器交互补证据，但 P9 不标记完成。
- 本轮为了验证原文保留，合成 AI 候选经过人工编辑后采用；不能据此宣称模型输出绝不纠错。真实手写稿疑字仍需用户最终核对。
- 未改数据库契约，无迁移；评分上下文版本与文档一起更新。未部署、无生产数据修改，夜间自动迭代继续。

## 夜间第四轮：上传边界与本地自动 Worker（2026-10-30 凌晨）

### 实际修复

- 发现仅限制 OCR 图像 2400 边长，细节多的 JPEG 仍会超过模型接口 2,000,000 字符。新增独立 ImageUploadEncoder，在 AppModel 用例层生成 ≤1,400,000 字节的 JPEG 上传副本；有限压缩仍超限就提示裁边，原图/rawText/核对稿不变。透明白底、空图拒绝、JSON 不转义 Base64 斜线。
- 后端两条图片接口共享规范 Base64、完整字符上限、MIME/文件签名轻量检查，伪图不触发付费调用。不冒充完整图片解码。
- 多页导入存在状态空隙：下一页 loadTransferable 期间 busy 恢复 false，用户可能提前确认半份稿。加入覆盖整个批次的导入状态、ordered 选择、读取失败缺页提示，批次中保护确认/编辑/删除/重排。该分支仅编译，未冒充系统多选实际通过。
- 本地 cron 原本启用但 Vault 配置为 0 项，一直无操作返回。新增 backend:worker:configure，只访问 localhost 开发容器，把现有配置经 stdin 写加密 Vault，无秘密进入 Git、argv、日志或临时文件；重复配置各项仍一条。

### 本轮检查

- npm run test:ocr-layout：9 项共享 macOS XCTest 真正执行通过（原排版/分句 6 + 图片预算/透明白底/非法源 3）。超高熵噪声允许明确拒绝，没有无限压缩来凑通过。
- npm test：44 项通过；npm run check 通过；iOS 生成、构建和 build-for-testing 通过（后者仅编译）。完整 iOS UI XCTest 的 deviceservice 问题未反复重试。
- 严格校验后真实手写图的认证转录、非空/疑点约束、匿名拒绝 4 项再次集成通过，结果仍只写私有目录。
- test-local-worker-schedule.mjs --live：一次性本地合成账号入队后仅轮询 status，不直接调用 Worker；数据库定时器实际完成 V1_2 模型报告，3 项检查通过并清理账号。清理后完成任务仍为原有 6 项。证据 artifacts/local-worker-schedule.json；幂等检查两个 Vault 名称各一条。
- 日志 artifacts/night-20261030-round4/；配置/使用文档 docs/LocalWorker.md。本轮无新视觉资源，不把旧截图标成多图验收证据。

### 接续与边界

- 真正手写 PhotosPicker、多页排序和部分加载失败的界面验收仍待完成；不能把 DEBUG 像素路径当系统相册。试过 Simulator Window→Fit Screen，坐标控制仍报 noWindowsAvailable；AX 控件/辅助滚动可用。未改系统安全开关。
- 本地 cron 已可运行，不需要临时人工 Worker 循环。保持 Docker/functions:serve 运行即可；未配置云端 Vault，未部署、未改账单/生产数据。
- 图片预算在 macOS ImageIO 和严格后端已验证；多图守卫仅构建/编译。仍无真实题面/图表，不给手写样本完整任务分数。真机、多页真实手写、正式 SMTP 和生产部署仍待外部验收，P9 未完成。

第四轮收尾：上传副本编码移至后台任务，避免高噪声大图多次 JPEG 尝试阻塞主界面；发送前和返回后均核对账号归属。最新 App 构建与测试编译通过。原始 UIKit 图像归一化仍保留既有流程，没有声称所有图像操作已完全离开主线程。

## 夜间第五轮：取消与临时副本（2026-10-30 05～06 时）

### 实际修复

- 扫描异步动作统一保存 Task 句柄，显式取消/视图离开取消等待。在 PhotoKit 加载、Vision 返回、图片写入以及 AI/解析结果应用前检查取消，取消不再按一般失败弹错误；相机权限返回也检查是否仍需要呈现。AI 编码完成后、发送前检查取消，已发出的服务端请求不保证撤回。
- 扫描取消和 AI 核对返回支持 Escape；显式取消清理本次未采用的本地图片副本，单页删除按 UUID 清理，失败可重试，不删除相册原图或已有稿件图片。
- ScanImageStore 拆出纯 Foundation 文件，原 UIKit 归一化保留为 extension，iOS 仍使用 completeFileProtection。路径要求精确 UUID.jpg；移除幂等且不删除符号链接指向的目标。识别/旋转前保存当前存储作用域，异步返回检查账号归属。

### 本轮证据

- 12 项共享 macOS XCTest 实际执行通过（此前 9 + 文件移除/幂等、路径越界、符号链接目标保护 3），不是完整 iOS UI 测试。
- 模拟器实际点击真实手写像素入口后立即 Escape：回到 0 词空稿，图片数量 4→4，没有等待识别完成后新落文件。使用的是 DEBUG 私有像素入口，不是 PhotosPicker。
- 再次用合成图片正常识别，确认文件数 4→5；Escape 取消后 5→4，回到 0 词空稿。保留文件数量恢复，单元测试另核对保留文件字节不变。记录 artifacts/night-20261030-round5/cancellation.json、discard.json；初次取消界面截图 scan-cancelled.png。
- 新编译出现 cancelScan 的 catch error 变量遮蔽错误，已改为 self.error；最新 App 构建与 build-for-testing 通过。日志 artifacts/night-20261030-round5/。后端本轮未修改，不把上一轮 44 项说成本轮重新执行。

### 新确认的 UI 阻碍

- 尝试真正系统相册的键盘导航时，CUA 明确报告 Mac 已锁定，自动解锁失败，要求用户手动解锁。收到该结果后停止所有电脑 UI 操作；未尝试绕过锁屏、改安全设置或用其他方式解锁。此前 noWindowsAvailable 可能与锁屏有关，但未解锁复核，不能断言同一原因。
- 因而真正手写 PhotosPicker、多页选择/加载失败/排序，以及新取消逻辑下 AI 成功分支的补验收仍待用户解锁后继续。原有 AI 成功/疑字拦截证据属于前轮，不冒称新 Task 管理下已重新通过。
- 显式取消已验证；侧滑退出或进程中断的全部临时文件回收未做。新增单页删除调用已构建，其按钮未在锁屏后进行实际操作。
- 不再重复锁屏 UI 尝试。可继续文件级检查；到 08:00 后按计划汇总并停止夜间自动化。未部署、未改生产、未改账单，P9 仍未完成。

## 2026-10-30 08:00 夜间收尾

- 已按截止时间停止夜间改码；08:02 删除 writeright 夜间 heartbeat，工具确认 deleteStatus=deleted。本地 Docker、函数服务和产品开发用 cron 保持现状。
- 交接汇总见 docs/NightHandoff_20261030.md。收尾未新增功能、未触发付费模型、未重复测试；上述各轮检查保留其实际执行时间与范围。
- 全部用户未提交修改保留。完整系统手写相册、多页与最新 Task 成功分支仍待手动解锁 Mac 后验收；未重复锁屏检查，P9 保持未完成。

## 2026-10-30 用户追加：首页日历展示双日期

- 日历橙色页眉改为「今天」及完整年月日、星期；纸页底部明确展示「考试日期：2026年12月19日」，倒计时保留。考试日期由 ExamDesk 常量提供，今天随既有分钟刷新/前台刷新更新。
- 两行日期均支持宽度不足时纵向排版，不再限制日期的动态字号；VoiceOver 同时读取今天与考试日期。同步更新设计规范。
- npm run ios:build 成功，git diff --check 通过。日志 /tmp/writeright-calendar-build.log。此次为用户追加的局部修改，未重启夜间自动化。
- 尚无用户手动解锁确认，遵循前轮锁屏限制，未操作模拟器或生成新截图；不能将构建成功等同实际 UI 验收通过。

## 2026-10-30 用户请求真机安装：连接与签名检查

- 重新执行 devicectl list/info 和 xcdevice list：已配对 iPhone 18 Pro 的记录为 iOS 27.2、Developer Mode enabled，但 tunnelState unavailable、ddiServicesAvailable false；xcdevice 当前 available=false，提示解锁并用数据线连接或保持同一局域网。不能把已配对记录当当前已可安装。
- 钥匙串查询为 0 valid codesigning identities；项目未选择 DEVELOPMENT_TEAM。实际 iphoneos/generic iOS Debug 构建退出 65，明确错误 Signing for EssayPilot requires a development team。日志 /tmp/writeright-device-build.log。
- 未安装或启动手机 App，未冒称真机测试通过。需用户恢复可用连接并在 Xcode 登录 Apple ID/选择签名 Team，随后继续安装。未更改系统、签名身份、账单或生产数据。

### 真机已连接后的复核

- 用户重新连接后，devicectl 现在报告 available (paired)、wired、tunnelState connected，连接阻碍已解除。手机仍为 iOS 27.2；实际查询明确返回 developer disk image could not be mounted，ddiServicesAvailable=false。钥匙串仍为 0 valid signing identities。
- 当前 Xcode 26.3，sw_vers 实测 Mac 已是 macOS 27.2（不再沿用早期 15.6 的环境描述）。Apple 官方 https://developer.apple.com/xcode/system-requirements 当前列出 Xcode 27.2 自带 iOS 27.2 SDK，要求 macOS 26.6 或更高；本机满足其系统要求。选用 Xcode 27.2 作为后续真机工具链，无须为此升级 macOS。
- 已访问官方应用下载入口 https://developer.apple.com/download/applications/，重定向至 Apple ID 登录，未取得安装包。未绕过登录、未替换原 Xcode、未修改 macOS。待用户完成官方新版下载与 Apple 签名账号设置后继续安装验收。

### 用户授权安装 Xcode 27.2

- 登录后通过官方页面实际下载 Xcode_27.2.xip（约 1.9 GB），xip 解包成功。应用 codesign --verify --deep --strict 通过，证书链为 Software Signing / Apple Code Signing Certification Authority / Apple Root CA；spctl assess 接受，source=Apple System。未移除隔离或修改系统安全设置。
- 已安装 /Applications/Xcode-27.2.app，实际 xcodebuild -version 为 Xcode 27.2 / 27B52。现有 /Applications/Xcode.app（26.3）保留，尚未切换系统默认工具链。
- 首次启动显示 Xcode and Apple SDKs Agreement，已向用户请求本次接受协议的明确确认；尚未点击 Agree，checkFirstLaunchStatus 为 69，不能宣称首次配置或项目构建通过。确认与必要组件安装完成后继续新版构建、真机开发服务及签名检查。
- 用户允许不影响项目时卸载旧版；待新版通过相关检查后再移除旧版，当前不提前删除。

### Xcode 安装与首次真机运行完成

- 用户明确同意 Apple SDK 协议后点击 Agree；中途再次遇到锁屏即停止，收到用户「Mac 已手动解锁」确认后继续。Install Required System Components 完成，checkFirstLaunchStatus 通过，SDK 列表包含 iOS 27.2。
- 新版下项目模拟器构建、iphoneos 无签名构建均通过。旧版正常退出后移至 ~/.Trash/Xcode-26.3.app，新版调整至 /Applications/Xcode.app，保留原 xcode-select 路径即可使用 27.2 / 27B52。未清空废纸篓，未升级 macOS 或改系统安全设置。
- 新版成功挂载手机开发者服务，设备具有安装/启动应用能力。用户另外明确授权在现有 Personal Team 创建 Apple Development 证书、本机钥匙串私钥；选择项目自动签名后证书/描述文件生成成功，真机签名构建通过。个人 Team 设置迁至 ignored Local.xcconfig，验证继承结果有效；私钥/证书未写入仓库。
- devicectl 实际安装 com.yiyun.essaypilot.dev 成功，随后 launch 成功。Device Hub 实际观察到手机上的 WriteRight 系统 PhotosPicker，用户正在手机上操作；未替用户选择私人相册项目，未将相册缩略图保存进仓库。此前完整手写多页/AI 路径仍不能算通过。
- 新工具链解析 Swift 包时只新增 swift-issue-reporting 2.1.2 的传递依赖锁定，原已锁版本未升级。构建日志已做邮箱脱敏，记录 artifacts/device-20261030/。未重新执行完整 XCTest、后端测试或付费模型。
- 检查实际安装包 Info.plist，Supabase URL/公开 key 尚未配置，当前真机版本不能联网登录/评分；前轮 DEBUG 模拟器环境覆盖不自动进入此包。需后续配置手机可访问的测试后端，不能把安装/启动成功当完整 AI 验收。P9 保持未完成，未部署或修改生产数据。

## 2026-10-30 云端配置与手机登录（接续用户授权）

- 用户明确要求手机离开Mac后仍可登录和批改，并授权完成云端配置。使用已关联的 EssayPilot-dev（新加坡，tdcxdiqvrfmppaqikgxu），未重建或清空项目、未升级套餐。配置前核查用户/草稿/提交/报告为0；此后用户已实际登录，不能继续视为空库。
- 通过官方CLI的HTTPS Management API原子应用缺少的P7迁移并登记历史；直连Postgres曾ECONNRESET。部署原八个函数，设置仅服务端DeepSeek/独立Worker token；Vault与既有分钟cron已验证无需本地Worker完成真实报告。App只打包公开地址/key，服务端密钥不进入客户端。
- 用户提供QQ SMTP并授权配置，凭据保存在ignored模式600私有文件；配置脚本通过环境传递，不打印密钥或邮箱。Supabase免费默认邮件拒绝验证码模板修改，接入QQ SMTP后六位OTP与品牌模板应用成功。用户明确确认手机收到验证码并登录，服务端确认邮箱验证和登录成功。
- 修复自定义INFOPLIST_KEY没有进入成品的问题，改用Config/AppInfo.plist引用公开构建变量；实际签名包检查云地址和公开key存在、无服务端密钥。此前手机安装包缺后端的阻碍已解除。
- 上一版「多图读取→核对→批改」曾完成48后端、42原生及专门4项照片检查；真实云11项集成通过，用户手写无题图另核对4项锚点。原始结果只在ignored tests/private。这是历史转录方案证据，不能说成下列照片直批证据。
- 真机UI XCTest曾失败于无法确定已启动应用PID；不能宣称真机重启会话或完整流程自动验收通过。用户实际邮箱登录确认与自动化失败分别记录。

## 2026-10-30 用户五项需求：照片直接批改、进度与人文体验

### 当前交付

- 重构照片流程：分别选题图/作文图、调整顺序/旋转/移除、保存草稿，一次「开始看图批改」。不执行本地OCR，不调用analyze-photos/transcribe-image，不提供LLM转文字或题面/正文核对编辑器。文字写作仍可用；历史OCR/AI转录文档保留兼容。手动编辑页的导图入口改为进入照片直批，照片草稿可以续开，复用题图可再写一稿。
- 新增submit-photo-grading、服务专用enqueue_photo_grading迁移和schema2.0。任务保存私有图片路径/页序/SHA256不可变快照，original_text为空、source_sentences_json为空；Worker取回验证图片后一次将全部题图与作文图交给deepseek-flash直接处理，复用原有cron、租约、有限重试与报告持久化。重试复用上传字节和幂等键；编码缓存失败清理未引用副本。客户端也核对报告图片指纹，不接受与本次快照不符的照片报告。
- 提示词WRITERIGHT_DIRECT_VISION_V2，A10/B15分别定档。先判断可读性，再结合任务、语言、组织；不按错误数/复杂词机械扣分，不把简单正确表达当低级错误。必改/可选分开，保留短引文中的学生错误、事实数字与原意；缺题、关键数据/正文不清强制不出总分。只输出用于建议的带页码短片段，禁止整篇原文转录。模型误认、改写和估分偏差仍可能存在。
- 等待页与练习任务采用五段细进度线，依准备/上传/队列/读图/整理或完成的实际状态推进，无假百分比/ETA。导入照片与发送照片区分，错误保留稿件和重试；可离开已提交任务。杯子/叶子可点击展开休息提醒，支持Reduce Motion和动态字号。
- 报告四页为总览/原稿建议/修改稿/复盘。题目始终展开原图，作文按页显示原稿和局部建议，优点、读图疑点、温和下一步并列；图片独立重试/放大。无估词数时不显示“0词”。成绩以衬线大数字、独立A/B刻度、同一版本趋势呈现，横轴为第几次练习。第二次同题可对比两次原稿和报告，不把估词数或局部建议当精确错误密度。
- 同题照片按题型与题图指纹关联，只选已有报告稿件；无题图不宣称同题。不同量表不直接比分数。鼓励不承诺提分、不虚构进步。隐私页改为解释照片私有云处理，不再显示会误导新流程的扫描备份开关。
- 顺带修复云删号只列前100个根目录对象的问题：先分页递归枚举再分批删除，清理失败不继续删除Auth账号。

### 实际检查与证据

- npm run env:check通过；npm run check通过；后端53项通过（含5项新直批/评分门槛/页码/私有图清理检查），npm run test:db 55项通过（含7项照片RPC/权限/幂等/快照检查）。本地数据库执行迁移和测试，无重置旧数据。
- 最终原生iOS XCTest44项实际执行通过：artifacts/ios-tests-20261030-142911.xcresult。覆盖无转录照片提交、无题不估分、页序、幂等复用、草稿图恢复、账号隔离和题图指纹对比，既有文本/同步/持久化回归保留。
- 最终模拟器UI XCTest3项实际通过：artifacts/ios-tests-20261030-142954.xcresult。覆盖照片直达报告、题图/作文图、原稿建议/复盘、复用题图第二稿与对比、重启后重新登录同一测试账号的报告恢复、成绩曲线、暗色Accessibility XXXL不溢出，以及手动编辑切换照片入口。UI模型是合成fixture，不冒称真实模型UI端到端；导图样例按钮绕过PhotosPicker，不能算系统相册通过。
- 过程中首次UI重启断言失败：测试Auth stub会话仅内存保存，重启处于游客库。改为重启后登录同一测试账号再核对持久数据，最终通过；不以此宣称真实Keychain会话恢复。后续收尾编译发现同题引用重构的成员访问错误，修正后原生/UI及真机构建重新通过。
- 开发云应用照片迁移、部署submit-photo-grading/grading-worker/delete-account，并完成14项真实deepseek-flash云检查：照片提交、幂等/冲突、无需本地Worker的cron报告、A10量表、schema2.0、无全文转录存储、私有原图回看、跨账号隔离及删号源图清理。证据artifacts/cloud-direct-photos/acceptance.json；合成原稿/完整报告仅tests/private/cloud-acceptance。最终提示词追加简单表达、局部错误/零分边界说明后重新check/53后端通过，并已更新云Worker；未为这段小幅文字追加重复付费基线测试。
- XcodeGen生成、模拟器构建、iphoneos签名构建通过。最终包检查为正确HTTPS云地址/客户端公开key，无服务端凭据。devicectl安装最新包到已连接iPhone成功；启动等待较久，Device Hub实际显示手机密码锁屏，已要求用户在手机手动解锁，未尝试输入密码或绕过锁屏，未宣称新版真机启动或整链路通过。
- 新实际截图已导出并检查：design/previews/direct-photo-upload.png、direct-photo-ready.png、direct-photo-overview.png、direct-photo-original-advice.png、direct-photo-comparison.png、direct-photo-stats-first-score.png（文件名沿用，最新已含两次记录）、photo-upload-dark-accessibility.png。全为合成UI数据，不把旧截图作为新版本证据。

### 遗留与接续

- 待手机手动解锁后检查新版真实运行、相机/真正系统PhotosPicker、多页手写顺序/失败/取消以及真实客户端云评分。当前云HTTP集成与模拟器fixtureUI分别成立，不合并成真机完整通过。
- 仍没有用户手写作文对应原题/图表，本轮没有给它完整任务评分或重新做转录。评分准确性、长篇多页手写和人工独立基线仍待验收，P9不标全部完成。
- 已按当前云端授权部署开发环境；未改账单、macOS、安全开关或生产数据，保留全部用户未提交修改。没有创建新自动化、提交或推送。

## 2026-10-30 本轮：首页互动、收藏反馈与「我的」

### 实际修改

- 报告复盘的收藏按钮读取规范化表达的真实收藏状态。成功保存后显示「已收藏」与实心书签、停止重复点击；重新打开报告仍保持。失败不做假成功，收藏夹删除后恢复可收藏。原有来源合并与去重保留。
- 首页收藏改为「书页一角」，放在逐日长笺后，与阅读语境连接。以衬线表达、引导文案、可展开释义/用法、换一句（至少两条时）及收藏夹入口呈现，空收藏不造内容。修复父级无障碍ID覆盖子按钮标识的问题，使入口可被独立定位与操作。
- 首页添加可开关的小台灯，直接放在顶部原生插画旁，切换插画灯罩/光池与回应。支持Reduce Motion，不增加自动闪烁。桌边新增喝口水/看看远处/暂时收笔三种可选回应，以及口袋便笺；不把点击当作完成真实行动，不制造连续打卡或积分压力。
- 口袋便笺由独立DeskCompanionModel保存，最多280字，按账号/游客隔离，本机保留、清空可用，不发AI、不云同步。账号切换重建对应模型，成功删号清理本机对应便笺。测试运行另外隔离UserDefaults命名空间，不污染日常使用。
- 「我的」重构为账号头部、真实练习/报告/收藏数量入口、成绩/同题对比、同步/导出/隐私、外观/帮助/关于。新增可打开既有报告的报告库；帮助回答照片直批、无题处理、等待、评分、原稿与便笺问题；关于页叶子按钮展开一封短留言。账号头部隐藏邮箱主要字符，完整账号信息进入账号页查看；不添加无实际能力的会员、客服或奖励项。
- 浅深色、大字号采用同一纸色/暖墨视觉；Accessibility字号下数量入口纵向排列，行图标使用固定尺寸避免挤入正文。首页和我的顶部使用明确背景，避免滚动文字穿过状态栏。没有修改后端合同、再次调用付费模型或重新部署云函数。

### 本轮检查

- XcodeGen、模拟器构建通过；完整原生46项实际执行通过（artifacts/ios-tests-20261030-182706.xcresult），含新增收藏状态/去重/移除回归及本机便笺重开、账号隔离、清理检查。
- 五个相关UI用例分批实际通过：账号登录/迁移/退出、首页点灯/桌边回应/便笺写入重启与清空/我的导航、深色Accessibility XXXL、报告收藏后已收藏及重开状态/首页收藏夹、原首页与四页导航。首轮artifact为ios-tests-20261030-182748.xcresult，其中收藏入口定位失败，其余4项通过；修复ID覆盖后相关2项在183243结果中通过。最终大字号图标修正后单独复验通过：183544结果。不能把首次失败的整套说成全绿。
- 真机签名构建和实际包公开云配置检查通过。本轮安装尝试失败：CoreDeviceError4016，设备无法取得开发服务/可信连接/电源保持状态，当前断开了可用开发连接。未尝试绕过手机锁屏，也没有宣称本轮新版已安装或真机验收通过；上一轮已安装的版本保留。
- 新模拟器截图：design/previews/home-reading-corner.png、home-desk-interactions.png、profile-library-light.png、profile-library-dark-accessibility.png。全为合成测试数据；图像已实际查看，大字号图标挤压后修正并重拍。
- 本轮无需后端变更，未重做53项后端或真实云模型通过项；既有云能力保持。git diff --check通过，保留所有用户未提交修改。

### 接续边界

- 手机恢复可信开发连接并手动解锁后，才能安装本轮包及真机验收；不反复锁屏截图或尝试密码。P9的完整真机相机/系统相册/多页手写与评分基线仍保持未完成。
- 便笺明确只存本机，不随账号同步到新手机；是私人短记，不替代练习草稿或云备份。其账号隔离和清空已测，完整VoiceOver手动导航仍待真机补验收。

本轮收尾补验收：最终图标/顶部背景版本的首页互动、帮助、关于页叶子留言、便笺重启与清空，再执行1个完整UI用例通过：artifacts/ios-tests-20261030-184012.xcresult。已更新浅色我的/桌边截图并新增profile-about-letter.png；其余5个相关UI用例的分批证据保持原实际范围。脱敏日志归档artifacts/desk-20261030/。本轮未安装到手机，失败原因仍为CoreDevice可信开发连接不可用。

## 2026-10-30 评分校准、双语修改稿与昵称（用户追加）

### 交付与版本

- 针对用户反馈的估分偏高1–2分，新增CALIBRATED_SCORING证据定档锚点。评分与鼓励独立，先核对任务/遗漏、语言准确性和组织；不默认良好或档位上沿，高档需充分原稿证据，不以“意思能猜到”、格式齐全或单句亮点抵消明显短板。不统一减分、不强制低分分布、不制造错误，也不因缺题/识图不清扣分。总评要求说明依据、限制更高档的问题与优先行动。没有人工gold对照，不能说已统计消除偏差。
- 新文字提示词WRITERIGHT_GRADING_V1_3、A/B独立量表V2、报告1.1.0；新照片提示词WRITERIGHT_DIRECT_VISION_V3、独立PHOTO_V3、报告2.1.0。已接受的V1_2和照片V2快照使用冻结的旧提示词及合同；旧报告与分数不修改，新旧量表曲线不直接连接。
- 两种修改稿各附中文译文、1–3句重点及中文说明，保存在rewrites.study。模型内部以顶层rewrite_study输出，再映射到报告，避免深层JSON错误。服务器验证中文存在、重点逐字引用/唯一定位/互不交叠，原生再次核对；不使用HTML，不猜测近似句。原始作文/题图路径不变，不增加OCR或LLM转录。
- 修改稿页支持中英对照开关、红色粗体重点与重点用途说明、重点开关、复制当前版本纯英文及已复制反馈。红色表示复习重点，不表示错误；无法可靠改写时无译文。早期报告明确提示未附双语材料，不伪造翻译；新规则对新批改生效。深色使用高对比红色，无障碍字号下改写版本为完整菜单、操作可纵排。
- 用户追加昵称：我的顶部显示昵称，铅笔/账号页可编辑，20字以内、去除首尾空白、留空恢复默认。使用既有profiles.nickname和RLS保存，服务端确认后更新，本机按账号缓存，退出隐藏/删号清理。失败保留原名与输入，旧异步读取不能覆盖新保存；我的下拉或立即同步可以重新读取昵称。没有创建新表或改旧数据结构；JSON合同/原生DTO/文档一起更新。

### 实际检查与真实问题

- npm run check及后端57项通过，涵盖新译文/重点锚点校验、空稿/历史兼容和旧提示词分流。新数据库昵称RLS测试加入后npm run test:db共60项通过，事务内合成账号回滚。
- 原生先49项通过（含三项双语DTO/旧报告/Unicode精确定位）；追加昵称后完整52项通过：artifacts/ios-tests-20261030-195740.xcresult。昵称三项覆盖保存/重置/账号隔离、失败及离线恢复、慢读取不覆盖新名。
- 相关UI分批通过：193240结果含文字报告双语/重点/开关、照片完整流程两项；193623结果为暗色Accessibility XXXL照片修改稿读图/中文显示一项；195822结果为昵称编辑/重置和原账号迁入/退出两项。昵称输入保存中禁用/未修改时禁用保存等收尾后，200103结果再验证昵称完整流程通过。上述是合成UI服务，不冒称模型真实UI端到端。
- 首次真实云双语验收失败于PHOTO_GRADING_VALIDATION_FAILED。私有诊断发现模型连续把review嵌进rewrites并漏关根括号；没有放宽JSON校验或擅自补括号/更改文本。改为模型内部顶层rewrite_study与独立review，新的真实直接调用一次通过；重新部署三项评分函数后真实云17项检查通过：artifacts/cloud-bilingual/acceptance.json，含V3版本、两份中文译文、准确重点、定时报告、无转录、私有图与账户隔离/清理。
- 同一合成样例新结果4/10，之前V2也是4/10；没有人工分数标签，不能据此宣称解决1–2分偏差、评分准确率或全面质量达标。完整原稿/模型输出仅ignored tests/private，未输出用户作文或个人邮箱。首次失败测试遗留的两张合成图按已删测试账号、精确fixture哈希与时间窗定位后通过Storage API清理；新云验收脚本失败收尾也改为先删私有图/账号。
- 真实云昵称5项通过：artifacts/cloud-profile/acceptance.json，验证保存、独立读取持久化、另一账号不可读/改及清空重置。仅合成账号，无模型调用、未修改用户自己的昵称。
- XcodeGen、模拟器构建、真机签名构建通过；实际包公开云配置检查通过。评分/双语版先安装并启动，昵称合并版本随后再次devicectl安装和启动成功，保留原账户/数据。最终启动页为「我的」，未替用户设定昵称。不能把安装/进程运行说成完整真机相机、系统相册、多页手写或真机真实评分流程全部通过。
- 新实际截图已导出检查：design/previews/rewrite-bilingual-emphasis.png、rewrite-dark-accessibility-focus.png、rewrite-dark-accessibility-translation.png、profile-nickname.png。均为合成内容，不含用户作文；测试结果和脱敏日志见相应artifacts。

### 接续边界

- 后续用用户真实题面和带人工评分的对照样本验证偏差与重复波动；当前仅作文手写图仍不能臆造原题或给完整任务分数。P9保持未完成。
- 新翻译/重点仅随新报告生成，旧报告保持不可变、展示明确缺失提示。昵称可随账号读取，离线只显示上次确认的缓存，不假装在线保存成功。
- 本轮根据既有用户授权部署开发云评分函数与安装手机；未改账单、macOS、安全设置或生产数据。未创建自动化、提交或推送，全部用户未提交修改保留。

## 2026-10-30 首页日落休息模式与异地安装说明

### 交付

- 顶部窗边小画新增「看看日落，歇一会儿」：太阳约7秒缓缓落到窗外，天色经过晚霞转为夜蓝，月亮与星光浮现，台灯关闭；文案回应「太阳慢慢落下，今天可以先到这里」。夜间可重新点灯并显示「夜色里，给自己留一盏小灯」，也可返回白天并恢复灯光。动画直接由SwiftUI插值驱动，没有定时后台任务或休息打卡，不改变App外观设置；减少动态效果时直接切换，当次状态不上传、重启恢复默认。
- 完成docs/WriteRight_异地iPhone安装说明.md，并加入README文档入口。面向异地iOS18.7.7朋友，覆盖TestFlight开发者会员、App ID/Release云配置、归档与外部审核/邀请、朋友端安装与账号登录、90天有效期/更新/排错，以及Ad Hoc与免费Personal Team备选的实际限制；提供可转发步骤与可选归档命令。Apple官方公开资料已查询核对并在文内引用。
- 本项目声明最低iOS17，朋友的18.7.7符合声明；并未在她的设备执行验收。当前Personal Team不能据此承诺TestFlight分发资格；邮箱OTP的审核访问方案也尚需准备。没有购买会员、执行发布归档/上传、提交审核或发送邀请。

### 实际检查与证据

- XcodeGen、模拟器构建通过；HomeRestModeTests的日落/关灯/重新点灯/返回白天与原首页四页导航，共2个UI用例实际通过：artifacts/ios-tests-20261030-202352.xcresult。另一个深色Accessibility XXXL的同类操作用例实际通过：artifacts/ios-tests-20261030-202713.xcresult；休息按钮边界没有横向溢出。
- 新截图design/previews/home-rest-day.png、home-rest-night.png、home-rest-dark-accessibility.png均从本轮真实模拟器测试导出并实际查看，未复用旧图；三张分别为浅色日景、浅色夜景、深色大字号夜景。减少动态效果分支已实现，本轮没有切换系统无障碍设置实测，完整VoiceOver手动导航仍待补验收。
- 真机签名构建成功，scripts/check-ios-cloud.mjs验证实际包连接既定HTTPS云项目且使用客户端公开key，没有服务端私密plist配置。devicectl当前列出已配对手机为unavailable，本轮没有执行安装，不能宣称新版已到手机或真机流程通过；上一轮已安装版保留。
- 安装说明本地链接、代码围栏检查通过，git diff --check通过；本轮仅首页表现与文档调整，没有改变后端、调用付费模型或重做既有后端通过项。日志见artifacts/rest-mode-20261030/。保留全部用户未提交修改，P9与远程18.7.7实际验收继续未完成。

### 用户连接手机后的补充安装

- 用户要求安装后，devicectl重新检查已配对iPhone18Pro为connected。既有最新日落版真机包的公开云配置检查再次通过，未重复构建或改变签名。
- devicectl实际覆盖安装com.yiyun.essaypilot.dev成功，随后启动命令成功，初始页参数为首页；没有卸载App或清除数据。这是安装与启动证据，未把它扩展为全部真机交互或相机/相册验收通过。

## 2026-10-30 无会员iLoader侧载方案与IPA

- 用户追问免费IPA侧载与完整服务。查询iLoader官方站/仓库、其isideload签名库、Apple免费账户限制及SideStore设备准备文档，确认可由接收方电脑使用其Apple账户重新签名导入IPA。此前异地文档仅列Xcode免费编译，遗漏第三方工具重签路线，现已修正；不把免费签名描述成永久或免签公开分发。
- 新增scripts/package-ios-sideload.sh，独立ignored artifacts目录构建真机Release，关闭开发签名，不导出证书或变更已装App；检查实际公开云配置后，以Payload/EssayPilot.app结构封装，清除副本的描述文件/签名目录，提供SHA-256。实际生成artifacts/sideload-20261030-213232/WriteRight-0.1.0-2-sideload.ipa（0.1.0构建2，4,951,691字节）。
- Release构建、ZIP完整性、单一Payload/目录遍历检查、最低系统17.0/真机iPhoneOS/实际Mach-O平台与minos检查、公开HTTPS云配置和无服务端plist私密项检查通过；IPA未包含私钥、描述文件、xcconfig或本机用户文档。验收摘要checks.json与build.log在同一artifact目录。脚本bash -n、文档本地链接/代码围栏、git diff --check通过。
- 新增docs/WriteRight_iLoader侧载安装说明.md并更新完整异地说明/README：官方工具来源、Windows iTunes前置、自有Apple账户与设备信任/Developer Mode、选IPA、自己的WriteRight邮箱登录、7天/3个App限制、原账户/标识续签覆盖安装与数据注意事项。SideStore只是可选续签方案，没有代装或配置。
- 代码检查显示邮箱OTP、HTTPS批改/同步、私有存储等当前功能不依赖付费Apple能力，免费签名有效且云服务/额度正常时不主动减少功能；这是架构推断，不是接收方18.7.7实际安装、Keychain、完整功能或7天续签通过的证据。当前私有样本、账号数据和签名材料未交付；没有登录朋友Apple账户、替她接受协议、撤销证书、改云服务或调用付费模型。P9保持原边界。

## 2026-10-30 21:40～21:44 当前云服务实际复核

- 用户询问当前运行情况及他人安装后的服务可用性。本轮实际查询Supabase开发项目ACTIVE_HEALTHY、9项函数ACTIVE、health/Auth HTTP200，cron启用且最近3次调用成功；公开Auth设置邮箱登录启用、允许新用户且仍验证邮箱。SMTP/模板只读diff无声明项差异，QQ SMTP实际认证235成功，未发送新邮件、不宣称接收方实际收件通过。
- 新执行一次真实DeepSeek照片Part A合成任务，17项云端直批/报告/双语重点/原图/无转录/账号隔离/删号清理检查通过，cron自动完成，无手动Worker。昵称5项通过；另一次性账号验证同步上传、独立登录会话拉取、旧修订冲突、删除和防复活5项通过，合计27项工程检查。仅合成账号及数据，收尾均清理，不触碰已有用户数据；旧验收JSON先备份，当前新证据保存在artifacts/cloud-availability-20261030-2140/。
- 侧载Release成品公开云配置再次检查通过。当前已实现的核心云服务运行正常，手机联网即可访问，不需开发者Mac在线；免费Apple签名期限与云服务可用性独立。没有修改配置、部署、账单或签名。报告模型全文仍仅保存在ignored tests/private/。
- 仍不宣称接收方iOS18.7.7实际安装、Keychain/邮件投递/所有本地交互已验收，也不从单个Part A样本推断评分质量或所有题型完整通过。详见docs/CloudSetup.md；P9保持未完成。

### 持续可用的维护说明

用户询问如何持续运行，查询Supabase官方当前暂停规则、价格/组织计费及备份范围，DeepSeek错误码与Supabase SMTP资料；在docs/CloudSetup.md补充免费/付费选择、模型余额、邮件/cron监控和独立图片备份。特别说明当前health仅静态存活响应，不能证明数据库/邮件/模型健康或保证免费项目不暂停。Pro从25美元/月起、不因低活跃暂停，不等于所有依赖永不故障；新监控、备份和购买均仅为建议，本轮未执行。没有改代码、套餐/账单、云配置、部署或创建自动化，也未重做付费模型验收；文档git diff --check通过。

### 接收方iOS18.7.7安装反馈与待定位问题

用户反馈iOS18.7.7已安装成功，属于接收方报告的安装证据，不扩大为完整服务或续签验收。随后反馈“该页面截图没反应”，当前消息未附页面图片，尚需澄清是系统截屏、App相机拍照还是相册导入。只读检查没有发现App截屏拦截/安全文本遮罩代码；相机权限与相册导入路径已定位，未凭猜测修改代码，也未宣称已复现或修复。

## 2026-10-30 接收方验证码失败定位与诊断提示

- 后续图片明确为邮箱登录页“验证码发送失败”，不是系统截屏。用户又确认同一手机Safari访问云健康地址报“已丢失网络连接”，确认该手机当前网络到云入口不可达；未确定DNS、TLS或具体运营商原因。Mac对比：配置代理路径Auth健康接口收到HTTP401（无apikey请求），直接路径curl35/TLS失败。旧云端成功验证在Mac可达路径完成，不能据此承诺别人5G可达。
- Dashboard认证日志只读查看后关闭本轮临时标签页；没有取得与该手机失败可靠关联的错误。Management日志读取遇到本机钥匙串交互等待，已终止本轮读取进程，不导出或输出凭据、不修改权限。没有向截图中的邮箱再次发送邮件，没有修改云配置、域名、账单或调用模型。
- 原发送/验证catch统一提示不准确。新增AuthFailureMessage按URLError、Supabase安全错误码及HTTP状态给出网络/TLS、限流、邮件策略、登录配置、服务异常/验证码错误的不同中文建议与安全数字/类别代码；不显示raw message、响应正文、邮箱或token。错误文字可选择复制。只有DEBUG测试服务在专用参数下模拟TLS失败，Release不包含该测试服务。
- XcodeGen、模拟器构建通过；4项错误映射/隐私回归、3项原账号测试，以及1项真实模拟器界面测试通过，结果artifacts/ios-tests-20261030-225908.xcresult。模拟器错误截图design/previews/login-network-diagnostic.png已实际查看，为合成邮箱和模拟网络失败，不冒称在接收方复现了iOS错误代码-1200。日志与网络检查摘要在artifacts/login-diagnostic-20261030/。
- 已构建Release 0.1.0(3) IPA：artifacts/sideload-20261030-230308/WriteRight-0.1.0-3-sideload.ipa。真机平台/最低iOS17/ZIP/不含私钥和描述文件/公开云配置检查通过，附校验文件；打包脚本支持传入构建号，默认3，保持构建2原包。未在接收方安装构建3，没有宣称新包解决网络线路。仅需更清楚的诊断时可用原Apple账户/标识覆盖安装；当前优先切Wi-Fi对比，若仍不可达需另行验证可达入口。
- CloudSetup及侧载说明已写明网络边界与排查方式，git diff --check通过；全部用户未提交修改保留。P9仍待接收方成功登录、完整云流程与续签验收。

## 2026-10-31 前一轮交付补记：进阶反馈、逐句修改与记录

上一轮因用户追加新任务在最终文档收尾前被打断；以下仅归档当时已取得的证据，不算本轮重新验收。

- 新文字报告1.3.0/提示词V1_5、照片报告2.3.0/提示词V5增加逐句原文/建议/中文理由（必要、可选、保留、疑字）、句式/篇章进阶建议及独立双语示范。逐句引用只在最终报告内，无OCR/中间转录流程；缺题不给完整任务分数或独立示范。重点精确引用、翻译/复制沿用阅读控件，旧报告不补造材料。V1_4/V4及更早快照冻结，本轮扩展学习反馈而非改变A/B评分量表。
- 历史移到练习右上角；记录新增待办/短记/分享链接、账号隔离SwiftData V4、独立同步游标、冲突副本及删除防复活。20261031010000_notebook_sync已获用户授权应用至EssayPilot-dev，三项批改函数已发布，既有用户数据保留。
- 实际check、后端65项通过；本地数据库65项在该轮迁移时通过。最终原生62项通过：artifacts/ios-tests-20261031-134710.xcresult。逐句/示范/文字报告、深色大字号阅读和浏览器交接4个UI用例实际通过于134103结果；同批原生旧版本断言失败后已修正并由134710全原生补验，不将失败批次称全绿。
- 新提示词真实直调：照片A/B各11条逐句反馈且complete；文字V1_5也通过原句精确覆盖与纠错一致性。公开摘要artifacts/development-live/WRITERIGHT_DIRECT_VISION_V5-checks.json，完整模型内容仅ignored tests/private。云端第一次发现示范与表达增强相同，补充忽略空白的重复拒绝和重试后，重新部署并执行真实云24项通过：artifacts/cloud-development/acceptance.json（2026-10-31 13:54:53北京时间），包含cron自动报告、逐句/进阶/独立双语、记录同步、私有图、跨账号隔离及测试账号清理；不是评分准确率或人工满分认定。
- 用户连接手机后，实际签名Release构建6、公有云配置检查通过；devicectl覆盖安装及正常启动成功，证据artifacts/device-learning-20261031/install.json与launch.json。未卸载App；安装/启动不代表完整真机相机、多页手写或VoiceOver验收。侧载包artifacts/sideload-20261031-135157/WriteRight-0.1.0-6-sideload.ipa，ZIP、最低iOS17、iPhoneOS与不含签名私钥/配置文件检查通过。新报告才生成新增学习材料；P9保持未完成。
- 另保留此前验证码诊断边界：原手机实际URLSession连通正常，已授权的一次发信收到429 over_email_send_rate_limit；不能继续笼统归为网络故障。用户同意改30封，本地配置已改，但云控制台保存后未独立回读，不能声称云限额30已验证。本轮不再发送测试邮件或调整限额。

## 2026-10-31 记录展示与首页互动（本轮，无手机）

### 实际交付

- 移除独立Paste按钮，只有「记下一件事」。同一编辑页选择待办/随手记/灵感链接，链接按需展开；灵感筛选中直接创建链接。标题可选，正文第一行或分享来源自动命名；错误保留输入，成功后清空遮住新条目的旧搜索/不匹配筛选。没有主动读取剪贴板或抓取链接。
- 记录按置顶、留给今天、慢慢来的小事、留下的片刻、已经走过分组。待办用复选圆圈；随手记/链接从菜单收好/标记看过。正文整块可编辑，链接独立整行打开。卡片省去重复首行与长URL，原始正文保留；过去日期使用温和的「还可以接着做」。已完成可从手边页找回，排序规则移至NotebookPresentation，表单校验移至NotebookEditorModel。
- 修复在途删除的撤销竞态：任何已删除条目的撤销均用新ID恢复，使迟到的删除确认不会抹掉恢复内容。保持SwiftData V4与云record合同，无新迁移/部署。
- 首页窗边小画增加安静/微风/小雨循环、添茶、照料绿植，以及对应当次状态/语音反馈。风线/雨滴、茶气、叶片与灯光使用有限原生插值，日落约7秒；无无限循环、额外计时器、天气请求或互动历史上传。状态重启恢复默认；灯光/夜色/窗外可组合，减少动态效果时直接切换。
- 首轮截图发现长插画动画让文字/按钮过渡叠影，已将Canvas动画与文字约0.22秒过渡分离，按钮标题即时更新；修复后新雨景/月夜截图实际查看，无旧文字残影。大字号控制纵排，记录主按钮补验为导航栏/底栏之间完整可见，不只部分可点击。

### 检查与证据

- npm run env:check、XcodeGen与模拟器构建通过。首轮相关原生13项/界面8项通过：artifacts/ios-tests-20261031-141759.xcresult，包含系统浏览器交接、重启/撤销/历史入口、日落及深色大字号。该轮截图叠影另行修复，不把交互通过当作视觉已合格。
- 最终版本相关原生14项、界面6项通过：artifacts/ios-tests-20261031-142606.xcresult。涵盖记录分组/搜索/链接/预览、无标题正文与分享文字保存、待办附链接类型保留、在途删除撤销、场景状态与重置；实际界面覆盖新增、编辑入口、完成/已看过、撤销、重启、日落/灯光、窗边/茶/绿植组合及深色Accessibility XXXL。
- 主按钮完整可见性额外补验1个UI用例通过：artifacts/ios-tests-20261031-143357.xcresult，重复的是同一大字号用例，不计成新的独立功能用例。没有切换真实系统Reduce Motion设置或手动VoiceOver遍历；实现分支不能冒称这些真机验收通过。
- 新截图已实际查看并保存：design/previews/home-window-rain.png、home-rain-night.png、notebook-light.png、notebook-seen-link.png、notebook-dark-accessibility.png。均来自本轮真实模拟器与合成数据；前一轮截图不作为本轮新证据。
- 新真机平台Release 0.1.0(7)侧载包：artifacts/sideload-20261031-143357/WriteRight-0.1.0-7-sideload.ipa，5,188,599字节。Release构建、公开云配置、ZIP/安全Payload、最低iOS17与无描述文件/签名私钥/xcconfig检查通过，附checks.json和SHA256。接收方仍需自行重签，不能直接点文件安装；当前没有连接手机，未尝试本轮真机安装。
- 本轮未修改后端/评分合同、未部署、未触发付费模型或新测试邮件，也未重复此前后端/数据库通过项。保留全部未提交修改、未提交或推送。需求/设计/使用文档与阶段记录已同步；P9完整真实多页手写/相机/VoiceOver与人工评分基线仍未完成。

## 2026-10-31 首页重复休息区修复与重新安装

- 用户前次要求安装后，构建7已实际覆盖安装、启动成功：artifacts/device-home7-20261031/install.json、launch.json；随后用户报告首页休息区重复，本次针对该问题修复。
- 原顶部InteractiveDeskView和底部DeskCompanionView在同一LazyVStack中使用相同的账号字符串ID，可能被错误复用；首轮移除旧休息内容后，实际回归仍无法找到底部便笺。改为home-scene-/home-note-不同前缀并复验，底部便笺恢复。旧版三项休息卡一并移除，顶部保留唯一书桌互动/日落入口；底部组件改为HomePrivateNoteView，仅负责原有私有便笺。便笺UserDefaults键与账号隔离模型完全保留，未迁移或清空内容。
- 首轮结果175414存在便笺缺失失败，不能当通过证据。最终artifacts/ios-tests-20261031-180115.xcresult：便笺持久化/账号隔离1项原生及3项界面用例通过，包括浅色、深色Accessibility XXXL滚动到首页底部、无旧休息卡、唯一顶部休息入口、便笺编辑/重启恢复、我的相关入口。新截图home-single-rest-private-note.png与home-single-rest-dark-large.png已实际查看并存入design/previews。
- 最终签名Release 0.1.0(8)构建和实际公开云配置检查通过；devicectl覆盖安装成功：artifacts/device-home8-20261031/install.json。首次带terminate-existing的启动CLI无输出等待后已结束该CLI；只读锁状态无需口令，改为正常启动成功，launch.json记录成功与进程ID。没有卸载App、清除用户数据或尝试绕过锁屏，不扩大为所有真机功能通过。
- 同步生成最终侧载包artifacts/sideload-20261031-180238/WriteRight-0.1.0-8-sideload.ipa（5,177,814字节），Release/公开云配置/ZIP/最低iOS17/真机平台/无签名私密文件检查通过，附SHA256和checks.json。初步修复版8在独立artifact中标为superseded，不用于交付。
- 需求/设计/阶段与安装说明已更新，git diff --check通过。没有部署、调用模型、改评分或改生产数据；本轮只修复首页与安装，P9其他未验收范围保持原边界。

## 2026-11-01 陪伴小猫、链接来源整理与缺陷修复（本轮，无手机）

### 实际交付

- 记录链接：NotebookLink新增平台识别——哔哩哔哩（bilibili.com、b23.tv、bili2233.cn）、微信公众号（仅mp.weixin.qq.com）、小红书、抖音。只取ASCII URL字符，避免把紧跟链接的中文分享语吞进URL；平台链接的http升级为https，其它网站仍只收https。分享文字中的【标题】（去掉B站后缀、拒绝App名）或链接前用户写的话自动成为标题，正文只剩链接时不重复存为备注。
- 按来源整理：灵感链接筛选下按来源分组（平台在前，其他网站按去掉www的域名），组内未看过、置顶、最新优先；两个及以上来源时出现来源书架，可单选筛选，切换筛选/保存/换账号时重置。搜索可用「B站」「公众号」等来源词。预览不再重复标题和长链接。
- 首页移除口袋便笺（HomePrivateNoteView、DeskCompanionModel及其测试删除）。旧便笺不静默删除：记录页顶部提示「收进记录」（存为随手记后再清理旧键）或「不需要了」（确认后清理）。帮助页同步改写。
- 陪伴小猫：小画窗台下的橘猫「团团」，可点它或用卡片摸摸头/喂小鱼干（每天各记一次）/陪我写一会儿（10/25/45分钟，可提前结束，回到前台或到点自动结算）。会按陪写中、深夜、离开≥2天回来、考试当天/7天内、关灯、下雨、心情、时段说不同的话，不责备缺席。成长点＝来书桌天数×2＋互动＋每5分钟陪写1点＋批改报告×4；六阶「小毛团→窗台小客→书页守护→陪写伙伴→长夜灯伴→同行到初试」（0/12/32/64/108/168点）分别加入围巾、铅笔、夜间灯笼、小书包；升级时说一句。成长路线页含改名（最多8字）、相识/来书桌/一起写/报告足迹、路线和规则说明。数据只存本机UserDefaults并按账号/游客隔离，不发AI、不云同步，删号清理。
- 缺陷修复：
  - 同步推送期间的新编辑：草稿/收藏确认改为比对已推送载荷，只有一致才清脏，避免在途编辑被标为已同步而丢失。
  - syncNow并发：同账号重复触发合并为同一任务，并在重载前确认账号未切换，避免冲突副本和跨账号写入。
  - 记事推送冲突时若服务端内容与本地相同（首次响应丢失后重推），直接按服务端revision确认，不再生成「（另一份记录）」副本；内容不同时仍保留副本。
  - 收藏取消后再收藏：本地未同步删除时复用原条目并清除deletedAt；已同步墓碑则新建ID，不再让新收藏被墓碑覆盖或显示为未收藏。
  - 游客照片草稿迁入账号前，先把题目页/作文页原图与上传图复制到账号图片目录，避免迁入后原图丢失。
  - 删除账号：只有服务端删除失败才报错并保留本机数据；成功后退出会话、清理小猫/旧便笺/昵称缓存与本机文件，本机文件清理失败给出单独说明。删号成功后Auth也会主动signOut。
  - 账号切换：openStore同时清空记录和收藏，activate重置同步状态，避免短暂显示上一账号内容。
  - 报告页优点/维度/任务检查/重点/表达改用位置ID，模型返回相同文字时不再触发SwiftUI重复ID。
  - 文字作文提交失败时在编辑页内显示原因，不再只写入不显示的全局错误；照片提交同样清理全局错误。
  - 照片批改进度页：连不上时也显示「刷新进度」，手动刷新会重启轮询；轮询由4分钟改为前2分钟每2秒、之后每10秒，最长约40分钟，不再静默停住。
  - 验证码校验时邮箱与发送时一样去空格并转小写。
  - LocalWritingStore的保存失败统一回滚上下文，避免留下半应用的未保存更改。

### 检查与证据

- npm run env:check：Xcode/模拟器SDK/XcodeGen/Supabase CLI/Docker等通过，Codex CLI缺失（与本轮无关）。XcodeGen与模拟器构建通过。
- 全原生82项通过：artifacts/ios-tests-20261101-133213.xcresult；补上记事重推不生成副本后全原生83项再次通过：artifacts/ios-tests-20261101-135647.xcresult（该改动只涉及同步引擎，未重跑UI）。新增CompanionTests 6项（每日上限与缺席、阶段阈值与升级提示、陪写计分/到点结算、账号隔离/改名/清理、旧便笺读取清理、无责备话语）、链接平台/标题/来源书架与预览，以及在途编辑保持脏标记、墓碑后再收藏、并发同步不产生冲突副本、游客照片草稿迁入保留原图4项回归。
- 全部UI 29项：artifacts/ios-tests-20261101-133300.xcresult中25项通过、1项按设计跳过（需真机账号），3项失败：
  - NotebookCreationTests：仍期待旧的「小红书里的一点灵感」，本轮改为优先使用用户在链接前写的话；更新断言后于artifacts/ios-tests-20261101-134818.xcresult通过。
  - WritingFlowTests深色Accessibility XXXL：小猫卡片让首页更长，懒加载列表首屏未生成倒计时；练习页的A/B入口也在首屏外（练习页本轮未改，提交版本里同一步同样会失败，此前被前一个断言挡住）。测试改为先滑到目标再断言，于artifacts/ios-tests-20261101-135227.xcresult通过。
  - LiveAcceptanceTests：本机存在/tmp/writeright-acceptance.json而被启用，但仍是旧OCR流程且需要本地线上环境，此前已记录未跑通；常规回归应跳过，不计入本轮通过。
- 新截图实际查看后保存：design/previews/home-companion-light.png、home-companion-focus.png、home-companion-dark-large.png、companion-growth.png、notebook-link-sources.png（模拟器、合成数据）。首轮截图发现小猫卡片文字叠影与链接预览重复标题，已修复后重拍。日志在artifacts/companion-20261101/。
- 本轮未改后端、数据库迁移、评分合同或云记录格式，未运行npm run check/npm test，未部署、未调用模型、未发邮件、未安装手机。没有手动VoiceOver遍历或真实Reduce Motion切换。

### 已知遗留

- 冷启动离线时会话恢复失败可能退回游客视图（未复现，待真机验证）；切换账号时拍照页会丢弃尚未保存的相机照片。
- 旧OCR草稿无法再提交，ScanReviewView/useEssayScan已是无入口代码；同步拉取只取单页200条；收藏的来源句取报告第一处修改句，不一定与表达相关；考试年份写死2026；导出JSON留在临时目录。
- ~~小猫成长只存本机~~（已在下一节「第二轮」改为随账号跨设备同步）。

## 2026-11-01 第二轮：温馨书桌重绘、小猫云同步、删除撤销、离线原图

### 实际交付

- 书桌与小猫重绘（原生矢量，用户选定方案）：圆角小房间，含圆点暖墙纸、小彩灯、挂画、木框拱窗与窗帘（远山、软云、太阳/月亮/星星）、木纹桌面、圆顶台灯、爱心马克杯、摊开的本子与铅笔、带小脸的陶土花盆。小猫为大头圆脸、带高光的大眼、腮红、ω嘴、虎斑纹，坐/陪写/睡三种姿态，围巾/铅笔/灯笼/小书包按阶段出现、体型随阶段略长。新增`DeskArt.swift`（等比缩放`DeskSpace`、颜色混合、云/心/星/铅笔），`DeskLightLayer`在小猫之上用正片叠底画夜色、滤色画灯光与彩灯光晕。日落、开关灯、安静/微风/小雨、添茶、照料绿植、心情细节与减少动态效果行为保留；点猫区域改为同一等比换算。
- 小猫成长跨设备同步：`CompanionGrowth`改为可合并格式（来访/摸头/小鱼干日期集合、按设备的陪写分钟与次数、`nameUpdatedAt`改名时间、最早相识日、最大已庆祝阶段），旧本机数据容错解码。迁移`20261101090000_companion_growth`新增`companion_profiles`表（RLS只读本人，客户端无直接写权限）与`merge_companion(jsonb)`（security definer、行锁、大小/日期/计数/名字校验、并集与取大合并、后写名字胜出）。客户端`CompanionSync`在登录后打开首页、回到前台、手动同步和小猫有新成长时静默上传并与本机最新状态再次合并；失败不打扰，下次再试。游客只留本机；删号仍清理本机（云端行随auth.users级联删除）。卡片隐私说明与帮助页同步改写。
- 历史/收藏左滑删除提供撤销：`PendingRemoval`立即隐藏、约5秒后才真正删除；离开页面、进入后台、再删下一条时按决定生效，切换账号放弃待删；底部撤销条带语音播报，撤销按钮44点、强调色。采用延迟删除而非删后恢复，避免与正在推送的同步删除竞态。
- 报告原图离线可看：`ReportPhotoCache`按SHA-256存于`JuGuang/accounts/<uid>/report-photos/`；`gradingPhoto`顺序为缓存→这台设备当初上传的同一份照片（按角色/页序且指纹一致）→联网下载并写缓存。每次读都核对指纹，损坏的缓存不当原图；删号随账号目录清理。
- 云端部署（用户授权：本地测试通过后应用到EssayPilot-dev，只新增表和函数）：先只读核对云端迁移历史8条，与本地相比只缺`20261101090000`、无云端独有迁移。新增`scripts/apply-companion-cloud-migration.mjs`，沿用记事迁移的做法经CLI HTTPS管理接口原子执行并登记历史（直连Postgres仍ECONNRESET）。回读：历史9条且已登记；表RLS开启、0行；authenticated可执行`merge_companion`、可select、不可insert；anon不可执行/不可读；辅助函数未授权authenticated；函数为security definer；auth.users仍为4个，未改动既有数据。

### 检查与证据

- npm run check通过；npm test 65项通过；npm run test:db 7个文件78项通过（含新增companion_growth 13项：匿名拒绝、首次保存、双设备合并、旧改名不覆盖、过期设备不增减、本人可读、直接写入42501、坏日期/负分钟/空名字拒绝、他人不可见）。git diff --check通过。
- 全原生91项通过、UI 28项中27项通过1项按设计跳过（需真机账号），LiveAcceptance按惯例排除：artifacts/ios-tests-20261101-143929.xcresult（所有最终代码之后运行）。新增/调整的检查：
  - CompanionTests：双设备合并不丢、同步在途新增照料保留、服务端形状解码与缺省、账号同步刷新书桌与删号清理。
  - PhotoPracticeTests：离线时本机上传原图可看、首次下载后缓存可看、损坏缓存被拒；PendingRemoval先隐藏、撤销不删、再删下一条结算上一条、到时删除、离开即生效。
  - GradingFlowTests（UI）：收藏左滑删除→撤销恢复；历史左滑删除→撤销恢复→再删等待窗口结束后真正消失（空状态出现）。
  - DeskArtRenderTests：深浅色各5种书桌状态与六阶小猫渲染为附件，逐张查看。
- 实际查看截图后保存到design/previews：desk-art-day-light/day-dark/night-lamp-dark/rest-night-light/rain-light/breeze-light、cat-stages-light/dark、favorite-undo-bar，并以重绘后画面更新home-companion-light/focus/dark-large、companion-growth、home-rest-day/night、home-rain-night、home-window-rain。首轮截图发现夜色发灰、月亮被云挡、陪写眼神像皱眉、小猫偏小，均已修正后重拍。日志在artifacts/companion-20261101/。
- 未调用模型、未发邮件、未安装手机、未改套餐。未用真实账号在云端调用`merge_companion`（避免写入用户数据），云端只做结构与权限回读；跨设备效果由本地pgTAP与原生测试证明，需新版本装到两台设备后实测。

### 已知遗留

- 开发者这台 iPhone 18 Pro 已安装 0.2.0，可以开始上传小猫成长；其它仍停在旧包的设备需要装上 0.2.0 后才会上传。游客期间的小猫不会在登录后并入账号（沿用原有按账号隔离）。
- 原图缓存不设容量上限，只随删号清理；只有看过一次或本机拍摄的原图离线可看，其它设备首次查看仍需联网。
- 撤销窗口内被隐藏的历史稿件在其它页面（如练习页「继续写」）仍可能短暂出现，窗口结束后一致。

## 2026-11-01 安装 0.2.0 并交付 IPA

- 应用营销版本由 0.1.0 调整为 0.2.0，构建号 1。已连接手机为有线配对的 iPhone 18 Pro（yyyy，iOS 27.2，开发者模式已开）。
- 签名 Release 构建通过，公开云配置检查通过。devicectl 覆盖安装成功并启动，进程 5731；设备上显示 WriteRight 0.2.0（1）。未卸载、未清数据。证据 artifacts/device-020-20261101-150158/install.json、launch.json。
- 与这次安装相同的签名包：artifacts/device-020-20261101-150158/WriteRight-0.2.0-1.ipa（4,592,405 字节，SHA-256 `404ddadae6545e6fc862e151abfedc95de54d8175465c54e9ee35946babd1327`）。含本机开发描述文件，供已注册设备重装。
- 侧载包 artifacts/sideload-20261101-150307/WriteRight-0.2.0-1-sideload.ipa（5,426,937 字节，SHA-256 `4eb8240e3df21f8f84a78b99471948205dcf39bfc20c21850b489d9f90d65c08`）。ZIP 可解、Payload/EssayPilot.app、版本 0.2.0 构建 1、最低 iOS 17.0、Mach-O 平台 IOS、无描述文件/签名目录/私钥；公开云配置检查通过。接收方需自行重签。
- 安装与启动不代表完整真机相机、多页手写或 VoiceOver 验收。未部署、未调用模型、未改生产数据。P9 不标完成。

## 2026-11-01 最近报告删除与撤销

### 实际交付

- 练习页「最近报告」支持左滑删除，复用 `PendingRemoval`：立即隐藏并显示约5秒撤销条，撤销不写入删除；超时、离开页面、进入后台或删除下一条时生效，切换账号放弃待删。只删除报告，不连带删除草稿、提交或收藏。
- SwiftData升级V5，以独立 `LocalGradingReportSyncState` 保存报告修订号、脏标记和删除墓碑；旧报告轻量迁移保留，删除经现有同步协议传播，远端删除、迟到批改响应和重复同步均不复活报告。首轮直接在原模型加字段导致重复版本校验和，已改为独立状态模型并重新验证。
- 需求、设计规范、P7阶段证据和V1验收记录同步更新。无需后端迁移或部署。

### 检查与证据

- `npm run ios:generate`、`npm run ios:build`通过；`npm run check`及后端65项测试通过；`git diff --check`通过。`npm run env:check`仅因本机缺少Codex CLI返回非零，Xcode、模拟器SDK和XcodeGen正常。
- 最终全部原生94项通过：artifacts/ios-tests-20261101-230715.xcresult，包含V4→V5旧报告迁移、删除后重启仍隐藏、迟到保存不复活、双设备删除同步。
- 完整原生/UI批次artifacts/ios-tests-20261101-225034.xcresult共120项通过、1项按设计跳过；唯一失败为既有`LiveAcceptanceTests.testRealAlbumOCRAndModelReport()`真实相册/云端OCR验收，与本次改动无关，不将完整批次称为全绿。报告删除→撤销→再次删除的UI流程在该批次通过。
- 报告撤销条截图已实际查看：artifacts/report-delete-attachments-20261101/5529E246-6BB4-46F7-82C7-63BAE689728E.png。未调用模型、未部署、未改生产数据、未安装真机；跨设备效果由两份本地库验证，物理双机仍待验收。

## 2026-11-02 数据可靠性、报告体验与系统扩展

### 实际交付

- 冷启动恢复会话失败时按本机缓存身份打开原账号空间，明确离线且不伪装可云端批改；照片新增、排序、旋转即时保存，切换账号不再丢失未保存照片。同步拉取完整分页，设置页显示实际待同步数量。
- 备份V4包含草稿、提交、报告、收藏、记录和原图；可导入合并，冲突文档另建标识，同名不同图在写入前停止。单份报告可导出分享。缓存页显示文件数/占用/上限，超过100MB–1GB设定值清理最久未读文件，支持手动清理，本机原稿不受影响。
- 「我的报告」支持题目/点评搜索、题型筛选、单份导出和多选删除；单删与批量删除均延迟生效并可撤销，批量操作放在顶部以避免与Tab栏命中冲突。逐句报告支持必改/类型筛选、简洁/详细讲解和原句—建议对照；照片按页呈现。收藏来源定位到实际对应句子，兼容be useful for/is useful for，找不到时留空而非误引第一句。
- 陪写新增60分钟和5–120分钟自定义，ActivityKit实时活动显示真实结束时间，提前结束按实际分钟结算。新增WriteRightWidgets扩展，主屏幕显示同一考试倒计时，锁屏/灵动岛显示陪写状态；App Group共享配置，应用声明NSSupportsLiveActivities。视觉沿用纸白、暖墨、柿橙与衬线，减少重复说明并以布局承载层级。

### 检查与证据

- `npm run ios:generate`、`npm run ios:build`通过；`npm run check`与后端65项测试通过；`git diff --check`通过。`npm run env:check`仅缺Codex CLI，Xcode/模拟器SDK/XcodeGen正常。
- 最终全部原生102项通过：artifacts/ios-tests-20261102-004305.xcresult。新增验证备份含图往返、冲突合并不覆盖、离线冷启动、205条同步分页、照片即时保存、准确收藏来源、缓存清理、60分钟及实时活动控制。
- 完整原生/UI批次artifacts/ios-tests-20261102-002343.xcresult为128项通过、1项跳过、2项失败：DevelopmentFlow详细报告缺少「为什么」标签已修复，并于artifacts/ios-tests-20261102-004028.xcresult单独复验通过；另一项仍为既有LiveAcceptance真实相册/云端OCR环境失败，不将完整批次称为全绿。
- 报告搜索/多选删除撤销/简洁对照全流程通过：artifacts/ios-tests-20261102-001925.xcresult。截图已实际查看：artifacts/expanded-feature-acceptance-20261102/645F9719-2A6E-483C-8FB6-723710C4FE74.png、7D215C42-5C22-4090-B176-81BF927EE40A.png。
- 真机平台Release及公开云配置检查通过：artifacts/sideload-20261102-004154/WriteRight-0.2.0-2-sideload.ipa。ZIP/包含Widget扩展/NSSupportsLiveActivities=true检查通过，接收方需自行重签；未安装手机。
- 当前物理iPhone显示unavailable，因此真机相机、多页手写、灵动岛外观、锁屏实时活动和主屏幕放置仍待设备验收；模拟器扩展安装和UI流程不替代这些项目。未部署、未调用模型、未改生产数据。

## 2026-11-02 覆盖安装 0.2.0（2）

- 用户连接手机后，yyyy（iPhone 18 Pro，iOS 27.2，有线、已配对、开发者模式已开、ddi 可用）覆盖安装 WriteRight 0.2.0（2）并启动，进程 9626。未卸载、未清数据。证据 artifacts/device-0202-20261102-164902/install.json、launch.json。
- 签名 Release 使用既有 Personal Team。主 App 描述文件包含 `group.com.yiyun.essaypilot.shared`；小组件描述文件的 App Group 列表为空，因此本次小组件签名未带该组。源文件 `ios/Config/Widget.entitlements` 仍声明该组，构建后已核对未改。公开云配置检查通过。主屏幕倒计时与依赖共享组的小组件数据仍待描述文件补上该组后重装验收。
- 安装与启动不代表真机相机、多页手写、灵动岛外观或主屏幕小组件放置通过。未部署、未调用模型、未改生产数据。

## 2026-11-02 侧载包保留小组件权限

- 核对 iLoader 2.4.1（2026-10-28）源码：`ExtensionsBehavior` 固定为 `ReuseMain`，小组件不单独注册 App ID，签名沿用主应用描述文件。只重打未签名 IPA 不能让这份 iLoader 启用灵动岛。
- `scripts/package-ios-sideload.sh` 改为在去掉设备描述文件后，用临时签名把 `group.com.yiyun.essaypilot.shared` 写入主应用和 `WriteRightWidgets.appex`，并附上 `archived-expanded-entitlements.xcent`。不导出私钥。
- 实际生成 `artifacts/sideload-20261102-170228/WriteRight-0.2.0-3-sideload.ipa`（5,688,226 字节，SHA-256 `ce81849c6659ba7801354e8de6345a4fc7fded70882f0b049904c89595b915e5`）。解压后主应用与小组件都能读到该 App Group，无 `embedded.mobileprovision`，`NSSupportsLiveActivities` 为 true，扩展点为 WidgetKit。公开云配置检查通过。
- 接收方需要用会单独登记扩展的工具安装，当前对应 Sideloadly，且不要移除扩展。尚未在接收方手机上安装，不能把包结构检查说成灵动岛已经出现。未部署、未改生产数据。

## 2026-11-03 账号中心与系统展示（无手机）

### 本轮实现

- 头像：我的顶部独立头像入口，系统 PhotosPicker 单选、更换与恢复默认；ImageIO 缩至640像素并重新编码去除元数据，按游客/账号保存在本机，退出隔离、删号清理。选择照片期间切换账号，晚到结果不会覆盖新账号头像。头像暂不跨设备同步，界面明确说明。
- 我的：紧凑标准导航标题、独立账号卡片、实际练习/报告/收藏数量、「学习记录 / 数据管理 / 通用」分组；省去入口抒情副标题和页尾口号。保留昵称、账号管理、同步、备份、缓存、隐私等既有实际功能。
- 小组件：以原 kind 升级 AppIntentConfiguration，支持每个组件独立选择倒计时/待办/灵感链接，以及暖纸/鼠尾草/午夜/自选照片背景；小号/中号布局。自选照片本机共用，1000像素压缩去元数据，深色遮罩保证文字对比；支持移除背景。
- 记录共享：默认关闭，用户在「我的 → 桌面小组件」明确开启后，才向 App Group 导出最多4条未完成且未删除的待办/链接标题与日期/域名。置顶优先，不共享正文；切换账号/退出/关闭时覆盖共享快照，快照变化才请求刷新。系统刷新可能延迟。点击小组件通过 writeright URL 跳转首页/记录页，并关闭旧弹层。
- 锁屏/灵动岛：圆形书页符号、分区计时、真实进度条与暖杏色强调；展开/紧凑/最小态统一书页符号，倒计时限定开始至结束区间，到期停在零。

### 实际检查与证据

- `npm run env:check`、`npm run ios:generate`、`npm run ios:build` 通过；模拟器 iPhone 17 / iOS26.2，无真机。
- 全量原生105项通过：`artifacts/ios-tests-20261103-141857.xcresult`。含新增头像压缩/损坏输入/持久化/账号隔离、晚到头像结果与记录共享过滤/退出清理；快照去重优化后另复验新增3项通过（`ios-tests-20261103-142056.xcresult`）。
- 昵称编辑重置、陪写/账号入口等3项原有界面回归通过（`ios-tests-20261103-141536.xcresult`）；紧凑导航修改后深色Accessibility XXXL另外复验通过（`ios-tests-20261103-141857.xcresult`）。
- 相册头像/背景的实际选择保存流程通过（`ios-tests-20261103-142056.xcresult`）。后续恢复默认与移除背景补验见下方收尾记录。
- 系统实时活动测试通过（`ios-tests-20261103-142737.xcresult`），实际查看锁屏通知中心卡片及灵动岛紧凑/展开态。真正断网锁机、长期到期回收和真机显示仍待验收。
- 桌面组件已真正从系统菜单添加，确认 WriteRight 图标变为小组件、实际显示46天及考试日期，系统添加测试通过（`ios-tests-20261103-143549.xcresult`）。早期仅截图但未断言组件的探索测试不算组件添加通过；最终用组件属性断言并人工查看截图。系统菜单存在 remote AX/动画超时，尝试重启模拟器 SpringBoard 后最终通过。
- 截图：`design/previews/profile-dark-accessibility.png`、`widget-countdown-small.png`、`focus-lock-screen.png`、`focus-island-compact.png`、`focus-island-expanded.png`。未将含私人相册图片的测试截图放入设计目录。新增纯色棋盘合成图片 `tests/fixtures/profile-widget.png`，测试脚本每次导入新副本，照片测试只选择当月测试图，避免使用已有个人照片。

### 边界

未改后端/数据库合同、未调用模型、未部署、未安装手机。小组件系统端多内容、多尺寸、所有主题组合未逐一操作验收；原生数据合同已检查。P9不扩大为完成。相册自动化前两轮因 remote Photos 网格不可点击而失败，改用实际网格中心点后通过；不把初次失败隐去。新增恢复默认的首次断言早于对话框关闭，收尾补验等待实际消失。

收尾：`artifacts/ios-tests-20261103-161025.xcresult` 的相册完整流程（合成棋盘图）通过，包含头像保存、背景保存/移除、恢复默认头像并等待实际消失。更新 `design/previews/profile.png`、`profile-avatar.png`、`widget-settings.png`。测试脚本已自动导入当次合成图；最终 `git diff --check` 通过。

## 2026-11-03 覆盖安装 0.2.0（4）并重打侧载包

- 已连接 yyyy（iPhone 18 Pro，iOS 27.2，有线、已配对、开发者模式已开、ddi 可用）。用当前代码覆盖安装 WriteRight 0.2.0（4）并启动，进程 13456。未卸载、未清数据。证据 `artifacts/device-0204-20261103-164726/install.json`、`launch.json`。
- 签名 Release 使用既有 Personal Team。公开云配置检查通过。主应用签名包含 `group.com.yiyun.essaypilot.shared`。小组件描述文件的 App Group 仍为空，因此本次装到手机的小组件签名未带该组；`ios/Config/Widget.entitlements` 在构建后已核对仍声明该组。主屏幕共享数据、锁屏和灵动岛仍待描述文件补上该组后重装验收。
- 同一签名包：`artifacts/device-0204-20261103-164726/WriteRight-0.2.0-4.ipa`（4,946,543 字节，SHA-256 `cbda639bddd92c2d5e47c1c26d1d9e3b93027ba67765ac9618ccea51fafb3792`）。含本机开发描述文件，供已注册设备重装。
- 侧载包 `artifacts/sideload-20261103-164833/WriteRight-0.2.0-4-sideload.ipa`（5,802,215 字节，SHA-256 `e361a4443b5c4aa64dd349c39f39c158f88eabe197ab0136f24c0bdd2e7f395e`）。解压后主应用与小组件都能读到该 App Group，无 `embedded.mobileprovision`，`NSSupportsLiveActivities` 为 true，扩展点为 WidgetKit。公开云配置检查通过。接收方需自行重签；iLoader 2.4.1 仍不能单独登记扩展。
- 安装与启动不代表真机相机、多页手写、灵动岛外观或主屏幕小组件放置通过。未部署、未调用模型、未改生产数据。P9 不标完成。

## 2026-11-03 小组件照片与记录

- 免费开发描述文件不能把 App Group 写进小组件。主应用写进共享目录的照片和记录，小组件读不到，于是继续显示午夜，开启「展示记录」也没有标题。时间线里再附带整张照片时，系统还可能留下上一次的午夜条目。
- 照片和记录快照同时写入主应用钥匙串分组 `TEAMID.com.yiyun.essaypilot.dev`。真机小组件只签这个钥匙串分组，不再要求 App Group。已保存的照片在打开 App 时补写到钥匙串。模拟器和对方可登记扩展的侧载包仍优先读 App Group。
- 只要保存了照片，小组件就改用这张照片，不再停在午夜；移除后恢复小组件里选的纯色。开启记录后，倒计时或待办显示待办标题，灵感链接显示链接。照片不再放进时间线条目。
- `ProfileWidgetTests` 4 项通过，含去掉共享目录副本后仍能读到照片和记录，午夜主题也会改用照片。已连接的 yyyy 覆盖安装 0.2.0（5）并启动，进程 13529。主应用签名同时有 App Group 和钥匙串分组；小组件签名只有同一钥匙串分组。未卸载、未清数据。未部署、未调用模型。
- 侧载包 `artifacts/sideload-20261103-171141/WriteRight-0.2.0-5-sideload.ipa`（5,823,632 字节，SHA-256 `0899c905bed41a4e4d995635f9c1ff2c3dc559f43268eb9c594e2399b3ef316d`）。解压后主应用与小组件都能读到该 App Group，无 `embedded.mobileprovision`，`NSSupportsLiveActivities` 为 true，扩展点为 WidgetKit。公开云配置检查通过。接收方需自行重签；iLoader 2.4.1 仍不能单独登记扩展。这份包不含本机开发钥匙串分组。
