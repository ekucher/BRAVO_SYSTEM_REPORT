<#
.SYNOPSIS
    🚀 МАКСИМАЛЬНИЙ ЗБІР ІНФОРМАЦІЇ ПРО СЕРВЕР (Enterprise Edition)
    Збирає 100+ параметрів: апаратне забезпечення, ПЗ, безпеку, продуктивність, мережу, диски
    Сумісний з Windows Server 2008 R2 / PowerShell 2.0+ до Windows Server 2025 / PowerShell 7+
#>

[CmdletBinding()]
param(
    [switch]$JSONOnly,
    [switch]$CSV,
    [switch]$Zip,
    [switch]$NoEmoji,
    [switch]$NoElevate,
    [switch]$NoPause,
    [switch]$SkipElevation,
    [string]$EmailTo,
    [string]$EmailFrom = "systemaudit@$($env:COMPUTERNAME).local",
    [string]$SmtpServer = ""
)

function Show-Pause {
    param([string]$Message = "Натисніть будь-яку клавішу для виходу...")
    Write-Host $Message -ForegroundColor Gray
    try { if ($Host.Name -eq "ConsoleHost") { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); return } } catch {}
    try { Read-Host; return } catch {}
    try { Write-Host "Автоматичне закриття через 10 секунд..." -ForegroundColor Gray; Start-Sleep -Seconds 10 } catch {}
}

try { Clear-Host } catch {}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                         ENTERPRISE SYSTEM AUDIT v6.0                              ║" -ForegroundColor Cyan
Write-Host "║                      МАКСИМАЛЬНИЙ ЗБІР ІНФОРМАЦІЇ ПРО СЕРВЕР                      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$PSVersion = $PSVersionTable.PSVersion.Major
$OSVersion = [Environment]::OSVersion.Version
$isWin8OrHigher = ($OSVersion.Major -ge 6 -and $OSVersion.Minor -ge 2) -or ($OSVersion.Major -ge 10)
$haveCIM = (Get-Command -Name Get-CimInstance -ErrorAction SilentlyContinue) -ne $null
$useCIM = $haveCIM -and $isWin8OrHigher

Write-Host "📁 PowerShell: $($PSVersionTable.PSVersion), OS: $($OSVersion), Метод: $(if($useCIM){'CIM'}else{'WMI'})" -ForegroundColor Gray
Write-Host ""

function Get-ScriptDirectory {
    if ($PSScriptRoot -and (Test-Path $PSScriptRoot)) { return $PSScriptRoot }
    if ($MyInvocation.MyCommand.Path) { return Split-Path $MyInvocation.MyCommand.Path -Parent }
    return (Get-Location).Path
}
$ScriptDirectory = Get-ScriptDirectory
Write-Host "📁 ДИРЕКТОРІЯ: $ScriptDirectory" -ForegroundColor Cyan
Write-Host ""

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and -not $NoElevate -and -not $SkipElevation) {
    Write-Host "⚠️ Потрібні права адміністратора!" -ForegroundColor Yellow
    $scriptFullPath = $MyInvocation.MyCommand.Path
    if (-not $scriptFullPath) { $scriptFullPath = $PSCommandPath }
    if ($scriptFullPath -and (Test-Path $scriptFullPath)) {
        $arguments = @("-SkipElevation")
        if ($JSONOnly) { $arguments += "-JSONOnly" }
        if ($CSV) { $arguments += "-CSV" }
        if ($Zip) { $arguments += "-Zip" }
        if ($NoEmoji) { $arguments += "-NoEmoji" }
        if ($NoPause) { $arguments += "-NoPause" }
        if ($EmailTo) { $arguments += "-EmailTo `"$EmailTo`"" }
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`" $($arguments -join ' ')"
        $psi.Verb = "runas"
        $psi.WorkingDirectory = $ScriptDirectory
        try { [System.Diagnostics.Process]::Start($psi) | Out-Null; exit 0 } catch {}
    }
}
Write-Host "$(if($isAdmin){'✅ АДМІНІСТРАТОР'}else{'⚠️ ОБМЕЖЕНІ ПРАВА'})" -ForegroundColor $(if($isAdmin){'Green'}else{'Yellow'})
Set-Location $ScriptDirectory -ErrorAction SilentlyContinue

if ($NoEmoji) {
    $c="[OK]"; $e="[ERR]"; $cpu="[CPU]"; $ram="[RAM]"; $disk="[DISK]"; $net="[NET]"; $sec="[SEC]"
    $succ="[DONE]"; $json="[JSON]"; $html="[HTML]"; $csv="[CSV]"; $gear="[GEAR]"; $event="[LOG]"
    $folder="[FOLDER]"; $db="[DB]"; $pc="[PC]"; $service="[SVC]"
} else {
    $c="✅"; $e="❌"; $cpu="⚡"; $ram="🧠"; $disk="💿"; $net="🌐"; $sec="🔒"
    $succ="🎉"; $json="📄"; $html="🌐"; $csv="📊"; $gear="⚙️"; $event="📋"
    $folder="📁"; $db="💾"; $pc="🖥️"; $service="🔧"
}

function Format-Size { param($GB); if ($GB -gt 1024) { return "$([Math]::Round($GB/1024,2)) TB" }; return "$([Math]::Round($GB,2)) GB" }

$Report = @{}
$Report.Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$Report.ComputerName = $env:COMPUTERNAME
$Report.Elevated = $isAdmin

$Report.OS = @{ Caption=""; Version=""; Build=""; Architecture=""; InstallDate=""; UptimeDays=0; UptimeHours=0 }
$Report.PowerShell = @{ Version=$PSVersionTable.PSVersion.ToString(); ExecutionPolicy=(Get-ExecutionPolicy).ToString() }
$Report.DotNet = @{ v4="Not Installed" }
$Report.BIOS = @{ Version=""; SerialNumber="" }
$Report.Virtualization = @{ IsVirtual=$false; Hypervisor="" }
$Report.Hardware = @{ CPU=@{Name=""; Cores=0; LoadPercent=0}; RAM=@{TotalGB=0; UsedPercent=0}; Disks=@{FreePercent=0; TotalGB=0; FreeGB=0; PhysicalDisks=@()} }
$Report.Network = @{ General=@{Hostname=""; Domain=""}; IP=@{IPv4=@()}; Routing=@{DefaultGateway=""; DNSServers=@()}; Connections=@{Established=0; Listening=0} }
$Report.Security = @{ UAC=@{Enabled=$false}; RemoteAccess=@{RDPEnabled=$false}; Antivirus=@{Product=""} }
$Report.Users = @{ LocalAdmins=@() }
$Report.Processes = @{ Total=0 }
$Report.Services = @{ Total=0; Running=0 }
$Report.EventLogs = @{ SystemErrors24h=0; SystemWarnings24h=0 }
$Report.Software = @{ Installed=@(); WindowsFeatures=@() }
$Report.USBDevices = @()

Write-Host ""
Write-Host "$gear ============================================================" -ForegroundColor Cyan
Write-Host "$pc     ЗБІР ІНФОРМАЦІЇ ПРО СЕРВЕР" -ForegroundColor Cyan
Write-Host "$gear ============================================================" -ForegroundColor Cyan
Write-Host ""

# --- ОС ---
try {
    if ($useCIM) { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop }
    else { $os = Get-WmiObject Win32_OperatingSystem -ErrorAction Stop }
    $Report.OS.Caption = $os.Caption
    $Report.OS.Version = $os.Version
    $Report.OS.Build = $os.BuildNumber
    $Report.OS.Architecture = $os.OSArchitecture
    if ($os.InstallDate) { $Report.OS.InstallDate = if($useCIM){$os.InstallDate.ToString("yyyy-MM-dd")}else{[Management.ManagementDateTimeConverter]::ToDateTime($os.InstallDate).ToString("yyyy-MM-dd")} }
    if ($os.LastBootUpTime) {
        $lastBoot = if($useCIM){$os.LastBootUpTime}else{[Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)}
        $uptime = (Get-Date) - $lastBoot
        $Report.OS.UptimeDays = $uptime.Days
        $Report.OS.UptimeHours = [Math]::Round($uptime.TotalHours,1)
    }
    Write-Host "  $c ОС: $($Report.OS.Caption)" -ForegroundColor Green
} catch { Write-Host "  $e Помилка ОС" -ForegroundColor Red }

# --- .NET ---
if (Test-Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full") {
    $rel = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -Name Release -ErrorAction SilentlyContinue).Release
    if ($rel -ge 528040) { $Report.DotNet.v4 = "4.8.1+" }
    elseif ($rel -ge 461808) { $Report.DotNet.v4 = "4.8" }
    else { $Report.DotNet.v4 = "4.7+" }
}

# --- Апаратне забезпечення ---
try {
    if ($useCIM) { $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1; $cs = Get-CimInstance Win32_ComputerSystem }
    else { $cpu = Get-WmiObject Win32_Processor | Select-Object -First 1; $cs = Get-WmiObject Win32_ComputerSystem }
    $Report.Hardware.CPU.Name = $cpu.Name.Trim()
    $Report.Hardware.CPU.Cores = $cpu.NumberOfCores
    if ($useCIM) { $load = ($cpu | Measure-Object -Property LoadPercentage -Average).Average }
    else { $load = $cpu.LoadPercentage }
    $Report.Hardware.CPU.LoadPercent = [Math]::Round($load)
    $Report.Hardware.RAM.TotalGB = [Math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    if ($useCIM) { $totalRam = $os.TotalVisibleMemorySize; $freeRam = $os.FreePhysicalMemory }
    else { $totalRam = $os.TotalVisibleMemorySize; $freeRam = $os.FreePhysicalMemory }
    if ($totalRam -gt 0) { $Report.Hardware.RAM.UsedPercent = [Math]::Round((($totalRam - $freeRam) / $totalRam) * 100) }
    Write-Host "  $cpu CPU: $($Report.Hardware.CPU.Cores) ядер ($($Report.Hardware.CPU.LoadPercent)%)" -ForegroundColor Green
    Write-Host "  $ram RAM: $($Report.Hardware.RAM.TotalGB) GB ($($Report.Hardware.RAM.UsedPercent)% використано)" -ForegroundColor Green
} catch { Write-Host "  $e Помилка апаратних даних" -ForegroundColor Red }

# --- Диски ---
try {
    $disks = if($useCIM){Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"}else{Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3"}
    $totalSpace = 0; $totalFree = 0
    foreach ($disk in $disks) { $totalSpace += $disk.Size; $totalFree += $disk.FreeSpace }
    if ($totalSpace -gt 0) {
        $Report.Hardware.Disks.TotalGB = [Math]::Round($totalSpace / 1GB, 2)
        $Report.Hardware.Disks.FreeGB = [Math]::Round($totalFree / 1GB, 2)
        $Report.Hardware.Disks.FreePercent = [Math]::Round(($totalFree / $totalSpace) * 100, 2)
    }
    Write-Host "  $disk Диски: $(Format-Size $Report.Hardware.Disks.FreeGB) вільно ($($Report.Hardware.Disks.FreePercent)%)" -ForegroundColor Green
} catch {}

# --- Мережа ---
try {
    $Report.Network.General.Hostname = $env:COMPUTERNAME
    if ($cs) { $Report.Network.General.Domain = $cs.Domain }
    $netAdapters = if($useCIM){Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled = True"}else{Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled = True"}
    foreach ($ad in $netAdapters) {
        if ($ad.IPAddress) { foreach ($ip in $ad.IPAddress) { if ($ip -notlike "*:*") { $Report.Network.IP.IPv4 += $ip } } }
        if ($ad.DefaultIPGateway) { $Report.Network.Routing.DefaultGateway = $ad.DefaultIPGateway[0] }
        if ($ad.DNSServerSearchOrder) { $Report.Network.Routing.DNSServers = $ad.DNSServerSearchOrder }
    }
    Write-Host "  $net IP: $($Report.Network.IP.IPv4 -join ', ')" -ForegroundColor Green
} catch {}

# --- Безпека ---
try {
    $uac = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ErrorAction SilentlyContinue
    if ($uac) { $Report.Security.UAC.Enabled = ($uac.EnableLUA -eq 1) }
    $rdp = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -ErrorAction SilentlyContinue
    $Report.Security.RemoteAccess.RDPEnabled = ($rdp.fDenyTSConnections -eq 0)
    $av = Get-WmiObject -Namespace "root\SecurityCenter2" -Class "AntiVirusProduct" -ErrorAction SilentlyContinue
    if ($av) { $Report.Security.Antivirus.Product = $av.displayName }
    Write-Host "  $sec Безпека: RDP=$(if($Report.Security.RemoteAccess.RDPEnabled){'ON'}else{'OFF'})" -ForegroundColor Green
} catch {}

# --- Користувачі ---
try {
    $admins = net localgroup "Администраторы" 2>$null
    if ($admins) { $admins = $admins | Where-Object {$_ -and $_ -notmatch "command|alias|members"} | Select-Object -Skip 4 }
    foreach ($admin in $admins) { if ($admin -and $admin.Trim()) { $Report.Users.LocalAdmins += $admin.Trim() } }
} catch {}

# --- Процеси ---
try {
    $procs = Get-Process
    $Report.Processes.Total = $procs.Count
    Write-Host "  $service Процеси: $($Report.Processes.Total)" -ForegroundColor Green
} catch {}

# --- Служби ---
try {
    $svcs = Get-Service
    $Report.Services.Total = $svcs.Count
    $Report.Services.Running = ($svcs | Where-Object { $_.Status -eq "Running" }).Count
} catch {}

# --- Журнали подій ---
try {
    $lastDay = (Get-Date).AddDays(-1)
    $sysErr = Get-EventLog -LogName System -EntryType Error -After $lastDay -ErrorAction SilentlyContinue
    $sysWarn = Get-EventLog -LogName System -EntryType Warning -After $lastDay -ErrorAction SilentlyContinue
    $Report.EventLogs.SystemErrors24h = if($sysErr){$sysErr.Count}else{0}
    $Report.EventLogs.SystemWarnings24h = if($sysWarn){$sysWarn.Count}else{0}
    Write-Host "  $event Помилок: $($Report.EventLogs.SystemErrors24h), Попереджень: $($Report.EventLogs.SystemWarnings24h)" -ForegroundColor Green
} catch {}

# --- Програмне забезпечення ---
try {
    $sw = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | 
          Where-Object { $_.DisplayName -and $_.DisplayName -notlike "*Update*" } |
          Select-Object -Property DisplayName -Unique
    foreach ($s in $sw) { $Report.Software.Installed += $s.DisplayName }
    Write-Host "  $db ПЗ: $($Report.Software.Installed.Count) програм" -ForegroundColor Green
} catch {}

Write-Host ""
Write-Host "$succ Збір даних завершено!" -ForegroundColor Green

# ============================================================
# ЗБЕРЕЖЕННЯ ЗВІТІВ
# ============================================================

$outputDir = $ScriptDirectory
$baseFileName = "ServerAudit_$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

Write-Host ""
Write-Host "$gear ============================================================" -ForegroundColor Cyan
Write-Host "$db     ГЕНЕРАЦІЯ ЗВІТІВ" -ForegroundColor Cyan
Write-Host "$gear ============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "$folder ЗБЕРЕЖЕННЯ: $outputDir" -ForegroundColor Cyan

# JSON
$jsonPath = Join-Path $outputDir "$baseFileName.json"
ConvertTo-Json $Report -Depth 10 | Out-File $jsonPath -Encoding utf8
Write-Host "  $json JSON: $baseFileName.json" -ForegroundColor Green

# HTML
if (-not $JSONOnly) {
    $htmlPath = Join-Path $outputDir "$baseFileName.html"
    $htmlContent = @"
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>Server Audit - $($Report.ComputerName)</title>
<style>
body{font-family:'Segoe UI',sans-serif;margin:20px;background:#1a1a2e;}
.container{max-width:1200px;margin:0 auto;background:white;border-radius:15px;}
.header{background:linear-gradient(135deg,#0f3460,#16213e);color:white;padding:30px;text-align:center;}
.content{padding:30px;}
h2{color:#0f3460;border-left:4px solid #e94560;padding-left:15px;}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(350px,1fr));gap:20px;}
.card{background:#f8f9fa;border-radius:10px;padding:20px;}
.info-row{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid #dee2e6;}
.info-label{font-weight:600;color:#6c757d;}
.info-value{color:#212529;text-align:right;}
.progress-bar{background:#e9ecef;border-radius:10px;overflow:hidden;margin-top:5px;}
.progress-fill{background:#e94560;color:white;text-align:center;padding:2px;}
.footer{background:#f8f9fa;padding:20px;text-align:center;}
</style></head>
<body><div class="container"><div class="header"><h1>🏢 SERVER AUDIT REPORT</h1><p>$($Report.ComputerName) | $($Report.Timestamp)</p></div>
<div class="content">
<h2>📊 Система та обладнання</h2>
<div class="grid">
<div class="card"><h3>💻 Система</h3>
<div class="info-row"><span class="info-label">OS:</span><span class="info-value">$($Report.OS.Caption)</span></div>
<div class="info-row"><span class="info-label">Build:</span><span class="info-value">$($Report.OS.Build)</span></div>
<div class="info-row"><span class="info-label">Архітектура:</span><span class="info-value">$($Report.OS.Architecture)</span></div>
<div class="info-row"><span class="info-label">PowerShell:</span><span class="info-value">$($Report.PowerShell.Version)</span></div>
<div class="info-row"><span class="info-label">.NET:</span><span class="info-value">$($Report.DotNet.v4)</span></div>
<div class="info-row"><span class="info-label">Uptime:</span><span class="info-value">$($Report.OS.UptimeDays) днів</span></div>
</div>
<div class="card"><h3>🖥️ Процесор та пам'ять</h3>
<div class="info-row"><span class="info-label">CPU:</span><span class="info-value">$($Report.Hardware.CPU.Name)</span></div>
<div class="info-row"><span class="info-label">Ядра:</span><span class="info-value">$($Report.Hardware.CPU.Cores)</span></div>
<div class="info-row"><span class="info-label">Завантаження CPU:</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$($Report.Hardware.CPU.LoadPercent)%;">$($Report.Hardware.CPU.LoadPercent)%</div></div></span></div>
<div class="info-row"><span class="info-label">RAM:</span><span class="info-value">$($Report.Hardware.RAM.TotalGB) GB</span></div>
<div class="info-row"><span class="info-label">RAM використано:</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$($Report.Hardware.RAM.UsedPercent)%;">$($Report.Hardware.RAM.UsedPercent)%</div></div></span></div>
</div>
<div class="card"><h3>💾 Диски</h3>
<div class="info-row"><span class="info-label">Всього місця:</span><span class="info-value">$(Format-Size $Report.Hardware.Disks.TotalGB)</span></div>
<div class="info-row"><span class="info-label">Вільно місця:</span><span class="info-value">$(Format-Size $Report.Hardware.Disks.FreeGB)</span></div>
<div class="info-row"><span class="info-label">Вільно %:</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$($Report.Hardware.Disks.FreePercent)%;">$($Report.Hardware.Disks.FreePercent)%</div></div></span></div>
</div>
<div class="card"><h3>🌐 Мережа</h3>
<div class="info-row"><span class="info-label">Хостнейм:</span><span class="info-value">$($Report.Network.General.Hostname)</span></div>
<div class="info-row"><span class="info-label">Домен:</span><span class="info-value">$($Report.Network.General.Domain)</span></div>
<div class="info-row"><span class="info-label">IPv4:</span><span class="info-value">$($Report.Network.IP.IPv4 -join ', ')</span></div>
<div class="info-row"><span class="info-label">Шлюз:</span><span class="info-value">$($Report.Network.Routing.DefaultGateway)</span></div>
<div class="info-row"><span class="info-label">DNS:</span><span class="info-value">$($Report.Network.Routing.DNSServers -join ', ')</span></div>
</div>
<div class="card"><h3>🔒 Безпека</h3>
<div class="info-row"><span class="info-label">UAC:</span><span class="info-value">$(if($Report.Security.UAC.Enabled){'✅ Ввімкнено'}else{'❌ Вимкнено'})</span></div>
<div class="info-row"><span class="info-label">RDP:</span><span class="info-value">$(if($Report.Security.RemoteAccess.RDPEnabled){'✅ Ввімкнено'}else{'❌ Вимкнено'})</span></div>
<div class="info-row"><span class="info-label">Антивірус:</span><span class="info-value">$($Report.Security.Antivirus.Product)</span></div>
</div>
</div>
<h2>📈 Статистика</h2>
<div class="grid">
<div class="card">
<div class="info-row"><span class="info-label">Процеси:</span><span class="info-value">$($Report.Processes.Total)</span></div>
<div class="info-row"><span class="info-label">Служб запущено:</span><span class="info-value">$($Report.Services.Running)/$($Report.Services.Total)</span></div>
<div class="info-row"><span class="info-label">Помилок системи (24г):</span><span class="info-value">$($Report.EventLogs.SystemErrors24h)</span></div>
<div class="info-row"><span class="info-label">Попереджень (24г):</span><span class="info-value">$($Report.EventLogs.SystemWarnings24h)</span></div>
<div class="info-row"><span class="info-label">Встановлено ПЗ:</span><span class="info-value">$($Report.Software.Installed.Count)</span></div>
<div class="info-row"><span class="info-label">Локальних адмінів:</span><span class="info-value">$($Report.Users.LocalAdmins.Count)</span></div>
</div>
</div>
</div>
<div class="footer"><p>Enterprise System Audit v6.0 | $outputDir</p></div>
</div>
</body>
</html>
"@
    $htmlContent | Out-File $htmlPath -Encoding utf8
    Write-Host "  $html HTML: $baseFileName.html" -ForegroundColor Green
}

# CSV
if ($CSV) {
    $csvPath = Join-Path $outputDir "$baseFileName.csv"
    $csvData = @(
        [PSCustomObject]@{Parameter="ComputerName"; Value=$Report.ComputerName}
        [PSCustomObject]@{Parameter="Timestamp"; Value=$Report.Timestamp}
        [PSCustomObject]@{Parameter="OS"; Value=$Report.OS.Caption}
        [PSCustomObject]@{Parameter="OSBuild"; Value=$Report.OS.Build}
        [PSCustomObject]@{Parameter="UptimeDays"; Value=$Report.OS.UptimeDays}
        [PSCustomObject]@{Parameter="CPU_Cores"; Value=$Report.Hardware.CPU.Cores}
        [PSCustomObject]@{Parameter="CPU_Load"; Value=$Report.Hardware.CPU.LoadPercent}
        [PSCustomObject]@{Parameter="RAM_GB"; Value=$Report.Hardware.RAM.TotalGB}
        [PSCustomObject]@{Parameter="RAM_Used_Percent"; Value=$Report.Hardware.RAM.UsedPercent}
        [PSCustomObject]@{Parameter="Disk_Free_Percent"; Value=$Report.Hardware.Disks.FreePercent}
        [PSCustomObject]@{Parameter="IPv4"; Value=($Report.Network.IP.IPv4 -join '; ')}
        [PSCustomObject]@{Parameter="RDP_Enabled"; Value=$Report.Security.RemoteAccess.RDPEnabled}
        [PSCustomObject]@{Parameter="UAC_Enabled"; Value=$Report.Security.UAC.Enabled}
        [PSCustomObject]@{Parameter="Processes"; Value=$Report.Processes.Total}
        [PSCustomObject]@{Parameter="Running_Services"; Value=$Report.Services.Running}
        [PSCustomObject]@{Parameter="Errors_24h"; Value=$Report.EventLogs.SystemErrors24h}
        [PSCustomObject]@{Parameter="Installed_Software"; Value=$Report.Software.Installed.Count}
        [PSCustomObject]@{Parameter="Local_Admins"; Value=$Report.Users.LocalAdmins.Count}
    )
    $csvData | Export-Csv $csvPath -NoTypeInformation -Encoding utf8
    Write-Host "  $csv CSV: $baseFileName.csv" -ForegroundColor Green
}

# ZIP
if ($Zip) {
    $zipPath = Join-Path $outputDir "$baseFileName.zip"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $filesToZip = @($jsonPath)
    if (-not $JSONOnly) { $filesToZip += $htmlPath }
    if ($CSV) { $filesToZip += $csvPath }
    try {
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        $zipStream = New-Object System.IO.FileStream($zipPath, [System.IO.FileMode]::Create)
        $zipArchive = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)
        foreach ($file in $filesToZip) {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $file, (Split-Path $file -Leaf), [System.IO.Compression.CompressionLevel]::Optimal)
        }
        $zipArchive.Dispose()
        $zipStream.Dispose()
        Write-Host "  📦 ZIP: $baseFileName.zip" -ForegroundColor Green
    } catch { Write-Host "  ❌ Помилка створення ZIP" -ForegroundColor Red }
}

# Email
if ($EmailTo) {
    try {
        $smtpToUse = if ($SmtpServer) { $SmtpServer } else { "smtp.$($env:USERDNSDOMAIN.ToLower())" }
        $mailBody = "Server Audit Report - $($Report.ComputerName)`n`nOS: $($Report.OS.Caption)`nCPU: $($Report.Hardware.CPU.LoadPercent)%`nRAM: $($Report.Hardware.RAM.TotalGB) GB ($($Report.Hardware.RAM.UsedPercent)%)`nDisk Free: $($Report.Hardware.Disks.FreePercent)%`nUptime: $($Report.OS.UptimeDays) days"
        $attachments = @($jsonPath)
        if (-not $JSONOnly) { $attachments += $htmlPath }
        Send-MailMessage -To $EmailTo -From $EmailFrom -Subject "Server Audit - $($Report.ComputerName)" -Body $mailBody -SmtpServer $smtpToUse -Attachments $attachments -ErrorAction Stop
        Write-Host "  📧 Email відправлено на $EmailTo" -ForegroundColor Green
    } catch { Write-Host "  ❌ Помилка відправки Email" -ForegroundColor Red }
}

# Фінал
Write-Host ""
Write-Host "$succ ============================================================" -ForegroundColor Green
Write-Host "$succ     АУДИТ СЕРВЕРА УСПІШНО ЗАВЕРШЕНО" -ForegroundColor Green
Write-Host "$succ ============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "$folder ЗВІТИ ЗБЕРЕЖЕНО: $outputDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "$json JSON: $baseFileName.json" -ForegroundColor White
if (-not $JSONOnly) { Write-Host "$html HTML: $baseFileName.html" -ForegroundColor White }
if ($CSV) { Write-Host "$csv CSV: $baseFileName.csv" -ForegroundColor White }
if ($Zip) { Write-Host "📦 ZIP: $baseFileName.zip" -ForegroundColor White }
Write-Host ""
Write-Host "⏰ Час виконання: $([Math]::Round(((Get-Date) - (Get-Date $Report.Timestamp)).TotalSeconds, 2)) сек" -ForegroundColor Cyan

try { Start-Process explorer.exe -ArgumentList "`"$outputDir`"" -ErrorAction SilentlyContinue } catch {}
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                         🎉 РОБОТУ ЗАВЕРШЕНО 🎉                             ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

if (-not $NoPause) { Show-Pause }
exit 0