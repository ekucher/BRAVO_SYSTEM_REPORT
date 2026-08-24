# MODULE: 37-Collectors-Events.ps1
# Збір інформації про журнали подій Windows.

function Get-BravoEventLogsAudit {
    [CmdletBinding()]
    param()

    # --- Журнали подій ---
    try {
        $lastDay = (Get-Date).AddDays(-1)
        $eventLogStart = (Get-Date).AddDays(-1 * $EventLogDays)

        $systemErrors24h = Get-EventLog -LogName System -EntryType Error -After $lastDay -ErrorAction SilentlyContinue
        $systemWarnings24h = Get-EventLog -LogName System -EntryType Warning -After $lastDay -ErrorAction SilentlyContinue
        $systemErrors = Get-EventLog -LogName System -EntryType Error -After $eventLogStart -ErrorAction SilentlyContinue
        $systemWarnings = Get-EventLog -LogName System -EntryType Warning -After $eventLogStart -ErrorAction SilentlyContinue

        $script:Report.EventLogs.SystemErrors24h = @($systemErrors24h).Count
        $script:Report.EventLogs.SystemWarnings24h = @($systemWarnings24h).Count
        $script:Report.EventLogs.SystemErrors = @($systemErrors).Count
        $script:Report.EventLogs.SystemWarnings = @($systemWarnings).Count

        # Топ джерел помилок — щоб знахідка була дієвою, а не просто цифрою.
        $topErrorSources = @(
            $systemErrors |
                Group-Object -Property Source |
                Sort-Object -Property Count -Descending |
                Select-Object -First 10 -Property @{Name='Source'; Expression={$_.Name}}, Count, @{Name='LastMessage'; Expression={($_.Group | Select-Object -First 1).Message}}
        )
        $script:Report.EventLogs.TopErrorSources = $topErrorSources

        if ($script:Report.EventLogs.SystemErrors -gt 0) {
            $topSourcesText = ($topErrorSources | Select-Object -First 3 | ForEach-Object { "$($_.Source) ($($_.Count))" }) -join ', '
            $topSourcesNote = if ($topSourcesText) { " Топ джерел: $topSourcesText." } else { '' }
            Add-AuditFinding -Severity 'WARNING' -Category 'EventLogs' -Message "За $EventLogDays днів знайдено системних помилок: $($script:Report.EventLogs.SystemErrors).$topSourcesNote" -Recommendation 'Перегляньте System log і визначте повторювані джерела помилок.'
        }

        Write-Host "  $IconEvent Події System: помилок=$($script:Report.EventLogs.SystemErrors), попереджень=$($script:Report.EventLogs.SystemWarnings) за $EventLogDays дн." -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'EventLogs' -Message $_.Exception.Message
    }
}
