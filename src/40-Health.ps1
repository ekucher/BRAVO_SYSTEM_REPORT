# MODULE: 40-Health.ps1
# Розрахунок підсумкової оцінки стану машини.

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
                # порогом 10/20%, що й per-volume findings у 32-Collectors-Storage.ps1),
                # а не по агрегованому FreePercent по всіх дисках разом. Інакше
                # один майже заповнений диск ховається за великим вільним місцем
                # на інших, і dashboard показує "OK" одночасно з CRITICAL-знахідкою
                # для того самого тому.
                $volumeFreePercents = @($script:Report.Hardware.Disks.Volumes | Where-Object { $null -ne $_.FreePercent } | ForEach-Object { $_.FreePercent })
                $worstFreePercent = if ($volumeFreePercents.Count -gt 0) { ($volumeFreePercents | Measure-Object -Minimum).Minimum } else { $script:Report.Hardware.Disks.FreePercent }

                $diskStatus = if ($worstFreePercent -lt 10) { 'CRITICAL' } elseif ($worstFreePercent -lt 20) { 'WARNING' } else { 'OK' }
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