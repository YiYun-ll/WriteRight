# 本地批改任务的自动处理

2026-10-30。仅适用于 EssayPilot 开发容器，未配置或部署云环境。

现有迁移 `20261029111000_worker_schedule.sql` 每分钟调用 `private.invoke_grading_worker()`。此前本地 Vault 未配置地址/token，函数直接返回空，任务依赖手动 Worker 调用。

## 启动

1. `npm run backend:start` 启动绑定 localhost 的开发后端。
2. 在另一个终端运行并保持 `npm run functions:serve`。
3. 在 ignored `supabase/.env.local` 设置与函数服务相同的本地 `WRITERIGHT_WORKER_TOKEN`（至少 16 字符），不把真实值写入 Git 或客户端。
4. `npm run backend:worker:configure` 只访问硬编码的开发容器与内部 Kong URL，并检查开发网络绑定 localhost；把已有 token 和内部 URL 写入本地加密 Vault。值走 stdin，不进 argv、日志、临时 SQL 或 migration；重复运行更新原项。
5. 本地 App 入队后，由数据库定时处理。客户端轮询只读进度，不唤起模型。

此配置不部署函数、不修改云端、已有 cron 计划或计费配置。停止本地函数服务后任务可能排队；重新启动后按已有租约/重试规则继续。依赖本地 Docker 和函数服务运行，不代表生产部署完成。

## 实际验证

`npm run test:worker-schedule` 为显式真实模型集成测试，使用合成作文和一次性本地账号，会产生模型调用，最终清理该测试账号，不读取生产。

本轮已实际通过：脚本只入队和读 status，没有直接请求 grading-worker；数据库 cron 自动生成真实 V1_2 报告。证据：ignored `artifacts/local-worker-schedule.json`。再次配置后两个 Vault 名称各一条。

故障重试、租约 fencing、有限次数及报告原子保存仍单独回归；一次成功不代表已模拟所有云端故障。
