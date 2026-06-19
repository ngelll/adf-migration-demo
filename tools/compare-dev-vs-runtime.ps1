# compare-dev-vs-runtime.ps1
# 对比 ADF 的"开发态(GitHub main 分支)" vs "运行态(工厂资源对象库)"
#
# 用法:
#   .\compare-dev-vs-runtime.ps1 -Factory <factory-name>
#   .\compare-dev-vs-runtime.ps1 -Factory <factory-name> -ResourceGroup <rg> -Subscription <sub-id>
#
# 例如:
#   .\compare-dev-vs-runtime.ps1 -Factory adf-dst-southeastasia-demo
#
# 依赖: Azure CLI (az), Git, PowerShell 5.1+ 或 PowerShell 7+
# 前置: az login 已完成
#
# Windows PowerShell 版本 - 不需要装 jq 或 bash

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Factory,

    [Parameter(Position=1)]
    [string]$ResourceGroup = "rg-adf-migration-demo",

    [Parameter(Position=2)]
    [string]$Subscription = ""
)

$ErrorActionPreference = "Stop"

# ----- 1) 检查依赖 -----
$missingDeps = @()
foreach ($cmd in @('az', 'git')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        $missingDeps += $cmd
    }
}
if ($missingDeps.Count -gt 0) {
    Write-Host "❌ 缺少依赖: $($missingDeps -join ', ')" -ForegroundColor Red
    Write-Host ""
    Write-Host "安装方法:"
    Write-Host "  az:  winget install Microsoft.AzureCLI    或    https://aka.ms/installazurecliwindows"
    Write-Host "  git: winget install Git.Git    或    https://git-scm.com/download/win"
    exit 1
}

# ----- 2) 如果没指定订阅,用当前默认 -----
if (-not $Subscription) {
    try {
        $Subscription = (az account show --query id -o tsv 2>$null)
    } catch {}
    if (-not $Subscription) {
        Write-Host "❌ 找不到 Azure 订阅。请先运行: az login" -ForegroundColor Red
        exit 1
    }
}

# ----- 3) 自动识别仓库根目录(脚本目录的父目录) -----
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir

# ----- 4) 输出标题 -----
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  比较: $Factory" -ForegroundColor Cyan
Write-Host "  订阅: $Subscription" -ForegroundColor Cyan
Write-Host "  资源组: $ResourceGroup" -ForegroundColor Cyan
Write-Host "  仓库目录: $RepoDir" -ForegroundColor Cyan
Write-Host "  开发态(GitHub main) vs 运行态(工厂对象库)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ----- 5) 拉最新 Git -----
if (Test-Path "$RepoDir\.git") {
    Push-Location $RepoDir
    Write-Host ""
    Write-Host "→ 拉取 GitHub main 最新代码..." -ForegroundColor Yellow
    git fetch origin main -q 2>&1 | Out-Null
    git pull --rebase origin main -q 2>&1 | Out-Null
    $commit = git rev-parse --short HEAD
    Write-Host "  当前 commit: $commit"
    Pop-Location
}

# ----- 6) 拿 Azure token -----
Write-Host ""
Write-Host "→ 获取 Azure access token..." -ForegroundColor Yellow
$Token = (az account get-access-token --subscription $Subscription --resource https://management.azure.com --query accessToken -o tsv 2>$null)
if (-not $Token) {
    Write-Host "❌ 获取 token 失败。请运行: az login" -ForegroundColor Red
    exit 1
}

# ----- 7) API 辅助函数 -----
function Invoke-AdfApi {
    param([string]$ResourcePath)
    $url = "https://management.azure.com/subscriptions/$Subscription/resourceGroups/$ResourceGroup/providers/Microsoft.DataFactory/factories/$Factory" + $(if($ResourcePath){"/$ResourcePath"}else{""}) + "?api-version=2018-06-01"
    $headers = @{ Authorization = "Bearer $Token" }
    return Invoke-RestMethod -Uri $url -Headers $headers -Method GET
}

# ----- 8) 对比开发态 vs 运行态 -----

Write-Host ""
Write-Host "--- 1) GlobalParameter ---" -ForegroundColor Green
Write-Host "[开发态/Git main]:" -ForegroundColor White
$factoryJsonPath = "$RepoDir\factory\$Factory.json"
if (Test-Path $factoryJsonPath) {
    $factoryJson = Get-Content $factoryJsonPath -Raw | ConvertFrom-Json
    $factoryJson.properties.globalParameters | ConvertTo-Json -Depth 5
} else {
    Write-Host "  (Git 仓库里找不到 factory\$Factory.json)" -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "[运行态/工厂]:" -ForegroundColor White
$runtimeFactory = Invoke-AdfApi ""
$runtimeFactory.properties.globalParameters | ConvertTo-Json -Depth 5

Write-Host ""
Write-Host "--- 2) LinkedService 数量 ---" -ForegroundColor Green
$DevLS = (Get-ChildItem "$RepoDir\linkedService\*.json" -ErrorAction SilentlyContinue).Count
$RtLS = (Invoke-AdfApi "linkedservices").value.Count
Write-Host "[开发态]: $DevLS 个"
Write-Host "[运行态]: $RtLS 个"

Write-Host ""
Write-Host "--- 3) Dataset 数量 ---" -ForegroundColor Green
$DevDS = (Get-ChildItem "$RepoDir\dataset\*.json" -ErrorAction SilentlyContinue).Count
$RtDS = (Invoke-AdfApi "datasets").value.Count
Write-Host "[开发态]: $DevDS 个"
Write-Host "[运行态]: $RtDS 个"

Write-Host ""
Write-Host "--- 4) Pipeline 数量 ---" -ForegroundColor Green
$DevPL = (Get-ChildItem "$RepoDir\pipeline\*.json" -ErrorAction SilentlyContinue).Count
$RtPL = (Invoke-AdfApi "pipelines").value.Count
Write-Host "[开发态]: $DevPL 个"
Write-Host "[运行态]: $RtPL 个"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
# ----- 9) 自动判断是否一致 -----
if ($DevLS -eq $RtLS -and $DevDS -eq $RtDS -and $DevPL -eq $RtPL) {
    Write-Host "  ✅ 开发态 == 运行态 (Studio 已点过'发布')" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  开发态 != 运行态 (Git 改了但运行态没同步,需要点'发布')" -ForegroundColor Yellow
}
Write-Host "============================================================" -ForegroundColor Cyan
