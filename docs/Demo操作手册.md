# ADF 跨区域迁移 Demo 操作手册

> 把 East Asia 的 Azure Data Factory 管道迁移到 Southeast Asia，通过 GitHub 共享配置。

**搭建日期**：2026-06-18
**搭建者**：机器猫 🐱
**环境**：Azure 订阅 `ME-MngEnvMCAP104996-jingnie-1`

---

## Demo 故事线（讲给观众听的版本）

> "我们公司有一个 Azure Data Factory 部署在 East Asia 区域，业务发展到东南亚后，我们需要把这套 ETL 管道**克隆**到 Southeast Asia 区域，以降低跨区域延迟。
>
> 老办法：在新区域手工重新搭建所有对象，容易遗漏，无法版本管理。
>
> 新办法（我们今天 Demo 的）：**用 GitHub 当传输介质**，让两个 Data Factory 共享同一份管道定义，做到——
>
> 1. 源 ADF 改了什么，commit 到 Git
> 2. 目标 ADF 从 Git 拉下来，发布
> 3. 整个迁移过程**0 手工对象创建**，**100% 可版本管理**，**任意区域 ADF 都能加入**"

---

## 环境清单

| 资源 | 区域 | 名字 |
|---|---|---|
| Resource Group | eastasia | `rg-adf-migration-demo` |
| 源 ADF (East Asia) | eastasia | `adf-src-eastasia-demo` |
| 目标 ADF (Southeast Asia) | southeastasia | `adf-dst-southeastasia-demo` |
| Storage Account | eastasia | `stadfdemobe002d` |
| Storage Container - Source | eastasia | `source-data/sample.csv` |
| Storage Container - Destination | eastasia | `destination-data/sample_copy.csv` |
| GitHub Repo | global | `ngelll/adf-migration-demo` |
|   - 协作分支 |  | `main` |
|   - 发布分支 |  | `adf_publish` |
| ADF 中的对象 |  | 1 LinkedService + 2 Dataset + 1 Pipeline |

---

## 完整流程时序图

```
┌─────────────────┐                   ┌─────────────────┐
│  源 ADF         │                   │   目标 ADF      │
│  (East Asia)    │                   │ (Southeast Asia)│
└────────┬────────┘                   └────────▲────────┘
         │                                     │
         │ Step 1: 在 Studio 配 Git            │
         │ 勾"导入现有资源"                    │
         │ 自动 push 对象到 main 分支          │
         ▼                                     │
    ┌─────────────────────────────────────────┐│
    │  GitHub: ngelll/adf-migration-demo      ││
    │   ├── main 分支(协作)                  ││
    │   │   ├── linkedService/                ││
    │   │   ├── dataset/                      ││
    │   │   ├── pipeline/                     ││
    │   │   └── factory/                      ││
    │   └── adf_publish 分支(ARM 模板)       ││
    │       └── ARMTemplateForFactory.json   ││
    └─────────┬───────────────────────────────┘│
              │                                │
              │ Step 2: 在目标 Studio 配 Git    │
              │ 不勾"导入"                     │
              │ 自动 pull main 分支            │
              └───────────────────────────────►│
                                               │
                                               │ Step 3: 在目标 Studio 点"发布"
                                               │ ↓ 生成 ARM 模板到 adf_publish
                                               │
                                               │ Step 4: 部署 ARM
                                               │   az deployment group create
                                               │   --template-file ARMTemplate...
                                               │
                                               │ Step 5: 验证管道运行成功
                                               ▼
                                          ✅ 迁移完成
```

---

## 演示步骤（live 给观众看）

### 演示 1：先看源 ADF 跑一次管道（30 秒）

打开浏览器，访问源 ADF Studio：
- https://portal.azure.com → 搜 `adf-src-eastasia-demo` → Launch Studio
- 左边 → "创作" → 找到 `MigrationDemoPipeline`
- 顶上 → "调试" 或 "添加触发器" → "立即触发"
- 等 25 秒，看 "监视" 页面变绿 ✅
- 打开 Azure Storage Explorer 或 Portal，看 `destination-data/sample_copy.csv` 已生成

**讲解词**：
> "这是我们老的、跑在 East Asia 区域的 Data Factory。管道做的事很简单：把一个 csv 文件从 source-data 复制到 destination-data。现在它工作得很好。"

### 演示 2：打开 GitHub 看仓库结构（10 秒）

打开 https://github.com/ngelll/adf-migration-demo

**讲解词**：
> "源 ADF 配置完 Git 后，所有对象都被推到 GitHub 的 main 分支了。看这个结构：
> - `linkedService/` 是数据存储连接
> - `dataset/` 是数据集定义
> - `pipeline/` 是管道定义
> - `factory/` 是工厂级配置
>
> 这就是我们的'传输介质'——所有配置都是 JSON，版本可追溯，可 PR Review。"

### 演示 3：打开目标 ADF（10 秒）

打开新 tab → 访问目标 ADF Studio：
- https://portal.azure.com → 搜 `adf-dst-southeastasia-demo` → Launch Studio
- 左边 → "创作"

**讲解词**：
> "这是新建在 Southeast Asia 的目标 ADF。它接的是同一个 GitHub 仓库的 main 分支。
> 看左边：管道、数据集都自动从 Git 拉下来了。我**没有手工创建任何对象**——完全是 GitHub 同步过来的。"

### 演示 4：触发目标 ADF 管道（30 秒）

- 在目标 ADF Studio → 找到 `MigrationDemoPipeline`
- 点 "调试" → "立即触发"
- 等 25 秒，看 "监视" 页面变绿 ✅

**讲解词**：
> "现在我让目标 ADF 跑这个管道。它在 Southeast Asia 区域，但管道定义是从 East Asia 那边推过来的。
>
> 26 秒后跑完，状态 Succeeded。看 destination-data 也写入了文件。
>
> **这就是跨区域迁移成功的标志**：源和目标区域跑同一个管道，行为完全一致。"

### 演示 5：展示版本管理威力（30 秒）

打开 GitHub 仓库的 commits 历史：
- https://github.com/ngelll/adf-migration-demo/commits/main

**讲解词**：
> "看 GitHub 的 commit 历史：每次有人修改 ADF 对象，都会自动生成一个 commit。
>
> 这意味着——
> 1. **可审计**：谁改了什么、什么时候改的，一目了然
> 2. **可回滚**：管道出问题，git revert 一下就回到上一版
> 3. **可 Review**：通过 PR 强制 Code Review，杜绝直接改生产
> 4. **可多人协作**：每人在自己的 feature 分支开发，互不影响
> 5. **可多环境扩展**：今天只接了一个东南亚，明天加美国、欧洲，方法完全一样"

---

## Q&A 常见问题预案

**Q: 那如果要迁移 SQL Server 连接字符串这种环境特定的东西怎么办？**

A: ADF 有"全局参数（Global Parameters）"和"参数化的 LinkedService"机制。我们可以让连接字符串变成 `${env.region}` 这种变量，ARM 模板部署时每个环境注入自己的值。

**Q: 那源 ADF 不小心删了某个管道，目标 ADF 会跟着删吗？**

A: 不会自动跟。Git 同步是"开发态"，目标 ADF 看到 Git 的变化，需要手动点"发布"才会进入"运行态"。这就是一道防火墙。

**Q: 我们生产环境只有"读"权限怎么办？**

A: 这正是 GitOps 的优势：生产 ADF 只读 GitHub，由 GitHub Actions 通过 SP 把 ARM 部署到生产，开发者无需直接接触生产权限。

**Q: 跨租户怎么办？比如客户的 ADF 在他们的 Azure 租户**

A: GitHub 仓库本身跟 Azure 租户无关。客户的 ADF 用客户的 GitHub 账号授权同一个仓库，配置完全一样。

**Q: 这个跟 Microsoft Fabric Data Factory 是什么关系？**

A: Microsoft Fabric 是新一代统一数据平台，里面也包含 Data Factory，但模型不同（不是基于 ADF Resources，而是 Fabric Workspaces）。Fabric 内部用 OneLake + Workspace 做集成，不需要这种 Git 跨区域同步。但**现有的 ADF 资源不会强制迁移**，存量项目继续用本 Demo 这套方法。

---

## 用过的关键命令清单（讲解用）

### 创建基础资源

```bash
# 创建 RG
az group create --name rg-adf-migration-demo --location eastasia

# 创建 SP
az ad sp create-for-rbac --name "adf-migration-demo-sp" \
  --role Contributor \
  --scopes "/subscriptions/<SUB>/resourceGroups/rg-adf-migration-demo"

# 注册 DataFactory RP
az provider register --namespace Microsoft.DataFactory --wait

# 创建源 ADF
az datafactory create -g rg-adf-migration-demo -n adf-src-eastasia-demo --location eastasia

# 创建目标 ADF
az datafactory create -g rg-adf-migration-demo -n adf-dst-southeastasia-demo --location southeastasia
```

### 部署管道定义

```bash
# 部署 LinkedService
az datafactory linked-service create \
  -g rg-adf-migration-demo \
  --factory-name adf-src-eastasia-demo \
  --linked-service-name AzureBlobStorageLS \
  --properties @AzureBlobStorageLS-props.json

# 部署 Dataset
az datafactory dataset create \
  -g rg-adf-migration-demo \
  --factory-name adf-src-eastasia-demo \
  --dataset-name SourceCsvDataset \
  --properties @SourceCsvDataset-props.json

# 部署 Pipeline
az datafactory pipeline create \
  -g rg-adf-migration-demo \
  --factory-name adf-src-eastasia-demo \
  --name MigrationDemoPipeline \
  --pipeline @MigrationDemoPipeline-props.json
```

### 触发管道运行

```bash
# 触发运行
RUN_ID=$(az datafactory pipeline create-run \
  -g rg-adf-migration-demo \
  --factory-name adf-src-eastasia-demo \
  --name MigrationDemoPipeline \
  --query runId -o tsv)

# 查看状态
az datafactory pipeline-run show \
  -g rg-adf-migration-demo \
  --factory-name adf-src-eastasia-demo \
  --run-id "$RUN_ID" \
  --query "{status:status, durationMs:durationInMs}" -o table
```

### Git 模式下，把 ARM 模板部署到运行态

```bash
# 部署 ADF 自动生成的 ARM 模板到目标 ADF
az deployment group create \
  --resource-group rg-adf-migration-demo \
  --template-file adf-dst-southeastasia-demo/ARMTemplateForFactory.json \
  --parameters factoryName=adf-dst-southeastasia-demo
```

---

## 后续延伸方向（高级话题）

1. **GitHub Actions 自动化**
   - 监听 `adf_publish` 分支 push
   - 自动 `az deployment group create` 把 ARM 模板部署到对应环境
   - 完全无人工干预

2. **多环境模型**
   - 用 `dev` / `staging` / `prod` 三个 GitHub 分支对应三套 ADF
   - 用不同的 `*.parameters.json` 注入各环境的连接字符串

3. **参数化进一步深入**
   - LinkedService 用变量化的 Key Vault 引用
   - 同一份 LinkedService 在不同环境指向不同的 Storage

4. **DR / Active-Active 部署**
   - 两个区域同时运行同一份管道
   - 用 Azure Front Door 路由触发请求

---

## 演示结束后清场

见 `cleanup.md`。

---


---

# 🚀 升级版 Demo:方案 B — 跨区域数据 + 配置同时迁移(2026-06-19 修订版)

> **重大更新**:本章节是踩过 3 个真实坑后的"可重现版本",**严格按这个顺序做就一定通过 Studio 验证**。

## 升级版叙事(讲给观众听)

> "刚才的第一版 Demo 里,两个 ADF 共享同一个东亚 Storage,目标 ADF 跨区域去东亚读数据,有延迟 + 流量费。
>
> **真实迁移场景里,数据要跟管道一起搬到新区域**。
>
> 关键挑战:**Storage endpoint 写死在 LinkedService 里,两个区域的 ADF 怎么用同一份 JSON 但连不同的 Storage**?
>
> 答案:**用 LinkedService 参数化 + 工厂的 GlobalParameter** —— 一份代码,多份环境配置,这就是企业的 dev/staging/prod 多环境模型。"

## 升级版数据流图

```
全局参数(每个工厂自己)         Git 仓库的 factory/<name>.json
    ↓                          └─ properties.globalParameters.StorageEndpoint
    ↓
管道运行时 @pipeline().globalParameters.StorageEndpoint  ← 只有 Pipeline 上下文能用这个
    ↓ (Pipeline activity 的 inputs/outputs 传给 Dataset)
Dataset 自己声明的参数 @dataset().StorageEndpoint  ← Dataset 上下文用这个
    ↓ (Dataset 引用 LinkedService 时传)
LinkedService 自己声明的参数 @{linkedService().StorageEndpoint}  ← LinkedService 上下文用这个
    ↓
最终拼到 serviceEndpoint
```

**核心约束**:每一层只能用自己上下文里可用的引用方式,**不能跳层**(否则 Studio 验证失败)。

## 升级版操作 7 步(2026-06-19 修订)

### Step 1:在 SEA 区域新建 Storage + 复制数据

```bash
cd /root/.openclaw/workspace/adf-migration-demo
export AZURE_CONFIG_DIR="$(pwd)/.azure-tmp"
SUB="bf01ff1d-8292-4746-917b-2b4048ee6ea1"

# 建新 Storage(SEA 区域)
SEA_STORAGE="stadfdemosea7660"
az storage account create \
  --name "$SEA_STORAGE" \
  --resource-group rg-adf-migration-demo \
  --location southeastasia \
  --sku Standard_LRS \
  --kind StorageV2 \
  --subscription "$SUB"

# 给 SP / 两个 ADF 的 MSI 加 SEA Storage Blob Data Contributor 权限
SP_OBJID="b01b87c2-44c2-427f-bf3e-1c2389891185"
SRC_ADF_MSI=$(az datafactory show -g rg-adf-migration-demo -n adf-src-eastasia-demo --subscription "$SUB" --query identity.principalId -o tsv)
DST_ADF_MSI=$(az datafactory show -g rg-adf-migration-demo -n adf-dst-southeastasia-demo --subscription "$SUB" --query identity.principalId -o tsv)

for principal in "$SP_OBJID" "$SRC_ADF_MSI" "$DST_ADF_MSI"; do
  az role assignment create \
    --assignee "$principal" \
    --role "Storage Blob Data Contributor" \
    --scope "/subscriptions/$SUB/resourceGroups/rg-adf-migration-demo/providers/Microsoft.Storage/storageAccounts/$SEA_STORAGE"
done

# 等 15 秒让 RBAC 传播
sleep 15

# 建容器
az storage container create --account-name "$SEA_STORAGE" --auth-mode login -n source-data
az storage container create --account-name "$SEA_STORAGE" --auth-mode login -n destination-data

# 上传演示数据(改个区域字段,演示时一目了然)
cat > /tmp/sample_sea.csv <<CSV
id,name,region,value
6,frank,southeastasia,600
7,grace,southeastasia,700
8,henry,southeastasia,800
9,iris,southeastasia,900
10,jack,southeastasia,1000
CSV

az storage blob upload \
  --account-name "$SEA_STORAGE" \
  --auth-mode login \
  --container-name source-data \
  --name sample.csv \
  --file /tmp/sample_sea.csv \
  --overwrite
```

### Step 2:把 LinkedService 改成参数化(改 GitHub)

```json
// linkedService/AzureBlobStorageLS.json
{
  "name": "AzureBlobStorageLS",
  "type": "Microsoft.DataFactory/factories/linkedservices",
  "properties": {
    "type": "AzureBlobStorage",
    "annotations": [],
    "parameters": {
      "StorageEndpoint": { "type": "String" }
    },
    "typeProperties": {
      "serviceEndpoint": "@{linkedService().StorageEndpoint}",
      "accountKind": "StorageV2"
    }
  }
}
```

### Step 3:把 Dataset 改成参数化(改 GitHub)

**关键修正**:Dataset 必须先**声明自己的 parameters**,引用 LinkedService 时用 `@dataset().StorageEndpoint`。

⚠️ **不能直接用 `@pipeline().globalParameters.X`** — Dataset 在静态层面没有 pipeline 上下文,Studio 验证会拒绝。

```json
// dataset/SourceCsvDataset.json
{
  "name": "SourceCsvDataset",
  "properties": {
    "linkedServiceName": {
      "referenceName": "AzureBlobStorageLS",
      "type": "LinkedServiceReference",
      "parameters": {
        "StorageEndpoint": {
          "value": "@dataset().StorageEndpoint",
          "type": "Expression"
        }
      }
    },
    "parameters": {
      "StorageEndpoint": { "type": "String" }
    },
    "annotations": [],
    "type": "DelimitedText",
    "typeProperties": {
      "location": {
        "type": "AzureBlobStorageLocation",
        "fileName": "sample.csv",
        "container": "source-data"
      },
      "columnDelimiter": ",",
      "escapeChar": "\\",
      "firstRowAsHeader": true,
      "quoteChar": "\""
    },
    "schema": []
  },
  "type": "Microsoft.DataFactory/factories/datasets"
}
```

DestinationCsvDataset.json 同理。

### Step 4:改 Pipeline,让 Copy Activity 调用 Dataset 时传 GlobalParameter

**关键步骤**:Pipeline 是唯一可以用 `@pipeline().globalParameters.X` 的上下文。

```json
// pipeline/MigrationDemoPipeline.json 里 activity 的 inputs / outputs
"inputs": [
  {
    "referenceName": "SourceCsvDataset",
    "type": "DatasetReference",
    "parameters": {
      "StorageEndpoint": {
        "value": "@pipeline().globalParameters.StorageEndpoint",
        "type": "Expression"
      }
    }
  }
],
"outputs": [
  {
    "referenceName": "DestinationCsvDataset",
    "type": "DatasetReference",
    "parameters": {
      "StorageEndpoint": {
        "value": "@pipeline().globalParameters.StorageEndpoint",
        "type": "Expression"
      }
    }
  }
]
```

### Step 5:把 GlobalParameter 加到 Git 仓库的 factory/<name>.json

**关键修正**:GlobalParameter 必须存在 Git 仓库的 `factory/<adf-name>.json` 文件里,**不是单独的 `globalParameters/` 文件夹**。

⚠️ 用 REST API PATCH 只更新工厂运行态,Studio 看不到。**必须把 GlobalParameter 写进 Git**,Studio 才能从 Git 拉到。

```json
// factory/adf-src-eastasia-demo.json(源 ADF,指 EA Storage)
{
  "name": "adf-src-eastasia-demo",
  "properties": {
    "trustModeClaimForMi": {
      "value": "Disabled",
      "editable": true
    },
    "globalParameters": {
      "StorageEndpoint": {
        "type": "String",
        "value": "https://stadfdemobe002d.blob.core.windows.net"
      }
    }
  },
  "location": "eastasia",
  "identity": {
    "type": "SystemAssigned",
    "principalId": "<源 ADF MSI>",
    "tenantId": "<tenant id>"
  }
}

// factory/adf-dst-southeastasia-demo.json(目标 ADF,指 SEA Storage)
{
  "name": "adf-dst-southeastasia-demo",
  "properties": {
    "trustModeClaimForMi": {
      "value": "Disabled",
      "editable": true
    },
    "globalParameters": {
      "StorageEndpoint": {
        "type": "String",
        "value": "https://stadfdemosea7660.blob.core.windows.net"
      }
    }
  },
  "location": "southeastasia",
  "identity": {
    "type": "SystemAssigned",
    "principalId": "<目标 ADF MSI>",
    "tenantId": "<tenant id>"
  }
}
```

**`git commit + push`** 全部改动到 `main` 分支。

### Step 6:让 Studio 拉新代码并发布

1. 打开两个 ADF 的 Studio,**F5 整页强刷**(让 Studio 重新从 Git 拉)
2. 如果 Studio 弹"未保存的更改要丢弃吗" → **选丢弃**
3. 去 "管理" → "全局参数",应该能看到 `StorageEndpoint` 已经有正确的值
4. 去 "创作" → 打开 `MigrationDemoPipeline` → 点 **"验证"**,应该全绿
5. 点 **"调试"** → 应该跑成功
6. 点 **"发布"** → 把 Git/Studio/运行态全部对齐(会生成 ARM 模板到 `adf_publish`)
7. 用 az CLI 部署 ARM 模板到运行态(从 `adf_publish` 分支):
   ```bash
   git checkout adf_publish
   az deployment group create \
     -g rg-adf-migration-demo \
     --subscription "$SUB" \
     --template-file adf-dst-southeastasia-demo/ARMTemplateForFactory.json \
     --parameters @adf-dst-southeastasia-demo/ARMTemplateParametersForFactory.json
   ```

### Step 7:跑管道验证两个区域各走各的 Storage

```bash
# 跑目标 ADF
RUN_ID=$(az datafactory pipeline create-run \
  -g rg-adf-migration-demo \
  --factory-name adf-dst-southeastasia-demo \
  --subscription "$SUB" \
  --name MigrationDemoPipeline \
  --query runId -o tsv)
sleep 30
az datafactory pipeline-run show \
  -g rg-adf-migration-demo \
  --factory-name adf-dst-southeastasia-demo \
  --subscription "$SUB" \
  --run-id "$RUN_ID" \
  --query "{status:status, durationMs:durationInMs}" -o table

# 验证文件
az storage blob download \
  --account-name stadfdemosea7660 \
  --auth-mode login \
  -c destination-data -n sample_copy.csv -f /tmp/result.csv
cat /tmp/result.csv
# 应该看到 frank/grace/henry/iris/jack(SEA 数据,不是 alice/bob/eve)
```

## ⚠️ 升级版的 3 个真实踩坑笔记

### 坑 1:Dataset 直接引用 `@pipeline().globalParameters.X`

**症状**:Studio 验证时报错 "pipeline().globalParameters.StorageEndpoint 不是受支持的系统变量"

**原因**:Dataset 在静态层面没有 pipeline 上下文,Studio 严格验证拒绝。Runtime 容错向上找能跑通,Studio 不容错。

**修复**:Dataset 加自己的 parameters,Pipeline 调用 Dataset 时再传 `@pipeline().globalParameters.X`。详见 Step 3 + Step 4。

### 坑 2:REST API PATCH GlobalParameter 后 Studio 看不到

**症状**:用 `curl -X PATCH ... globalParameters` 设了 GlobalParameter,**Runtime 跑管道能用**,但 **Studio 全局参数页显示空**,Studio 验证还报"找不到参数"。

**原因**:REST API PATCH 只更新工厂运行态,**不写回 Git 仓库**。ADF Git 模式下 Studio 从 Git 拉显示,所以看不到。

**修复**:把 GlobalParameter 写到 `factory/<adf-name>.json` 的 `properties.globalParameters` 字段,push 到 main。详见 Step 5。

### 坑 3:误把 GlobalParameter 放在 `globalParameters/` 文件夹

**症状**:建了 `globalParameters/<adf-name>.json` 文件,Studio 还是看不到。

**原因**:ADF Git 仓库**没有 `globalParameters/` 这个标准文件夹**(我一开始猜错了)。GlobalParameter 的标准位置是 `factory/<adf-name>.json`。

**修复**:删掉 `globalParameters/` 文件夹,把内容合并进 `factory/<name>.json` 的 `properties.globalParameters` 字段。

## 升级版 Q&A

**Q: 如果要加美国区域怎么办?**

A:
1. 重复 Step 1(建美国 Storage)
2. 建一个新 ADF `adf-us-eastus2-demo`,接 Git
3. 在 Git 里新建 `factory/adf-us-eastus2-demo.json`,GlobalParameter 指美国 Storage
4. 其他 LinkedService/Dataset/Pipeline 不变

GitHub 那份 JSON 一行都不改。

**Q: 那连接字符串、密码、Key 之类的敏感信息怎么办?**

A: LinkedService 参数化 + 引用 Azure Key Vault。GitHub 里只存"去哪个 Key Vault 取哪个 Secret",真实凭据永远不进 Git。Key Vault 的 reference 表达式格式:

```json
"password": {
  "type": "AzureKeyVaultSecret",
  "store": { "referenceName": "AzureKeyVaultLS", "type": "LinkedServiceReference" },
  "secretName": { "value": "@pipeline().globalParameters.SecretName", "type": "Expression" }
}
```

**Q: 数据怎么从老 Storage 同步到新 Storage?**

A: 方案 C 用 ADF 自己做(再起一个迁移管道)。简单场景用 `azcopy` 或 `az storage blob copy`。

**Q: 多个区域 ADF,Git push 一次能 deploy 到所有区域吗?**

A: GitHub Actions + 多个 `az deployment` 命令 = 是的。这是企业 GitOps 的标准做法。

**Q: 为什么不在 Studio 里手动加 GlobalParameter,而要走 Git?**

A: 在 Studio 手动加也可以(Studio 会自动写回 Git)。但**写到 Git 才是真正的 GitOps**:任何环境的新 ADF 接同一个 Git 就自动有正确的 GlobalParameter,不需要人工再去每个区域 Studio 里点一遍。

## 升级版核心价值

✅ **一份代码 + 多份环境配置** = 真正的 GitOps  
✅ **新加区域 = 改一行 GlobalParameter** = 极致扩展性  
✅ **跟 dev/staging/prod 多环境是同一套方法** = 落地立即可用  
✅ **敏感信息走 Key Vault,不进 Git** = 安全合规  
✅ **Studio + Runtime 双验证通过** = 真正生产可用,不是 hack
