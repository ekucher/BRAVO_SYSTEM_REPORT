<#
.SYNOPSIS
    Точка запуску BRAVO SYSTEM REPORT.
.DESCRIPTION
    Запускає основний скрипт із каталогу src.
    Параметри явно приймаються root wrapper-ом і передаються в основний скрипт через splatting.
.NOTES
    Консольний вивід і документація проекту ведуться українською мовою.
    У скриптах не використовуються emoji.
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

$ScriptPath = Join-Path $PSScriptRoot 'src\Get-BravoSystemReport.ps1'

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Не знайдено основний скрипт: $ScriptPath"
}

$ForwardParameters = @{
    Profile = $Profile
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $ForwardParameters.OutputPath = $OutputPath
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