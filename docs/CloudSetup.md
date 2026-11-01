# WriteRight 云端配置

日期：2026-10-30。手机直接连接 HTTPS 云端，不需要 Mac、本地 Docker 或本地函数服务持续运行。

## 当前项目与边界

已关联云项目 EssayPilot-dev（`tdcxdiqvrfmppaqikgxu`，新加坡）。配置前实际核查：账号、草稿、提交、报告均为 0；已存在 P4/P5 数据库迁移和 health 函数。没有重建项目或清空数据，没有升级套餐。

本轮完成同步迁移 P7、照片队列迁移和九个 Edge Functions、服务端模型配置、Vault/cron、客户端公开配置，以及 QQ SMTP 与六位验证码邮件模板。部署操作来自本轮用户「完成云端配置的全部操作」授权，覆盖此前仅本地开发的部署限制。

## 客户端与服务端各放什么

| 位置 | 内容 |
| --- | --- |
| ignored `ios/Config/Local.xcconfig` | `SUPABASE_HOST`、公开 publishable/anon key、本机 Personal Team；没有 DeepSeek/SMTP/service-role 密钥 |
| `ios/Config/AppInfo.plist` | 仅构建变量引用；Xcode 将公开地址/key 展开进 App。自定义 `INFOPLIST_KEY_*` 没有进入成品的问题已用显式 plist 修复 |
| Supabase Edge Function Secrets | DeepSeek API key、`https://api.deepseek.com`、`deepseek-flash`、独立云 Worker token |
| Supabase Auth SMTP | QQ SMTP 地址、端口、发件邮箱、授权码；不放进 App 或 Edge Function 公开响应 |
| Supabase Vault | 云端函数地址、Worker token，已有数据库 cron 每分钟唤起 Worker |
| ignored `supabase/.env.cloud` / `.env.smtp` | 本机私有配置，权限 600；不打印真实值、不提交 Git |

## 维护命令

以下是明确修改云端的命令。脚本要求项目与当前 linked ref 一致；不要把它们与仅本地的 worker 配置脚本混用。

```sh
node scripts/configure-ios-cloud.mjs --project-ref YOUR_PROJECT_REF
node scripts/configure-cloud-auth.mjs --project-ref YOUR_PROJECT_REF
node scripts/configure-cloud-auth.mjs --apply --project-ref YOUR_PROJECT_REF
node scripts/configure-cloud-worker.mjs --apply --project-ref YOUR_PROJECT_REF
```

Auth 配置脚本先检查差异，只提交明确声明的邮箱相关配置；保留邮箱验证和已有 MFA 设置。SMTP 密码通过环境引用传入 CLI，不出现在命令参数或临时 TOML 中。发件地址默认与 SMTP 登录地址一致。

部署函数：

```sh
npm exec supabase secrets set -- --project-ref YOUR_PROJECT_REF --env-file supabase/.env.cloud
npm exec supabase functions deploy -- --project-ref YOUR_PROJECT_REF --use-api --jobs 2
```

数据库版本仍以 `supabase/migrations/` 为来源。此次数据库直连报 ECONNRESET，改用官方 CLI `db query --linked` 的 HTTPS Management API 执行唯一缺少的 P7 文件，并在同一事务记录原版本号、名称和语句；没有重复应用已有迁移。

## 验证

`NODE_USE_ENV_PROXY=1 node scripts/test-cloud-photos.mjs --live --project-ref YOUR_PROJECT_REF`

这会调用真实付费模型，创建并清理一次性合成测试账号。检查云端 AI 读取两类照片、保留 `I has`、题文分离、提交幂等、云端 cron 自动报告、10 分量表、跨账号隔离与删号。测试不调用本地 Worker；证据 `artifacts/cloud-photos/acceptance.json`，正文仅在 ignored `tests/private/cloud-acceptance/`。

另一次 `--handwriting` 实际读取用户手写样本，无题面时返回 task=null、没有评分；只核对了四个指定数字锚点，不代表整体识图准确率。原图与模型全文只在 ignored `tests/private/`。

用户已在手机收到真实 QQ SMTP 验证码并确认登录；服务端确认邮箱验证及登录成功。真机 UI XCTest 启动 Runner 失败，不能据此宣称真机会话重启自动验收通过。后续修改 QQ 密码可能导致授权码失效，按 QQ 官方授权码管理页更新私有配置再应用。

## 当前照片直批接口

新入口为 `submit-photo-grading`，直接将题图和作文图送入持久队列，Worker一次看图批改，不调用 analyze-photos/transcribe-image。旧接口为历史兼容保留。合同与评分提示词见 [DirectPhotoGrading.md](DirectPhotoGrading.md)。

新增迁移可通过 `node scripts/apply-photo-cloud-migration.mjs --apply --project-ref YOUR_PROJECT_REF` 应用；在单一事务执行仓库迁移并登记历史，避免数据库直连故障。脚本仅在当前 linked 项目工作。

新的真实云验收：`NODE_USE_ENV_PROXY=1 node scripts/test-cloud-direct-photos.mjs --live --project-ref YOUR_PROJECT_REF`。14项实际通过，包括照片队列、无转录存储、私有原图回看、cron报告、跨账号隔离和删号清理，证据 artifacts/cloud-direct-photos/acceptance.json。删除账号已补齐嵌套目录及超过100张照片的分页清理。

## 官方资料

- [Supabase Secrets](https://supabase.com/docs/guides/functions/secrets)
- [Supabase 邮箱验证码](https://supabase.com/docs/guides/auth/auth-email-passwordless)
- [QQ 邮箱授权码](https://help.mail.qq.com/detail/106/985)

## 2026-10-30 21:40～21:44 在线状态复核

用户询问别人安装后是否能使用全部服务，实际复核开发云而非仅引用旧测试：项目ACTIVE_HEALTHY，9个函数ACTIVE，health/Auth健康接口HTTP200；每分钟cron启用，最近3次调用成功。Auth公开设置显示邮箱登录启用、新用户注册未禁用、仍要求邮箱验证；远程SMTP/六位验证码模板与已确认配置没有差异。QQ SMTP实际认证返回235，未发送新测试邮件，所以本轮不宣称已向接收方邮箱成功投递。

一次新的合成题图/作文图真实云端Part A批改17项通过：提交、幂等、cron自动完成、V3评分、双语修改稿/精确重点、私有原图访问、无转录、账号隔离及删除清理；昵称5项通过；独立登录会话的同步上传/拉取、冲突、删除及防复活5项通过。全部使用一次性合成账号，收尾清理，没有修改现有用户数据。未手动唤起Worker，没有改配置或部署。

侧载Release成品的HTTPS公开云配置再次检查通过，直接使用该云项目；别人不需要开发者电脑运行或服务端密钥。当前核心服务链路正常，不因免费Apple重签而主动限制已实现功能；仍需签名有效、网络/云端配额/模型额度正常。接收方iOS18.7.7的iLoader安装、Keychain、真实邮箱收件及完整App本地交互尚需首次验收；本轮云HTTP验收不能替代这些检查，也没有证明所有题型评分质量。

新证据：artifacts/cloud-availability-20261030-2140/，包含当前状态、认证设置、SMTP结果及27项工程验收摘要；之前验收文件另有备份。模型全文与合成图片仍只在ignored tests/private/。

## 持续可用的维护安排

以下是2026-10-30核查后的建议，不表示已经购买套餐、开通持续监控或执行备份。

| 项目 | 维护动作 | 当前边界 |
| --- | --- | --- |
| Supabase项目 | 查看组织Billing/Usage、暂停预警和配额；需要避免低活跃自动暂停时选择付费套餐 | 本轮没有升级或修改账单 |
| DeepSeek | 保持可用余额，监控余额不足/限流和任务失败；设置适合自己的预算提醒 | 刚完成一次真实调用，不等于余额永不耗尽 |
| QQ SMTP | 保留有效授权码，变更凭据后同步更新云配置并本人验收收件；留意退信/限流 | 认证已通过，未重新向朋友发信 |
| 后台任务 | 保持现有每分钟cron、Vault配置；监控失败率、最旧排队时长与超时 | cron和真实自动批改已测；没有外部持续告警已部署的证据 |
| 数据恢复 | 定期加密备份数据库及私有图片，保管到独立位置并演练恢复 | 本轮没有导出用户数据或执行恢复 |

### 免费与付费选择

Supabase免费项目过去7天内用户数据库活动不足时可能自动暂停；用户的真实请求和访问Dashboard可产生活动，但不能承诺永不暂停。当前health函数只返回静态服务状态，不查询数据库，因此不能把探测health或项目内部cron当作可靠的“免暂停保证”。收到预警应检查Dashboard；已暂停时按官方步骤Resume。[Supabase：项目暂停](https://supabase.com/docs/guides/platform/free-project-pausing)

截至核查日，Pro标价从25美元/月起，计费按组织管理，额外项目/资源可能另计；付费项目不因低活跃自动暂停，但仍需管理账单、资源配额和第三方服务。适合用户开始日常依赖App时考虑，不需要购买Apple开发者会员才能使用云端。[Supabase价格](https://supabase.com/pricing)、[组织计费](https://supabase.com/docs/guides/platform/billing-on-supabase)

DeepSeek余额用尽会返回402，服务限流/过载也会影响批改。不要通过不断重提相同付费任务处理余额问题；先恢复余额/服务，再按任务错误处理。API key继续只保存在云端。[DeepSeek错误码](https://api-docs.deepseek.com/quick_start/error_codes/)

### 监控建议

- 使用独立于Mac和业务项目的云端监控；每5～10分钟轻量检查接口与数据库连通，连续失败后告警并在恢复时通知。频率是建议，本轮没有创建定时任务或对外通知。
- 分别关注健康接口、真实数据库/登录、邮件投递、排队任务及模型余额。当前health HTTP200仅证明这个函数能响应，不能代表所有依赖健康。
- 日常探测不调用付费模型；另用低频合成样本做经授权的真实批改验收。监控日志不记录作文全文、邮箱、token或key。
- 监控和备份应运行在云端，而非依赖Codex桌面线程、这台Mac或本地Docker持续在线。

### 备份与恢复

Supabase建议免费项目定期导出数据库并异地保存；Pro包含每日数据库备份并保留最近7天。数据库备份不包含Storage中的实际图片文件，应另备份私有原图，限制访问并验证恢复。不能只恢复数据库就宣称原稿图片也恢复成功。[Supabase备份范围](https://supabase.com/docs/guides/platform/backups)

免费侧载的7天签名续期独立于以上云端维护；后端在线也不能让过期签名的App打开。

## 接收方移动网络不可达：2026-10-30后续反馈

接收方安装成功后实际反馈邮箱验证码发送失败。用户进一步确认同一手机Safari访问健康接口显示“已丢失网络连接”，这是客户端当前网络无法到达服务入口的证据；具体DNS、TLS或运营商线路原因尚未区分，不宣称已确认某家运营商屏蔽。

Mac只读对比中，配置的代理路径可到达Auth健康接口（未带apikey时HTTP401，证明收到网关响应），禁用代理的直接路径curl返回35/TLS连接失败。此前27项云端检查使用Mac可达路径，不能由此推断接收方5G可达。Dashboard只读日志页已查看，未取到与这次失败可靠关联的服务端错误；不把没有看到错误当作请求成功证据。

先让接收方换Wi-Fi/其他网络，对比同一只读地址与实际登录；若目标使用网络持续不可达，应选择并实测可达的自有域名/受控HTTPS网关或后端入口，覆盖Auth、REST/RPC、Functions与私有Storage全链路。不能只换登录地址、关闭TLS校验、嵌入service-role密钥或用未知公共代理转发私人作文。相关入口尚未部署，也没有修改域名、套餐或账单。

客户端构建3已改为明确区分网络/TLS、发信限流、邮件策略、登录配置、服务端故障及验证码失效，不显示原始响应正文/个人邮箱/token；这提升诊断能力，并未修复或更换网络链路。

## 2026-10-31 已授权开发云更新

EssayPilot-dev已应用20261031010000_notebook_sync迁移并发布submit-grading、submit-photo-grading和grading-worker，新报告提供句式/篇章建议及独立双语示范，记录可按账号同步。未修改套餐、账单或已有用户内容。原始题图/作文图仍一起直批，无转录步骤。部署、兼容与回退边界见NotebookAndLearning.md；实际23项真实云验收及本地测试见progress.md。旧版客户端与旧报告保持兼容，新学习内容仅新批改生成。

## 2026-11-01 已授权开发云更新（小猫成长同步）

EssayPilot-dev已应用20261101090000_companion_growth：新增companion_profiles表（RLS只读本人）与merge_companion(jsonb)合并函数，只新增表和函数，未改已有数据、函数、套餐或账单。脚本scripts/apply-companion-cloud-migration.mjs需显式--apply --project-ref且与已关联项目一致，迁移与历史登记在同一事务、重复执行无副作用。回读结果与本地pgTAP见progress.md。旧版客户端不调用该函数，行为不变。
