<#
.SYNOPSIS
    Публікує поточний проект на GitHub.
.DESCRIPTION
    Потребує Git, GitHub CLI та активної авторизації gh.
    Скрипт збережено у UTF-8 з BOM для коректної роботи українського тексту у Windows PowerShell 5.1.
#>

[CmdletBinding()]
param(
    [string]$RepoName = 'BRAVO_SYSTEM_REPORT',
    [string]$Owner = 'ekucher',
    [switch]$Public
)

$ErrorActionPreference = 'Stop'

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit 1
}

try { Clear-Host } catch {}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Fail 'Git не знайдено у PATH.'
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Fail 'GitHub CLI не знайдено у PATH.'
}

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

if (-not (Test-Path '.git')) {
    Write-Info 'Ініціалізація локального Git-репозиторію...'
    git init
}

git branch -M main
git add .

$Changes = git status --porcelain
if ($Changes) {
    Write-Info 'Створення коміту...'
    git commit -m 'Ініціалізовано проект BRAVO SYSTEM REPORT'
} else {
    Write-Info 'Немає змін для коміту.'
}

$Visibility = if ($Public) { '--public' } else { '--private' }
$FullName = "$Owner/$RepoName"
$ExistingRemote = git remote get-url origin 2>$null

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ExistingRemote)) {
    Write-Info "Створення GitHub-репозиторію $FullName..."
    gh repo create $FullName $Visibility --source . --remote origin --push
} else {
    Write-Info "Remote origin уже існує: $ExistingRemote"
    Write-Info 'Відправлення поточної гілки...'
    git push -u origin HEAD
}

Write-Info 'Готово.'
