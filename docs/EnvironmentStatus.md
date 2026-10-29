# 开发环境实际状态

检查日期：2026-10-29（Asia/Shanghai）。本文件记录环境准备与验证结果；产品阶段验收见 `progress.md`。

## 仓库与云端

| 项目 | 结果 |
| --- | --- |
| GitHub | `YiYun-ll/EssayPilot`，已确认 private，默认分支 main |
| 初始提交 | 已推送到私有仓库 |
| GitHub CI | Backend checks 首次执行成功 |
| Supabase 登录 | CLI 已登录，已实际读取组织与项目 |
| Supabase 组织 | EssayPilot，`tlvqxgmnksvklwaeasao` |
| Supabase 开发项目 | EssayPilot-dev，`tdcxdiqvrfmppaqikgxu` |
| 区域 | ap-southeast-1（Singapore） |
| 云端健康接口 | `https://tdcxdiqvrfmppaqikgxu.supabase.co/functions/v1/health`，HTTP 200 |
| DeepSeek | 认证 HTTP 200，模型列表确认 `deepseek-flash` 可用 |
| 服务端配置 | DeepSeek Key、Base URL、评分/解析模型与 AI Provider 已写入开发项目 Secrets |

仓库：https://github.com/YiYun-ll/EssayPilot

开发项目：https://supabase.com/dashboard/project/tdcxdiqvrfmppaqikgxu

首次 CI：https://github.com/YiYun-ll/EssayPilot/actions/runs/40830394232

## 本机工具

| 工具 | 实际状态 |
| --- | --- |
| Node.js | v24.14.1 |
| Kimi Code CLI | 2.4.0；已有 OAuth provider 配置，doctor 校验通过 |
| Deno | 2.9.6 |
| Supabase CLI | 2.122.0，锁定于 package-lock.json |
| OrbStack | 2.2.5，macOS 签名校验通过，Docker 引擎正常 |
| XcodeGen | 2.46.0，已成功生成 Xcode 工程 |
| Xcode | 26.3（17C529），已安装、校验签名并完成首次授权 |
| Xcode 账号 | 已登录并实际加载 Personal Team；未创建新的签名证书 |
| 开发工具目录 | `/Applications/Xcode.app/Contents/Developer` |
| iOS SDK | 26.2，已可被 xcrun 识别 |
| iOS 模拟器运行时 | 26.2（23C54）arm64，系统签名 Verified、状态 Ready |
| Cursor | 3.27.22，已恢复安装；签名、公证、CLI 与实际项目窗口均验证通过 |
| Cursor 扩展 | Codex、Swift、Deno 已安装 |
| Cursor 命令 | 用户级 `cursor` 命令已配置，已打开项目 |
| Git | 使用 Xcode 提供的 Git；仓库配置了独立的 GitHub noreply 身份 |

## 已完成的验证

- `npm run check`：格式、lint、TypeScript 类型检查通过。
- `npm test`：2 项后端基础测试通过。
- SwiftUI 源码：通过面向 iOS 17 的 `swiftc -typecheck`。
- `npm run env:check`：全部工具链检查通过。
- `npm run ios:build`：真实 iOS 模拟器构建成功。
- `npm run ios:run`：安装并启动到 iPhone 17 / iOS 26.2，实际界面显示 EssayPilot 启动页；进程检查通过。
- 本地 Supabase：数据库、认证、存储、Studio、Mailpit 启动并健康。
- 本地健康函数：修正 Docker 网络后返回 HTTP 200。
- Studio 跟随跳转后 HTTP 200；Mailpit HTTP 200。
- 合成邮箱 OTP 请求 HTTP 200，并确认 Mailpit 收到测试邮件；没有向真实邮箱发送测试邮件。
- Docker 对外映射端口检查：绑定到 `127.0.0.1`。
- 云端健康函数：已部署并实际请求成功。
- 云端服务端 Secret 名称核验齐全，未读取或输出其值。
- 本地私有服务端配置权限为 `600`。
- DeepSeek Key 未出现在 Git 跟踪文件或提交历史中。

## 私有配置

- `supabase/.env.local`：服务端配置，已被 Git 忽略。
- `ios/Config/Local.xcconfig`：仅含开发项目 URL 主机名与客户端公钥，已被 Git 忽略。
- 开发数据库密码已保存到 macOS Keychain：service 为 `EssayPilot.supabase.dev.database`，account 为 GitHub 登录名。
- `.setup/`：安装和验证日志、更新缓存备份，已被 Git 忽略；不应分享或加入仓库。已确认密码在 Keychain 后移除临时密码备份，并清理用完的安装大文件。
- 真实 API Key 不进入 iOS 应用、Git、README 或 CI。

## 尚待完成或另行准备

- 当前未连接 iPhone，不能完成真机信任、Developer Mode、签名安装和相机测试。
- 云端正式 SMTP 尚未配置；开发阶段本地 Mailpit 可用，面向普通测试用户前需准备邮件服务。
- 登录、业务表/RLS 和评分 Provider 已完成本机阶段验证；OCR、持久队列与同步等是后续产品开发任务。

## 安装过程中的处理

Xcode 自动获取组件索引在当前网络路径下失败。已从 Apple 官方地址直连获取索引，并暂时设置 Xcode 使用该本地索引；运行时安装完成后已恢复原自动索引设置。

iOS 26.2 正式运行时从 Apple 官方资源目录选择 `23C54` arm64 版本。分段下载已通过官方目录的 SHA-256 校验，使用 macOS 自带 AEA 与 AppleArchive 资源提取工具还原，再由 `simctl runtime add` 验证签名并导入系统存储。

Cursor 曾出现应用文件不完整与旧 ShipIt 更新任务处于反复启动状态。已停止旧任务、备份其更新缓存，通过 Finder 从官方公证安装包完整重装。现有账号、设置和扩展数据保留；已验证正常打开 EssayPilot 项目。

XcodeGen 的默认 SettingPresets 资源已随可执行文件完整安装，重新生成的工程通过实际构建。构建日志仅有未使用 AppIntents 框架的元数据提取提示，不影响启动。
