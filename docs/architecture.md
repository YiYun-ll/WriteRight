# 架构说明

## 客户端

`ios/EssayPilot` 是 SwiftUI 应用，产品名为 WriteRight，Swift 模块保留 EssayPilot。

- `App/`：应用入口、组合根与跨页面业务状态。
- `Features/`：首页、练习、报告、记录和账号等功能视图。
- `Domain/`：题目、草稿、提交、报告、翻译与学习记录模型。
- `Core/`：认证、批改、同步、图片、系统活动与通用能力。
- `Persistence/`：SwiftData 本地存储和迁移。
- `Shared/`：客户端与 Widget Extension 共用的数据模型。
- `WriteRightWidgets/`：主屏幕小组件、锁屏实时活动与灵动岛。

视图通过业务模型和用例访问能力，后端请求与持久化细节不放在视图层。SwiftData 负责本地数据，未启用自动 CloudKit 同步。

## 批改流程

小作文、大作文和翻译使用独立且版本化的评分标准。题目与作答均可选择文字或照片，任一侧包含照片时走照片批改管线，纯文字走文字管线。

照片与当前选择的文字一起形成不可变提交快照，直接发送给模型，不经过 OCR 或独立转录确认。原图保留用于报告回看；引用只服务于最终反馈，无法辨认的内容不得转换为学生错误。

```text
练习输入 → 不可变提交 → 持久任务队列 → Grading Worker
                                      → 模型适配与重试
                                      → Schema / 语义校验
                                      → 版本化报告 → 本地保存与回看
```

## 服务端

`supabase/functions` 包含认证任务提交、照片提交、状态查询、Worker、账号删除和健康检查等 Edge Functions。

`_shared/grading` 存放评分提示词、模型适配器、校验器与版本化合同。JSON Schema 只负责结构边界，分数、引用、数字事实和来源覆盖还需确定性校验。历史合同保留，旧报告不被重写。

`supabase/migrations` 是数据库结构的唯一版本来源。账号数据由 Row Level Security 隔离，私有图片通过认证访问，Worker 使用独立服务端凭据。

## 同步与备份

登录后，客户端通过 Supabase 同步账号自己的练习、报告、记录和陪伴状态。离线编辑先保存在本机；冲突与删除需要保留明确语义，不能以晚到响应覆盖同步期间的新编辑。

备份采用合并导入，不覆盖当前内容。原图按内容指纹缓存并校验，损坏缓存不能替代原稿。

## 密钥边界

客户端只包含 Supabase URL 与 publishable/anon key。DeepSeek Key、service-role key、SMTP 凭据和 Worker token 仅存在于服务端密钥管理或本地被忽略的配置中。模型输入、学生作文和导入内容始终作为数据处理，不作为开发者指令。
