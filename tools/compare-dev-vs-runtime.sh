#!/bin/bash
# compare-dev-vs-runtime.sh
# 对比 ADF 的"开发态(GitHub main 分支)" vs "运行态(工厂资源对象库)"
#
# 用法:
#   ./compare-dev-vs-runtime.sh <factory-name> [resource-group] [subscription-id]
#
# 例如:
#   ./compare-dev-vs-runtime.sh adf-dst-southeastasia-demo
#   ./compare-dev-vs-runtime.sh adf-dst-southeastasia-demo my-rg my-sub-id
#
# 依赖: az, git, curl, jq
# 前置: az login 已完成
#
# 通用版 v2 - 跨平台 + 无硬编码

set -e

# ----- 1) 解析参数 -----
FACTORY="${1:-}"
if [ -z "$FACTORY" ]; then
  echo "❌ 用法: $0 <factory-name> [resource-group] [subscription-id]"
  echo ""
  echo "示例:"
  echo "  $0 adf-dst-southeastasia-demo"
  echo "  $0 adf-dst-southeastasia-demo rg-adf-migration-demo bf01ff1d-8292-4746-917b-2b4048ee6ea1"
  exit 1
fi

# Resource Group: 命令行 > 环境变量 > 默认
RG="${2:-${ADF_RG:-rg-adf-migration-demo}}"

# Subscription: 命令行 > 环境变量 > 当前默认订阅
SUB="${3:-${ADF_SUB:-$(az account show --query id -o tsv 2>/dev/null)}}"

if [ -z "$SUB" ]; then
  echo "❌ 找不到 Azure 订阅 ID。请先运行: az login"
  exit 1
fi

# 自动识别仓库根目录(脚本所在目录的父目录)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# ----- 2) 依赖检查 -----
for cmd in az git curl jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ 缺少依赖: $cmd"
    echo ""
    echo "安装方法:"
    echo "  Mac: brew install azure-cli git jq"
    echo "  Ubuntu/Debian: apt install azure-cli git jq curl"
    echo "  Windows: 用 WSL 或者用 PowerShell 版本 compare-dev-vs-runtime.ps1"
    exit 1
  fi
done

# ----- 3) 输出标题 -----
echo "============================================================"
echo "  比较: $FACTORY"
echo "  订阅: $SUB"
echo "  资源组: $RG"
echo "  仓库目录: $REPO_DIR"
echo "  开发态(GitHub main) vs 运行态(工厂对象库)"
echo "============================================================"

# ----- 4) 拉最新 Git -----
if [ -d "$REPO_DIR/.git" ]; then
  cd "$REPO_DIR"
  echo ""
  echo "→ 拉取 GitHub main 最新代码..."
  git fetch origin main -q 2>&1 | grep -v "^$" || true
  git pull --rebase origin main -q 2>&1 | grep -v "Already up to date" || true
  echo "  当前 commit: $(git rev-parse --short HEAD)"
fi

# ----- 5) 拿 Azure token -----
echo ""
echo "→ 获取 Azure access token..."
TOKEN=$(az account get-access-token --subscription "$SUB" --resource https://management.azure.com --query accessToken -o tsv 2>/dev/null)
if [ -z "$TOKEN" ]; then
  echo "❌ 获取 token 失败。请运行: az login --tenant <your-tenant-id>"
  exit 1
fi

# ----- 6) API 辅助函数 -----
api() {
  curl -s -H "Authorization: Bearer $TOKEN" \
    "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.DataFactory/factories/$FACTORY/$1?api-version=2018-06-01"
}

# ----- 7) 对比开发态 vs 运行态 -----
echo ""
echo "--- 1) GlobalParameter ---"
echo "[开发态/Git main]:"
if [ -f "$REPO_DIR/factory/$FACTORY.json" ]; then
  jq '.properties.globalParameters' "$REPO_DIR/factory/$FACTORY.json"
else
  echo "  (Git 仓库里找不到 factory/$FACTORY.json)"
fi
echo ""
echo "[运行态/工厂]:"
api "" | jq '.properties.globalParameters'

echo ""
echo "--- 2) LinkedService 数量 ---"
DEV_LS=$(ls "$REPO_DIR/linkedService/"*.json 2>/dev/null | wc -l | tr -d ' ')
RT_LS=$(api 'linkedservices' | jq '.value | length')
echo "[开发态]: $DEV_LS 个"
echo "[运行态]: $RT_LS 个"

echo ""
echo "--- 3) Dataset 数量 ---"
DEV_DS=$(ls "$REPO_DIR/dataset/"*.json 2>/dev/null | wc -l | tr -d ' ')
RT_DS=$(api 'datasets' | jq '.value | length')
echo "[开发态]: $DEV_DS 个"
echo "[运行态]: $RT_DS 个"

echo ""
echo "--- 4) Pipeline 数量 ---"
DEV_PL=$(ls "$REPO_DIR/pipeline/"*.json 2>/dev/null | wc -l | tr -d ' ')
RT_PL=$(api 'pipelines' | jq '.value | length')
echo "[开发态]: $DEV_PL 个"
echo "[运行态]: $RT_PL 个"

echo ""
echo "============================================================"
# ----- 8) 自动判断是否一致 -----
if [ "$DEV_LS" = "$RT_LS" ] && [ "$DEV_DS" = "$RT_DS" ] && [ "$DEV_PL" = "$RT_PL" ]; then
  echo "  ✅ 开发态 == 运行态 (Studio 已点过'发布')"
else
  echo "  ⚠️  开发态 != 运行态 (Git 改了但运行态没同步,需要点'发布')"
fi
echo "============================================================"
