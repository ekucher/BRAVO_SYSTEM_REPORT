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

        $script:Report.Health.Score = $score
        $script:Report.Health.Status = if ($criticalCount -gt 0) { 'CRITICAL' } elseif ($warningCount -gt 0 -or $errorCount -gt 0) { 'WARNING' } else { 'OK' }
    } catch {
        Add-AuditError -Section 'HealthScore' -Message $_.Exception.Message
    }

    Write-Host ''
    Write-Host "$IconDone Збір даних завершено! Оцінка стану: $($script:Report.Health.Score)/100 ($($script:Report.Health.Status))" -ForegroundColor Green
}
