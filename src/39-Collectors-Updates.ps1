# MODULE: 39-Collectors-Updates.ps1
# Аналіз ОС і збір інформації про оновлення Windows, які потрібно встановити.
#
# Таблиця життєвого циклу Windows (Get-BravoWindowsLifecycleTable) винесена
# у окремий data-модуль src/39a-Data-WindowsLifecycle.ps1 (P0.7), який будується
# перед цим модулем — див. src/BRAVO.build.json.

function Test-BravoUpdateClassification {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Update,
        [ValidateSet('Security','Critical','Driver','Definition')]
        [string]$Classification
    )

    if ($null -eq $Update) { return $false }

    # Стабільні CategoryID класифікацій Windows Update (не залежать від мови інтерфейсу).
    $classificationIds = @{
        Security   = '0fa1201d-4330-4fa8-8ae9-b877473b6441'
        Critical   = 'e6cf1350-c01b-414d-a61f-263d14d133b4'
        Driver     = 'ebfc1fc5-71a4-4f7b-9aca-3b9a503104a0'
        Definition = 'e0789628-ce08-4437-be74-2495b842f43b'
    }

    # Fallback на англомовні назви категорій, якщо CategoryID недоступний.
    $classificationNames = @{
        Security   = 'Security'
        Critical   = 'Critical'
        Driver     = 'Driver'
        Definition = 'Definition'
    }

    $categoryIds = ([string]$Update.CategoryIds).ToLowerInvariant()
    if ($categoryIds) { return ($categoryIds -like "*$($classificationIds[$Classification])*") }

    return ([string]$Update.Categories -match $classificationNames[$Classification])
}

function Get-BravoOsSupportInfo {
    [CmdletBinding()]
    param(
        [string]$Caption,
        [string]$Build,
        [string]$EditionId = ''
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

    # Канал визначається у порядку LTSC/LTSB -> Enterprise/Education/Server -> Consumer.
    # LTSC визначається за EditionID (EnterpriseS, EnterpriseSN, IoTEnterpriseS), бо Caption
    # на Enterprise/Education SAC не відрізняється від LTSC-редакції.
    $isLtscChannel = $false
    if ($EditionId) {
        $isLtscChannel = ($EditionId -match '^(IoT)?EnterpriseS(N)?$')
    } else {
        $isLtscChannel = ($Caption -match 'LTSC|LTSB')
    }

    # Pro Education і Pro for Workstations містять у Caption слово Education/Pro,
    # але обслуговуються за споживчим циклом Home/Pro.
    $isConsumerProEdition = $false
    if ($EditionId) {
        $isConsumerProEdition = ($EditionId -match '^Professional')
    } else {
        $isConsumerProEdition = ($Caption -match 'Pro Education|Pro for Workstations')
    }

    $isEnterpriseChannel = (-not $isConsumerProEdition) -and ($Caption -match 'Enterprise|Education|Server')

    $result.Channel = if ($isLtscChannel) { 'LTSC / LTSB' } elseif ($isEnterpriseChannel) { 'Enterprise / Education' } else { 'Consumer' }

    $entry = Get-BravoWindowsLifecycleTable | Where-Object { $_.Build -eq $buildNumber -and $_.IsServer -eq $isServer } | Select-Object -First 1
    if (-not $entry) { return $result }

    $result.Product = $entry.Product
    $result.DisplayVersion = $entry.DisplayVersion

    $endDateText = ''
    if ($isLtscChannel) { $endDateText = $entry.SupportEndLtsc }
    if (-not $endDateText -and ($isLtscChannel -or $isEnterpriseChannel)) { $endDateText = $entry.SupportEndEnterprise }
    if (-not $endDateText -and -not $isLtscChannel -and -not $isEnterpriseChannel) { $endDateText = $entry.SupportEndConsumer }
    if (-not $endDateText) { $endDateText = $entry.SupportEndConsumer }
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
        NoAutoUpdate = $false
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
            # NoAutoUpdate=1 має пріоритет: політику "Configure Automatic Updates" вимкнено,
            # а старе значення AUOptions при цьому може лишитись у реєстрі.
            if ($autoUpdatePolicy.NoAutoUpdate -eq 1) {
                $agent.NoAutoUpdate = $true
                $agent.AutoUpdateOption = 'Автоматичні оновлення вимкнено політикою (NoAutoUpdate=1)'
            } elseif ($null -ne $autoUpdatePolicy.AUOptions) {
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
            $detectTime = [datetime]::MinValue
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
            $parsed = [datetime]::MinValue
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
            Status       = 'Failed'
            Method       = 'Microsoft.Update.Session (COM)'
            Error        = ''
            Updates      = @()
            TotalFound   = 0
            IsTruncated  = $false
        }

        try {
            $updateSession = New-Object -ComObject 'Microsoft.Update.Session'
            $updateSearcher = $updateSession.CreateUpdateSearcher()
            $searchOutput = $updateSearcher.Search('IsInstalled=0 and IsHidden=0')

            $collected = @()
            $totalFound = 0
            foreach ($update in $searchOutput.Updates) {
                $totalFound++

                # Понад ліміт оновлення не зберігаються детально, але враховуються в TotalFound.
                if ($totalFound -gt $MaxItems) { continue }

                # Назви категорій локалізовані, тому для класифікації зберігаємо ще й стабільні CategoryID.
                $categories = @()
                $categoryIds = @()
                try {
                    foreach ($updateCategory in $update.Categories) {
                        $categories += [string]$updateCategory.Name
                        $categoryIds += ([string]$updateCategory.CategoryID).ToLowerInvariant()
                    }
                } catch {
                    $categories = @()
                    $categoryIds = @()
                }

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
                    CategoryIds    = ($categoryIds -join ', ')
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
            $searchResult.TotalFound = $totalFound
            $searchResult.IsTruncated = ($totalFound -gt $MaxItems)
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

    # Нуль або від'ємне значення не має вимикати таймаут: повертаємось до значення за замовчуванням.
    if ($TimeoutSeconds -le 0) { $TimeoutSeconds = 180 }

    $canUseJob = ((Get-Command -Name 'Start-Job' -ErrorAction SilentlyContinue) -ne $null)

    if (-not $canUseJob) {
        $inlineResult = & $searchBlock $MaxItems
        return [ordered]@{
            Status  = [string]$inlineResult.Status
            Method  = [string]$inlineResult.Method
            Error   = [string]$inlineResult.Error
            Updates = @($inlineResult.Updates)
            TotalFound = [int]$inlineResult.TotalFound
            IsTruncated = [bool]$inlineResult.IsTruncated
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
                TotalFound = 0
                IsTruncated = $false
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
                TotalFound = 0
                IsTruncated = $false
                DurationSeconds = [Math]::Round(((Get-Date) - $startedAt).TotalSeconds, 1)
            }
        }

        return [ordered]@{
            Status  = [string]$jobResult.Status
            Method  = [string]$jobResult.Method
            Error   = [string]$jobResult.Error
            Updates = @($jobResult.Updates)
            TotalFound = [int]$jobResult.TotalFound
            IsTruncated = [bool]$jobResult.IsTruncated
            DurationSeconds = [Math]::Round(((Get-Date) - $startedAt).TotalSeconds, 1)
        }
    } catch {
        return [ordered]@{
            Status  = 'Failed'
            Method  = 'Microsoft.Update.Session (COM)'
            Error   = $_.Exception.Message
            Updates = @()
            TotalFound = 0
            IsTruncated = $false
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
        $osEditionId = ''
        try {
            $editionKey = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'EditionID' -ErrorAction SilentlyContinue
            if ($editionKey -and $editionKey.EditionID) { $osEditionId = [string]$editionKey.EditionID }
        } catch {
            Add-AuditError -Section 'Updates.Edition' -Message $_.Exception.Message
        }

        $script:Report.Updates.OS.EditionId = $osEditionId

        $supportInfo = Get-BravoOsSupportInfo -Caption $script:Report.OS.Caption -Build $script:Report.OS.Build -EditionId $osEditionId

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

                $securityUpdates = @($pendingUpdates | Where-Object { (Test-BravoUpdateClassification -Update $_ -Classification 'Security') -or $_.MsrcSeverity })
                $criticalUpdates = @($pendingUpdates | Where-Object { (Test-BravoUpdateClassification -Update $_ -Classification 'Critical') -or $_.MsrcSeverity -eq 'Critical' })
                $driverUpdates = @($pendingUpdates | Where-Object { Test-BravoUpdateClassification -Update $_ -Classification 'Driver' })
                $definitionUpdates = @($pendingUpdates | Where-Object { Test-BravoUpdateClassification -Update $_ -Classification 'Definition' })
                $downloadedUpdates = @($pendingUpdates | Where-Object { $_.IsDownloaded })

                $totalSizeMb = 0
                foreach ($pendingUpdate in $pendingUpdates) { $totalSizeMb += [double]$pendingUpdate.SizeMB }

                $totalFound = [int]$searchResult.TotalFound
                if ($totalFound -lt $pendingUpdates.Count) { $totalFound = $pendingUpdates.Count }

                $script:Report.Updates.Pending.Total = $totalFound
                $script:Report.Updates.Pending.Detailed = $pendingUpdates.Count
                $script:Report.Updates.Pending.IsTruncated = [bool]$searchResult.IsTruncated
                $script:Report.Updates.Pending.Security = $securityUpdates.Count
                $script:Report.Updates.Pending.Critical = $criticalUpdates.Count
                $script:Report.Updates.Pending.Driver = $driverUpdates.Count
                $script:Report.Updates.Pending.Definition = $definitionUpdates.Count
                $classifiedUpdates = @($pendingUpdates | Where-Object {
                    $_.MsrcSeverity -or
                    (Test-BravoUpdateClassification -Update $_ -Classification 'Security') -or
                    (Test-BravoUpdateClassification -Update $_ -Classification 'Critical') -or
                    (Test-BravoUpdateClassification -Update $_ -Classification 'Driver') -or
                    (Test-BravoUpdateClassification -Update $_ -Classification 'Definition')
                })
                $script:Report.Updates.Pending.Other = $pendingUpdates.Count - $classifiedUpdates.Count
                $script:Report.Updates.Pending.Downloaded = $downloadedUpdates.Count
                $script:Report.Updates.Pending.TotalSizeMB = [Math]::Round($totalSizeMb, 2)
                $script:Report.Updates.Pending.Items = $pendingUpdates

                $oldestRelease = @($pendingUpdates | Where-Object { $_.ReleasedOn } | Sort-Object ReleasedOn | Select-Object -First 1)
                if ($oldestRelease.Count -gt 0) {
                    $oldestDate = [datetime]::MinValue
                    if ([datetime]::TryParse($oldestRelease[0].ReleasedOn, [ref]$oldestDate)) {
                        $script:Report.Updates.Pending.OldestReleasedOn = $oldestRelease[0].ReleasedOn
                        $script:Report.Updates.Pending.MaxAgeDays = [int][Math]::Floor(((Get-Date) - $oldestDate).TotalDays)
                    }
                }

                if ($script:Report.Updates.Pending.IsTruncated) {
                    Write-Host "  $IconGear Оновлення: знайдено $totalFound, детально збережено $($pendingUpdates.Count)" -ForegroundColor Yellow
                    Add-AuditFinding -Severity 'WARNING' -Category 'Updates' -Message "Знайдено $totalFound оновлень; детальний список обмежено $($pendingUpdates.Count) записами" -Recommendation 'Категорії та обсяг пораховані лише за збереженими записами: перевірте машину вручну через Windows Update.'
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
        # Успішний пошук не перекривається помилкою пост-обробки: статус міняється лише якщо він ще не OK.
        if ($script:Report.Updates.Search.Status -ne 'OK') {
            $script:Report.Updates.Search.Status = 'Failed'
            $script:Report.Updates.Search.Error = $_.Exception.Message
        }
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
        if ($searchStatus -eq 'OK' -and [int]$script:Report.Updates.Pending.Critical -gt 0) { $updatesDetails += "critical: $($script:Report.Updates.Pending.Critical)" }
        if ($script:Report.Updates.Installed.LastInstalledOn) { $updatesDetails += "останнє: $($script:Report.Updates.Installed.LastInstalledOn)" }
        if ($script:Report.Updates.PendingReboot.Required) { $updatesDetails += 'потрібне перезавантаження' }
        $updatesMetric.Details = ($updatesDetails -join ', ')

        $pendingCritical = [int]$script:Report.Updates.Pending.Critical

        $updatesMetric.Status = if ($script:Report.Updates.OS.SupportStatus -eq 'EndOfSupport' -or $pendingSecurity -gt 0 -or $pendingCritical -gt 0) {
            'CRITICAL'
        } elseif ($pendingTotal -gt 0 -or $script:Report.Updates.PendingReboot.Required -or $script:Report.Updates.OS.SupportStatus -in @('EndingSoon','Unknown') -or $searchStatus -notin @('OK','Skipped')) {
            'WARNING'
        } else {
            'OK'
        }
    } catch {
        Add-AuditError -Section 'Updates.Metric' -Message $_.Exception.Message
    }
}
