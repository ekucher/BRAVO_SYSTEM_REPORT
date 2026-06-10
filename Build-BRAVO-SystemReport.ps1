[CmdletBinding()]
param(
    [string]$ManifestPath = ".\src\BRAVO.build.json",
    [switch]$Clean,
    [switch]$CreateSha512
)

$ErrorActionPreference = "Stop"

try { Clear-Host } catch {}

$RepoRoot = Split-Path -Parent $PSCommandPath
Set-Location $RepoRoot

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    throw $Message
}

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    Write-Fail "Не знайдено manifest: $ManifestPath"
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

$outputPath = Join-Path $RepoRoot $manifest.output
$outputDir = Split-Path -Parent $outputPath

if ($Clean -and (Test-Path -LiteralPath $outputPath)) {
    Remove-Item -LiteralPath $outputPath -Force
}

if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$header = @"
<#
    BRAVO SYSTEM REPORT
    Згенерований монолітний runtime-скрипт.
    GeneratedAt: $generatedAt

    УВАГА:
    Не редагуйте цей файл вручну.
    Зміни потрібно вносити у модулі src\*.ps1 і виконувати build.
#>

"@

Set-Content -LiteralPath $outputPath -Value $header -Encoding UTF8

foreach ($relativeFile in $manifest.files) {
    $modulePath = Join-Path $RepoRoot $relativeFile

    if (-not (Test-Path -LiteralPath $modulePath)) {
        Write-Fail "Не знайдено модуль: $relativeFile"
    }

    Write-Info "Додавання модуля: $relativeFile"

    Add-Content -LiteralPath $outputPath -Value ""
    Add-Content -LiteralPath $outputPath -Value "# ============================================================"
    Add-Content -LiteralPath $outputPath -Value "# MODULE: $relativeFile"
    Add-Content -LiteralPath $outputPath -Value "# ============================================================"
    Add-Content -LiteralPath $outputPath -Value ""

    $content = Get-Content -LiteralPath $modulePath -Raw -Encoding UTF8
    Add-Content -LiteralPath $outputPath -Value $content
}

$tokens = $null
$parseErrors = $null

$null = [System.Management.Automation.Language.Parser]::ParseFile(
    $outputPath,
    [ref]$tokens,
    [ref]$parseErrors
)

if ($parseErrors.Count -gt 0) {
    $parseErrors | Format-Table Message, Extent -AutoSize
    Write-Fail "Parser check не пройдено: $outputPath"
}

Write-Ok "Syntax OK: $outputPath"

if ($CreateSha512) {
    $shaPath = Join-Path $RepoRoot $manifest.sha512
    $hash = Get-FileHash -LiteralPath $outputPath -Algorithm SHA512
    $hash.Hash | Set-Content -LiteralPath $shaPath -Encoding ASCII
    Write-Ok "SHA512 created: $shaPath"
}

Write-Ok "Build completed successfully."
Write-Host "[INFO] Runtime: $outputPath" -ForegroundColor Cyan
