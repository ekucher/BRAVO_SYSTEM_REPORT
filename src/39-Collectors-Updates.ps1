# MODULE: 39-Collectors-Updates.ps1
# Аналіз ОС і збір інформації про оновлення Windows, які потрібно встановити.

# Дата актуальності статичної таблиці життєвого циклу Windows.
# Оновлюйте разом із таблицею у Get-BravoWindowsLifecycleTable.
$script:BravoLifecycleTableUpdatedAt = '2026-08-24'

function Get-BravoWindowsLifecycleTable {
    [CmdletBinding()]
    param()

    # Статична таблиця життєвого циклу Windows.
    # Дані потребують періодичного оновлення разом із $BravoLifecycleTableUpdatedAt.
    return @(
        # 25H2: дати виведені за штатним циклом Microsoft (24 міс. Home/Pro, 36 міс. Enterprise/Education) і не звірені з lifecycle-сторінкою.
        [PSCustomObject]@{ Build = 26200; IsServer = $false; Product = 'Windows 11'; DisplayVersion = '25H2'; SupportEndConsumer = '2027-10-12'; SupportEndEnterprise = '2028-10-10' }
        [PSCustomObject]@{ Build = 26100; IsServer = $false; Product = 'Windows 11'; DisplayVersion = '24H2'; SupportEndConsumer = '2026-10-13'; SupportEndEnterprise = '2027-10-12' }
        [PSCustomObject]@{ Build = 22631; IsServer = $false; Product = 'Windows 11'; DisplayVersion = '23H2'; SupportEndConsumer = '2025-11-11'; SupportEndEnterprise = '2026-11-10' }
        [PSCustomObject]@{ Build = 22621; IsServer = $false; Product = 'Windows 11'; DisplayVersion = '22H2'; SupportEndConsumer = '2024-10-08'; SupportEndEnterprise = '2025-10-14' }
        [PSCustomObject]@{ Build = 22000; IsServer = $false; Product = 'Windows 11'; DisplayVersion = '21H2'; SupportEndConsumer = '2023-10-10'; SupportEndEnterprise = '2024-10-08' }
        [PSCustomObject]@{ Build = 19045; IsServer = $false; Product = 'Windows 10'; DisplayVersion = '22H2'; SupportEndConsumer = '2025-10-14'; SupportEndEnterprise = '2025-10-14' }
        [PSCustomObject]@{ Build = 19044; IsServer = $false; Product = 'Windows 10'; DisplayVersion = '21H2'; SupportEndConsumer = '2023-06-13'; SupportEndEnterprise = '2024-06-11' }
        [PSCustomObject]@{ Build = 19043; IsServer = $false; Product = 'Windows 10'; DisplayVersion = '21H1'; SupportEndConsumer = '2022-12-13'; SupportEndEnterprise = '2022-12-13' }
        [PSCustomObject]@{ Build = 19042; IsServer = $false; Product = 'Windows 10'; DisplayVersion = '20H2'; SupportEndConsumer = '2022-05-10'; SupportEndEnterprise = '2023-05-09' }
        [PSCustomObject]@{ Build = 19041; IsServer = $false; Product = 'Windows 10'; DisplayVersion = '2004'; SupportEndConsumer = '2021-12-14'; SupportEndEnterprise = '2021-12-14' }
        [PSCustomObject]@{ Build = 18363; IsServer = $false; Product = 'Windows 10'; DisplayVersion = '1909'; SupportEndConsumer = '2021-05-11'; SupportEndEnterprise = '2022-05-10' }
        [PSCustomObject]@{ Build = 17763; IsServer = $false; Product = 'Windows 10'; DisplayVersion = '1809 / LTSC 2019'; SupportEndConsumer = '2020-11-10'; SupportEndEnterprise = '2029-01-09' }
        [PSCustomObject]@{ Build = 14393; IsServer = $false; Product = 'Windows 10'; DisplayVersion = '1607 / LTSB 2016'; SupportEndConsumer = '2018-04-10'; SupportEndEnterprise = '2026-10-13' }
        [PSCustomObject]@{ Build = 10240; IsServer = $false; Product = 'Windows 10'; DisplayVersion = '1507 / LTSB 2015'; SupportEndConsumer = '2017-05-09'; SupportEndEnterprise = '2025-10-14' }
        [PSCustomObject]@{ Build = 9600;  IsServer = $false; Product = 'Windows 8.1'; DisplayVersion = '8.1'; SupportEndConsumer = '2023-01-10'; SupportEndEnterprise = '2023-01-10' }
        [PSCustomObject]@{ Build = 7601;  IsServer = $false; Product = 'Windows 7'; DisplayVersion = 'SP1'; SupportEndConsumer = '2020-01-14'; SupportEndEnterprise = '2023-01-10' }
        [PSCustomObject]@{ Build = 26100; IsServer = $true;  Product = 'Windows Server 2025'; DisplayVersion = '24H2'; SupportEndConsumer = '2034-10-10'; SupportEndEnterprise = '2034-10-10' }
        [PSCustomObject]@{ Build = 20348; IsServer = $true;  Product = 'Windows Server 2022'; DisplayVersion = '21H2'; SupportEndConsumer = '2031-10-14'; SupportEndEnterprise = '2031-10-14' }
        [PSCustomObject]@{ Build = 17763; IsServer = $true;  Product = 'Windows Server 2019'; DisplayVersion = '1809'; SupportEndConsumer = '2029-01-09'; SupportEndEnterprise = '2029-01-09' }
        [PSCustomObject]@{ Build = 14393; IsServer = $true;  Product = 'Windows Server 2016'; DisplayVersion = '1607'; SupportEndConsumer = '2027-01-12'; SupportEndEnterprise = '2027-01-12' }
        [PSCustomObject]@{ Build = 9600;  IsServer = $true;  Product = 'Windows Server 2012 R2'; DisplayVersion = 'R2'; SupportEndConsumer = '2023-10-10'; SupportEndEnterprise = '2023-10-10' }
        [PSCustomObject]@{ Build = 7601;  IsServer = $true;  Product = 'Windows Server 2008 R2'; DisplayVersion = 'R2 SP1'; SupportEndConsumer = '2020-01-14'; SupportEndEnterprise = '2023-01-10' }
    )
}

function Get-BravoOsSupportInfo {
    [CmdletBinding()]
    param(
        [string]$Caption,
        [string]$Build
    )

    $result = [ordered]@{
        Product = ''
        DisplayVersion = ''
        Channel = 'Consumer'
        SupportEndDate = ''
        DaysToEndOfSupport = $null
        SupportStatus = 'Unknown'
        LifecycleDataUpdatedAt = $script:BravoLifecycleTableUpdatedAt
    }

    $buildNumber = 0
    if (-not [int]::TryParse(($Build -split '\.')[0], [ref]$buildNumber)) { return $result }

    $isServer = ($Caption -match 'Server')
    $isEnterpriseChannel = ($Caption -match 'Enterprise|Education|LTSC|LTSB|Server')
    if ($isEnterpriseChannel) { $result.Channel = 'Enterprise / LTSC' }

    $entry = Get-BravoWindowsLifecycleTable | Where-Object { $_.Build -eq $buildNumber -and $_.IsServer -eq $isServer } | Select-Object -First 1
    if (-not $entry) { return $result }

    $result.Product = $entry.Product
    $result.DisplayVersion = $entry.DisplayVersion

    $endDateText = if ($isEnterpriseChannel -and $entry.SupportEndEnterprise) { $entry.SupportEndEnterprise } else { $entry.SupportEndConsumer }
    if (-not $endDateText) { $endDateText = $entry.SupportEndEnterprise }
    if (-not $endDateText) { return $result }

    $endDate = $null
    try { $endDate = [datetime]::ParseExact($endDateText, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) } catch { return $result }

    $daysLeft = [int][Math]::Floor(($endDate - (Get-Date).Date).TotalDays)
    $result.SupportEndDate = $endDateText
    $result.DaysToEndOfSupport = $daysLeft
    $result.SupportStatus = if ($daysLeft -lt 0) { 'EndOfSupport' } elseif ($daysLeft -le 180) { 'EndingSoon' } else { 'Supported' }

    return $result
}

function Get-BravoPendingRebootInfo {
    [CmdletBinding()]
    param()

    $reasons = @()

    $rebootKeys = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'; Reason = 'Component Based Servicing: RebootPending' }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress'; Reason = 'Component Based Servicing: RebootInProgress' }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'; Reason = 'Windows Update: RebootRequired' }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting'; Reason = 'Windows Update: PostRebootReporting' }
    )

    foreach ($rebootKey in $rebootKeys) {
        try {
            if (Test-Path -LiteralPath $rebootKey.Path) { $reasons += $rebootKey.Reason }
        } catch {
            Add-AuditError -Section 'Updates.PendingReboot' -Message $_.Exception.Message
        }
    }

    try {
        $sessionManager = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
        if ($sessionManager -and @($sessionManager.PendingFileRenameOperations).Count -gt 0) {
            $reasons += 'Session Manager: PendingFileRenameOperations'
        }
    } catch {
        Add-AuditError -Section 'Updates.PendingReboot' -Message $_.Exception.Message
    }

    try {
        $activeName = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -Name 'ComputerName' -ErrorAction SilentlyContinue).ComputerName
        $pendingName = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -Name 'ComputerName' -ErrorAction SilentlyContinue).ComputerName
        if ($activeName -and $pendingName -and ($activeName -ne $pendingName)) {
            $reasons += 'Заплановане перейменування машини'
        }
    } catch {
        Add-AuditError -Section 'Updates.PendingReboot' -Message $_.Exception.Message
    }

    return [ordered]@{
        Required = ([bool](@($reasons).Count -gt 0))
        Reasons  = @($reasons)
    }
}

function Get-BravoWindowsUpdateAgentInfo {
    [CmdletBinding()]
    param()

    $agent = [ordered]@{
        ServiceStatus = ''
        ServiceStartType = ''
        AutoUpdateOption = ''
        LastDetectSuccess = ''
        LastInstallSuccess = ''
        DaysSinceLastDetect = $null
        ManagedByWSUS = $false
        WSUSServer = ''
    }

    try {
        $wuService = Get-Service -Name 'wuauserv' -ErrorAction SilentlyContinue
        if ($wuService) {
            $agent.ServiceStatus = [string]$wuService.Status
            try { $agent.ServiceStartType = [string]$wuService.StartType } catch { $agent.ServiceStartType = '' }
        }

        if (-not $agent.ServiceStartType) {
            $wuWmiService = Get-AuditObject -ClassName 'Win32_Service' -Filter "Name='wuauserv'" -First
            if ($wuWmiService) {
                $agent.ServiceStartType = [string]$wuWmiService.StartMode
                if (-not $agent.ServiceStatus) { $agent.ServiceStatus = [string]$wuWmiService.State }
            }
        }
    } catch {
        Add-AuditError -Section 'Updates.Service' -Message $_.Exception.Message
    }

    try {
        $autoUpdatePolicy = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -ErrorAction SilentlyContinue
        if ($autoUpdatePolicy) {
            if ($null -ne $autoUpdatePolicy.AUOptions) {
                $agent.AutoUpdateOption = switch ([int]$autoUpdatePolicy.AUOptions) {
                    1 { 'Автоматичні оновлення вимкнено політикою' }
                    2 { 'Повідомляти перед завантаженням' }
                    3 { 'Завантажувати автоматично, повідомляти перед установкою' }
                    4 { 'Завантажувати та встановлювати за розкладом' }
                    5 { 'Керується локальним адміністратором' }
                    default { "AUOptions=$($autoUpdatePolicy.AUOptions)" }
                }
            }
            if ($autoUpdatePolicy.UseWUServer -eq 1) { $agent.ManagedByWSUS = $true }
        }

        $wsusPolicy = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -ErrorAction SilentlyContinue
        if ($wsusPolicy -and $wsusPolicy.WUServer) { $agent.WSUSServer = [string]$wsusPolicy.WUServer }
    } catch {
        Add-AuditError -Section 'Updates.Policy' -Message $_.Exception.Message
    }

    try {
        $detectResults = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Detect' -ErrorAction SilentlyContinue
        if ($detectResults -and $detectResults.LastSuccessTime) {
            $agent.LastDetectSuccess = [string]$detectResults.LastSuccessTime
            $detectTime = $null
            if ([datetime]::TryParse($agent.LastDetectSuccess, [ref]$detectTime)) {
                $agent.DaysSinceLastDetect = [int][Math]::Floor(((Get-Date) - $detectTime).TotalDays)
            }
        }

        $installResults = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Install' -ErrorAction SilentlyContinue
        if ($installResults -and $installResults.LastSuccessTime) {
            $agent.LastInstallSuccess = [string]$installResults.LastSuccessTime
        }
    } catch {
        Add-AuditError -Section 'Updates.Results' -Message $_.Exception.Message
    }

    return $agent
}

function Get-BravoInstalledUpdatesInfo {
    [CmdletBinding()]
    param(
        [int]$RecentCount = 15
    )

    $installed = [ordered]@{
        Total = 0
        LastInstalledOn = ''
        DaysSinceLastUpdate = $null
        InstalledLast30Days = 0
        Recent = @()
    }

    $hotfixes = @()
    try {
        $hotfixes = @(Get-HotFix -ErrorAction Stop)
    } catch {
        try {
            $hotfixes = @(Get-AuditObject -ClassName 'Win32_QuickFixEngineering')
        } catch {
            Add-AuditError -Section 'Updates.Installed' -Message $_.Exception.Message
            return $installed
        }
    }

    $installed.Total = @($hotfixes).Count
    if ($installed.Total -eq 0) { return $installed }

    $normalized = foreach ($hotfix in $hotfixes) {
        $installedOn = $null
        if ($hotfix.InstalledOn -is [datetime]) {
            $installedOn = [datetime]$hotfix.InstalledOn
        } elseif ($hotfix.InstalledOn) {
            $parsed = $null
            if ([datetime]::TryParse([string]$hotfix.InstalledOn, [ref]$parsed)) { $installedOn = $parsed }
        }

        [PSCustomObject]@{
            HotFixID    = [string]$hotfix.HotFixID
            Description = [string]$hotfix.Description
            InstalledBy = [string]$hotfix.InstalledBy
            InstalledOn = $installedOn
            InstalledOnText = if ($installedOn) { $installedOn.ToString('yyyy-MM-dd') } else { '' }
        }
    }

    $dated = @($normalized | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending)
    if ($dated.Count -gt 0) {
        $lastInstalled = $dated[0].InstalledOn
        $installed.LastInstalledOn = $lastInstalled.ToString('yyyy-MM-dd')
        $installed.DaysSinceLastUpdate = [int][Math]::Floor(((Get-Date) - $lastInstalled).TotalDays)
        $installed.InstalledLast30Days = @($dated | Where-Object { $_.InstalledOn -ge (Get-Date).AddDays(-30) }).Count
        $installed.Recent = @($dated | Select-Object -First $RecentCount | Select-Object HotFixID, Description, InstalledBy, InstalledOnText)
    } else {
        $installed.Recent = @($normalized | Select-Object -First $RecentCount | Select-Object HotFixID, Description, InstalledBy, InstalledOnText)
    }

    return $installed
}

function Get-BravoPendingUpdatesSearchScriptBlock {
    [CmdletBinding()]
    param()

    return {
        param([int]$MaxItems)

        $searchResult = [ordered]@{
            Status  = 'Failed'
            Method  = 'Microsoft.Update.Session (COM)'
            Error   = ''
            Updates = @()
        }

        try {
            $updateSession = New-Object -ComObject 'Microsoft.Update.Session'
            $updateSearcher = $updateSession.CreateUpdateSearcher()
            $searchOutput = $updateSearcher.Search('IsInstalled=0 and IsHidden=0')

            $collected = @()
            $index = 0
            foreach ($update in $searchOutput.Updates) {
                if ($index -ge $MaxItems) { break }
                $index++

                $categories = @()
                try { $categories = @($update.Categories | ForEach-Object { [string]$_.Name }) } catch { $categories = @() }

                $kbList = @()
                try { $kbList = @($update.KBArticleIDs | ForEach-Object { "KB$_" }) } catch { $kbList = @() }

                $rebootBehavior = ''
                try { $rebootBehavior = [string]$update.InstallationBehavior.RebootBehavior } catch { $rebootBehavior = '' }

                $deploymentChange = ''
                try {
                    if ($update.LastDeploymentChangeTime) {
                        $deploymentChange = ([datetime]$update.LastDeploymentChangeTime).ToString('yyyy-MM-dd')
                    }
                } catch { $deploymentChange = '' }

                $sizeMb = 0
                try { $sizeMb = [Math]::Round(([double]$update.MaxDownloadSize) / 1MB, 2) } catch { $sizeMb = 0 }

                $collected += [PSCustomObject]@{
                    Title          = [string]$update.Title
                    KB             = ($kbList -join ', ')
                    Categories     = ($categories -join ', ')
                    MsrcSeverity   = [string]$update.MsrcSeverity
                    IsDownloaded   = [bool]$update.IsDownloaded
                    IsMandatory    = [bool]$update.IsMandatory
                    RebootBehavior = $rebootBehavior
                    SizeMB         = $sizeMb
                    ReleasedOn     = $deploymentChange
                    SupportUrl     = [string]$update.SupportUrl
                }
            }

            $searchResult.Updates = $collected
            $searchResult.Status = 'OK'
        } catch {
            $searchResult.Error = $_.Exception.Message
        }

        return [PSCustomObject]$searchResult
    }
}

function Invoke-BravoPendingUpdatesSearch {
    [CmdletBinding()]
    param(
        [int]$TimeoutSeconds = 180,
        [int]$MaxItems = 200
    )

    $searchBlock = Get-BravoPendingUpdatesSearchScriptBlock
    $startedAt = Get-Date

    $canUseJob = ($TimeoutSeconds -gt 0) -and ((Get-Command -Name 'Start-Job' -ErrorAction SilentlyContinue) -ne $null)

    if (-not $canUseJob) {
        $inlineResult = & $searchBlock $MaxItems
        return [ordered]@{
            Status  = [string]$inlineResult.Status
            Method  = [string]$inlineResult.Method
            Error   = [string]$inlineResult.Error
            Updates = @($inlineResult.Updates)
            DurationSeconds = [Math]::Round(((Get-Date) - $startedAt).TotalSeconds, 1)
        }
    }

    $searchJob = $null
    try {
        $searchJob = Start-Job -ScriptBlock $searchBlock -ArgumentList $MaxItems
        $completedJob = Wait-Job -Job $searchJob -Timeout $TimeoutSeconds

        if (-not $completedJob) {
            try { Stop-Job -Job $searchJob -ErrorAction SilentlyContinue } catch {}
            return [ordered]@{
                Status  = 'Timeout'
                Method  = 'Microsoft.Update.Session (COM)'
                Error   = "Пошук оновлень перевищив ліміт $TimeoutSeconds сек."
                Updates = @()
                DurationSeconds = [Math]::Round(((Get-Date) - $startedAt).TotalSeconds, 1)
            }
        }

        $jobResult = Receive-Job -Job $searchJob -ErrorAction SilentlyContinue
        if (-not $jobResult) {
            return [ordered]@{
                Status  = 'Failed'
                Method  = 'Microsoft.Update.Session (COM)'
                Error   = 'Пошук оновлень не повернув результат.'
                Updates = @()
                DurationSeconds = [Math]::Round(((Get-Date) - $startedAt).TotalSeconds, 1)
            }
        }

        return [ordered]@{
            Status  = [string]$jobResult.Status
            Method  = [string]$jobResult.Method
            Error   = [string]$jobResult.Error
            Updates = @($jobResult.Updates)
            DurationSeconds = [Math]::Round(((Get-Date) - $startedAt).TotalSeconds, 1)
        }
    } catch {
        return [ordered]@{
            Status  = 'Failed'
            Method  = 'Microsoft.Update.Session (COM)'
            Error   = $_.Exception.Message
            Updates = @()
            DurationSeconds = [Math]::Round(((Get-Date) - $startedAt).TotalSeconds, 1)
        }
    } finally {
        if ($searchJob) { try { Remove-Job -Job $searchJob -Force -ErrorAction SilentlyContinue } catch {} }
    }
}

function Get-BravoUpdatesAudit {
    [CmdletBinding()]
    param()

    # --- Аналіз ОС і потрібних оновлень ---
    try {
        $supportInfo = Get-BravoOsSupportInfo -Caption $script:Report.OS.Caption -Build $script:Report.OS.Build

        $script:Report.Updates.OS.Product = $supportInfo.Product
        $script:Report.Updates.OS.DisplayVersion = $supportInfo.DisplayVersion
        $script:Report.Updates.OS.Channel = $supportInfo.Channel
        $script:Report.Updates.OS.SupportEndDate = $supportInfo.SupportEndDate
        $script:Report.Updates.OS.DaysToEndOfSupport = $supportInfo.DaysToEndOfSupport
        $script:Report.Updates.OS.SupportStatus = $supportInfo.SupportStatus
        $script:Report.Updates.OS.LifecycleDataUpdatedAt = $supportInfo.LifecycleDataUpdatedAt

        try {
            $currentVersionKey = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
            if ($currentVersionKey) {
                if ($currentVersionKey.DisplayVersion) { $script:Report.Updates.OS.RegistryDisplayVersion = [string]$currentVersionKey.DisplayVersion }
                elseif ($currentVersionKey.ReleaseId) { $script:Report.Updates.OS.RegistryDisplayVersion = [string]$currentVersionKey.ReleaseId }

                if ($null -ne $currentVersionKey.UBR) {
                    $script:Report.Updates.OS.UBR = [string]$currentVersionKey.UBR
                    $script:Report.Updates.OS.FullBuild = "$($script:Report.OS.Build).$($currentVersionKey.UBR)"
                }
            }
        } catch {
            Add-AuditError -Section 'Updates.OSBuild' -Message $_.Exception.Message
        }

        if (-not $script:Report.Updates.OS.FullBuild) { $script:Report.Updates.OS.FullBuild = [string]$script:Report.OS.Build }

        if ($supportInfo.SupportStatus -eq 'EndOfSupport') {
            Add-AuditFinding -Severity 'CRITICAL' -Category 'Updates' -Message "ОС поза підтримкою з $($supportInfo.SupportEndDate): $($script:Report.OS.Caption) $($supportInfo.DisplayVersion)" -Recommendation 'Заплануйте оновлення до підтримуваної версії Windows: оновлення безпеки більше не випускаються.'
        } elseif ($supportInfo.SupportStatus -eq 'EndingSoon') {
            Add-AuditFinding -Severity 'WARNING' -Category 'Updates' -Message "Підтримка ОС завершується $($supportInfo.SupportEndDate) (залишилось днів: $($supportInfo.DaysToEndOfSupport))" -Recommendation 'Заплануйте перехід на новішу версію Windows до завершення підтримки.'
        }
    } catch {
        Add-AuditError -Section 'Updates.OS' -Message $_.Exception.Message
    }

    # --- Windows Update agent і політики ---
    try {
        $agentInfo = Get-BravoWindowsUpdateAgentInfo
        foreach ($agentKey in @($agentInfo.Keys)) { $script:Report.Updates.WindowsUpdate[$agentKey] = $agentInfo[$agentKey] }

        if ($agentInfo.ServiceStartType -match 'Disabled') {
            Add-AuditFinding -Severity 'WARNING' -Category 'Updates' -Message 'Службу Windows Update (wuauserv) вимкнено' -Recommendation 'Увімкніть службу wuauserv, інакше оновлення безпеки не встановлюються.'
        }
        if ($agentInfo.AutoUpdateOption -like '*вимкнено політикою*') {
            Add-AuditFinding -Severity 'WARNING' -Category 'Updates' -Message 'Автоматичні оновлення вимкнено груповою політикою (AUOptions=1)' -Recommendation 'Перевірте політику Windows Update або забезпечте контрольований цикл оновлень.'
        }
        if ($null -ne $agentInfo.DaysSinceLastDetect -and $agentInfo.DaysSinceLastDetect -gt 30) {
            Add-AuditFinding -Severity 'WARNING' -Category 'Updates' -Message "Останній успішний пошук оновлень був $($agentInfo.DaysSinceLastDetect) дн. тому" -Recommendation 'Перевірте доступність Windows Update або WSUS-сервера.'
        }
    } catch {
        Add-AuditError -Section 'Updates.Agent' -Message $_.Exception.Message
    }

    # --- Pending reboot ---
    try {
        $rebootInfo = Get-BravoPendingRebootInfo
        $script:Report.Updates.PendingReboot.Required = $rebootInfo.Required
        $script:Report.Updates.PendingReboot.Reasons = $rebootInfo.Reasons

        if ($rebootInfo.Required) {
            Add-AuditFinding -Severity 'WARNING' -Category 'Updates' -Message "Потрібне перезавантаження для завершення встановлення оновлень: $($rebootInfo.Reasons -join '; ')" -Recommendation 'Заплануйте контрольоване перезавантаження, щоб застосувати встановлені оновлення.'
        }
    } catch {
        Add-AuditError -Section 'Updates.PendingReboot' -Message $_.Exception.Message
    }

    # --- Встановлені оновлення ---
    try {
        $recentCount = if ($Profile -eq 'Quick') { 5 } elseif ($Profile -eq 'Full') { 15 } else { 30 }
        $installedInfo = Get-BravoInstalledUpdatesInfo -RecentCount $recentCount
        foreach ($installedKey in @($installedInfo.Keys)) { $script:Report.Updates.Installed[$installedKey] = $installedInfo[$installedKey] }

        if ($null -ne $installedInfo.DaysSinceLastUpdate -and $installedInfo.DaysSinceLastUpdate -gt 60) {
            Add-AuditFinding -Severity 'WARNING' -Category 'Updates' -Message "Останнє оновлення встановлено $($installedInfo.DaysSinceLastUpdate) дн. тому ($($installedInfo.LastInstalledOn))" -Recommendation 'Перевірте, чи працює цикл оновлень Windows Update або WSUS.'
        }
    } catch {
        Add-AuditError -Section 'Updates.Installed' -Message $_.Exception.Message
    }

    # --- Пошук доступних оновлень ---
    try {
        $skipSearch = $SkipUpdateSearch -or ($Profile -eq 'Quick')

        if ($skipSearch) {
            $script:Report.Updates.Search.Status = 'Skipped'
            $script:Report.Updates.Search.Error = if ($SkipUpdateSearch) { 'Пошук вимкнено параметром -SkipUpdateSearch.' } else { 'Профіль Quick не виконує онлайн-пошук оновлень.' }
            Write-Host "  $IconGear Оновлення: онлайн-пошук пропущено" -ForegroundColor Yellow
        } else {
            Write-Host "  $IconGear Оновлення: пошук доступних оновлень (до $UpdateSearchTimeoutSec сек)..." -ForegroundColor Cyan

            $searchResult = Invoke-BravoPendingUpdatesSearch -TimeoutSeconds $UpdateSearchTimeoutSec
            $script:Report.Updates.Search.Status = $searchResult.Status
            $script:Report.Updates.Search.Method = $searchResult.Method
            $script:Report.Updates.Search.Error = $searchResult.Error
            $script:Report.Updates.Search.DurationSeconds = $searchResult.DurationSeconds
            $script:Report.Updates.Search.CheckedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

            if ($searchResult.Status -ne 'OK') {
                Add-AuditError -Section 'Updates.Search' -Message $searchResult.Error
                Write-Host "  $IconError Оновлення: пошук не виконано ($($searchResult.Status))" -ForegroundColor Red
            } else {
                $pendingUpdates = @($searchResult.Updates)

                $securityUpdates = @($pendingUpdates | Where-Object { $_.Categories -match 'Security' -or $_.MsrcSeverity })
                $criticalUpdates = @($pendingUpdates | Where-Object { $_.Categories -match 'Critical' -or $_.MsrcSeverity -in @('Critical') })
                $driverUpdates = @($pendingUpdates | Where-Object { $_.Categories -match 'Driver' })
                $definitionUpdates = @($pendingUpdates | Where-Object { $_.Categories -match 'Definition' })
                $downloadedUpdates = @($pendingUpdates | Where-Object { $_.IsDownloaded })

                $totalSizeMb = 0
                foreach ($pendingUpdate in $pendingUpdates) { $totalSizeMb += [double]$pendingUpdate.SizeMB }

                $script:Report.Updates.Pending.Total = $pendingUpdates.Count
                $script:Report.Updates.Pending.Security = $securityUpdates.Count
                $script:Report.Updates.Pending.Critical = $criticalUpdates.Count
                $script:Report.Updates.Pending.Driver = $driverUpdates.Count
                $script:Report.Updates.Pending.Definition = $definitionUpdates.Count
                $classifiedUpdates = @($pendingUpdates | Where-Object { $_.Categories -match 'Security|Critical|Driver|Definition' -or $_.MsrcSeverity })
                $script:Report.Updates.Pending.Other = $pendingUpdates.Count - $classifiedUpdates.Count
                $script:Report.Updates.Pending.Downloaded = $downloadedUpdates.Count
                $script:Report.Updates.Pending.TotalSizeMB = [Math]::Round($totalSizeMb, 2)
                $script:Report.Updates.Pending.Items = $pendingUpdates

                $oldestRelease = @($pendingUpdates | Where-Object { $_.ReleasedOn } | Sort-Object ReleasedOn | Select-Object -First 1)
                if ($oldestRelease.Count -gt 0) {
                    $oldestDate = $null
                    if ([datetime]::TryParse($oldestRelease[0].ReleasedOn, [ref]$oldestDate)) {
                        $script:Report.Updates.Pending.OldestReleasedOn = $oldestRelease[0].ReleasedOn
                        $script:Report.Updates.Pending.MaxAgeDays = [int][Math]::Floor(((Get-Date) - $oldestDate).TotalDays)
                    }
                }

                if ($criticalUpdates.Count -gt 0 -or $securityUpdates.Count -gt 0) {
                    Add-AuditFinding -Severity 'CRITICAL' -Category 'Updates' -Message "Не встановлено оновлення безпеки: security=$($securityUpdates.Count), critical=$($criticalUpdates.Count)" -Recommendation 'Встановіть оновлення безпеки якнайшвидше та перезавантажте машину.'
                } elseif ($pendingUpdates.Count -gt 0) {
                    Add-AuditFinding -Severity 'WARNING' -Category 'Updates' -Message "Доступні невстановлені оновлення: $($pendingUpdates.Count)" -Recommendation 'Заплануйте встановлення доступних оновлень Windows.'
                }

                Write-Host "  $IconOk Оновлення: доступно $($pendingUpdates.Count) (security: $($securityUpdates.Count))" -ForegroundColor Green
            }
        }
    } catch {
        $script:Report.Updates.Search.Status = 'Failed'
        $script:Report.Updates.Search.Error = $_.Exception.Message
        Add-AuditError -Section 'Updates.Search' -Message $_.Exception.Message
    }

    # --- Метрика dashboard ---
    try {
        $updatesMetric = $script:Report.Dashboard.Metrics.Updates
        $searchStatus = $script:Report.Updates.Search.Status
        $pendingTotal = [int]$script:Report.Updates.Pending.Total
        $pendingSecurity = [int]$script:Report.Updates.Pending.Security

        if ($searchStatus -eq 'OK') {
            $updatesMetric.Value = "$pendingTotal до встановлення"
        } elseif ($searchStatus -eq 'Skipped') {
            $updatesMetric.Value = 'Пошук пропущено'
        } else {
            $updatesMetric.Value = "Пошук: $searchStatus"
        }

        $updatesDetails = @()
        if ($script:Report.Updates.OS.DisplayVersion) { $updatesDetails += "$($script:Report.Updates.OS.Product) $($script:Report.Updates.OS.DisplayVersion)" }
        if ($searchStatus -eq 'OK' -and $pendingSecurity -gt 0) { $updatesDetails += "security: $pendingSecurity" }
        if ($script:Report.Updates.Installed.LastInstalledOn) { $updatesDetails += "останнє: $($script:Report.Updates.Installed.LastInstalledOn)" }
        if ($script:Report.Updates.PendingReboot.Required) { $updatesDetails += 'потрібне перезавантаження' }
        $updatesMetric.Details = ($updatesDetails -join ', ')

        $updatesMetric.Status = if ($script:Report.Updates.OS.SupportStatus -eq 'EndOfSupport' -or $pendingSecurity -gt 0) {
            'CRITICAL'
        } elseif ($pendingTotal -gt 0 -or $script:Report.Updates.PendingReboot.Required -or $script:Report.Updates.OS.SupportStatus -eq 'EndingSoon' -or $searchStatus -notin @('OK','Skipped')) {
            'WARNING'
        } else {
            'OK'
        }
    } catch {
        Add-AuditError -Section 'Updates.Metric' -Message $_.Exception.Message
    }
}
