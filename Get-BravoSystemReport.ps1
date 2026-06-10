<#
.SYNOPSIS
    Точка запуску BRAVO SYSTEM REPORT.
.DESCRIPTION
    Запускає основний скрипт із каталогу src.
    Відносний OutputPath рахується від кореня репозиторію, а не від src.
.NOTES
    Консольний вивід і документація проекту ведуться українською мовою.
    У службовому PowerShell-виводі не використовуються emoji.
    HTML-звіт є окремим візуальним артефактом і може містити emoji.
#>

[CmdletBinding()]
param(
    [ValidateSet('Quick','Full','Deep','Forensic')]
    [string]$Profile = 'Full',

    [string]$OutputPath = '',

    [switch]$JSONOnly,
    [switch]$CSV,
    [switch]$Zip,
    [switch]$NoEmoji,
    [switch]$NoElevate,
    [switch]$NoPause,
    [switch]$NoOpenFolder,
    [switch]$SkipElevation,

    [int]$EventLogDays = 0,

    [string]$EmailTo,
    [string]$EmailFrom = "systemaudit@$($env:COMPUTERNAME).local",
    [string]$SmtpServer = ''
)

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
$ScriptPath = Join-Path $RepoRoot 'dist\\Get-BravoSystemReport.ps1'

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

$ForwardParameters = @{
    Profile    = $Profile
    OutputPath = $ResolvedOutputPath
}

if ($JSONOnly)      { $ForwardParameters.JSONOnly = $true }
if ($CSV)           { $ForwardParameters.CSV = $true }
if ($Zip)           { $ForwardParameters.Zip = $true }
if ($NoEmoji)       { $ForwardParameters.NoEmoji = $true }
if ($NoElevate)     { $ForwardParameters.NoElevate = $true }
if ($NoPause)       { $ForwardParameters.NoPause = $true }
if ($NoOpenFolder)  { $ForwardParameters.NoOpenFolder = $true }
if ($SkipElevation) { $ForwardParameters.SkipElevation = $true }

if ($EventLogDays -gt 0) {
    $ForwardParameters.EventLogDays = $EventLogDays
}

if (-not [string]::IsNullOrWhiteSpace($EmailTo)) {
    $ForwardParameters.EmailTo = $EmailTo
}

if (-not [string]::IsNullOrWhiteSpace($EmailFrom)) {
    $ForwardParameters.EmailFrom = $EmailFrom
}

if (-not [string]::IsNullOrWhiteSpace($SmtpServer)) {
    $ForwardParameters.SmtpServer = $SmtpServer
}

& $ScriptPath @ForwardParameters
