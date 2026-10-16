# MODULE: 37-Collectors-Events.ps1
# Збір інформації про журнали подій Windows.

function Get-BravoEventLogsAudit {
    [CmdletBinding()]
    param()

    # --- Журнали подій ---
    # Кожен запит до журналу виконується з -ErrorAction Stop і власним try/catch:
    # збій одного запиту (журнал недоступний, відмовлено в доступі тощо) фіксується
    # через Add-AuditError, а не "ковтається" -ErrorAction SilentlyContinue мовчки,
    # і не блокує виконання решти запитів цієї функції.
    $lastDay = (Get-Date).AddDays(-1)
    $eventLogStart = (Get-Date).AddDays(-1 * $EventLogDays)

    $systemErrors24h = @()
    $systemWarnings24h = @()
    $systemErrors = @()
    $systemWarnings = @()

    try {
        $systemErrors24h = @(Get-EventLog -LogName System -EntryType Error -After $lastDay -ErrorAction Stop)
    } catch {
        Add-AuditError -Section 'EventLogs' -Message "SystemErrors24h: $($_.Exception.Message)"
    }

    try {
        $systemWarnings24h = @(Get-EventLog -LogName System -EntryType Warning -After $lastDay -ErrorAction Stop)
    } catch {
        Add-AuditError -Section 'EventLogs' -Message "SystemWarnings24h: $($_.Exception.Message)"
    }

    try {
        $systemErrors = @(Get-EventLog -LogName System -EntryType Error -After $eventLogStart -ErrorAction Stop)
    } catch {
        Add-AuditError -Section 'EventLogs' -Message "SystemErrors: $($_.Exception.Message)"
    }

    try {
        $systemWarnings = @(Get-EventLog -LogName System -EntryType Warning -After $eventLogStart -ErrorAction Stop)
    } catch {
        Add-AuditError -Section 'EventLogs' -Message "SystemWarnings: $($_.Exception.Message)"
    }

    $script:Report.EventLogs.SystemErrors24h = $systemErrors24h.Count
    $script:Report.EventLogs.SystemWarnings24h = $systemWarnings24h.Count
    $script:Report.EventLogs.SystemErrors = $systemErrors.Count
    $script:Report.EventLogs.SystemWarnings = $systemWarnings.Count

    if ($script:Report.EventLogs.SystemErrors -gt 0) {
        Add-AuditFinding -Severity 'WARNING' -Category 'EventLogs' -Message "За $EventLogDays днів знайдено системних помилок: $($script:Report.EventLogs.SystemErrors)." -Recommendation 'Перегляньте System log і визначте повторювані джерела помилок.'
    }

    Write-Host "  $IconEvent Події System: помилок=$($script:Report.EventLogs.SystemErrors), попереджень=$($script:Report.EventLogs.SystemWarnings) за $EventLogDays дн." -ForegroundColor Green
}
