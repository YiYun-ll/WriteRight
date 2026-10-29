# 开发进度

日期：2026-10-29（Asia/Shanghai）。产品名称：**WriteRight**，用户指定。代码模块与私有仓库：EssayPilot。

执行依据：[分阶段开发计划](../WriteRight_分阶段开发计划.md)。初版需求作为待实现规格保留，没有把规格当作完成证据。

## 当前交付

| 阶段 | 状态 | 实际结果 |
| --- | --- | --- |
| P0 环境 | 已验证 | Xcode/iOS 模拟器、Cursor、Codex、Kimi、Supabase、私有仓库和 CI；见 `EnvironmentStatus.md` |
| P1 品牌与界面 | 已验证（模拟器） | WriteRight 显示名称、原创橙白图标、深浅色设计、首页/练习/历史/我的；`design/previews/` 有实际截图 |
| P2 本地写作 | 已验证（本机） | SwiftData 分版本库、Repository、题目 revision/确认、草稿自动保存、重启恢复、词数/分句、不可变提交快照、搜索/题型筛选、同题新稿、练习导出 |
| P3 模型契约 | 已验证（工程 PoC） | 独立 A/B Rubric、共享 Schema、DeepSeek Provider、UTF-16 合成、校验/有限重试；见 `P3_ModelValidation.md` |
| P4 账号与权限 | 已验证（本机/模拟器） | 邮箱 OTP、Keychain 会话、刷新/退出、账号分库、游客草稿显式迁移、核心云表、RLS、私有 Storage、邮箱变更 |
| P5～P9 | 未开始 | 批改 Job/报告 → 图片/OCR → 同步 → 学习积累 → 完整验收 |

## 本轮检查结果

- `npm run check`：格式、Lint 与全部后端/脚本类型检查通过。
- `npm test`：30 项通过，含非法分数/引用、原文一致性、重复修改、数字变化、截断/空输出和有限重试边界。
- `npm run test:db`：25 项 pgTAP 测试通过，覆盖两用户读写隔离、跨账号外键、不可变提交、评分保护、匿名拒绝和私有对象路径。
- `npm run test:ios`：13 项单测 + 6 项 UI 测试通过（`artifacts/ios-tests-20261029-180319.xcresult`），覆盖游客草稿迁移、两账号隔离、OTP 登录和退出。
- 本地 Mailpit 实际收到 6 位验证码，OTP 验证、token 刷新、退出和邮箱变更均通过；没有向真实邮箱发送邮件。
- iOS 工程构建成功，编译产物的 `CFBundleDisplayName` 确认是 WriteRight。模拟器浅色/深色大字号导航、正文写作、切后台保存和重启恢复已验证。
- 真实模型 PoC：首轮 7 请求中 5 通过、2 安全拒绝；修复边界后定向复测 3 请求全部通过。总计 15 次实际模型调用，失败码、用量和耗时均记录，没有用合成结果宣称人工评分准确率。

## 本轮修正

- 题目、要点、正文统一焦点控制，键盘工具栏可收起所有输入框的键盘，确认按钮不会因测试点中键盘工具栏而误判成功。
- “题目已确认”在返回和重启后保持，改题面/要求会失效并增加 revision。
- 保存失败保留编辑内容并允许重试；后续草稿编辑不能覆盖已提交快照。
- App 更名不移动初次开发的本地存储路径，保留已有数据的连续性。
- 模型可选优化不能混入最小修改稿，同一句不允许重复修改；英文基数词转数字造成的误报已修正并有回归测试。
- P4 使用 iOS 26 `glassEffect`，旧系统回退到 `regularMaterial`；登录页只保留必要输入、主操作和状态。实际截图：`design/previews/login-otp.png`。
- 本地 Auth 需要 `confirmation` / `magic_link` 模板键匹配 GoTrue 环境变量；已修正并实际验证验证码邮件。

## 下一阶段与验收边界

下一阶段是 P5：幂等批改提交、持久 Job、分阶段 Worker、失败恢复和客户端完整报告。

当前 App 可以本地写作、登录并隔离账号数据，不提供未实现的在线批改按钮。OCR、多设备同步、评分报告、收藏/分析尚未接入。完整 VoiceOver 操作、真实手写相机、iPhone 签名/性能、正式 SMTP、双设备同步和独立人工评分基线，分别留在对应阶段验收。P4 Migration 仅在本机验证，未部署到开发项目。

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
