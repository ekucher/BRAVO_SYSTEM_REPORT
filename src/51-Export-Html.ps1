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

            function Get-BravoSafePercentText {
                # Для progress-bar значень (style="width:...%"), які вставляються
                # без ConvertTo-BravoHtmlText напряму в HTML-атрибут і текст.
                # Гарантує, що на виході завжди чисте число 0-100 — навіть якщо
                # джерело (WMI/CIM) колись поверне не число, воно не потрапить
                # у розмітку як є.
                param([AllowNull()][object]$Value)
                $parsed = 0.0
                # [string]-каст PowerShell форматує double через InvariantCulture
                # (крапка), тож TryParse ТЕЖ має звірятись з InvariantCulture —
                # інакше на локалізованих ОС (де CurrentCulture очікує кому,
                # напр. uk-UA) парсинг мовчки провалюється і все стає "0%".
                if ($null -ne $Value -and [double]::TryParse([string]$Value, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
                    if ($parsed -lt 0) { $parsed = 0 }
                    if ($parsed -gt 100) { $parsed = 100 }
                    return $parsed.ToString([System.Globalization.CultureInfo]::InvariantCulture)
                }
                return '0'
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
            $updatesMetric = $dashboardMetrics.Updates

            $metricCardsHtml = @(
                New-BravoMetricCardHtml -Icon '🧠' -Title $cpuMetric.Title -Value $cpuMetric.Value -Details $cpuMetric.Details -Status $cpuMetric.Status
                New-BravoMetricCardHtml -Icon '💾' -Title $ramMetric.Title -Value $ramMetric.Value -Details $ramMetric.Details -Status $ramMetric.Status
                New-BravoMetricCardHtml -Icon '💿' -Title $diskMetric.Title -Value $diskMetric.Value -Details $diskMetric.Details -Status $diskMetric.Status
                New-BravoMetricCardHtml -Icon '🖥️' -Title $osMetric.Title -Value $osMetric.Value -Details $osMetric.Details -Status $osMetric.Status
                New-BravoMetricCardHtml -Icon '🔄' -Title $updatesMetric.Title -Value $updatesMetric.Value -Details $updatesMetric.Details -Status $updatesMetric.Status
            ) -join "`n"

            $findingsGrouped = Get-BravoFindingsGrouped -Findings $script:Report.Health.Findings
            $findingsRows = if (@($findingsGrouped.Sorted).Count -gt 0) {
                (@($findingsGrouped.Sorted) | ForEach-Object {
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

            $updatesSupportStatus = [string]$script:Report.Updates.OS.SupportStatus
            $updatesSupportStatusClass = switch ($updatesSupportStatus) {
                'EndOfSupport' { 'status-critical' }
                'EndingSoon'   { 'status-warning' }
                'Supported'    { 'status-ok' }
                default        { 'status-unknown' }
            }

            $updatesSupportStatusText = switch ($updatesSupportStatus) {
                'EndOfSupport' { 'Поза підтримкою' }
                'EndingSoon'   { 'Підтримка завершується' }
                'Supported'    { 'Підтримується' }
                default        { 'Невідомо' }
            }

            $updatesSearchStatus = [string]$script:Report.Updates.Search.Status
            $updatesSearchStatusText = switch ($updatesSearchStatus) {
                'OK'         { 'Виконано' }
                'Skipped'    { 'Пропущено' }
                'Timeout'    { 'Таймаут' }
                'Failed'     { 'Помилка' }
                'NotChecked' { 'Не перевірялось' }
                default      { $updatesSearchStatus }
            }
            if ($script:Report.Updates.Search.Error) {
                $updatesSearchStatusText = "$updatesSearchStatusText — $($script:Report.Updates.Search.Error)"
            }

            $pendingRebootText = if ($script:Report.Updates.PendingReboot.Required) {
                "Так: $((@($script:Report.Updates.PendingReboot.Reasons) | Where-Object { $_ }) -join '; ')"
            } else {
                'Ні'
            }

            $pendingUpdatesRows = if (@($script:Report.Updates.Pending.Items).Count -gt 0) {
                (@($script:Report.Updates.Pending.Items) | ForEach-Object {
                    $updateSeverityClass = if ($_.MsrcSeverity -eq 'Critical') { 'status-critical' } elseif ($_.MsrcSeverity) { 'status-warning' } else { 'status-unknown' }
                    $updateSeverityText = if ($_.MsrcSeverity) { [string]$_.MsrcSeverity } else { '—' }
                    $downloadedText = if ($_.IsDownloaded) { 'Так' } else { 'Ні' }
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Title)</td><td>$(ConvertTo-BravoHtmlText $_.KB)</td><td>$(ConvertTo-BravoHtmlText $_.Categories)</td><td><span class=`"status-pill $updateSeverityClass`">$(ConvertTo-BravoHtmlText $updateSeverityText)</span></td><td>$(ConvertTo-BravoHtmlText $_.SizeMB)</td><td>$downloadedText</td><td>$(ConvertTo-BravoHtmlText $_.ReleasedOn)</td></tr>"
                }) -join "`n"
            } elseif ($updatesSearchStatus -eq 'OK') {
                '<tr><td colspan="7" class="muted">Невстановлених оновлень не знайдено.</td></tr>'
            } else {
                '<tr><td colspan="7" class="muted">Пошук доступних оновлень не виконувався або завершився невдало.</td></tr>'
            }

            $installedUpdatesRows = if (@($script:Report.Updates.Installed.Recent).Count -gt 0) {
                (@($script:Report.Updates.Installed.Recent) | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.HotFixID)</td><td>$(ConvertTo-BravoHtmlText $_.Description)</td><td>$(ConvertTo-BravoHtmlText $_.InstalledBy)</td><td>$(ConvertTo-BravoHtmlText $_.InstalledOnText)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Дані про встановлені оновлення відсутні.</td></tr>'
            }

            $serviceRows = if ($script:Report.Services.AutomaticStopped.Count -gt 0) {
                ($script:Report.Services.AutomaticStopped | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Name)</td><td>$(ConvertTo-BravoHtmlText $_.DisplayName)</td><td>$(ConvertTo-BravoHtmlText $_.StartMode)</td><td>$(ConvertTo-BravoHtmlText $_.State)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Автоматичних служб у зупиненому стані не знайдено.</td></tr>'
            }

            $eventTopErrorRows = if ($script:Report.EventLogs.TopErrorSources.Count -gt 0) {
                ($script:Report.EventLogs.TopErrorSources | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Source)</td><td>$(ConvertTo-BravoHtmlText $_.Count)</td><td>$(ConvertTo-BravoHtmlText $_.LastMessage)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="3" class="muted">Помилок System log за вибраний період не знайдено.</td></tr>'
            }

            $eventLogSummaryRows = if (@($script:Report.EventLogs.LogSummaries).Count -gt 0) {
                (@($script:Report.EventLogs.LogSummaries) | ForEach-Object {
                    $logSummary = $_
                    $criticalText = if ($null -eq $logSummary.CriticalCount) { '—' } else { $logSummary.CriticalCount }
                    $criticalClass = if ($null -ne $logSummary.CriticalCount -and [int]$logSummary.CriticalCount -gt 0) { 'risk-critical' } else { 'risk-ok' }
                    $errorClass = if ($null -ne $logSummary.ErrorCount -and [int]$logSummary.ErrorCount -gt 0) { 'risk-warning' } else { 'risk-ok' }
                    "<tr><td>$(ConvertTo-BravoHtmlText $logSummary.LogName)</td><td>$(ConvertTo-BravoHtmlText $logSummary.Status)</td><td><span class=`"risk $criticalClass`">$(ConvertTo-BravoHtmlText $criticalText)</span></td><td><span class=`"risk $errorClass`">$(ConvertTo-BravoHtmlText $logSummary.ErrorCount)</span></td><td>$(ConvertTo-BravoHtmlText $logSummary.WarningCount)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="5" class="muted">Per-log summary недоступний для поточного профілю (Full/Deep/Forensic).</td></tr>'
            }

            $eventLogProviderRows = if (@($script:Report.EventLogs.LogSummaries).Count -gt 0) {
                $allProviders = @($script:Report.EventLogs.LogSummaries | ForEach-Object { $logName = $_.LogName; @($_.TopProviders) | ForEach-Object { [PSCustomObject]@{ LogName = $logName; ProviderName = $_.ProviderName; Count = $_.Count; LastMessage = $_.LastMessage } } })
                if ($allProviders.Count -gt 0) {
                    ($allProviders | ForEach-Object {
                        "<tr><td>$(ConvertTo-BravoHtmlText $_.LogName)</td><td>$(ConvertTo-BravoHtmlText $_.ProviderName)</td><td>$(ConvertTo-BravoHtmlText $_.Count)</td><td>$(ConvertTo-BravoHtmlText $_.LastMessage)</td></tr>"
                    }) -join "`n"
                } else {
                    '<tr><td colspan="4" class="muted">Провайдерів Critical/Error/Warning за вибраний період не знайдено.</td></tr>'
                }
            } else {
                '<tr><td colspan="4" class="muted">Provider summary недоступний для поточного профілю (Full/Deep/Forensic).</td></tr>'
            }

            $hardwareDiagnosticRows = if (@($script:Report.EventLogs.HardwareDiagnostics).Count -gt 0) {
                (@($script:Report.EventLogs.HardwareDiagnostics) | ForEach-Object {
                    $diag = $_
                    $countText = if ($null -eq $diag.Count) { '—' } else { $diag.Count }
                    $countClass = if ($null -ne $diag.Count -and [int]$diag.Count -gt 0) { 'risk-warning' } else { 'risk-ok' }
                    "<tr><td>$(ConvertTo-BravoHtmlText $diag.Provider)</td><td>$(ConvertTo-BravoHtmlText $diag.Status)</td><td><span class=`"risk $countClass`">$(ConvertTo-BravoHtmlText $countText)</span></td><td>$(ConvertTo-BravoHtmlText $diag.LastMessage)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Hardware diagnostics недоступні для поточного профілю (Full/Deep/Forensic).</td></tr>'
            }

            $listeningPortRows = if (@($script:Report.Network.Connections.ListeningPorts).Count -gt 0) {
                (@($script:Report.Network.Connections.ListeningPorts) | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.LocalAddress)</td><td>$(ConvertTo-BravoHtmlText $_.LocalPort)</td><td>$(ConvertTo-BravoHtmlText $_.OwningProcess)</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $_.ProcessName))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Listening ports недоступні для поточного профілю (Full/Deep/Forensic).</td></tr>'
            }

            $establishedConnectionRows = if (@($script:Report.Network.Connections.EstablishedConnections).Count -gt 0) {
                (@($script:Report.Network.Connections.EstablishedConnections) | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.LocalAddress)</td><td>$(ConvertTo-BravoHtmlText $_.LocalPort)</td><td>$(ConvertTo-BravoHtmlText $_.RemoteAddress)</td><td>$(ConvertTo-BravoHtmlText $_.RemotePort)</td><td>$(ConvertTo-BravoHtmlText $_.OwningProcess)</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $_.ProcessName))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="6" class="muted">Established connections недоступні для поточного профілю (Full/Deep/Forensic).</td></tr>'
            }

            $smbShareRows = if (@($script:Report.Network.SmbShares).Count -gt 0) {
                (@($script:Report.Network.SmbShares) | ForEach-Object {
                    $share = $_
                    $adminClass = if ($share.IsAdministrative) { 'risk-unknown' } else { 'risk-ok' }
                    "<tr><td>$(ConvertTo-BravoHtmlText $share.Name)</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $share.Path))</td><td>$(ConvertTo-BravoHtmlText $share.ShareType)</td><td><span class=`"risk $adminClass`">$(ConvertTo-BravoHtmlText $share.IsAdministrative)</span></td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">SMB shares недоступні (модуль SmbShare відсутній, шар немає, або профіль не Full/Deep/Forensic).</td></tr>'
            }

            $adapterRows = if ($script:Report.Network.Adapters.Count -gt 0) {
                ($script:Report.Network.Adapters | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Description)</td><td>$(ConvertTo-BravoHtmlText $_.MACAddress)</td><td>$(ConvertTo-BravoHtmlListText $_.IPv4)</td><td>$(ConvertTo-BravoHtmlListText $_.Gateway)</td><td>$(ConvertTo-BravoHtmlListText $_.DNS)</td><td>$(ConvertTo-BravoHtmlText $_.DHCPEnabled)</td><td>$(ConvertTo-BravoHtmlText $_.LinkSpeed)</td><td>$(ConvertTo-BravoHtmlText $_.Status)</td><td>$(ConvertTo-BravoHtmlText $_.DriverVersion)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="9" class="muted">Мережеві адаптери не знайдені або збір недоступний.</td></tr>'
            }

            $routingTableEntries = @($script:Report.Network.Routing.RoutingTable)
            $routingTableRows = if ($routingTableEntries.Count -gt 0) {
                ($routingTableEntries | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.DestinationPrefix)</td><td>$(ConvertTo-BravoHtmlText $_.NextHop)</td><td>$(ConvertTo-BravoHtmlText $_.RouteMetric)</td><td>$(ConvertTo-BravoHtmlText $_.InterfaceAlias)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Routing table дані відсутні (профіль не Full/Deep/Forensic, або збір завершився з помилкою).</td></tr>'
            }

            $arpEntries = @($script:Report.Network.ARP)
            $arpRows = if ($arpEntries.Count -gt 0) {
                ($arpEntries | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.IPAddress)</td><td>$(ConvertTo-BravoHtmlText $_.LinkLayerAddress)</td><td>$(ConvertTo-BravoHtmlText $_.State)</td><td>$(ConvertTo-BravoHtmlText $_.InterfaceAlias)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">ARP-кеш даних відсутні (профіль не Full/Deep/Forensic, або збір завершився з помилкою).</td></tr>'
            }

            $winHttpProxyText = if (@($script:Report.Network.WinHttpProxy.RawOutput).Count -gt 0) {
                (@($script:Report.Network.WinHttpProxy.RawOutput) -join '; ')
            } else {
                $script:Report.Network.WinHttpProxy.Status
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
            $reservedCount = if ($storageRisk -and $storageRisk.Summary) { [int]$storageRisk.Summary.ReservedCount } else { 0 }

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
                    $hasDriveLetter = [bool]($volume.DriveLetter -and [string]$volume.DriveLetter -ne '')
                    # Томи без літери диска (WinRE/EFI/MSR) — системно-
                    # зарезервовані розділи, майже завжди заповнені образом
                    # відновлення; той самий принцип виключення, що й у
                    # Get-BravoStorageRiskSummary (src/32-Collectors-Storage.ps1)
                    # — інакше ця таблиця незалежно рахує WARNING/CRITICAL для
                    # штатного стану, розбігаючись із Findings-зведенням вище.
                    $riskText = if (-not $hasDriveLetter) { 'RESERVED' } elseif ($null -eq $freePercent) { 'UNKNOWN' } elseif ($freePercent -lt $criticalThreshold) { 'CRITICAL' } elseif ($freePercent -lt $warningThreshold) { 'WARNING' } else { 'OK' }
                    $riskClass = Get-BravoStorageRiskClass $riskText
                    $reason = if ($riskText -eq 'RESERVED') { 'Системно-зарезервований том без літери диска (WinRE/EFI/MSR) — не є ризиком.' } elseif ($riskText -eq 'CRITICAL') { "Вільного місця менше $criticalThreshold%." } elseif ($riskText -eq 'WARNING') { "Вільного місця менше $warningThreshold%." } elseif ($riskText -eq 'UNKNOWN') { 'Не вдалося визначити free percent.' } else { 'Показники в межах порогів.' }
                    "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStorageDisplayText $volume))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FileSystemLabel))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FileSystem))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.DriveType))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.HealthStatus))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.OperationalStatus))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.SizeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreePercent))%</td><td><span class=`"risk $riskClass`">$(ConvertTo-BravoHtmlText $riskText)</span></td><td>$(ConvertTo-BravoHtmlText $reason)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="11" class="muted">Storage Deep дані відсутні для поточного профілю або збір завершився з помилкою.</td></tr>'
            }

            $bitlockerVolumes = @($storageDeep.BitLocker)
            $bitlockerRows = if ($bitlockerVolumes.Count -gt 0) {
                ($bitlockerVolumes | ForEach-Object {
                    $volume = $_
                    $protectionText = [string]$volume.ProtectionStatus
                    $protectionClass = if ($protectionText -eq 'On') { 'risk-ok' } elseif ($protectionText -eq 'Off') { 'risk-warning' } else { 'risk-unknown' }
                    "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.MountPoint))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.VolumeType))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.VolumeStatus))</td><td><span class=`"risk $protectionClass`">$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.ProtectionStatus))</span></td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.EncryptionPercentage))%</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.EncryptionMethod))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.LockStatus))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="7" class="muted">BitLocker дані відсутні (модуль не встановлено, профіль не Deep/Forensic, або збір завершився з помилкою).</td></tr>'
            }

            $shadowCopyList = @($storageDeep.ShadowCopies)
            $shadowCopyRows = if ($shadowCopyList.Count -gt 0) {
                ($shadowCopyList | ForEach-Object {
                    $shadowCopy = $_
                    "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $shadowCopy.VolumeName))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $shadowCopy.InstallDate))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $shadowCopy.ClientAccessible))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $shadowCopy.Persistent))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Точки відновлення VSS відсутні (немає активних точок відновлення, або профіль не Deep/Forensic).</td></tr>'
            }

            $storagePoolList = @($storageDeep.StoragePools)
            $storagePoolRows = if ($storagePoolList.Count -gt 0) {
                ($storagePoolList | ForEach-Object {
                    $pool = $_
                    $poolHealthText = [string]$pool.HealthStatus
                    $poolHealthClass = if ($poolHealthText -eq 'Healthy') { 'risk-ok' } elseif ($poolHealthText -eq '') { 'risk-unknown' } else { 'risk-warning' }
                    "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $pool.FriendlyName))</td><td><span class=`"risk $poolHealthClass`">$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $pool.HealthStatus))</span></td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $pool.OperationalStatus))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $pool.SizeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $pool.AllocatedGB))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="5" class="muted">Storage Spaces не використовується (немає пулів, модуль Storage відсутній, або профіль не Deep/Forensic).</td></tr>'
            }

            $reliabilityList = @($storageDeep.ReliabilityCounters)
            $reliabilityRows = if ($reliabilityList.Count -gt 0) {
                ($reliabilityList | ForEach-Object {
                    $counter = $_
                    $wearText = if ($null -ne $counter.WearPercent -and [string]$counter.WearPercent -ne '') { "$($counter.WearPercent)%" } else { '—' }
                    $wearClass = if ($null -ne $counter.WearPercent -and [string]$counter.WearPercent -ne '' -and [double]$counter.WearPercent -ge 90) { 'risk-warning' } else { 'risk-ok' }
                    $readUncorrected = if ($counter.ReadErrorsUncorrected) { [int64]$counter.ReadErrorsUncorrected } else { 0 }
                    $writeUncorrected = if ($counter.WriteErrorsUncorrected) { [int64]$counter.WriteErrorsUncorrected } else { 0 }
                    $uncorrectedErrors = $readUncorrected + $writeUncorrected
                    $errorsClass = if ($uncorrectedErrors -gt 0) { 'risk-warning' } else { 'risk-ok' }
                    "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $counter.FriendlyName))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $counter.MediaType))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $counter.TemperatureCelsius))</td><td><span class=`"risk $wearClass`">$(ConvertTo-BravoHtmlText $wearText)</span></td><td><span class=`"risk $errorsClass`">$uncorrectedErrors</span></td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $counter.PowerOnHours))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="6" class="muted">SMART reliability counters відсутні (модуль Storage не встановлено, диск не підтримує лічильники, або профіль не Deep/Forensic).</td></tr>'
            }

            $smartPredictList = @($storageDeep.SmartPredictFailures)
            $smartPredictRows = if ($smartPredictList.Count -gt 0) {
                ($smartPredictList | ForEach-Object {
                    $predict = $_
                    $predictClass = if ($predict.PredictFailure) { 'risk-critical' } else { 'risk-ok' }
                    "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $predict.InstanceName))</td><td><span class=`"risk $predictClass`">$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $predict.PredictFailure))</span></td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $predict.Reason))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="3" class="muted">SMART predictive-failure API недоступне на цій машині (типово для NVMe/RAID-контролерів — обмеження драйвера, не помилка).</td></tr>'
            }

            $monitorRows = if (@($script:Report.Hardware.Monitors).Count -gt 0) {
                (@($script:Report.Hardware.Monitors) | ForEach-Object {
                    $monitor = $_
                    $sizeText = if ($monitor.WidthCm -and $monitor.HeightCm) { "$($monitor.WidthCm)x$($monitor.HeightCm) см" } else { '—' }
                    "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $monitor.Manufacturer))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $monitor.Model))</td><td>$(ConvertTo-BravoHtmlText $monitor.Active)</td><td>$(ConvertTo-BravoHtmlText $sizeText)</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $monitor.YearOfManufacture))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="5" class="muted">Дані про монітори недоступні (WmiMonitorID, напр. на VM/RDP-сесії без реального дисплея).</td></tr>'
            }

            $gpuList = @($script:Report.Hardware.GPU)
            $gpuRows = if ($gpuList.Count -gt 0) {
                ($gpuList | ForEach-Object {
                    $gpu = $_
                    $adapterRamText = if ($gpu.AdapterRAMBytes) { Format-Size ([Math]::Round($gpu.AdapterRAMBytes / 1GB, 2)) } else { 'N/A' }
                    "<tr><td>$(ConvertTo-BravoHtmlText $gpu.Name)</td><td>$(ConvertTo-BravoHtmlText $adapterRamText)</td><td>$(ConvertTo-BravoHtmlText $gpu.DriverVersion)</td><td>$(ConvertTo-BravoHtmlText $gpu.CurrentResolution)</td><td>$(ConvertTo-BravoHtmlText $gpu.Status)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="5" class="muted">GPU дані відсутні (профіль не Full/Deep/Forensic, або збір завершився з помилкою).</td></tr>'
            }

            $tlsProtocolList = @($script:Report.Security.TLS.Protocols)
            $tlsRows = if ($tlsProtocolList.Count -gt 0) {
                ($tlsProtocolList | ForEach-Object {
                    $tlsEntry = $_
                    $tlsStatusText = [string]$tlsEntry.Status
                    $tlsStatusClass = if ($tlsStatusText -eq 'Enabled') { 'risk-ok' } elseif ($tlsStatusText -eq 'Disabled') { 'risk-warning' } else { 'risk-unknown' }
                    "<tr><td>$(ConvertTo-BravoHtmlText $tlsEntry.Protocol)</td><td>$(ConvertTo-BravoHtmlText $tlsEntry.Side)</td><td><span class=`"risk $tlsStatusClass`">$(ConvertTo-BravoHtmlText $tlsStatusText)</span></td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="3" class="muted">TLS registry дані відсутні (профіль не Full/Deep/Forensic, або збір завершився з помилкою).</td></tr>'
            }

            $auditPolicyEntries = @($script:Report.Security.AuditPolicy.Subcategories)
            $auditPolicyRows = if ($auditPolicyEntries.Count -gt 0) {
                ($auditPolicyEntries | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Category)</td><td>$(ConvertTo-BravoHtmlText $_.Subcategory)</td><td>$(ConvertTo-BravoHtmlText $_.InclusionSetting)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="3" class="muted">Audit policy дані відсутні (профіль не Full/Deep/Forensic, або збір завершився з помилкою).</td></tr>'
            }

            $autorunEntries = @($script:Report.Security.Autoruns)
            $autorunRows = if ($autorunEntries.Count -gt 0) {
                ($autorunEntries | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Name)</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $_.Command))</td><td>$(ConvertTo-BravoHtmlText $_.Source)</td><td>$(ConvertTo-BravoHtmlText $_.Hive)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Autoruns-записів не знайдено (профіль не Deep/Forensic, або чисте автозавантаження).</td></tr>'
            }

            $scheduledTaskEntries = @($script:Report.Security.ScheduledTasks | Where-Object { -not $_.IsMicrosoftDefault })
            $scheduledTaskRows = if ($scheduledTaskEntries.Count -gt 0) {
                ($scheduledTaskEntries | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Name)</td><td>$(ConvertTo-BravoHtmlText $_.Path)</td><td>$(ConvertTo-BravoHtmlText $_.State)</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $_.Author))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $_.Execute))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="5" class="muted">Не-Microsoft scheduled tasks не знайдено (профіль не Deep/Forensic, або всі задачі — вбудовані Microsoft-задачі).</td></tr>'
            }
            $scheduledTaskMicrosoftCount = @($script:Report.Security.ScheduledTasks | Where-Object { $_.IsMicrosoftDefault }).Count

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
                    # Allow-list схеми перед вставкою в href: HTML-encode сам собою
                    # не блокує javascript:/data:-URI, лише екранує спецсимволи.
                    $catalogUrlValue = [string]$pendingUpdate.CatalogUrl
                    $catalogLinkHtml = if ([string]::IsNullOrWhiteSpace($catalogUrlValue) -or $catalogUrlValue -notmatch '^https://') { '' } else { "<a href=`"$(ConvertTo-BravoHtmlText $catalogUrlValue)`" target=`"_blank`" rel=`"noopener noreferrer`">Catalog ↗</a>" }
                    "<tr><td>$(ConvertTo-BravoHtmlText $pendingUpdate.KB)</td><td>$(ConvertTo-BravoHtmlText $pendingUpdate.Title)</td><td><span class=`"risk $severityClass`">$(ConvertTo-BravoHtmlText $severityText)</span></td><td>$(ConvertTo-BravoHtmlText $pendingUpdate.Categories)</td><td>$(if($pendingUpdate.IsDownloaded){'Так'}else{'Ні'})</td><td>$(ConvertTo-BravoHtmlText $pendingUpdate.SizeMB)</td><td>$catalogLinkHtml</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="7" class="muted">Відсутні оновлення не виявлені, пошук пропущено або завершився з помилкою (див. Search status).</td></tr>'
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
:root{--page-bg:#0b1020;--panel:#ffffff;--panel-soft:#f8fafc;--panel-muted:#eef2ff;--text:#0f172a;--muted:#64748b;--line:#e2e8f0;--primary:#2563eb;--primary-dark:#1e40af;--accent:#06b6d4;--success:#16a34a;--warning:#d97706;--critical:#dc2626;--unknown:#64748b;--shadow:0 22px 60px rgba(15,23,42,.24);--radius-lg:24px;--radius-md:18px;--radius-sm:12px;--nav-bg:rgba(248,250,252,.96);--btn-bg:#ffffff;--btn-text:#1e293b;--tab-panel-bg:linear-gradient(180deg,#ffffff,#fbfdff);--title-text:#0f172a;--metric-card-bg:linear-gradient(180deg,#ffffff,#f8fafc);--toolbar-bg:#f8fafc;--search-bg:#ffffff;--search-border:#cbd5e1;--table-scroll-bg:#ffffff;--th-bg:#eff6ff;--th-text:#1e3a8a;--storage-item-bg:#f8fafc;--progress-track:#e2e8f0}
:root[data-theme="dark"]{--panel:#0f172a;--panel-soft:#1e293b;--panel-muted:#1e3a5f;--text:#e2e8f0;--muted:#94a3b8;--line:#334155;--nav-bg:rgba(15,23,42,.94);--btn-bg:#1e293b;--btn-text:#e2e8f0;--tab-panel-bg:linear-gradient(180deg,#1e293b,#0f172a);--title-text:#e2e8f0;--metric-card-bg:linear-gradient(180deg,#1e293b,#0f172a);--toolbar-bg:#1e293b;--search-bg:#0f172a;--search-border:#334155;--table-scroll-bg:#0f172a;--th-bg:#1e3a5f;--th-text:#93c5fd;--storage-item-bg:#1e293b;--progress-track:#334155}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--panel:#0f172a;--panel-soft:#1e293b;--panel-muted:#1e3a5f;--text:#e2e8f0;--muted:#94a3b8;--line:#334155;--nav-bg:rgba(15,23,42,.94);--btn-bg:#1e293b;--btn-text:#e2e8f0;--tab-panel-bg:linear-gradient(180deg,#1e293b,#0f172a);--title-text:#e2e8f0;--metric-card-bg:linear-gradient(180deg,#1e293b,#0f172a);--toolbar-bg:#1e293b;--search-bg:#0f172a;--search-border:#334155;--table-scroll-bg:#0f172a;--th-bg:#1e3a5f;--th-text:#93c5fd;--storage-item-bg:#1e293b;--progress-track:#334155}}
.theme-toggle{display:inline-flex;align-items:center;justify-content:center;width:38px;height:38px;border-radius:12px;border:1px solid rgba(255,255,255,.28);background:rgba(255,255,255,.13);color:white;font-size:18px;cursor:pointer;line-height:1}.theme-toggle:hover{background:rgba(255,255,255,.24)}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;font-family:'Segoe UI',Roboto,Arial,sans-serif;background:radial-gradient(circle at 15% 8%,rgba(37,99,235,.34),transparent 28%),radial-gradient(circle at 92% 18%,rgba(6,182,212,.28),transparent 30%),linear-gradient(135deg,#0b1020,#111827 48%,#020617);color:var(--text)}
.report-shell{max-width:1440px;margin:28px auto;background:var(--panel);border-radius:var(--radius-lg);overflow:hidden;box-shadow:var(--shadow)}
.dashboard-header{position:relative;color:white;padding:32px 38px 24px 38px;background:linear-gradient(135deg,rgba(37,99,235,.98),rgba(14,165,233,.88)),linear-gradient(135deg,#0f172a,#1e293b)}
.dashboard-header:after{content:'';position:absolute;right:-70px;bottom:-120px;width:280px;height:280px;border-radius:999px;background:rgba(255,255,255,.13)}
.header-grid{position:relative;z-index:1;display:grid;grid-template-columns:minmax(0,1fr) auto auto;gap:22px;align-items:start}.brand{display:flex;gap:18px;align-items:center}.brand-icon{width:70px;height:70px;display:flex;align-items:center;justify-content:center;border-radius:22px;background:rgba(255,255,255,.18);border:1px solid rgba(255,255,255,.28);font-size:36px}
.dashboard-header h1{margin:0;font-size:34px;letter-spacing:.4px}.dashboard-header p{margin:8px 0 0 0;opacity:.92}.header-meta{display:grid;grid-template-columns:repeat(2,minmax(130px,auto));gap:10px;min-width:320px}.meta-tile{padding:10px 12px;border:1px solid rgba(255,255,255,.24);border-radius:14px;background:rgba(255,255,255,.13);backdrop-filter:blur(8px)}.meta-label{font-size:11px;text-transform:uppercase;letter-spacing:.06em;opacity:.75;font-weight:800}.meta-value{font-size:14px;font-weight:900;margin-top:4px;word-break:break-word}
.status-pill{display:inline-flex;align-items:center;justify-content:center;border-radius:999px;padding:6px 10px;font-size:12px;font-weight:900;letter-spacing:.03em;white-space:nowrap}.status-ok{background:rgba(22,163,74,.12);color:var(--success);border:1px solid rgba(22,163,74,.35)}.status-warning{background:rgba(217,119,6,.12);color:var(--warning);border:1px solid rgba(217,119,6,.35)}.status-critical{background:rgba(220,38,38,.12);color:var(--critical);border:1px solid rgba(220,38,38,.35)}.status-unknown{background:rgba(100,116,139,.12);color:var(--unknown);border:1px solid rgba(100,116,139,.35)}.dashboard-header .status-pill{background:rgba(255,255,255,.16);color:white;border-color:rgba(255,255,255,.3)}
.tab-nav{position:sticky;top:0;z-index:10;display:flex;flex-wrap:wrap;gap:8px;padding:14px 30px;background:var(--nav-bg);border-bottom:1px solid var(--line);backdrop-filter:blur(12px)}.tab-button{display:inline-flex;align-items:center;gap:8px;padding:10px 14px;border-radius:999px;border:1px solid var(--line);background:var(--btn-bg);color:var(--btn-text);text-decoration:none;font-weight:900;font-size:13px;box-shadow:0 4px 14px rgba(15,23,42,.06);cursor:pointer}.tab-button.active,.tab-button:hover{background:#2563eb;color:white;border-color:#2563eb}
.content{padding:30px}.tab-panel{display:none;margin-bottom:30px;padding:24px;border:1px solid var(--line);border-radius:22px;background:var(--tab-panel-bg);box-shadow:0 10px 30px rgba(15,23,42,.06)}.tab-panel.active{display:block}.tab-panel-title{display:flex;align-items:center;gap:12px;margin:0 0 18px 0;color:var(--title-text);font-size:22px}.tab-panel-title:after{content:'';flex:1;height:1px;background:var(--line)}.section-icon{width:38px;height:38px;display:inline-flex;align-items:center;justify-content:center;border-radius:12px;background:var(--panel-muted);color:var(--primary)}
.metrics-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:16px;margin-bottom:22px}.metric-card{position:relative;min-height:160px;padding:20px;border:1px solid var(--line);border-radius:20px;background:var(--metric-card-bg);box-shadow:0 8px 24px rgba(15,23,42,.07);overflow:hidden}.metric-card:before{content:'';position:absolute;left:0;top:0;bottom:0;width:5px;background:var(--unknown)}.metric-card.status-ok:before{background:var(--success)}.metric-card.status-warning:before{background:var(--warning)}.metric-card.status-critical:before{background:var(--critical)}.metric-topline{display:flex;justify-content:space-between;gap:10px;align-items:center;margin-bottom:12px}.metric-icon{font-size:30px}.metric-title{color:var(--muted);font-size:13px;font-weight:900;text-transform:uppercase;letter-spacing:.06em}.metric-value{margin-top:8px;font-size:24px;font-weight:950;color:var(--text);line-height:1.15;word-break:break-word}.metric-details{margin-top:8px;color:var(--muted);font-size:13px;line-height:1.45}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:18px}.card{background:var(--panel-soft);border:1px solid var(--line);border-radius:18px;padding:20px;box-shadow:0 8px 24px rgba(15,23,42,.06)}.card h3{display:flex;align-items:center;gap:8px;margin:0 0 14px 0;font-size:18px;color:var(--title-text)}.info-row{display:flex;justify-content:space-between;gap:16px;padding:10px 0;border-bottom:1px solid var(--line)}.info-row:last-child{border-bottom:none}.info-label{font-weight:850;color:var(--muted)}.info-value{color:var(--text);text-align:right;word-break:break-word;font-weight:650}.progress-bar{background:var(--progress-track);border-radius:999px;overflow:hidden;min-width:170px;height:24px}.progress-fill{height:24px;line-height:24px;background:linear-gradient(90deg,var(--primary),var(--accent));color:white;text-align:center;font-size:12px;font-weight:900}
.table-toolbar{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:10px 0 10px 0;padding:10px 12px;border:1px solid var(--line);border-radius:14px;background:var(--toolbar-bg)}.table-search{width:min(420px,100%);padding:10px 12px;border:1px solid var(--search-border);border-radius:12px;background:var(--search-bg);color:var(--text);font-size:13px;font-weight:650;outline:none}.table-search:focus{border-color:var(--primary);box-shadow:0 0 0 3px rgba(37,99,235,.16)}.table-counter{color:var(--muted);font-size:12px;font-weight:900;white-space:nowrap}.row-hidden{display:none !important}
.table-scroll{max-height:430px;overflow:auto;border:1px solid var(--line);border-radius:14px;background:var(--table-scroll-bg)}.data-table{width:100%;border-collapse:separate;border-spacing:0;font-size:13px}.data-table th,.data-table td{padding:11px 12px;text-align:left;border-bottom:1px solid var(--line);vertical-align:top}.data-table th{position:sticky;top:0;background:var(--th-bg);color:var(--th-text);font-size:12px;text-transform:uppercase;letter-spacing:.04em;z-index:1}.data-table tr:last-child td{border-bottom:none}.storage-summary-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin:12px 0 16px 0}.storage-summary-item{background:var(--storage-item-bg);border:1px solid var(--line);border-radius:12px;padding:12px}.storage-summary-label{color:var(--muted);font-size:12px;margin-bottom:4px;font-weight:800;text-transform:uppercase;letter-spacing:.04em}.storage-summary-value{font-size:22px;font-weight:900}.risk{font-weight:900;white-space:nowrap}.risk-critical{color:var(--critical)}.risk-warning{color:var(--warning)}.risk-ok{color:var(--success)}.risk-unknown{color:var(--muted)}.muted{color:var(--muted)}.footer{background:var(--toolbar-bg);border-top:1px solid var(--line);padding:18px 24px;text-align:center;color:var(--muted);font-size:13px}
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
      <button type="button" id="theme-toggle" class="theme-toggle" onclick="toggleTheme()" aria-label="Перемкнути тему" title="Світла/темна тема">🌙</button>
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
    <button type="button" class="tab-button" data-tab-target="tab-updates" onclick="openTab(event, 'tab-updates')" aria-controls="tab-updates" aria-selected="false">Updates</button>
    <button type="button" class="tab-button" data-tab-target="tab-findings" onclick="openTab(event, 'tab-findings')" aria-controls="tab-findings" aria-selected="false">Findings</button>
  </nav>
  <main class="content">
    <section id="tab-general" class="tab-panel active"><h2 class="tab-panel-title"><span class="section-icon">📌</span>General Dashboard</h2><div class="metrics-grid">$metricCardsHtml</div><div class="grid"><div class="card"><h3>Підсумок</h3>$(New-BravoInfoRowHtml 'Health Score' "$($script:Report.Health.Score)/100")$(New-BravoInfoRowHtml 'Status' $script:Report.Status)$(New-BravoInfoRowHtml 'Status reason' $script:Report.StatusReason)$(New-BravoInfoRowHtml 'Findings' $script:Report.Health.Findings.Count)$(New-BravoInfoRowHtml 'Collection errors' $script:Report.CollectionErrors.Count)</div><div class="card"><h3>Ключова мережа</h3>$(New-BravoInfoRowHtml 'Primary IPv4' $script:Report.Network.IP.PrimaryIPv4)$(New-BravoInfoRowHtml 'Gateway' ((@($script:Report.Network.Routing.DefaultGateways) | Where-Object { $_ }) -join ', '))$(New-BravoInfoRowHtml 'DNS' ((@($script:Report.Network.Routing.DNSServers) | Where-Object { $_ }) -join ', '))$(New-BravoInfoRowHtml 'Public IPv4 status' $publicIpv4StatusForReport)</div></div></section>
    <section id="tab-os" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">🖥️</span>OS</h2><div class="grid"><div class="card"><h3>Операційна система</h3>$(New-BravoInfoRowHtml 'OS' $script:Report.OS.Caption)$(New-BravoInfoRowHtml 'Version' $script:Report.OS.Version)$(New-BravoInfoRowHtml 'Build' $script:Report.OS.Build)$(New-BravoInfoRowHtml 'Architecture' $script:Report.OS.Architecture)$(New-BravoInfoRowHtml 'Install date' $script:Report.OS.InstallDate)$(New-BravoInfoRowHtml 'Last boot' $script:Report.OS.LastBootUpTime)$(New-BravoInfoRowHtml 'Uptime' $script:Report.Dashboard.Header.UptimeText)</div><div class="card"><h3>Runtime</h3>$(New-BravoInfoRowHtml 'PowerShell' $script:Report.PowerShell.Version)$(New-BravoInfoRowHtml 'Edition' $script:Report.PowerShell.Edition)$(New-BravoInfoRowHtml 'ExecutionPolicy' $script:Report.PowerShell.ExecutionPolicy)$(New-BravoInfoRowHtml '.NET v4' $script:Report.DotNet.v4)$(New-BravoInfoRowHtml '.NET оновлення' $(if($script:Report.DotNet.UpdateAvailable){"Доступне (найновіша: $($script:Report.DotNet.LatestKnownVersion))"}else{'Немає'}))$(New-BravoInfoRowHtml 'PowerShell 7 (Core)' $(if($script:Report.PowerShell.Core7Installed){$script:Report.PowerShell.Core7Version}else{'Не встановлено'}))$(New-BravoInfoRowHtml 'PowerShell 7 оновлення' $(if($script:Report.PowerShell.Core7UpdateAvailable){"Доступне (найновіша: $($script:Report.PowerShell.Core7LatestKnown))"}else{'Немає'}))$(New-BravoInfoRowHtml 'Use CIM' $script:Report.Meta.UseCim)</div><div class="card"><h3>Windows Update</h3>$(New-BravoInfoRowHtml 'Service' $script:Report.WindowsUpdate.ServiceStatus)$(New-BravoInfoRowHtml 'Installed hotfixes' $script:Report.WindowsUpdate.InstalledHotFixCount)$(New-BravoInfoRowHtml 'Last hotfix' "$($script:Report.WindowsUpdate.LastInstalledHotFix) ($($script:Report.WindowsUpdate.LastInstallDate))")$(New-BravoInfoRowHtml 'Pending reboot' $(if($script:Report.WindowsUpdate.PendingRebootRequired){'Так'}else{'Ні'}))$(New-BravoInfoRowHtml 'Pending updates' $script:Report.WindowsUpdate.PendingCount)$(New-BravoInfoRowHtml 'Pending critical / security' "$($script:Report.WindowsUpdate.PendingCritical) / $($script:Report.WindowsUpdate.PendingSecurity)")$(New-BravoInfoRowHtml 'Search status' $script:Report.WindowsUpdate.SearchStatus)</div></div><h3>Pending Windows Updates</h3>$(New-BravoTableToolbarHtml -TableId 'table-pending-updates' -Placeholder 'Пошук по KB, назві, severity...')<div class="table-scroll"><table id="table-pending-updates" class="data-table"><thead><tr><th>KB</th><th>Назва</th><th>Severity</th><th>Категорії</th><th>Завантажено</th><th>Size MB</th><th>Посилання</th></tr></thead><tbody>$updatesPendingRows</tbody></table></div></section>
    <section id="tab-hardware" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">🧠</span>Hardware</h2><div class="grid"><div class="card"><h3>CPU / RAM</h3>$(New-BravoInfoRowHtml 'CPU' $script:Report.Hardware.CPU.Name)$(New-BravoInfoRowHtml 'Cores / threads' "$($script:Report.Hardware.CPU.Cores)/$($script:Report.Hardware.CPU.LogicalProcessors)")<div class="info-row"><span class="info-label">CPU load</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$(Get-BravoSafePercentText $script:Report.Hardware.CPU.LoadPercent)%">$(Get-BravoSafePercentText $script:Report.Hardware.CPU.LoadPercent)%</div></div></span></div>$(New-BravoInfoRowHtml 'RAM total visible' "$($script:Report.Hardware.RAM.TotalVisibleMemoryGB) GB")$(New-BravoInfoRowHtml 'RAM used/free' "$($script:Report.Hardware.RAM.UsedGB) GB / $($script:Report.Hardware.RAM.FreeGB) GB")<div class="info-row"><span class="info-label">RAM used</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$(Get-BravoSafePercentText $script:Report.Hardware.RAM.UsedPercent)%">$(Get-BravoSafePercentText $script:Report.Hardware.RAM.UsedPercent)%</div></div></span></div></div><div class="card"><h3>Disk summary</h3>$(New-BravoInfoRowHtml 'Total' (Format-Size $script:Report.Hardware.Disks.TotalGB))$(New-BravoInfoRowHtml 'Free' (Format-Size $script:Report.Hardware.Disks.FreeGB))<div class="info-row"><span class="info-label">Free percent</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$(Get-BravoSafePercentText $script:Report.Hardware.Disks.FreePercent)%">$(Get-BravoSafePercentText $script:Report.Hardware.Disks.FreePercent)%</div></div></span></div></div><div class="card"><h3>System / Motherboard</h3>$(New-BravoInfoRowHtml 'Manufacturer' $script:Report.Hardware.ComputerSystem.Manufacturer)$(New-BravoInfoRowHtml 'Model' $script:Report.Hardware.ComputerSystem.Model)$(New-BravoInfoRowHtml 'Chassis type' $script:Report.Hardware.ComputerSystem.ChassisType)$(New-BravoInfoRowHtml 'Motherboard' "$($script:Report.Hardware.Motherboard.Manufacturer) $($script:Report.Hardware.Motherboard.Product)")$(New-BravoInfoRowHtml 'Motherboard version' $script:Report.Hardware.Motherboard.Version)</div></div><div class="storage-summary-grid"><div class="storage-summary-item"><div class="storage-summary-label">Critical volumes</div><div class="storage-summary-value"><span class="risk risk-critical">$criticalCount</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">Warning volumes</div><div class="storage-summary-value"><span class="risk risk-warning">$warningCount</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">System warnings</div><div class="storage-summary-value"><span class="risk risk-warning">$systemWarningCount</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">Healthy volumes</div><div class="storage-summary-value"><span class="risk risk-ok">$healthyCount</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">System-reserved (без літери)</div><div class="storage-summary-value"><span class="risk risk-unknown">$reservedCount</span></div></div></div><h3>Storage Critical Findings</h3>$(New-BravoTableToolbarHtml -TableId 'table-storage-critical' -Placeholder 'Пошук по storage findings...')<div class="table-scroll"><table id="table-storage-critical" class="data-table"><thead><tr><th>Том</th><th>Мітка</th><th>FS</th><th>Size GB</th><th>Free GB</th><th>Free %</th><th>Risk</th><th>Причина</th></tr></thead><tbody>$storageCriticalRows</tbody></table></div><h3>Storage Deep</h3>$(New-BravoTableToolbarHtml -TableId 'table-storage-deep' -Placeholder 'Пошук по дисках, FS, health, risk...')<div class="table-scroll"><table id="table-storage-deep" class="data-table"><thead><tr><th>Том</th><th>Мітка</th><th>FS</th><th>Тип</th><th>Health</th><th>Operational</th><th>Size GB</th><th>Free GB</th><th>Free %</th><th>Risk</th><th>Причина</th></tr></thead><tbody>$storageDeepRows</tbody></table></div><h3>BitLocker</h3>$(New-BravoTableToolbarHtml -TableId 'table-bitlocker' -Placeholder 'Пошук по томах, статусу захисту...')<div class="table-scroll"><table id="table-bitlocker" class="data-table"><thead><tr><th>Том</th><th>Тип</th><th>Volume Status</th><th>Protection</th><th>Encryption %</th><th>Method</th><th>Lock Status</th></tr></thead><tbody>$bitlockerRows</tbody></table></div><h3>Shadow Copies (VSS)</h3>$(New-BravoTableToolbarHtml -TableId 'table-shadowcopies' -Placeholder 'Пошук по точках відновлення...')<div class="table-scroll"><table id="table-shadowcopies" class="data-table"><thead><tr><th>Volume</th><th>Install Date</th><th>Client Accessible</th><th>Persistent</th></tr></thead><tbody>$shadowCopyRows</tbody></table></div><h3>Storage Spaces</h3>$(New-BravoTableToolbarHtml -TableId 'table-storagepools' -Placeholder 'Пошук по пулах...')<div class="table-scroll"><table id="table-storagepools" class="data-table"><thead><tr><th>Name</th><th>Health</th><th>Operational</th><th>Size GB</th><th>Allocated GB</th></tr></thead><tbody>$storagePoolRows</tbody></table></div><h3>SMART / Reliability Counters</h3>$(New-BravoTableToolbarHtml -TableId 'table-reliability' -Placeholder 'Пошук по дисках...')<div class="table-scroll"><table id="table-reliability" class="data-table"><thead><tr><th>Disk</th><th>Media</th><th>Temp °C</th><th>Wear</th><th>Uncorrected errors</th><th>Power-on hours</th></tr></thead><tbody>$reliabilityRows</tbody></table></div><h3>SMART Predictive Failure</h3>$(New-BravoTableToolbarHtml -TableId 'table-smartpredict' -Placeholder 'Пошук по дисках...')<div class="table-scroll"><table id="table-smartpredict" class="data-table"><thead><tr><th>Instance</th><th>Predict Failure</th><th>Reason</th></tr></thead><tbody>$smartPredictRows</tbody></table></div><h3>GPU</h3>$(New-BravoTableToolbarHtml -TableId 'table-gpu' -Placeholder 'Пошук по відеокартах...')<div class="table-scroll"><table id="table-gpu" class="data-table"><thead><tr><th>Name</th><th>VRAM</th><th>Driver</th><th>Resolution</th><th>Status</th></tr></thead><tbody>$gpuRows</tbody></table></div><h3>Monitors</h3>$(New-BravoTableToolbarHtml -TableId 'table-monitors' -Placeholder 'Пошук по моніторах...')<div class="table-scroll"><table id="table-monitors" class="data-table"><thead><tr><th>Manufacturer</th><th>Model</th><th>Active</th><th>Size</th><th>Year</th></tr></thead><tbody>$monitorRows</tbody></table></div></section>
    <section id="tab-network" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">🌐</span>Network</h2><div class="grid"><div class="card"><h3>Routing</h3>$(New-BravoInfoRowHtml 'Hostname' $script:Report.Network.General.Hostname)$(New-BravoInfoRowHtml 'Domain' $script:Report.Network.General.Domain)$(New-BravoInfoRowHtml 'IPv4' ((@($script:Report.Network.IP.IPv4) | Where-Object { $_ }) -join ', '))$(New-BravoInfoRowHtml 'Primary IPv4' $script:Report.Network.IP.PrimaryIPv4)$(New-BravoInfoRowHtml 'Gateway' ((@($script:Report.Network.Routing.DefaultGateways) | Where-Object { $_ }) -join ', '))$(New-BravoInfoRowHtml 'DNS' ((@($script:Report.Network.Routing.DNSServers) | Where-Object { $_ }) -join ', '))$(New-BravoInfoRowHtml 'Public IPv4 status' $publicIpv4StatusForReport)</div><div class="card"><h3>Connections</h3>$(New-BravoInfoRowHtml 'Established' $script:Report.Network.Connections.Established)$(New-BravoInfoRowHtml 'Listening' $script:Report.Network.Connections.Listening)$(New-BravoInfoRowHtml 'ISP / Organization' $script:Report.Network.IP.PublicIPv4ISP)$(New-BravoInfoRowHtml 'ASN' $script:Report.Network.IP.PublicIPv4ASN)$(New-BravoInfoRowHtml 'Location' $publicIpv4LocationForReport)$(New-BravoInfoRowHtml 'IP lookup provider' $script:Report.Network.IP.PublicIPv4Provider)$(New-BravoInfoRowHtml 'ISP lookup provider' $script:Report.Network.IP.PublicIPv4LookupProvider)$(New-BravoInfoRowHtml 'Checked at' $script:Report.Network.IP.PublicIPv4CheckedAt)</div></div><h3>Adapters</h3>$(New-BravoTableToolbarHtml -TableId 'table-network-adapters' -Placeholder 'Пошук по adapter, MAC, IPv4, gateway, DNS, driver...')<div class="table-scroll"><table id="table-network-adapters" class="data-table"><thead><tr><th>Description</th><th>MAC</th><th>IPv4</th><th>Gateway</th><th>DNS</th><th>DHCP</th><th>Link Speed</th><th>Status</th><th>Driver</th></tr></thead><tbody>$adapterRows</tbody></table></div><div class="grid"><div class="card"><h3>WinHTTP Proxy</h3>$(New-BravoInfoRowHtml 'Status' $script:Report.Network.WinHttpProxy.Status)$(New-BravoInfoRowHtml 'Details' $winHttpProxyText)</div></div><h3>Routing Table</h3>$(New-BravoTableToolbarHtml -TableId 'table-routing' -Placeholder 'Пошук по маршрутах...')<div class="table-scroll"><table id="table-routing" class="data-table"><thead><tr><th>Destination</th><th>Next Hop</th><th>Metric</th><th>Interface</th></tr></thead><tbody>$routingTableRows</tbody></table></div><h3>ARP Cache</h3>$(New-BravoTableToolbarHtml -TableId 'table-arp' -Placeholder 'Пошук по ARP-кешу...')<div class="table-scroll"><table id="table-arp" class="data-table"><thead><tr><th>IP Address</th><th>MAC Address</th><th>State</th><th>Interface</th></tr></thead><tbody>$arpRows</tbody></table></div><h3>Listening Ports</h3>$(New-BravoTableToolbarHtml -TableId 'table-listening' -Placeholder 'Пошук по портах...')<div class="table-scroll"><table id="table-listening" class="data-table"><thead><tr><th>Local Address</th><th>Port</th><th>PID</th><th>Process</th></tr></thead><tbody>$listeningPortRows</tbody></table></div><h3>Established Connections</h3>$(New-BravoTableToolbarHtml -TableId 'table-established' -Placeholder 'Пошук по з''єднаннях...')<div class="table-scroll"><table id="table-established" class="data-table"><thead><tr><th>Local Address</th><th>Local Port</th><th>Remote Address</th><th>Remote Port</th><th>PID</th><th>Process</th></tr></thead><tbody>$establishedConnectionRows</tbody></table></div><h3>SMB Shares</h3>$(New-BravoTableToolbarHtml -TableId 'table-smbshares' -Placeholder 'Пошук по shares...')<div class="table-scroll"><table id="table-smbshares" class="data-table"><thead><tr><th>Name</th><th>Path</th><th>Type</th><th>Administrative</th></tr></thead><tbody>$smbShareRows</tbody></table></div></section>
    <section id="tab-security" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">🔒</span>Security</h2><div class="grid"><div class="card"><h3>Security baseline</h3>$(New-BravoInfoRowHtml 'UAC' $(if($script:Report.Security.UAC.Enabled){'Ввімкнено'}else{'Вимкнено'}))$(New-BravoInfoRowHtml 'RDP' $(if($script:Report.Security.RemoteAccess.RDPEnabled){'Ввімкнено'}else{'Вимкнено'}))$(New-BravoInfoRowHtml 'Antivirus' $script:Report.Security.Antivirus.Product)$(New-BravoInfoRowHtml 'Local admins' $script:Report.Users.LocalAdmins.Count)</div><div class="card"><h3>UAC full policy</h3>$(New-BravoInfoRowHtml 'Admin prompt behavior' $script:Report.Security.UAC.ConsentPromptBehaviorAdminText)$(New-BravoInfoRowHtml 'User prompt behavior' $script:Report.Security.UAC.ConsentPromptBehaviorUserText)$(New-BravoInfoRowHtml 'Secure desktop prompt' $(if($null -eq $script:Report.Security.UAC.PromptOnSecureDesktop){'N/A'}elseif($script:Report.Security.UAC.PromptOnSecureDesktop){'Так'}else{'Ні'}))$(New-BravoInfoRowHtml 'Filter admin token' $(if($null -eq $script:Report.Security.UAC.FilterAdministratorToken){'N/A'}elseif($script:Report.Security.UAC.FilterAdministratorToken){'Так'}else{'Ні'}))</div><div class="card"><h3>Firewall</h3>$(New-BravoInfoRowHtml 'Profiles collected' $script:Report.Security.Firewall.Count)$(New-BravoInfoRowHtml 'Health status' $script:Report.Health.Status)$(New-BravoInfoRowHtml 'Findings' $script:Report.Health.Findings.Count)</div><div class="card"><h3>Secure Boot / TPM / SMBv1</h3>$(New-BravoInfoRowHtml 'Secure Boot' $script:Report.Security.SecureBoot.Status)$(New-BravoInfoRowHtml 'TPM' $script:Report.Security.TPM.Status)$(New-BravoInfoRowHtml 'TPM Ready' $(if($null -eq $script:Report.Security.TPM.Ready){'N/A'}elseif($script:Report.Security.TPM.Ready){'Так'}else{'Ні'}))$(New-BravoInfoRowHtml 'TPM Manufacturer' $script:Report.Security.TPM.ManufacturerId)$(New-BravoInfoRowHtml 'TPM Spec Version' $script:Report.Security.TPM.SpecVersion)$(New-BravoInfoRowHtml 'SMBv1' $script:Report.Security.SMBv1.Status)</div><div class="card"><h3>Windows Defender</h3>$(New-BravoInfoRowHtml 'Status' $script:Report.Security.Defender.Status)$(New-BravoInfoRowHtml 'Real-Time Protection' $(if($null -eq $script:Report.Security.Defender.RealTimeProtectionEnabled){'N/A'}elseif($script:Report.Security.Defender.RealTimeProtectionEnabled){'Увімкнено'}else{'Вимкнено'}))$(New-BravoInfoRowHtml 'Behavior Monitor' $(if($null -eq $script:Report.Security.Defender.BehaviorMonitorEnabled){'N/A'}elseif($script:Report.Security.Defender.BehaviorMonitorEnabled){'Увімкнено'}else{'Вимкнено'}))$(New-BravoInfoRowHtml 'Signature version' $script:Report.Security.Defender.AntivirusSignatureVersion)$(New-BravoInfoRowHtml 'Signature age, днів' $script:Report.Security.Defender.AntivirusSignatureAgeDays)$(New-BravoInfoRowHtml 'Engine version' $script:Report.Security.Defender.AMEngineVersion)</div><div class="card"><h3>RDP details</h3>$(New-BravoInfoRowHtml 'NLA required' $(if($null -eq $script:Report.Security.RemoteAccess.NLAEnabled){'N/A'}elseif($script:Report.Security.RemoteAccess.NLAEnabled){'Так'}else{'Ні'}))$(New-BravoInfoRowHtml 'Port' $script:Report.Security.RemoteAccess.Port)$(New-BravoInfoRowHtml 'Firewall scope' $script:Report.Security.RemoteAccess.FirewallScope)$(New-BravoInfoRowHtml 'Firewall profiles' $script:Report.Security.RemoteAccess.FirewallProfiles)$(New-BravoInfoRowHtml 'Allowed users' ((@($script:Report.Security.RemoteAccess.AllowedUsers) | Where-Object { $_ }) -join ', '))</div><div class="card"><h3>WinRM</h3>$(New-BravoInfoRowHtml 'Status' $script:Report.Security.WinRM.Status)$(New-BravoInfoRowHtml 'Service' $script:Report.Security.WinRM.ServiceStatus)$(New-BravoInfoRowHtml 'Basic auth' $(if($null -eq $script:Report.Security.WinRM.Auth.Basic){'N/A'}elseif($script:Report.Security.WinRM.Auth.Basic){'Увімкнено'}else{'Вимкнено'}))$(New-BravoInfoRowHtml 'CredSSP' $(if($null -eq $script:Report.Security.WinRM.Auth.CredSSP){'N/A'}elseif($script:Report.Security.WinRM.Auth.CredSSP){'Увімкнено'}else{'Вимкнено'}))$(New-BravoInfoRowHtml 'Listeners' $script:Report.Security.WinRM.Listeners.Count)</div><div class="card"><h3>SMB signing</h3>$(New-BravoInfoRowHtml 'Status' $script:Report.Security.SMB.Status)$(New-BravoInfoRowHtml 'Server signing required' $(if($null -eq $script:Report.Security.SMB.ServerSigningRequired){'N/A'}elseif($script:Report.Security.SMB.ServerSigningRequired){'Так'}else{'Ні'}))$(New-BravoInfoRowHtml 'Insecure guest logons' $(if($null -eq $script:Report.Security.SMB.InsecureGuestLogonsEnabled){'N/A'}elseif($script:Report.Security.SMB.InsecureGuestLogonsEnabled){'Увімкнено'}else{'Вимкнено'}))</div><div class="card"><h3>Password Policy</h3>$(New-BravoInfoRowHtml 'Min password length' $script:Report.Security.PasswordPolicy.MinPasswordLength)$(New-BravoInfoRowHtml 'Max password age, днів' $script:Report.Security.PasswordPolicy.MaxPasswordAgeDays)$(New-BravoInfoRowHtml 'Password history length' $script:Report.Security.PasswordPolicy.PasswordHistoryLength)$(New-BravoInfoRowHtml 'Lockout threshold' $script:Report.Security.PasswordPolicy.LockoutThreshold)$(New-BravoInfoRowHtml 'Lockout duration, хв' $script:Report.Security.PasswordPolicy.LockoutDurationMinutes)</div></div><h3>TLS registry status</h3>$(New-BravoTableToolbarHtml -TableId 'table-tls' -Placeholder 'Пошук по протоколах TLS...')<div class="table-scroll"><table id="table-tls" class="data-table"><thead><tr><th>Protocol</th><th>Side</th><th>Status</th></tr></thead><tbody>$tlsRows</tbody></table></div><h3>Audit Policy</h3>$(New-BravoTableToolbarHtml -TableId 'table-audit-policy' -Placeholder 'Пошук по категоріях audit policy...')<div class="table-scroll"><table id="table-audit-policy" class="data-table"><thead><tr><th>Category</th><th>Subcategory</th><th>Inclusion Setting</th></tr></thead><tbody>$auditPolicyRows</tbody></table></div><h3>Autoruns</h3>$(New-BravoTableToolbarHtml -TableId 'table-autoruns' -Placeholder 'Пошук по autorun-записах...')<div class="table-scroll"><table id="table-autoruns" class="data-table"><thead><tr><th>Name</th><th>Command</th><th>Source</th><th>Hive</th></tr></thead><tbody>$autorunRows</tbody></table></div><h3>Scheduled Tasks (не-Microsoft, $scheduledTaskMicrosoftCount вбудованих Microsoft-задач приховано)</h3>$(New-BravoTableToolbarHtml -TableId 'table-scheduledtasks' -Placeholder 'Пошук по задачах...')<div class="table-scroll"><table id="table-scheduledtasks" class="data-table"><thead><tr><th>Name</th><th>Path</th><th>State</th><th>Author</th><th>Execute</th></tr></thead><tbody>$scheduledTaskRows</tbody></table></div></section>
    <section id="tab-services" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">⚙️</span>Services</h2><div class="grid"><div class="card"><h3>Service summary</h3>$(New-BravoInfoRowHtml 'Processes' $script:Report.Processes.Total)$(New-BravoInfoRowHtml 'Services running' "$($script:Report.Services.Running)/$($script:Report.Services.Total)")$(New-BravoInfoRowHtml 'Automatic stopped' $script:Report.Services.AutomaticStopped.Count)$(New-BravoInfoRowHtml "System errors ($EventLogDays дн.)" $script:Report.EventLogs.SystemErrors)$(New-BravoInfoRowHtml "System warnings ($EventLogDays дн.)" $script:Report.EventLogs.SystemWarnings)</div></div><h3>Automatic stopped services</h3>$(New-BravoTableToolbarHtml -TableId 'table-services-stopped' -Placeholder 'Пошук по службах...')<div class="table-scroll"><table id="table-services-stopped" class="data-table"><thead><tr><th>Name</th><th>DisplayName</th><th>StartType</th><th>Status</th></tr></thead><tbody>$serviceRows</tbody></table></div><h3>Топ джерел помилок System log ($EventLogDays дн.)</h3>$(New-BravoTableToolbarHtml -TableId 'table-events-top-sources' -Placeholder 'Пошук по джерелах помилок...')<div class="table-scroll"><table id="table-events-top-sources" class="data-table"><thead><tr><th>Source</th><th>Count</th><th>Останнє повідомлення</th></tr></thead><tbody>$eventTopErrorRows</tbody></table></div><h3>Event Logs: System / Application / Setup / Security ($EventLogDays дн.)</h3>$(New-BravoTableToolbarHtml -TableId 'table-events-logsummary' -Placeholder 'Пошук по журналах...')<div class="table-scroll"><table id="table-events-logsummary" class="data-table"><thead><tr><th>Log</th><th>Status</th><th>Critical</th><th>Error</th><th>Warning</th></tr></thead><tbody>$eventLogSummaryRows</tbody></table></div><h3>Provider Summary (Critical/Error/Warning)</h3>$(New-BravoTableToolbarHtml -TableId 'table-events-providers' -Placeholder 'Пошук по провайдерах...')<div class="table-scroll"><table id="table-events-providers" class="data-table"><thead><tr><th>Log</th><th>Provider</th><th>Count</th><th>Останнє повідомлення</th></tr></thead><tbody>$eventLogProviderRows</tbody></table></div><h3>Hardware Diagnostics (Disk/Ntfs/StorPort/StorNVMe/WHEA/Kernel-Power/BugCheck)</h3>$(New-BravoTableToolbarHtml -TableId 'table-events-hwdiag' -Placeholder 'Пошук по провайдерах...')<div class="table-scroll"><table id="table-events-hwdiag" class="data-table"><thead><tr><th>Provider</th><th>Status</th><th>Count</th><th>Останнє повідомлення</th></tr></thead><tbody>$hardwareDiagnosticRows</tbody></table></div></section>
    <section id="tab-software" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">📦</span>Software</h2><div class="grid"><div class="card"><h3>Software summary</h3>$(New-BravoInfoRowHtml 'Installed software' $script:Report.Software.Installed.Count)$(New-BravoInfoRowHtml 'Profile' $Profile)</div></div><h3>Installed software</h3>$(New-BravoTableToolbarHtml -TableId 'table-software-installed' -Placeholder 'Пошук по назві, версії або видавцю...')<div class="table-scroll"><table id="table-software-installed" class="data-table"><thead><tr><th>Name</th><th>Version</th><th>Publisher</th><th>Install date</th></tr></thead><tbody>$softwareRows</tbody></table></div></section>
    <section id="tab-updates" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">🔄</span>Updates</h2><div class="grid"><div class="card"><h3>Життєвий цикл ОС</h3>$(New-BravoInfoRowHtml 'Продукт' $script:Report.Updates.OS.Product)$(New-BravoInfoRowHtml 'Версія' $script:Report.Updates.OS.DisplayVersion)$(New-BravoInfoRowHtml 'Версія з реєстру' $script:Report.Updates.OS.RegistryDisplayVersion)$(New-BravoInfoRowHtml 'Full build' $script:Report.Updates.OS.FullBuild)$(New-BravoInfoRowHtml 'Канал' $script:Report.Updates.OS.Channel)$(New-BravoInfoRowHtml 'EditionID' $script:Report.Updates.OS.EditionId)$(New-BravoInfoRowHtml 'Кінець підтримки' $script:Report.Updates.OS.SupportEndDate)$(New-BravoInfoRowHtml 'Днів до кінця підтримки' $script:Report.Updates.OS.DaysToEndOfSupport)<div class="info-row"><span class="info-label">Статус підтримки</span><span class="info-value"><span class="status-pill $updatesSupportStatusClass">$(ConvertTo-BravoHtmlText $updatesSupportStatusText)</span></span></div>$(New-BravoInfoRowHtml 'Дані lifecycle від' $script:Report.Updates.OS.LifecycleDataUpdatedAt)</div><div class="card"><h3>Windows Update</h3>$(New-BravoInfoRowHtml 'Служба wuauserv' $script:Report.Updates.WindowsUpdate.ServiceStatus)$(New-BravoInfoRowHtml 'Тип запуску' $script:Report.Updates.WindowsUpdate.ServiceStartType)$(New-BravoInfoRowHtml 'Політика оновлень' $script:Report.Updates.WindowsUpdate.AutoUpdateOption)$(New-BravoInfoRowHtml 'WSUS' $(if($script:Report.Updates.WindowsUpdate.ManagedByWSUS){$script:Report.Updates.WindowsUpdate.WSUSServer}else{'Ні'}))$(New-BravoInfoRowHtml 'Останній пошук' $script:Report.Updates.WindowsUpdate.LastDetectSuccess)$(New-BravoInfoRowHtml 'Остання установка' $script:Report.Updates.WindowsUpdate.LastInstallSuccess)$(New-BravoInfoRowHtml 'Потрібне перезавантаження' $pendingRebootText)$(New-BravoInfoRowHtml 'Статус пошуку' $updatesSearchStatusText)$(New-BravoInfoRowHtml 'Тривалість пошуку, сек' $script:Report.Updates.Search.DurationSeconds)</div></div><div class="storage-summary-grid"><div class="storage-summary-item"><div class="storage-summary-label">Потрібно встановити</div><div class="storage-summary-value">$($script:Report.Updates.Pending.Total)$(if($script:Report.Updates.Pending.IsTruncated){" <span class=`"risk risk-warning`">детально: $($script:Report.Updates.Pending.Detailed)</span>"})</div></div><div class="storage-summary-item"><div class="storage-summary-label">Security</div><div class="storage-summary-value"><span class="risk risk-critical">$($script:Report.Updates.Pending.Security)</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">Драйвери</div><div class="storage-summary-value"><span class="risk risk-warning">$($script:Report.Updates.Pending.Driver)</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">Завантажено</div><div class="storage-summary-value"><span class="risk risk-ok">$($script:Report.Updates.Pending.Downloaded)</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">Обсяг, MB</div><div class="storage-summary-value">$($script:Report.Updates.Pending.TotalSizeMB)</div></div><div class="storage-summary-item"><div class="storage-summary-label">Встановлено оновлень</div><div class="storage-summary-value">$($script:Report.Updates.Installed.Total)</div></div></div><h3>Оновлення, які потрібно встановити</h3>$(New-BravoTableToolbarHtml -TableId 'table-updates-pending' -Placeholder 'Пошук по назві, KB, категорії...')<div class="table-scroll"><table id="table-updates-pending" class="data-table"><thead><tr><th>Title</th><th>KB</th><th>Categories</th><th>Severity</th><th>Size MB</th><th>Downloaded</th><th>Released</th></tr></thead><tbody>$pendingUpdatesRows</tbody></table></div><h3>Останні встановлені оновлення</h3>$(New-BravoTableToolbarHtml -TableId 'table-updates-installed' -Placeholder 'Пошук по KB, опису, користувачу...')<div class="table-scroll"><table id="table-updates-installed" class="data-table"><thead><tr><th>HotFixID</th><th>Description</th><th>Installed by</th><th>Installed on</th></tr></thead><tbody>$installedUpdatesRows</tbody></table></div></section>
    <section id="tab-findings" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">🔎</span>Findings</h2><div class="storage-summary-grid"><div class="storage-summary-item"><div class="storage-summary-label">Critical</div><div class="storage-summary-value"><span class="risk risk-critical">$($findingsGrouped.CriticalCount)</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">Warning</div><div class="storage-summary-value"><span class="risk risk-warning">$($findingsGrouped.WarningCount)</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">Info</div><div class="storage-summary-value"><span class="risk risk-unknown">$($findingsGrouped.InfoCount)</span></div></div></div>$(New-BravoTableToolbarHtml -TableId 'table-findings' -Placeholder 'Пошук по severity, category, message...')<div class="table-scroll"><table id="table-findings" class="data-table"><thead><tr><th>Severity</th><th>Category</th><th>Message</th><th>Recommendation</th></tr></thead><tbody>$findingsRows</tbody></table></div><h2 class="tab-panel-title"><span class="section-icon">🛠️</span>Помилки збору даних</h2>$(New-BravoTableToolbarHtml -TableId 'table-collection-errors' -Placeholder 'Пошук по помилках збору...')<div class="table-scroll"><table id="table-collection-errors" class="data-table"><thead><tr><th>Time</th><th>Section</th><th>Message</th></tr></thead><tbody>$errorsRows</tbody></table></div></section>
  </main>
  <footer class="footer"><p>BRAVO SYSTEM REPORT v$ScriptVersion | $(ConvertTo-BravoHtmlText $OutputDir)</p></footer>
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
  // Dark mode: :root[data-theme] override CSS-змінних, дефолт — prefers-color-scheme
  // (system-рівень, без явного вибору). Вибір користувача зберігається через
  // localStorage — на file:// протоколі деякі браузери обмежують доступ до
  // localStorage (throws SecurityError), тому обгорнуто в try/catch: тема все
  // одно перемикається в межах поточної сесії перегляду, лише не зберігається
  // між відкриттями файлу.
  function getStoredTheme(){
    try { return window.localStorage.getItem('bravo-theme'); } catch(e) { return null; }
  }
  function setStoredTheme(value){
    try { window.localStorage.setItem('bravo-theme', value); } catch(e) { /* file:// або приватний режим — не критично */ }
  }
  function updateThemeToggleIcon(theme){
    var toggleButton = document.getElementById('theme-toggle');
    if(!toggleButton){ return; }
    var isDark = theme === 'dark' || (!theme && window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches);
    toggleButton.textContent = isDark ? '☀️' : '🌙';
  }
  function applyTheme(theme){
    if(theme === 'dark' || theme === 'light'){
      document.documentElement.setAttribute('data-theme', theme);
    } else {
      document.documentElement.removeAttribute('data-theme');
    }
    updateThemeToggleIcon(theme);
  }
  window.toggleTheme = function(){
    var current = document.documentElement.getAttribute('data-theme');
    var systemPrefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
    var currentlyDark = current === 'dark' || (!current && systemPrefersDark);
    var next = currentlyDark ? 'light' : 'dark';
    applyTheme(next);
    setStoredTheme(next);
  };
  function initTheme(){
    applyTheme(getStoredTheme());
  }
  if(document.readyState === 'loading'){
    document.addEventListener('DOMContentLoaded', function(){ initializeTableFilters(); activateInitialTab(); initTheme(); });
  } else {
    initializeTableFilters();
    activateInitialTab();
    initTheme();
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
            Add-ExportError -Section 'Export.Html' -Message $_.Exception.Message
            Write-Host "  $IconError Помилка HTML: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Чиста-по-суті функція локалізації msedge.exe: спершу PATH (Get-Command),
# потім два стандартних шляхи встановлення (64-bit і 32-bit under
# Program Files (x86) — Edge типово встановлюється як 32-bit застосунок
# навіть на 64-bit Windows). Повертає $null, якщо Edge не знайдено —
# виклик далі трактує це як штатну відсутність опційної залежності, не
# помилку.
function Get-BravoEdgeExecutablePath {
    [CmdletBinding()]
    param()

    $pathCommand = Get-Command msedge.exe -ErrorAction SilentlyContinue
    $candidates = @(
        if ($pathCommand) { $pathCommand.Source }
        'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
        'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }

    return $null
}

# v0.6.1 Advanced UX: автоматична конвертація HTML-звіту в PDF через
# headless Microsoft Edge (`--print-to-pdf`). Опційна фіча (-ExportPdf) —
# відсутність Edge на машині НЕ є помилкою збору чи експорту (лише
# Write-Host Warning), оскільки PDF не є обов'язковим форматом звіту.
function Export-BravoPdfReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputDir,
        [Parameter(Mandatory = $true)]
        [string]$BaseFileName
    )

    $htmlPath = Join-Path $OutputDir "$BaseFileName.html"
    if (-not (Test-Path -LiteralPath $htmlPath)) {
        # Нема з чого конвертувати (HTML не створено/помилка HTML-етапу) —
        # той HTML-етап уже зафіксував власну ExportError, тут дублювати
        # не потрібно.
        return
    }

    $edgePath = Get-BravoEdgeExecutablePath
    if (-not $edgePath) {
        Write-Host "  [INFO] Edge CLI PDF: msedge.exe не знайдено на цій машині — PDF пропущено (не помилка, опційна фіча)." -ForegroundColor Yellow
        return
    }

    try {
        $pdfPath = Join-Path $OutputDir "$BaseFileName.pdf"
        $htmlUri = ([Uri]$htmlPath).AbsoluteUri
        $edgeArguments = @(
            '--headless'
            '--disable-gpu'
            "--print-to-pdf=`"$pdfPath`""
            '--print-to-pdf-no-header'
            $htmlUri
        )

        $process = Start-Process -FilePath $edgePath -ArgumentList $edgeArguments -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop

        if ($process.ExitCode -eq 0 -and (Test-Path -LiteralPath $pdfPath)) {
            $script:Report.GeneratedFiles += $pdfPath
            Write-Host "  $IconHtml PDF: $BaseFileName.pdf" -ForegroundColor White
        } else {
            Add-ExportError -Section 'Export.Pdf' -Message "msedge.exe --print-to-pdf завершився з exit code $($process.ExitCode), PDF-файл не з'явився."
        }
    } catch {
        Add-ExportError -Section 'Export.Pdf' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка PDF: $($_.Exception.Message)" -ForegroundColor Red
    }
}
