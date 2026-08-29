# MODULE: 39-Collectors-Updates.ps1
# Збір інформації про Windows Update: встановлені оновлення,
# відсутні (потрібні) оновлення та статус pending reboot.

function Get-BravoWindowsUpdateAudit {
    [CmdletBinding()]
    param()

    # --- Служба Windows Update ---
    try {
        $wuService = Get-Service -Name 'wuauserv' -ErrorAction Stop
        $script:Report.WindowsUpdate.ServiceStatus = "$($wuService.Status) ($($wuService.StartType))"

        if ($wuService.StartType -eq 'Disabled') {
            Add-AuditFinding -Severity 'WARNING' -Category 'WindowsUpdate' -Message 'Служба Windows Update (wuauserv) вимкнена' -Recommendation 'Перевірте, чи вимкнення є навмисним (політика/WSUS). Інакше увімкніть службу для отримання оновлень безпеки.'
        }
    } catch {
        Add-AuditError -Section 'WindowsUpdate.Service' -Message $_.Exception.Message
    }

    # --- Встановлені оновлення (HotFix) ---
    try {
        $hotFixes = Get-HotFix -ErrorAction Stop | Sort-Object InstalledOn -Descending

        $script:Report.WindowsUpdate.InstalledHotFixCount = @($hotFixes).Count

        # Накопичення через конвеєр замість += у циклі — уникає O(n^2)
        # перевиділення масиву на кожній ітерації при великій історії hotfix'ів.
        $script:Report.WindowsUpdate.InstalledHotFixes = @($hotFixes | ForEach-Object {
            $installedOn = ''
            if ($_.InstalledOn) { $installedOn = $_.InstalledOn.ToString('yyyy-MM-dd') }

            [PSCustomObject]@{
                HotFixID    = $_.HotFixID
                Description = $_.Description
                InstalledOn = $installedOn
                InstalledBy = $_.InstalledBy
            }
        })

        $lastHotFix = $hotFixes | Where-Object { $_.InstalledOn } | Select-Object -First 1
        if ($lastHotFix) {
            $script:Report.WindowsUpdate.LastInstalledHotFix = $lastHotFix.HotFixID
            $script:Report.WindowsUpdate.LastInstallDate = $lastHotFix.InstalledOn.ToString('yyyy-MM-dd')

            $daysSinceLastUpdate = [int]((Get-Date) - $lastHotFix.InstalledOn).TotalDays
            $script:Report.WindowsUpdate.DaysSinceLastInstall = $daysSinceLastUpdate

            if ($daysSinceLastUpdate -gt 60) {
                Add-AuditFinding -Severity 'WARNING' -Category 'WindowsUpdate' -Message "Останнє оновлення встановлено $daysSinceLastUpdate дн. тому ($($lastHotFix.HotFixID))" -Recommendation 'Запустіть перевірку та встановлення оновлень Windows Update.'
            }
        }

        Write-Host "  $IconOk Встановлені оновлення: $($script:Report.WindowsUpdate.InstalledHotFixCount) (останнє: $($script:Report.WindowsUpdate.LastInstallDate))" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'WindowsUpdate.HotFix' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка збору HotFix: $($_.Exception.Message)" -ForegroundColor Red
    }

    # --- Pending reboot ---
    try {
        $rebootKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        )

        $pendingReboot = $false
        foreach ($rebootKey in $rebootKeys) {
            if (Test-Path -LiteralPath $rebootKey) { $pendingReboot = $true; break }
        }

        if (-not $pendingReboot) {
            $sessionManager = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -ErrorAction SilentlyContinue
            if ($sessionManager -and $sessionManager.PendingFileRenameOperations) { $pendingReboot = $true }
        }

        $script:Report.WindowsUpdate.PendingRebootRequired = $pendingReboot

        if ($pendingReboot) {
            Add-AuditFinding -Severity 'WARNING' -Category 'WindowsUpdate' -Message 'Система очікує перезавантаження для завершення встановлення оновлень' -Recommendation 'Заплануйте контрольоване перезавантаження машини.'
        }
    } catch {
        Add-AuditError -Section 'WindowsUpdate.PendingReboot' -Message $_.Exception.Message
    }

    # --- Пошук відсутніх оновлень (Windows Update Agent COM API) ---
    # Пошук може тривати кілька хвилин, тому виконується лише для Deep/Forensic.
    if ($Profile -notin @('Deep','Forensic')) {
        $script:Report.WindowsUpdate.SearchStatus = 'Skipped'
        Write-Host "  $IconGear Пошук відсутніх оновлень пропущено (профіль: $Profile)" -ForegroundColor Gray
        return
    }

    try {
        Write-Host "  $IconGear Пошук відсутніх оновлень (може тривати кілька хвилин)..." -ForegroundColor Gray

        $updateSession = New-Object -ComObject 'Microsoft.Update.Session'
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $searchResult = $updateSearcher.Search("IsInstalled=0 and IsHidden=0 and Type='Software'")

        $pendingCriticalCount = 0
        $pendingSecurityCount = 0

        # Накопичення через конвеєр замість += у циклі — уникає O(n^2)
        # перевиділення масиву при великій кількості pending updates.
        $script:Report.WindowsUpdate.PendingUpdates = @($searchResult.Updates | ForEach-Object {
            $update = $_
            $kbList = @($update.KBArticleIDs | ForEach-Object { "KB$_" })
            $categoryNames = @($update.Categories | ForEach-Object { $_.Name })
            # CategoryID — стабільний, локале-незалежний GUID від WUA API.
            # $_.Name — локалізована назва категорії ("Security Updates" /
            # "Оновлення для системи безпеки" / інше на не-EN Windows),
            # тож звірка з англійським літералом "Security" (як робилося
            # раніше) на локалізованих ОС завжди провалювалась би.
            # 0FA1201D-4330-4FA8-8AE9-B877473B6441 = офіційний WUA CategoryID
            # для "Security Updates" (постійний, документований Microsoft).
            $categoryIds = @($update.Categories | ForEach-Object { $_.CategoryID })

            $severity = [string]$update.MsrcSeverity
            if ($severity -eq 'Critical') { $pendingCriticalCount++ }
            if ($categoryIds -contains '0fa1201d-4330-4fa8-8ae9-b877473b6441') { $pendingSecurityCount++ }

            $catalogUrl = ''
            if ($kbList.Count -gt 0) {
                $catalogUrl = "https://www.catalog.update.microsoft.com/Search.aspx?q=$([Uri]::EscapeDataString($kbList[0]))"
            }

            [PSCustomObject]@{
                Title        = $update.Title
                KB           = ($kbList -join ', ')
                Severity     = $severity
                Categories   = ($categoryNames -join ', ')
                IsDownloaded = [bool]$update.IsDownloaded
                SizeMB       = [Math]::Round($update.MaxDownloadSize / 1MB, 1)
                CatalogUrl   = $catalogUrl
            }
        })

        $script:Report.WindowsUpdate.PendingCount = @($script:Report.WindowsUpdate.PendingUpdates).Count
        $script:Report.WindowsUpdate.PendingCritical = $pendingCriticalCount
        $script:Report.WindowsUpdate.PendingSecurity = $pendingSecurityCount
        $script:Report.WindowsUpdate.SearchStatus = 'OK'

        if ($pendingCriticalCount -gt 0) {
            Add-AuditFinding -Severity 'CRITICAL' -Category 'WindowsUpdate' -Message "Не встановлено критичних оновлень: $pendingCriticalCount" -Recommendation 'Встановіть критичні оновлення якнайшвидше.'
        } elseif ($script:Report.WindowsUpdate.PendingCount -gt 0) {
            Add-AuditFinding -Severity 'WARNING' -Category 'WindowsUpdate' -Message "Очікують встановлення оновлень: $($script:Report.WindowsUpdate.PendingCount) (з них security: $pendingSecurityCount)" -Recommendation 'Заплануйте встановлення оновлень у сервісне вікно.'
        }

        Write-Host "  $IconOk Відсутні оновлення: $($script:Report.WindowsUpdate.PendingCount) (critical: $pendingCriticalCount, security: $pendingSecurityCount)" -ForegroundColor Green
    } catch {
        $script:Report.WindowsUpdate.SearchStatus = 'Error'
        $script:Report.WindowsUpdate.SearchError = $_.Exception.Message
        Add-AuditError -Section 'WindowsUpdate.Search' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка пошуку оновлень: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        # Явно звільняємо WUA COM-об'єкти (RCW), а не покладаємось лише на
        # завершення процесу — не критично для одноразового запуску скрипта,
        # але страхує від накопичення незвільнених посилань, якщо цю функцію
        # колись почнуть викликати кілька разів у межах одного процесу
        # (наприклад, тест-раннер, що імпортує модулі й дергає колектори в циклі).
        foreach ($comObject in @($searchResult, $updateSearcher, $updateSession)) {
            if ($comObject) {
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($comObject) | Out-Null } catch {}
            }
        }
    }
}
