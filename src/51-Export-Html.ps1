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

    if (-not $JSONOnly) {
        try {
            $htmlPath = Join-Path $OutputDir "$BaseFileName.html"

            function ConvertTo-BravoHtmlText {
                param([AllowNull()][object]$Value)
                if ($null -eq $Value) { return '' }
                return [System.Net.WebUtility]::HtmlEncode([string]$Value)
            }

            function ConvertTo-BravoHtmlListText {
                param(
                    [AllowNull()][object]$Value,
                    [string]$Separator = ', '
                )
                if ($null -eq $Value) { return '' }
                return ConvertTo-BravoHtmlText ((@($Value) | Where-Object { $_ }) -join $Separator)
            }

            function Get-BravoStatusClass {
                param([AllowNull()][object]$Status)
                switch (([string]$Status).ToUpperInvariant()) {
                    'CRITICAL' { return 'status-critical' }
                    'WARNING'  { return 'status-warning' }
                    'OK'       { return 'status-ok' }
                    default    { return 'status-unknown' }
                }
            }

            function Get-BravoStorageRiskClass {
                param([AllowNull()][object]$Risk)
                switch (([string]$Risk).ToUpperInvariant()) {
                    'CRITICAL' { return 'risk-critical' }
                    'WARNING'  { return 'risk-warning' }
                    'OK'       { return 'risk-ok' }
                    default    { return 'risk-unknown' }
                }
            }

            function Get-BravoStorageDisplayText {
                param([AllowNull()][object]$Volume)
                if ($null -eq $Volume) { return '' }
                if ($Volume.DriveLetter) { return ("{0}:" -f ([string]$Volume.DriveLetter).TrimEnd(':')) }
                if ($Volume.Drive) { return [string]$Volume.Drive }
                if ($Volume.DeviceID) { return [string]$Volume.DeviceID }
                if ($Volume.VolumeKey) { return [string]$Volume.VolumeKey }
                return 'Volume без літери'
            }

            function Get-BravoStoragePropertyText {
                param([AllowNull()][object]$Value)
                if ($null -eq $Value -or [string]$Value -eq '') { return '—' }
                return [string]$Value
            }

            function New-BravoInfoRowHtml {
                param(
                    [string]$Label,
                    [AllowNull()][object]$Value
                )
                return "<div class=`"info-row`"><span class=`"info-label`">$(ConvertTo-BravoHtmlText $Label)</span><span class=`"info-value`">$(ConvertTo-BravoHtmlText $Value)</span></div>"
            }

            function New-BravoTableToolbarHtml {
                param(
                    [Parameter(Mandatory = $true)]
                    [ValidateNotNullOrEmpty()]
                    [string]$TableId,

                    [Parameter(Mandatory = $true)]
                    [ValidateNotNullOrEmpty()]
                    [string]$Placeholder
                )

                $safeTableId = ConvertTo-BravoHtmlText $TableId
                $safePlaceholder = ConvertTo-BravoHtmlText $Placeholder

                return @"
<div class="table-toolbar" data-table-toolbar="$safeTableId">
  <input class="table-search" type="search" placeholder="$safePlaceholder" data-table-filter="$safeTableId" autocomplete="off">
  <span class="table-counter" data-table-counter="$safeTableId">Рядків: —</span>
</div>
"@
            }

            function New-BravoMetricCardHtml {
                param(
                    [string]$Icon,
                    [string]$Title,
                    [AllowNull()][object]$Value,
                    [AllowNull()][object]$Details,
                    [AllowNull()][object]$Status
                )

                $statusText = if ($Status) { [string]$Status } else { 'OK' }
                $statusClass = Get-BravoStatusClass $statusText

                return @"
<div class="metric-card $statusClass">
  <div class="metric-topline">
    <div class="metric-icon">$Icon</div>
    <span class="status-pill $statusClass">$(ConvertTo-BravoHtmlText $statusText)</span>
  </div>
  <div class="metric-title">$(ConvertTo-BravoHtmlText $Title)</div>
  <div class="metric-value">$(ConvertTo-BravoHtmlText $Value)</div>
  <div class="metric-details">$(ConvertTo-BravoHtmlText $Details)</div>
</div>
"@
            }

            $dashboardMetrics = $script:Report.Dashboard.Metrics
            $cpuMetric = $dashboardMetrics.CPU
            $ramMetric = $dashboardMetrics.RAM
            $diskMetric = $dashboardMetrics.Disk
            $osMetric = $dashboardMetrics.OS

            $metricCardsHtml = @(
                New-BravoMetricCardHtml -Icon '🧠' -Title $cpuMetric.Title -Value $cpuMetric.Value -Details $cpuMetric.Details -Status $cpuMetric.Status
                New-BravoMetricCardHtml -Icon '💾' -Title $ramMetric.Title -Value $ramMetric.Value -Details $ramMetric.Details -Status $ramMetric.Status
                New-BravoMetricCardHtml -Icon '💿' -Title $diskMetric.Title -Value $diskMetric.Value -Details $diskMetric.Details -Status $diskMetric.Status
                New-BravoMetricCardHtml -Icon '🖥️' -Title $osMetric.Title -Value $osMetric.Value -Details $osMetric.Details -Status $osMetric.Status
            ) -join "`n"

            $findingsRows = if ($script:Report.Health.Findings.Count -gt 0) {
                ($script:Report.Health.Findings | ForEach-Object {
                    $severityClass = Get-BravoStatusClass $_.Severity
                    "<tr><td><span class=`"status-pill $severityClass`">$(ConvertTo-BravoHtmlText $_.Severity)</span></td><td>$(ConvertTo-BravoHtmlText $_.Category)</td><td>$(ConvertTo-BravoHtmlText $_.Message)</td><td>$(ConvertTo-BravoHtmlText $_.Recommendation)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Критичних зауважень не знайдено.</td></tr>'
            }

            $errorsRows = if ($script:Report.CollectionErrors.Count -gt 0) {
                ($script:Report.CollectionErrors | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Time)</td><td>$(ConvertTo-BravoHtmlText $_.Section)</td><td>$(ConvertTo-BravoHtmlText $_.Message)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="3" class="muted">Помилок збору даних не зафіксовано.</td></tr>'
            }

            $softwareRows = if ($script:Report.Software.Installed.Count -gt 0) {
                ($script:Report.Software.Installed | ForEach-Object {
                    if ($_ -is [string]) {
                        "<tr><td>$(ConvertTo-BravoHtmlText $_)</td><td>—</td><td>—</td><td>—</td></tr>"
                    } else {
                        "<tr><td>$(ConvertTo-BravoHtmlText $_.DisplayName)</td><td>$(ConvertTo-BravoHtmlText $_.DisplayVersion)</td><td>$(ConvertTo-BravoHtmlText $_.Publisher)</td><td>$(ConvertTo-BravoHtmlText $_.InstallDate)</td></tr>"
                    }
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Дані про встановлене ПЗ відсутні.</td></tr>'
            }

            $serviceRows = if ($script:Report.Services.AutomaticStopped.Count -gt 0) {
                ($script:Report.Services.AutomaticStopped | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Name)</td><td>$(ConvertTo-BravoHtmlText $_.DisplayName)</td><td>$(ConvertTo-BravoHtmlText $_.StartType)</td><td>$(ConvertTo-BravoHtmlText $_.Status)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Автоматичних служб у зупиненому стані не знайдено.</td></tr>'
            }

            $adapterRows = if ($script:Report.Network.Adapters.Count -gt 0) {
                ($script:Report.Network.Adapters | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Description)</td><td>$(ConvertTo-BravoHtmlText $_.MACAddress)</td><td>$(ConvertTo-BravoHtmlListText $_.IPv4)</td><td>$(ConvertTo-BravoHtmlListText $_.Gateway)</td><td>$(ConvertTo-BravoHtmlListText $_.DNS)</td><td>$(ConvertTo-BravoHtmlText $_.DHCPEnabled)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="6" class="muted">Мережеві адаптери не знайдені або збір недоступний.</td></tr>'
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
            foreach ($item in @($storageRisk.CriticalVolumes)) { if ($item) { $storageFindingItems += [PSCustomObject]@{ Group = 'CRITICAL'; Volume = $item } } }
            foreach ($item in @($storageRisk.WarningVolumes)) { if ($item) { $storageFindingItems += [PSCustomObject]@{ Group = 'WARNING'; Volume = $item } } }
            foreach ($item in @($storageRisk.SystemVolumeWarnings)) { if ($item) { $storageFindingItems += [PSCustomObject]@{ Group = 'WARNING'; Volume = $item } } }

            $storageCriticalRows = if (@($storageFindingItems).Count -gt 0) {
                ($storageFindingItems | ForEach-Object {
                    $volume = $_.Volume
                    $riskText = if ($volume.Risk) { [string]$volume.Risk } else { [string]$_.Group }
                    $riskClass = Get-BravoStorageRiskClass $riskText
                    $reason = if ($volume.Reason) { $volume.Reason } elseif ($volume.Message) { $volume.Message } else { 'Потребує перевірки storage thresholds.' }
                    "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStorageDisplayText $volume))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.Label))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FileSystem))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.SizeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreePercent))%</td><td><span class=`"risk $riskClass`">$(ConvertTo-BravoHtmlText $riskText)</span></td><td>$(ConvertTo-BravoHtmlText $reason)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="8" class="muted">Критичних або попереджувальних storage-знахідок немає.</td></tr>'
            }

            $storageVolumes = @($storageDeep.Volumes)
            $storageDeepRows = if ($storageVolumes.Count -gt 0) {
                ($storageVolumes | ForEach-Object {
                    $volume = $_
                    $freePercent = $null
                    if ($null -ne $volume.FreePercent -and [string]$volume.FreePercent -ne '') { $freePercent = [double]$volume.FreePercent }
                    $riskText = if ($null -eq $freePercent) { 'UNKNOWN' } elseif ($freePercent -lt $criticalThreshold) { 'CRITICAL' } elseif ($freePercent -lt $warningThreshold) { 'WARNING' } else { 'OK' }
                    $riskClass = Get-BravoStorageRiskClass $riskText
                    $reason = if ($riskText -eq 'CRITICAL') { "Вільного місця менше $criticalThreshold%." } elseif ($riskText -eq 'WARNING') { "Вільного місця менше $warningThreshold%." } elseif ($riskText -eq 'UNKNOWN') { 'Не вдалося визначити free percent.' } else { 'Показники в межах порогів.' }
                    "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStorageDisplayText $volume))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FileSystemLabel))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FileSystem))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.DriveType))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.HealthStatus))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.OperationalStatus))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.SizeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreePercent))%</td><td><span class=`"risk $riskClass`">$(ConvertTo-BravoHtmlText $riskText)</span></td><td>$(ConvertTo-BravoHtmlText $reason)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="11" class="muted">Storage Deep дані відсутні для поточного профілю або збір завершився з помилкою.</td></tr>'
            }

            $updatesPending = @($script:Report.WindowsUpdate.PendingUpdates)
            $updatesPendingRows = if ($updatesPending.Count -gt 0) {
                ($updatesPending | ForEach-Object {
                    $pendingUpdate = $_
                    $severityText = if ([string]::IsNullOrWhiteSpace([string]$pendingUpdate.Severity)) { 'Unspecified' } else { [string]$pendingUpdate.Severity }
                    $severityClass = switch ($severityText) {
                        'Critical'  { 'risk-critical' }
                        'Important' { 'risk-warning' }
                        'Moderate'  { 'risk-warning' }
                        'Low'       { 'risk-ok' }
                        default     { 'risk-unknown' }
                    }
                    "<tr><td>$(ConvertTo-BravoHtmlText $pendingUpdate.KB)</td><td>$(ConvertTo-BravoHtmlText $pendingUpdate.Title)</td><td><span class=`"risk $severityClass`">$(ConvertTo-BravoHtmlText $severityText)</span></td><td>$(ConvertTo-BravoHtmlText $pendingUpdate.Categories)</td><td>$(if($pendingUpdate.IsDownloaded){'Так'}else{'Ні'})</td><td>$(ConvertTo-BravoHtmlText $pendingUpdate.SizeMB)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="6" class="muted">Відсутні оновлення не виявлені, пошук пропущено або завершився з помилкою (див. Search status).</td></tr>'
            }

            $computerNameHtml = ConvertTo-BravoHtmlText $script:Report.ComputerName
            $timestampHtml = ConvertTo-BravoHtmlText $script:Report.Timestamp
            $profileHtml = ConvertTo-BravoHtmlText $Profile
            $statusHtml = ConvertTo-BravoHtmlText $script:Report.Status
            $statusReasonHtml = ConvertTo-BravoHtmlText $script:Report.StatusReason
            $statusClass = Get-BravoStatusClass $script:Report.Status
            $uptimeHtml = ConvertTo-BravoHtmlText $script:Report.Dashboard.Header.UptimeText
            $primaryIpv4Html = ConvertTo-BravoHtmlText $script:Report.Network.IP.PrimaryIPv4
            $publicIpv4StatusForReport = if (-not [string]::IsNullOrWhiteSpace([string]$script:Report.Network.IP.PublicIPv4)) {
                [string]$script:Report.Network.IP.PublicIPv4
            } elseif (-not [string]::IsNullOrWhiteSpace([string]$script:Report.Network.PublicIPv4)) {
                [string]$script:Report.Network.PublicIPv4
            } else {
                [string]$script:Report.Network.IP.PublicIPv4Status
            }
            $publicIpv4LocationPartsForReport = @(
                [string]$script:Report.Network.IP.PublicIPv4Country
                [string]$script:Report.Network.IP.PublicIPv4Region
                [string]$script:Report.Network.IP.PublicIPv4City
            ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

            $publicIpv4LocationForReport = if ($publicIpv4LocationPartsForReport.Count -gt 0) {
                $publicIpv4LocationPartsForReport -join ', '
            } else {
                ''
            }
            $htmlTitle = ConvertTo-BravoHtmlText "BRAVO SYSTEM REPORT - $($script:Report.ComputerName)"

            $htmlContent = @"
<!DOCTYPE html>
<html lang="uk">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$htmlTitle</title>
<style>
:root{--page-bg:#0b1020;--panel:#ffffff;--panel-soft:#f8fafc;--panel-muted:#eef2ff;--text:#0f172a;--muted:#64748b;--line:#e2e8f0;--primary:#2563eb;--primary-dark:#1e40af;--accent:#06b6d4;--success:#16a34a;--warning:#d97706;--critical:#dc2626;--unknown:#64748b;--shadow:0 22px 60px rgba(15,23,42,.24);--radius-lg:24px;--radius-md:18px;--radius-sm:12px}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;font-family:'Segoe UI',Roboto,Arial,sans-serif;background:radial-gradient(circle at 15% 8%,rgba(37,99,235,.34),transparent 28%),radial-gradient(circle at 92% 18%,rgba(6,182,212,.28),transparent 30%),linear-gradient(135deg,#0b1020,#111827 48%,#020617);color:var(--text)}
.report-shell{max-width:1440px;margin:28px auto;background:var(--panel);border-radius:var(--radius-lg);overflow:hidden;box-shadow:var(--shadow)}
.dashboard-header{position:relative;color:white;padding:32px 38px 24px 38px;background:linear-gradient(135deg,rgba(37,99,235,.98),rgba(14,165,233,.88)),linear-gradient(135deg,#0f172a,#1e293b)}
.dashboard-header:after{content:'';position:absolute;right:-70px;bottom:-120px;width:280px;height:280px;border-radius:999px;background:rgba(255,255,255,.13)}
.header-grid{position:relative;z-index:1;display:grid;grid-template-columns:minmax(0,1fr) auto;gap:22px;align-items:start}.brand{display:flex;gap:18px;align-items:center}.brand-icon{width:70px;height:70px;display:flex;align-items:center;justify-content:center;border-radius:22px;background:rgba(255,255,255,.18);border:1px solid rgba(255,255,255,.28);font-size:36px}
.dashboard-header h1{margin:0;font-size:34px;letter-spacing:.4px}.dashboard-header p{margin:8px 0 0 0;opacity:.92}.header-meta{display:grid;grid-template-columns:repeat(2,minmax(130px,auto));gap:10px;min-width:320px}.meta-tile{padding:10px 12px;border:1px solid rgba(255,255,255,.24);border-radius:14px;background:rgba(255,255,255,.13);backdrop-filter:blur(8px)}.meta-label{font-size:11px;text-transform:uppercase;letter-spacing:.06em;opacity:.75;font-weight:800}.meta-value{font-size:14px;font-weight:900;margin-top:4px;word-break:break-word}
.status-pill{display:inline-flex;align-items:center;justify-content:center;border-radius:999px;padding:6px 10px;font-size:12px;font-weight:900;letter-spacing:.03em;white-space:nowrap}.status-ok{background:rgba(22,163,74,.12);color:var(--success);border:1px solid rgba(22,163,74,.35)}.status-warning{background:rgba(217,119,6,.12);color:var(--warning);border:1px solid rgba(217,119,6,.35)}.status-critical{background:rgba(220,38,38,.12);color:var(--critical);border:1px solid rgba(220,38,38,.35)}.status-unknown{background:rgba(100,116,139,.12);color:var(--unknown);border:1px solid rgba(100,116,139,.35)}.dashboard-header .status-pill{background:rgba(255,255,255,.16);color:white;border-color:rgba(255,255,255,.3)}
.tab-nav{position:sticky;top:0;z-index:10;display:flex;flex-wrap:wrap;gap:8px;padding:14px 30px;background:rgba(248,250,252,.96);border-bottom:1px solid var(--line);backdrop-filter:blur(12px)}.tab-button{display:inline-flex;align-items:center;gap:8px;padding:10px 14px;border-radius:999px;border:1px solid var(--line);background:white;color:#1e293b;text-decoration:none;font-weight:900;font-size:13px;box-shadow:0 4px 14px rgba(15,23,42,.06);cursor:pointer}.tab-button.active,.tab-button:hover{background:#2563eb;color:white;border-color:#2563eb}
.content{padding:30px}.tab-panel{display:none;margin-bottom:30px;padding:24px;border:1px solid var(--line);border-radius:22px;background:linear-gradient(180deg,#ffffff,#fbfdff);box-shadow:0 10px 30px rgba(15,23,42,.06)}.tab-panel.active{display:block}.tab-panel-title{display:flex;align-items:center;gap:12px;margin:0 0 18px 0;color:#0f172a;font-size:22px}.tab-panel-title:after{content:'';flex:1;height:1px;background:var(--line)}.section-icon{width:38px;height:38px;display:inline-flex;align-items:center;justify-content:center;border-radius:12px;background:#eff6ff;color:var(--primary)}
.metrics-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:16px;margin-bottom:22px}.metric-card{position:relative;min-height:160px;padding:20px;border:1px solid var(--line);border-radius:20px;background:linear-gradient(180deg,#ffffff,#f8fafc);box-shadow:0 8px 24px rgba(15,23,42,.07);overflow:hidden}.metric-card:before{content:'';position:absolute;left:0;top:0;bottom:0;width:5px;background:var(--unknown)}.metric-card.status-ok:before{background:var(--success)}.metric-card.status-warning:before{background:var(--warning)}.metric-card.status-critical:before{background:var(--critical)}.metric-topline{display:flex;justify-content:space-between;gap:10px;align-items:center;margin-bottom:12px}.metric-icon{font-size:30px}.metric-title{color:var(--muted);font-size:13px;font-weight:900;text-transform:uppercase;letter-spacing:.06em}.metric-value{margin-top:8px;font-size:24px;font-weight:950;color:var(--text);line-height:1.15;word-break:break-word}.metric-details{margin-top:8px;color:var(--muted);font-size:13px;line-height:1.45}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:18px}.card{background:var(--panel-soft);border:1px solid var(--line);border-radius:18px;padding:20px;box-shadow:0 8px 24px rgba(15,23,42,.06)}.card h3{display:flex;align-items:center;gap:8px;margin:0 0 14px 0;font-size:18px;color:#0f172a}.info-row{display:flex;justify-content:space-between;gap:16px;padding:10px 0;border-bottom:1px solid var(--line)}.info-row:last-child{border-bottom:none}.info-label{font-weight:850;color:var(--muted)}.info-value{color:var(--text);text-align:right;word-break:break-word;font-weight:650}.progress-bar{background:#e2e8f0;border-radius:999px;overflow:hidden;min-width:170px;height:24px}.progress-fill{height:24px;line-height:24px;background:linear-gradient(90deg,var(--primary),var(--accent));color:white;text-align:center;font-size:12px;font-weight:900}
.table-toolbar{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:10px 0 10px 0;padding:10px 12px;border:1px solid var(--line);border-radius:14px;background:#f8fafc}.table-search{width:min(420px,100%);padding:10px 12px;border:1px solid #cbd5e1;border-radius:12px;background:white;color:var(--text);font-size:13px;font-weight:650;outline:none}.table-search:focus{border-color:var(--primary);box-shadow:0 0 0 3px rgba(37,99,235,.16)}.table-counter{color:var(--muted);font-size:12px;font-weight:900;white-space:nowrap}.row-hidden{display:none !important}
.table-scroll{max-height:430px;overflow:auto;border:1px solid var(--line);border-radius:14px;background:white}.data-table{width:100%;border-collapse:separate;border-spacing:0;font-size:13px}.data-table th,.data-table td{padding:11px 12px;text-align:left;border-bottom:1px solid var(--line);vertical-align:top}.data-table th{position:sticky;top:0;background:#eff6ff;color:#1e3a8a;font-size:12px;text-transform:uppercase;letter-spacing:.04em;z-index:1}.data-table tr:last-child td{border-bottom:none}.storage-summary-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin:12px 0 16px 0}.storage-summary-item{background:#f8fafc;border:1px solid var(--line);border-radius:12px;padding:12px}.storage-summary-label{color:#64748b;font-size:12px;margin-bottom:4px;font-weight:800;text-transform:uppercase;letter-spacing:.04em}.storage-summary-value{font-size:22px;font-weight:900}.risk{font-weight:900;white-space:nowrap}.risk-critical{color:var(--critical)}.risk-warning{color:var(--warning)}.risk-ok{color:var(--success)}.risk-unknown{color:#64748b}.muted{color:#64748b}.footer{background:#f8fafc;border-top:1px solid var(--line);padding:18px 24px;text-align:center;color:var(--muted);font-size:13px}
@media (max-width:820px){.report-shell{margin:0;border-radius:0}.dashboard-header{padding:24px}.header-grid{grid-template-columns:1fr}.header-meta{grid-template-columns:1fr;min-width:0}.content{padding:18px}.tab-panel{padding:16px}.info-row{display:block}.info-value{display:block;text-align:left;margin-top:4px}.table-toolbar{align-items:stretch;flex-direction:column}.table-search{width:100%}.table-counter{white-space:normal}}
@media print{body{background:white}.report-shell{box-shadow:none;margin:0;border-radius:0}.dashboard-header{background:#1e40af !important}.tab-nav,.table-toolbar{display:none}.tab-panel{display:block !important;break-inside:avoid;box-shadow:none}.table-scroll{max-height:none;overflow:visible}.row-hidden{display:table-row !important}}
</style>
</head>
<body>
<div class="report-shell">
  <header class="dashboard-header">
    <div class="header-grid">
      <div class="brand"><div class="brand-icon">📊</div><div><h1>BRAVO SYSTEM REPORT</h1><p>$computerNameHtml | $timestampHtml | Profile: $profileHtml</p><p><span class="status-pill $statusClass">Health Score: $($script:Report.Health.Score)/100 — $statusHtml</span></p></div></div>
      <div class="header-meta"><div class="meta-tile"><div class="meta-label">Computer</div><div class="meta-value">$computerNameHtml</div></div><div class="meta-tile"><div class="meta-label">Uptime</div><div class="meta-value">$uptimeHtml</div></div><div class="meta-tile"><div class="meta-label">Primary IPv4</div><div class="meta-value">$primaryIpv4Html</div></div><div class="meta-tile"><div class="meta-label">Status reason</div><div class="meta-value">$statusReasonHtml</div></div></div>
    </div>
  </header>
  <nav class="tab-nav" aria-label="BRAVO report sections">
    <button type="button" class="tab-button active" data-tab-target="tab-general" onclick="openTab(event, 'tab-general')" aria-controls="tab-general" aria-selected="true">General</button>
    <button type="button" class="tab-button" data-tab-target="tab-os" onclick="openTab(event, 'tab-os')" aria-controls="tab-os" aria-selected="false">OS</button>
    <button type="button" class="tab-button" data-tab-target="tab-hardware" onclick="openTab(event, 'tab-hardware')" aria-controls="tab-hardware" aria-selected="false">Hardware</button>
    <button type="button" class="tab-button" data-tab-target="tab-network" onclick="openTab(event, 'tab-network')" aria-controls="tab-network" aria-selected="false">Network</button>
    <button type="button" class="tab-button" data-tab-target="tab-security" onclick="openTab(event, 'tab-security')" aria-controls="tab-security" aria-selected="false">Security</button>
    <button type="button" class="tab-button" data-tab-target="tab-services" onclick="openTab(event, 'tab-services')" aria-controls="tab-services" aria-selected="false">Services</button>
    <button type="button" class="tab-button" data-tab-target="tab-software" onclick="openTab(event, 'tab-software')" aria-controls="tab-software" aria-selected="false">Software</button>
    <button type="button" class="tab-button" data-tab-target="tab-findings" onclick="openTab(event, 'tab-findings')" aria-controls="tab-findings" aria-selected="false">Findings</button>
  </nav>
  <main class="content">
    <section id="tab-general" class="tab-panel active"><h2 class="tab-panel-title"><span class="section-icon">📌</span>General Dashboard</h2><div class="metrics-grid">$metricCardsHtml</div><div class="grid"><div class="card"><h3>Підсумок</h3>$(New-BravoInfoRowHtml 'Health Score' "$($script:Report.Health.Score)/100")$(New-BravoInfoRowHtml 'Status' $script:Report.Status)$(New-BravoInfoRowHtml 'Status reason' $script:Report.StatusReason)$(New-BravoInfoRowHtml 'Findings' $script:Report.Health.Findings.Count)$(New-BravoInfoRowHtml 'Collection errors' $script:Report.CollectionErrors.Count)</div><div class="card"><h3>Ключова мережа</h3>$(New-BravoInfoRowHtml 'Primary IPv4' $script:Report.Network.IP.PrimaryIPv4)$(New-BravoInfoRowHtml 'Gateway' ((@($script:Report.Network.Routing.DefaultGateways) | Where-Object { $_ }) -join ', '))$(New-BravoInfoRowHtml 'DNS' ((@($script:Report.Network.Routing.DNSServers) | Where-Object { $_ }) -join ', '))$(New-BravoInfoRowHtml 'Public IPv4 status' $publicIpv4StatusForReport)</div></div></section>
    <section id="tab-os" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">🖥️</span>OS</h2><div class="grid"><div class="card"><h3>Операційна система</h3>$(New-BravoInfoRowHtml 'OS' $script:Report.OS.Caption)$(New-BravoInfoRowHtml 'Version' $script:Report.OS.Version)$(New-BravoInfoRowHtml 'Build' $script:Report.OS.Build)$(New-BravoInfoRowHtml 'Architecture' $script:Report.OS.Architecture)$(New-BravoInfoRowHtml 'Install date' $script:Report.OS.InstallDate)$(New-BravoInfoRowHtml 'Last boot' $script:Report.OS.LastBootUpTime)$(New-BravoInfoRowHtml 'Uptime' $script:Report.Dashboard.Header.UptimeText)</div><div class="card"><h3>Runtime</h3>$(New-BravoInfoRowHtml 'PowerShell' $script:Report.PowerShell.Version)$(New-BravoInfoRowHtml 'Edition' $script:Report.PowerShell.Edition)$(New-BravoInfoRowHtml 'ExecutionPolicy' $script:Report.PowerShell.ExecutionPolicy)$(New-BravoInfoRowHtml '.NET v4' $script:Report.DotNet.v4)$(New-BravoInfoRowHtml 'Use CIM' $script:Report.Meta.UseCim)</div><div class="card"><h3>Windows Update</h3>$(New-BravoInfoRowHtml 'Service' $script:Report.WindowsUpdate.ServiceStatus)$(New-BravoInfoRowHtml 'Installed hotfixes' $script:Report.WindowsUpdate.InstalledHotFixCount)$(New-BravoInfoRowHtml 'Last hotfix' "$($script:Report.WindowsUpdate.LastInstalledHotFix) ($($script:Report.WindowsUpdate.LastInstallDate))")$(New-BravoInfoRowHtml 'Pending reboot' $(if($script:Report.WindowsUpdate.PendingRebootRequired){'Так'}else{'Ні'}))$(New-BravoInfoRowHtml 'Pending updates' $script:Report.WindowsUpdate.PendingCount)$(New-BravoInfoRowHtml 'Pending critical / security' "$($script:Report.WindowsUpdate.PendingCritical) / $($script:Report.WindowsUpdate.PendingSecurity)")$(New-BravoInfoRowHtml 'Search status' $script:Report.WindowsUpdate.SearchStatus)</div></div><h3>Pending Windows Updates</h3>$(New-BravoTableToolbarHtml -TableId 'table-pending-updates' -Placeholder 'Пошук по KB, назві, severity...')<div class="table-scroll"><table id="table-pending-updates" class="data-table"><thead><tr><th>KB</th><th>Назва</th><th>Severity</th><th>Категорії</th><th>Завантажено</th><th>Size MB</th></tr></thead><tbody>$updatesPendingRows</tbody></table></div></section>
    <section id="tab-hardware" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">🧠</span>Hardware</h2><div class="grid"><div class="card"><h3>CPU / RAM</h3>$(New-BravoInfoRowHtml 'CPU' $script:Report.Hardware.CPU.Name)$(New-BravoInfoRowHtml 'Cores / threads' "$($script:Report.Hardware.CPU.Cores)/$($script:Report.Hardware.CPU.LogicalProcessors)")<div class="info-row"><span class="info-label">CPU load</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$($script:Report.Hardware.CPU.LoadPercent)%">$($script:Report.Hardware.CPU.LoadPercent)%</div></div></span></div>$(New-BravoInfoRowHtml 'RAM total visible' "$($script:Report.Hardware.RAM.TotalVisibleMemoryGB) GB")$(New-BravoInfoRowHtml 'RAM used/free' "$($script:Report.Hardware.RAM.UsedGB) GB / $($script:Report.Hardware.RAM.FreeGB) GB")<div class="info-row"><span class="info-label">RAM used</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$($script:Report.Hardware.RAM.UsedPercent)%">$($script:Report.Hardware.RAM.UsedPercent)%</div></div></span></div></div><div class="card"><h3>Disk summary</h3>$(New-BravoInfoRowHtml 'Total' (Format-Size $script:Report.Hardware.Disks.TotalGB))$(New-BravoInfoRowHtml 'Free' (Format-Size $script:Report.Hardware.Disks.FreeGB))<div class="info-row"><span class="info-label">Free percent</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$($script:Report.Hardware.Disks.FreePercent)%">$($script:Report.Hardware.Disks.FreePercent)%</div></div></span></div></div></div><div class="storage-summary-grid"><div class="storage-summary-item"><div class="storage-summary-label">Critical volumes</div><div class="storage-summary-value"><span class="risk risk-critical">$criticalCount</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">Warning volumes</div><div class="storage-summary-value"><span class="risk risk-warning">$warningCount</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">System warnings</div><div class="storage-summary-value"><span class="risk risk-warning">$systemWarningCount</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">Healthy volumes</div><div class="storage-summary-value"><span class="risk risk-ok">$healthyCount</span></div></div></div><h3>Storage Critical Findings</h3>$(New-BravoTableToolbarHtml -TableId 'table-storage-critical' -Placeholder 'Пошук по storage findings...')<div class="table-scroll"><table id="table-storage-critical" class="data-table"><thead><tr><th>Том</th><th>Мітка</th><th>FS</th><th>Size GB</th><th>Free GB</th><th>Free %</th><th>Risk</th><th>Причина</th></tr></thead><tbody>$storageCriticalRows</tbody></table></div><h3>Storage Deep</h3>$(New-BravoTableToolbarHtml -TableId 'table-storage-deep' -Placeholder 'Пошук по дисках, FS, health, risk...')<div class="table-scroll"><table id="table-storage-deep" class="data-table"><thead><tr><th>Том</th><th>Мітка</th><th>FS</th><th>Тип</th><th>Health</th><th>Operational</th><th>Size GB</th><th>Free GB</th><th>Free %</th><th>Risk</th><th>Причина</th></tr></thead><tbody>$storageDeepRows</tbody></table></div></section>
    <section id="tab-network" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">🌐</span>Network</h2><div class="grid"><div class="card"><h3>Routing</h3>$(New-BravoInfoRowHtml 'Hostname' $script:Report.Network.General.Hostname)$(New-BravoInfoRowHtml 'Domain' $script:Report.Network.General.Domain)$(New-BravoInfoRowHtml 'IPv4' ((@($script:Report.Network.IP.IPv4) | Where-Object { $_ }) -join ', '))$(New-BravoInfoRowHtml 'Primary IPv4' $script:Report.Network.IP.PrimaryIPv4)$(New-BravoInfoRowHtml 'Gateway' ((@($script:Report.Network.Routing.DefaultGateways) | Where-Object { $_ }) -join ', '))$(New-BravoInfoRowHtml 'DNS' ((@($script:Report.Network.Routing.DNSServers) | Where-Object { $_ }) -join ', '))$(New-BravoInfoRowHtml 'Public IPv4 status' $publicIpv4StatusForReport)</div><div class="card"><h3>Connections</h3>$(New-BravoInfoRowHtml 'Established' $script:Report.Network.Connections.Established)$(New-BravoInfoRowHtml 'Listening' $script:Report.Network.Connections.Listening)$(New-BravoInfoRowHtml 'ISP / Organization' $script:Report.Network.IP.PublicIPv4ISP)$(New-BravoInfoRowHtml 'ASN' $script:Report.Network.IP.PublicIPv4ASN)$(New-BravoInfoRowHtml 'Location' $publicIpv4LocationForReport)$(New-BravoInfoRowHtml 'IP lookup provider' $script:Report.Network.IP.PublicIPv4Provider)$(New-BravoInfoRowHtml 'ISP lookup provider' $script:Report.Network.IP.PublicIPv4LookupProvider)$(New-BravoInfoRowHtml 'Checked at' $script:Report.Network.IP.PublicIPv4CheckedAt)</div></div><h3>Adapters</h3>$(New-BravoTableToolbarHtml -TableId 'table-network-adapters' -Placeholder 'Пошук по adapter, MAC, IPv4, gateway, DNS...')<div class="table-scroll"><table id="table-network-adapters" class="data-table"><thead><tr><th>Description</th><th>MAC</th><th>IPv4</th><th>Gateway</th><th>DNS</th><th>DHCP</th></tr></thead><tbody>$adapterRows</tbody></table></div></section>
    <section id="tab-security" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">🔒</span>Security</h2><div class="grid"><div class="card"><h3>Security baseline</h3>$(New-BravoInfoRowHtml 'UAC' $(if($script:Report.Security.UAC.Enabled){'Ввімкнено'}else{'Вимкнено'}))$(New-BravoInfoRowHtml 'RDP' $(if($script:Report.Security.RemoteAccess.RDPEnabled){'Ввімкнено'}else{'Вимкнено'}))$(New-BravoInfoRowHtml 'Antivirus' $script:Report.Security.Antivirus.Product)$(New-BravoInfoRowHtml 'Local admins' $script:Report.Users.LocalAdmins.Count)</div><div class="card"><h3>Firewall</h3>$(New-BravoInfoRowHtml 'Profiles collected' $script:Report.Security.Firewall.Count)$(New-BravoInfoRowHtml 'Health status' $script:Report.Health.Status)$(New-BravoInfoRowHtml 'Findings' $script:Report.Health.Findings.Count)</div></div></section>
    <section id="tab-services" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">⚙️</span>Services</h2><div class="grid"><div class="card"><h3>Service summary</h3>$(New-BravoInfoRowHtml 'Processes' $script:Report.Processes.Total)$(New-BravoInfoRowHtml 'Services running' "$($script:Report.Services.Running)/$($script:Report.Services.Total)")$(New-BravoInfoRowHtml 'Automatic stopped' $script:Report.Services.AutomaticStopped.Count)$(New-BravoInfoRowHtml "System errors ($EventLogDays дн.)" $script:Report.EventLogs.SystemErrors)$(New-BravoInfoRowHtml "System warnings ($EventLogDays дн.)" $script:Report.EventLogs.SystemWarnings)</div></div><h3>Automatic stopped services</h3>$(New-BravoTableToolbarHtml -TableId 'table-services-stopped' -Placeholder 'Пошук по службах...')<div class="table-scroll"><table id="table-services-stopped" class="data-table"><thead><tr><th>Name</th><th>DisplayName</th><th>StartType</th><th>Status</th></tr></thead><tbody>$serviceRows</tbody></table></div></section>
    <section id="tab-software" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">📦</span>Software</h2><div class="grid"><div class="card"><h3>Software summary</h3>$(New-BravoInfoRowHtml 'Installed software' $script:Report.Software.Installed.Count)$(New-BravoInfoRowHtml 'Profile' $Profile)</div></div><h3>Installed software</h3>$(New-BravoTableToolbarHtml -TableId 'table-software-installed' -Placeholder 'Пошук по назві, версії або видавцю...')<div class="table-scroll"><table id="table-software-installed" class="data-table"><thead><tr><th>Name</th><th>Version</th><th>Publisher</th><th>Install date</th></tr></thead><tbody>$softwareRows</tbody></table></div></section>
    <section id="tab-findings" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">🔎</span>Findings</h2>$(New-BravoTableToolbarHtml -TableId 'table-findings' -Placeholder 'Пошук по severity, category, message...')<div class="table-scroll"><table id="table-findings" class="data-table"><thead><tr><th>Severity</th><th>Category</th><th>Message</th><th>Recommendation</th></tr></thead><tbody>$findingsRows</tbody></table></div><h2 class="tab-panel-title"><span class="section-icon">🛠️</span>Помилки збору даних</h2>$(New-BravoTableToolbarHtml -TableId 'table-collection-errors' -Placeholder 'Пошук по помилках збору...')<div class="table-scroll"><table id="table-collection-errors" class="data-table"><thead><tr><th>Time</th><th>Section</th><th>Message</th></tr></thead><tbody>$errorsRows</tbody></table></div></section>
  </main>
  <footer class="footer"><p>BRAVO SYSTEM REPORT v$ScriptVersion | $OutputDir</p></footer>
</div>
<script>
(function(){
  function getPanels(){ return Array.prototype.slice.call(document.querySelectorAll('.tab-panel')); }
  function getButtons(){ return Array.prototype.slice.call(document.querySelectorAll('.tab-button')); }
  function normalizeText(value){ return (value || '').toString().toLowerCase(); }
  function updateTableCounter(tableId, visibleRows, totalRows){
    var counter = document.querySelector('[data-table-counter="' + tableId + '"]');
    if(counter){ counter.textContent = 'Рядків: ' + visibleRows + ' / ' + totalRows; }
  }
  function filterTable(tableId, query){
    var table = document.getElementById(tableId);
    if(!table || !table.tBodies || table.tBodies.length === 0){ return; }
    var rows = Array.prototype.slice.call(table.tBodies[0].rows);
    var searchText = normalizeText(query).trim();
    var visibleRows = 0;
    rows.forEach(function(row){
      var rowText = normalizeText(row.innerText || row.textContent);
      var isVisible = searchText === '' || rowText.indexOf(searchText) !== -1;
      row.classList.toggle('row-hidden', !isVisible);
      if(isVisible){ visibleRows++; }
    });
    updateTableCounter(tableId, visibleRows, rows.length);
  }
  function initializeTableFilters(){
    var filters = Array.prototype.slice.call(document.querySelectorAll('[data-table-filter]'));
    filters.forEach(function(input){
      var tableId = input.getAttribute('data-table-filter');
      filterTable(tableId, input.value);
      input.addEventListener('input', function(){ filterTable(tableId, input.value); });
    });
  }
  window.openTab = function(event, tabId){
    if(event && event.preventDefault){ event.preventDefault(); }
    var selectedPanel = document.getElementById(tabId);
    if(!selectedPanel){ return false; }
    getPanels().forEach(function(panel){ panel.classList.remove('active'); panel.style.display = 'none'; });
    getButtons().forEach(function(button){ button.classList.remove('active'); button.setAttribute('aria-selected', 'false'); });
    selectedPanel.classList.add('active');
    selectedPanel.style.display = 'block';
    var activeButton = event && event.currentTarget ? event.currentTarget : document.querySelector('.tab-button[data-tab-target="' + tabId + '"]');
    if(activeButton){ activeButton.classList.add('active'); activeButton.setAttribute('aria-selected', 'true'); }
    if(window.history && window.history.replaceState){ window.history.replaceState(null, '', '#' + tabId); }
    return false;
  };
  function activateInitialTab(){
    var requestedTab = window.location.hash ? window.location.hash.substring(1) : 'tab-general';
    if(!document.getElementById(requestedTab)){ requestedTab = 'tab-general'; }
    var button = document.querySelector('.tab-button[data-tab-target="' + requestedTab + '"]');
    window.openTab({ preventDefault:function(){}, currentTarget:button }, requestedTab);
  }
  if(document.readyState === 'loading'){
    document.addEventListener('DOMContentLoaded', function(){ initializeTableFilters(); activateInitialTab(); });
  } else {
    initializeTableFilters();
    activateInitialTab();
  }
})();
</script>
</body>
</html>
"@

            $htmlContent | Out-File $htmlPath -Encoding utf8
            $script:Report.GeneratedFiles += $htmlPath
            Write-Host "  $IconHtml HTML: $BaseFileName.html" -ForegroundColor Green
        } catch {
            Add-AuditError -Section 'Export.Html' -Message $_.Exception.Message
            Write-Host "  $IconError Помилка HTML: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
