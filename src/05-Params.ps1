# MODULE: 05-Params.ps1
# Параметри запуску BRAVO SYSTEM REPORT.
# Цей файл підключається build-скриптом перед основною runtime-логікою.
[CmdletBinding()]
param(
    [ValidateSet('Quick','Full','Deep','Forensic')]
    [string]$Profile = 'Forensic',

    [string]$OutputPath = '',

    [switch]$JSONOnly,
    [switch]$CSV,
    [switch]$Zip = $true,
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

    [int]$EventLogDays = 0,

    [switch]$SkipUpdateSearch,
    [int]$UpdateSearchTimeoutSec = 180,

    [string]$EmailTo,
    [string]$EmailFrom = "systemaudit@$($env:COMPUTERNAME).local",
    [string]$SmtpServer = ''
)
