# WriteRight

考研英语（二）AI 作文批改原生 iOS App。目标技术栈为 SwiftUI、SwiftData、VisionKit/Vision、Supabase 和 DeepSeek。

面向用户的名称为 **WriteRight**，仓库与 Swift 模块保留 EssayPilot。

当前已完成品牌与图标、四页导航和本地写作闭环：题目确认、自动保存、重启恢复、历史搜索与筛选。模型 Provider、共享 Schema 和工程 PoC 已验证。账号、在线批改报告、OCR、云同步及学习分析仍按后续阶段实施。

- [分阶段开发计划与验收](WriteRight_分阶段开发计划.md)
- [产品与系统设计](EssayPilot_V1_需求分析与系统设计.md)
- [开发环境与工具协作](docs/DevelopmentSetup.md)
- [本机实际准备与验证结果](docs/EnvironmentStatus.md)
- [开发进度](docs/progress.md)
- [AI 工具共同规则](AGENTS.md)
- [设计规范](docs/DesignSystem.md)
- [模型工程验证记录](docs/P3_ModelValidation.md)

页面预览：[首页](design/previews/home-light.png)、[编辑](design/previews/editor.png)、[深色大字号](design/previews/home-dark-accessibility.png)。

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
npm run test:ios
```

## 目录

```text
ios/                  SwiftUI 工程与 XcodeGen 定义
supabase/             本地配置、迁移、Edge Functions
schemas/              共享 JSON Schema 的链接入口
supabase/functions/_shared/grading/  版本化 Rubric/Prompt、Provider 与校验器
tests/backend/        批改校验、Provider 与健康检查测试
tests/fixtures/       合成工程样本（不作为人工 Golden Set）
design/               原创图标、实际生成提示词和模拟器截图
scripts/              环境检查与启动/构建脚本
docs/                 环境、进度和验证记录
```

## 凭据

`.env.example` 仅包含占位符。真实服务端密钥保存在 `supabase/.env.local` 或云端 Supabase Secrets；签名覆盖配置使用 `ios/Config/Local.xcconfig`。这些文件已被 Git 忽略。

客户端只能包含 Supabase URL 与客户端公钥，不能包含 DeepSeek API Key、Supabase secret/service-role key。Kimi、Codex 的登录凭据由工具自身管理。

开发中的模拟器构建无需签名；安装到真机前必须在 Xcode 中配置自己的 Team 和唯一 Bundle ID。
