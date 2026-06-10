# MODULE: 51-Export-Html.ps1
# Експорт BRAVO SYSTEM REPORT у HTML.

function Export-BravoHtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputDir,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseFileName,

        [Parameter(Mandatory = $true)]
        [bool]$JSONOnly,

        [Parameter(Mandatory = $true)]
        [int]$EventLogDays,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Profile,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptVersion
    )
# HTML
if (-not $JSONOnly) {
    try {
        $htmlPath = Join-Path $outputDir "$baseFileName.html"
        $findingsRows = if ($script:Report.Health.Findings.Count -gt 0) {
            ($script:Report.Health.Findings | ForEach-Object {
                "<tr><td>$($_.Severity)</td><td>$($_.Category)</td><td>$($_.Message)</td><td>$($_.Recommendation)</td></tr>"
            }) -join "`n"
        } else {
            '<tr><td colspan="4">Критичних зауважень не знайдено.</td></tr>'
        }

        $errorsRows = if ($script:Report.CollectionErrors.Count -gt 0) {
            ($script:Report.CollectionErrors | ForEach-Object {
                "<tr><td>$($_.Time)</td><td>$($_.Section)</td><td>$($_.Message)</td></tr>"
            }) -join "`n"
        } else {
            '<tr><td colspan="3">Помилок збору даних не зафіксовано.</td></tr>'
        }

        function ConvertTo-BravoHtmlText {
            param(
                [AllowNull()]
                [object]$Value
            )

            if ($null -eq $Value) {
                return ''
            }

            return [System.Net.WebUtility]::HtmlEncode([string]$Value)
        }

        function Get-BravoStorageRiskClass {
            param(
                [AllowNull()]
                [object]$Risk
            )

            switch (([string]$Risk).ToUpperInvariant()) {
                'CRITICAL' { return 'risk-critical' }
                'WARNING'  { return 'risk-warning' }
                'OK'       { return 'risk-ok' }
                default    { return 'risk-unknown' }
            }
        }

        function Get-BravoStorageDisplayText {
            param(
                [AllowNull()]
                [object]$Volume
            )

            if ($null -eq $Volume) {
                return ''
            }

            if ($Volume.DriveLetter) {
                return ("{0}:" -f ([string]$Volume.DriveLetter).TrimEnd(':'))
            }

            if ($Volume.Drive) {
                return [string]$Volume.Drive
            }

            if ($Volume.DeviceID) {
                return [string]$Volume.DeviceID
            }

            if ($Volume.VolumeKey) {
                return [string]$Volume.VolumeKey
            }

            return 'Volume без літери'
        }

        function Get-BravoStoragePropertyText {
            param(
                [AllowNull()]
                [object]$Value
            )

            if ($null -eq $Value -or [string]$Value -eq '') {
                return '—'
            }

            return [string]$Value
        }

        $disksContainer = $script:Report.Hardware.Disks

        if ($disksContainer -is [System.Collections.IDictionary]) {
            $storageDeep = $disksContainer['Deep']
            $storageRisk = $disksContainer['StorageRisk']
        } else {
            $storageDeep = $disksContainer.Deep
            $storageRisk = $disksContainer.StorageRisk
        }

        $criticalThreshold = if ($storageRisk -and $storageRisk.CriticalFreePercent) { [double]$storageRisk.CriticalFreePercent } else { 5 }
        $warningThreshold = if ($storageRisk -and $storageRisk.WarningFreePercent) { [double]$storageRisk.WarningFreePercent } else { 10 }

        $criticalCount = if ($storageRisk -and $storageRisk.Summary) { [int]$storageRisk.Summary.CriticalCount } else { 0 }
        $warningCount = if ($storageRisk -and $storageRisk.Summary) { [int]$storageRisk.Summary.WarningCount } else { 0 }
        $systemWarningCount = if ($storageRisk -and $storageRisk.Summary) { [int]$storageRisk.Summary.SystemWarningCount } else { 0 }
        $healthyCount = if ($storageRisk -and $storageRisk.Summary) { [int]$storageRisk.Summary.HealthyCount } else { 0 }

        $storageFindingItems = @()

        foreach ($item in @($storageRisk.CriticalVolumes)) {
            if ($item) {
                $storageFindingItems += [PSCustomObject]@{ Group = 'CRITICAL'; Volume = $item }
            }
        }

        foreach ($item in @($storageRisk.WarningVolumes)) {
            if ($item) {
                $storageFindingItems += [PSCustomObject]@{ Group = 'WARNING'; Volume = $item }
            }
        }

        foreach ($item in @($storageRisk.SystemVolumeWarnings)) {
            if ($item) {
                $storageFindingItems += [PSCustomObject]@{ Group = 'WARNING'; Volume = $item }
            }
        }

        $storageCriticalRows = if (@($storageFindingItems).Count -gt 0) {
            ($storageFindingItems | ForEach-Object {
                $volume = $_.Volume
                $riskText = if ($volume.Risk) { [string]$volume.Risk } else { [string]$_.Group }
                $riskClass = Get-BravoStorageRiskClass $riskText
                $reason = if ($volume.Reason) { $volume.Reason } elseif ($volume.Message) { $volume.Message } else { 'Потребує перевірки storage thresholds.' }

                "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStorageDisplayText $volume))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.Label))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FileSystem))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.SizeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreePercent))%</td><td><span class=""risk $riskClass"">$(ConvertTo-BravoHtmlText $riskText)</span></td><td>$(ConvertTo-BravoHtmlText $reason)</td></tr>"
            }) -join "`n"
        } else {
            '<tr><td colspan="8" class="muted">Критичних або попереджувальних storage-знахідок немає.</td></tr>'
        }

        $storageVolumes = @($storageDeep.Volumes)

        $storageDeepRows = if ($storageVolumes.Count -gt 0) {
            ($storageVolumes | ForEach-Object {
                $volume = $_
                $freePercent = $null

                if ($null -ne $volume.FreePercent -and [string]$volume.FreePercent -ne '') {
                    $freePercent = [double]$volume.FreePercent
                }

                $riskText = if ($null -eq $freePercent) {
                    'UNKNOWN'
                } elseif ($freePercent -lt $criticalThreshold) {
                    'CRITICAL'
                } elseif ($freePercent -lt $warningThreshold) {
                    'WARNING'
                } else {
                    'OK'
                }

                $riskClass = Get-BravoStorageRiskClass $riskText

                $reason = if ($riskText -eq 'CRITICAL') {
                    "Вільного місця менше $criticalThreshold%."
                } elseif ($riskText -eq 'WARNING') {
                    "Вільного місця менше $warningThreshold%."
                } elseif ($riskText -eq 'UNKNOWN') {
                    'Не вдалося визначити free percent.'
                } else {
                    'Показники в межах порогів.'
                }

                "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStorageDisplayText $volume))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FileSystemLabel))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FileSystem))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.DriveType))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.HealthStatus))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.OperationalStatus))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.SizeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreePercent))%</td><td><span class=""risk $riskClass"">$(ConvertTo-BravoHtmlText $riskText)</span></td><td>$(ConvertTo-BravoHtmlText $reason)</td></tr>"
            }) -join "`n"
        } else {
            '<tr><td colspan="11" class="muted">Storage Deep дані відсутні для поточного профілю або збір завершився з помилкою.</td></tr>'
        }

        $storageHtmlSection = @"
<div class="section storage-critical-section">
  <h2>💽 Storage Critical Findings</h2>
  <div class="storage-summary-grid">
    <div class="storage-summary-item"><div class="storage-summary-label">Critical volumes</div><div class="storage-summary-value"><span class="risk risk-critical">$criticalCount</span></div></div>
    <div class="storage-summary-item"><div class="storage-summary-label">Warning volumes</div><div class="storage-summary-value"><span class="risk risk-warning">$warningCount</span></div></div>
    <div class="storage-summary-item"><div class="storage-summary-label">System warnings</div><div class="storage-summary-value"><span class="risk risk-warning">$systemWarningCount</span></div></div>
    <div class="storage-summary-item"><div class="storage-summary-label">Healthy volumes</div><div class="storage-summary-value"><span class="risk risk-ok">$healthyCount</span></div></div>
  </div>

  <table class="storage-table">
    <thead>
      <tr>
        <th>Том</th>
        <th>Мітка</th>
        <th>FS</th>
        <th>Size GB</th>
        <th>Free GB</th>
        <th>Free %</th>
        <th>Risk</th>
        <th>Причина</th>
      </tr>
    </thead>
    <tbody>
      $storageCriticalRows
    </tbody>
  </table>
</div>

<div class="section storage-deep-section">
  <h2>🧱 Storage Deep</h2>
  <table class="storage-table">
    <thead>
      <tr>
        <th>Том</th>
        <th>Мітка</th>
        <th>FS</th>
        <th>Тип</th>
        <th>Health</th>
        <th>Operational</th>
        <th>Size GB</th>
        <th>Free GB</th>
        <th>Free %</th>
        <th>Risk</th>
        <th>Причина</th>
      </tr>
    </thead>
    <tbody>
      $storageDeepRows
    </tbody>
  </table>
</div>
"@
        $htmlContent = @"
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>BRAVO SYSTEM REPORT - $($script:Report.ComputerName)</title>
<style>
:root{
  --bg:#0b1020;
  --panel:#ffffff;
  --panel-soft:#f8fafc;
  --text:#0f172a;
  --muted:#64748b;
  --line:#e2e8f0;
  --primary:#2563eb;
  --primary-dark:#1e40af;
  --accent:#06b6d4;
  --success:#16a34a;
  --warning:#d97706;
  --critical:#dc2626;
  --shadow:0 22px 60px rgba(15,23,42,.24);
}
*{box-sizing:border-box}
body{
  margin:0;
  font-family:'Segoe UI',Roboto,Arial,sans-serif;
  background:
    radial-gradient(circle at 15% 8%,rgba(37,99,235,.34),transparent 28%),
    radial-gradient(circle at 92% 18%,rgba(6,182,212,.28),transparent 30%),
    linear-gradient(135deg,#0b1020,#111827 48%,#020617);
  color:var(--text);
}
.container{
  max-width:1360px;
  margin:28px auto;
  background:var(--panel);
  border-radius:24px;
  overflow:hidden;
  box-shadow:var(--shadow);
}
.header{
  position:relative;
  padding:34px 38px;
  color:white;
  background:
    linear-gradient(135deg,rgba(37,99,235,.96),rgba(14,165,233,.86)),
    linear-gradient(135deg,#0f172a,#1e293b);
}
.header:after{
  content:'';
  position:absolute;
  right:-70px;
  bottom:-120px;
  width:280px;
  height:280px;
  border-radius:999px;
  background:rgba(255,255,255,.13);
}
.brand{
  display:flex;
  align-items:center;
  gap:18px;
  position:relative;
  z-index:1;
}
.brand-icon{
  width:68px;
  height:68px;
  display:flex;
  align-items:center;
  justify-content:center;
  border-radius:20px;
  background:rgba(255,255,255,.18);
  border:1px solid rgba(255,255,255,.28);
  font-size:36px;
}
.header h1{
  margin:0;
  font-size:34px;
  letter-spacing:.4px;
}
.header p{
  margin:8px 0 0 0;
  opacity:.92;
}
.badge{
  display:inline-flex;
  align-items:center;
  gap:8px;
  border-radius:999px;
  padding:8px 14px;
  background:rgba(255,255,255,.16);
  border:1px solid rgba(255,255,255,.28);
  color:white;
  font-weight:800;
}
.content{padding:30px}
.summary-grid{
  display:grid;
  grid-template-columns:repeat(auto-fit,minmax(190px,1fr));
  gap:16px;
  margin-bottom:28px;
}
.summary-card{
  background:linear-gradient(180deg,#ffffff,#f8fafc);
  border:1px solid var(--line);
  border-radius:18px;
  padding:18px;
  box-shadow:0 8px 24px rgba(15,23,42,.07);
}
.summary-icon{
  font-size:28px;
  margin-bottom:8px;
}
.summary-label{
  color:var(--muted);
  font-size:13px;
  font-weight:800;
  text-transform:uppercase;
  letter-spacing:.06em;
}
.summary-value{
  margin-top:6px;
  font-size:22px;
  font-weight:900;
  color:var(--text);
  line-height:1.15;
}
h2{
  display:flex;
  align-items:center;
  gap:10px;
  margin:30px 0 16px 0;
  color:#0f172a;
  font-size:22px;
}
h2:after{
  content:'';
  flex:1;
  height:1px;
  background:var(--line);
}
.section-icon{
  width:38px;
  height:38px;
  display:inline-flex;
  align-items:center;
  justify-content:center;
  border-radius:12px;
  background:#eff6ff;
  color:var(--primary);
}
.grid{
  display:grid;
  grid-template-columns:repeat(auto-fit,minmax(340px,1fr));
  gap:18px;
}
.card{
  background:var(--panel-soft);
  border:1px solid var(--line);
  border-radius:18px;
  padding:20px;
  box-shadow:0 8px 24px rgba(15,23,42,.06);
}
.card h3{
  display:flex;
  align-items:center;
  gap:8px;
  margin:0 0 14px 0;
  font-size:18px;
  color:#0f172a;
}
.info-row{
  display:flex;
  justify-content:space-between;
  gap:16px;
  padding:10px 0;
  border-bottom:1px solid var(--line);
}
.info-row:last-child{border-bottom:none}
.info-label{
  font-weight:800;
  color:var(--muted);
}
.info-value{
  color:var(--text);
  text-align:right;
  word-break:break-word;
  font-weight:650;
}
.progress-bar{
  background:#e2e8f0;
  border-radius:999px;
  overflow:hidden;
  min-width:170px;
  height:24px;
}
.progress-fill{
  height:24px;
  line-height:24px;
  background:linear-gradient(90deg,var(--primary),var(--accent));
  color:white;
  text-align:center;
  font-size:12px;
  font-weight:900;
}
table{
  width:100%;
  border-collapse:separate;
  border-spacing:0;
  margin-top:12px;
  overflow:hidden;
  border:1px solid var(--line);
  border-radius:14px;
}
th,td{
  padding:11px 12px;
  text-align:left;
  border-bottom:1px solid var(--line);
}
th{
  background:#eff6ff;
  color:#1e3a8a;
  font-size:13px;
  text-transform:uppercase;
  letter-spacing:.04em;
}
tr:last-child td{border-bottom:none}
.footer{
  background:#f8fafc;
  border-top:1px solid var(--line);
  padding:18px 24px;
  text-align:center;
  color:var(--muted);
  font-size:13px;
}
@media print{
  body{background:white}
  .container{box-shadow:none;margin:0;border-radius:0}
  .header{background:#1e40af !important}
}

  .storage-summary-grid{
    display:grid;
    grid-template-columns:repeat(auto-fit,minmax(160px,1fr));
    gap:12px;
    margin:12px 0 16px 0;
  }
  .storage-summary-item{
    background:#f8fafc;
    border:1px solid var(--border,#e5e7eb);
    border-radius:10px;
    padding:10px 12px;
  }
  .storage-summary-label{
    color:#64748b;
    font-size:12px;
    margin-bottom:4px;
  }
  .storage-summary-value{
    font-size:20px;
    font-weight:700;
  }
  .storage-table{
    width:100%;
    border-collapse:collapse;
    margin-top:12px;
    font-size:13px;
  }
  .storage-table th,
  .storage-table td{
    text-align:left;
    padding:8px 10px;
    border-bottom:1px solid var(--border,#e5e7eb);
    vertical-align:top;
  }
  .storage-table th{
    background:#f1f5f9;
    color:#334155;
    font-weight:700;
  }
  .risk{
    font-weight:700;
    white-space:nowrap;
  }
  .risk-critical{color:var(--critical,#dc2626);}
  .risk-warning{color:var(--warning,#f59e0b);}
  .risk-ok{color:var(--success,#16a34a);}
  .risk-unknown{color:#64748b;}
  .muted{color:#64748b;}
</style></head>
<body><div class="container"><div class="header">
<div class="brand">
  <div class="brand-icon">📊</div>
  <div>
    <h1>BRAVO SYSTEM REPORT</h1>
    <p>$($script:Report.ComputerName) | $($script:Report.Timestamp) | Profile: $Profile</p>
    <p><span class="badge">🎯 Health Score: $($script:Report.Health.Score)/100 — $($script:Report.Health.Status)</span></p>
  </div>
</div>
</div>
<div class="content">
<div class="summary-grid">
  <div class="summary-card"><div class="summary-icon">🖥️</div><div class="summary-label">ОС</div><div class="summary-value">$($script:Report.OS.Caption)</div></div>
  <div class="summary-card"><div class="summary-icon">🧠</div><div class="summary-label">CPU</div><div class="summary-value">$($script:Report.Hardware.CPU.Cores)/$($script:Report.Hardware.CPU.LogicalProcessors)</div></div>
  <div class="summary-card"><div class="summary-icon">💾</div><div class="summary-label">RAM</div><div class="summary-value">$($script:Report.Hardware.RAM.TotalGB) GB</div></div>
  <div class="summary-card"><div class="summary-icon">💿</div><div class="summary-label">Диски</div><div class="summary-value">$($script:Report.Hardware.Disks.FreePercent)% free</div></div>
  <div class="summary-card"><div class="summary-icon">🔒</div><div class="summary-label">Security</div><div class="summary-value">$($script:Report.Health.Status)</div></div>
</div>
<h2><span class="section-icon">🖥️</span>Система та обладнання</h2>
<div class="grid">
<div class="card"><h3>🖥️ Система</h3>
<div class="info-row"><span class="info-label">OS:</span><span class="info-value">$($script:Report.OS.Caption)</span></div>
<div class="info-row"><span class="info-label">Build:</span><span class="info-value">$($script:Report.OS.Build)</span></div>
<div class="info-row"><span class="info-label">Архітектура:</span><span class="info-value">$($script:Report.OS.Architecture)</span></div>
<div class="info-row"><span class="info-label">PowerShell:</span><span class="info-value">$($script:Report.PowerShell.Version)</span></div>
<div class="info-row"><span class="info-label">.NET:</span><span class="info-value">$($script:Report.DotNet.v4)</span></div>
<div class="info-row"><span class="info-label">Uptime:</span><span class="info-value">$($script:Report.OS.UptimeDays) днів</span></div>
</div>
<div class="card"><h3>🧠 Процесор та пам'ять</h3>
<div class="info-row"><span class="info-label">CPU:</span><span class="info-value">$($script:Report.Hardware.CPU.Name)</span></div>
<div class="info-row"><span class="info-label">Ядра/потоки:</span><span class="info-value">$($script:Report.Hardware.CPU.Cores)/$($script:Report.Hardware.CPU.LogicalProcessors)</span></div>
<div class="info-row"><span class="info-label">Завантаження CPU:</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$($script:Report.Hardware.CPU.LoadPercent)%">$($script:Report.Hardware.CPU.LoadPercent)%</div></div></span></div>
<div class="info-row"><span class="info-label">RAM:</span><span class="info-value">$($script:Report.Hardware.RAM.TotalGB) GB</span></div>
<div class="info-row"><span class="info-label">RAM використано:</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$($script:Report.Hardware.RAM.UsedPercent)%">$($script:Report.Hardware.RAM.UsedPercent)%</div></div></span></div>
</div>
<div class="card"><h3>💿 Диски</h3>
<div class="info-row"><span class="info-label">Всього місця:</span><span class="info-value">$(Format-Size $script:Report.Hardware.Disks.TotalGB)</span></div>
<div class="info-row"><span class="info-label">Вільно місця:</span><span class="info-value">$(Format-Size $script:Report.Hardware.Disks.FreeGB)</span></div>
<div class="info-row"><span class="info-label">Вільно %:</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$($script:Report.Hardware.Disks.FreePercent)%">$($script:Report.Hardware.Disks.FreePercent)%</div></div></span></div>
$storageHtmlSection
</div>
<div class="card"><h3>🌐 Мережа</h3>
<div class="info-row"><span class="info-label">Хостнейм:</span><span class="info-value">$($script:Report.Network.General.Hostname)</span></div>
<div class="info-row"><span class="info-label">Домен:</span><span class="info-value">$($script:Report.Network.General.Domain)</span></div>
<div class="info-row"><span class="info-label">IPv4:</span><span class="info-value">$($script:Report.Network.IP.IPv4 -join ', ')</span></div>
<div class="info-row"><span class="info-label">Шлюз:</span><span class="info-value">$($script:Report.Network.Routing.DefaultGateway)</span></div>
<div class="info-row"><span class="info-label">DNS:</span><span class="info-value">$($script:Report.Network.Routing.DNSServers -join ', ')</span></div>
</div>
<div class="card"><h3>🔒 Безпека</h3>
<div class="info-row"><span class="info-label">UAC:</span><span class="info-value">$(if($script:Report.Security.UAC.Enabled){'Ввімкнено'}else{'Вимкнено'})</span></div>
<div class="info-row"><span class="info-label">RDP:</span><span class="info-value">$(if($script:Report.Security.RemoteAccess.RDPEnabled){'Ввімкнено'}else{'Вимкнено'})</span></div>
<div class="info-row"><span class="info-label">Антивірус:</span><span class="info-value">$($script:Report.Security.Antivirus.Product)</span></div>
</div>
</div>
<h2><span class="section-icon">📈</span>Статистика</h2>
<div class="grid"><div class="card">
<div class="info-row"><span class="info-label">Процеси:</span><span class="info-value">$($script:Report.Processes.Total)</span></div>
<div class="info-row"><span class="info-label">Служб запущено:</span><span class="info-value">$($script:Report.Services.Running)/$($script:Report.Services.Total)</span></div>
<div class="info-row"><span class="info-label">Автоматичних служб зупинено:</span><span class="info-value">$($script:Report.Services.AutomaticStopped.Count)</span></div>
<div class="info-row"><span class="info-label">Помилок System ($EventLogDays дн.):</span><span class="info-value">$($script:Report.EventLogs.SystemErrors)</span></div>
<div class="info-row"><span class="info-label">Попереджень System ($EventLogDays дн.):</span><span class="info-value">$($script:Report.EventLogs.SystemWarnings)</span></div>
<div class="info-row"><span class="info-label">Встановлено ПЗ:</span><span class="info-value">$($script:Report.Software.Installed.Count)</span></div>
<div class="info-row"><span class="info-label">Локальних адмінів:</span><span class="info-value">$($script:Report.Users.LocalAdmins.Count)</span></div>
</div></div>
<h2><span class="section-icon">🔎</span>Findings</h2><table><tr><th>Severity</th><th>Category</th><th>Message</th><th>Recommendation</th></tr>$findingsRows</table>
<h2><span class="section-icon">🛠️</span>Помилки збору даних</h2><table><tr><th>Time</th><th>Section</th><th>Message</th></tr>$errorsRows</table>
</div>
<div class="footer"><p>BRAVO SYSTEM REPORT v$ScriptVersion | $outputDir</p></div>
</div></body></html>
"@
        $htmlContent | Out-File $htmlPath -Encoding utf8
        $script:Report.GeneratedFiles += $htmlPath
        Write-Host "  $IconHtml HTML: $baseFileName.html" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Export.Html' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка HTML: $($_.Exception.Message)" -ForegroundColor Red
    }
}

}
