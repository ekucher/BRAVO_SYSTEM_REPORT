# MODULE: 40-Health.ps1
# Розрахунок підсумкової оцінки стану машини.

# Чиста функція: сортує findings за severity (CRITICAL -> WARNING -> INFO ->
# невідомий severity в кінець), потім за Category — і рахує підсумкові
# лічильники по severity. Використовується і HTML-звітом (вкладка Findings),
# і TXT/Markdown summary (v0.6.0 Reports and UX) — єдина точка групування,
# щоб усі формати показували ту саму сортовану/згруповану картину.
function Get-BravoFindingsGrouped {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        $Findings
    )

    $severityOrder = @{ CRITICAL = 0; WARNING = 1; INFO = 2 }

    $sorted = @($Findings) | Sort-Object -Property `
        @{ Expression = { if ($severityOrder.ContainsKey($_.Severity)) { $severityOrder[$_.Severity] } else { 99 } } }, `
        @{ Expression = { [string]$_.Category } }

    return [PSCustomObject]@{
        Sorted        = $sorted
        CriticalCount = @($sorted | Where-Object { $_.Severity -eq 'CRITICAL' }).Count
        WarningCount  = @($sorted | Where-Object { $_.Severity -eq 'WARNING' }).Count
        InfoCount     = @($sorted | Where-Object { $_.Severity -eq 'INFO' }).Count
    }
}

function Update-BravoHealthScore {
    [CmdletBinding()]
    param()

    # --- Health score ---
    try {
        $criticalCount = @($script:Report.Health.Findings | Where-Object { $_.Severity -eq 'CRITICAL' }).Count
        $warningCount = @($script:Report.Health.Findings | Where-Object { $_.Severity -eq 'WARNING' }).Count
        $errorCount = @($script:Report.CollectionErrors).Count

        $score = 100 - ($criticalCount * 20) - ($warningCount * 7) - [Math]::Min($errorCount * 2, 20)
        if ($score -lt 0) { $score = 0 }

        $status = if ($criticalCount -gt 0) { 'CRITICAL' } elseif ($warningCount -gt 0 -or $errorCount -gt 0) { 'WARNING' } else { 'OK' }
        $statusReason = "critical=$criticalCount; warning=$warningCount; collectionErrors=$errorCount"

        $script:Report.Health.Score = $score
        $script:Report.Health.Status = $status
        $script:Report.Status = $status
        $script:Report.StatusReason = $statusReason

        if ($script:Report.Dashboard) {
            $script:Report.Dashboard.Header.Status = $status
            $script:Report.Dashboard.Header.StatusReason = $statusReason
            $script:Report.Dashboard.Header.GeneratedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

            if ($script:Report.Hardware -and $script:Report.Hardware.Disks) {
                # Статус dashboard-плитки рахуємо по НАЙГІРШОМУ тому (тим самим
                # централізованим порогом Get-BravoStorageThresholds, що й
                # per-volume findings у 32-Collectors-Storage.ps1 — P1), а не по
                # агрегованому FreePercent по всіх дисках разом. Інакше один
                # майже заповнений диск ховається за великим вільним місцем на
                # інших, і dashboard показує "OK" одночасно з CRITICAL-знахідкою
                # для того самого тому.
                $storageThresholds = Get-BravoStorageThresholds
                $volumeFreePercents = @($script:Report.Hardware.Disks.Volumes | Where-Object { $null -ne $_.FreePercent } | ForEach-Object { $_.FreePercent })
                $worstFreePercent = if ($volumeFreePercents.Count -gt 0) { ($volumeFreePercents | Measure-Object -Minimum).Minimum } else { $script:Report.Hardware.Disks.FreePercent }

                $diskStatus = if ($worstFreePercent -lt $storageThresholds.CriticalFreePercent) { 'CRITICAL' } elseif ($worstFreePercent -lt $storageThresholds.WarningFreePercent) { 'WARNING' } else { 'OK' }
                $script:Report.Dashboard.Metrics.Disk.Value = "$($script:Report.Hardware.Disks.FreePercent)% free"
                $script:Report.Dashboard.Metrics.Disk.Details = "$($script:Report.Hardware.Disks.FreeGB) GB free з $($script:Report.Hardware.Disks.TotalGB) GB"
                $script:Report.Dashboard.Metrics.Disk.Status = $diskStatus
            }
        }
    } catch {
        Add-AuditError -Section 'HealthScore' -Message $_.Exception.Message
    }

    Write-Host ''
    Write-Host "$IconDone Збір даних завершено! Оцінка стану: $($script:Report.Health.Score)/100 ($($script:Report.Health.Status))" -ForegroundColor Green
}