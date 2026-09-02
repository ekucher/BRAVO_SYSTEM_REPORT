<#
.SYNOPSIS
    Точка запуску BRAVO SYSTEM REPORT.
.DESCRIPTION
    Запускає основний скрипт із каталогу dist.
    Відносний OutputPath рахується від кореня репозиторію, а не від dist.

    Єдине джерело істини для дефолтних значень параметрів — src/05-Params.ps1
    (компілюється в dist/Get-BravoSystemReport.ps1). Цей wrapper НЕ дублює
    дефолти самостійно: параметр форвардиться в dist лише якщо користувач
    явно його передав ($PSBoundParameters), інакше застосовується єдиний
    дефолт з dist. Так само форвардинг через `& $ScriptPath @ForwardParameters`
    (splat, in-process виклик) коректно передає -Zip:$false — на відміну від
    forwarding через elevation-relaunch у dist (там серіалізація в CLI-текст,
    інше обмеження, вирішене окремо через -NoZip).
.NOTES
    Консольний вивід і документація проекту ведуться українською мовою.
    У службовому PowerShell-виводі не використовуються emoji.
    HTML-звіт є окремим візуальним артефактом і може містити emoji.
#>

[CmdletBinding()]
param(
    [ValidateSet('Quick','Full','Deep','Forensic')]
    [string]$Profile,

    [string]$OutputPath = '',

    [switch]$JSONOnly,
    [switch]$CSV,
    [switch]$Zip,
    [switch]$NoZip,
    [switch]$NoEmoji,
    [switch]$NoElevate,
    [switch]$NoPause,
    [switch]$NoOpenFolder,
    [switch]$SkipElevation,
    [switch]$SkipPublicIP,
    [switch]$SkipGeoIP,
    [switch]$Offline,
    [switch]$Strict,
    [switch]$Sanitize,
    [ValidateSet('Basic','Strict')]
    [string]$SanitizeLevel,
    [switch]$SkipUpdateSearch,

    [int]$EventLogDays = 0,
    [int]$UpdateSearchTimeoutSec,

    [string]$EmailTo,
    [string]$EmailFrom,
    [string]$SmtpServer,

    [switch]$ExportPdf
)

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
$ScriptPath = Join-Path $RepoRoot 'dist\Get-BravoSystemReport.ps1'

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Не знайдено основний скрипт: $ScriptPath"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $ResolvedOutputPath = Join-Path $RepoRoot 'reports'
} elseif ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $ResolvedOutputPath = $OutputPath
} else {
    $ResolvedOutputPath = Join-Path $RepoRoot $OutputPath
}

# Транспарентний passthrough: форвардиться лише те, що користувач ЯВНО
# передав. OutputPath — виняток, рахується окремо (base = корінь репо,
# не dist), тому завжди форвардиться з уже resolved-значенням. Це замінює
# ручний список `if ($X) { $ForwardParameters.X = $true }` на кожен
# параметр — саме такий ручний список і був причиною P0.1-P0.3 (дрейф
# дефолтів/забуті параметри між wrapper і dist), тому нові параметри
# (SkipUpdateSearch, UpdateSearchTimeoutSec тощо) форвардяться автоматично
# і не потребують окремого рядка тут.
$ForwardParameters = @{}
foreach ($key in $PSBoundParameters.Keys) {
    if ($key -eq 'OutputPath') { continue }
    $ForwardParameters[$key] = $PSBoundParameters[$key]
}
$ForwardParameters['OutputPath'] = $ResolvedOutputPath

& $ScriptPath @ForwardParameters
exit $LASTEXITCODE
