# P3 · 模型工程验证记录

日期：2026-10-29。模型：`deepseek-flash`。样本来自 `tests/fixtures/grading/samples.json`，均为本项目编写的合成内容，不含真实用户作文，没有人工评分标签。

## 已落地

- A/B 独立 Rubric 与六档合法性校验；缺少已确认题目时只允许语言批改，总分、档位和区间均为 null。
- JSON Schema 2020-12 严格结构校验；程序生成词数、SHA-256、句子 ID/UTF-16 区间和版本字段。
- 必改/可选区分、原句逐字匹配、重复纠错拒绝、要点和证据引用校验；最小修改稿按降序区间替换，不采用模型生成的整篇最小稿。
- 必要语言纠错保留原句数字；增强稿新增数字保守拦截，允许明确英文基数词转换（two → 2）。
- DeepSeek Adapter：HTTPS、JSON 模式、关闭 thinking、6500 输出 token 上限、45 秒单次超时、最多两次尝试。记录安全错误码、用量和耗时，不记录原文/凭据到日志。
- 30 项后端测试通过（含原有 2 项健康检查）。PoC 是开发脚本，没有公开未鉴权的批改入口；持久 Job 和客户端报告在 P5 实现。

## 第一轮：识别问题

Prompt：`WRITERIGHT_GRADING_V1`。7 个请求、10 次实际模型调用，5 个最终通过，2 个被拒绝。

| 样本 | 最终结果 | 模拟分数 | 每次耗时（秒） | 输入/输出 token 合计 | 拦截/重试原因 |
| --- | --- | --- | --- | --- | --- |
| A-invitation | 通过 | 8 | 6.94 | 1892 / 1015 | — |
| A-grammar | 通过 | 5 | 6.59 / 6.33 | 3462 / 2257 | JSON |
| B-chart | 通过 | 12 | 7.89 | 2062 / 1287 | — |
| B-static-facts | 安全拒绝 | 无总分 | 6.01 / 6.16 | 3756 / 2080 | OPTIONAL_CHANGED_MINIMAL, DUPLICATE_CORRECTION |
| B-language-only | 通过 | 无总分 | 6.48 | 1567 / 1082 | — |
| A-embedded-instruction | 通过 | 9 | 6.25 | 1989 / 943 | — |
| A-invitation-repeat | 安全拒绝 | 无总分 | 6.91 / 5.51 | 3808 / 1992 | REWRITE_NEW_NUMBER, REWRITE_NEW_NUMBER |

两份失败均没有作为完成报告交付：静态图表样本混淆必改和可选、产生重复原句修改；邀请信重复样本将正文的英文时间 two 写成数字 2，触发了过于保守的数字拦截。后一项属于校验器误报。

## 定向复测：修正可复现边界

Prompt 升为 `WRITERIGHT_GRADING_V1_1`，明确同一句合并必要修改、可选建议只放 optional_upgrade；校验器接受明确基数词的等价数字。没有放宽分数、原句引用或重复修改限制。

| 样本 | 最终结果 | 模拟分数 | 每次耗时（秒） | 输入/输出 token 合计 | 拦截/重试原因 |
| --- | --- | --- | --- | --- | --- |
| A-invitation | 通过 | 9 | 7.77 / 5.93 | 3938 / 2007 | JSON |
| B-static-facts | 通过 | 11 | 5.77 / 6.70 | 3886 / 1940 | JSON |
| A-invitation-repeat | 通过 | 9 | 6.01 | 1960 / 923 | — |

三份定向复测均通过，消耗 5 次调用。整个已认证 PoC 共 15 次模型调用，输入 28,320 token、输出 15,526 token。每次模型尝试耗时 5.51～7.89 秒；重试时整个请求更长。这不是价格承诺或长期性能结论。

新提示词下两次相同邀请信都是 9 分；旧提示词的一次结果为 8 分。跨 Prompt 的变化不能用来证明同版本稳定性，两个重复结果也不足以说明评分可靠。B 缺题样本正确返回无总分。

## 必须延续的风险

1. 本轮共有 3 次模型输出不能直接 JSON.parse，由一次重试恢复。不能因启用 JSON 模式就跳过解析、业务校验和失败恢复。P5 应拆分持久化阶段，保留有限修复和失败状态。
2. 数字守卫不能证明语义一致性：日期/人物/角色、单位、主题和数字关系仍可能被改变；英文数字解析仅覆盖明确的 0～99 基数词，不是通用语义系统。高风险事实在 P5/P6 增加复核，并由 P9 人工基线评价。
3. 合成样本只验证结构和异常处理，没有 MAE、人工分档一致率、误改率或手写 OCR 质量结论。P9 需要 30～50 份独立人工复核样本。
4. 题目确认标记来自调用方；用户确认本身不能证明题面真实完整。图像解析、uncertain 字段和题面可靠性在 P6 闭环。
5. 端侧 NLTokenizer 与服务端 Intl.Segmenter 可能产生不同分句，报告必须带回服务端的原文区间，不能按句序号重新匹配。P5 接口应以服务端快照为准。
6. 题目解析 Schema 已提取并版本化；图像解析实际调用仍属 P6，没有提前宣称通过。

## 复现与文件

离线检查：`npm run check && npm test`。有正确服务端密钥后，执行 `npm run poc:grading` 会产生付费 API 请求；不在 CI 自动运行。

定向运行示例：

```bash
npm run poc:grading -- --sample=B-static-facts --output=artifacts/grading-poc-targeted.json
```

脚本只允许访问 DeepSeek 和本机现有代理 `127.0.0.1:7890`。代理端口不同时需明确调整网络许可；不要扩大到任意主机。

完整合成输出在本机忽略目录 `artifacts/grading-poc-initial.json` / `artifacts/grading-poc-refined.json`。本文件只保留可审查的摘要；没有把这些结果标作人工 Golden Set。

API 依据：DeepSeek 官方 [Chat Completion](https://api-docs.deepseek.com/api/create-chat-completion/) 与 [JSON Output](https://api-docs.deepseek.com/guides/json_mode/)，核对日期 2026-10-29。
