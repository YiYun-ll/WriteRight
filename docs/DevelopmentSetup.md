# 开发环境与工具协作

基准日期：2026-10-29（Asia/Shanghai）。实际验证结果见 `EnvironmentStatus.md`。

## 工具版本

| 工具 | 基准版本/选择 | 作用 |
| --- | --- | --- |
| Node.js | 24.14.1 | 开发工具运行环境；不作为 iOS 运行时 |
| Supabase CLI | 2.122.0，项目 devDependency | 本地服务、迁移、部署 |
| Deno | 2.9.6 | 后端检查与测试 |
| Kimi Code CLI | 2.4.0 | 在 Cursor 终端中使用的编码助手 |
| XcodeGen | 2.46.0 | 从 `ios/project.yml` 生成工程 |
| Xcode | 27.2（27B52），本机 macOS 27.2；2026-10-30 实测 | SDK、模拟器、构建、签名 |
| OrbStack | 2.2.5 | 本地 Docker 运行环境 |

Xcode、手机 iOS 与 macOS 版本需匹配；若真实设备系统较新，先核对官方兼容表。

## 新机器准备

1. 从 Apple 官方安装兼容的完整 Xcode，首次启动并安装 iOS 平台组件。
2. 从官方源安装 Node.js、OrbStack，启动 OrbStack。
3. 安装 CLI，然后进入项目运行 `npm ci`。

```bash
npm install --global --prefix "$HOME/.local" @moonshot-ai/kimi-code@2.4.0 deno@2.9.6
```

用户终端 PATH 需包含 `$HOME/.local/bin`。Supabase 使用项目内锁定版本，不要求全局安装。

XcodeGen 可从官方 2.46.0 release 下载 `xcodegen.zip`，将其中 `xcodegen/bin/xcodegen` 放入项目的 `.tools/bin/xcodegen`，并将 `xcodegen/share/` 完整复制到 `.tools/share/`。默认 SettingPresets 必须与可执行文件一起安装；也可用包管理器完整安装后通过 PATH 使用。

```bash
npm ci
npm run env:check
npm run ios:generate
npm run ios:build
```

## Cursor、Codex、Kimi Code

- Cursor 打开整个 `EssayPilot` 目录，Xcode 打开 `ios/EssayPilot.xcodeproj`。
- 推荐扩展记录于 `.vscode/extensions.json`：官方 Codex、Swift、Deno。
- Codex 可从桌面应用或 Cursor 扩展使用；同一个任务选用一个写入入口。
- Kimi Code 在 Cursor 的终端运行 `kimi`；首次使用按提示登录。
- Cursor 命令面板运行 `Tasks: Run Task`，可选择预置的 Kimi Code、环境检查、本地后端、函数服务和 iOS 构建/运行任务。
- 三者共用根目录的 `AGENTS.md`。不要复制成三套相互冲突的规则。
- 用户已指定评分与题目解析均使用 `deepseek-flash`，覆盖原始设计文档中建议的 Pro 默认值。
- 聊天历史不自动互通；将任务进度、验证结果和后续工作写入 `docs/progress.md`。
- 同一 checkout 一次只允许一个 AI 写入。需要并行开发时，创建独立 Git worktree。
- Swift 扩展依赖完整 Xcode 的 SourceKit 工具链；仅安装扩展不等于可以编译 iOS。
- `npm run ios:run` 会构建最新代码，选择可用 iPhone 模拟器、安装并启动 App。模拟器图形界面可从 Xcode 的 Open Developer Tool → Simulator 打开。

建议任务交接格式：目标、允许修改的目录、接口约束、完成条件、已执行检查、未完成事项。

## 本地后端

```bash
npm run backend:start
```

启动脚本创建 `essaypilot-local` Docker 网络，并将服务映射绑定至 `127.0.0.1`。若已有同名网络的绑定不符合要求，脚本会停止并报错。

| 服务 | 地址 |
| --- | --- |
| API | http://127.0.0.1:54321 |
| PostgreSQL | 127.0.0.1:54322 |
| Studio | http://127.0.0.1:54323 |
| 本地测试邮件 | http://127.0.0.1:54324 |

本地邮件只进入 Mailpit，不发送到真实邮箱。

第一次克隆工作区时，将 `.env.example` 复制为 `supabase/.env.local`，再填写真实配置。已经存在该文件时不要覆盖。函数启动命令明确读取这个忽略文件，并使用与 API 网关相同的 `essaypilot-local` 网络。

```bash
npm run functions:serve
curl --fail http://127.0.0.1:54321/functions/v1/health
```

`health` 是不包含用户数据的公开探针。实际业务接口后续必须分别实现认证、所有权校验与配额限制。

```bash
npm run check
npm test
npm run backend:stop
```

## 云端与真实 AI

- 本地、云端开发项目、正式私用项目分别配置。
- `npx supabase login` 使用官方登录流程，凭据由 CLI 管理。
- 创建或连接开发项目后，用迁移管理数据库；勿把修改仅保留在网页控制台。
- 真实 DeepSeek Key 只写入 `supabase/.env.local`，再经 CLI 上传为项目 Secrets。
- 不在聊天、README、Git、构建日志中粘贴密钥；只核验密钥是否存在与请求结果。
- 正式邮箱 OTP 需要自定义 SMTP 和包含 `{{ .Token }}` 的邮件模板。
- 在接入实际 AI 前保持 Mock，先用合成数据验证接口和错误恢复。
- 当前业务表、RLS、持久队列、真实 AI Provider 和开发云已接入；仍需分别运行数据库与真实云验收。health只证明静态函数存活，不代表邮件/队列/模型都正常。新记录与学习反馈的迁移/部署见NotebookAndLearning.md。

## 真机

在 Xcode 的 Signing & Capabilities 中选择自己的 Team，必要时覆盖开发 Bundle ID，连接 iPhone 并按系统提示完成信任与 Developer Mode。相机、手写 OCR、Keychain、签名和跨设备同步都需真机另行验收。

2026-10-30 已安装官方 Xcode 27.2 至 `/Applications/Xcode.app`，首次组件配置通过，默认 CLI SDK 为 27.2。旧 Xcode 26.3 已移至用户废纸篓，未清空。现有项目通过新版模拟器构建、真机无签名构建和真机签名构建，并已实际安装、启动在 iOS 27.2 的 iPhone 上。Personal Team 配置只保存在 ignored `ios/Config/Local.xcconfig`，证书和私钥在本机钥匙串。

当前真机安装包的 Supabase 地址与公开 key 未配置；本地写作、系统相册和 Vision 可以使用，联网登录/AI 批改不能据此宣称通过。模拟器前轮真实后端验收使用 DEBUG 环境覆盖，不自动适用于这个真机安装包。连接手机可访问的测试后端仍是后续独立配置项；不要将模拟器 localhost 地址直接填入手机。

## 官方来源

- https://developer.apple.com/xcode/system-requirements
- https://developer.apple.com/download/all/?q=Xcode%2026.3
- https://learn.chatgpt.com/docs/codex/ide
- https://learn.chatgpt.com/docs/agent-configuration/agents-md
- https://cursor.com/docs/rules
- https://www.kimi.com/code/docs/en/kimi-code-cli/guides/getting-started.html
- https://docs.deno.com/runtime/getting_started/installation/
- https://supabase.com/docs/guides/local-development
- https://supabase.com/docs/guides/functions/development-environment
- https://supabase.com/docs/guides/auth/auth-smtp
- https://orbstack.dev/download
- https://github.com/yonaskolb/XcodeGen/releases/tag/2.46.0

## 2026-10-30 本地调度与扫描检查

本地函数服务运行时执行 `npm run backend:worker:configure`，补齐已有 cron 的本地加密 Vault 配置。详见 [LocalWorker.md](LocalWorker.md)。`npm run test:worker-schedule` 是显式真实模型合成测试，不访问生产。

`npm run test:ocr-layout` 现执行 12 项共享 Foundation/ImageIO XCTest，覆盖忠实排版、UTF-16 区间、上传预算与透明白底。它不依赖 simulator deviceservice，不可代替完整 iOS UI 套件通过声明。
