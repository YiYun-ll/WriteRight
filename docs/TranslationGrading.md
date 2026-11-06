# 英语二翻译批改（2026-11-05）

## 范围与流程

练习页先选择小作文（A/10分）、大作文（B/15分）或翻译（T/15分），再选择照片或文字。批改任务、继续写、同题再练、最近报告与历史沿用原有存储和任务机制。无障碍字号下题型单列，操作图标与标题上下排列；历史与报告筛选改用菜单，避免四项分段文字挤压。

翻译为英语二英译汉。文字编辑器分别输入完整英文原文、中文译文、可选参考译文及练习要求。原文通过现有题目确认动作冻结；参考译文变化使确认失效。照片分别收集英文原文与中文译文，每类最多4页，直接随角色/页序发送给模型，不运行OCR，不增加转录或确认步骤。参考译文可选文字输入；没有参考译文也可批改。

所有题型使用现有服务端 `DeepSeekAdapter` 和 `deepseek-flash`，基址 `https://api.deepseek.com`。API Key继续由服务端环境配置；客户端不存放密钥。

## 独立评分与报告

- 翻译专用 `KY_EN2_TRANSLATION_V1` / `WRITERIGHT_TRANSLATION_V1`，报告 `schema_version=3.0.0`。A/B的评分版本及历史合同保留，作文提示词显式拒绝T，避免意外套用作文标准。
- 逐句/意群划分模拟采分点，满分合计15，0.25分精度。文字练习要求明确“5句专项”时校验恰好5句，每句3–4个采分点、满分3。照片普通练习按原文内容量分配15分。
- 逐句提供英文原句、学生原译、每点含义/满分/实得/理由、问题解释、句子主干与翻译方法、修改译文。原译保留错误；文本引用必须来自原输入，顺序、覆盖和重复引用受校验。照片引用携带原文页码及译文页码，仅用于最终报告。
- 总分由程序汇总：`max(0, 各采分点实得合计 − 错别字扣分)`。不影响原意的中文错别字每满3个扣0.5，余1–2个扣0.25；已算误译的错误不得重复列入错字。错字必须能在学生原译中找到对应出现次数。
- 总览显示各句得分、合计、错字明细及最终分数；维度为准确性、完整性、通顺性。修改稿呈现完整中文译文、加粗的主要修改及原因，支持复制；复盘给最多3个薄弱点、3–5个词组/句法与翻译方法，可收藏表达。
- 允许合理语序、拆句合句及同义表达；参考译文只作对照。是否语义等价、错字是否影响原意、是否重复扣语义分，仍需人工样本评估，程序不能证明语义正确性。
- 缺英文原文、读图不清或反馈覆盖不足：总分为空，明确需补充的信息，不生成完整修改稿或错字扣分。疑句采分点实得为空、不给猜测修改，不把识图疑点当学生错误。清楚可读但漏译的句子正常按漏译评价。

## 合同与持久化

接口沿用 `submit-grading`、`submit-photo-grading`、`grading-status` 与 `grading-worker`。`task.part`新增T，`task.referenceTranslation`为可选文本。Swift `WritingTaskDocument.referenceTranslation`、`GradingReportPayload.translationReview`均可选，兼容旧JSON。SwiftData继续保存原有文档JSON，无须增加本地实体/CloudKit同步。

`translation-assessment.schema.json`定义模型评估结果，`translation-report.schema.json`引用它并定义最终报告。模型不提供总分、版本或来源元信息；服务端生成，并在持久阶段恢复后重新校验。非法JSON/结构/采分点/引用可修复重试一次，错误日志只保留错误码。提供方明确不可重试错误不会重复请求。

照片内容Hash保留现有题型/角色/页序/字节校验，并在有参考译文时纳入参考文本；原文图片指纹仍只由题型与原文图片生成，以支持同题对比。已提交的参考译文保存在不可变task上下文，重试复用原快照；更改参考文本不能复用原幂等键。报告恢复校验图片路径/指纹/角色/页码。

迁移 `20261105100000_translation_grading.sql`扩大任务及报告的part约束，T允许15分，A仍只允许10分；报告分数改为numeric(5,2)，避免14.75被四舍五入成14.8。RLS、私有图片、账号边界、队列租约和服务端函数权限不变。中文翻译不计算“每100英文词错误密度”。

## 验证与发布边界

实际检查见 `docs/progress.md`。2026-11-05 已按用户后续授权将迁移与翻译相关函数部署至现有 EssayPilot-dev，并完成真实 deepseek-flash 云端文字、2+2页合成印刷图片与缺原文联调，41项检查通过。测试依赖现有分钟cron，没有手动唤起Worker；两个一次性测试账号及图片已清理。UI合成报告仍仅属于Debug界面证据，与本次真实云结果分别记录。真实多页手写、人工评分质量与真机摄像头验收尚待完成。

发布时需先迁移数据库约束，再同步发布提交/worker函数，最后发布支持T及3.0.0报告的客户端。旧客户端不认识T，不能让旧客户端拉到T文档后将解码失败误称为同步成功；正式多版本发布需要最低客户端版本策略或服务端按能力过滤的独立工作，当前开发版本同步必须使用新客户端。


### 实际部署与联调命令

```sh
node scripts/apply-translation-cloud-migration.mjs --apply --project-ref YOUR_LINKED_PROJECT_REF
npm exec supabase functions deploy -- submit-grading submit-photo-grading grading-worker --project-ref YOUR_LINKED_PROJECT_REF --use-api --jobs 2
swift scripts/generate-translation-fixtures.swift
NODE_USE_ENV_PROXY=1 node scripts/test-cloud-translation.mjs --live --project-ref YOUR_LINKED_PROJECT_REF
```

迁移脚本核对linked ref、从版本化SQL执行单一事务并登记相同原文；重复执行只校验历史，不重复改表。云验收需要 `tests/private/cloud-translation/source-1.jpg`、`source-2.jpg`、`answer-1.jpg`、`answer-2.jpg` 四张合成图片，英文/中文内容取 `tests/fixtures/grading/translation-live.json`，分页为前三句/后两句。CLI只在脚本内读取测试凭据，不将token/密钥写入日志或证据。验收会真实计费、创建和清理一次性账号，应只在明确授权的linked项目运行。

证据：`artifacts/cloud-translation-20261105/2026-11-05T10-30-40-703Z/acceptance.json`，实际原生DTO解码：`artifacts/cloud-translation-20261105/native-decoding.json`，原文/图片/完整报告仅保留在ignored `tests/private/cloud-translation/`。
