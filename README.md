# ADF 跨区域迁移 Demo —— 全部产出索引

> **2026-06-19 更新**:新增方案 B(数据 + 配置完整迁移),全流程通过 Studio 验证 + Runtime 跑通

## 📂 工作区结构

```
/root/.openclaw/workspace/adf-migration-demo/
├── adf-objects/                    # ADF 对象 JSON(部署用,第一版)
│   ├── AzureBlobStorageLS-props.json
│   ├── SourceCsvDataset-props.json
│   ├── DestinationCsvDataset-props.json
│   └── MigrationDemoPipeline-props.json
├── git-workspace/repo/             # 本地 Git 工作区
│   ├── factory/                    # ✨ 含 GlobalParameter(方案 B)
│   ├── linkedService/              # 已参数化(方案 B)
│   ├── dataset/                    # 已参数化(方案 B)
│   ├── pipeline/                   # 已加传参逻辑(方案 B)
│   └── adf-dst-southeastasia-demo/ # adf_publish 分支(ARM 模板)
├── docs/
│   ├── Demo操作手册.md             # 演示讲解的脚本(含方案 B v2 修订)✨
│   └── cleanup.md                  # 清场指南
├── .sea_storage_name               # ✨ SEA Storage 名字(方案 B)
└── .azure-tmp/                     # SP 凭据缓存(隔离的)

GitHub 仓库:
https://github.com/ngelll/adf-migration-demo
├── main 分支            # 开发态(ADF Studio 同步推/拉)
└── adf_publish 分支     # 发布态(ARM 模板)
```

## 🎬 演示验证录像(关键节点)

### 第一版:配置迁移(2026-06-18 上午)

| 时间点 | 事件 | 验证方式 |
|---|---|---|
| 11:00 | RG + Storage 就绪 | `az resource list` |
| 11:01 | source-data/sample.csv 上传 | `az storage blob list` |
| 11:05 | 源 ADF 创建完成 | `az datafactory show` |
| 11:09 | 目标 ADF 创建完成 | `az datafactory show` |
| 11:10 | 源 ADF 三件套(LS/DS/Pipeline)部署 | `az datafactory pipeline list` |
| 11:12 | **源 ADF 管道首跑成功**(25 秒) | destination-data/sample_copy.csv 生成 |
| 11:35 | 源 ADF 接 GitHub Git | GitHub main 分支自动提交 4 个对象 |
| 12:13 | 源 ADF 推送对象到 main 分支 commit `72981d2` | `git log` |
| 12:24 | 目标 ADF 接 GitHub Git | REST API 显示 repoConfiguration 已绑定 |
| 12:27 | 目标 ADF 从 main 拉到对象 | Studio 显示管道+数据集 |
| 12:29 | 目标 ADF 点"发布" | adf_publish 分支自动生成 ARM 模板 |
| 12:30 | ARM 模板部署到目标 ADF 运行态 | `az deployment group create` Succeeded |
| 12:33 | **目标 ADF 管道首跑成功**(26 秒) | destination-data/sample_copy.csv 重新生成 |

### 第二版:数据 + 配置完整迁移(2026-06-18 下午 + 06-19 早晨)

| 时间点 | 事件 | 验证方式 |
|---|---|---|
| 13:00 | SEA Storage `stadfdemosea7660` 创建完成 | 含 frank/grace/jack 等 SEA 数据 |
| 13:01 | RBAC 加完成,GlobalParameter 设到工厂运行态 | REST API 确认 |
| 13:02 | LinkedService 参数化(commit `9984fe2`) | GitHub diff |
| 13:05 | **目标 ADF 用方案 B 跑成功**(28 秒) | SEA destination 写入 frank/grace 5 行 ✅ |
| **02:35** (06-19) | **Studio 验证报错** | "pipeline().globalParameters.X 不是受支持系统变量" |
| **02:36** | 修复 Dataset → Pipeline 参数传递(commit `6e77d28`) | Runtime 仍通过(28 秒) |
| **02:44** | **Studio 全局参数页空 + 验证仍报错** | 抓到第二个 bug |
| **02:45** | GlobalParameter 加到 Git `factory/<name>.json`(commit `c0dcd51`) | Studio 终于能看到了 |
| **02:48** | **两个 ADF 都通过 Studio 验证 + 跑通** | ✅ 端到端完美 |

## 📊 跨区域迁移结果对比

### 第一版(共享东亚 Storage)

| 维度 | 源 ADF (East Asia) | 目标 ADF (Southeast Asia) |
|---|---|---|
| 数据源 | 同一个东亚 Storage | 同一个东亚 Storage(跨区域访问)|
| LinkedService 数 | 1 | 1 ✅ 一致 |
| Dataset 数 | 2 | 2 ✅ 一致 |
| Pipeline 数 | 1 | 1 ✅ 一致 |

### 第二版(各走各的 Storage)✨

| 维度 | 源 ADF (East Asia) | 目标 ADF (Southeast Asia) |
|---|---|---|
| **数据源** | EA Storage `stadfdemobe002d` | **SEA Storage `stadfdemosea7660`** ✅ |
| **GlobalParameter** | `StorageEndpoint = EA endpoint` | **`StorageEndpoint = SEA endpoint`** ✅ |
| **样本数据** | alice/bob/charlie/david/eve | **frank/grace/henry/iris/jack** ✅ |
| **共享代码** | 1 份 Git 仓库 | **同一份 Git 仓库** ✅ |
| **加新区域成本** | - | **改一行 GlobalParameter** ✅ |

## ⚠️ 方案 B 踩过的 3 个真实坑(2026-06-19 笔记)

1. **Dataset 不能直接用 `@pipeline().X`** → 必须 Dataset 加自己的参数,Pipeline 调用时传
2. **REST API PATCH GlobalParameter 不会同步到 Git** → Studio 显示空 + 验证报错
3. **GlobalParameter 在 Git 仓库的位置是 `factory/<name>.json`,不是 `globalParameters/` 文件夹**

详见 [Demo操作手册.md](./docs/Demo操作手册.md) → "升级版的 3 个真实踩坑笔记" 章节

## 🔑 重要凭据(Demo 结束需处理)

| 凭据 | 用途 | 处理方式 |
|---|---|---|
| SP `adf-migration-demo-sp` (`14f4ce99-...`) | az CLI 自动化 | Demo 后 `az ad sp delete` |
| GitHub PAT `adf-migration-demo-pat` | Git push/pull | Demo 后在 https://github.com/settings/tokens 删除 |
| GitHub OAuth "Azure Data Factory" | ADF Studio Git 集成 | Demo 后在 https://github.com/settings/applications Revoke |

## 📖 关键文档

- **Demo 讲解脚本** → [Demo操作手册.md](./docs/Demo操作手册.md)(含第一版 + 方案 B v2 修订)
- **演示完清场** → [docs/cleanup.md](./docs/cleanup.md)
- **本索引** → [README.md](./README.md)

## 🎯 Demo 核心叙事(升级版)

> "今天我们演示了 **完整的 GitOps 多区域 ETL 部署**:
>
> **第一层**(配置迁移):用 GitHub 作为传输介质,把一个 Azure Data Factory 的完整 ETL 管道从 East Asia 跨区域复制到 Southeast Asia。
>
> **第二层**(数据迁移):通过 LinkedService 参数化 + 工厂级 GlobalParameter,实现**同一份 JSON 配置,两个区域各连各自的 Storage**。这就是企业 dev/staging/prod 多环境模型的标准做法。
>
> 关键看点:
> 1. **0 手工对象创建**:目标 ADF 的所有对象都从 GitHub 同步过来
> 2. **100% 配置一致**:两个区域跑同一份 JSON,但数据各走各家
> 3. **可版本控制**:每次改动都是 GitHub commit,可 review 可回滚
> 4. **可扩展到任意多区域**:再加一个区域,改 1 行 GlobalParameter 即可
> 5. **完全 GitOps**:未来加 GitHub Actions 就能做到全自动部署
> 6. **Studio + Runtime 双验证通过**:真正生产可用,不是 hack"

## 🎬 Demo Cheat Sheet(快速演示)

如果要给客户/同事 5 分钟演示,按这个顺序:

1. **打开 GitHub 仓库** → 展示 1 份代码
2. **打开源 ADF Studio** → 展示 main 分支同步过来的对象
3. **打开目标 ADF Studio** → 展示同样的对象 + 不同的 GlobalParameter
4. **CLI 触发目标 ADF 管道** → 30 秒内完成
5. **下载 SEA Storage 的输出文件** → 内容是 SEA 数据(不是 EA 数据)

10 行 CLI 就能演完核心价值。详细脚本见 [Demo操作手册.md](./docs/Demo操作手册.md)。
