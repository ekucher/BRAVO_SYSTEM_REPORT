<#
.SYNOPSIS
    Точка запуску BRAVO SYSTEM REPORT.
.DESCRIPTION
    Запускає основний скрипт із каталогу src. Залишено для зручного старту з кореня репозиторію.
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArguments
)

$ErrorActionPreference = 'Stop'
$ScriptPath = Join-Path $PSScriptRoot 'src\Get-BravoSystemReport.ps1'

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Не знайдено основний скрипт: $ScriptPath"
}

& $ScriptPath @RemainingArguments
