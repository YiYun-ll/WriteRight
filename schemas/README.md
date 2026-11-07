# 共享契约

此目录提供 JSON Schema 2020-12 契约入口，文件链接到 `supabase/functions/_shared/contracts/` 中的唯一源文件，便于 Edge Function 打包与外部检查共同使用。

核心报告、照片报告、翻译报告和题目解析均有独立版本。结构校验之外，分数、引用、数字事实、来源覆盖和版本兼容由 `_shared/grading/validation.ts` 及对应业务校验负责。

修改契约时，应同步更新 Swift DTO、后端校验、数据库迁移（如需要）、回归样本和[架构说明](../docs/architecture.md)，并保持旧报告可读。
