# MODULE: 30-Collectors-OS.ps1
# Збір інформації про операційну систему.

function Get-BravoOperatingSystemAudit {
    [CmdletBinding()]
    param()

    # --- ОС ---
    try {
        $osInfo = Get-AuditObject -ClassName 'Win32_OperatingSystem' -First
        $script:Report.OS.Caption = $osInfo.Caption
        $script:Report.OS.Version = $osInfo.Version
        $script:Report.OS.Build = $osInfo.BuildNumber
        $script:Report.OS.Architecture = $osInfo.OSArchitecture

        $installDate = Convert-AuditDateTime -Value $osInfo.InstallDate -UseCim:$script:UseCim
        if ($installDate) { $script:Report.OS.InstallDate = $installDate.ToString('yyyy-MM-dd') }

        $lastBoot = Convert-AuditDateTime -Value $osInfo.LastBootUpTime -UseCim:$script:UseCim
        if ($lastBoot) {
            $uptime = (Get-Date) - $lastBoot
            $script:Report.OS.LastBootUpTime = $lastBoot.ToString('yyyy-MM-dd HH:mm:ss')
            $script:Report.OS.UptimeDays = $uptime.Days
            $script:Report.OS.UptimeHours = [Math]::Round($uptime.TotalHours, 1)
            $script:Report.Dashboard.Header.UptimeText = "$($script:Report.OS.UptimeDays) дн. / $($script:Report.OS.UptimeHours) год."
        }

        $script:Report.Dashboard.Metrics.OS.Value = $script:Report.OS.Caption
        $script:Report.Dashboard.Metrics.OS.Details = "Build $($script:Report.OS.Build), $($script:Report.OS.Architecture)"
        $script:Report.Dashboard.Metrics.OS.Status = 'OK'

        if ($script:Report.OS.UptimeDays -gt 90) {
            Add-AuditFinding -Severity 'WARNING' -Category 'OS' -Message "Uptime більше 90 днів: $($script:Report.OS.UptimeDays)" -Recommendation 'Заплануйте контрольоване перезавантаження після перевірки критичних служб.'
            $script:Report.Dashboard.Metrics.OS.Status = 'WARNING'
        }

        Write-Host "  $IconOk ОС: $($script:Report.OS.Caption)" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'OS' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка збору даних ОС: $($_.Exception.Message)" -ForegroundColor Red
    }
}