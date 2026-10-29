# EssayPilot

考研英语（二）AI 作文批改原生 iOS App。目标技术栈为 SwiftUI、SwiftData、VisionKit/Vision、Supabase 和 DeepSeek。

当前交付范围是**开发环境与工程骨架**。登录、作文编辑、OCR、真实批改和云同步等产品功能尚未实现。

- [产品与系统设计](EssayPilot_V1_需求分析与系统设计.md)
- [开发环境与工具协作](docs/DevelopmentSetup.md)
- [本机实际准备与验证结果](docs/EnvironmentStatus.md)
- [开发进度](docs/progress.md)
- [AI 工具共同规则](AGENTS.md)

## 开始开发

```bash
npm ci
npm run env:check
npm run check
npm test
```

后端开发：先启动 OrbStack，然后执行：

```bash
npm run backend:start
npm run functions:serve
```

新克隆的工作区需先将 `.env.example` 复制为 `supabase/.env.local`；已有该文件时保留原配置。

本地控制台：`http://127.0.0.1:54323`；本地测试邮件：`http://127.0.0.1:54324`。

iOS 开发：使用完整 Xcode 打开 `ios/EssayPilot.xcodeproj`。修改工程定义后重新生成：

```bash
npm run ios:generate
npm run ios:build
npm run ios:run
```

## 目录

```text
ios/                  SwiftUI 工程与 XcodeGen 定义
supabase/             本地配置、迁移、Edge Functions
schemas/              后续添加共享 JSON Schema
prompts/              后续添加版本化评分与纠错 Prompt
tests/backend/        后端工具链与健康检查测试
scripts/              环境检查与启动/构建脚本
docs/                 环境、进度和验证记录
```

## 凭据

`.env.example` 仅包含占位符。真实服务端密钥保存在 `supabase/.env.local` 或云端 Supabase Secrets；签名覆盖配置使用 `ios/Config/Local.xcconfig`。这些文件已被 Git 忽略。

客户端只能包含 Supabase URL 与客户端公钥，不能包含 DeepSeek API Key、Supabase secret/service-role key。Kimi、Codex 的登录凭据由工具自身管理。

开发中的模拟器构建无需签名；安装到真机前必须在 Xcode 中配置自己的 Team 和唯一 Bundle ID。
