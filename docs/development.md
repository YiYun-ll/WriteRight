# 开发指南

## 环境

- Xcode 与 iOS 模拟器 SDK，最低部署目标为 iOS 17。
- XcodeGen，用于从 `ios/project.yml` 生成工程。
- Node.js 22.19+ 与 Deno 2.9.6。
- Supabase CLI 由项目 npm 依赖提供；本地数据库需要可用的 Docker 环境。

## 安装与检查

```bash
npm ci
npm run env:check
npm run check
npm test
```

后端检查覆盖格式、lint、类型和单元测试。GitHub Actions 会对推送到 `main` 和 Pull Request 的后端变更运行同类检查。

## iOS 工程

```bash
npm run ios:generate
npm run ios:build
npm run ios:run
npm run test:ios
```

`ios/EssayPilot.xcodeproj` 由 XcodeGen 生成。修改目标、源码目录或构建设置时，应编辑 `ios/project.yml` 并重新生成，避免只修改工程文件。

本地签名和客户端公开配置从示例开始：

```bash
cp ios/Config/Local.xcconfig.example ios/Config/Local.xcconfig
```

按需填写 `DEVELOPMENT_TEAM`、`SUPABASE_HOST` 和 `SUPABASE_PUBLISHABLE_KEY`。`Local.xcconfig` 已被 Git 忽略，不能放入 DeepSeek Key、service-role key 或签名私钥。

## 本地 Supabase

```bash
cp .env.example supabase/.env.local
npm run backend:start
npm run test:db
npm run functions:serve
```

常用地址：

- API：`http://127.0.0.1:54321`
- Studio：`http://127.0.0.1:54323`
- 测试邮件：`http://127.0.0.1:54324`

停止本地服务：

```bash
npm run backend:stop
```

## 测试边界

- `npm test`：后端确定性单元测试。
- `npm run test:db`：本地数据库迁移、权限和函数测试。
- `npm run test:ios`：模拟器原生单元与界面测试。
- `npm run test:grading`：真实付费模型集成测试，仅在配置好本地 Worker 后显式运行。

测试使用合成样本。私人材料只能放在已被忽略的 `tests/private/`，不得进入 Git、Issue 或 CI 日志。

## 发布变更

数据库变更必须提交新迁移，不以控制台手工修改代替。契约变化需同步更新 Edge Function、Swift DTO、共享 Schema 和回归测试。云端部署、套餐调整及生产数据操作不属于本地开发步骤，必须单独确认目标与授权。
