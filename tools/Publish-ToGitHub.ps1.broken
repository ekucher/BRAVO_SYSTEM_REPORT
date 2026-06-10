<#
.SYNOPSIS
    Створює приватний GitHub-репозиторій BRAVO_SYSTEM_REPORT і пушить поточний проект.
.DESCRIPTION
    Потребує встановлений GitHub CLI (`gh`) та авторизацію `gh auth login`.
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

function Write-ErrorAndExit {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit 1
}

try { Clear-Host } catch {}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-ErrorAndExit 'Git не знайдено в PATH.'
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-ErrorAndExit 'GitHub CLI не знайдено в PATH. Встановіть gh або створіть репозиторій вручну на GitHub.'
}

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

if (-not (Test-Path '.git')) {
    Write-Info 'Ініціалізація локального Git-репозиторію...'
    git init
}

git branch -M main
git add .

$hasChanges = git status --porcelain
if ($hasChanges) {
    Write-Info 'Створення першого коміту...'
    git commit -m 'Ініціалізовано проект BRAVO SYSTEM REPORT'
} else {
    Write-Info 'Немає нових змін для коміту.'
}

$visibility = if ($Public) { '--public' } else { '--private' }
$fullName = "$Owner/$RepoName"

Write-Info "Створення GitHub-репозиторію $fullName..."
gh repo create $fullName $visibility --source . --remote origin --push

Write-Info 'Готово.'
