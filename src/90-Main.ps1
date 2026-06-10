# MODULE: 90-Main.ps1
# Основний execution flow BRAVO SYSTEM REPORT.
# Param-блок винесено у src\05-Params.ps1.
# Helper-функції винесено у src\10-Core.ps1.

<#
.SYNOPSIS
    BRAVO SYSTEM REPORT — детальний аудит Windows-машини.
.DESCRIPTION
    Збирає базову інформацію про ОС, апаратне забезпечення, диски, мережу,
    безпеку, користувачів, процеси, служби, події та встановлене ПЗ.

    Версія 0.2.0 стабілізує початковий скрипт:
    - додає профілі аудиту;
    - додає OutputPath, NoOpenFolder, NoPause;
    - виправляє конфлікти змінних іконок з об'єктами CPU/дисків;
    - додає CollectionErrors та Findings;
    - виправляє обчислення часу виконання;
    - прибирає порожні catch-блоки.
.NOTES
    Рекомендована версія: Windows PowerShell 5.1+.
    Для частини даних потрібні права адміністратора.
#>
$ErrorActionPreference = 'Continue'
$ScriptStartTime = Get-Date
$ScriptVersion = "0.3.4"

function Show-Pause {
    param([string]$Message = 'Натисніть будь-яку клавішу для виходу...')

    Write-Host $Message -ForegroundColor Gray
    try {
        if ($Host.Name -eq 'ConsoleHost') {
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
    } catch {}

    try { Read-Host | Out-Null; return } catch {}
    try {
        Write-Host 'Автоматичне закриття через 10 секунд...' -ForegroundColor Gray
        Start-Sleep -Seconds 10
    } catch {}
}

function Get-ScriptDirectory {
    if ($PSScriptRoot -and (Test-Path -LiteralPath $PSScriptRoot)) { return $PSScriptRoot }
    if ($MyInvocation.MyCommand.Path) { return Split-Path -Parent $MyInvocation.MyCommand.Path }
    return (Get-Location).Path
}

function Format-Size {
    param([double]$GB)

    if ($null -eq $GB) { return '0 GB' }
    if ($GB -gt 1024) { return "$([Math]::Round($GB / 1024, 2)) TB" }
    return "$([Math]::Round($GB, 2)) GB"
}

function Convert-AuditDateTime {
    param(
        [Parameter(Mandatory = $false)]$Value,
        [bool]$UseCim = $false
    )

    if (-not $Value) { return $null }

    try {
        if ($UseCim -or $Value -is [datetime]) { return [datetime]$Value }
        return [Management.ManagementDateTimeConverter]::ToDateTime($Value)
    } catch {
        return $null
    }
}

function Add-AuditError {
    param(
        [string]$Section,
        [string]$Message
    )

    if (-not $script:Report) { return }

    $script:Report.CollectionErrors += [PSCustomObject]@{
        Time    = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Section = $Section
        Message = $Message
    }
}

function Add-AuditFinding {
    param(
        [ValidateSet('INFO','WARNING','CRITICAL')]
        [string]$Severity,
        [string]$Category,
        [string]$Message,
        [string]$Recommendation = ''
    )

    if (-not $script:Report) { return }

    $script:Report.Health.Findings += [PSCustomObject]@{
        Severity       = $Severity
        Category       = $Category
        Message        = $Message
        Recommendation = $Recommendation
    }
}

function Get-AuditObject {
    param(
        [string]$ClassName,
        [string]$Filter = '',
        [switch]$First
    )

    if ($script:UseCim) {
        if ($Filter) { $result = Get-CimInstance -ClassName $ClassName -Filter $Filter -ErrorAction Stop }
        else { $result = Get-CimInstance -ClassName $ClassName -ErrorAction Stop }
    } else {
        if ($Filter) { $result = Get-WmiObject -Class $ClassName -Filter $Filter -ErrorAction Stop }
        else { $result = Get-WmiObject -Class $ClassName -ErrorAction Stop }
    }

    if ($First) { return $result | Select-Object -First 1 }
    return $result
}



function Resolve-AuditOutputPath {
    param(
        [string]$RequestedPath,
        [string]$DefaultPath
    )

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) { $RequestedPath = $DefaultPath }

    if (-not [System.IO.Path]::IsPathRooted($RequestedPath)) {
        $RequestedPath = Join-Path $DefaultPath $RequestedPath
    }

    if (-not (Test-Path -LiteralPath $RequestedPath)) {
        New-Item -ItemType Directory -Path $RequestedPath -Force | Out-Null
    }

    return (Resolve-Path -LiteralPath $RequestedPath).Path
}

try { Clear-Host } catch {}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$PSMajorVersion = $PSVersionTable.PSVersion.Major
$OSVersion = [Environment]::OSVersion.Version
$IsWin8OrHigher = ($OSVersion.Major -ge 6 -and $OSVersion.Minor -ge 2) -or ($OSVersion.Major -ge 10)
$HaveCim = (Get-Command -Name Get-CimInstance -ErrorAction SilentlyContinue) -ne $null
$script:UseCim = $HaveCim -and $IsWin8OrHigher

if ($EventLogDays -le 0) {
    $EventLogDays = switch ($Profile) {
        'Quick'    { 1 }
        'Full'     { 3 }
        'Deep'     { 7 }
        'Forensic' { 14 }
        default    { 3 }
    }
}

$ScriptDirectory = Get-ScriptDirectory

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and -not $NoElevate -and -not $SkipElevation) {
    Write-Host '[INFO] Потрібні права адміністратора. Запит підвищення прав...' -ForegroundColor Yellow
    $scriptFullPath = $MyInvocation.MyCommand.Path
    if (-not $scriptFullPath) { $scriptFullPath = $PSCommandPath }

    if ($scriptFullPath -and (Test-Path -LiteralPath $scriptFullPath)) {
        $arguments = @('-SkipElevation')
        $arguments += "-Profile $Profile"
        $arguments += "-EventLogDays $EventLogDays"
        if ($OutputPath) { $arguments += "-OutputPath `"$OutputPath`"" }
        if ($JSONOnly) { $arguments += '-JSONOnly' }
        if ($CSV) { $arguments += '-CSV' }
        if ($Zip) { $arguments += '-Zip' }
        if ($NoEmoji) { $arguments += '-NoEmoji' }
        if ($NoPause) { $arguments += '-NoPause' }
        if ($NoOpenFolder) { $arguments += '-NoOpenFolder' }
        if ($EmailTo) { $arguments += "-EmailTo `"$EmailTo`"" }
        if ($EmailFrom) { $arguments += "-EmailFrom `"$EmailFrom`"" }
        if ($SmtpServer) { $arguments += "-SmtpServer `"$SmtpServer`"" }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`" $($arguments -join ' ')"
        $psi.Verb = 'runas'
        $psi.WorkingDirectory = $ScriptDirectory

        try {
            [System.Diagnostics.Process]::Start($psi) | Out-Null
            exit 0
        } catch {
            Write-Host "[INFO] Не вдалося підвищити права: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# У службовому PowerShell-виводі emoji не використовуються.
# HTML-звіт є винятком: emoji дозволені як частина візуального звіту.
$IconOk='[OK]'; $IconError='[ERROR]'; $IconCpu='[OK]'; $IconRam='[OK]'; $IconDisk='[OK]'; $IconNetwork='[OK]'; $IconSecurity='[OK]'
$IconDone='[SUCCESS]'; $IconJson='[OK]'; $IconHtml='[OK]'; $IconCsv='[OK]'; $IconGear='[INFO]'; $IconEvent='[OK]'
$IconFolder='[INFO]'; $IconDb='[OK]'; $IconPc='[INFO]'; $IconService='[OK]'; $IconZip='[OK]'; $IconEmail='[OK]'

Write-Host ''
Write-Host "=== BRAVO SYSTEM REPORT v$ScriptVersion ===" -ForegroundColor Cyan
Write-Host '=== ДЕТАЛЬНИЙ ЗВІТ ПРО WINDOWS-МАШИНУ ===' -ForegroundColor Cyan
Write-Host ''
Write-Host "[INFO] PowerShell: $($PSVersionTable.PSVersion), OS: $OSVersion, метод: $(if($script:UseCim){'CIM'}else{'WMI'}), профіль: $Profile" -ForegroundColor Gray
Write-Host "[INFO] Директорія: $ScriptDirectory" -ForegroundColor Cyan
Write-Host "$(if($isAdmin){'[OK] АДМІНІСТРАТОР'}else{'[INFO] ОБМЕЖЕНІ ПРАВА'})" -ForegroundColor $(if($isAdmin){'Green'}else{'Yellow'})
Write-Host ''

Set-Location $ScriptDirectory -ErrorAction SilentlyContinue

$script:Report = New-BravoReportModel

Write-Host '=== ЗБІР ІНФОРМАЦІЇ ПРО МАШИНУ ===' -ForegroundColor Cyan
Write-Host ''

# --- ОС ---
Get-BravoOperatingSystemAudit

# --- .NET ---
try {
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full') {
        $release = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue).Release
        if ($release -ge 533320) { $script:Report.DotNet.v4 = '4.8.1+' }
        elseif ($release -ge 528040) { $script:Report.DotNet.v4 = '4.8' }
        elseif ($release -ge 461808) { $script:Report.DotNet.v4 = '4.7.2+' }
        elseif ($release) { $script:Report.DotNet.v4 = "Release $release" }
    }
} catch {
    Add-AuditError -Section 'DotNet' -Message $_.Exception.Message
}

# --- Апаратне забезпечення ---
Get-BravoHardwareAudit

# --- BIOS ---
try {
    $biosInfo = Get-AuditObject -ClassName 'Win32_BIOS' -First
    $script:Report.BIOS.Version = ($biosInfo.SMBIOSBIOSVersion, $biosInfo.Version | Where-Object { $_ } | Select-Object -First 1)
    $script:Report.BIOS.SerialNumber = $biosInfo.SerialNumber
    $releaseDate = Convert-AuditDateTime -Value $biosInfo.ReleaseDate -UseCim:$script:UseCim
    if ($releaseDate) { $script:Report.BIOS.ReleaseDate = $releaseDate.ToString('yyyy-MM-dd') }
} catch {
    Add-AuditError -Section 'BIOS' -Message $_.Exception.Message
}

# --- Диски ---
Get-BravoStorageAudit

# --- Мережа ---
Get-BravoNetworkAudit

# --- Безпека ---
Get-BravoSecurityAudit

# --- Користувачі ---
Get-BravoUsersAudit

# --- Процеси та служби ---
Get-BravoProcessesServicesAudit

# --- Журнали подій ---
Get-BravoEventLogsAudit

# --- Програмне забезпечення ---
Get-BravoSoftwareAudit

# --- Health score ---
Update-BravoHealthScore

# ============================================================
# ЗБЕРЕЖЕННЯ ЗВІТІВ
# ============================================================

try {
    $outputDir = Resolve-AuditOutputPath -RequestedPath $OutputPath -DefaultPath $ScriptDirectory
} catch {
    Add-AuditError -Section 'OutputPath' -Message $_.Exception.Message
    $outputDir = $ScriptDirectory
}

$script:Report.OutputPath = $outputDir
$baseFileName = "BravoSystemReport_$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

Write-Host ''
Write-Host '=== ГЕНЕРАЦІЯ ЗВІТІВ ===' -ForegroundColor Cyan
Write-Host ''
Write-Host "$IconFolder Збереження: $outputDir" -ForegroundColor Cyan

# JSON
Export-BravoJsonReport -OutputDir $outputDir -BaseFileName $baseFileName

# HTML
Export-BravoHtmlReport -OutputDir $outputDir -BaseFileName $baseFileName -JSONOnly $JSONOnly -EventLogDays $EventLogDays -Profile $Profile -ScriptVersion $ScriptVersion

# CSV
if ($CSV) {
    try {
        $csvPath = Join-Path $outputDir "$baseFileName.csv"
        $csvData = @(
            [PSCustomObject]@{Parameter='ComputerName'; Value=$script:Report.ComputerName}
            [PSCustomObject]@{Parameter='Timestamp'; Value=$script:Report.Timestamp}
            [PSCustomObject]@{Parameter='Profile'; Value=$script:Report.Profile}
            [PSCustomObject]@{Parameter='HealthScore'; Value=$script:Report.Health.Score}
            [PSCustomObject]@{Parameter='HealthStatus'; Value=$script:Report.Health.Status}
            [PSCustomObject]@{Parameter='OS'; Value=$script:Report.OS.Caption}
            [PSCustomObject]@{Parameter='OSBuild'; Value=$script:Report.OS.Build}
            [PSCustomObject]@{Parameter='UptimeDays'; Value=$script:Report.OS.UptimeDays}
            [PSCustomObject]@{Parameter='CPU_Cores'; Value=$script:Report.Hardware.CPU.Cores}
            [PSCustomObject]@{Parameter='CPU_LogicalProcessors'; Value=$script:Report.Hardware.CPU.LogicalProcessors}
            [PSCustomObject]@{Parameter='CPU_Load'; Value=$script:Report.Hardware.CPU.LoadPercent}
            [PSCustomObject]@{Parameter='RAM_GB'; Value=$script:Report.Hardware.RAM.TotalGB}
            [PSCustomObject]@{Parameter='RAM_Used_Percent'; Value=$script:Report.Hardware.RAM.UsedPercent}
            [PSCustomObject]@{Parameter='Disk_Free_Percent'; Value=$script:Report.Hardware.Disks.FreePercent}
            [PSCustomObject]@{Parameter='IPv4'; Value=($script:Report.Network.IP.IPv4 -join '; ')}
            [PSCustomObject]@{Parameter='RDP_Enabled'; Value=$script:Report.Security.RemoteAccess.RDPEnabled}
            [PSCustomObject]@{Parameter='UAC_Enabled'; Value=$script:Report.Security.UAC.Enabled}
            [PSCustomObject]@{Parameter='Processes'; Value=$script:Report.Processes.Total}
            [PSCustomObject]@{Parameter='Running_Services'; Value=$script:Report.Services.Running}
            [PSCustomObject]@{Parameter='AutomaticStoppedServices'; Value=$script:Report.Services.AutomaticStopped.Count}
            [PSCustomObject]@{Parameter='Errors_24h'; Value=$script:Report.EventLogs.SystemErrors24h}
            [PSCustomObject]@{Parameter='Errors_ProfileDays'; Value=$script:Report.EventLogs.SystemErrors}
            [PSCustomObject]@{Parameter='Installed_Software'; Value=$script:Report.Software.Installed.Count}
            [PSCustomObject]@{Parameter='Local_Admins'; Value=$script:Report.Users.LocalAdmins.Count}
            [PSCustomObject]@{Parameter='Findings'; Value=$script:Report.Health.Findings.Count}
            [PSCustomObject]@{Parameter='CollectionErrors'; Value=$script:Report.CollectionErrors.Count}
        )
        $csvData | Export-Csv $csvPath -NoTypeInformation -Encoding utf8
        $script:Report.GeneratedFiles += $csvPath
        Write-Host "  $IconCsv CSV: $baseFileName.csv" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Export.Csv' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка CSV: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ZIP
if ($Zip) {
    try {
        $zipPath = Join-Path $outputDir "$baseFileName.zip"
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
        if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

        $zipStream = New-Object System.IO.FileStream($zipPath, [System.IO.FileMode]::Create)
        $zipArchive = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)

        foreach ($file in $script:Report.GeneratedFiles) {
            if (Test-Path -LiteralPath $file) {
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $file, (Split-Path $file -Leaf), [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
            }
        }

        $zipArchive.Dispose()
        $zipStream.Dispose()
        $script:Report.GeneratedFiles += $zipPath
        Write-Host "  $IconZip ZIP: $baseFileName.zip" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Export.Zip' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка створення ZIP: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Email
if ($EmailTo) {
    try {
        $smtpToUse = if ($SmtpServer) { $SmtpServer } else { "smtp.$($env:USERDNSDOMAIN.ToLower())" }
        $mailBody = "BRAVO SYSTEM REPORT - $($script:Report.ComputerName)`n`nOS: $($script:Report.OS.Caption)`nHealth: $($script:Report.Health.Score)/100 ($($script:Report.Health.Status))`nCPU: $($script:Report.Hardware.CPU.LoadPercent)%`nRAM: $($script:Report.Hardware.RAM.TotalGB) GB ($($script:Report.Hardware.RAM.UsedPercent)%)`nDisk Free: $($script:Report.Hardware.Disks.FreePercent)%`nUptime: $($script:Report.OS.UptimeDays) days"
        $attachments = @($script:Report.GeneratedFiles | Where-Object { $_ -and (Test-Path -LiteralPath $_) -and ($_ -notlike '*.zip') })
        Send-MailMessage -To $EmailTo -From $EmailFrom -Subject "BRAVO SYSTEM REPORT - $($script:Report.ComputerName)" -Body $mailBody -SmtpServer $smtpToUse -Attachments $attachments -ErrorAction Stop
        Write-Host "  $IconEmail Email відправлено на $EmailTo" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Export.Email' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка відправки Email: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Фінал
$elapsedSeconds = [Math]::Round(((Get-Date) - $ScriptStartTime).TotalSeconds, 2)

Write-Host ''
Write-Host '=== АУДИТ МАШИНИ ЗАВЕРШЕНО ===' -ForegroundColor Green
Write-Host ''
Write-Host "$IconFolder Звіти збережено: $outputDir" -ForegroundColor Cyan
Write-Host "$IconJson JSON: $baseFileName.json" -ForegroundColor White
if (-not $JSONOnly) { Write-Host "$IconHtml HTML: $baseFileName.html" -ForegroundColor White }
if ($CSV) { Write-Host "$IconCsv CSV: $baseFileName.csv" -ForegroundColor White }
if ($Zip) { Write-Host "$IconZip ZIP: $baseFileName.zip" -ForegroundColor White }
Write-Host "Оцінка стану: $($script:Report.Health.Score)/100 ($($script:Report.Health.Status))" -ForegroundColor Cyan
Write-Host "Знахідки: $($script:Report.Health.Findings.Count); помилки збору: $($script:Report.CollectionErrors.Count)" -ForegroundColor Cyan
Write-Host "Час виконання: $elapsedSeconds сек" -ForegroundColor Cyan
Write-Host ''

if (-not $NoOpenFolder) {
    try { Start-Process explorer.exe -ArgumentList "`"$outputDir`"" -ErrorAction SilentlyContinue } catch {
        Add-AuditError -Section 'OpenFolder' -Message $_.Exception.Message
    }
}

if (-not $NoPause) { Show-Pause }
exit 0
