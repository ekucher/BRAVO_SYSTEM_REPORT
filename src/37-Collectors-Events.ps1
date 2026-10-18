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

    # Числовий .Level (стандартний Windows Event Log level: 1=Critical,
    # 2=Error, 3=Warning) — locale-independent. .LevelDisplayName — це MUI
    # рядок, локалізований на мову ОС аудитованої машини ("Помилка" на
    # укр., "Erreur" на фр. тощо), тому порівняння з англійськими літералами
    # раніше давало нульові лічильники на не-англомовних системах (Release
    # Blocker Fixes v0.6.1).
    $criticalCount = @($events | Where-Object { $_.Level -eq 1 }).Count
    $errorCount    = @($events | Where-Object { $_.Level -eq 2 }).Count
    $warningCount  = @($events | Where-Object { $_.Level -eq 3 }).Count

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
    $topErrorSources = @()

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
        # Повний набір подій (не лише Count), бо знахідка нижче публікує
        # топ джерел помилок — той самий індексований Get-WinEvent API, що й
        # Get-BravoWinEventCount, лише без відкидання самих об'єктів.
        $systemErrorEvents = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 2; StartTime = $eventLogStart } -ErrorAction Stop)
        $systemErrors = $systemErrorEvents.Count

        $topErrorSources = @(
            $systemErrorEvents |
                Group-Object -Property ProviderName |
                Sort-Object -Property Count -Descending |
                Select-Object -First 10 -Property @{Name='Source'; Expression={$_.Name}}, Count, @{Name='LastMessage'; Expression={($_.Group | Select-Object -First 1).Message}}
        )
    } catch {
        if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound,*') {
            $systemErrors = 0
            $topErrorSources = @()
        } else {
            Add-AuditError -Section 'EventLogs' -Message "SystemErrors: $($_.Exception.Message)"
        }
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
    $script:Report.EventLogs.TopErrorSources = $topErrorSources

    if ($script:Report.EventLogs.SystemErrors -gt 0) {
        $topSourcesText = ($topErrorSources | Select-Object -First 3 | ForEach-Object { "$($_.Source) ($($_.Count))" }) -join ', '
        $topSourcesNote = if ($topSourcesText) { " Топ джерел: $topSourcesText." } else { '' }
        Add-AuditFinding -Severity 'WARNING' -Category 'EventLogs' -Message "За $EventLogDays днів знайдено системних помилок: $($script:Report.EventLogs.SystemErrors).$topSourcesNote" -Recommendation 'Перегляньте System log і визначте повторювані джерела помилок.'
    }

    Write-Host "  $IconEvent Події System: помилок=$($script:Report.EventLogs.SystemErrors), попереджень=$($script:Report.EventLogs.SystemWarnings) за $EventLogDays дн." -ForegroundColor Green

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

        # --- Hardware diagnostics: Disk/Ntfs/storport/stornvme/WHEA/
        # Kernel-Power/BugCheck — провайдер-специфічний зріз System log
        # для критичних апаратних/драйверних проблем (диски, storage-стек,
        # апаратні помилки WHEA, неочікувані вимкнення живлення, крахи ОС).
        # Кожен провайдер запитується ОКРЕМО (не одним FilterHashtable з
        # масивом ProviderName): якщо хоча б один провайдер не зареєстрований
        # у системі (Get-WinEvent кидає NoMatchingProvidersFound на весь
        # запит одразу), решта провайдерів не мали б зібратись взагалі —
        # перевірено локальним репро (Get-WinEvent з масивом провайдерів,
        # один з яких відсутній, валить весь запит).
        $hardwareDiagnosticProviders = @(
            [PSCustomObject]@{ Label = 'Disk'; ProviderName = 'disk' }
            [PSCustomObject]@{ Label = 'Ntfs'; ProviderName = 'Ntfs' }
            [PSCustomObject]@{ Label = 'StorPort'; ProviderName = 'Microsoft-Windows-StorPort' }
            [PSCustomObject]@{ Label = 'StorNVMe'; ProviderName = 'stornvme' }
            [PSCustomObject]@{ Label = 'WHEA'; ProviderName = 'Microsoft-Windows-WHEA-Logger' }
            [PSCustomObject]@{ Label = 'Kernel-Power'; ProviderName = 'Microsoft-Windows-Kernel-Power' }
            [PSCustomObject]@{ Label = 'BugCheck'; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting' }
        )

        foreach ($diagProvider in $hardwareDiagnosticProviders) {
            try {
                $providerEvents = Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = $diagProvider.ProviderName; StartTime = $eventLogStart; Level = 1, 2, 3 } -ErrorAction Stop

                $lastMessage = ($providerEvents | Select-Object -First 1).Message
                $script:Report.EventLogs.HardwareDiagnostics += [PSCustomObject]@{
                    Provider     = $diagProvider.Label
                    Status       = 'Detected'
                    Count        = @($providerEvents).Count
                    LastMessage  = $lastMessage
                }

                if (@($providerEvents).Count -gt 0) {
                    Add-AuditFinding -Severity 'WARNING' -Category 'EventLogs.HardwareDiagnostics' -Message "Провайдер '$($diagProvider.Label)' залишив $(@($providerEvents).Count) Critical/Error/Warning подій у System log за $EventLogDays днів." -Recommendation 'Перегляньте System log за цим провайдером — можливі проблеми диска/storage-стека/апаратного забезпечення.'
                }
            } catch {
                if ($_.FullyQualifiedErrorId -match 'NoMatchingEventsFound') {
                    # Провайдер зареєстрований, але за період немає жодної
                    # Critical/Error/Warning події — штатний, здоровий стан.
                    $script:Report.EventLogs.HardwareDiagnostics += [PSCustomObject]@{
                        Provider    = $diagProvider.Label
                        Status      = 'Detected'
                        Count       = 0
                        LastMessage = ''
                    }
                } elseif ($_.FullyQualifiedErrorId -match 'NoMatchingProvidersFound|LogsAndProvidersDontOverlap') {
                    # NoMatchingProvidersFound: провайдер не зареєстрований у
                    # системі (напр. stornvme на машині без NVMe-диска).
                    # LogsAndProvidersDontOverlap: провайдер зареєстрований,
                    # але не пише події в System log (напр. StorPort на
                    # системі, де активний лише stornvme, чи навпаки —
                    # перевірено локальним репро). Обидва — штатна апаратна/
                    # драйверна відмінність, не помилка збору.
                    $script:Report.EventLogs.HardwareDiagnostics += [PSCustomObject]@{
                        Provider    = $diagProvider.Label
                        Status      = 'NotAvailable'
                        Count       = $null
                        LastMessage = ''
                    }
                } else {
                    $script:Report.EventLogs.HardwareDiagnostics += [PSCustomObject]@{
                        Provider    = $diagProvider.Label
                        Status      = 'Unavailable'
                        Count       = $null
                        LastMessage = ''
                    }
                    Add-AuditError -Section "EventLogs.HardwareDiagnostics.$($diagProvider.Label)" -Message $_.Exception.Message
                }
            }
        }
    }
}
