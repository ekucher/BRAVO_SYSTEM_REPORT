<#
.SYNOPSIS
    Publishes the current project to GitHub.

.DESCRIPTION
    Requires Git, GitHub CLI and active gh authentication.
    This helper intentionally uses ASCII-only console output to avoid encoding issues on legacy Windows consoles.
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
    Write-Fail 'Git was not found in PATH.'
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Fail 'GitHub CLI was not found in PATH.'
}

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

if (-not (Test-Path '.git')) {
    Write-Info 'Initializing local Git repository...'
    git init
}

git branch -M main
git add .

$Changes = git status --porcelain

if ($Changes) {
    Write-Info 'Creating initial commit...'
    git commit -m 'Ініціалізовано проект BRAVO SYSTEM REPORT'
} else {
    Write-Info 'No changes to commit.'
}

$Visibility = if ($Public) { '--public' } else { '--private' }
$FullName = "$Owner/$RepoName"

$ExistingRemote = git remote get-url origin 2>$null

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ExistingRemote)) {
    Write-Info "Creating GitHub repository $FullName..."
    gh repo create $FullName $Visibility --source . --remote origin --push
} else {
    Write-Info "Remote origin already exists: $ExistingRemote"
    Write-Info 'Pushing current branch...'
    git push -u origin HEAD
}

Write-Info 'Done.'
