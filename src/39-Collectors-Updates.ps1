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

        foreach ($hotFix in $hotFixes) {
            $installedOn = ''
            if ($hotFix.InstalledOn) { $installedOn = $hotFix.InstalledOn.ToString('yyyy-MM-dd') }

            $script:Report.WindowsUpdate.InstalledHotFixes += [PSCustomObject]@{
                HotFixID    = $hotFix.HotFixID
                Description = $hotFix.Description
                InstalledOn = $installedOn
                InstalledBy = $hotFix.InstalledBy
            }
        }

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

        foreach ($update in $searchResult.Updates) {
            $kbList = @()
            foreach ($kbArticleId in $update.KBArticleIDs) { $kbList += "KB$kbArticleId" }

            $categoryNames = @()
            foreach ($updateCategory in $update.Categories) { $categoryNames += $updateCategory.Name }

            $severity = [string]$update.MsrcSeverity
            if ($severity -eq 'Critical') { $pendingCriticalCount++ }
            if (($categoryNames -join ' ') -match 'Security') { $pendingSecurityCount++ }

            $script:Report.WindowsUpdate.PendingUpdates += [PSCustomObject]@{
                Title        = $update.Title
                KB           = ($kbList -join ', ')
                Severity     = $severity
                Categories   = ($categoryNames -join ', ')
                IsDownloaded = [bool]$update.IsDownloaded
                SizeMB       = [Math]::Round($update.MaxDownloadSize / 1MB, 1)
            }
        }

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
    }
}
