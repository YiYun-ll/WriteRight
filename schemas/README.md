# 共享契约

`report.schema.json` 与 `task-parse.schema.json` 是 JSON Schema 2020-12 契约入口，当前核心报告版本 1.0.0，提取自初版设计文档。文件通过 Git 符号链接指向 `supabase/functions/_shared/contracts/` 的唯一源文件，使 Edge Function 打包不依赖容器外路径。

报告结构校验使用锁定版本 Ajv 8.17.1；分数、引用、版本、必要修改及有限数字事实校验在 `_shared/grading/validation.ts`。服务端词数与原文区间为权威值，模型不得生成可信定位。

Swift 当前实现本地题目/草稿/不可变提交 DTO；报告 DTO 及其解码在 P5 随客户端报告一起接入。题目解析实际调用及确认 UI 在 P6 完成。

修改契约时同步更新 Swift DTO、后端校验与回归样本。
