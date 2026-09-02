# MODULE: 37-Collectors-Events.ps1
# Збір інформації про журнали подій Windows.

# Чиста функція без побічних ефектів: групує вже отримані Get-WinEvent
# записи (об'єкти з полями LevelDisplayName/ProviderName/Message) в
# Critical/Error/Warning-лічильники й топ-10 провайдерів. Винесено окремо
# від I/O (Get-WinEvent), щоб покрити unit-тестами без реального журналу
# подій.
function ConvertTo-BravoEventLogSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [array]$Events
    )

    $events = @($Events)

    $criticalCount = @($events | Where-Object { $_.LevelDisplayName -eq 'Critical' }).Count
    $errorCount    = @($events | Where-Object { $_.LevelDisplayName -eq 'Error' }).Count
    $warningCount  = @($events | Where-Object { $_.LevelDisplayName -eq 'Warning' }).Count

    $topProviders = @(
        $events |
            Group-Object -Property ProviderName |
            Sort-Object -Property Count -Descending |
            Select-Object -First 10 -Property @{Name='ProviderName'; Expression={$_.Name}}, Count, @{Name='LastMessage'; Expression={($_.Group | Select-Object -First 1).Message}}
    )

    return [PSCustomObject]@{
        CriticalCount = $criticalCount
        ErrorCount    = $errorCount
        WarningCount  = $warningCount
        TopProviders  = $topProviders
    }
}

function Get-BravoEventLogsAudit {
    [CmdletBinding()]
    param()

    # --- Журнали подій ---
    try {
        $lastDay = (Get-Date).AddDays(-1)
        $eventLogStart = (Get-Date).AddDays(-1 * $EventLogDays)

        # -ErrorAction SilentlyContinue сам собою нічого не пише в CollectionErrors.
        # "No matches found" — очікуваний benign-результат, коли за період справді
        # немає жодного запису (не помилка збору). Будь-яка ІНША помилка
        # (лог очищено/недоступний, немає прав) реєструється явно, щоб
        # SystemErrors=0 не видавали себе за "перевірено й чисто", коли збір
        # насправді провалився.
        $eventLogErrors = @()
        $systemErrors24h = Get-EventLog -LogName System -EntryType Error -After $lastDay -ErrorAction SilentlyContinue -ErrorVariable +eventLogErrors
        $systemWarnings24h = Get-EventLog -LogName System -EntryType Warning -After $lastDay -ErrorAction SilentlyContinue -ErrorVariable +eventLogErrors
        $systemErrors = Get-EventLog -LogName System -EntryType Error -After $eventLogStart -ErrorAction SilentlyContinue -ErrorVariable +eventLogErrors
        $systemWarnings = Get-EventLog -LogName System -EntryType Warning -After $eventLogStart -ErrorAction SilentlyContinue -ErrorVariable +eventLogErrors

        # Звіряємо FullyQualifiedErrorId, а не текст Exception.Message: повідомлення
        # локалізується разом з MUI-пакетом Windows (напр. на uk-UA/ru-UA системах
        # текст буде не англійським), тоді як FullyQualifiedErrorId — стабільний
        # ідентифікатор, незалежний від локалі.
        foreach ($eventLogError in $eventLogErrors) {
            if ($eventLogError.FullyQualifiedErrorId -notmatch 'GetEventLogNoEntriesFound') {
                Add-AuditError -Section 'EventLogs.System' -Message $eventLogError.Exception.Message
            }
        }

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

    # --- Per-log summary (System/Application/Setup/Security): Critical/Error/
    # Warning-лічильники + топ-10 провайдерів, через Get-WinEvent (докладніший
    # API за Get-EventLog вище — дає LevelDisplayName/ProviderName напряму,
    # без потреби мапити numeric EntryType). Гейтовано Full/Deep/Forensic —
    # 4 окремих Get-WinEvent-запити дорожчі за Quick/Full-профільний бюджет
    # часу, ніж один System-прохід вище.
    if ($Profile -in @('Full', 'Deep', 'Forensic')) {
        foreach ($logName in @('System', 'Application', 'Setup', 'Security')) {
            try {
                $winEvents = Get-WinEvent -FilterHashtable @{ LogName = $logName; StartTime = $eventLogStart; Level = 1, 2, 3 } -ErrorAction Stop
                $summary = ConvertTo-BravoEventLogSummary -Events $winEvents

                $script:Report.EventLogs.LogSummaries += [PSCustomObject]@{
                    LogName       = $logName
                    Status        = 'Detected'
                    CriticalCount = $summary.CriticalCount
                    ErrorCount    = $summary.ErrorCount
                    WarningCount  = $summary.WarningCount
                    TopProviders  = $summary.TopProviders
                }

                if ($summary.CriticalCount -gt 0) {
                    Add-AuditFinding -Severity 'CRITICAL' -Category 'EventLogs' -Message "Журнал '$logName' містить $($summary.CriticalCount) Critical-подій за $EventLogDays днів." -Recommendation "Перегляньте журнал $logName у Event Viewer, зверніть увагу на топ-провайдерів."
                }
            } catch {
                if ($_.FullyQualifiedErrorId -match 'NoMatchingEventsFound') {
                    # Штатний benign-результат — за період справді немає жодного
                    # Critical/Error/Warning запису в цьому журналі, не помилка.
                    $script:Report.EventLogs.LogSummaries += [PSCustomObject]@{
                        LogName       = $logName
                        Status        = 'Detected'
                        CriticalCount = 0
                        ErrorCount    = 0
                        WarningCount  = 0
                        TopProviders  = @()
                    }
                } else {
                    # Журнал відсутній (напр. Setup log на деяких Server Core
                    # збірках) або доступ заборонено — не помилка збору per se
                    # (решта журналів продовжують оброблятись), фіксуємо статус
                    # окремо для цього журналу.
                    $script:Report.EventLogs.LogSummaries += [PSCustomObject]@{
                        LogName       = $logName
                        Status        = 'Unavailable'
                        CriticalCount = $null
                        ErrorCount    = $null
                        WarningCount  = $null
                        TopProviders  = @()
                    }
                    Add-AuditError -Section "EventLogs.$logName" -Message $_.Exception.Message
                }
            }
        }
    }
}
