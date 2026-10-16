# MODULE: 37-Collectors-Events.ps1
# Збір інформації про журнали подій Windows.

function Get-BravoWinEventCount {
    # Get-WinEvent -FilterHashtable виконує запит на рівні Win32 Event Log API
    # (індексований пошук по EVTX), тож на великому System log він у рази
    # швидший за застарілий Get-EventLog, який послідовно перебирає записи.
    # "Нуль відповідних подій" у Get-WinEvent — це не збій, а окрема
    # нетерміновна помилка з FullyQualifiedErrorId NoMatchingEventsFound;
    # її явно відрізняємо від реального збою (журнал недоступний тощо),
    # щоб не повторити помилку "справжня помилка ковтається мовчки".
    param(
        [Parameter(Mandatory)][string]$LogName,
        [Parameter(Mandatory)][int[]]$Level,
        [Parameter(Mandatory)][datetime]$StartTime
    )

    try {
        return @(Get-WinEvent -FilterHashtable @{ LogName = $LogName; Level = $Level; StartTime = $StartTime } -ErrorAction Stop).Count
    } catch {
        if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound,*') {
            return 0
        }
        throw
    }
}

function Get-BravoEventLogsAudit {
    [CmdletBinding()]
    param()

    # --- Журнали подій ---
    # Кожен запит до журналу виконується з власним try/catch: збій одного
    # запиту (журнал недоступний, відмовлено в доступі тощо) фіксується через
    # Add-AuditError, а не "ковтається" мовчки, і не блокує виконання решти
    # запитів цієї функції.
    $lastDay = (Get-Date).AddDays(-1)
    $eventLogStart = (Get-Date).AddDays(-1 * $EventLogDays)

    $systemErrors24h = 0
    $systemWarnings24h = 0
    $systemErrors = 0
    $systemWarnings = 0

    try {
        $systemErrors24h = Get-BravoWinEventCount -LogName 'System' -Level 2 -StartTime $lastDay
    } catch {
        Add-AuditError -Section 'EventLogs' -Message "SystemErrors24h: $($_.Exception.Message)"
    }

    try {
        $systemWarnings24h = Get-BravoWinEventCount -LogName 'System' -Level 3 -StartTime $lastDay
    } catch {
        Add-AuditError -Section 'EventLogs' -Message "SystemWarnings24h: $($_.Exception.Message)"
    }

    try {
        $systemErrors = Get-BravoWinEventCount -LogName 'System' -Level 2 -StartTime $eventLogStart
    } catch {
        Add-AuditError -Section 'EventLogs' -Message "SystemErrors: $($_.Exception.Message)"
    }

    try {
        $systemWarnings = Get-BravoWinEventCount -LogName 'System' -Level 3 -StartTime $eventLogStart
    } catch {
        Add-AuditError -Section 'EventLogs' -Message "SystemWarnings: $($_.Exception.Message)"
    }

    $script:Report.EventLogs.SystemErrors24h = $systemErrors24h
    $script:Report.EventLogs.SystemWarnings24h = $systemWarnings24h
    $script:Report.EventLogs.SystemErrors = $systemErrors
    $script:Report.EventLogs.SystemWarnings = $systemWarnings

    if ($script:Report.EventLogs.SystemErrors -gt 0) {
        Add-AuditFinding -Severity 'WARNING' -Category 'EventLogs' -Message "За $EventLogDays днів знайдено системних помилок: $($script:Report.EventLogs.SystemErrors)." -Recommendation 'Перегляньте System log і визначте повторювані джерела помилок.'
    }

    Write-Host "  $IconEvent Події System: помилок=$($script:Report.EventLogs.SystemErrors), попереджень=$($script:Report.EventLogs.SystemWarnings) за $EventLogDays дн." -ForegroundColor Green
}
