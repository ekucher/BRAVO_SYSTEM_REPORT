<#
.SYNOPSIS
    Застосовує patch стабілізації BRAVO SYSTEM REPORT v0.2.0.
.DESCRIPTION
    Копіює перевірені файли з patch/files у корінь репозиторію.
    Скрипт збережено у UTF-8 з BOM для коректної роботи українського тексту у Windows PowerShell 5.1.
#>

[CmdletBinding()]
param(
    [switch]$Commit,
    [switch]$Push,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Write-Log {
    param(
        [ValidateSet('INFO','OK','SUCCESS','ERROR')]
        [string]$Level,
        [string]$Message
    )

    $Color = switch ($Level) {
        'INFO'  { 'Cyan' }
        'OK'    { 'Green' }
        'SUCCESS' { 'Green' }
        'ERROR' { 'Red' }
        default { 'White' }
    }

    Write-Host ("[{0}] {1}" -f $Level, $Message) -ForegroundColor $Color
}

function Test-RepositoryRoot {
    param([string]$Path)

    return (
        (Test-Path (Join-Path $Path '.git')) -and
        (Test-Path (Join-Path $Path 'src')) -and
        (Test-Path (Join-Path $Path 'tools'))
    )
}

try { Clear-Host } catch {}

Write-Host '=== ЗАСТОСУВАННЯ PATCH v0.2.0 ===' -ForegroundColor Cyan
$RepoRoot = (Get-Location).Path

if (-not (Test-RepositoryRoot -Path $RepoRoot)) {
    throw 'Поточна директорія не схожа на корінь репозиторію BRAVO SYSTEM REPORT.'
}

$PatchRoot = Join-Path $RepoRoot 'patch'
$FilesRoot = Join-Path $PatchRoot 'files'

if (-not (Test-Path $FilesRoot)) {
    throw "Не знайдено директорію файлів patch: $FilesRoot"
}

Write-Log INFO "Корінь репозиторію: $RepoRoot"
Write-Log INFO "Директорія файлів patch: $FilesRoot"

$FilesToCopy = @(
    @{ Source = 'README.md'; Target = 'README.md' },
    @{ Source = 'CHANGELOG.md'; Target = 'CHANGELOG.md' },
    @{ Source = '.editorconfig'; Target = '.editorconfig' },
    @{ Source = 'docs/ROADMAP.md'; Target = 'docs/ROADMAP.md' },
    @{ Source = 'src/Get-BravoSystemReport.ps1'; Target = 'src/Get-BravoSystemReport.ps1' },
    @{ Source = 'tools/Publish-ToGitHub.ps1'; Target = 'tools/Publish-ToGitHub.ps1' }
)

foreach ($Item in $FilesToCopy) {
    $SourcePath = Join-Path $FilesRoot $Item.Source
    $TargetPath = Join-Path $RepoRoot $Item.Target
    $TargetDir = Split-Path -Parent $TargetPath

    if (-not (Test-Path $SourcePath)) {
        throw "Не знайдено обов'язковий файл patch: $SourcePath"
    }

    if ($DryRun) {
        Write-Log INFO "Перевірка копіювання: $($Item.Source) -> $($Item.Target)"
        continue
    }

    if ($TargetDir -and -not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    Copy-Item -Path $SourcePath -Destination $TargetPath -Force
    Write-Log OK "Скопійовано: $($Item.Target)"
}

if ($DryRun) {
    Write-Log INFO 'Режим перевірки завершено. Файли не змінено.'
    exit 0
}

Write-Host '=== ПЕРЕВІРКА POWERSHELL ===' -ForegroundColor Cyan
Write-Log INFO 'Перевірка синтаксису PowerShell...'
$PowerShellFiles = @(
    'src/Get-BravoSystemReport.ps1',
    'tools/Publish-ToGitHub.ps1'
)

foreach ($RelativePath in $PowerShellFiles) {
    $FullPath = Join-Path $RepoRoot $RelativePath
    $Tokens = $null
    $Errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($FullPath, [ref]$Tokens, [ref]$Errors) | Out-Null

    if ($Errors -and $Errors.Count -gt 0) {
        Write-Log ERROR "Помилки синтаксису у файлі: $RelativePath"
        $Errors | Format-List
        throw "Перевірка синтаксису PowerShell не пройдена: $RelativePath"
    }

    Write-Log OK "Синтаксис коректний: $RelativePath"
}

Write-Log INFO 'Перевірка відсутності emoji у PowerShell-скриптах...'
foreach ($RelativePath in $PowerShellFiles) {
    $FullPath = Join-Path $RepoRoot $RelativePath
    $Content = Get-Content -LiteralPath $FullPath -Raw
    $HasEmoji = $false

    foreach ($Char in $Content.ToCharArray()) {
        if ([int][char]$Char -ge 0xD800 -and [int][char]$Char -le 0xDFFF) {
            $HasEmoji = $true
            break
        }
    }

    if ($HasEmoji) {
        throw "У скрипті знайдено emoji або surrogate-символи: $RelativePath"
    }

    Write-Log OK "Emoji не знайдено: $RelativePath"
}

if ($Commit) {
    Write-Host '=== GIT COMMIT ===' -ForegroundColor Cyan
    Write-Log INFO 'Підготовка Git-коміту...'
    git add README.md CHANGELOG.md .editorconfig docs/ROADMAP.md src/Get-BravoSystemReport.ps1 tools/Publish-ToGitHub.ps1 review patch

    $Changes = git status --porcelain
    if ($Changes) {
        git commit -m 'Стабілізовано BRAVO SYSTEM REPORT v0.2.0'
        Write-Log OK 'Коміт створено.'
    } else {
        Write-Log INFO 'Немає змін для коміту.'
    }
}

if ($Push) {
    Write-Host '=== GIT PUSH ===' -ForegroundColor Cyan
    Write-Log INFO 'Відправлення поточної гілки на GitHub...'
    git push -u origin HEAD
    Write-Log SUCCESS 'Відправлення завершено.'
}

Write-Log SUCCESS 'Patch стабілізації v0.2.0 застосовано.'
