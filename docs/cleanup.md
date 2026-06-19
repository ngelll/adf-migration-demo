# Demo 清场指南

> Demo 演示完后，按这个清单回收资源 + 撤销凭据，避免长期账单和安全暴露。
> 
> **2026-06-19 更新**:加入方案 B 新增的 SEA Storage 清理。

---

## 🔥 一键清场（推荐）

### Step 1：删整个 RG（删除所有 Azure 资源，含两个 Storage 和两个 ADF）

```bash
az group delete \
  --name rg-adf-migration-demo \
  --subscription bf01ff1d-8292-4746-917b-2b4048ee6ea1 \
  --yes \
  --no-wait
```

`--no-wait` 让命令立刻返回，删除在 Azure 后台异步进行（5-10 分钟完成）。

**删 RG 会一并删除**:
- 源 ADF `adf-src-eastasia-demo`
- 目标 ADF `adf-dst-southeastasia-demo`
- EA Storage `stadfdemobe002d` + 2 个容器 + 数据
- **SEA Storage `stadfdemosea7660` + 2 个容器 + 数据**(方案 B 新增)
- 所有 RBAC 角色分配

### Step 2：删除 GitHub 仓库

打开 https://github.com/ngelll/adf-migration-demo
→ Settings → 拉到最底 → Danger Zone → "Delete this repository"
→ 输入 `ngelll/adf-migration-demo` 确认 → 删除

### Step 3：撤销 GitHub PAT

打开 https://github.com/settings/tokens
→ 找到 `adf-migration-demo-pat`
→ 点 "Delete" 或 "Revoke"

### Step 4：撤销 Azure SP

```bash
az ad sp delete --id 14f4ce99-007e-48d4-a3ea-5360c3fc880e
```

或者只清掉它的角色分配（保留 SP 主体）：

```bash
# 列出该 SP 的所有角色分配
az role assignment list --assignee 14f4ce99-007e-48d4-a3ea-5360c3fc880e -o table

# 删除特定的角色分配
az role assignment delete --assignee 14f4ce99-007e-48d4-a3ea-5360c3fc880e --role "Owner" --scope "/subscriptions/bf01ff1d-8292-4746-917b-2b4048ee6ea1/resourceGroups/rg-adf-migration-demo"
```

### Step 5：撤销 ADF 在 GitHub 上的 OAuth 授权

打开 https://github.com/settings/applications
→ 找到 "Azure Data Factory"（你之前在 ADF Studio 接 Git 时授权的）
→ 点 "Revoke"

### Step 6：清理本地工作区

```bash
rm -rf /root/.openclaw/workspace/adf-migration-demo
```

---

## ✅ 验证清场完成

```bash
# 1. 验证 RG 已删除
az group exists --name rg-adf-migration-demo --subscription bf01ff1d-8292-4746-917b-2b4048ee6ea1
# 应该返回 false

# 2. 验证 SP 已删除
az ad sp show --id 14f4ce99-007e-48d4-a3ea-5360c3fc880e 2>&1 | grep "does not exist"
# 应该匹配

# 3. 浏览器访问 https://github.com/ngelll/adf-migration-demo
# 应该 404

# 4. https://github.com/settings/tokens
# 应该看不到 adf-migration-demo-pat
```

---

## ⚠️ 安全建议（写给未来的你）

1. **SP 密码已暴露**：你在飞书聊天里贴过完整 SP 密码，建议清场后**至少 reset 一次** SP secret（即使马上要删 SP 也最好走一遍，养成习惯）。
2. **PAT 已暴露**：同理，清场后立即在 GitHub 删除该 PAT。
3. **不要在公网共享仓库里留 Storage Account 名字**：当前 `ngelll/adf-migration-demo` 是 Public 仓库，里面的 JSON 文件含 `stadfdemobe002d` 的全限定 endpoint。删仓库前可以先改成 Private，或者直接删仓库（推荐删，反正 Demo 完了）。

---

## 💰 不删 RG，只暂停账单怎么办？

如果你想保留资源继续玩，但不想烧太多钱：

```bash
# 关闭两个 ADF 的 Managed Identity（最便宜状态）
# ADF 本身是 PaaS，按使用计费，空闲几乎不收费
# Storage Account 占 8 KB 的 Standard_LRS 一个月 ~0.0002 美元

# 真正烧钱的是管道运行时间，所以只要不触发就基本免费
```

**真实账单估算**（不主动触发管道的情况下）：

| 资源 | 月成本 |
|---|---|
| 2 个 ADF（空闲） | ~$0 |
| EA Storage Account + 2 个容器 + 124 字节 csv | ~$0.0002 |
| **SEA Storage Account + 2 个容器 + 151 字节 csv**(方案 B 新增)| ~$0.0002 |
| **总计** | **<$0.01/月** |

所以**保留几天到几周都不会有显著账单**。

---

## 真要长期保留？建议这样改造

1. **删除 PAT，重新生成长期 PAT**（90 天或 1 年）
2. **删除当前 SP，建一个 Federated Identity SP**（用 GitHub Actions OIDC，无密码）
3. **GitHub 仓库改成 Private**
4. **加 GitHub Actions workflow**，自动部署 `adf_publish` 分支到目标 ADF
5. **加 Azure DevOps 仪表板监控** 两个 ADF 的运行成功率
