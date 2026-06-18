# ADF Migration Demo

这是一个演示 Azure Data Factory 跨区域迁移的项目。

## 仓库说明

本仓库被两个 Azure Data Factory 共享:

- **源 ADF**: `adf-src-eastasia-demo` @ East Asia
- **目标 ADF**: `adf-dst-southeastasia-demo` @ Southeast Asia

## 分支策略

- `main`: 主分支,代表稳定版本
- `adf_publish`: ADF 自动管理的发布分支
- `feature/*`: 开发新功能时的临时分支

## 迁移流程演示

1. 源 ADF 接 Git → 在 `main` 分支上开发管道
2. 源 ADF 发布 → 触发 ADF 生成 ARM 模板到 `adf_publish` 分支
3. 目标 ADF 接同一个 Git 仓库 → 拉取 `main` 分支
4. 在目标 ADF 中调整环境参数(区域、Storage、Key Vault 等)
5. 目标 ADF 发布 → 完成跨区域迁移

## 重要的环境参数

| 参数 | 源 ADF | 目标 ADF |
|---|---|---|
| Region | East Asia | Southeast Asia |
| Storage Account | stadfdemobe002d (东亚) | 同一个(演示简化) |

Demo 由机器猫🐱搭建,正式使用前请清理并改为 Private 仓库。
