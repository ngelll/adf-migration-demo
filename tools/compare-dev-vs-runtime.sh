#!/bin/bash
# compare-dev-vs-runtime.sh
# 对比 ADF 的"开发态(GitHub main 分支)" vs "运行态(工厂资源对象)"
# 用法: ./compare-dev-vs-runtime.sh <factory-name>

set -e

FACTORY="${1:-adf-dst-southeastasia-demo}"
SUB="bf01ff1d-8292-4746-917b-2b4048ee6ea1"
RG="rg-adf-migration-demo"
REPO_DIR="/root/.openclaw/workspace/adf-migration-demo/git-workspace/repo"

export AZURE_CONFIG_DIR="/root/.openclaw/workspace/adf-migration-demo/.azure-tmp"

echo "============================================================"
echo "  比较: $FACTORY"
echo "  开发态(GitHub main) vs 运行态(工厂对象库)"
echo "============================================================"

# 拉最新的 Git
cd "$REPO_DIR"
git fetch origin main -q
git checkout main -q
git pull --rebase origin main -q 2>&1 | grep -v "Already" || true

# 用 az 拿 token
TOKEN=$(az account get-access-token --resource https://management.azure.com --query accessToken -o tsv 2>/dev/null)

api() {
  curl -s -H "Authorization: Bearer $TOKEN" \
    "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.DataFactory/factories/$FACTORY/$1?api-version=2018-06-01"
}

echo ""
echo "--- 1) GlobalParameter ---"
echo "[开发态/Git main]:"
jq '.properties.globalParameters' "$REPO_DIR/factory/$FACTORY.json" 2>/dev/null || echo "  (Git 里无)"
echo ""
echo "[运行态/工厂]:"
api "" | jq '.properties.globalParameters'

echo ""
echo "--- 2) LinkedService 数量 ---"
echo "[开发态]: $(ls $REPO_DIR/linkedService/*.json 2>/dev/null | wc -l) 个"
echo "[运行态]: $(api 'linkedservices' | jq '.value | length') 个"

echo ""
echo "--- 3) Dataset 数量 ---"
echo "[开发态]: $(ls $REPO_DIR/dataset/*.json 2>/dev/null | wc -l) 个"
echo "[运行态]: $(api 'datasets' | jq '.value | length') 个"

echo ""
echo "--- 4) Pipeline 数量 ---"
echo "[开发态]: $(ls $REPO_DIR/pipeline/*.json 2>/dev/null | wc -l) 个"
echo "[运行态]: $(api 'pipelines' | jq '.value | length') 个"

echo ""
echo "============================================================"
echo "  ✅ 如果开发态和运行态都一样,说明 Studio 已点过'发布'"
echo "  ⚠️ 如果不一致,说明 Git 改了但运行态还没同步"
echo "============================================================"
