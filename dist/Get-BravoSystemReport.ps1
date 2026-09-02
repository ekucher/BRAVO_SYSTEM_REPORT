<#
    BRAVO SYSTEM REPORT
    Згенерований монолітний runtime-скрипт.
    GeneratedAt: 2026-09-02 23:36:49

    УВАГА:
    Не редагуйте цей файл вручну.
    Зміни потрібно вносити у модулі src\*.ps1 і виконувати build.
#>


# ============================================================
# MODULE: src/00-Header.ps1
# ============================================================

# MODULE: 00-Header.ps1


# ============================================================
# MODULE: src/05-Params.ps1
# ============================================================

# MODULE: 05-Params.ps1
# Параметри запуску BRAVO SYSTEM REPORT.
# Цей файл підключається build-скриптом перед основною runtime-логікою.
[CmdletBinding()]
param(
    [ValidateSet('Quick','Full','Deep','Forensic')]
    [string]$Profile = 'Forensic',

    [string]$OutputPath = '',

    [switch]$JSONOnly,
    [switch]$CSV,
    [switch]$Zip = $true,
    [switch]$NoZip,
    [switch]$NoEmoji,
    [switch]$NoElevate,
    [switch]$NoPause,
    [switch]$NoOpenFolder,
    [switch]$SkipElevation,
    [switch]$SkipPublicIP,
    [switch]$SkipGeoIP,
    [switch]$Offline,
    [switch]$Strict,
    [switch]$Sanitize,
    [ValidateSet('Basic','Strict')]
    [string]$SanitizeLevel = 'Basic',

    [int]$EventLogDays = 0,

    [switch]$SkipUpdateSearch,
    [int]$UpdateSearchTimeoutSec = 180,

    [string]$EmailTo,
    [string]$EmailFrom = "systemaudit@$($env:COMPUTERNAME).local",
    [string]$SmtpServer = '',

    [switch]$ExportPdf
)


# ============================================================
# MODULE: src/10-Core.ps1
# ============================================================

# MODULE: 10-Core.ps1
# Базові helper-функції BRAVO SYSTEM REPORT.
# Цей файл підключається build-скриптом перед основною runtime-логікою.

function Test-BravoUsableIPv4Address {
    [CmdletBinding()]
    param(
        [string]$Address
    )

    if ([string]::IsNullOrWhiteSpace($Address)) {
        return $false
    }

    [System.Net.IPAddress]$parsedAddress = $null

    if (-not [System.Net.IPAddress]::TryParse($Address, [ref]$parsedAddress)) {
        return $false
    }

    if ($parsedAddress.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        return $false
    }

    if ($Address -eq "0.0.0.0") {
        return $false
    }

    if ($Address -like "127.*") {
        return $false
    }

    if ($Address -like "169.254.*") {
        return $false
    }

    return $true
}

function Get-BravoPrimaryNetworkInterface {
    [CmdletBinding()]
    param()

    try {
        if ((Get-Command Get-NetRoute -ErrorAction SilentlyContinue) -and
            (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) -and
            (Get-Command Get-NetIPConfiguration -ErrorAction SilentlyContinue) -and
            (Get-Command Get-NetIPInterface -ErrorAction SilentlyContinue)) {

            $routes = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction Stop |
                Where-Object {
                    $_.InterfaceIndex -and
                    $_.NextHop -and
                    $_.NextHop -ne "0.0.0.0"
                } |
                ForEach-Object {
                    $ipInterface = Get-NetIPInterface -AddressFamily IPv4 -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue |
                        Select-Object -First 1

                    $interfaceMetric = 9999

                    if ($ipInterface -and $null -ne $ipInterface.InterfaceMetric) {
                        $interfaceMetric = [int]$ipInterface.InterfaceMetric
                    }

                    [pscustomobject]@{
                        Route           = $_
                        InterfaceIndex  = [int]$_.InterfaceIndex
                        InterfaceAlias  = $_.InterfaceAlias
                        NextHop         = $_.NextHop
                        RouteMetric     = [int]$_.RouteMetric
                        InterfaceMetric = $interfaceMetric
                        TotalMetric     = ([int]$_.RouteMetric + $interfaceMetric)
                    }
                } |
                Sort-Object TotalMetric, RouteMetric, InterfaceMetric, InterfaceIndex

            foreach ($routeInfo in $routes) {
                $adapter = Get-NetAdapter -InterfaceIndex $routeInfo.InterfaceIndex -ErrorAction SilentlyContinue |
                    Select-Object -First 1

                if (-not $adapter) {
                    continue
                }

                if ($adapter.Status -ne "Up") {
                    continue
                }

                if (-not $adapter.HardwareInterface) {
                    continue
                }

                $ipConfig = Get-NetIPConfiguration -InterfaceIndex $routeInfo.InterfaceIndex -ErrorAction SilentlyContinue

                if (-not $ipConfig -or -not $ipConfig.IPv4Address) {
                    continue
                }

                foreach ($ipv4 in @($ipConfig.IPv4Address)) {
                    if ($ipv4.IPAddress -and (Test-BravoUsableIPv4Address -Address $ipv4.IPAddress)) {
                        return [pscustomobject]@{
                            IPv4                 = $ipv4.IPAddress
                            InterfaceIndex       = $routeInfo.InterfaceIndex
                            InterfaceAlias       = $adapter.Name
                            InterfaceDescription = $adapter.InterfaceDescription
                            Gateway              = $routeInfo.NextHop
                            RouteMetric          = $routeInfo.RouteMetric
                            InterfaceMetric      = $routeInfo.InterfaceMetric
                            TotalMetric          = $routeInfo.TotalMetric
                            HardwareInterface    = $adapter.HardwareInterface
                            SelectionMethod      = "DefaultRoutePhysicalAdapter"
                        }
                    }
                }
            }

            foreach ($routeInfo in $routes) {
                $ipConfig = Get-NetIPConfiguration -InterfaceIndex $routeInfo.InterfaceIndex -ErrorAction SilentlyContinue

                if (-not $ipConfig -or -not $ipConfig.IPv4Address) {
                    continue
                }

                foreach ($ipv4 in @($ipConfig.IPv4Address)) {
                    if ($ipv4.IPAddress -and (Test-BravoUsableIPv4Address -Address $ipv4.IPAddress)) {
                        return [pscustomobject]@{
                            IPv4                 = $ipv4.IPAddress
                            InterfaceIndex       = $routeInfo.InterfaceIndex
                            InterfaceAlias       = $routeInfo.InterfaceAlias
                            InterfaceDescription = ""
                            Gateway              = $routeInfo.NextHop
                            RouteMetric          = $routeInfo.RouteMetric
                            InterfaceMetric      = $routeInfo.InterfaceMetric
                            TotalMetric          = $routeInfo.TotalMetric
                            HardwareInterface    = $false
                            SelectionMethod      = "DefaultRouteFallbackAdapter"
                        }
                    }
                }
            }
        }
    } catch {
        # Свідомо ігноруємо: сучасний Get-NetRoute/Get-NetAdapter шлях недоступний
        # або впав (наприклад, немає модуля NetTCPIP) — нижче є CIM/WMI fallback.
    }

    try {
        $adapter = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction Stop |
            Where-Object {
                $_.DefaultIPGateway -and $_.IPAddress
            } |
            Sort-Object IPConnectionMetric, InterfaceIndex |
            Select-Object -First 1

        if ($adapter -and $adapter.IPAddress) {
            foreach ($address in @($adapter.IPAddress)) {
                if (Test-BravoUsableIPv4Address -Address $address) {
                    return [pscustomobject]@{
                        IPv4                 = $address
                        InterfaceIndex       = $adapter.InterfaceIndex
                        InterfaceAlias       = ""
                        InterfaceDescription = $adapter.Description
                        Gateway              = ($adapter.DefaultIPGateway -join ", ")
                        RouteMetric          = $null
                        InterfaceMetric      = $adapter.IPConnectionMetric
                        TotalMetric          = $adapter.IPConnectionMetric
                        HardwareInterface    = $null
                        SelectionMethod      = "CimDefaultGatewayFallback"
                    }
                }
            }
        }
    } catch {
        # Свідомо ігноруємо: обидва методи (NetAdapter та CIM) недоступні —
        # повертаємо $null, виклик нижче трактує це як "primary interface не знайдено".
    }

    return $null
}

function Move-BravoIPv4ToFront {
    [CmdletBinding()]
    param(
        [string[]]$IPv4 = @(),
        [string]$PrimaryIPv4 = ""
    )

    $cleanIPv4 = @(
        $IPv4 |
            Where-Object { Test-BravoUsableIPv4Address -Address $_ } |
            Select-Object -Unique
    )

    if ([string]::IsNullOrWhiteSpace($PrimaryIPv4)) {
        return @($cleanIPv4)
    }

    if (-not (Test-BravoUsableIPv4Address -Address $PrimaryIPv4)) {
        return @($cleanIPv4)
    }

    $orderedIPv4 = New-Object System.Collections.Generic.List[string]
    $orderedIPv4.Add($PrimaryIPv4) | Out-Null

    foreach ($address in $cleanIPv4) {
        if ($address -ne $PrimaryIPv4) {
            $orderedIPv4.Add($address) | Out-Null
        }
    }

    return @($orderedIPv4)
}
function Get-BravoAllUsableIPv4AddressList {
    [CmdletBinding()]
    param()

    $result = New-Object System.Collections.Generic.List[string]

    try {
        $configs = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction Stop

        foreach ($config in $configs) {
            if (-not $config.IPAddress) {
                continue
            }

            foreach ($address in @($config.IPAddress)) {
                if (-not (Test-BravoUsableIPv4Address -Address $address)) {
                    continue
                }

                if ($result -notcontains $address) {
                    $result.Add($address) | Out-Null
                }
            }
        }
    } catch {
        # Свідомо ігноруємо: CIM-запит недоступний на цій машині —
        # повертаємо порожній список замість переривання збору мережевих даних.
    }

    return @($result)
}

function Get-BravoPublicIPv4Address {
    [CmdletBinding()]
    param(
        [int]$TimeoutSec = 5
    )

    $providers = @(
        [pscustomobject]@{
            Name = "ipify"
            Uri  = "https://api.ipify.org"
        },
        [pscustomobject]@{
            Name = "AmazonCheckIp"
            Uri  = "https://checkip.amazonaws.com"
        },
        [pscustomobject]@{
            Name = "ifconfig.me"
            Uri  = "https://ifconfig.me/ip"
        }
    )

    foreach ($provider in $providers) {
        try {
            $response = Invoke-RestMethod -Uri $provider.Uri -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
            $address = ([string]$response).Trim()

            if (Test-BravoUsableIPv4Address -Address $address) {
                return [pscustomobject]@{
                    IPv4        = $address
                    Provider    = $provider.Name
                    Uri         = $provider.Uri
                    CheckedAt   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    Status      = "Detected"
                    Error       = ""
                }
            }
        } catch {
            continue
        }
    }

    return [pscustomobject]@{
        IPv4        = $null
        Provider    = ""
        Uri         = ""
        CheckedAt   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Status      = "Unavailable"
        Error       = "Public IPv4 не визначено через доступні HTTPS endpoints."
    }
}
function Get-BravoPublicIPv4ProviderInfo {
    [CmdletBinding()]
    param(
        [string]$PublicIPv4,
        [int]$TimeoutSec = 5
    )

    $checkedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    if (-not (Test-BravoUsableIPv4Address -Address $PublicIPv4)) {
        return [pscustomobject]@{
            IPAddress       = $PublicIPv4
            LookupProvider  = ""
            ISP             = ""
            Organization    = ""
            ASN             = ""
            Country         = ""
            Region          = ""
            City            = ""
            Timezone        = ""
            CheckedAt       = $checkedAt
            Status          = "Skipped"
            Error           = "Public IPv4 is empty or invalid."
        }
    }

    $uri = "https://ipapi.co/$PublicIPv4/json/"

    try {
        $response = Invoke-RestMethod `
            -Uri $uri `
            -UseBasicParsing `
            -TimeoutSec $TimeoutSec `
            -Headers @{ "User-Agent" = "BRAVO-SYSTEM-REPORT" } `
            -ErrorAction Stop

        $org = [string]$response.org

        return [pscustomobject]@{
            IPAddress       = [string]$response.ip
            LookupProvider  = "ipapi.co"
            ISP             = $org
            Organization    = $org
            ASN             = [string]$response.asn
            Country         = [string]$response.country_name
            Region          = [string]$response.region
            City            = [string]$response.city
            Timezone        = [string]$response.timezone
            CheckedAt       = $checkedAt
            Status          = "Detected"
            Error           = ""
        }
    } catch {
        return [pscustomobject]@{
            IPAddress       = $PublicIPv4
            LookupProvider  = "ipapi.co"
            ISP             = ""
            Organization    = ""
            ASN             = ""
            Country         = ""
            Region          = ""
            City            = ""
            Timezone        = ""
            CheckedAt       = $checkedAt
            Status          = "Unavailable"
            Error           = $_.Exception.Message
        }
    }
}


# ============================================================
# MODULE: src/20-ReportModel.ps1
# ============================================================

# MODULE: 20-ReportModel.ps1
# Створення базової моделі звіту BRAVO SYSTEM REPORT.

function New-BravoReportModel {
    [CmdletBinding()]
    param()

return [ordered]@{
    SchemaVersion = '0.6.19'
    ScriptVersion = $ScriptVersion
    Profile = $Profile
    Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    ComputerName = $env:COMPUTERNAME
    Elevated = $isAdmin
    Status = 'OK'
    StatusReason = 'Початковий стан до розрахунку Health Score'
    OutputPath = ''
    GeneratedFiles = @()
    Meta = [ordered]@{
        StartedAt = $ScriptStartTime.ToString('yyyy-MM-dd HH:mm:ss')
        PowerShellHost = $Host.Name
        UserName = [Environment]::UserName
        UserDomainName = [Environment]::UserDomainName
        UseCim = $script:UseCim
        EventLogDays = $EventLogDays
    }
    Dashboard = [ordered]@{
        Header = [ordered]@{
            ComputerName = $env:COMPUTERNAME
            GeneratedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            UptimeText = ''
            Status = 'OK'
            StatusReason = 'Початковий стан до розрахунку Health Score'
        }
        Metrics = [ordered]@{
            CPU = [ordered]@{ Title='CPU'; Value=''; Status='OK'; Details='' }
            RAM = [ordered]@{ Title='RAM'; Value=''; Status='OK'; Details='' }
            Disk = [ordered]@{ Title='Disk'; Value=''; Status='OK'; Details='' }
            OS = [ordered]@{ Title='OS'; Value=''; Status='OK'; Details='' }
            Updates = [ordered]@{ Title='Updates'; Value=''; Status='OK'; Details='' }
        }
        Tabs = [ordered]@{
            General = $true
            OS = $true
            Hardware = $true
            Network = $true
            Security = $true
            Services = $true
            Software = $true
            Updates = $true
        }
    }
    Health = [ordered]@{
        Score = 100
        Status = 'OK'
        Findings = @()
    }
    OS = [ordered]@{ Caption=''; Version=''; Build=''; Architecture=''; InstallDate=''; LastBootUpTime=''; UptimeDays=0; UptimeHours=0 }
    PowerShell = [ordered]@{
        Version=$PSVersionTable.PSVersion.ToString(); Edition=$PSVersionTable.PSEdition; ExecutionPolicy=(Get-ExecutionPolicy).ToString()
        Core7Installed=$false; Core7Version=''; Core7LatestKnown='7.4'; Core7UpdateAvailable=$false
    }
    DotNet = [ordered]@{ v4='Not Installed'; ReleaseKey=0; LatestKnownVersion='4.8.1'; UpdateAvailable=$false }
    WindowsUpdate = [ordered]@{
        ServiceStatus = ''
        InstalledHotFixCount = 0
        InstalledHotFixes = @()
        LastInstalledHotFix = ''
        LastInstallDate = ''
        DaysSinceLastInstall = -1
        PendingRebootRequired = $false
        PendingUpdates = @()
        PendingCount = 0
        PendingCritical = 0
        PendingSecurity = 0
        SearchStatus = 'NotChecked'
        SearchError = ''
    }
    BIOS = [ordered]@{ Version=''; SerialNumber=''; ReleaseDate='' }
    Virtualization = [ordered]@{ IsVirtual=$false; Hypervisor='' }
    Hardware = [ordered]@{
        ComputerSystem = [ordered]@{ Manufacturer=''; Model=''; Domain=''; TotalPhysicalMemoryGB=0; ChassisType=''; ChassisTypeCode=$null }
        CPU = [ordered]@{ Name=''; Cores=0; LogicalProcessors=0; MaxClockSpeedMHz=0; LoadPercent=0 }
        RAM = [ordered]@{ TotalGB=0; TotalVisibleMemoryGB=0; FreeGB=0; UsedGB=0; UsedPercent=0; Source=''; Modules=@() }
        Disks = [ordered]@{ FreePercent=0; TotalGB=0; FreeGB=0; Volumes=@(); PhysicalDisks=@() }
        Motherboard = [ordered]@{ Manufacturer=''; Product=''; SerialNumber=''; Version='' }
        GPU = @()
        Monitors = @()
    }
    Network = [ordered]@{
        General = [ordered]@{ Hostname=''; Domain='' }
        IP = [ordered]@{
            IPv4=@()
            PrimaryIPv4=''
            PrimaryInterface=$null
            PublicIPv4=''
            PublicIPv4Provider=''
            PublicIPv4LookupProvider=''
            PublicIPv4ISP=''
            PublicIPv4Organization=''
            PublicIPv4ASN=''
            PublicIPv4Country=''
            PublicIPv4Region=''
            PublicIPv4City=''
            PublicIPv4Timezone=''
            PublicIPv4ProviderInfoCheckedAt=''
            PublicIPv4ProviderInfoStatus='NotChecked'
            PublicIPv4ProviderInfoError=''
            PublicIPv4CheckedAt=''
            PublicIPv4Status='NotChecked'
        }
        Routing = [ordered]@{ DefaultGateway=''; DefaultGateways=@(); DNSServers=@(); DNSSuffixSearchOrder=@(); RoutingTable=@() }
        Adapters = @()
        Connections = [ordered]@{ Established=0; Listening=0; ListeningPorts=@(); EstablishedConnections=@() }
        ARP = @()
        WinHttpProxy = [ordered]@{ RawOutput=@(); Status='NotChecked'; Error='' }
        SmbShares = @()
    }
    Security = [ordered]@{
        UAC=[ordered]@{
            Enabled=$false
            ConsentPromptBehaviorAdminCode=$null
            ConsentPromptBehaviorAdminText=''
            ConsentPromptBehaviorUserCode=$null
            ConsentPromptBehaviorUserText=''
            PromptOnSecureDesktop=$null
            FilterAdministratorToken=$null
        }
        RemoteAccess=[ordered]@{
            RDPEnabled=$false
            NLAEnabled=$null
            Port=$null
            FirewallScope=''
            FirewallProfiles=''
            AllowedUsers=@()
        }
        Antivirus=[ordered]@{Product=''}
        Firewall=[ordered]@{}
        SecureBoot = [ordered]@{
            Supported = $null
            Enabled = $null
            Status = 'NotChecked'
            Error = ''
        }
        TPM = [ordered]@{
            Present = $null
            Ready = $null
            Enabled = $null
            Activated = $null
            ManufacturerId = ''
            ManufacturerVersion = ''
            SpecVersion = ''
            Status = 'NotChecked'
            Error = ''
        }
        SMBv1 = [ordered]@{
            Enabled = $null
            Status = 'NotChecked'
            Error = ''
        }
        TLS = [ordered]@{
            Protocols = @()
        }
        Defender = [ordered]@{
            Available = $null
            AMServiceEnabled = $null
            AntivirusEnabled = $null
            RealTimeProtectionEnabled = $null
            BehaviorMonitorEnabled = $null
            AntivirusSignatureVersion = ''
            AntivirusSignatureLastUpdated = ''
            AntivirusSignatureAgeDays = $null
            AMEngineVersion = ''
            AMProductVersion = ''
            Status = 'NotChecked'
            Error = ''
        }
        WinRM = [ordered]@{
            ServiceStatus = ''
            Listeners = @()
            Auth = [ordered]@{ Basic = $null; Kerberos = $null; Negotiate = $null; Certificate = $null; CredSSP = $null }
            Status = 'NotChecked'
            Error = ''
        }
        SMB = [ordered]@{
            ServerSigningRequired = $null
            ServerSigningEnabled = $null
            ClientSigningRequired = $null
            InsecureGuestLogonsEnabled = $null
            Status = 'NotChecked'
            Error = ''
        }
        PasswordPolicy = [ordered]@{
            MinPasswordLength = $null
            MaxPasswordAgeDays = $null
            MinPasswordAgeDays = $null
            PasswordHistoryLength = $null
            LockoutThreshold = $null
            LockoutDurationMinutes = $null
            LockoutObservationWindowMinutes = $null
            Status = 'NotChecked'
            Error = ''
        }
        AuditPolicy = [ordered]@{
            Subcategories = @()
            TotalCount = 0
            Status = 'NotChecked'
            Error = ''
        }
        Autoruns = @()
        ScheduledTasks = @()
    }
    Users = [ordered]@{ LocalAdmins=@() }
    Processes = [ordered]@{ Total=0; TopMemory=@() }
    Services = [ordered]@{ Total=0; Running=0; AutomaticStopped=@() }
    EventLogs = [ordered]@{ Days=$EventLogDays; SystemErrors=0; SystemWarnings=0; SystemErrors24h=0; SystemWarnings24h=0; TopErrorSources=@(); LogSummaries=@(); HardwareDiagnostics=@() }
    # Software.WindowsFeatures та USBDevices: заплановані, ще не реалізовані
    # колектори (жоден src/*.ps1 їх наразі не заповнює) — завжди порожній
    # масив у звіті, не помилка збору.
    Software = [ordered]@{ Installed=@(); WindowsFeatures=@() }
    Updates = [ordered]@{
        OS = [ordered]@{
            Product=''
            DisplayVersion=''
            RegistryDisplayVersion=''
            EditionId=''
            UBR=''
            FullBuild=''
            Channel=''
            SupportEndDate=''
            DaysToEndOfSupport=$null
            SupportStatus='Unknown'
            LifecycleDataUpdatedAt=''
        }
        WindowsUpdate = [ordered]@{
            ServiceStatus=''
            ServiceStartType=''
            AutoUpdateOption=''
            NoAutoUpdate=$false
            LastDetectSuccess=''
            LastInstallSuccess=''
            DaysSinceLastDetect=$null
            ManagedByWSUS=$false
            WSUSServer=''
        }
        PendingReboot = [ordered]@{ Required=$false; Reasons=@() }
        Search = [ordered]@{ Status='NotChecked'; Method=''; Error=''; CheckedAt=''; DurationSeconds=0 }
        Pending = [ordered]@{
            Total=0
            Detailed=0
            IsTruncated=$false
            Security=0
            Critical=0
            Driver=0
            Definition=0
            Other=0
            Downloaded=0
            TotalSizeMB=0
            OldestReleasedOn=''
            MaxAgeDays=$null
            Items=@()
        }
        Installed = [ordered]@{ Total=0; LastInstalledOn=''; DaysSinceLastUpdate=$null; InstalledLast30Days=0; Recent=@() }
    }
    USBDevices = @()
    # CollectionErrors — помилки ЗБОРУ даних (WMI/CIM/реєстр недоступні тощо):
    # властивість аудитованої машини, впливає на Health Score.
    # ExportErrors — помилки ЗАПИСУ звітів (JSON/HTML/CSV/ZIP/Email): проблема
    # самого інструмента, НЕ впливає на Health Score, але впливає на exit code.
    CollectionErrors = @()
    ExportErrors = @()
}
}


# ============================================================
# MODULE: src/30-Collectors-OS.ps1
# ============================================================

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

# ============================================================
# MODULE: src/31-Collectors-Hardware.ps1
# ============================================================

# MODULE: 31-Collectors-Hardware.ps1
# Збір базової інформації про апаратне забезпечення: CPU, RAM, ComputerSystem/
# chassis type, Motherboard, GPU, Monitors.

# Чиста функція: EDID-текстові поля WmiMonitorID (ManufacturerName/
# UserFriendlyName/SerialNumberID) приходять як масив UInt16-кодів символів
# з нульовим заповненням у хвості фіксованої довжини — конвертує в звичайний
# рядок, відкидаючи нульові байти.
function ConvertFrom-BravoWmiMonitorCharArray {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [array]$Value
    )

    if (-not $Value) { return '' }
    return -join ([char[]]($Value | Where-Object { $_ -ne 0 }))
}

# Чиста функція: SMBIOS chassis type code (Win32_SystemEnclosure.ChassisTypes)
# -> людяний опис. Повний перелік значно довший (SMBIOS specification,
# System Enclosure or Chassis Types), тут — найпоширеніші коди для робочих
# станцій/ноутбуків/серверів; невідомий код повертається як "Unknown ($code)",
# а не помилка.
function Get-BravoChassisTypeText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [Nullable[int]]$ChassisTypeCode
    )

    if ($null -eq $ChassisTypeCode) { return 'Unknown' }

    $chassisTypeMap = @{
        1 = 'Other'; 2 = 'Unknown'; 3 = 'Desktop'; 4 = 'Low Profile Desktop'
        5 = 'Pizza Box'; 6 = 'Mini Tower'; 7 = 'Tower'; 8 = 'Portable'
        9 = 'Laptop'; 10 = 'Notebook'; 11 = 'Hand Held'; 12 = 'Docking Station'
        13 = 'All in One'; 14 = 'Sub Notebook'; 15 = 'Space-saving'; 16 = 'Lunch Box'
        17 = 'Main System Chassis'; 18 = 'Expansion Chassis'; 19 = 'SubChassis'
        20 = 'Bus Expansion Chassis'; 21 = 'Peripheral Chassis'; 22 = 'Storage Chassis'
        23 = 'Rack Mount Chassis'; 24 = 'Sealed-case PC'; 30 = 'Tablet'
        31 = 'Convertible'; 32 = 'Detachable'
    }

    if ($chassisTypeMap.ContainsKey($ChassisTypeCode)) { return $chassisTypeMap[$ChassisTypeCode] }
    return "Unknown ($ChassisTypeCode)"
}

# --- P1: централізовані CPU/RAM thresholds ---
# Єдине джерело порогів для Dashboard-плиток CPU/RAM і для Health.Findings —
# щоб перевантаження CPU/RAM (на відміну від попередньої поведінки) впливало
# на Health Score і потрапляло у Findings tab, а не лише в колір dashboard-картки.
function Get-BravoHardwareThresholds {
    [CmdletBinding()]
    param()

    return [ordered]@{
        CpuWarningPercent = 75
        CpuCriticalPercent = 90
        RamWarningPercent = 85
        RamCriticalPercent = 95
    }
}

function Get-BravoHardwareAudit {
    [CmdletBinding()]
    param()

    # --- Апаратне забезпечення ---
    try {
        $cpuInfo = Get-AuditObject -ClassName 'Win32_Processor' -First
        $computerSystemInfo = Get-AuditObject -ClassName 'Win32_ComputerSystem' -First
        $osInfo = Get-AuditObject -ClassName 'Win32_OperatingSystem' -First

        $script:Report.Hardware.ComputerSystem.Manufacturer = $computerSystemInfo.Manufacturer
        $script:Report.Hardware.ComputerSystem.Model = $computerSystemInfo.Model
        $script:Report.Hardware.ComputerSystem.Domain = $computerSystemInfo.Domain
        $script:Report.Hardware.ComputerSystem.TotalPhysicalMemoryGB = [Math]::Round($computerSystemInfo.TotalPhysicalMemory / 1GB, 2)

        $script:Report.Hardware.CPU.Name = ($cpuInfo.Name | ForEach-Object { $_.Trim() })
        $script:Report.Hardware.CPU.Cores = $cpuInfo.NumberOfCores
        $script:Report.Hardware.CPU.LogicalProcessors = $cpuInfo.NumberOfLogicalProcessors
        $script:Report.Hardware.CPU.MaxClockSpeedMHz = $cpuInfo.MaxClockSpeed

        # LoadPercentage — опціональна властивість WMI, на частині VM (особливо
        # одразу після старту) повертає $null. Це очікуваний, не помилковий стан
        # (не CollectionError) — трапляється регулярно на щойно піднятих VM,
        # включно з CI-раннерами, і не мало б штрафувати Health Score чи ламати
        # інваріант "CollectionErrors=0" в EndToEnd-тесті на кожному такому
        # прогоні. [Math]::Round($null) мовчки стає 0 — залишаємо цю поведінку,
        # 0% тут означає "невідомо", а не підтверджений нуль.
        $cpuLoadAverage = ($cpuInfo.LoadPercentage | Measure-Object -Average).Average
        if ($null -ne $cpuLoadAverage) {
            $script:Report.Hardware.CPU.LoadPercent = [Math]::Round($cpuLoadAverage)
        }

        $totalPhysicalMemoryGB = [Math]::Round($computerSystemInfo.TotalPhysicalMemory / 1GB, 2)
        $script:Report.Hardware.RAM.TotalGB = $totalPhysicalMemoryGB
        $script:Report.Hardware.RAM.Source = 'Win32_OperatingSystem.TotalVisibleMemorySize/FreePhysicalMemory'

        if ($osInfo.TotalVisibleMemorySize -gt 0) {
            $totalVisibleMemoryGB = [Math]::Round(($osInfo.TotalVisibleMemorySize * 1KB) / 1GB, 2)
            $freeMemoryGB = [Math]::Round(($osInfo.FreePhysicalMemory * 1KB) / 1GB, 2)
            $usedMemoryGB = [Math]::Round(($totalVisibleMemoryGB - $freeMemoryGB), 2)
            $usedPercent = [Math]::Round((($totalVisibleMemoryGB - $freeMemoryGB) / $totalVisibleMemoryGB) * 100, 2)

            if ($usedMemoryGB -lt 0) { $usedMemoryGB = 0 }
            if ($usedPercent -lt 0) { $usedPercent = 0 }
            if ($usedPercent -gt 100) { $usedPercent = 100 }

            $script:Report.Hardware.RAM.TotalVisibleMemoryGB = $totalVisibleMemoryGB
            $script:Report.Hardware.RAM.FreeGB = $freeMemoryGB
            $script:Report.Hardware.RAM.UsedGB = $usedMemoryGB
            $script:Report.Hardware.RAM.UsedPercent = $usedPercent
        }

        $hardwareThresholds = Get-BravoHardwareThresholds

        $script:Report.Dashboard.Metrics.CPU.Value = "$($script:Report.Hardware.CPU.LoadPercent)%"
        $script:Report.Dashboard.Metrics.CPU.Details = "$($script:Report.Hardware.CPU.Cores) ядер / $($script:Report.Hardware.CPU.LogicalProcessors) потоків"
        $script:Report.Dashboard.Metrics.CPU.Status = if ($script:Report.Hardware.CPU.LoadPercent -ge $hardwareThresholds.CpuCriticalPercent) { 'CRITICAL' } elseif ($script:Report.Hardware.CPU.LoadPercent -ge $hardwareThresholds.CpuWarningPercent) { 'WARNING' } else { 'OK' }

        $script:Report.Dashboard.Metrics.RAM.Value = "$($script:Report.Hardware.RAM.UsedPercent)%"
        $script:Report.Dashboard.Metrics.RAM.Details = "$($script:Report.Hardware.RAM.UsedGB) GB використано з $($script:Report.Hardware.RAM.TotalVisibleMemoryGB) GB"
        $script:Report.Dashboard.Metrics.RAM.Status = if ($script:Report.Hardware.RAM.UsedPercent -ge $hardwareThresholds.RamCriticalPercent) { 'CRITICAL' } elseif ($script:Report.Hardware.RAM.UsedPercent -ge $hardwareThresholds.RamWarningPercent) { 'WARNING' } else { 'OK' }

        # CPU LoadPercent буває $null (щойно піднята VM — див. коментар вище,
        # це не помилка), тож findings пишемо лише коли значення реально відоме.
        if ($null -ne $script:Report.Hardware.CPU.LoadPercent) {
            if ($script:Report.Hardware.CPU.LoadPercent -ge $hardwareThresholds.CpuCriticalPercent) {
                Add-AuditFinding -Severity 'CRITICAL' -Category 'Hardware.CPU' -Message "Завантаження CPU критично високе: $($script:Report.Hardware.CPU.LoadPercent)%." -Recommendation 'Перевірте процеси з найбільшим споживанням CPU (Processes.TopCPU) — можливий runaway-процес або недостатня продуктивність для навантаження.'
            } elseif ($script:Report.Hardware.CPU.LoadPercent -ge $hardwareThresholds.CpuWarningPercent) {
                Add-AuditFinding -Severity 'WARNING' -Category 'Hardware.CPU' -Message "Завантаження CPU підвищене: $($script:Report.Hardware.CPU.LoadPercent)%." -Recommendation 'Спостерігайте за динамікою навантаження CPU, за потреби перевірте Processes.TopCPU.'
            }
        }

        if ($script:Report.Hardware.RAM.UsedPercent -ge $hardwareThresholds.RamCriticalPercent) {
            Add-AuditFinding -Severity 'CRITICAL' -Category 'Hardware.RAM' -Message "Використання RAM критично високе: $($script:Report.Hardware.RAM.UsedPercent)% ($($script:Report.Hardware.RAM.UsedGB) GB з $($script:Report.Hardware.RAM.TotalVisibleMemoryGB) GB)." -Recommendation 'Перевірте процеси з найбільшим споживанням пам''яті (Processes.TopMemory) — можливий memory leak або недостатньо RAM для навантаження.'
        } elseif ($script:Report.Hardware.RAM.UsedPercent -ge $hardwareThresholds.RamWarningPercent) {
            Add-AuditFinding -Severity 'WARNING' -Category 'Hardware.RAM' -Message "Використання RAM підвищене: $($script:Report.Hardware.RAM.UsedPercent)% ($($script:Report.Hardware.RAM.UsedGB) GB з $($script:Report.Hardware.RAM.TotalVisibleMemoryGB) GB)." -Recommendation 'Спостерігайте за динамікою використання RAM, за потреби перевірте Processes.TopMemory.'
        }

        if ($Profile -in @('Full','Deep','Forensic')) {
            try {
                $memoryModules = Get-AuditObject -ClassName 'Win32_PhysicalMemory'
                foreach ($module in $memoryModules) {
                    $script:Report.Hardware.RAM.Modules += [PSCustomObject]@{
                        BankLabel    = $module.BankLabel
                        DeviceLocator = $module.DeviceLocator
                        Manufacturer = $module.Manufacturer
                        PartNumber   = ($module.PartNumber | ForEach-Object { if ($_) { $_.Trim() } })
                        SerialNumber = $module.SerialNumber
                        CapacityGB   = [Math]::Round($module.Capacity / 1GB, 2)
                        SpeedMHz     = $module.Speed
                    }
                }
            } catch {
                Add-AuditError -Section 'Hardware.RAM.Modules' -Message $_.Exception.Message
            }

            try {
                $chassisInfo = Get-AuditObject -ClassName 'Win32_SystemEnclosure' -First
                if ($chassisInfo -and $chassisInfo.ChassisTypes -and $chassisInfo.ChassisTypes.Count -gt 0) {
                    $chassisTypeCode = [int]$chassisInfo.ChassisTypes[0]
                    $script:Report.Hardware.ComputerSystem.ChassisTypeCode = $chassisTypeCode
                    $script:Report.Hardware.ComputerSystem.ChassisType = Get-BravoChassisTypeText -ChassisTypeCode $chassisTypeCode
                }
            } catch {
                Add-AuditError -Section 'Hardware.ChassisType' -Message $_.Exception.Message
            }

            try {
                $baseBoardInfo = Get-AuditObject -ClassName 'Win32_BaseBoard' -First
                if ($baseBoardInfo) {
                    $script:Report.Hardware.Motherboard.Manufacturer = $baseBoardInfo.Manufacturer
                    $script:Report.Hardware.Motherboard.Product = $baseBoardInfo.Product
                    $script:Report.Hardware.Motherboard.SerialNumber = $baseBoardInfo.SerialNumber
                    $script:Report.Hardware.Motherboard.Version = $baseBoardInfo.Version
                }
            } catch {
                Add-AuditError -Section 'Hardware.Motherboard' -Message $_.Exception.Message
            }

            try {
                $videoControllers = Get-AuditObject -ClassName 'Win32_VideoController'
                foreach ($videoController in $videoControllers) {
                    $script:Report.Hardware.GPU += [PSCustomObject]@{
                        Name           = $videoController.Name
                        # AdapterRAM — 32-bit DWORD у WMI: для карт з >4 GB VRAM
                        # значення переповнюється/спотворюється (відома проблема
                        # Win32_VideoController, не баг цього колектора) —
                        # публікуємо як є, з приміткою в docs, а не намагаємось
                        # "виправити" здогадками.
                        AdapterRAMBytes = $videoController.AdapterRAM
                        DriverVersion  = $videoController.DriverVersion
                        VideoProcessor = $videoController.VideoProcessor
                        CurrentResolution = if ($videoController.CurrentHorizontalResolution -and $videoController.CurrentVerticalResolution) { "$($videoController.CurrentHorizontalResolution)x$($videoController.CurrentVerticalResolution)" } else { '' }
                        Status         = $videoController.Status
                    }
                }
            } catch {
                Add-AuditError -Section 'Hardware.GPU' -Message $_.Exception.Message
            }

            if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
                try {
                    # WmiMonitorID (namespace root\wmi) — EDID-дані фізичних
                    # моніторів, доступні лише через CIM/WMI (не WMI-класи в
                    # root\cimv2, тому не через Get-AuditObject/-UseCim wrapper).
                    # Текстові поля EDID приходять як масиви UInt16-кодів
                    # символів з нульовим заповненням у хвості — конвертуємо
                    # чистою функцією, щоб не тягнути нулі в рядок.
                    $monitorIds = Get-CimInstance -Namespace 'root\wmi' -ClassName 'WmiMonitorID' -ErrorAction Stop
                    $monitorParams = @{}
                    try {
                        Get-CimInstance -Namespace 'root\wmi' -ClassName 'WmiMonitorBasicDisplayParams' -ErrorAction Stop | ForEach-Object {
                            $monitorParams[$_.InstanceName] = $_
                        }
                    } catch {
                        # Фізичні розміри — необов'язковий бонус, відсутність
                        # цього класу не має валити збір моніторів взагалі.
                    }

                    foreach ($monitorId in $monitorIds) {
                        $displayParams = $monitorParams[$monitorId.InstanceName]
                        $script:Report.Hardware.Monitors += [PSCustomObject]@{
                            InstanceName        = $monitorId.InstanceName
                            Active              = $monitorId.Active
                            Manufacturer        = ConvertFrom-BravoWmiMonitorCharArray -Value $monitorId.ManufacturerName
                            Model               = ConvertFrom-BravoWmiMonitorCharArray -Value $monitorId.UserFriendlyName
                            SerialNumber        = ConvertFrom-BravoWmiMonitorCharArray -Value $monitorId.SerialNumberID
                            YearOfManufacture   = $monitorId.YearOfManufacture
                            WeekOfManufacture   = $monitorId.WeekOfManufacture
                            WidthCm             = if ($displayParams) { $displayParams.MaxHorizontalImageSize } else { $null }
                            HeightCm            = if ($displayParams) { $displayParams.MaxVerticalImageSize } else { $null }
                        }
                    }
                } catch {
                    # Namespace root\wmi/WmiMonitorID може бути недоступний
                    # (напр. віртуальна машина без реального дисплея, RDP-сесія
                    # без monitor EDID) — штатний стан, не помилка збору.
                }
            }
        }

        Write-Host "  $IconCpu CPU: $($script:Report.Hardware.CPU.Cores) ядер / $($script:Report.Hardware.CPU.LogicalProcessors) потоків ($($script:Report.Hardware.CPU.LoadPercent)%)" -ForegroundColor Green
        Write-Host "  $IconRam RAM: $($script:Report.Hardware.RAM.TotalGB) GB ($($script:Report.Hardware.RAM.UsedPercent)% використано)" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Hardware' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка апаратних даних: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ============================================================
# MODULE: src/32-Collectors-Storage.ps1
# ============================================================

# MODULE: 32-Collectors-Storage.ps1
# Збір інформації про диски, Storage Deep Audit та storage-ризики.

# --- P1: централізовані storage thresholds ---
# Єдине джерело порогів вільного місця для basic (Get-BravoStorageAudit)
# і deep (Get-BravoStorageRiskSummary) audit — щоб обидва шляхи узгоджено
# оцінювали один і той самий том і не породжували суперечливих findings.
function Get-BravoStorageThresholds {
    [CmdletBinding()]
    param()

    return [ordered]@{
        CriticalFreePercent      = 5
        WarningFreePercent       = 10
        SystemWarningFreePercent = 15
    }
}

# Чиста функція без побічних ефектів: за відсотком вільного місця повертає
# рівень ризику тому. CD-ROM/оптичні носії завжди 'Healthy' (read-only,
# "вільне місце" не є показником ризику — примонтований ISO завжди 0%).
function Get-BravoStorageFreeSpaceSeverity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [Nullable[double]]$FreePercent,
        [bool]$IsSystemDrive = $false,
        [string]$DriveType = ''
    )

    if ($null -eq $FreePercent) { return 'Unknown' }
    if ($DriveType -eq 'CD-ROM') { return 'Healthy' }

    $thresholds = Get-BravoStorageThresholds

    if ($FreePercent -lt $thresholds.CriticalFreePercent) { return 'Critical' }
    if ($FreePercent -lt $thresholds.WarningFreePercent) { return 'Warning' }
    if ($IsSystemDrive -and $FreePercent -lt $thresholds.SystemWarningFreePercent) { return 'SystemWarning' }

    return 'Healthy'
}

function Convert-BravoBytesToGB {
    param([Parameter(Mandatory = $false)]$Bytes)

    if ($null -eq $Bytes -or $Bytes -eq '') {
        return $null
    }

    try {
        return [Math]::Round(([double]$Bytes / 1GB), 2)
    } catch {
        return $null
    }
}

function Get-BravoStorageDeepAudit {
    # Заповнюються нижче в цій функції: CollectedAt, LogicalDisks, Volumes,
    # Disks, Partitions, PageFiles, BitLocker, ShadowCopies, StoragePools,
    # ReliabilityCounters, SmartPredictFailures (обидва — SMART/NVMe health,
    # можуть лишатись порожніми, якщо апаратура/драйвер не підтримує).
    #
    # НЕ реалізовано (завжди порожній масив @() — не заплановано окремо,
    # PhysicalDisks тут дублювало б $script:Report.Hardware.Disks.PhysicalDisks
    # — це різні поля з однаковою назвою в різних секціях моделі):
    # PhysicalDisks, StorageSubsystems.
    $storage = [ordered]@{
        CollectedAt  = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        LogicalDisks = @()
        Volumes      = @()
        Disks        = @()
        Partitions            = @()
        PhysicalDisks         = @()
        ReliabilityCounters   = @()
        BitLocker             = @()
        ShadowCopies          = @()
        StoragePools          = @()
        StorageSubsystems     = @()
        SmartPredictFailures  = @()
        PageFiles             = @()
    }

    try {
        $logicalDisks = Get-AuditObject -ClassName 'Win32_LogicalDisk' -Filter 'DriveType=3'
        foreach ($disk in $logicalDisks) {
            $freePercent = if ($disk.Size -gt 0) {
                [Math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)
            } else {
                $null
            }

            $storage.LogicalDisks += [PSCustomObject]@{
                DeviceID    = $disk.DeviceID
                VolumeName  = $disk.VolumeName
                FileSystem  = $disk.FileSystem
                TotalGB     = Convert-BravoBytesToGB $disk.Size
                FreeGB      = Convert-BravoBytesToGB $disk.FreeSpace
                FreePercent = $freePercent
                Compressed  = $disk.Compressed
            }
        }
    } catch {
        Add-AuditError -Section 'StorageDeep.LogicalDisks' -Message $_.Exception.Message
    }

    if (Get-Command Get-Volume -ErrorAction SilentlyContinue) {
        try {
            $volumes = Get-Volume -ErrorAction Stop
            foreach ($volume in $volumes) {
                $freePercent = if ($volume.Size -gt 0) {
                    [Math]::Round(($volume.SizeRemaining / $volume.Size) * 100, 2)
                } else {
                    $null
                }

                $storage.Volumes += [PSCustomObject]@{
                    DriveLetter       = $volume.DriveLetter
                    FileSystemLabel   = $volume.FileSystemLabel
                    FileSystem        = $volume.FileSystem
                    DriveType         = [string]$volume.DriveType
                    HealthStatus      = [string]$volume.HealthStatus
                    OperationalStatus = ($volume.OperationalStatus -join ', ')
                    SizeGB            = Convert-BravoBytesToGB $volume.Size
                    FreeGB            = Convert-BravoBytesToGB $volume.SizeRemaining
                    FreePercent       = $freePercent
                }

                if ($volume.HealthStatus -and [string]$volume.HealthStatus -notin @('Healthy','Unknown')) {
                    Add-AuditFinding -Severity 'WARNING' -Category 'Storage' -Message "Том $($volume.DriveLetter): HealthStatus=$($volume.HealthStatus)" -Recommendation 'Перевірте стан тому через Get-Volume, Event Viewer та інструменти виробника диска.'
                }
            }
        } catch {
            Add-AuditError -Section 'StorageDeep.GetVolume' -Message $_.Exception.Message
        }
    }

    if (Get-Command Get-Disk -ErrorAction SilentlyContinue) {
        try {
            $disks = Get-Disk -ErrorAction Stop
            foreach ($disk in $disks) {
                $storage.Disks += [PSCustomObject]@{
                    Number            = $disk.Number
                    FriendlyName      = $disk.FriendlyName
                    SerialNumber      = $disk.SerialNumber
                    BusType           = [string]$disk.BusType
                    MediaType         = [string]$disk.MediaType
                    PartitionStyle    = [string]$disk.PartitionStyle
                    OperationalStatus = ($disk.OperationalStatus -join ', ')
                    HealthStatus      = [string]$disk.HealthStatus
                    IsBoot            = $disk.IsBoot
                    IsSystem          = $disk.IsSystem
                    IsOffline         = $disk.IsOffline
                    IsReadOnly        = $disk.IsReadOnly
                    SizeGB            = Convert-BravoBytesToGB $disk.Size
                }

                if ($disk.IsOffline -or $disk.IsReadOnly) {
                    Add-AuditFinding -Severity 'CRITICAL' -Category 'Storage' -Message "Disk $($disk.Number): IsOffline=$($disk.IsOffline), IsReadOnly=$($disk.IsReadOnly)" -Recommendation 'Перевірте Get-Disk, diskpart, SAN policy, стан носія та контролер.'
                }

                if ($disk.HealthStatus -and [string]$disk.HealthStatus -notin @('Healthy','Unknown')) {
                    Add-AuditFinding -Severity 'CRITICAL' -Category 'Storage' -Message "Disk $($disk.Number): HealthStatus=$($disk.HealthStatus)" -Recommendation 'Негайно перевірте SMART, журнали та резервні копії.'
                }
            }
        } catch {
            Add-AuditError -Section 'StorageDeep.GetDisk' -Message $_.Exception.Message
        }
    }


    if (Get-Command Get-Partition -ErrorAction SilentlyContinue) {
        try {
            $partitions = Get-Partition -ErrorAction Stop
            foreach ($partition in $partitions) {
                $storage.Partitions += [PSCustomObject]@{
                    DiskNumber      = $partition.DiskNumber
                    PartitionNumber = $partition.PartitionNumber
                    DriveLetter     = $partition.DriveLetter
                    Type            = [string]$partition.Type
                    GptType         = [string]$partition.GptType
                    MbrType         = [string]$partition.MbrType
                    IsActive        = $partition.IsActive
                    IsBoot          = $partition.IsBoot
                    IsSystem        = $partition.IsSystem
                    IsHidden        = $partition.IsHidden
                    IsReadOnly      = $partition.IsReadOnly
                    OffsetGB        = Convert-BravoBytesToGB $partition.Offset
                    SizeGB          = Convert-BravoBytesToGB $partition.Size
                }
            }
        } catch {
            Add-AuditError -Section 'StorageDeep.GetPartition' -Message $_.Exception.Message
        }
    }

    if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
        try {
            $bitlockerVolumes = Get-BitLockerVolume -ErrorAction Stop
            foreach ($volume in $bitlockerVolumes) {
                $storage.BitLocker += [PSCustomObject]@{
                    MountPoint           = $volume.MountPoint
                    VolumeType           = [string]$volume.VolumeType
                    CapacityGB           = if ($null -ne $volume.CapacityGB) { [Math]::Round($volume.CapacityGB, 2) } else { $null }
                    VolumeStatus         = [string]$volume.VolumeStatus
                    EncryptionPercentage = $volume.EncryptionPercentage
                    EncryptionMethod     = [string]$volume.EncryptionMethod
                    ProtectionStatus     = [string]$volume.ProtectionStatus
                    LockStatus           = [string]$volume.LockStatus
                    AutoUnlockEnabled    = $volume.AutoUnlockEnabled
                }

                # Незашифрований системний том — окрема, свідомо вужча знахідка:
                # відсутність BitLocker на data-томах занадто поширена на
                # звичайних робочих станціях, щоб бути WARNING на кожному
                # прогоні (той самий принцип, що й з WinRE/EFI-розділами
                # раніше в цій сесії); системний том — інша вага ризику.
                if ($volume.VolumeType -eq 'OperatingSystem' -and [string]$volume.ProtectionStatus -eq 'Off') {
                    # INFO, не WARNING: відсутність BitLocker на системному
                    # томі — поширений і часто свідомий вибір (dev-машини,
                    # десктопи без фізичного ризику крадіжки, альтернативне
                    # шифрування) — не впливає на Health Score/Status, лише
                    # фіксується в звіті як факт стану (той самий принцип, що
                    # й Secure Boot/TPM: "не є помилкою", лише публікація стану).
                    Add-AuditFinding -Severity 'INFO' -Category 'Storage.BitLocker' -Message "Системний том $($volume.MountPoint) не захищений BitLocker (ProtectionStatus=Off)." -Recommendation 'Розгляньте увімкнення BitLocker для системного тому, особливо на портативних пристроях.'
                }
            }
        } catch {
            # Get-BitLockerVolume вимагає прав адміністратора й може падати з
            # access denied на непідвищеній сесії — не помилка збору per se,
            # оскільки решта Deep Audit продовжує працювати; фіксуємо окремо.
            Add-AuditError -Section 'StorageDeep.BitLocker' -Message $_.Exception.Message
        }
    }
    # BitLocker-модуль не встановлено (напр. Windows Home edition, деякі
    # Server Core збірки без feature BitLocker) — $storage.BitLocker
    # лишається порожнім масивом, це штатний стан машини, не помилка.

    try {
        $pageFiles = Get-AuditObject -ClassName 'Win32_PageFileUsage'
        foreach ($pageFile in $pageFiles) {
            $storage.PageFiles += [PSCustomObject]@{
                Name            = $pageFile.Name
                AllocatedBaseMB = $pageFile.AllocatedBaseSize
                CurrentUsageMB  = $pageFile.CurrentUsage
                PeakUsageMB     = $pageFile.PeakUsage
                InstallDate     = if ($pageFile.InstallDate) {
                    $pageFileInstallDate = Convert-AuditDateTime -Value $pageFile.InstallDate -UseCim:$script:UseCim
                    if ($pageFileInstallDate) { $pageFileInstallDate.ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
                } else {
                    ''
                }
                Status          = $pageFile.Status
            }
        }
    } catch {
        Add-AuditError -Section 'StorageDeep.PageFiles' -Message $_.Exception.Message
    }

    try {
        # Win32_ShadowCopy — точки відновлення VSS (System Restore/File
        # History/backup-софт їх створюють). Порожній масив — штатний стан
        # (VSS вимкнено, немає точок відновлення), не помилка збору.
        $shadowCopies = Get-AuditObject -ClassName 'Win32_ShadowCopy'
        foreach ($shadowCopy in $shadowCopies) {
            $storage.ShadowCopies += [PSCustomObject]@{
                ID                = $shadowCopy.ID
                VolumeName        = $shadowCopy.VolumeName
                InstallDate       = if ($shadowCopy.InstallDate) {
                    $shadowCopyDate = Convert-AuditDateTime -Value $shadowCopy.InstallDate -UseCim:$script:UseCim
                    if ($shadowCopyDate) { $shadowCopyDate.ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
                } else {
                    ''
                }
                ClientAccessible = $shadowCopy.ClientAccessible
                Persistent       = $shadowCopy.Persistent
            }
        }
    } catch {
        # Win32_ShadowCopy-провайдер може бути недоступний (служба VSS
        # вимкнена/недоступна) — фіксуємо як помилку збору, оскільки клас
        # штатно присутній на всіх підтримуваних Windows.
        Add-AuditError -Section 'StorageDeep.ShadowCopies' -Message $_.Exception.Message
    }

    if (Get-Command Get-StoragePool -ErrorAction SilentlyContinue) {
        try {
            # IsPrimordial=$true — це прихований "сирий" пул, що представляє
            # фізичні диски системи саму по собі, не реальний Storage Spaces
            # пул, створений користувачем; виключаємо як шум без цінності
            # (той самий принцип, що й Unreachable/Incomplete у ARP-кеші).
            $storagePools = Get-StoragePool -ErrorAction Stop | Where-Object { -not $_.IsPrimordial }
            foreach ($pool in $storagePools) {
                $storage.StoragePools += [PSCustomObject]@{
                    FriendlyName      = $pool.FriendlyName
                    HealthStatus      = [string]$pool.HealthStatus
                    OperationalStatus = [string]$pool.OperationalStatus
                    SizeGB            = Convert-BravoBytesToGB $pool.Size
                    AllocatedGB       = Convert-BravoBytesToGB $pool.AllocatedSize
                    IsReadOnly        = $pool.IsReadOnly
                }

                if ([string]$pool.HealthStatus -notin @('Healthy', '')) {
                    Add-AuditFinding -Severity 'WARNING' -Category 'Storage.StoragePools' -Message "Storage Pool '$($pool.FriendlyName)' має статус HealthStatus=$($pool.HealthStatus)." -Recommendation 'Перевірте стан пулу та фізичних дисків, що входять до нього (Get-PhysicalDisk).'
                }
            }
        } catch {
            Add-AuditError -Section 'StorageDeep.StoragePools' -Message $_.Exception.Message
        }
    }
    # Get-StoragePool відсутній (модуль Storage не встановлено, напр. деякі
    # Server Core/старіші Windows) або Storage Spaces не використовується —
    # $storage.StoragePools лишається порожнім масивом, штатний стан.

    if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
        try {
            $physicalDisksForReliability = Get-PhysicalDisk -ErrorAction Stop
            foreach ($physicalDisk in $physicalDisksForReliability) {
                try {
                    # Get-StorageReliabilityCounter може падати для окремого
                    # диска (напр. USB/віртуальний диск без SMART-контролера) —
                    # обробляємо кожен диск незалежно, один збій не має гасити
                    # решту.
                    $counter = $physicalDisk | Get-StorageReliabilityCounter -ErrorAction Stop
                    if (-not $counter) { continue }

                    $storage.ReliabilityCounters += [PSCustomObject]@{
                        DeviceId                = $physicalDisk.DeviceId
                        FriendlyName             = $physicalDisk.FriendlyName
                        MediaType                = [string]$physicalDisk.MediaType
                        TemperatureCelsius       = $counter.Temperature
                        TemperatureMaxCelsius    = $counter.TemperatureMax
                        WearPercent              = $counter.Wear
                        ReadErrorsTotal          = $counter.ReadErrorsTotal
                        ReadErrorsUncorrected    = $counter.ReadErrorsUncorrected
                        WriteErrorsTotal         = $counter.WriteErrorsTotal
                        WriteErrorsUncorrected   = $counter.WriteErrorsUncorrected
                        PowerOnHours             = $counter.PowerOnHours
                    }

                    # Некориговані помилки читання/запису — однозначний сигнал
                    # апаратної проблеми диска (на відміну від Total, які
                    # включають штатно-скориговані помилки і завжди >0 на
                    # робочому диску). Wear >= 90% — SSD/NVMe близько до
                    # кінця ресурсу за специфікацією виробника.
                    if (($counter.ReadErrorsUncorrected -gt 0) -or ($counter.WriteErrorsUncorrected -gt 0)) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Storage.Reliability' -Message "Диск '$($physicalDisk.FriendlyName)' має некориговані помилки читання/запису (SMART reliability counters)." -Recommendation 'Перевірте стан диска (chkdsk, виробничий diagnostic tool) і за потреби замініть.'
                    }
                    if ($null -ne $counter.Wear -and [double]$counter.Wear -ge 90) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Storage.Reliability' -Message "Диск '$($physicalDisk.FriendlyName)' має Wear=$($counter.Wear)% — близько до кінця ресурсу SSD/NVMe." -Recommendation 'Заплануйте заміну диска та перевірте резервні копії.'
                    }
                } catch {
                    Add-AuditError -Section 'StorageDeep.ReliabilityCounters' -Message $_.Exception.Message
                }
            }
        } catch {
            Add-AuditError -Section 'StorageDeep.ReliabilityCounters' -Message $_.Exception.Message
        }
    }
    # Get-PhysicalDisk/Get-StorageReliabilityCounter відсутні (модуль Storage
    # не встановлено) — $storage.ReliabilityCounters лишається порожнім
    # масивом, штатний стан.

    try {
        # MSStorageDriver_FailurePredictStatus (namespace root\wmi) — легасі
        # SMART predictive-failure API, доступний лише для деяких контролерів
        # (переважно старі ATA/SATA, часто НЕ покриває NVMe чи RAID-контролери
        # з власним драйвером) і вимагає прав адміністратора. Відсутність
        # класу/інстансів — штатний стан для більшості сучасних машин, не
        # помилка збору.
        if ($script:UseCim) {
            $failurePredicts = Get-CimInstance -Namespace 'root\wmi' -ClassName 'MSStorageDriver_FailurePredictStatus' -ErrorAction Stop
        } else {
            $failurePredicts = Get-WmiObject -Namespace 'root\wmi' -Class 'MSStorageDriver_FailurePredictStatus' -ErrorAction Stop
        }

        foreach ($predict in $failurePredicts) {
            $storage.SmartPredictFailures += [PSCustomObject]@{
                InstanceName   = $predict.InstanceName
                PredictFailure = $predict.PredictFailure
                Reason         = $predict.Reason
            }

            if ($predict.PredictFailure) {
                Add-AuditFinding -Severity 'CRITICAL' -Category 'Storage.SMART' -Message "SMART передбачає можливий збій диска '$($predict.InstanceName)' (PredictFailure=True)." -Recommendation 'Негайно створіть резервну копію даних і заплануйте заміну диска.'
            }
        }
    } catch {
        # Клас відсутній у namespace (WMI-провайдер SMART не встановлено/не
        # підтримується контролером) — це не помилка збору, а обмеження
        # апаратної/драйверної підтримки; не фіксуємо Add-AuditError, аби не
        # створювати CollectionErrors на переважній більшості сучасних машин
        # (NVMe/RAID), де цей клас штатно відсутній.
    }

    return [PSCustomObject]$storage
}


# --- BRAVO v0.3.2 Storage Critical Findings ---
function Get-BravoStorageRiskSummary {
    param(
        [Parameter(Mandatory = $true)]
        $StorageDeep
    )

    $thresholds = Get-BravoStorageThresholds
    $criticalThreshold = $thresholds.CriticalFreePercent
    $warningThreshold = $thresholds.WarningFreePercent
    $systemWarningThreshold = $thresholds.SystemWarningFreePercent
    $systemDrive = ($env:SystemDrive -replace ':','').ToUpperInvariant()

    $risk = [ordered]@{
        CollectedAt                = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        CriticalFreePercent        = $criticalThreshold
        WarningFreePercent         = $warningThreshold
        SystemWarningFreePercent   = $systemWarningThreshold
        CriticalVolumes            = @()
        WarningVolumes             = @()
        SystemVolumeWarnings       = @()
        HealthyVolumes             = @()
        ReservedVolumes            = @()
        Summary                    = [ordered]@{
            CriticalCount           = 0
            WarningCount            = 0
            SystemWarningCount      = 0
            HealthyCount            = 0
            ReservedCount           = 0
        }
    }

    if (-not $StorageDeep -or -not $StorageDeep.Volumes) {
        return [PSCustomObject]$risk
    }

    foreach ($volume in @($StorageDeep.Volumes)) {
        $driveLetter = ''
        if ($null -ne $volume.DriveLetter -and [string]$volume.DriveLetter -ne '') {
            $driveLetter = ([string]$volume.DriveLetter).TrimEnd(':').ToUpperInvariant()
        }

        $label = [string]$volume.FileSystemLabel
        $displayName = if ($driveLetter) {
            if ($label) { "$driveLetter`: $label" } else { "$driveLetter`:" }
        } elseif ($label) {
            $label
        } else {
            'Volume без літери'
        }

        $freePercent = $null
        try {
            if ($null -ne $volume.FreePercent -and [string]$volume.FreePercent -ne '') {
                $freePercent = [double]$volume.FreePercent
            }
        } catch {
            $freePercent = $null
        }

        $freeGB = $volume.FreeGB
        $sizeGB = $volume.SizeGB

        $volumeRisk = [PSCustomObject]@{
            DriveLetter  = $driveLetter
            Name         = $displayName
            Label        = $label
            FileSystem   = $volume.FileSystem
            HealthStatus = $volume.HealthStatus
            SizeGB       = $sizeGB
            FreeGB       = $freeGB
            FreePercent  = $freePercent
        }

        if ($null -eq $freePercent) {
            continue
        }

        # CD-ROM/оптичні носії — read-only, "вільне місце" не є показником ризику
        # (наприклад ISO-образ примонтований як том завжди показує 0% вільно).
        if ([string]$volume.DriveType -eq 'CD-ROM') {
            $risk.HealthyVolumes += $volumeRisk
            continue
        }

        # Томи без літери диска (WinRE/EFI System Partition/MSR) — системно-
        # зарезервовані розділи фіксованого розміру, недоступні користувачу
        # через Провідник чи звичайне очищення файлів. WinRE Partition (типово
        # ~0.5-1 GB) майже завжди заповнений на 90%+ образом відновлення — це
        # штатний стан Windows, а не ризик, що потребує дій. Виводити їх у
        # Critical/Warning findings і знижувати Health Score на КОЖНІЙ Windows-
        # машині було б систематичним false positive. Дані про них лишаються
        # видимими в таблиці Storage Deep (без Add-AuditFinding).
        if (-not $driveLetter) {
            $risk.ReservedVolumes += $volumeRisk
            continue
        }

        if ($freePercent -lt $criticalThreshold) {
            $risk.CriticalVolumes += $volumeRisk

            Add-AuditFinding `
                -Severity 'CRITICAL' `
                -Category 'Storage.FreeSpace' `
                -Message ("Том {0} має критично мало вільного місця: {1} GB з {2} GB ({3}%)." -f $displayName, $freeGB, $sizeGB, $freePercent) `
                -Recommendation 'Терміново звільніть місце або розширте том. Для VM/backup/workload томів перевірте snapshots, ISO, тимчасові файли, кеші, старі архіви та дублікати.'

            continue
        }

        if ($freePercent -lt $warningThreshold) {
            $risk.WarningVolumes += $volumeRisk

            Add-AuditFinding `
                -Severity 'WARNING' `
                -Category 'Storage.FreeSpace' `
                -Message ("Том {0} має мало вільного місця: {1} GB з {2} GB ({3}%)." -f $displayName, $freeGB, $sizeGB, $freePercent) `
                -Recommendation 'Заплануйте очищення або розширення тому, щоб уникнути переходу в критичний стан.'

            continue
        }

        if ($driveLetter -eq $systemDrive -and $freePercent -lt $systemWarningThreshold) {
            $risk.SystemVolumeWarnings += $volumeRisk

            Add-AuditFinding `
                -Severity 'WARNING' `
                -Category 'Storage.SystemDrive' `
                -Message ("Системний том {0} має менше {1}% вільного місця: {2}%." -f $displayName, $systemWarningThreshold, $freePercent) `
                -Recommendation 'Для системного тому бажано тримати запас вільного місця для оновлень Windows, кешів, crash dumps і тимчасових файлів.'

            continue
        }

        $risk.HealthyVolumes += $volumeRisk
    }

    $risk.Summary.CriticalCount = @($risk.CriticalVolumes).Count
    $risk.Summary.WarningCount = @($risk.WarningVolumes).Count
    $risk.Summary.SystemWarningCount = @($risk.SystemVolumeWarnings).Count
    $risk.Summary.HealthyCount = @($risk.HealthyVolumes).Count
    $risk.Summary.ReservedCount = @($risk.ReservedVolumes).Count

    return [PSCustomObject]$risk
}

function Get-BravoStorageAudit {
    [CmdletBinding()]
    param()

    # --- Диски ---
    try {
        $logicalDiskInfo = Get-AuditObject -ClassName 'Win32_LogicalDisk' -Filter 'DriveType=3'
        $totalSpace = 0
        $totalFree = 0

        # Deep/Forensic профілі нижче в цій же функції запускають
        # Get-BravoStorageRiskSummary, який оцінює ті самі томи з тими самими
        # централізованими порогами (Get-BravoStorageThresholds), але глибше
        # (включно з томами без літери диска й системним порогом). Щоб не
        # породжувати для одного тому два findings різної суворості —
        # basic-прохід у Deep/Forensic суто збирає TotalGB/FreeGB, а рішення
        # про findings делегує risk summary.
        $emitBasicFindings = ($Profile -notin @('Deep','Forensic'))
        $thresholds = Get-BravoStorageThresholds

        foreach ($logicalDisk in $logicalDiskInfo) {
            $totalSpace += [double]$logicalDisk.Size
            $totalFree += [double]$logicalDisk.FreeSpace

            $volume = [PSCustomObject]@{
                DeviceID    = $logicalDisk.DeviceID
                VolumeName  = $logicalDisk.VolumeName
                FileSystem  = $logicalDisk.FileSystem
                TotalGB     = [Math]::Round($logicalDisk.Size / 1GB, 2)
                FreeGB      = [Math]::Round($logicalDisk.FreeSpace / 1GB, 2)
                FreePercent = if ($logicalDisk.Size -gt 0) { [Math]::Round(($logicalDisk.FreeSpace / $logicalDisk.Size) * 100, 2) } else { 0 }
            }
            $script:Report.Hardware.Disks.Volumes += $volume

            if ($emitBasicFindings) {
                if ($volume.FreePercent -lt $thresholds.CriticalFreePercent) {
                    Add-AuditFinding -Severity 'CRITICAL' -Category 'Storage.FreeSpace' -Message "На диску $($volume.DeviceID) менше $($thresholds.CriticalFreePercent)% вільного місця: $($volume.FreePercent)%" -Recommendation 'Звільніть місце або розширте том.'
                } elseif ($volume.FreePercent -lt $thresholds.WarningFreePercent) {
                    Add-AuditFinding -Severity 'WARNING' -Category 'Storage.FreeSpace' -Message "На диску $($volume.DeviceID) менше $($thresholds.WarningFreePercent)% вільного місця: $($volume.FreePercent)%" -Recommendation 'Перевірте темп росту даних і заплануйте очищення.'
                }
            }
        }

        if ($totalSpace -gt 0) {
            $script:Report.Hardware.Disks.TotalGB = [Math]::Round($totalSpace / 1GB, 2)
            $script:Report.Hardware.Disks.FreeGB = [Math]::Round($totalFree / 1GB, 2)
            $script:Report.Hardware.Disks.FreePercent = [Math]::Round(($totalFree / $totalSpace) * 100, 2)
        }

        if ($Profile -in @('Full','Deep','Forensic')) {
            try {
                $physicalDisks = Get-AuditObject -ClassName 'Win32_DiskDrive'
                foreach ($physicalDisk in $physicalDisks) {
                    $script:Report.Hardware.Disks.PhysicalDisks += [PSCustomObject]@{
                        Model        = $physicalDisk.Model
                        SerialNumber = $physicalDisk.SerialNumber
                        Interface    = $physicalDisk.InterfaceType
                        MediaType    = $physicalDisk.MediaType
                        SizeGB       = [Math]::Round($physicalDisk.Size / 1GB, 2)
                        Status       = $physicalDisk.Status
                    }
                }
            } catch {
                Add-AuditError -Section 'Storage.PhysicalDisks' -Message $_.Exception.Message
            }
        }

        Write-Host "  $IconDisk Диски: $(Format-Size $script:Report.Hardware.Disks.FreeGB) вільно ($($script:Report.Hardware.Disks.FreePercent)%)" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Storage' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка збору дисків: $($_.Exception.Message)" -ForegroundColor Red
    }


    # --- BRAVO v0.3.0 Storage Deep Audit Skeleton ---
    if ($Profile -in @('Deep','Forensic')) {
        try {
            Write-Host "  [INFO] Storage Deep Audit: збір базових storage-даних..."

            $storageDeep = Get-BravoStorageDeepAudit

            if ($script:Report.Hardware.Disks -is [System.Collections.IDictionary]) {
                $script:Report.Hardware.Disks['Deep'] = $storageDeep
            } else {
                $script:Report.Hardware.Disks | Add-Member -MemberType NoteProperty -Name 'Deep' -Value $storageDeep -Force
            }

            Write-Host ("  [OK] Storage Deep Audit: logicalDisks={0}, volumes={1}, disks={2}" -f @($storageDeep.LogicalDisks).Count, @($storageDeep.Volumes).Count, @($storageDeep.Disks).Count)
            $storageRisk = Get-BravoStorageRiskSummary -StorageDeep $storageDeep

            if ($script:Report.Hardware.Disks -is [System.Collections.IDictionary]) {
                $script:Report.Hardware.Disks['StorageRisk'] = $storageRisk
            } else {
                $script:Report.Hardware.Disks | Add-Member -MemberType NoteProperty -Name 'StorageRisk' -Value $storageRisk -Force
            }

            Write-Host ("  [OK] Storage Risk: critical={0}, warning={1}, systemWarning={2}, healthy={3}" -f $storageRisk.Summary.CriticalCount, $storageRisk.Summary.WarningCount, $storageRisk.Summary.SystemWarningCount, $storageRisk.Summary.HealthyCount)
        } catch {
            Add-AuditError -Section 'StorageDeep' -Message $_.Exception.Message
            Write-Host "  [ERROR] Storage Deep Audit: $($_.Exception.Message)"
        }
    }
}


# ============================================================
# MODULE: src/33-Collectors-Network.ps1
# ============================================================

# MODULE: 33-Collectors-Network.ps1
# Збір інформації про мережеві адаптери, IP, TCP-з'єднання, primary IPv4,
# public IPv4, routing table, ARP-кеш, WinHTTP proxy та SMB shares.

# Чиста функція: будує PID -> ProcessName lookup з масиву процесів
# (напр. Get-Process), щоб TCP-з'єднання можна було збагатити ProcessName
# без одного Get-Process виклику на кожне з'єднання окремо.
function Get-BravoProcessNameLookup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        $Processes
    )

    $map = @{}
    foreach ($process in @($Processes)) {
        if ($process -and $null -ne $process.Id) {
            $map[[int]$process.Id] = $process.ProcessName
        }
    }
    return $map
}

function Get-BravoNetworkAudit {
    [CmdletBinding()]
    param()

    # --- Мережа ---
    try {
        $computerSystemInfo = Get-AuditObject -ClassName 'Win32_ComputerSystem' -First
        $script:Report.Network.General.Hostname = $env:COMPUTERNAME
        if ($computerSystemInfo) { $script:Report.Network.General.Domain = $computerSystemInfo.Domain }

        $networkAdapterConfigInfo = Get-AuditObject -ClassName 'Win32_NetworkAdapterConfiguration' -Filter 'IPEnabled = True'
        foreach ($adapterConfig in $networkAdapterConfigInfo) {
            if ($adapterConfig.IPAddress) {
                foreach ($ip in $adapterConfig.IPAddress) {
                    if ($ip -notlike '*:*') { $script:Report.Network.IP.IPv4 += $ip }
                }
            }

            if ($adapterConfig.DefaultIPGateway) {
                $script:Report.Network.Routing.DefaultGateways = @($script:Report.Network.Routing.DefaultGateways + $adapterConfig.DefaultIPGateway) | Where-Object { $_ } | Select-Object -Unique

                if (-not $script:Report.Network.Routing.DefaultGateway) {
                    $script:Report.Network.Routing.DefaultGateway = $adapterConfig.DefaultIPGateway[0]
                }
            }

            if ($adapterConfig.DNSServerSearchOrder) {
                $script:Report.Network.Routing.DNSServers = @($script:Report.Network.Routing.DNSServers + $adapterConfig.DNSServerSearchOrder) | Where-Object { $_ } | Select-Object -Unique
            }

            if ($adapterConfig.DNSDomainSuffixSearchOrder) {
                $script:Report.Network.Routing.DNSSuffixSearchOrder = @($script:Report.Network.Routing.DNSSuffixSearchOrder + $adapterConfig.DNSDomainSuffixSearchOrder) | Where-Object { $_ } | Select-Object -Unique
            }

            $script:Report.Network.Adapters += [PSCustomObject]@{
                Description = $adapterConfig.Description
                MACAddress  = $adapterConfig.MACAddress
                DHCPEnabled = $adapterConfig.DHCPEnabled
                IPv4        = @($adapterConfig.IPAddress | Where-Object { $_ -notlike '*:*' })
                Gateway     = @($adapterConfig.DefaultIPGateway)
                DNS         = @($adapterConfig.DNSServerSearchOrder)
                DNSSuffixSearchOrder = @($adapterConfig.DNSDomainSuffixSearchOrder)
                LinkSpeed      = ''
                Status         = ''
                DriverVersion  = ''
                DriverProvider = ''
            }
        }

        # --- Збагачення адаптерів: link speed, status, driver (v0.5.0 Network
        # Audit) ---
        # Get-NetAdapter покриває всі мережеві інтерфейси (включно з тими, що
        # не мають IP — вимкнені/від'єднані), тоді як цикл вище йде лише по
        # Win32_NetworkAdapterConfiguration з IPEnabled=True. Тому збагачуємо
        # ЛИШЕ вже наявні записи (адаптери з IP) за MAC-адресою — не додаємо
        # нові рядки з Get-NetAdapter, щоб не змінювати семантику "Adapters" з
        # "інтерфейси з IP" на "усі мережеві інтерфейси в системі" (це окрема
        # задача, якщо колись знадобиться). Гейтовано Full/Deep/Forensic —
        # той самий принцип, що й RAM.Modules/Chassis/Motherboard/GPU.
        if ($Profile -in @('Full','Deep','Forensic') -and (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue)) {
            try {
                $netAdapterByMac = @{}
                foreach ($netAdapter in (Get-NetAdapter -ErrorAction Stop)) {
                    $normalizedMac = ([string]$netAdapter.MacAddress) -replace '[:\-]', ''
                    if ($normalizedMac) { $netAdapterByMac[$normalizedMac] = $netAdapter }
                }

                foreach ($adapterEntry in $script:Report.Network.Adapters) {
                    $normalizedMac = ([string]$adapterEntry.MACAddress) -replace '[:\-]', ''
                    if ($normalizedMac -and $netAdapterByMac.ContainsKey($normalizedMac)) {
                        $matchedNetAdapter = $netAdapterByMac[$normalizedMac]
                        $adapterEntry.LinkSpeed      = [string]$matchedNetAdapter.LinkSpeed
                        $adapterEntry.Status         = [string]$matchedNetAdapter.Status
                        $adapterEntry.DriverVersion  = [string]$matchedNetAdapter.DriverVersion
                        $adapterEntry.DriverProvider = [string]$matchedNetAdapter.DriverProvider
                    }
                }
            } catch {
                Add-AuditError -Section 'Network.AdapterDetails' -Message $_.Exception.Message
            }
        }

        # --- Routing table / ARP / WinHTTP proxy (v0.5.0 Network Audit) ---
        if ($Profile -in @('Full','Deep','Forensic')) {
            if (Get-Command Get-NetRoute -ErrorAction SilentlyContinue) {
                try {
                    $netRoutes = Get-NetRoute -AddressFamily IPv4 -ErrorAction Stop |
                        Select-Object -First 200 -Property DestinationPrefix, NextHop, RouteMetric, InterfaceAlias, ifIndex

                    foreach ($route in $netRoutes) {
                        $script:Report.Network.Routing.RoutingTable += [PSCustomObject]@{
                            DestinationPrefix = $route.DestinationPrefix
                            NextHop           = $route.NextHop
                            RouteMetric       = $route.RouteMetric
                            InterfaceAlias    = $route.InterfaceAlias
                            InterfaceIndex    = $route.ifIndex
                        }
                    }
                } catch {
                    Add-AuditError -Section 'Network.RoutingTable' -Message $_.Exception.Message
                }
            }

            if (Get-Command Get-NetNeighbor -ErrorAction SilentlyContinue) {
                try {
                    # Виключаємо Unreachable/Incomplete — це не реальні записи
                    # ARP-кешу, а тимчасові стани резолюції, шум без цінності
                    # для аудиту.
                    $netNeighbors = Get-NetNeighbor -AddressFamily IPv4 -ErrorAction Stop |
                        Where-Object { $_.State -notin @('Unreachable', 'Incomplete') } |
                        Select-Object -First 200 -Property IPAddress, LinkLayerAddress, State, InterfaceAlias

                    foreach ($neighbor in $netNeighbors) {
                        $script:Report.Network.ARP += [PSCustomObject]@{
                            IPAddress        = $neighbor.IPAddress
                            LinkLayerAddress = $neighbor.LinkLayerAddress
                            State            = $neighbor.State.ToString()
                            InterfaceAlias   = $neighbor.InterfaceAlias
                        }
                    }
                } catch {
                    Add-AuditError -Section 'Network.ARP' -Message $_.Exception.Message
                }
            }

            # WinHTTP proxy: свідомо БЕЗ парсингу/інтерпретації тексту виводу
            # netsh (локалізований, як і net.exe/auditpol.exe раніше в цій
            # сесії) — публікуємо сирі рядки як є, без спроби визначити
            # Enabled/Disabled за англійськими фразами типу "Direct access".
            if (Get-Command netsh -ErrorAction SilentlyContinue) {
                try {
                    $winHttpProxyOutput = & netsh winhttp show proxy 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        $script:Report.Network.WinHttpProxy.RawOutput = @($winHttpProxyOutput | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
                        $script:Report.Network.WinHttpProxy.Status = 'Detected'
                    } else {
                        $script:Report.Network.WinHttpProxy.Status = 'Unavailable'
                    }
                } catch {
                    $script:Report.Network.WinHttpProxy.Status = 'Unavailable'
                    $script:Report.Network.WinHttpProxy.Error = $_.Exception.Message
                }
            } else {
                $script:Report.Network.WinHttpProxy.Status = 'NotAvailable'
            }
        }

        if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
            try {
                $tcpConnections = Get-NetTCPConnection -ErrorAction Stop
                $established = @($tcpConnections | Where-Object { $_.State -eq 'Established' })
                $script:Report.Network.Connections.Established = $established.Count
                $listening = @($tcpConnections | Where-Object { $_.State -eq 'Listen' })
                $script:Report.Network.Connections.Listening = $listening.Count

                if ($Profile -in @('Full','Deep','Forensic')) {
                    # Один Get-Process на весь колектор — не по одному виклику
                    # на кожне з'єднання (200+ записів кожного типу).
                    $processNameById = Get-BravoProcessNameLookup -Processes (Get-Process -ErrorAction SilentlyContinue)

                    $script:Report.Network.Connections.ListeningPorts = $listening |
                        Select-Object -First 200 -Property LocalAddress, LocalPort, OwningProcess, @{Name='ProcessName'; Expression={ $pn = $processNameById[[int]$_.OwningProcess]; if ($pn) { $pn } else { '' } }}

                    $script:Report.Network.Connections.EstablishedConnections = $established |
                        Select-Object -First 200 -Property LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess, @{Name='ProcessName'; Expression={ $pn = $processNameById[[int]$_.OwningProcess]; if ($pn) { $pn } else { '' } }}
                }
            } catch {
                Add-AuditError -Section 'Network.TcpConnections' -Message $_.Exception.Message
            }
        }

        if (Get-Command Get-SmbShare -ErrorAction SilentlyContinue) {
            try {
                if ($Profile -in @('Full','Deep','Forensic')) {
                    $smbShares = Get-SmbShare -ErrorAction Stop
                    foreach ($share in $smbShares) {
                        # Адміністративні шари ($-суфікс: C$, ADMIN$, IPC$ тощо)
                        # створюються Windows автоматично на кожній машині —
                        # не приховуємо їх (це теж корисна інформація для
                        # аудиту), а позначаємо окремим полем, щоб споживач
                        # звіту міг відфільтрувати штатний шум від реальних
                        # користувацьких шар.
                        $script:Report.Network.SmbShares += [PSCustomObject]@{
                            Name             = $share.Name
                            Path             = $share.Path
                            Description      = $share.Description
                            ShareType        = [string]$share.ShareType
                            ScopeName        = $share.ScopeName
                            IsAdministrative = [bool]($share.Name -match '\$$')
                        }
                    }
                }
            } catch {
                Add-AuditError -Section 'Network.SmbShares' -Message $_.Exception.Message
            }
        }
        # Get-SmbShare відсутній (модуль SmbShare не встановлено) — штатний
        # стан, $script:Report.Network.SmbShares лишається порожнім масивом.
    # --- Впорядкування IPv4 (primary адреса першою) ---
    $bravoPrimaryNetwork = Get-BravoPrimaryNetworkInterface
    $bravoPrimaryIPv4 = $null

    if ($bravoPrimaryNetwork -and $bravoPrimaryNetwork.IPv4) {
        $bravoPrimaryIPv4 = $bravoPrimaryNetwork.IPv4
    }

    $bravoIPv4Source = @(Get-BravoAllUsableIPv4AddressList)

    if ($bravoIPv4Source.Count -eq 0 -and $script:Report.Network.IP.IPv4) {
        $bravoIPv4Source = @($script:Report.Network.IP.IPv4)
    }

    $bravoOrderedIPv4 = @(Move-BravoIPv4ToFront -IPv4 $bravoIPv4Source -PrimaryIPv4 $bravoPrimaryIPv4)

    if ($bravoOrderedIPv4.Count -gt 0) {
        $bravoPrimaryIPv4 = $bravoOrderedIPv4[0]
        $bravoIPv4Text = $bravoOrderedIPv4 -join ", "
    } else {
        $bravoPrimaryIPv4 = "N/A"
        $bravoIPv4Text = "N/A"
    }

    $script:Report.Network.IP.IPv4 = @($bravoOrderedIPv4)
    $script:Report.Network.IP.PrimaryIPv4 = $bravoPrimaryIPv4
    $script:Report.Network.IP.PrimaryInterface = $bravoPrimaryNetwork

    Write-Host "  [OK] IP: $bravoIPv4Text" -ForegroundColor Green

    # --- Public IPv4 та geo/ISP-дані ---
    # Мережево-залежна перевірка, що звертається до сторонніх сервісів:
    # гейтована профілем (не виконується для Quick), прапорцем -SkipPublicIP
    # і глобальним -Offline (вимикає всі зовнішні HTTPS-запити скрипта).
    $bravoPublicIPLookupEnabled = (-not $SkipPublicIP) -and (-not $Offline) -and ($Profile -in @('Full', 'Deep', 'Forensic'))

    if ($bravoPublicIPLookupEnabled) {
        $bravoPublicIPv4Info = Get-BravoPublicIPv4Address

        $script:Report.Network.IP.PublicIPv4 = $bravoPublicIPv4Info.IPv4
        $script:Report.Network.IP.PublicIPv4Provider = $bravoPublicIPv4Info.Provider
        $script:Report.Network.IP.PublicIPv4CheckedAt = $bravoPublicIPv4Info.CheckedAt
        $script:Report.Network.IP.PublicIPv4Status = $bravoPublicIPv4Info.Status

        # GeoIP/ISP-лукап (ipapi.co) — окремий зовнішній запит, що передає
        # публічну IPv4-адресу третій стороні. Гейтований окремо від самого
        # факту визначення Public IPv4: -SkipGeoIP (або -Offline) дозволяє
        # лишити Public IPv4 у звіті, але не відправляти її на geo-lookup сервіс.
        $bravoGeoIPLookupEnabled = (-not $SkipGeoIP) -and (-not $Offline)

        if ($bravoGeoIPLookupEnabled) {
            $bravoPublicIPv4ProviderInfo = Get-BravoPublicIPv4ProviderInfo -PublicIPv4 $bravoPublicIPv4Info.IPv4

            $script:Report.Network.IP.PublicIPv4LookupProvider = $bravoPublicIPv4ProviderInfo.LookupProvider
            $script:Report.Network.IP.PublicIPv4ISP = $bravoPublicIPv4ProviderInfo.ISP
            $script:Report.Network.IP.PublicIPv4Organization = $bravoPublicIPv4ProviderInfo.Organization
            $script:Report.Network.IP.PublicIPv4ASN = $bravoPublicIPv4ProviderInfo.ASN
            $script:Report.Network.IP.PublicIPv4Country = $bravoPublicIPv4ProviderInfo.Country
            $script:Report.Network.IP.PublicIPv4Region = $bravoPublicIPv4ProviderInfo.Region
            $script:Report.Network.IP.PublicIPv4City = $bravoPublicIPv4ProviderInfo.City
            $script:Report.Network.IP.PublicIPv4Timezone = $bravoPublicIPv4ProviderInfo.Timezone
            $script:Report.Network.IP.PublicIPv4ProviderInfoCheckedAt = $bravoPublicIPv4ProviderInfo.CheckedAt
            $script:Report.Network.IP.PublicIPv4ProviderInfoStatus = $bravoPublicIPv4ProviderInfo.Status
            $script:Report.Network.IP.PublicIPv4ProviderInfoError = $bravoPublicIPv4ProviderInfo.Error

        } else {
            $bravoGeoSkipReason = if ($Offline) { "-Offline" } else { "-SkipGeoIP" }
            $script:Report.Network.IP.PublicIPv4ProviderInfoStatus = 'Skipped'
            $script:Report.Network.IP.PublicIPv4ProviderInfoError = "GeoIP lookup пропущено ($bravoGeoSkipReason)."
            Write-Host "  [INFO] GeoIP/ISP lookup: пропущено ($bravoGeoSkipReason)" -ForegroundColor Yellow
        }

        if ($bravoPublicIPv4Info.Status -ne "Detected") {
            Write-Host "  [INFO] Public IP: не визначено" -ForegroundColor Yellow
        } elseif ($bravoGeoIPLookupEnabled -and -not [string]::IsNullOrWhiteSpace([string]$bravoPublicIPv4ProviderInfo.ISP)) {
            Write-Host "  [OK] Public IP: визначено, ISP: $($bravoPublicIPv4ProviderInfo.ISP)" -ForegroundColor Green
        } else {
            Write-Host "  [OK] Public IP: визначено, записано у звіт" -ForegroundColor Green
        }
    } else {
        $bravoSkipReason = if ($Offline) { "-Offline" } elseif ($SkipPublicIP) { "-SkipPublicIP" } else { "профіль $Profile" }
        $script:Report.Network.IP.PublicIPv4Status = 'Skipped'
        $script:Report.Network.IP.PublicIPv4ProviderInfoStatus = 'Skipped'
        Write-Host "  [INFO] Public IP: пропущено ($bravoSkipReason)" -ForegroundColor Yellow
    }
    } catch {
        Add-AuditError -Section 'Network' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка мережевих даних: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ============================================================
# MODULE: src/34-Collectors-Security.ps1
# ============================================================

# MODULE: 34-Collectors-Security.ps1
# Збір інформації про UAC (+full policy), RDP (+NLA/port/firewall scope/
# allowed users), антивірус, Windows Firewall, Secure Boot, TPM, SMBv1, TLS
# registry status, деталі Windows Defender, WinRM (listeners/auth), SMB
# signing, password policy (net accounts), audit policy (auditpol),
# autoruns (Run/RunOnce ключі реєстру + папки автозавантаження) та
# scheduled tasks (Get-ScheduledTask).

# Чиста функція: ConsentPromptBehaviorAdmin DWORD (HKLM:\...\Policies\System)
# -> людяний опис. Значення за документацією Microsoft (UAC group policy
# settings); невідомий код повертається як "Unknown ($code)", не помилка.
function Get-BravoUacAdminPromptText {
    [CmdletBinding()]
    param([AllowNull()][Nullable[int]]$Code)

    switch ($Code) {
        0 { return 'Elevate without prompting' }
        1 { return 'Prompt for credentials on the secure desktop' }
        2 { return 'Prompt for consent on the secure desktop' }
        3 { return 'Prompt for credentials' }
        4 { return 'Prompt for consent' }
        5 { return 'Prompt for consent for non-Windows binaries' }
        $null { return 'Unknown (not set)' }
        default { return "Unknown ($Code)" }
    }
}

# Чиста функція: ConsentPromptBehaviorUser DWORD -> людяний опис.
function Get-BravoUacUserPromptText {
    [CmdletBinding()]
    param([AllowNull()][Nullable[int]]$Code)

    switch ($Code) {
        0 { return 'Automatically deny elevation requests' }
        1 { return 'Prompt for credentials on the secure desktop' }
        3 { return 'Prompt for credentials' }
        $null { return 'Unknown (not set)' }
        default { return "Unknown ($Code)" }
    }
}

# Чиста функція: витягує Name/Value пари з об'єкта, поверненого
# Get-ItemProperty, відкидаючи службові PS*-метавластивості (PSPath/
# PSParentPath/PSChildName/PSDrive/PSProvider), які завжди присутні на
# результаті Get-ItemProperty поряд з реальними значеннями реєстрового
# ключа. Винесено окремо від I/O, щоб покрити unit-тестами без реального
# реєстру.
function ConvertFrom-BravoRegistryKeyProperties {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $PropertiesObject
    )

    $result = @()
    if (-not $PropertiesObject) { return $result }

    foreach ($propName in $PropertiesObject.PSObject.Properties.Name) {
        if ($propName -match '^PS(Path|ParentPath|ChildName|Drive|Provider)$') { continue }
        $result += [PSCustomObject]@{
            Name  = $propName
            Value = [string]$PropertiesObject.$propName
        }
    }

    return $result
}

# Чиста функція: інтерпретує пару SCHANNEL registry DWORD (Enabled,
# DisabledByDefault — HKLM:\...\SecurityProviders\SCHANNEL\Protocols\<protocol>\<Client|Server>)
# у людяний статус. Семантика за документацією Microsoft:
# - обидва ключі відсутні -> адміністратор нічого не налаштовував, діє
#   вбудований дефолт ОС (залежить від версії Windows) -> 'NotConfigured';
# - Enabled=0 -> явно вимкнено, незалежно від DisabledByDefault;
# - DisabledByDefault=1 (і Enabled не 0) -> вимкнено за замовчуванням;
# - інакше (Enabled=1 або відсутній, DisabledByDefault=0 або відсутній) ->
#   явно чи неявно увімкнено -> 'Enabled'.
function Get-BravoTlsProtocolStatus {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [Nullable[int]]$Enabled,
        [AllowNull()]
        [Nullable[int]]$DisabledByDefault
    )

    if ($null -eq $Enabled -and $null -eq $DisabledByDefault) { return 'NotConfigured' }
    if ($null -ne $Enabled -and $Enabled -eq 0) { return 'Disabled' }
    if ($null -ne $DisabledByDefault -and $DisabledByDefault -eq 1) { return 'Disabled' }
    return 'Enabled'
}

# Чиста функція: парсить вивід `net accounts` за ПОЗИЦІЄЮ рядка, а не за
# текстом мітки. `net.exe` локалізує самі мітки (на не-EN збірках Windows),
# але порядок рядків — фіксований у самому net.exe, не залежить від мовного
# пакета (перевірено на UA-локалізованій машині: значення виводяться у тому
# самому порядку, що документує Microsoft для будь-якої локалі). Той самий
# принцип, що й для RemoteDesktop-UserMode-In-TCP (незалежне від локалізації
# ім'я замість локалізованого DisplayGroup) раніше в цій сесії.
function ConvertFrom-BravoNetAccountsOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines
    )

    $dataLines = @($Lines | Where-Object { $_ -match ':' })

    function Get-BravoNetAccountsValueAt {
        param([int]$Index)
        if ($dataLines.Count -le $Index) { return $null }
        $line = $dataLines[$Index]
        $colonIndex = $line.LastIndexOf(':')
        if ($colonIndex -lt 0) { return $null }
        $value = $line.Substring($colonIndex + 1).Trim()
        if ([string]::IsNullOrWhiteSpace($value)) { return $null }
        return $value
    }

    # Фіксований порядок рядків net accounts (індекс 0 — "Force user logoff...",
    # навмисно не використовується цим колектором):
    return [ordered]@{
        MinPasswordAgeDays               = Get-BravoNetAccountsValueAt 1
        MaxPasswordAgeDays               = Get-BravoNetAccountsValueAt 2
        MinPasswordLength                = Get-BravoNetAccountsValueAt 3
        PasswordHistoryLength            = Get-BravoNetAccountsValueAt 4
        LockoutThreshold                 = Get-BravoNetAccountsValueAt 5
        LockoutDurationMinutes           = Get-BravoNetAccountsValueAt 6
        LockoutObservationWindowMinutes  = Get-BravoNetAccountsValueAt 7
    }
}

function Get-BravoSecurityAudit {
    [CmdletBinding()]
    param()

    # --- Безпека ---
    try {
        # Важливо: WARNING/INFO-знахідки нижче генеруються лише якщо ключ реєстру
        # реально вдалось прочитати. Якщо $uac/$rdp -eq $null (немає прав, GPO,
        # Server Core), стан невідомий — це НЕ те саме, що "підтверджено вимкнено",
        # і не повинно ставати хибним WARNING на дефолтному значенні моделі.
        $uac = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction SilentlyContinue
        if ($uac) {
            $script:Report.Security.UAC.Enabled = ($uac.EnableLUA -eq 1)

            if (-not $script:Report.Security.UAC.Enabled) {
                Add-AuditFinding -Severity 'WARNING' -Category 'Security' -Message 'UAC вимкнено.' -Recommendation 'Увімкніть UAC, якщо немає обґрунтованого винятку.'
            }

            # UAC full policy: значення нижче — типово $null, якщо адміністратор
            # ніколи не змінював дефолт групової політики (Windows тоді діє за
            # вбудованим дефолтом ConsentPromptBehaviorAdmin=5/User=3) — це
            # штатний стан, не помилка, публікуємо як є без Add-AuditFinding на
            # "не налаштовано".
            $adminPromptCode = if ($null -ne $uac.ConsentPromptBehaviorAdmin) { [int]$uac.ConsentPromptBehaviorAdmin } else { $null }
            $userPromptCode = if ($null -ne $uac.ConsentPromptBehaviorUser) { [int]$uac.ConsentPromptBehaviorUser } else { $null }
            $script:Report.Security.UAC.ConsentPromptBehaviorAdminCode = $adminPromptCode
            $script:Report.Security.UAC.ConsentPromptBehaviorAdminText = Get-BravoUacAdminPromptText -Code $adminPromptCode
            $script:Report.Security.UAC.ConsentPromptBehaviorUserCode = $userPromptCode
            $script:Report.Security.UAC.ConsentPromptBehaviorUserText = Get-BravoUacUserPromptText -Code $userPromptCode
            $script:Report.Security.UAC.PromptOnSecureDesktop = if ($null -ne $uac.PromptOnSecureDesktop) { [bool]$uac.PromptOnSecureDesktop } else { $null }
            $script:Report.Security.UAC.FilterAdministratorToken = if ($null -ne $uac.FilterAdministratorToken) { [bool]$uac.FilterAdministratorToken } else { $null }

            # Найризикованіша конфігурація UAC для адміністратора — "Elevate
            # without prompting" (код 0): підвищення привілеїв відбувається без
            # жодного запиту, повністю нівелює захист UAC для admin-облікових
            # записів. Значення 1-5 (усі варіанти "Prompt for...") — прийнятні.
            if ($script:Report.Security.UAC.Enabled -and $adminPromptCode -eq 0) {
                Add-AuditFinding -Severity 'WARNING' -Category 'Security.UAC' -Message 'UAC налаштовано на "Elevate without prompting" для адміністраторів (ConsentPromptBehaviorAdmin=0) — підвищення привілеїв без запиту.' -Recommendation 'Змініть ConsentPromptBehaviorAdmin на значення 1-5 (запит підтвердження/облікових даних), якщо немає обґрунтованого винятку.'
            }
        } else {
            Add-AuditError -Section 'Security.UAC' -Message 'Не вдалося прочитати ключ реєстру EnableLUA — стан UAC невідомий.'
        }

        $rdp = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -ErrorAction SilentlyContinue
        if ($rdp) {
            $script:Report.Security.RemoteAccess.RDPEnabled = ($rdp.fDenyTSConnections -eq 0)

            if ($script:Report.Security.RemoteAccess.RDPEnabled) {
                Add-AuditFinding -Severity 'INFO' -Category 'RemoteAccess' -Message 'RDP увімкнено.' -Recommendation 'Деталі NLA/firewall scope/дозволених користувачів — див. Security.RemoteAccess у звіті (Full/Deep/Forensic профілі); окремі WARNING породжуються автоматично, якщо NLA не вимагається або firewall-scope занадто широкий.'
            }
        } else {
            Add-AuditError -Section 'Security.RemoteAccess' -Message 'Не вдалося прочитати ключ реєстру fDenyTSConnections — стан RDP невідомий.'
        }

        try {
            $antivirusInfo = Get-WmiObject -Namespace 'root\SecurityCenter2' -Class 'AntiVirusProduct' -ErrorAction SilentlyContinue
            if ($antivirusInfo) { $script:Report.Security.Antivirus.Product = (($antivirusInfo | Select-Object -ExpandProperty displayName) -join '; ') }
        } catch {
            Add-AuditError -Section 'Security.Antivirus' -Message $_.Exception.Message
        }

        if (Get-Command Get-NetFirewallProfile -ErrorAction SilentlyContinue) {
            try {
                $firewallProfiles = Get-NetFirewallProfile -ErrorAction Stop
                foreach ($profileInfo in $firewallProfiles) {
                    $script:Report.Security.Firewall[$profileInfo.Name] = [ordered]@{
                        Enabled = $profileInfo.Enabled
                        DefaultInboundAction = $profileInfo.DefaultInboundAction.ToString()
                        DefaultOutboundAction = $profileInfo.DefaultOutboundAction.ToString()
                    }

                    if (-not $profileInfo.Enabled) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Firewall' -Message "Firewall-профіль $($profileInfo.Name) вимкнено." -Recommendation 'Перевірте політику Windows Firewall.'
                    }
                }
            } catch {
                Add-AuditError -Section 'Security.Firewall' -Message $_.Exception.Message
            }
        }

        # --- Secure Boot / TPM (Deep Security, v0.5.0) ---
        # Гейтовано Full/Deep/Forensic: не критично для Quick-профілю, і на
        # частині машин (VM без vTPM, Legacy BIOS) обидва запити стабільно
        # "не підтримується" — щоб не подовжувати найшвидший профіль зайвими
        # WMI/cmdlet-викликами без цінності.
        if ($Profile -in @('Full','Deep','Forensic')) {
            try {
                $secureBootEnabled = Confirm-SecureBootUEFI -ErrorAction Stop
                $script:Report.Security.SecureBoot.Supported = $true
                $script:Report.Security.SecureBoot.Enabled = [bool]$secureBootEnabled
                $script:Report.Security.SecureBoot.Status = if ($secureBootEnabled) { 'Enabled' } else { 'Disabled' }

                if (-not $secureBootEnabled) {
                    # INFO, не WARNING: Secure Boot вимкнений — поширений
                    # свідомий вибір (dual-boot, старіше/специфічне обладнання,
                    # dev-машини) — не впливає на Health Score/Status, лише
                    # фіксується в звіті як факт стану.
                    Add-AuditFinding -Severity 'INFO' -Category 'Security.SecureBoot' -Message 'Secure Boot підтримується, але вимкнено.' -Recommendation 'Увімкніть Secure Boot у UEFI/BIOS, якщо немає обґрунтованого винятку (dual-boot з несумісною ОС, специфічне обладнання).'
                }
            } catch {
                # Confirm-SecureBootUEFI кидає виняток і на Legacy BIOS (немає
                # UEFI — Secure Boot фізично неможливий), і на частині VM —
                # це штатний стан машини, не помилка збору (Add-AuditError
                # НЕ викликається, щоб не давати хибний exit code 1 на кожній
                # Legacy BIOS/VM-машині).
                $script:Report.Security.SecureBoot.Supported = $false
                $script:Report.Security.SecureBoot.Status = 'NotSupported'
                $script:Report.Security.SecureBoot.Error = $_.Exception.Message
            }

            try {
                $tpmInfo = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' -ClassName 'Win32_Tpm' -ErrorAction Stop | Select-Object -First 1

                if ($tpmInfo) {
                    $script:Report.Security.TPM.Present = $true
                    $script:Report.Security.TPM.Enabled = [bool]$tpmInfo.IsEnabled_InitialValue
                    $script:Report.Security.TPM.Activated = [bool]$tpmInfo.IsActivated_InitialValue
                    $script:Report.Security.TPM.Ready = $script:Report.Security.TPM.Enabled -and $script:Report.Security.TPM.Activated
                    $script:Report.Security.TPM.ManufacturerId = [string]$tpmInfo.ManufacturerId
                    $script:Report.Security.TPM.ManufacturerVersion = [string]$tpmInfo.ManufacturerVersion
                    $script:Report.Security.TPM.SpecVersion = [string]$tpmInfo.SpecVersion
                    $script:Report.Security.TPM.Status = 'Detected'

                    if (-not $script:Report.Security.TPM.Ready) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.TPM' -Message 'TPM присутній, але не увімкнений/не активований повністю.' -Recommendation 'Увімкніть і активуйте TPM у UEFI/BIOS — потрібен для BitLocker, Windows Hello, Credential Guard.'
                    }
                } else {
                    $script:Report.Security.TPM.Present = $false
                    $script:Report.Security.TPM.Status = 'NotPresent'
                }
            } catch {
                # Клас Win32_Tpm/namespace відсутній — типово означає відсутність
                # фізичного/firmware TPM (старе обладнання, VM без vTPM), не
                # помилка збору (та сама логіка, що й для Secure Boot вище).
                $script:Report.Security.TPM.Present = $false
                $script:Report.Security.TPM.Status = 'NotPresent'
                $script:Report.Security.TPM.Error = $_.Exception.Message
            }

            # --- SMBv1 ---
            if (Get-Command Get-SmbServerConfiguration -ErrorAction SilentlyContinue) {
                try {
                    $smbConfig = Get-SmbServerConfiguration -ErrorAction Stop
                    $script:Report.Security.SMBv1.Enabled = [bool]$smbConfig.EnableSMB1Protocol
                    $script:Report.Security.SMBv1.Status = if ($smbConfig.EnableSMB1Protocol) { 'Enabled' } else { 'Disabled' }

                    if ($smbConfig.EnableSMB1Protocol) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.SMBv1' -Message 'SMBv1 увімкнено — застарілий, вразливий протокол (EternalBlue/WannaCry).' -Recommendation 'Вимкніть SMBv1: Set-SmbServerConfiguration -EnableSMB1Protocol $false, якщо немає застарілих пристроїв, що вимагають саме SMBv1.'
                    }
                } catch {
                    Add-AuditError -Section 'Security.SMBv1' -Message $_.Exception.Message
                }
            } else {
                # Get-SmbServerConfiguration відсутній (застарілий Windows без
                # модуля SmbShare) — штатний стан, не помилка збору.
                $script:Report.Security.SMBv1.Status = 'NotAvailable'
            }

            # --- TLS registry status ---
            $tlsProtocolNames = @('TLS 1.0', 'TLS 1.1', 'TLS 1.2', 'TLS 1.3')
            foreach ($tlsProtocolName in $tlsProtocolNames) {
                foreach ($tlsSide in @('Client', 'Server')) {
                    $tlsRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$tlsProtocolName\$tlsSide"
                    $tlsProperties = Get-ItemProperty -Path $tlsRegistryPath -ErrorAction SilentlyContinue

                    $tlsEnabledValue = if ($tlsProperties -and $null -ne $tlsProperties.Enabled) { [int]$tlsProperties.Enabled } else { $null }
                    $tlsDisabledByDefaultValue = if ($tlsProperties -and $null -ne $tlsProperties.DisabledByDefault) { [int]$tlsProperties.DisabledByDefault } else { $null }
                    $tlsStatus = Get-BravoTlsProtocolStatus -Enabled $tlsEnabledValue -DisabledByDefault $tlsDisabledByDefaultValue

                    $script:Report.Security.TLS.Protocols += [PSCustomObject]@{
                        Protocol           = $tlsProtocolName
                        Side               = $tlsSide
                        Enabled            = $tlsEnabledValue
                        DisabledByDefault  = $tlsDisabledByDefaultValue
                        Status             = $tlsStatus
                    }

                    # Застарілі протоколи (1.0/1.1) явно увімкнені реєстром —
                    # адміністратор свідомо переозначив ОС-дефолт у бік менш
                    # безпечного стану. TLS 1.2 явно вимкнений — навпаки,
                    # ризик сумісності (більшість сучасних клієнтів/серверів
                    # вимагають мінімум 1.2). 'NotConfigured' (найпоширеніший
                    # стан на реальних машинах — ОС-дефолт) НЕ породжує
                    # finding: адмін нічого не змінював, немає що звинувачувати.
                    if ($tlsProtocolName -in @('TLS 1.0', 'TLS 1.1') -and $tlsStatus -eq 'Enabled' -and $tlsEnabledValue -eq 1) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.TLS' -Message "$tlsProtocolName ($tlsSide) явно увімкнено через реєстр — застарілий протокол." -Recommendation 'Вимкніть застарілі TLS-версії через SCHANNEL registry, якщо немає застарілих клієнтів/серверів, що вимагають саме цю версію.'
                    } elseif ($tlsProtocolName -eq 'TLS 1.2' -and $tlsStatus -eq 'Disabled') {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.TLS' -Message "TLS 1.2 ($tlsSide) вимкнено через реєстр — ризик сумісності з сучасними клієнтами/серверами." -Recommendation 'Перевірте, чи це свідоме рішення; TLS 1.2 зазвичай мінімально необхідна версія для сучасних з''єднань.'
                    }
                }
            }

            # --- Defender details ---
            if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
                try {
                    $defenderStatus = Get-MpComputerStatus -ErrorAction Stop

                    $script:Report.Security.Defender.Available = $true
                    $script:Report.Security.Defender.AMServiceEnabled = [bool]$defenderStatus.AMServiceEnabled
                    $script:Report.Security.Defender.AntivirusEnabled = [bool]$defenderStatus.AntivirusEnabled
                    $script:Report.Security.Defender.RealTimeProtectionEnabled = [bool]$defenderStatus.RealTimeProtectionEnabled
                    $script:Report.Security.Defender.BehaviorMonitorEnabled = [bool]$defenderStatus.BehaviorMonitorEnabled
                    $script:Report.Security.Defender.AntivirusSignatureVersion = [string]$defenderStatus.AntivirusSignatureVersion
                    $script:Report.Security.Defender.AMEngineVersion = [string]$defenderStatus.AMEngineVersion
                    $script:Report.Security.Defender.AMProductVersion = [string]$defenderStatus.AMProductVersion
                    $script:Report.Security.Defender.Status = 'Detected'

                    if ($defenderStatus.AntivirusSignatureLastUpdated) {
                        $script:Report.Security.Defender.AntivirusSignatureLastUpdated = $defenderStatus.AntivirusSignatureLastUpdated.ToString('yyyy-MM-dd HH:mm:ss')
                        $script:Report.Security.Defender.AntivirusSignatureAgeDays = [Math]::Round(((Get-Date) - $defenderStatus.AntivirusSignatureLastUpdated).TotalDays)
                    }

                    # RealTimeProtectionEnabled=$false на машині зі стороннім
                    # антивірусом (напр. цей же script:Report.Security.Antivirus.Product
                    # показує інший продукт) — очікуваний, не тривожний стан:
                    # Defender свідомо переходить у passive mode. Тут навмисно
                    # НЕ звіряємо з Antivirus.Product (окрема, вже зібрана
                    # SecurityCenter2-знахідка) — просто повідомляємо факт, без
                    # спроби вгадати "чи це нормально", щоб не плодити хибних
                    # WARNING/не-WARNING рішень на основі непрямих ознак.
                    if (-not $script:Report.Security.Defender.RealTimeProtectionEnabled) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.Defender' -Message 'Windows Defender Real-Time Protection вимкнено.' -Recommendation 'Перевірте, чи це свідоме рішення (напр. активний сторонній антивірус) — якщо ні, увімкніть Real-Time Protection.'
                    }

                    if ($null -ne $script:Report.Security.Defender.AntivirusSignatureAgeDays -and $script:Report.Security.Defender.AntivirusSignatureAgeDays -gt 7) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.Defender' -Message "Сигнатури Windows Defender застарілі: $($script:Report.Security.Defender.AntivirusSignatureAgeDays) днів з останнього оновлення." -Recommendation 'Запустіть оновлення сигнатур антивіруса (Update-MpSignature) та перевірте підключення до Windows Update.'
                    }
                } catch {
                    # Get-MpComputerStatus може падати, коли служба Defender
                    # вимкнена GPO/сторонім антивірусом — штатний стан машини,
                    # не помилка збору.
                    $script:Report.Security.Defender.Available = $false
                    $script:Report.Security.Defender.Status = 'Unavailable'
                    $script:Report.Security.Defender.Error = $_.Exception.Message
                }
            } else {
                $script:Report.Security.Defender.Available = $false
                $script:Report.Security.Defender.Status = 'NotAvailable'
            }

            # --- RDP details: NLA, port, firewall scope, allowed users ---
            if ($script:Report.Security.RemoteAccess.RDPEnabled) {
                try {
                    $rdpTcpConfig = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -ErrorAction SilentlyContinue
                    if ($rdpTcpConfig) {
                        $script:Report.Security.RemoteAccess.NLAEnabled = ($rdpTcpConfig.UserAuthentication -eq 1)
                        $script:Report.Security.RemoteAccess.Port = $rdpTcpConfig.PortNumber

                        if (-not $script:Report.Security.RemoteAccess.NLAEnabled) {
                            Add-AuditFinding -Severity 'WARNING' -Category 'RemoteAccess' -Message 'RDP увімкнено, але Network Level Authentication (NLA) не вимагається.' -Recommendation 'Увімкніть вимогу NLA для RDP (UserAuthentication=1), якщо немає застарілих клієнтів, що не підтримують NLA.'
                        }
                    }
                } catch {
                    Add-AuditError -Section 'Security.RemoteAccess.NLA' -Message $_.Exception.Message
                }

                # RemoteDesktop-UserMode-In-TCP — вбудоване, НЕ локалізоване ім'я
                # правила (на відміну від DisplayGroup/DisplayName, які на
                # неанглійських збірках Windows перекладені й ненадійні для
                # програмного пошуку).
                if (Get-Command Get-NetFirewallRule -ErrorAction SilentlyContinue) {
                    try {
                        $rdpFirewallRule = Get-NetFirewallRule -Name 'RemoteDesktop-UserMode-In-TCP' -ErrorAction Stop
                        $script:Report.Security.RemoteAccess.FirewallProfiles = $rdpFirewallRule.Profile.ToString()

                        if ($rdpFirewallRule.Enabled) {
                            $rdpAddressFilter = Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $rdpFirewallRule -ErrorAction Stop
                            $script:Report.Security.RemoteAccess.FirewallScope = ($rdpAddressFilter.RemoteAddress -join ', ')

                            if ($script:Report.Security.RemoteAccess.FirewallScope -eq 'Any' -and $rdpFirewallRule.Profile.ToString() -match 'Public') {
                                Add-AuditFinding -Severity 'WARNING' -Category 'RemoteAccess' -Message 'RDP firewall-правило дозволяє підключення з будь-якої адреси (RemoteAddress=Any) у Public-профілі.' -Recommendation 'Обмежте RemoteAddress конкретними підмережами/VPN-діапазоном, особливо для Public-профілю фаєрвола.'
                            }
                        }
                    } catch {
                        # Вбудоване правило відсутнє/перейменоване (нетипова
                        # конфігурація) — не помилка збору, просто немає даних.
                    }
                }

                if (Get-Command Get-LocalGroupMember -ErrorAction SilentlyContinue) {
                    try {
                        $rdpGroupMembers = Get-LocalGroupMember -Group 'Remote Desktop Users' -ErrorAction Stop
                        $script:Report.Security.RemoteAccess.AllowedUsers = @($rdpGroupMembers | ForEach-Object { $_.Name })
                    } catch {
                        # Група "Remote Desktop Users" може не існувати
                        # (локалізована назва на не-EN збірках, або взагалі
                        # відсутня) — не помилка збору.
                    }
                }
            }

            # --- WinRM: listeners, auth ---
            $winrmService = Get-Service -Name 'WinRM' -ErrorAction SilentlyContinue
            if ($winrmService) {
                $script:Report.Security.WinRM.ServiceStatus = $winrmService.Status.ToString()

                if ($winrmService.Status -eq 'Running') {
                    try {
                        $winrmListeners = Get-ChildItem 'WSMan:\localhost\Listener' -ErrorAction Stop
                        foreach ($listener in $winrmListeners) {
                            $listenerProps = Get-ChildItem $listener.PSPath -ErrorAction Stop
                            $script:Report.Security.WinRM.Listeners += [PSCustomObject]@{
                                Transport = ($listenerProps | Where-Object { $_.Name -eq 'Transport' }).Value
                                Port      = ($listenerProps | Where-Object { $_.Name -eq 'Port' }).Value
                                Enabled   = ($listenerProps | Where-Object { $_.Name -eq 'Enabled' }).Value
                            }
                        }

                        $winrmAuth = Get-ChildItem 'WSMan:\localhost\Service\Auth' -ErrorAction Stop
                        foreach ($authSetting in @('Basic', 'Kerberos', 'Negotiate', 'Certificate', 'CredSSP')) {
                            $matchedAuthSetting = $winrmAuth | Where-Object { $_.Name -eq $authSetting }
                            if ($matchedAuthSetting) {
                                $script:Report.Security.WinRM.Auth[$authSetting] = [System.Convert]::ToBoolean($matchedAuthSetting.Value)
                            }
                        }

                        $script:Report.Security.WinRM.Status = 'Detected'

                        if ($script:Report.Security.WinRM.Auth.Basic -eq $true) {
                            Add-AuditFinding -Severity 'WARNING' -Category 'Security.WinRM' -Message 'WinRM Basic authentication увімкнено.' -Recommendation 'Вимкніть Basic auth для WinRM, якщо немає обґрунтованої потреби — креденшели передаються без надійного захисту поза HTTPS-транспортом.'
                        }

                        if ($script:Report.Security.WinRM.Auth.CredSSP -eq $true) {
                            Add-AuditFinding -Severity 'WARNING' -Category 'Security.WinRM' -Message 'WinRM CredSSP authentication увімкнено.' -Recommendation 'CredSSP дозволяє делегування креденшелів (ризик relay/pass-the-hash) — вимкніть, якщо не потрібен саме подвійний hop.'
                        }
                    } catch {
                        Add-AuditError -Section 'Security.WinRM' -Message $_.Exception.Message
                    }
                } else {
                    $script:Report.Security.WinRM.Status = 'ServiceNotRunning'
                }
            } else {
                $script:Report.Security.WinRM.Status = 'NotAvailable'
            }

            # --- SMB signing / insecure guest access ---
            if (Get-Command Get-SmbServerConfiguration -ErrorAction SilentlyContinue) {
                try {
                    $smbServerConfig = Get-SmbServerConfiguration -ErrorAction Stop
                    $smbClientConfig = Get-SmbClientConfiguration -ErrorAction Stop

                    $script:Report.Security.SMB.ServerSigningRequired = [bool]$smbServerConfig.RequireSecuritySignature
                    $script:Report.Security.SMB.ServerSigningEnabled = [bool]$smbServerConfig.EnableSecuritySignature
                    $script:Report.Security.SMB.ClientSigningRequired = [bool]$smbClientConfig.RequireSecuritySignature
                    $script:Report.Security.SMB.InsecureGuestLogonsEnabled = [bool]$smbClientConfig.EnableInsecureGuestLogons
                    $script:Report.Security.SMB.Status = 'Detected'

                    if (-not $script:Report.Security.SMB.ServerSigningRequired) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.SMB' -Message 'SMB server signing не є обов''язковим (RequireSecuritySignature=False).' -Recommendation 'Увімкніть обов''язковий SMB signing на сервері — знижує ризик SMB relay-атак (напр. NTLM relay).'
                    }

                    if ($script:Report.Security.SMB.InsecureGuestLogonsEnabled) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.SMB' -Message 'SMB client дозволяє insecure guest logons.' -Recommendation 'Вимкніть EnableInsecureGuestLogons — небезпечний fallback на неавтентифікований guest-доступ до SMB-серверів.'
                    }
                } catch {
                    Add-AuditError -Section 'Security.SMB' -Message $_.Exception.Message
                }
            } else {
                $script:Report.Security.SMB.Status = 'NotAvailable'
            }

            # --- Password policy (net accounts) ---
            try {
                $netAccountsOutput = & net accounts 2>&1

                if ($LASTEXITCODE -eq 0) {
                    $parsedPolicy = ConvertFrom-BravoNetAccountsOutput -Lines $netAccountsOutput

                    $script:Report.Security.PasswordPolicy.MinPasswordAgeDays = $parsedPolicy.MinPasswordAgeDays
                    $script:Report.Security.PasswordPolicy.MaxPasswordAgeDays = $parsedPolicy.MaxPasswordAgeDays
                    $script:Report.Security.PasswordPolicy.MinPasswordLength = $parsedPolicy.MinPasswordLength
                    $script:Report.Security.PasswordPolicy.PasswordHistoryLength = $parsedPolicy.PasswordHistoryLength
                    $script:Report.Security.PasswordPolicy.LockoutThreshold = $parsedPolicy.LockoutThreshold
                    $script:Report.Security.PasswordPolicy.LockoutDurationMinutes = $parsedPolicy.LockoutDurationMinutes
                    $script:Report.Security.PasswordPolicy.LockoutObservationWindowMinutes = $parsedPolicy.LockoutObservationWindowMinutes
                    $script:Report.Security.PasswordPolicy.Status = 'Detected'

                    # Findings рахуються лише з ЧИСЛОВИХ значень (locale-безпечно
                    # — цифри не локалізуються так, як текстові мітки/значення
                    # "Never"/"None"/"Unlimited"). Нечислове значення (не
                    # вдалось [int]::TryParse) залишає поле "не оцінене" —
                    # свідомо без спроби вгадати сенс локалізованого слова.
                    $minLength = 0
                    if ([int]::TryParse($script:Report.Security.PasswordPolicy.MinPasswordLength, [ref]$minLength) -and $minLength -lt 8) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.PasswordPolicy' -Message "Мінімальна довжина пароля замала: $minLength символів." -Recommendation 'Встановіть мінімальну довжину пароля не менше 8 символів (net accounts /minpwlen:8 або групова політика).'
                    }

                    $lockoutThreshold = 0
                    if ([int]::TryParse($script:Report.Security.PasswordPolicy.LockoutThreshold, [ref]$lockoutThreshold) -and $lockoutThreshold -eq 0) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.PasswordPolicy' -Message 'Політика блокування облікового запису вимкнена (Lockout threshold=0) — необмежена кількість спроб входу.' -Recommendation 'Встановіть lockout threshold (напр. 5-10 невдалих спроб) для захисту від brute-force атак.'
                    }

                    $historyLength = 0
                    if ([int]::TryParse($script:Report.Security.PasswordPolicy.PasswordHistoryLength, [ref]$historyLength) -and $historyLength -eq 0) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.PasswordPolicy' -Message 'Історія паролів вимкнена (0) — користувачі можуть одразу повторно використовувати старий пароль.' -Recommendation 'Встановіть довжину історії паролів (напр. 5-24) для заборони повторного використання.'
                    }
                } else {
                    $script:Report.Security.PasswordPolicy.Status = 'Unavailable'
                }
            } catch {
                # `net accounts` недоступний (напр. обмежене середовище без
                # net.exe) — не типова ситуація на Windows, але не помилка
                # інструмента, якщо трапиться.
                $script:Report.Security.PasswordPolicy.Status = 'Unavailable'
                $script:Report.Security.PasswordPolicy.Error = $_.Exception.Message
            }

            # --- Audit policy (auditpol) ---
            # Свідомо БЕЗ findings на основі тексту "Inclusion Setting": ці
            # значення (напр. "No Auditing"/"Success and Failure") — локалізовані
            # рядки auditpol.exe, на відміну від числових полів password policy
            # вище. Судити "недостатньо аудиту" за збігом англійського тексту
            # було б ненадійно на не-EN системах — просто публікуємо сирі дані.
            if (Get-Command auditpol -ErrorAction SilentlyContinue) {
                try {
                    $auditPolicyCsv = & auditpol /get /category:* /r 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        $auditPolicyEntries = $auditPolicyCsv | ConvertFrom-Csv -ErrorAction Stop

                        foreach ($entry in $auditPolicyEntries) {
                            $script:Report.Security.AuditPolicy.Subcategories += [PSCustomObject]@{
                                Category          = $entry.'Policy Target'
                                Subcategory       = $entry.Subcategory
                                SubcategoryGuid   = $entry.'Subcategory GUID'
                                InclusionSetting  = $entry.'Inclusion Setting'
                            }
                        }

                        $script:Report.Security.AuditPolicy.TotalCount = $script:Report.Security.AuditPolicy.Subcategories.Count
                        $script:Report.Security.AuditPolicy.Status = 'Detected'
                    } else {
                        $script:Report.Security.AuditPolicy.Status = 'Unavailable'
                    }
                } catch {
                    Add-AuditError -Section 'Security.AuditPolicy' -Message $_.Exception.Message
                }
            } else {
                $script:Report.Security.AuditPolicy.Status = 'NotAvailable'
            }

            # --- Autoruns: реєстрові Run/RunOnce (HKLM/HKCU + Wow6432Node на
            # 64-bit) + папки автозавантаження (User/AllUsers Startup).
            # Гейтовано окремо Deep/Forensic (не Full) — набагато більший
            # обсяг даних, ніж решта Security-блоку вище.
            if ($Profile -in @('Deep','Forensic')) {
                try {
                    $autorunRegistryTargets = @(
                        [PSCustomObject]@{ Hive = 'HKLM'; Source = 'Run';     Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' }
                        [PSCustomObject]@{ Hive = 'HKLM'; Source = 'RunOnce'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' }
                        [PSCustomObject]@{ Hive = 'HKLM'; Source = 'Run (Wow6432Node)';     Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' }
                        [PSCustomObject]@{ Hive = 'HKLM'; Source = 'RunOnce (Wow6432Node)'; Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce' }
                        [PSCustomObject]@{ Hive = 'HKCU'; Source = 'Run';     Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' }
                        [PSCustomObject]@{ Hive = 'HKCU'; Source = 'RunOnce'; Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' }
                    )

                    foreach ($target in $autorunRegistryTargets) {
                        if (-not (Test-Path -LiteralPath $target.Path)) { continue }
                        try {
                            $keyProperties = Get-ItemProperty -LiteralPath $target.Path -ErrorAction Stop
                            $entries = ConvertFrom-BravoRegistryKeyProperties -PropertiesObject $keyProperties
                            foreach ($entry in $entries) {
                                $script:Report.Security.Autoruns += [PSCustomObject]@{
                                    Name    = $entry.Name
                                    Command = $entry.Value
                                    Source  = $target.Source
                                    Hive    = $target.Hive
                                }
                            }
                        } catch {
                            Add-AuditError -Section "Security.Autoruns.$($target.Source)" -Message $_.Exception.Message
                        }
                    }

                    # Папки автозавантаження — окремий механізм autorun, не
                    # реєстровий; WOW6432Node-варіанту тут немає (шлях на
                    # файловій системі однаковий для 32/64-bit процесів).
                    $startupFolders = @(
                        [PSCustomObject]@{ Hive = 'HKCU'; Source = 'StartupFolder (User)';     Path = [Environment]::GetFolderPath('Startup') }
                        [PSCustomObject]@{ Hive = 'HKLM'; Source = 'StartupFolder (AllUsers)'; Path = [Environment]::GetFolderPath('CommonStartup') }
                    )

                    foreach ($folder in $startupFolders) {
                        if (-not $folder.Path -or -not (Test-Path -LiteralPath $folder.Path)) { continue }
                        try {
                            $files = Get-ChildItem -LiteralPath $folder.Path -File -ErrorAction Stop
                            foreach ($file in $files) {
                                # desktop.ini — штатний системний файл папки, не autorun-запис.
                                if ($file.Name -eq 'desktop.ini') { continue }
                                $script:Report.Security.Autoruns += [PSCustomObject]@{
                                    Name    = $file.BaseName
                                    Command = $file.FullName
                                    Source  = $folder.Source
                                    Hive    = $folder.Hive
                                }
                            }
                        } catch {
                            Add-AuditError -Section "Security.Autoruns.$($folder.Source)" -Message $_.Exception.Message
                        }
                    }
                } catch {
                    Add-AuditError -Section 'Security.Autoruns' -Message $_.Exception.Message
                }
            }
            # Відсутність autorun-записів (чисте автозавантаження) — штатний
            # стан, не помилка збору; $script:Report.Security.Autoruns
            # лишається порожнім масивом.

            # --- Scheduled tasks: гейтовано окремо Deep/Forensic (той самий
            # принцип, що й Autoruns вище — суттєво більший обсяг даних, ніж
            # решта Security-блоку). Вбудовані задачі Windows (TaskPath
            # \Microsoft\Windows\*) — типово 200-300+ на кожній машині; замість
            # приховування (втрата даних) або показу всіх без розбору (шум),
            # позначаємо прапорцем IsMicrosoftDefault=true — той самий
            # принцип "дані видимі, findings обережні", що вже застосований
            # для ARP/Storage ReservedVolumes.
            if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
                try {
                    $scheduledTasks = Get-ScheduledTask -ErrorAction Stop
                    foreach ($task in $scheduledTasks) {
                        $firstAction = $task.Actions | Select-Object -First 1
                        $script:Report.Security.ScheduledTasks += [PSCustomObject]@{
                            Name               = $task.TaskName
                            Path               = $task.TaskPath
                            State              = [string]$task.State
                            Author             = $task.Author
                            Execute            = if ($firstAction) { [string]$firstAction.Execute } else { '' }
                            Arguments          = if ($firstAction) { [string]$firstAction.Arguments } else { '' }
                            IsMicrosoftDefault = [bool]($task.TaskPath -like '\Microsoft\Windows\*')
                        }
                    }
                } catch {
                    Add-AuditError -Section 'Security.ScheduledTasks' -Message $_.Exception.Message
                }
            }
            # Get-ScheduledTask відсутній (модуль ScheduledTasks не
            # встановлено, напр. деякі Server Core збірки) — штатний стан,
            # $script:Report.Security.ScheduledTasks лишається порожнім
            # масивом.

            Write-Host "  $IconSecurity Secure Boot: $($script:Report.Security.SecureBoot.Status), TPM: $($script:Report.Security.TPM.Status), SMBv1: $($script:Report.Security.SMBv1.Status), Defender: $($script:Report.Security.Defender.Status), WinRM: $($script:Report.Security.WinRM.Status), Password policy: $($script:Report.Security.PasswordPolicy.Status), Audit policy: $($script:Report.Security.AuditPolicy.Status) ($($script:Report.Security.AuditPolicy.TotalCount))" -ForegroundColor Green
        }

        Write-Host "  $IconSecurity Безпека: RDP=$(if($script:Report.Security.RemoteAccess.RDPEnabled){'ON'}else{'OFF'}), UAC=$(if($script:Report.Security.UAC.Enabled){'ON'}else{'OFF'})" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Security' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка даних безпеки: $($_.Exception.Message)" -ForegroundColor Red
    }
}


# ============================================================
# MODULE: src/35-Collectors-Users.ps1
# ============================================================

# MODULE: 35-Collectors-Users.ps1
# Збір інформації про локальних користувачів та адміністраторів.

function Get-LocalAdministratorsSafe {
    $members = @()

    try {
        $adminGroupSid = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
        $adminGroupName = $adminGroupSid.Translate([Security.Principal.NTAccount]).Value.Split('\\')[-1]
    } catch {
        $adminGroupName = 'Administrators'
    }

    if (Get-Command Get-LocalGroupMember -ErrorAction SilentlyContinue) {
        try {
            $members = Get-LocalGroupMember -Group $adminGroupName -ErrorAction Stop |
                Select-Object -ExpandProperty Name
            return @($members)
        } catch {
            Add-AuditError -Section 'Users.LocalAdmins.GetLocalGroupMember' -Message $_.Exception.Message
        }
    }

    try {
        $raw = net localgroup "$adminGroupName" 2>$null
        if ($raw) {
            # Завершальний рядок "The command completed successfully." (net.exe)
            # локалізується разом з MUI-пакетом Windows — раніше тут матчився
            # текст лише для en/uk, на інших локалях (ru/de/pl/...) фальшивий
            # службовий рядок потрапляв у список адмінів. net localgroup
            # структурно ЗАВЖДИ завершує вивід рівно одним таким рядком
            # одразу після переліку членів, тому замість тексту-матчингу
            # просто відкидаємо останній непорожній рядок після роздільника
            # "----" — це локале-незалежно.
            $capture = $false
            $capturedLines = New-Object System.Collections.Generic.List[string]
            foreach ($line in $raw) {
                $text = ($line | Out-String).Trim()
                if (-not $text) { continue }
                if ($text -match '^-{3,}$') { $capture = $true; continue }
                if ($capture) { $capturedLines.Add($text) }
            }
            if ($capturedLines.Count -gt 0) {
                # Останній рядок — завжди статус-повідомлення net.exe, не ім'я.
                $capturedLines.RemoveAt($capturedLines.Count - 1)
            }
            $members = @($capturedLines)
        }
    } catch {
        Add-AuditError -Section 'Users.LocalAdmins.NetLocalGroup' -Message $_.Exception.Message
    }

    return @($members)
}

function Get-BravoUsersAudit {
    [CmdletBinding()]
    param()

    # --- Користувачі ---
    try {
        $script:Report.Users.LocalAdmins = @(Get-LocalAdministratorsSafe | Where-Object { $_ } | Select-Object -Unique)
    } catch {
        Add-AuditError -Section 'Users' -Message $_.Exception.Message
    }
}


# ============================================================
# MODULE: src/36-Collectors-ProcessesServices.ps1
# ============================================================

# MODULE: 36-Collectors-ProcessesServices.ps1
# Збір інформації про процеси, служби та автоматичні служби, які не запущені.

function Get-BravoProcessesServicesAudit {
    [CmdletBinding()]
    param()

    # --- Процеси ---
    try {
        $processInfo = Get-Process -ErrorAction Stop
        $script:Report.Processes.Total = $processInfo.Count
        if ($Profile -in @('Full','Deep','Forensic')) {
            try {
                # WorkingSet64 обчислюється лениво при першому зверненні (потребує
                # handle до процесу), а не кешується в момент Get-Process — якщо
                # короткоживучий процес завершується між Get-Process і Sort-Object,
                # звернення до .WorkingSet64 усередині сортування кидає виняток
                # "process has exited" і валить весь TopMemory разом з рештою
                # процесів. Тому знімаємо WorkingSet64 у власному try/catch на
                # кожен процес окремо — процес, що встиг завершитись, просто
                # пропускається, решта топ-10 все одно рахується.
                $processSnapshot = New-Object System.Collections.Generic.List[object]
                foreach ($proc in $processInfo) {
                    try {
                        $processSnapshot.Add([PSCustomObject]@{
                            ProcessName = $proc.ProcessName
                            Id          = $proc.Id
                            MemoryMB    = [Math]::Round($proc.WorkingSet64 / 1MB, 2)
                        })
                    } catch {
                        # Свідомо ігноруємо: процес завершився між Get-Process і
                        # зверненням до WorkingSet64 — не переривляємо збір топ-10
                        # через один короткоживучий процес.
                    }
                }
                $script:Report.Processes.TopMemory = @($processSnapshot | Sort-Object -Property MemoryMB -Descending | Select-Object -First 10)
            } catch {
                Add-AuditError -Section 'Processes.TopMemory' -Message $_.Exception.Message
            }
        }
        Write-Host "  $IconService Процеси: $($script:Report.Processes.Total)" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Processes' -Message $_.Exception.Message
    }

    # --- Служби ---
    try {
        $serviceInfo = Get-Service -ErrorAction Stop
        $script:Report.Services.Total = $serviceInfo.Count
        $script:Report.Services.Running = @($serviceInfo | Where-Object { $_.Status -eq 'Running' }).Count

        if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
            try {
                # Відомі trigger-start/опціональні служби Windows: WMI показує їх як
                # StartMode='Auto', але вони штатно стоять Stopped, поки їх не розбудить
                # тригер (подія/пристрій/попит) — це не ознака проблеми на машині.
                # RemoteRegistry особливо: зупинена = добре (security best practice).
                $bravoKnownTriggerStartServices = @(
                    'edgeupdate', 'edgeupdatem', 'gupdate', 'gupdatem',
                    'MapsBroker', 'sppsvc', 'WbioSrvc', 'RemoteRegistry'
                )

                $autoStopped = Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State<>'Running'" -ErrorAction Stop
                $script:Report.Services.AutomaticStopped = @($autoStopped | Select-Object Name, DisplayName, State, StartMode, StartName)

                $noteworthyStopped = @($script:Report.Services.AutomaticStopped | Where-Object { $_.Name -notin $bravoKnownTriggerStartServices })

                if ($noteworthyStopped.Count -gt 0) {
                    $totalStoppedCount = $script:Report.Services.AutomaticStopped.Count
                    $noiseCount = $totalStoppedCount - $noteworthyStopped.Count
                    $noiseNote = if ($noiseCount -gt 0) { " (ще $noiseCount — відомі trigger-start/опціональні служби, не є ризиком)" } else { '' }

                    Add-AuditFinding -Severity 'WARNING' -Category 'Services' -Message "Автоматичних служб не запущено: $($noteworthyStopped.Count)$noiseNote." -Recommendation 'Перевірте, чи ці служби мають бути запущені.'
                }
            } catch {
                Add-AuditError -Section 'Services.AutomaticStopped' -Message $_.Exception.Message
            }
        }
    } catch {
        Add-AuditError -Section 'Services' -Message $_.Exception.Message
    }
}


# ============================================================
# MODULE: src/37-Collectors-Events.ps1
# ============================================================

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


# ============================================================
# MODULE: src/38-Collectors-Software.ps1
# ============================================================

# MODULE: 38-Collectors-Software.ps1
# Збір інформації про встановлене програмне забезпечення.

function Get-BravoSoftwareAudit {
    [CmdletBinding()]
    param()

    # --- Програмне забезпечення ---
    try {
        $softwareRegistryPaths = @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )

        if ($Profile -in @('Deep','Forensic')) {
            $softwareRegistryPaths += 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        }

        $softwareInfo = Get-ItemProperty $softwareRegistryPaths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayName -notlike '*Update*' } |
            Sort-Object DisplayName -Unique

        foreach ($softwareItem in $softwareInfo) {
            if ($Profile -eq 'Quick') {
                $script:Report.Software.Installed += $softwareItem.DisplayName
            } else {
                $script:Report.Software.Installed += [PSCustomObject]@{
                    DisplayName    = $softwareItem.DisplayName
                    DisplayVersion = $softwareItem.DisplayVersion
                    Publisher      = $softwareItem.Publisher
                    InstallDate    = $softwareItem.InstallDate
                    InstallLocation = $softwareItem.InstallLocation
                }
            }
        }

        Write-Host "  $IconDb ПЗ: $($script:Report.Software.Installed.Count) програм" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Software' -Message $_.Exception.Message
    }
}


# ============================================================
# MODULE: src/39a-Data-WindowsLifecycle.ps1
# ============================================================

# MODULE: 39a-Data-WindowsLifecycle.ps1
# Централізований data-модуль: статична таблиця життєвого циклу Windows.
# Винесено з src/39-Collectors-Updates.ps1 (P0.7), щоб оновлення дат
# не вимагало правок логіки колектора Get-BravoOsSupportInfo.

# Дата актуальності статичної таблиці життєвого циклу Windows.
# Оновлюйте разом із таблицею у Get-BravoWindowsLifecycleTable.
# Звірено з офіційними lifecycle-сторінками Microsoft Learn (learn.microsoft.com/lifecycle).
$script:BravoLifecycleTableUpdatedAt = '2026-09-01'

function Get-BravoWindowsLifecycleTable {
    [CmdletBinding()]
    param()

    # Статична таблиця життєвого циклу Windows.
    # Дані потребують періодичного оновлення разом із $BravoLifecycleTableUpdatedAt.
    #
    # SupportEndConsumer   — Home / Pro / Core-редакції.
    # SupportEndEnterprise — Enterprise / Education / серверні редакції.
    # SupportEndLtsc       — LTSC / LTSB-редакції (порожнє, якщо такої редакції немає).
    #
    # Свідомі виключення:
    # - IoT LTSC-редакції з довшими термінами не виділені окремо;
    # - дати ESU не використовуються (наприклад, Windows 7 SP1 і Server 2008 R2 SP1 показують 2020-01-14,
    #   а не 2023-01-10; Windows 10 22H2 показує 2025-10-14, а не дату завершення ESU);
    # - Windows Server SAC 1809 пропущено, бо build 17763 збігається з Windows Server 2019 (LTSC);
    # - дати наведені як публічно оголошена дата (офіційна raw "Retirement Date" на learn.microsoft.com/lifecycle
    #   вказана як HH:59:59 наступного календарного дня в PT — тут узгоджено з публічним анонсом, на 1 день раніше).
    return @(
        # --- Клієнтські випуски ---
        [PSCustomObject]@{ Build = 26200; IsServer = $false; Product = 'Windows 11'                    ; DisplayVersion = '25H2'                ; SupportEndConsumer = '2027-10-12'; SupportEndEnterprise = '2028-10-10'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 26100; IsServer = $false; Product = 'Windows 11'                    ; DisplayVersion = '24H2'                ; SupportEndConsumer = '2026-10-13'; SupportEndEnterprise = '2027-10-12'; SupportEndLtsc = '2029-10-09' }
        [PSCustomObject]@{ Build = 22631; IsServer = $false; Product = 'Windows 11'                    ; DisplayVersion = '23H2'                ; SupportEndConsumer = '2025-11-11'; SupportEndEnterprise = '2026-11-10'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 22621; IsServer = $false; Product = 'Windows 11'                    ; DisplayVersion = '22H2'                ; SupportEndConsumer = '2024-10-08'; SupportEndEnterprise = '2025-10-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 22000; IsServer = $false; Product = 'Windows 11'                    ; DisplayVersion = '21H2'                ; SupportEndConsumer = '2023-10-10'; SupportEndEnterprise = '2024-10-08'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 19045; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '22H2'                ; SupportEndConsumer = '2025-10-14'; SupportEndEnterprise = '2025-10-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 19044; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '21H2'                ; SupportEndConsumer = '2023-06-13'; SupportEndEnterprise = '2024-06-11'; SupportEndLtsc = '2027-01-12' }
        [PSCustomObject]@{ Build = 19043; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '21H1'                ; SupportEndConsumer = '2022-12-13'; SupportEndEnterprise = '2022-12-13'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 19042; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '20H2'                ; SupportEndConsumer = '2022-05-10'; SupportEndEnterprise = '2023-05-09'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 19041; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '2004'                ; SupportEndConsumer = '2021-12-14'; SupportEndEnterprise = '2021-12-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 18363; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1909'                ; SupportEndConsumer = '2021-05-11'; SupportEndEnterprise = '2022-05-10'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 18362; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1903'                ; SupportEndConsumer = '2020-12-08'; SupportEndEnterprise = '2020-12-08'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 17763; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1809'                ; SupportEndConsumer = '2020-11-10'; SupportEndEnterprise = '2021-05-11'; SupportEndLtsc = '2029-01-09' }
        [PSCustomObject]@{ Build = 17134; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1803'                ; SupportEndConsumer = '2019-11-12'; SupportEndEnterprise = '2021-05-11'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 16299; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1709'                ; SupportEndConsumer = '2019-04-09'; SupportEndEnterprise = '2020-10-13'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 15063; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1703'                ; SupportEndConsumer = '2018-10-09'; SupportEndEnterprise = '2019-10-08'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 14393; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1607'                ; SupportEndConsumer = '2018-04-10'; SupportEndEnterprise = '2019-04-09'; SupportEndLtsc = '2026-10-13' }
        [PSCustomObject]@{ Build = 10586; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1511'                ; SupportEndConsumer = '2017-10-10'; SupportEndEnterprise = '2017-10-10'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 10240; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1507'                ; SupportEndConsumer = '2017-05-09'; SupportEndEnterprise = '2017-05-09'; SupportEndLtsc = '2025-10-14' }
        [PSCustomObject]@{ Build = 9600 ; IsServer = $false; Product = 'Windows 8.1'                   ; DisplayVersion = '8.1'                 ; SupportEndConsumer = '2023-01-10'; SupportEndEnterprise = '2023-01-10'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 9200 ; IsServer = $false; Product = 'Windows 8'                     ; DisplayVersion = 'RTM'                 ; SupportEndConsumer = '2016-01-12'; SupportEndEnterprise = '2016-01-12'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 7601 ; IsServer = $false; Product = 'Windows 7'                     ; DisplayVersion = 'SP1'                 ; SupportEndConsumer = '2020-01-14'; SupportEndEnterprise = '2020-01-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 7600 ; IsServer = $false; Product = 'Windows 7'                     ; DisplayVersion = 'RTM'                 ; SupportEndConsumer = '2013-04-09'; SupportEndEnterprise = '2013-04-09'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 6002 ; IsServer = $false; Product = 'Windows Vista'                 ; DisplayVersion = 'SP2'                 ; SupportEndConsumer = '2017-04-11'; SupportEndEnterprise = '2017-04-11'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 6001 ; IsServer = $false; Product = 'Windows Vista'                 ; DisplayVersion = 'SP1'                 ; SupportEndConsumer = '2011-07-12'; SupportEndEnterprise = '2011-07-12'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 6000 ; IsServer = $false; Product = 'Windows Vista'                 ; DisplayVersion = 'RTM'                 ; SupportEndConsumer = '2010-04-13'; SupportEndEnterprise = '2010-04-13'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 3790 ; IsServer = $false; Product = 'Windows XP Professional x64'   ; DisplayVersion = 'SP2'                 ; SupportEndConsumer = '2014-04-08'; SupportEndEnterprise = '2014-04-08'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 2600 ; IsServer = $false; Product = 'Windows XP'                    ; DisplayVersion = 'SP3'                 ; SupportEndConsumer = '2014-04-08'; SupportEndEnterprise = '2014-04-08'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 2195 ; IsServer = $false; Product = 'Windows 2000 Professional'     ; DisplayVersion = 'SP4'                 ; SupportEndConsumer = '2010-07-13'; SupportEndEnterprise = '2010-07-13'; SupportEndLtsc = '' }

        # --- Серверні випуски ---
        [PSCustomObject]@{ Build = 26100; IsServer = $true ; Product = 'Windows Server 2025'           ; DisplayVersion = '24H2'                ; SupportEndConsumer = '2034-11-14'; SupportEndEnterprise = '2034-11-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 25398; IsServer = $true ; Product = 'Windows Server 23H2'          ; DisplayVersion = '23H2'                ; SupportEndConsumer = '2025-10-24'; SupportEndEnterprise = '2025-10-24'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 20348; IsServer = $true ; Product = 'Windows Server 2022'           ; DisplayVersion = '21H2'                ; SupportEndConsumer = '2031-10-14'; SupportEndEnterprise = '2031-10-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 19042; IsServer = $true ; Product = 'Windows Server SAC'            ; DisplayVersion = '20H2'                ; SupportEndConsumer = '2022-08-09'; SupportEndEnterprise = '2022-08-09'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 19041; IsServer = $true ; Product = 'Windows Server SAC'            ; DisplayVersion = '2004'                ; SupportEndConsumer = '2021-12-14'; SupportEndEnterprise = '2021-12-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 18363; IsServer = $true ; Product = 'Windows Server SAC'            ; DisplayVersion = '1909'                ; SupportEndConsumer = '2021-05-11'; SupportEndEnterprise = '2021-05-11'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 18362; IsServer = $true ; Product = 'Windows Server SAC'            ; DisplayVersion = '1903'                ; SupportEndConsumer = '2020-12-08'; SupportEndEnterprise = '2020-12-08'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 17763; IsServer = $true ; Product = 'Windows Server 2019'           ; DisplayVersion = '1809'                ; SupportEndConsumer = '2029-01-09'; SupportEndEnterprise = '2029-01-09'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 17134; IsServer = $true ; Product = 'Windows Server SAC'            ; DisplayVersion = '1803'                ; SupportEndConsumer = '2019-11-12'; SupportEndEnterprise = '2019-11-12'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 16299; IsServer = $true ; Product = 'Windows Server SAC'            ; DisplayVersion = '1709'                ; SupportEndConsumer = '2019-04-09'; SupportEndEnterprise = '2019-04-09'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 14393; IsServer = $true ; Product = 'Windows Server 2016'           ; DisplayVersion = '1607'                ; SupportEndConsumer = '2027-01-12'; SupportEndEnterprise = '2027-01-12'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 9600 ; IsServer = $true ; Product = 'Windows Server 2012 R2'        ; DisplayVersion = 'R2'                  ; SupportEndConsumer = '2023-10-10'; SupportEndEnterprise = '2023-10-10'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 9200 ; IsServer = $true ; Product = 'Windows Server 2012'           ; DisplayVersion = 'RTM'                 ; SupportEndConsumer = '2023-10-10'; SupportEndEnterprise = '2023-10-10'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 7601 ; IsServer = $true ; Product = 'Windows Server 2008 R2'        ; DisplayVersion = 'R2 SP1'              ; SupportEndConsumer = '2020-01-14'; SupportEndEnterprise = '2020-01-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 7600 ; IsServer = $true ; Product = 'Windows Server 2008 R2'        ; DisplayVersion = 'R2 RTM'              ; SupportEndConsumer = '2013-04-09'; SupportEndEnterprise = '2013-04-09'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 6002 ; IsServer = $true ; Product = 'Windows Server 2008'           ; DisplayVersion = 'SP2'                 ; SupportEndConsumer = '2020-01-14'; SupportEndEnterprise = '2020-01-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 6001 ; IsServer = $true ; Product = 'Windows Server 2008'           ; DisplayVersion = 'RTM'                 ; SupportEndConsumer = '2011-07-12'; SupportEndEnterprise = '2011-07-12'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 3790 ; IsServer = $true ; Product = 'Windows Server 2003 / 2003 R2' ; DisplayVersion = 'SP2'                 ; SupportEndConsumer = '2015-07-14'; SupportEndEnterprise = '2015-07-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 2195 ; IsServer = $true ; Product = 'Windows 2000 Server'           ; DisplayVersion = 'SP4'                 ; SupportEndConsumer = '2010-07-13'; SupportEndEnterprise = '2010-07-13'; SupportEndLtsc = '' }
    )
}


# ============================================================
# MODULE: src/39-Collectors-Updates.ps1
# ============================================================

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
        $skipSearch = $SkipUpdateSearch -or $Offline -or ($Profile -eq 'Quick')

        if ($skipSearch) {
            $script:Report.Updates.Search.Status = 'Skipped'
            $script:Report.Updates.Search.Error = if ($Offline) { 'Пошук вимкнено параметром -Offline.' } elseif ($SkipUpdateSearch) { 'Пошук вимкнено параметром -SkipUpdateSearch.' } else { 'Профіль Quick не виконує онлайн-пошук оновлень.' }
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


# ============================================================
# MODULE: src/39b-Collectors-Runtime.ps1
# ============================================================

# MODULE: 39b-Collectors-Runtime.ps1
# Перевірка можливості оновлення .NET Framework (4.x) та PowerShell.
# Працює повністю офлайн: "найновіша відома версія" — константи в коді,
# без звернень в інтернет. Періодично варто оновлювати ці константи.

function Get-BravoRuntimeAudit {
    [CmdletBinding()]
    param()

    # --- .NET Framework 4.x ---
    try {
        # .NET Framework 4.8.1 підтримується лише на Windows 11 22H2+ (build 22621+)
        # та Windows Server 2022 23H2/Annual Channel+ (build 25398+, теж >= 22621).
        # На старіших ОС (Windows 7 SP1–10, Server 2012–2022 LTSC) 4.8.1 не існує
        # як окремий пакет — інсталятор там блокується "не підтримується цією ОС",
        # тож максимум, який можна рекомендувати, — 4.8.
        $osBuildNumber = 0
        $osBuildParsed = [int]::TryParse([string]$script:Report.OS.Build, [ref]$osBuildNumber)
        $supports481 = $osBuildParsed -and ($osBuildNumber -ge 22621)

        if ($supports481) {
            $maxCompatibleVersion = '4.8.1'
            $maxCompatibleReleaseKey = 533320
        } else {
            $maxCompatibleVersion = '4.8'
            $maxCompatibleReleaseKey = 528040
        }
        $script:Report.DotNet.LatestKnownVersion = $maxCompatibleVersion

        if (Test-Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full') {
            $release = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue).Release

            if ($release) {
                $script:Report.DotNet.ReleaseKey = $release

                if ($release -ge 533320) { $script:Report.DotNet.v4 = '4.8.1+' }
                elseif ($release -ge 528040) { $script:Report.DotNet.v4 = '4.8' }
                elseif ($release -ge 461808) { $script:Report.DotNet.v4 = '4.7.2+' }
                else { $script:Report.DotNet.v4 = "Release $release" }

                $script:Report.DotNet.UpdateAvailable = ($release -lt $maxCompatibleReleaseKey)

                if ($script:Report.DotNet.UpdateAvailable) {
                    if ($supports481) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'DotNet' -Message ".NET Framework застарів: $($script:Report.DotNet.v4) (максимальна сумісна версія для цієї ОС: 4.8.1)" -Recommendation 'Встановіть оновлення через Windows Update (.NET Framework 4.8.1 постачається як компонент ОС) або офлайн-інсталятор із microsoft.com/net/download/dotnet-framework/net481, якщо Windows Update недоступний.'
                    } else {
                        Add-AuditFinding -Severity 'WARNING' -Category 'DotNet' -Message ".NET Framework застарів: $($script:Report.DotNet.v4) (максимальна сумісна версія для цієї ОС: 4.8; 4.8.1 на цій версії Windows НЕ підтримується)" -Recommendation 'Встановіть .NET Framework 4.8 (максимум, підтримуваний цією ОС) через Windows Update або офлайн-інсталятор. Не намагайтесь ставити 4.8.1 — інсталятор заблокує встановлення як несумісне з цією ОС.'
                    }
                }
            }
        }

        Write-Host "  $IconOk .NET Framework: $($script:Report.DotNet.v4)" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Runtime.DotNet' -Message $_.Exception.Message
    }

    # --- Windows PowerShell (Desktop edition) ---
    try {
        $psVersion = $PSVersionTable.PSVersion
        $currentPSEdition = $PSVersionTable.PSEdition

        if ($currentPSEdition -eq 'Desktop' -and $psVersion.Major -lt 5) {
            Add-AuditFinding -Severity 'WARNING' -Category 'PowerShell' -Message "Застаріла версія Windows PowerShell: $psVersion" -Recommendation 'Оновіть до Windows PowerShell 5.1 (Windows Management Framework 5.1) — це остання версія Desktop-редакції.'
        }
    } catch {
        Add-AuditError -Section 'Runtime.PowerShell' -Message $_.Exception.Message
    }

    # --- PowerShell 7 (Core), встановлений поруч ---
    try {
        $latestKnownCore7 = '7.6' # оновлено 2026-08, звірити при наступному ревю
        $script:Report.PowerShell.Core7LatestKnown = $latestKnownCore7

        $core7InstallsPath = 'HKLM:\SOFTWARE\Microsoft\PowerShellCore\InstalledVersions'
        if (Test-Path $core7InstallsPath) {
            $core7Install = Get-ChildItem -LiteralPath $core7InstallsPath -ErrorAction SilentlyContinue |
                ForEach-Object { Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue } |
                Where-Object { $_.SemanticVersion } |
                Sort-Object { [version]($_.SemanticVersion -replace '-.*$','') } -Descending |
                Select-Object -First 1

            if ($core7Install) {
                $script:Report.PowerShell.Core7Installed = $true
                $script:Report.PowerShell.Core7Version = $core7Install.SemanticVersion

                $core7VersionParsed = [version]($core7Install.SemanticVersion -replace '-.*$','')
                $latestKnownParsed = [version]$latestKnownCore7

                if (($core7VersionParsed.Major -lt $latestKnownParsed.Major) -or
                    ($core7VersionParsed.Major -eq $latestKnownParsed.Major -and $core7VersionParsed.Minor -lt $latestKnownParsed.Minor)) {
                    $script:Report.PowerShell.Core7UpdateAvailable = $true
                    Add-AuditFinding -Severity 'WARNING' -Category 'PowerShell' -Message "PowerShell 7 застарів: $($script:Report.PowerShell.Core7Version) (найновіша відома версія: $latestKnownCore7)" -Recommendation 'Оновіть PowerShell 7 через winget (winget upgrade Microsoft.PowerShell) або MSI з github.com/PowerShell/PowerShell.'
                }
            }
        }

        if (-not $script:Report.PowerShell.Core7Installed -and $PSVersionTable.PSEdition -eq 'Desktop' -and $PSVersionTable.PSVersion.Major -ge 5) {
            Add-AuditFinding -Severity 'INFO' -Category 'PowerShell' -Message 'PowerShell 7 (Core) не встановлено' -Recommendation 'За потреби встановіть сучасний PowerShell 7 для розширеної функціональності та кросплатформної сумісності.'
        }

        Write-Host "  $IconOk PowerShell 7 (Core): $(if($script:Report.PowerShell.Core7Installed){$script:Report.PowerShell.Core7Version}else{'не встановлено'})" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Runtime.PowerShellCore' -Message $_.Exception.Message
    }
}


# ============================================================
# MODULE: src/40-Health.ps1
# ============================================================

# MODULE: 40-Health.ps1
# Розрахунок підсумкової оцінки стану машини.

function Update-BravoHealthScore {
    [CmdletBinding()]
    param()

    # --- Health score ---
    try {
        $criticalCount = @($script:Report.Health.Findings | Where-Object { $_.Severity -eq 'CRITICAL' }).Count
        $warningCount = @($script:Report.Health.Findings | Where-Object { $_.Severity -eq 'WARNING' }).Count
        $errorCount = @($script:Report.CollectionErrors).Count

        $score = 100 - ($criticalCount * 20) - ($warningCount * 7) - [Math]::Min($errorCount * 2, 20)
        if ($score -lt 0) { $score = 0 }

        $status = if ($criticalCount -gt 0) { 'CRITICAL' } elseif ($warningCount -gt 0 -or $errorCount -gt 0) { 'WARNING' } else { 'OK' }
        $statusReason = "critical=$criticalCount; warning=$warningCount; collectionErrors=$errorCount"

        $script:Report.Health.Score = $score
        $script:Report.Health.Status = $status
        $script:Report.Status = $status
        $script:Report.StatusReason = $statusReason

        if ($script:Report.Dashboard) {
            $script:Report.Dashboard.Header.Status = $status
            $script:Report.Dashboard.Header.StatusReason = $statusReason
            $script:Report.Dashboard.Header.GeneratedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

            if ($script:Report.Hardware -and $script:Report.Hardware.Disks) {
                # Статус dashboard-плитки рахуємо по НАЙГІРШОМУ тому (тим самим
                # централізованим порогом Get-BravoStorageThresholds, що й
                # per-volume findings у 32-Collectors-Storage.ps1 — P1), а не по
                # агрегованому FreePercent по всіх дисках разом. Інакше один
                # майже заповнений диск ховається за великим вільним місцем на
                # інших, і dashboard показує "OK" одночасно з CRITICAL-знахідкою
                # для того самого тому.
                $storageThresholds = Get-BravoStorageThresholds
                $volumeFreePercents = @($script:Report.Hardware.Disks.Volumes | Where-Object { $null -ne $_.FreePercent } | ForEach-Object { $_.FreePercent })
                $worstFreePercent = if ($volumeFreePercents.Count -gt 0) { ($volumeFreePercents | Measure-Object -Minimum).Minimum } else { $script:Report.Hardware.Disks.FreePercent }

                $diskStatus = if ($worstFreePercent -lt $storageThresholds.CriticalFreePercent) { 'CRITICAL' } elseif ($worstFreePercent -lt $storageThresholds.WarningFreePercent) { 'WARNING' } else { 'OK' }
                $script:Report.Dashboard.Metrics.Disk.Value = "$($script:Report.Hardware.Disks.FreePercent)% free"
                $script:Report.Dashboard.Metrics.Disk.Details = "$($script:Report.Hardware.Disks.FreeGB) GB free з $($script:Report.Hardware.Disks.TotalGB) GB"
                $script:Report.Dashboard.Metrics.Disk.Status = $diskStatus
            }
        }
    } catch {
        Add-AuditError -Section 'HealthScore' -Message $_.Exception.Message
    }

    Write-Host ''
    Write-Host "$IconDone Збір даних завершено! Оцінка стану: $($script:Report.Health.Score)/100 ($($script:Report.Health.Status))" -ForegroundColor Green
}

# ============================================================
# MODULE: src/45-Sanitize.ps1
# ============================================================

# MODULE: 45-Sanitize.ps1
# P1/v0.4.3 Safe Sharing: маскування чутливих даних у звіті перед export-етапами.
# Виконується ОДИН раз, одразу після Update-BravoHealthScore і ДО будь-якого
# export'а (JSON/HTML/CSV/ZIP) — усі формати читають той самий $script:Report,
# тож єдина точка санітизації покриває їх усі.
#
# -SanitizeLevel Basic  (дефолт при -Sanitize без явного рівня): маскує
#   computer name, user name, domain/workgroup, DNS suffix, public IPv4,
#   MAC-адреси, серійні номери, локальних адміністраторів, install path ПЗ.
# -SanitizeLevel Strict: усе з Basic + приватні IPv4/gateway/DNS-сервери.
#
# Свідомо НЕ реалізовано (немає відповідних полів моделі, які можна було б
# замаскувати): service account names — колектори служб не збирають LogOnAs;
# якщо колись з'явиться, сюди додається окрема категорія.

# Створює маскер-функцію для однієї категорії значень: однакове вхідне
# значення завжди повертає той самий токен (консистентність у межах одного
# звіту — не ламає читабельність "той самий MAC у трьох місцях"), різні
# значення отримують токени з наростаючим номером.
function New-BravoSanitizeMasker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prefix
    )

    $state = [ordered]@{ Map = @{}; Counter = 0; Prefix = $Prefix }

    return {
        param([AllowNull()][object]$Value)

        $text = [string]$Value
        if ([string]::IsNullOrWhiteSpace($text)) { return $Value }

        if (-not $state.Map.ContainsKey($text)) {
            $state.Counter++
            $state.Map[$text] = "REDACTED-$($state.Prefix)-$($state.Counter)"
        }

        return $state.Map[$text]
    }.GetNewClosure()
}

function Invoke-BravoReportSanitization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Report,

        [ValidateSet('Basic', 'Strict')]
        [string]$Level = 'Basic'
    )

    $maskComputer = New-BravoSanitizeMasker -Prefix 'COMPUTERNAME'
    $maskUser     = New-BravoSanitizeMasker -Prefix 'USER'
    $maskDomain   = New-BravoSanitizeMasker -Prefix 'DOMAIN'
    $maskDnsSuffix = New-BravoSanitizeMasker -Prefix 'DNSSUFFIX'
    $maskPublicIP = New-BravoSanitizeMasker -Prefix 'PUBLIC-IP'
    $maskMac      = New-BravoSanitizeMasker -Prefix 'MAC'
    $maskSerial   = New-BravoSanitizeMasker -Prefix 'SERIAL'
    $maskAdmin    = New-BravoSanitizeMasker -Prefix 'ADMIN'
    $maskPath     = New-BravoSanitizeMasker -Prefix 'PATH'
    $maskPrivateIP = New-BravoSanitizeMasker -Prefix 'PRIVATE-IP'

    # --- Computer name ---
    if ($Report.ComputerName) { $Report.ComputerName = & $maskComputer $Report.ComputerName }
    if ($Report.Dashboard -and $Report.Dashboard.Header -and $Report.Dashboard.Header.ComputerName) {
        $Report.Dashboard.Header.ComputerName = & $maskComputer $Report.Dashboard.Header.ComputerName
    }
    if ($Report.Network -and $Report.Network.General -and $Report.Network.General.Hostname) {
        $Report.Network.General.Hostname = & $maskComputer $Report.Network.General.Hostname
    }

    # --- User name ---
    if ($Report.Meta -and $Report.Meta.UserName) { $Report.Meta.UserName = & $maskUser $Report.Meta.UserName }

    # --- Domain/workgroup ---
    if ($Report.Meta -and $Report.Meta.UserDomainName) { $Report.Meta.UserDomainName = & $maskDomain $Report.Meta.UserDomainName }
    if ($Report.Hardware -and $Report.Hardware.ComputerSystem -and $Report.Hardware.ComputerSystem.Domain) {
        $Report.Hardware.ComputerSystem.Domain = & $maskDomain $Report.Hardware.ComputerSystem.Domain
    }
    if ($Report.Network -and $Report.Network.General -and $Report.Network.General.Domain) {
        $Report.Network.General.Domain = & $maskDomain $Report.Network.General.Domain
    }

    # --- DNS suffix ---
    if ($Report.Network -and $Report.Network.Routing -and $Report.Network.Routing.DNSSuffixSearchOrder) {
        $Report.Network.Routing.DNSSuffixSearchOrder = @($Report.Network.Routing.DNSSuffixSearchOrder | ForEach-Object { & $maskDnsSuffix $_ })
    }

    # --- Public IPv4 (і geo/ISP-дані, що з нею пов'язані) ---
    if ($Report.Network -and $Report.Network.IP) {
        if ($Report.Network.IP.PublicIPv4) { $Report.Network.IP.PublicIPv4 = & $maskPublicIP $Report.Network.IP.PublicIPv4 }
    }

    # --- MAC-адреси ---
    if ($Report.Network -and $Report.Network.Adapters) {
        foreach ($adapter in @($Report.Network.Adapters)) {
            if ($adapter.MACAddress) { $adapter.MACAddress = & $maskMac $adapter.MACAddress }
        }
    }

    # ARP-кеш (Network.ARP, v0.5.0) — та сама категорія MAC, що й Adapters
    # вище: маскується завжди (Basic), незалежно від рівня. IP-адреси в ARP —
    # приватні (сусіди в тій самій підмережі за визначенням) — маскуються
    # нижче разом з рештою приватних IPv4, лише в Strict.
    if ($Report.Network -and $Report.Network.ARP) {
        foreach ($arpEntry in @($Report.Network.ARP)) {
            if ($arpEntry.LinkLayerAddress) { $arpEntry.LinkLayerAddress = & $maskMac $arpEntry.LinkLayerAddress }
        }
    }

    # --- Серійні номери ---
    if ($Report.BIOS -and $Report.BIOS.SerialNumber) { $Report.BIOS.SerialNumber = & $maskSerial $Report.BIOS.SerialNumber }

    if ($Report.Hardware -and $Report.Hardware.RAM -and $Report.Hardware.RAM.Modules) {
        foreach ($module in @($Report.Hardware.RAM.Modules)) {
            if ($module.SerialNumber) { $module.SerialNumber = & $maskSerial $module.SerialNumber }
        }
    }

    if ($Report.Hardware -and $Report.Hardware.Disks) {
        $disksContainer = $Report.Hardware.Disks
        $physicalDisks = if ($disksContainer -is [System.Collections.IDictionary]) { $disksContainer['PhysicalDisks'] } else { $disksContainer.PhysicalDisks }
        foreach ($disk in @($physicalDisks)) {
            if ($disk.SerialNumber) { $disk.SerialNumber = & $maskSerial $disk.SerialNumber }
        }

        # Storage Deep Audit (Get-BravoStorageDeepAudit, Deep/Forensic профілі) —
        # окремий Disks-масив з власними серійними номерами (Get-Disk), не
        # плутати з Hardware.Disks.PhysicalDisks (Win32_DiskDrive) вище.
        $storageDeep = if ($disksContainer -is [System.Collections.IDictionary]) { $disksContainer['Deep'] } else { $disksContainer.Deep }
        if ($storageDeep -and $storageDeep.Disks) {
            foreach ($deepDisk in @($storageDeep.Disks)) {
                if ($deepDisk.SerialNumber) { $deepDisk.SerialNumber = & $maskSerial $deepDisk.SerialNumber }
            }
        }
    }

    # Монітори (Hardware.Monitors, v0.5.0-tail) — та сама категорія SERIAL,
    # що й BIOS/RAM/Disks: EDID SerialNumberID теж унікальний ідентифікатор
    # фізичного пристрою.
    if ($Report.Hardware -and $Report.Hardware.Monitors) {
        foreach ($monitor in @($Report.Hardware.Monitors)) {
            if ($monitor.SerialNumber) { $monitor.SerialNumber = & $maskSerial $monitor.SerialNumber }
        }
    }

    # --- Локальні адміністратори ---
    if ($Report.Users -and $Report.Users.LocalAdmins) {
        $Report.Users.LocalAdmins = @($Report.Users.LocalAdmins | ForEach-Object { & $maskAdmin $_ })
    }

    # --- Дозволені RDP-користувачі (та сама категорія імен облікових записів,
    # що й LocalAdmins — той самий маскер, узгоджені токени в межах звіту) ---
    if ($Report.Security -and $Report.Security.RemoteAccess -and $Report.Security.RemoteAccess.AllowedUsers) {
        $Report.Security.RemoteAccess.AllowedUsers = @($Report.Security.RemoteAccess.AllowedUsers | ForEach-Object { & $maskAdmin $_ })
    }

    # --- Чутливі шляхи встановлення ПЗ ---
    if ($Report.Software -and $Report.Software.Installed) {
        foreach ($item in @($Report.Software.Installed)) {
            if ($item -isnot [string] -and $item.InstallLocation) {
                $item.InstallLocation = & $maskPath $item.InstallLocation
            }
        }
    }

    # --- Autoruns (Security.Autoruns, v0.5.0-tail) — Command часто містить
    # повний шлях виконуваного файлу з профілю користувача (C:\Users\jdoe\...)
    # — та сама категорія PATH, що й InstallLocation, маскується завжди (Basic).
    if ($Report.Security -and $Report.Security.Autoruns) {
        foreach ($autorun in @($Report.Security.Autoruns)) {
            if ($autorun.Command) { $autorun.Command = & $maskPath $autorun.Command }
        }
    }

    # --- Scheduled tasks (Security.ScheduledTasks, v0.5.0-tail) — Author
    # часто у форматі DOMAIN\username або COMPUTERNAME\username (реальний
    # обліковий запис, що створив задачу) — та сама категорія ADMIN, що й
    # LocalAdmins/AllowedUsers. Execute/Arguments можуть містити шлях з
    # профілю користувача — категорія PATH, як і Autoruns.Command вище.
    if ($Report.Security -and $Report.Security.ScheduledTasks) {
        foreach ($task in @($Report.Security.ScheduledTasks)) {
            if ($task.Author) { $task.Author = & $maskAdmin $task.Author }
            if ($task.Execute) { $task.Execute = & $maskPath $task.Execute }
            if ($task.Arguments) { $task.Arguments = & $maskPath $task.Arguments }
        }
    }

    # --- Приватні IPv4/gateway/DNS-сервери — лише Strict ---
    if ($Level -eq 'Strict' -and $Report.Network) {
        if ($Report.Network.IP) {
            if ($Report.Network.IP.IPv4) {
                $Report.Network.IP.IPv4 = @($Report.Network.IP.IPv4 | ForEach-Object { & $maskPrivateIP $_ })
            }
            if ($Report.Network.IP.PrimaryIPv4) { $Report.Network.IP.PrimaryIPv4 = & $maskPrivateIP $Report.Network.IP.PrimaryIPv4 }
            if ($Report.Network.IP.PrimaryInterface) {
                if ($Report.Network.IP.PrimaryInterface.IPv4) { $Report.Network.IP.PrimaryInterface.IPv4 = & $maskPrivateIP $Report.Network.IP.PrimaryInterface.IPv4 }
                if ($Report.Network.IP.PrimaryInterface.Gateway) { $Report.Network.IP.PrimaryInterface.Gateway = & $maskPrivateIP $Report.Network.IP.PrimaryInterface.Gateway }
            }
        }

        if ($Report.Network.Routing) {
            if ($Report.Network.Routing.DefaultGateway) { $Report.Network.Routing.DefaultGateway = & $maskPrivateIP $Report.Network.Routing.DefaultGateway }
            if ($Report.Network.Routing.DefaultGateways) {
                $Report.Network.Routing.DefaultGateways = @($Report.Network.Routing.DefaultGateways | ForEach-Object { & $maskPrivateIP $_ })
            }
            if ($Report.Network.Routing.DNSServers) {
                $Report.Network.Routing.DNSServers = @($Report.Network.Routing.DNSServers | ForEach-Object { & $maskPrivateIP $_ })
            }
        }

        if ($Report.Network.Adapters) {
            foreach ($adapter in @($Report.Network.Adapters)) {
                if ($adapter.IPv4) { $adapter.IPv4 = @($adapter.IPv4 | ForEach-Object { & $maskPrivateIP $_ }) }
                if ($adapter.Gateway) { $adapter.Gateway = @($adapter.Gateway | ForEach-Object { & $maskPrivateIP $_ }) }
                if ($adapter.DNS) { $adapter.DNS = @($adapter.DNS | ForEach-Object { & $maskPrivateIP $_ }) }
            }
        }

        if ($Report.Network.ARP) {
            foreach ($arpEntry in @($Report.Network.ARP)) {
                if ($arpEntry.IPAddress) { $arpEntry.IPAddress = & $maskPrivateIP $arpEntry.IPAddress }
            }
        }

        if ($Report.Network.Routing -and $Report.Network.Routing.RoutingTable) {
            foreach ($routeEntry in @($Report.Network.Routing.RoutingTable)) {
                if ($routeEntry.DestinationPrefix) { $routeEntry.DestinationPrefix = & $maskPrivateIP $routeEntry.DestinationPrefix }
                if ($routeEntry.NextHop) { $routeEntry.NextHop = & $maskPrivateIP $routeEntry.NextHop }
            }
        }

        if ($Report.Network.Connections -and $Report.Network.Connections.ListeningPorts) {
            foreach ($port in @($Report.Network.Connections.ListeningPorts)) {
                if ($port.LocalAddress) { $port.LocalAddress = & $maskPrivateIP $port.LocalAddress }
            }
        }

        if ($Report.Network.Connections -and $Report.Network.Connections.EstablishedConnections) {
            foreach ($conn in @($Report.Network.Connections.EstablishedConnections)) {
                if ($conn.LocalAddress) { $conn.LocalAddress = & $maskPrivateIP $conn.LocalAddress }
                if ($conn.RemoteAddress) { $conn.RemoteAddress = & $maskPrivateIP $conn.RemoteAddress }
            }
        }
    }

    # --- SMB shares: шлях може містити username (напр. C:\Users\jdoe\Share) —
    # та сама категорія PATH, що й Software.Installed[].InstallLocation,
    # маскується завжди (Basic), незалежно від рівня.
    if ($Report.Network -and $Report.Network.SmbShares) {
        foreach ($share in @($Report.Network.SmbShares)) {
            if ($share.Path) { $share.Path = & $maskPath $share.Path }
        }
    }

    return $Report
}


# ============================================================
# MODULE: src/50-Export-Json.ps1
# ============================================================

# MODULE: 50-Export-Json.ps1
# Експорт BRAVO SYSTEM REPORT у JSON.

function Export-BravoJsonReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputDir,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseFileName
    )

    # JSON
    try {
        $jsonPath = Join-Path $OutputDir "$BaseFileName.json"
        $jsonContent = ConvertTo-Json $script:Report -Depth 12
        # Out-File -Encoding utf8 у Windows PowerShell 5.1 завжди додає BOM,
        # що ламає суворі JSON-парсери (RFC 8259 не допускає BOM) у зовнішніх
        # CI/monitoring-пайплайнах, які читають цей файл. Пишемо через
        # .NET напряму з UTF8Encoding($false) — без BOM.
        #
        # Ретрай на IOException: якщо цей файл уже існує (90-Main.ps1 повторно
        # викликає цю функцію наприкінці, щоб зафіксувати фінальні ExportErrors),
        # він міг лишитись коротко заблокованим попереднім кроком — наприклад,
        # Send-MailMessage асинхронно звільняє handle вкладення не миттєво
        # (garbage collector/finalizer), і негайний повторний запис ловить
        # sharing violation. Підтверджено реальним прогоном. 3 спроби з
        # короткою паузою покривають цей транзієнтний випадок.
        # Примітка: виключення від .NET static method call (WriteAllText)
        # PowerShell 5.1 обгортає в MethodInvocationException — типізований
        # `catch [System.IO.IOException]` НЕ спрацьовує (тип не збігається,
        # перевірено емпірично), тому тут навмисно catch-all із перевіркою
        # реальної причини через InnerException.
        #
        # Важливо: сам по собі Start-Sleep НЕ допомагає — підтверджено
        # емпірично, lock тримається 5+ секунд і довше без дій. Причина:
        # Send-MailMessage (SmtpClient/MailMessage/Attachment) звільняє
        # file handle вкладення лише через finalizer, а не одразу при
        # виключенні — GC не запускається сам по собі негайно. Явний
        # [GC]::Collect() + WaitForPendingFinalizers() форсує звільнення
        # миттєво (перевірено емпірично — без цього retry марний).
        $maxAttempts = 3
        for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
            try {
                [System.IO.File]::WriteAllText($jsonPath, $jsonContent, (New-Object System.Text.UTF8Encoding($false)))
                break
            } catch {
                $isShareViolation = ($_.Exception.InnerException -is [System.IO.IOException]) -or ($_.Exception -is [System.IO.IOException])
                if (-not $isShareViolation -or $attempt -ge $maxAttempts) { throw }
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
            }
        }
        $script:Report.GeneratedFiles += $jsonPath
        Write-Host "  $IconJson JSON: $BaseFileName.json" -ForegroundColor Green
    } catch {
        Add-ExportError -Section 'Export.Json' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка JSON: $($_.Exception.Message)" -ForegroundColor Red
    }
}


# ============================================================
# MODULE: src/51-Export-Html.ps1
# ============================================================

# MODULE: 51-Export-Html.ps1
# Експорт BRAVO SYSTEM REPORT у HTML.

function Export-BravoHtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputDir,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseFileName,

        [Parameter(Mandatory = $true)]
        [bool]$JSONOnly,

        [Parameter(Mandatory = $true)]
        [int]$EventLogDays,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Profile,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptVersion
    )

    if (-not $JSONOnly) {
        try {
            $htmlPath = Join-Path $OutputDir "$BaseFileName.html"

            function ConvertTo-BravoHtmlText {
                param([AllowNull()][object]$Value)
                if ($null -eq $Value) { return '' }
                return [System.Net.WebUtility]::HtmlEncode([string]$Value)
            }

            function Get-BravoSafePercentText {
                # Для progress-bar значень (style="width:...%"), які вставляються
                # без ConvertTo-BravoHtmlText напряму в HTML-атрибут і текст.
                # Гарантує, що на виході завжди чисте число 0-100 — навіть якщо
                # джерело (WMI/CIM) колись поверне не число, воно не потрапить
                # у розмітку як є.
                param([AllowNull()][object]$Value)
                $parsed = 0.0
                # [string]-каст PowerShell форматує double через InvariantCulture
                # (крапка), тож TryParse ТЕЖ має звірятись з InvariantCulture —
                # інакше на локалізованих ОС (де CurrentCulture очікує кому,
                # напр. uk-UA) парсинг мовчки провалюється і все стає "0%".
                if ($null -ne $Value -and [double]::TryParse([string]$Value, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
                    if ($parsed -lt 0) { $parsed = 0 }
                    if ($parsed -gt 100) { $parsed = 100 }
                    return $parsed.ToString([System.Globalization.CultureInfo]::InvariantCulture)
                }
                return '0'
            }

            function ConvertTo-BravoHtmlListText {
                param(
                    [AllowNull()][object]$Value,
                    [string]$Separator = ', '
                )
                if ($null -eq $Value) { return '' }
                return ConvertTo-BravoHtmlText ((@($Value) | Where-Object { $_ }) -join $Separator)
            }

            function Get-BravoStatusClass {
                param([AllowNull()][object]$Status)
                switch (([string]$Status).ToUpperInvariant()) {
                    'CRITICAL' { return 'status-critical' }
                    'WARNING'  { return 'status-warning' }
                    'OK'       { return 'status-ok' }
                    default    { return 'status-unknown' }
                }
            }

            function Get-BravoStorageRiskClass {
                param([AllowNull()][object]$Risk)
                switch (([string]$Risk).ToUpperInvariant()) {
                    'CRITICAL' { return 'risk-critical' }
                    'WARNING'  { return 'risk-warning' }
                    'OK'       { return 'risk-ok' }
                    default    { return 'risk-unknown' }
                }
            }

            function Get-BravoStorageDisplayText {
                param([AllowNull()][object]$Volume)
                if ($null -eq $Volume) { return '' }
                if ($Volume.DriveLetter) { return ("{0}:" -f ([string]$Volume.DriveLetter).TrimEnd(':')) }
                if ($Volume.Drive) { return [string]$Volume.Drive }
                if ($Volume.DeviceID) { return [string]$Volume.DeviceID }
                if ($Volume.VolumeKey) { return [string]$Volume.VolumeKey }
                return 'Volume без літери'
            }

            function Get-BravoStoragePropertyText {
                param([AllowNull()][object]$Value)
                if ($null -eq $Value -or [string]$Value -eq '') { return '—' }
                return [string]$Value
            }

            function New-BravoInfoRowHtml {
                param(
                    [string]$Label,
                    [AllowNull()][object]$Value
                )
                return "<div class=`"info-row`"><span class=`"info-label`">$(ConvertTo-BravoHtmlText $Label)</span><span class=`"info-value`">$(ConvertTo-BravoHtmlText $Value)</span></div>"
            }

            function New-BravoTableToolbarHtml {
                param(
                    [Parameter(Mandatory = $true)]
                    [ValidateNotNullOrEmpty()]
                    [string]$TableId,

                    [Parameter(Mandatory = $true)]
                    [ValidateNotNullOrEmpty()]
                    [string]$Placeholder
                )

                $safeTableId = ConvertTo-BravoHtmlText $TableId
                $safePlaceholder = ConvertTo-BravoHtmlText $Placeholder

                return @"
<div class="table-toolbar" data-table-toolbar="$safeTableId">
  <input class="table-search" type="search" placeholder="$safePlaceholder" data-table-filter="$safeTableId" autocomplete="off">
  <span class="table-counter" data-table-counter="$safeTableId">Рядків: —</span>
</div>
"@
            }

            function New-BravoMetricCardHtml {
                param(
                    [string]$Icon,
                    [string]$Title,
                    [AllowNull()][object]$Value,
                    [AllowNull()][object]$Details,
                    [AllowNull()][object]$Status
                )

                $statusText = if ($Status) { [string]$Status } else { 'OK' }
                $statusClass = Get-BravoStatusClass $statusText

                return @"
<div class="metric-card $statusClass">
  <div class="metric-topline">
    <div class="metric-icon">$Icon</div>
    <span class="status-pill $statusClass">$(ConvertTo-BravoHtmlText $statusText)</span>
  </div>
  <div class="metric-title">$(ConvertTo-BravoHtmlText $Title)</div>
  <div class="metric-value">$(ConvertTo-BravoHtmlText $Value)</div>
  <div class="metric-details">$(ConvertTo-BravoHtmlText $Details)</div>
</div>
"@
            }

            $dashboardMetrics = $script:Report.Dashboard.Metrics
            $cpuMetric = $dashboardMetrics.CPU
            $ramMetric = $dashboardMetrics.RAM
            $diskMetric = $dashboardMetrics.Disk
            $osMetric = $dashboardMetrics.OS
            $updatesMetric = $dashboardMetrics.Updates

            $metricCardsHtml = @(
                New-BravoMetricCardHtml -Icon '🧠' -Title $cpuMetric.Title -Value $cpuMetric.Value -Details $cpuMetric.Details -Status $cpuMetric.Status
                New-BravoMetricCardHtml -Icon '💾' -Title $ramMetric.Title -Value $ramMetric.Value -Details $ramMetric.Details -Status $ramMetric.Status
                New-BravoMetricCardHtml -Icon '💿' -Title $diskMetric.Title -Value $diskMetric.Value -Details $diskMetric.Details -Status $diskMetric.Status
                New-BravoMetricCardHtml -Icon '🖥️' -Title $osMetric.Title -Value $osMetric.Value -Details $osMetric.Details -Status $osMetric.Status
                New-BravoMetricCardHtml -Icon '🔄' -Title $updatesMetric.Title -Value $updatesMetric.Value -Details $updatesMetric.Details -Status $updatesMetric.Status
            ) -join "`n"

            $findingsRows = if ($script:Report.Health.Findings.Count -gt 0) {
                ($script:Report.Health.Findings | ForEach-Object {
                    $severityClass = Get-BravoStatusClass $_.Severity
                    "<tr><td><span class=`"status-pill $severityClass`">$(ConvertTo-BravoHtmlText $_.Severity)</span></td><td>$(ConvertTo-BravoHtmlText $_.Category)</td><td>$(ConvertTo-BravoHtmlText $_.Message)</td><td>$(ConvertTo-BravoHtmlText $_.Recommendation)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Критичних зауважень не знайдено.</td></tr>'
            }

            $errorsRows = if ($script:Report.CollectionErrors.Count -gt 0) {
                ($script:Report.CollectionErrors | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Time)</td><td>$(ConvertTo-BravoHtmlText $_.Section)</td><td>$(ConvertTo-BravoHtmlText $_.Message)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="3" class="muted">Помилок збору даних не зафіксовано.</td></tr>'
            }

            $softwareRows = if ($script:Report.Software.Installed.Count -gt 0) {
                ($script:Report.Software.Installed | ForEach-Object {
                    if ($_ -is [string]) {
                        "<tr><td>$(ConvertTo-BravoHtmlText $_)</td><td>—</td><td>—</td><td>—</td></tr>"
                    } else {
                        "<tr><td>$(ConvertTo-BravoHtmlText $_.DisplayName)</td><td>$(ConvertTo-BravoHtmlText $_.DisplayVersion)</td><td>$(ConvertTo-BravoHtmlText $_.Publisher)</td><td>$(ConvertTo-BravoHtmlText $_.InstallDate)</td></tr>"
                    }
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Дані про встановлене ПЗ відсутні.</td></tr>'
            }

            $updatesSupportStatus = [string]$script:Report.Updates.OS.SupportStatus
            $updatesSupportStatusClass = switch ($updatesSupportStatus) {
                'EndOfSupport' { 'status-critical' }
                'EndingSoon'   { 'status-warning' }
                'Supported'    { 'status-ok' }
                default        { 'status-unknown' }
            }

            $updatesSupportStatusText = switch ($updatesSupportStatus) {
                'EndOfSupport' { 'Поза підтримкою' }
                'EndingSoon'   { 'Підтримка завершується' }
                'Supported'    { 'Підтримується' }
                default        { 'Невідомо' }
            }

            $updatesSearchStatus = [string]$script:Report.Updates.Search.Status
            $updatesSearchStatusText = switch ($updatesSearchStatus) {
                'OK'         { 'Виконано' }
                'Skipped'    { 'Пропущено' }
                'Timeout'    { 'Таймаут' }
                'Failed'     { 'Помилка' }
                'NotChecked' { 'Не перевірялось' }
                default      { $updatesSearchStatus }
            }
            if ($script:Report.Updates.Search.Error) {
                $updatesSearchStatusText = "$updatesSearchStatusText — $($script:Report.Updates.Search.Error)"
            }

            $pendingRebootText = if ($script:Report.Updates.PendingReboot.Required) {
                "Так: $((@($script:Report.Updates.PendingReboot.Reasons) | Where-Object { $_ }) -join '; ')"
            } else {
                'Ні'
            }

            $pendingUpdatesRows = if (@($script:Report.Updates.Pending.Items).Count -gt 0) {
                (@($script:Report.Updates.Pending.Items) | ForEach-Object {
                    $updateSeverityClass = if ($_.MsrcSeverity -eq 'Critical') { 'status-critical' } elseif ($_.MsrcSeverity) { 'status-warning' } else { 'status-unknown' }
                    $updateSeverityText = if ($_.MsrcSeverity) { [string]$_.MsrcSeverity } else { '—' }
                    $downloadedText = if ($_.IsDownloaded) { 'Так' } else { 'Ні' }
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Title)</td><td>$(ConvertTo-BravoHtmlText $_.KB)</td><td>$(ConvertTo-BravoHtmlText $_.Categories)</td><td><span class=`"status-pill $updateSeverityClass`">$(ConvertTo-BravoHtmlText $updateSeverityText)</span></td><td>$(ConvertTo-BravoHtmlText $_.SizeMB)</td><td>$downloadedText</td><td>$(ConvertTo-BravoHtmlText $_.ReleasedOn)</td></tr>"
                }) -join "`n"
            } elseif ($updatesSearchStatus -eq 'OK') {
                '<tr><td colspan="7" class="muted">Невстановлених оновлень не знайдено.</td></tr>'
            } else {
                '<tr><td colspan="7" class="muted">Пошук доступних оновлень не виконувався або завершився невдало.</td></tr>'
            }

            $installedUpdatesRows = if (@($script:Report.Updates.Installed.Recent).Count -gt 0) {
                (@($script:Report.Updates.Installed.Recent) | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.HotFixID)</td><td>$(ConvertTo-BravoHtmlText $_.Description)</td><td>$(ConvertTo-BravoHtmlText $_.InstalledBy)</td><td>$(ConvertTo-BravoHtmlText $_.InstalledOnText)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Дані про встановлені оновлення відсутні.</td></tr>'
            }

            $serviceRows = if ($script:Report.Services.AutomaticStopped.Count -gt 0) {
                ($script:Report.Services.AutomaticStopped | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Name)</td><td>$(ConvertTo-BravoHtmlText $_.DisplayName)</td><td>$(ConvertTo-BravoHtmlText $_.StartMode)</td><td>$(ConvertTo-BravoHtmlText $_.State)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Автоматичних служб у зупиненому стані не знайдено.</td></tr>'
            }

            $eventTopErrorRows = if ($script:Report.EventLogs.TopErrorSources.Count -gt 0) {
                ($script:Report.EventLogs.TopErrorSources | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Source)</td><td>$(ConvertTo-BravoHtmlText $_.Count)</td><td>$(ConvertTo-BravoHtmlText $_.LastMessage)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="3" class="muted">Помилок System log за вибраний період не знайдено.</td></tr>'
            }

            $eventLogSummaryRows = if (@($script:Report.EventLogs.LogSummaries).Count -gt 0) {
                (@($script:Report.EventLogs.LogSummaries) | ForEach-Object {
                    $logSummary = $_
                    $criticalText = if ($null -eq $logSummary.CriticalCount) { '—' } else { $logSummary.CriticalCount }
                    $criticalClass = if ($null -ne $logSummary.CriticalCount -and [int]$logSummary.CriticalCount -gt 0) { 'risk-critical' } else { 'risk-ok' }
                    $errorClass = if ($null -ne $logSummary.ErrorCount -and [int]$logSummary.ErrorCount -gt 0) { 'risk-warning' } else { 'risk-ok' }
                    "<tr><td>$(ConvertTo-BravoHtmlText $logSummary.LogName)</td><td>$(ConvertTo-BravoHtmlText $logSummary.Status)</td><td><span class=`"risk $criticalClass`">$(ConvertTo-BravoHtmlText $criticalText)</span></td><td><span class=`"risk $errorClass`">$(ConvertTo-BravoHtmlText $logSummary.ErrorCount)</span></td><td>$(ConvertTo-BravoHtmlText $logSummary.WarningCount)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="5" class="muted">Per-log summary недоступний для поточного профілю (Full/Deep/Forensic).</td></tr>'
            }

            $eventLogProviderRows = if (@($script:Report.EventLogs.LogSummaries).Count -gt 0) {
                $allProviders = @($script:Report.EventLogs.LogSummaries | ForEach-Object { $logName = $_.LogName; @($_.TopProviders) | ForEach-Object { [PSCustomObject]@{ LogName = $logName; ProviderName = $_.ProviderName; Count = $_.Count; LastMessage = $_.LastMessage } } })
                if ($allProviders.Count -gt 0) {
                    ($allProviders | ForEach-Object {
                        "<tr><td>$(ConvertTo-BravoHtmlText $_.LogName)</td><td>$(ConvertTo-BravoHtmlText $_.ProviderName)</td><td>$(ConvertTo-BravoHtmlText $_.Count)</td><td>$(ConvertTo-BravoHtmlText $_.LastMessage)</td></tr>"
                    }) -join "`n"
                } else {
                    '<tr><td colspan="4" class="muted">Провайдерів Critical/Error/Warning за вибраний період не знайдено.</td></tr>'
                }
            } else {
                '<tr><td colspan="4" class="muted">Provider summary недоступний для поточного профілю (Full/Deep/Forensic).</td></tr>'
            }

            $hardwareDiagnosticRows = if (@($script:Report.EventLogs.HardwareDiagnostics).Count -gt 0) {
                (@($script:Report.EventLogs.HardwareDiagnostics) | ForEach-Object {
                    $diag = $_
                    $countText = if ($null -eq $diag.Count) { '—' } else { $diag.Count }
                    $countClass = if ($null -ne $diag.Count -and [int]$diag.Count -gt 0) { 'risk-warning' } else { 'risk-ok' }
                    "<tr><td>$(ConvertTo-BravoHtmlText $diag.Provider)</td><td>$(ConvertTo-BravoHtmlText $diag.Status)</td><td><span class=`"risk $countClass`">$(ConvertTo-BravoHtmlText $countText)</span></td><td>$(ConvertTo-BravoHtmlText $diag.LastMessage)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Hardware diagnostics недоступні для поточного профілю (Full/Deep/Forensic).</td></tr>'
            }

            $listeningPortRows = if (@($script:Report.Network.Connections.ListeningPorts).Count -gt 0) {
                (@($script:Report.Network.Connections.ListeningPorts) | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.LocalAddress)</td><td>$(ConvertTo-BravoHtmlText $_.LocalPort)</td><td>$(ConvertTo-BravoHtmlText $_.OwningProcess)</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $_.ProcessName))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Listening ports недоступні для поточного профілю (Full/Deep/Forensic).</td></tr>'
            }

            $establishedConnectionRows = if (@($script:Report.Network.Connections.EstablishedConnections).Count -gt 0) {
                (@($script:Report.Network.Connections.EstablishedConnections) | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.LocalAddress)</td><td>$(ConvertTo-BravoHtmlText $_.LocalPort)</td><td>$(ConvertTo-BravoHtmlText $_.RemoteAddress)</td><td>$(ConvertTo-BravoHtmlText $_.RemotePort)</td><td>$(ConvertTo-BravoHtmlText $_.OwningProcess)</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $_.ProcessName))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="6" class="muted">Established connections недоступні для поточного профілю (Full/Deep/Forensic).</td></tr>'
            }

            $smbShareRows = if (@($script:Report.Network.SmbShares).Count -gt 0) {
                (@($script:Report.Network.SmbShares) | ForEach-Object {
                    $share = $_
                    $adminClass = if ($share.IsAdministrative) { 'risk-unknown' } else { 'risk-ok' }
                    "<tr><td>$(ConvertTo-BravoHtmlText $share.Name)</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $share.Path))</td><td>$(ConvertTo-BravoHtmlText $share.ShareType)</td><td><span class=`"risk $adminClass`">$(ConvertTo-BravoHtmlText $share.IsAdministrative)</span></td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">SMB shares недоступні (модуль SmbShare відсутній, шар немає, або профіль не Full/Deep/Forensic).</td></tr>'
            }

            $adapterRows = if ($script:Report.Network.Adapters.Count -gt 0) {
                ($script:Report.Network.Adapters | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Description)</td><td>$(ConvertTo-BravoHtmlText $_.MACAddress)</td><td>$(ConvertTo-BravoHtmlListText $_.IPv4)</td><td>$(ConvertTo-BravoHtmlListText $_.Gateway)</td><td>$(ConvertTo-BravoHtmlListText $_.DNS)</td><td>$(ConvertTo-BravoHtmlText $_.DHCPEnabled)</td><td>$(ConvertTo-BravoHtmlText $_.LinkSpeed)</td><td>$(ConvertTo-BravoHtmlText $_.Status)</td><td>$(ConvertTo-BravoHtmlText $_.DriverVersion)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="9" class="muted">Мережеві адаптери не знайдені або збір недоступний.</td></tr>'
            }

            $routingTableEntries = @($script:Report.Network.Routing.RoutingTable)
            $routingTableRows = if ($routingTableEntries.Count -gt 0) {
                ($routingTableEntries | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.DestinationPrefix)</td><td>$(ConvertTo-BravoHtmlText $_.NextHop)</td><td>$(ConvertTo-BravoHtmlText $_.RouteMetric)</td><td>$(ConvertTo-BravoHtmlText $_.InterfaceAlias)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Routing table дані відсутні (профіль не Full/Deep/Forensic, або збір завершився з помилкою).</td></tr>'
            }

            $arpEntries = @($script:Report.Network.ARP)
            $arpRows = if ($arpEntries.Count -gt 0) {
                ($arpEntries | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.IPAddress)</td><td>$(ConvertTo-BravoHtmlText $_.LinkLayerAddress)</td><td>$(ConvertTo-BravoHtmlText $_.State)</td><td>$(ConvertTo-BravoHtmlText $_.InterfaceAlias)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">ARP-кеш даних відсутні (профіль не Full/Deep/Forensic, або збір завершився з помилкою).</td></tr>'
            }

            $winHttpProxyText = if (@($script:Report.Network.WinHttpProxy.RawOutput).Count -gt 0) {
                (@($script:Report.Network.WinHttpProxy.RawOutput) -join '; ')
            } else {
                $script:Report.Network.WinHttpProxy.Status
            }

            $disksContainer = $script:Report.Hardware.Disks
            if ($disksContainer -is [System.Collections.IDictionary]) {
                $storageDeep = $disksContainer['Deep']
                $storageRisk = $disksContainer['StorageRisk']
            } else {
                $storageDeep = $disksContainer.Deep
                $storageRisk = $disksContainer.StorageRisk
            }

            $criticalThreshold = if ($storageRisk -and $storageRisk.CriticalFreePercent) { [double]$storageRisk.CriticalFreePercent } else { 5 }
            $warningThreshold = if ($storageRisk -and $storageRisk.WarningFreePercent) { [double]$storageRisk.WarningFreePercent } else { 10 }
            $criticalCount = if ($storageRisk -and $storageRisk.Summary) { [int]$storageRisk.Summary.CriticalCount } else { 0 }
            $warningCount = if ($storageRisk -and $storageRisk.Summary) { [int]$storageRisk.Summary.WarningCount } else { 0 }
            $systemWarningCount = if ($storageRisk -and $storageRisk.Summary) { [int]$storageRisk.Summary.SystemWarningCount } else { 0 }
            $healthyCount = if ($storageRisk -and $storageRisk.Summary) { [int]$storageRisk.Summary.HealthyCount } else { 0 }
            $reservedCount = if ($storageRisk -and $storageRisk.Summary) { [int]$storageRisk.Summary.ReservedCount } else { 0 }

            $storageFindingItems = @()
            foreach ($item in @($storageRisk.CriticalVolumes)) { if ($item) { $storageFindingItems += [PSCustomObject]@{ Group = 'CRITICAL'; Volume = $item } } }
            foreach ($item in @($storageRisk.WarningVolumes)) { if ($item) { $storageFindingItems += [PSCustomObject]@{ Group = 'WARNING'; Volume = $item } } }
            foreach ($item in @($storageRisk.SystemVolumeWarnings)) { if ($item) { $storageFindingItems += [PSCustomObject]@{ Group = 'WARNING'; Volume = $item } } }

            $storageCriticalRows = if (@($storageFindingItems).Count -gt 0) {
                ($storageFindingItems | ForEach-Object {
                    $volume = $_.Volume
                    $riskText = if ($volume.Risk) { [string]$volume.Risk } else { [string]$_.Group }
                    $riskClass = Get-BravoStorageRiskClass $riskText
                    $reason = if ($volume.Reason) { $volume.Reason } elseif ($volume.Message) { $volume.Message } else { 'Потребує перевірки storage thresholds.' }
                    "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStorageDisplayText $volume))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.Label))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FileSystem))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.SizeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreePercent))%</td><td><span class=`"risk $riskClass`">$(ConvertTo-BravoHtmlText $riskText)</span></td><td>$(ConvertTo-BravoHtmlText $reason)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="8" class="muted">Критичних або попереджувальних storage-знахідок немає.</td></tr>'
            }

            $storageVolumes = @($storageDeep.Volumes)
            $storageDeepRows = if ($storageVolumes.Count -gt 0) {
                ($storageVolumes | ForEach-Object {
                    $volume = $_
                    $freePercent = $null
                    if ($null -ne $volume.FreePercent -and [string]$volume.FreePercent -ne '') { $freePercent = [double]$volume.FreePercent }
                    $hasDriveLetter = [bool]($volume.DriveLetter -and [string]$volume.DriveLetter -ne '')
                    # Томи без літери диска (WinRE/EFI/MSR) — системно-
                    # зарезервовані розділи, майже завжди заповнені образом
                    # відновлення; той самий принцип виключення, що й у
                    # Get-BravoStorageRiskSummary (src/32-Collectors-Storage.ps1)
                    # — інакше ця таблиця незалежно рахує WARNING/CRITICAL для
                    # штатного стану, розбігаючись із Findings-зведенням вище.
                    $riskText = if (-not $hasDriveLetter) { 'RESERVED' } elseif ($null -eq $freePercent) { 'UNKNOWN' } elseif ($freePercent -lt $criticalThreshold) { 'CRITICAL' } elseif ($freePercent -lt $warningThreshold) { 'WARNING' } else { 'OK' }
                    $riskClass = Get-BravoStorageRiskClass $riskText
                    $reason = if ($riskText -eq 'RESERVED') { 'Системно-зарезервований том без літери диска (WinRE/EFI/MSR) — не є ризиком.' } elseif ($riskText -eq 'CRITICAL') { "Вільного місця менше $criticalThreshold%." } elseif ($riskText -eq 'WARNING') { "Вільного місця менше $warningThreshold%." } elseif ($riskText -eq 'UNKNOWN') { 'Не вдалося визначити free percent.' } else { 'Показники в межах порогів.' }
                    "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStorageDisplayText $volume))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FileSystemLabel))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FileSystem))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.DriveType))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.HealthStatus))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.OperationalStatus))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.SizeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreePercent))%</td><td><span class=`"risk $riskClass`">$(ConvertTo-BravoHtmlText $riskText)</span></td><td>$(ConvertTo-BravoHtmlText $reason)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="11" class="muted">Storage Deep дані відсутні для поточного профілю або збір завершився з помилкою.</td></tr>'
            }

            $bitlockerVolumes = @($storageDeep.BitLocker)
            $bitlockerRows = if ($bitlockerVolumes.Count -gt 0) {
                ($bitlockerVolumes | ForEach-Object {
                    $volume = $_
                    $protectionText = [string]$volume.ProtectionStatus
                    $protectionClass = if ($protectionText -eq 'On') { 'risk-ok' } elseif ($protectionText -eq 'Off') { 'risk-warning' } else { 'risk-unknown' }
                    "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.MountPoint))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.VolumeType))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.VolumeStatus))</td><td><span class=`"risk $protectionClass`">$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.ProtectionStatus))</span></td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.EncryptionPercentage))%</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.EncryptionMethod))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.LockStatus))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="7" class="muted">BitLocker дані відсутні (модуль не встановлено, профіль не Deep/Forensic, або збір завершився з помилкою).</td></tr>'
            }

            $shadowCopyList = @($storageDeep.ShadowCopies)
            $shadowCopyRows = if ($shadowCopyList.Count -gt 0) {
                ($shadowCopyList | ForEach-Object {
                    $shadowCopy = $_
                    "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $shadowCopy.VolumeName))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $shadowCopy.InstallDate))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $shadowCopy.ClientAccessible))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $shadowCopy.Persistent))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Точки відновлення VSS відсутні (немає активних точок відновлення, або профіль не Deep/Forensic).</td></tr>'
            }

            $storagePoolList = @($storageDeep.StoragePools)
            $storagePoolRows = if ($storagePoolList.Count -gt 0) {
                ($storagePoolList | ForEach-Object {
                    $pool = $_
                    $poolHealthText = [string]$pool.HealthStatus
                    $poolHealthClass = if ($poolHealthText -eq 'Healthy') { 'risk-ok' } elseif ($poolHealthText -eq '') { 'risk-unknown' } else { 'risk-warning' }
                    "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $pool.FriendlyName))</td><td><span class=`"risk $poolHealthClass`">$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $pool.HealthStatus))</span></td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $pool.OperationalStatus))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $pool.SizeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $pool.AllocatedGB))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="5" class="muted">Storage Spaces не використовується (немає пулів, модуль Storage відсутній, або профіль не Deep/Forensic).</td></tr>'
            }

            $reliabilityList = @($storageDeep.ReliabilityCounters)
            $reliabilityRows = if ($reliabilityList.Count -gt 0) {
                ($reliabilityList | ForEach-Object {
                    $counter = $_
                    $wearText = if ($null -ne $counter.WearPercent -and [string]$counter.WearPercent -ne '') { "$($counter.WearPercent)%" } else { '—' }
                    $wearClass = if ($null -ne $counter.WearPercent -and [string]$counter.WearPercent -ne '' -and [double]$counter.WearPercent -ge 90) { 'risk-warning' } else { 'risk-ok' }
                    $readUncorrected = if ($counter.ReadErrorsUncorrected) { [int64]$counter.ReadErrorsUncorrected } else { 0 }
                    $writeUncorrected = if ($counter.WriteErrorsUncorrected) { [int64]$counter.WriteErrorsUncorrected } else { 0 }
                    $uncorrectedErrors = $readUncorrected + $writeUncorrected
                    $errorsClass = if ($uncorrectedErrors -gt 0) { 'risk-warning' } else { 'risk-ok' }
                    "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $counter.FriendlyName))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $counter.MediaType))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $counter.TemperatureCelsius))</td><td><span class=`"risk $wearClass`">$(ConvertTo-BravoHtmlText $wearText)</span></td><td><span class=`"risk $errorsClass`">$uncorrectedErrors</span></td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $counter.PowerOnHours))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="6" class="muted">SMART reliability counters відсутні (модуль Storage не встановлено, диск не підтримує лічильники, або профіль не Deep/Forensic).</td></tr>'
            }

            $smartPredictList = @($storageDeep.SmartPredictFailures)
            $smartPredictRows = if ($smartPredictList.Count -gt 0) {
                ($smartPredictList | ForEach-Object {
                    $predict = $_
                    $predictClass = if ($predict.PredictFailure) { 'risk-critical' } else { 'risk-ok' }
                    "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $predict.InstanceName))</td><td><span class=`"risk $predictClass`">$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $predict.PredictFailure))</span></td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $predict.Reason))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="3" class="muted">SMART predictive-failure API недоступне на цій машині (типово для NVMe/RAID-контролерів — обмеження драйвера, не помилка).</td></tr>'
            }

            $monitorRows = if (@($script:Report.Hardware.Monitors).Count -gt 0) {
                (@($script:Report.Hardware.Monitors) | ForEach-Object {
                    $monitor = $_
                    $sizeText = if ($monitor.WidthCm -and $monitor.HeightCm) { "$($monitor.WidthCm)x$($monitor.HeightCm) см" } else { '—' }
                    "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $monitor.Manufacturer))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $monitor.Model))</td><td>$(ConvertTo-BravoHtmlText $monitor.Active)</td><td>$(ConvertTo-BravoHtmlText $sizeText)</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $monitor.YearOfManufacture))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="5" class="muted">Дані про монітори недоступні (WmiMonitorID, напр. на VM/RDP-сесії без реального дисплея).</td></tr>'
            }

            $gpuList = @($script:Report.Hardware.GPU)
            $gpuRows = if ($gpuList.Count -gt 0) {
                ($gpuList | ForEach-Object {
                    $gpu = $_
                    $adapterRamText = if ($gpu.AdapterRAMBytes) { Format-Size ([Math]::Round($gpu.AdapterRAMBytes / 1GB, 2)) } else { 'N/A' }
                    "<tr><td>$(ConvertTo-BravoHtmlText $gpu.Name)</td><td>$(ConvertTo-BravoHtmlText $adapterRamText)</td><td>$(ConvertTo-BravoHtmlText $gpu.DriverVersion)</td><td>$(ConvertTo-BravoHtmlText $gpu.CurrentResolution)</td><td>$(ConvertTo-BravoHtmlText $gpu.Status)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="5" class="muted">GPU дані відсутні (профіль не Full/Deep/Forensic, або збір завершився з помилкою).</td></tr>'
            }

            $tlsProtocolList = @($script:Report.Security.TLS.Protocols)
            $tlsRows = if ($tlsProtocolList.Count -gt 0) {
                ($tlsProtocolList | ForEach-Object {
                    $tlsEntry = $_
                    $tlsStatusText = [string]$tlsEntry.Status
                    $tlsStatusClass = if ($tlsStatusText -eq 'Enabled') { 'risk-ok' } elseif ($tlsStatusText -eq 'Disabled') { 'risk-warning' } else { 'risk-unknown' }
                    "<tr><td>$(ConvertTo-BravoHtmlText $tlsEntry.Protocol)</td><td>$(ConvertTo-BravoHtmlText $tlsEntry.Side)</td><td><span class=`"risk $tlsStatusClass`">$(ConvertTo-BravoHtmlText $tlsStatusText)</span></td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="3" class="muted">TLS registry дані відсутні (профіль не Full/Deep/Forensic, або збір завершився з помилкою).</td></tr>'
            }

            $auditPolicyEntries = @($script:Report.Security.AuditPolicy.Subcategories)
            $auditPolicyRows = if ($auditPolicyEntries.Count -gt 0) {
                ($auditPolicyEntries | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Category)</td><td>$(ConvertTo-BravoHtmlText $_.Subcategory)</td><td>$(ConvertTo-BravoHtmlText $_.InclusionSetting)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="3" class="muted">Audit policy дані відсутні (профіль не Full/Deep/Forensic, або збір завершився з помилкою).</td></tr>'
            }

            $autorunEntries = @($script:Report.Security.Autoruns)
            $autorunRows = if ($autorunEntries.Count -gt 0) {
                ($autorunEntries | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Name)</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $_.Command))</td><td>$(ConvertTo-BravoHtmlText $_.Source)</td><td>$(ConvertTo-BravoHtmlText $_.Hive)</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="4" class="muted">Autoruns-записів не знайдено (профіль не Deep/Forensic, або чисте автозавантаження).</td></tr>'
            }

            $scheduledTaskEntries = @($script:Report.Security.ScheduledTasks | Where-Object { -not $_.IsMicrosoftDefault })
            $scheduledTaskRows = if ($scheduledTaskEntries.Count -gt 0) {
                ($scheduledTaskEntries | ForEach-Object {
                    "<tr><td>$(ConvertTo-BravoHtmlText $_.Name)</td><td>$(ConvertTo-BravoHtmlText $_.Path)</td><td>$(ConvertTo-BravoHtmlText $_.State)</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $_.Author))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $_.Execute))</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="5" class="muted">Не-Microsoft scheduled tasks не знайдено (профіль не Deep/Forensic, або всі задачі — вбудовані Microsoft-задачі).</td></tr>'
            }
            $scheduledTaskMicrosoftCount = @($script:Report.Security.ScheduledTasks | Where-Object { $_.IsMicrosoftDefault }).Count

            $updatesPending = @($script:Report.WindowsUpdate.PendingUpdates)
            $updatesPendingRows = if ($updatesPending.Count -gt 0) {
                ($updatesPending | ForEach-Object {
                    $pendingUpdate = $_
                    $severityText = if ([string]::IsNullOrWhiteSpace([string]$pendingUpdate.Severity)) { 'Unspecified' } else { [string]$pendingUpdate.Severity }
                    $severityClass = switch ($severityText) {
                        'Critical'  { 'risk-critical' }
                        'Important' { 'risk-warning' }
                        'Moderate'  { 'risk-warning' }
                        'Low'       { 'risk-ok' }
                        default     { 'risk-unknown' }
                    }
                    # Allow-list схеми перед вставкою в href: HTML-encode сам собою
                    # не блокує javascript:/data:-URI, лише екранує спецсимволи.
                    $catalogUrlValue = [string]$pendingUpdate.CatalogUrl
                    $catalogLinkHtml = if ([string]::IsNullOrWhiteSpace($catalogUrlValue) -or $catalogUrlValue -notmatch '^https://') { '' } else { "<a href=`"$(ConvertTo-BravoHtmlText $catalogUrlValue)`" target=`"_blank`" rel=`"noopener noreferrer`">Catalog ↗</a>" }
                    "<tr><td>$(ConvertTo-BravoHtmlText $pendingUpdate.KB)</td><td>$(ConvertTo-BravoHtmlText $pendingUpdate.Title)</td><td><span class=`"risk $severityClass`">$(ConvertTo-BravoHtmlText $severityText)</span></td><td>$(ConvertTo-BravoHtmlText $pendingUpdate.Categories)</td><td>$(if($pendingUpdate.IsDownloaded){'Так'}else{'Ні'})</td><td>$(ConvertTo-BravoHtmlText $pendingUpdate.SizeMB)</td><td>$catalogLinkHtml</td></tr>"
                }) -join "`n"
            } else {
                '<tr><td colspan="7" class="muted">Відсутні оновлення не виявлені, пошук пропущено або завершився з помилкою (див. Search status).</td></tr>'
            }

            $computerNameHtml = ConvertTo-BravoHtmlText $script:Report.ComputerName
            $timestampHtml = ConvertTo-BravoHtmlText $script:Report.Timestamp
            $profileHtml = ConvertTo-BravoHtmlText $Profile
            $statusHtml = ConvertTo-BravoHtmlText $script:Report.Status
            $statusReasonHtml = ConvertTo-BravoHtmlText $script:Report.StatusReason
            $statusClass = Get-BravoStatusClass $script:Report.Status
            $uptimeHtml = ConvertTo-BravoHtmlText $script:Report.Dashboard.Header.UptimeText
            $primaryIpv4Html = ConvertTo-BravoHtmlText $script:Report.Network.IP.PrimaryIPv4
            $publicIpv4StatusForReport = if (-not [string]::IsNullOrWhiteSpace([string]$script:Report.Network.IP.PublicIPv4)) {
                [string]$script:Report.Network.IP.PublicIPv4
            } else {
                [string]$script:Report.Network.IP.PublicIPv4Status
            }
            $publicIpv4LocationPartsForReport = @(
                [string]$script:Report.Network.IP.PublicIPv4Country
                [string]$script:Report.Network.IP.PublicIPv4Region
                [string]$script:Report.Network.IP.PublicIPv4City
            ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

            $publicIpv4LocationForReport = if ($publicIpv4LocationPartsForReport.Count -gt 0) {
                $publicIpv4LocationPartsForReport -join ', '
            } else {
                ''
            }
            $htmlTitle = ConvertTo-BravoHtmlText "BRAVO SYSTEM REPORT - $($script:Report.ComputerName)"

            $htmlContent = @"
<!DOCTYPE html>
<html lang="uk">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$htmlTitle</title>
<style>
:root{--page-bg:#0b1020;--panel:#ffffff;--panel-soft:#f8fafc;--panel-muted:#eef2ff;--text:#0f172a;--muted:#64748b;--line:#e2e8f0;--primary:#2563eb;--primary-dark:#1e40af;--accent:#06b6d4;--success:#16a34a;--warning:#d97706;--critical:#dc2626;--unknown:#64748b;--shadow:0 22px 60px rgba(15,23,42,.24);--radius-lg:24px;--radius-md:18px;--radius-sm:12px;--nav-bg:rgba(248,250,252,.96);--btn-bg:#ffffff;--btn-text:#1e293b;--tab-panel-bg:linear-gradient(180deg,#ffffff,#fbfdff);--title-text:#0f172a;--metric-card-bg:linear-gradient(180deg,#ffffff,#f8fafc);--toolbar-bg:#f8fafc;--search-bg:#ffffff;--search-border:#cbd5e1;--table-scroll-bg:#ffffff;--th-bg:#eff6ff;--th-text:#1e3a8a;--storage-item-bg:#f8fafc;--progress-track:#e2e8f0}
:root[data-theme="dark"]{--panel:#0f172a;--panel-soft:#1e293b;--panel-muted:#1e3a5f;--text:#e2e8f0;--muted:#94a3b8;--line:#334155;--nav-bg:rgba(15,23,42,.94);--btn-bg:#1e293b;--btn-text:#e2e8f0;--tab-panel-bg:linear-gradient(180deg,#1e293b,#0f172a);--title-text:#e2e8f0;--metric-card-bg:linear-gradient(180deg,#1e293b,#0f172a);--toolbar-bg:#1e293b;--search-bg:#0f172a;--search-border:#334155;--table-scroll-bg:#0f172a;--th-bg:#1e3a5f;--th-text:#93c5fd;--storage-item-bg:#1e293b;--progress-track:#334155}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--panel:#0f172a;--panel-soft:#1e293b;--panel-muted:#1e3a5f;--text:#e2e8f0;--muted:#94a3b8;--line:#334155;--nav-bg:rgba(15,23,42,.94);--btn-bg:#1e293b;--btn-text:#e2e8f0;--tab-panel-bg:linear-gradient(180deg,#1e293b,#0f172a);--title-text:#e2e8f0;--metric-card-bg:linear-gradient(180deg,#1e293b,#0f172a);--toolbar-bg:#1e293b;--search-bg:#0f172a;--search-border:#334155;--table-scroll-bg:#0f172a;--th-bg:#1e3a5f;--th-text:#93c5fd;--storage-item-bg:#1e293b;--progress-track:#334155}}
.theme-toggle{display:inline-flex;align-items:center;justify-content:center;width:38px;height:38px;border-radius:12px;border:1px solid rgba(255,255,255,.28);background:rgba(255,255,255,.13);color:white;font-size:18px;cursor:pointer;line-height:1}.theme-toggle:hover{background:rgba(255,255,255,.24)}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;font-family:'Segoe UI',Roboto,Arial,sans-serif;background:radial-gradient(circle at 15% 8%,rgba(37,99,235,.34),transparent 28%),radial-gradient(circle at 92% 18%,rgba(6,182,212,.28),transparent 30%),linear-gradient(135deg,#0b1020,#111827 48%,#020617);color:var(--text)}
.report-shell{max-width:1440px;margin:28px auto;background:var(--panel);border-radius:var(--radius-lg);overflow:hidden;box-shadow:var(--shadow)}
.dashboard-header{position:relative;color:white;padding:32px 38px 24px 38px;background:linear-gradient(135deg,rgba(37,99,235,.98),rgba(14,165,233,.88)),linear-gradient(135deg,#0f172a,#1e293b)}
.dashboard-header:after{content:'';position:absolute;right:-70px;bottom:-120px;width:280px;height:280px;border-radius:999px;background:rgba(255,255,255,.13)}
.header-grid{position:relative;z-index:1;display:grid;grid-template-columns:minmax(0,1fr) auto auto;gap:22px;align-items:start}.brand{display:flex;gap:18px;align-items:center}.brand-icon{width:70px;height:70px;display:flex;align-items:center;justify-content:center;border-radius:22px;background:rgba(255,255,255,.18);border:1px solid rgba(255,255,255,.28);font-size:36px}
.dashboard-header h1{margin:0;font-size:34px;letter-spacing:.4px}.dashboard-header p{margin:8px 0 0 0;opacity:.92}.header-meta{display:grid;grid-template-columns:repeat(2,minmax(130px,auto));gap:10px;min-width:320px}.meta-tile{padding:10px 12px;border:1px solid rgba(255,255,255,.24);border-radius:14px;background:rgba(255,255,255,.13);backdrop-filter:blur(8px)}.meta-label{font-size:11px;text-transform:uppercase;letter-spacing:.06em;opacity:.75;font-weight:800}.meta-value{font-size:14px;font-weight:900;margin-top:4px;word-break:break-word}
.status-pill{display:inline-flex;align-items:center;justify-content:center;border-radius:999px;padding:6px 10px;font-size:12px;font-weight:900;letter-spacing:.03em;white-space:nowrap}.status-ok{background:rgba(22,163,74,.12);color:var(--success);border:1px solid rgba(22,163,74,.35)}.status-warning{background:rgba(217,119,6,.12);color:var(--warning);border:1px solid rgba(217,119,6,.35)}.status-critical{background:rgba(220,38,38,.12);color:var(--critical);border:1px solid rgba(220,38,38,.35)}.status-unknown{background:rgba(100,116,139,.12);color:var(--unknown);border:1px solid rgba(100,116,139,.35)}.dashboard-header .status-pill{background:rgba(255,255,255,.16);color:white;border-color:rgba(255,255,255,.3)}
.tab-nav{position:sticky;top:0;z-index:10;display:flex;flex-wrap:wrap;gap:8px;padding:14px 30px;background:var(--nav-bg);border-bottom:1px solid var(--line);backdrop-filter:blur(12px)}.tab-button{display:inline-flex;align-items:center;gap:8px;padding:10px 14px;border-radius:999px;border:1px solid var(--line);background:var(--btn-bg);color:var(--btn-text);text-decoration:none;font-weight:900;font-size:13px;box-shadow:0 4px 14px rgba(15,23,42,.06);cursor:pointer}.tab-button.active,.tab-button:hover{background:#2563eb;color:white;border-color:#2563eb}
.content{padding:30px}.tab-panel{display:none;margin-bottom:30px;padding:24px;border:1px solid var(--line);border-radius:22px;background:var(--tab-panel-bg);box-shadow:0 10px 30px rgba(15,23,42,.06)}.tab-panel.active{display:block}.tab-panel-title{display:flex;align-items:center;gap:12px;margin:0 0 18px 0;color:var(--title-text);font-size:22px}.tab-panel-title:after{content:'';flex:1;height:1px;background:var(--line)}.section-icon{width:38px;height:38px;display:inline-flex;align-items:center;justify-content:center;border-radius:12px;background:var(--panel-muted);color:var(--primary)}
.metrics-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:16px;margin-bottom:22px}.metric-card{position:relative;min-height:160px;padding:20px;border:1px solid var(--line);border-radius:20px;background:var(--metric-card-bg);box-shadow:0 8px 24px rgba(15,23,42,.07);overflow:hidden}.metric-card:before{content:'';position:absolute;left:0;top:0;bottom:0;width:5px;background:var(--unknown)}.metric-card.status-ok:before{background:var(--success)}.metric-card.status-warning:before{background:var(--warning)}.metric-card.status-critical:before{background:var(--critical)}.metric-topline{display:flex;justify-content:space-between;gap:10px;align-items:center;margin-bottom:12px}.metric-icon{font-size:30px}.metric-title{color:var(--muted);font-size:13px;font-weight:900;text-transform:uppercase;letter-spacing:.06em}.metric-value{margin-top:8px;font-size:24px;font-weight:950;color:var(--text);line-height:1.15;word-break:break-word}.metric-details{margin-top:8px;color:var(--muted);font-size:13px;line-height:1.45}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:18px}.card{background:var(--panel-soft);border:1px solid var(--line);border-radius:18px;padding:20px;box-shadow:0 8px 24px rgba(15,23,42,.06)}.card h3{display:flex;align-items:center;gap:8px;margin:0 0 14px 0;font-size:18px;color:var(--title-text)}.info-row{display:flex;justify-content:space-between;gap:16px;padding:10px 0;border-bottom:1px solid var(--line)}.info-row:last-child{border-bottom:none}.info-label{font-weight:850;color:var(--muted)}.info-value{color:var(--text);text-align:right;word-break:break-word;font-weight:650}.progress-bar{background:var(--progress-track);border-radius:999px;overflow:hidden;min-width:170px;height:24px}.progress-fill{height:24px;line-height:24px;background:linear-gradient(90deg,var(--primary),var(--accent));color:white;text-align:center;font-size:12px;font-weight:900}
.table-toolbar{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:10px 0 10px 0;padding:10px 12px;border:1px solid var(--line);border-radius:14px;background:var(--toolbar-bg)}.table-search{width:min(420px,100%);padding:10px 12px;border:1px solid var(--search-border);border-radius:12px;background:var(--search-bg);color:var(--text);font-size:13px;font-weight:650;outline:none}.table-search:focus{border-color:var(--primary);box-shadow:0 0 0 3px rgba(37,99,235,.16)}.table-counter{color:var(--muted);font-size:12px;font-weight:900;white-space:nowrap}.row-hidden{display:none !important}
.table-scroll{max-height:430px;overflow:auto;border:1px solid var(--line);border-radius:14px;background:var(--table-scroll-bg)}.data-table{width:100%;border-collapse:separate;border-spacing:0;font-size:13px}.data-table th,.data-table td{padding:11px 12px;text-align:left;border-bottom:1px solid var(--line);vertical-align:top}.data-table th{position:sticky;top:0;background:var(--th-bg);color:var(--th-text);font-size:12px;text-transform:uppercase;letter-spacing:.04em;z-index:1}.data-table tr:last-child td{border-bottom:none}.storage-summary-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin:12px 0 16px 0}.storage-summary-item{background:var(--storage-item-bg);border:1px solid var(--line);border-radius:12px;padding:12px}.storage-summary-label{color:var(--muted);font-size:12px;margin-bottom:4px;font-weight:800;text-transform:uppercase;letter-spacing:.04em}.storage-summary-value{font-size:22px;font-weight:900}.risk{font-weight:900;white-space:nowrap}.risk-critical{color:var(--critical)}.risk-warning{color:var(--warning)}.risk-ok{color:var(--success)}.risk-unknown{color:var(--muted)}.muted{color:var(--muted)}.footer{background:var(--toolbar-bg);border-top:1px solid var(--line);padding:18px 24px;text-align:center;color:var(--muted);font-size:13px}
@media (max-width:820px){.report-shell{margin:0;border-radius:0}.dashboard-header{padding:24px}.header-grid{grid-template-columns:1fr}.header-meta{grid-template-columns:1fr;min-width:0}.content{padding:18px}.tab-panel{padding:16px}.info-row{display:block}.info-value{display:block;text-align:left;margin-top:4px}.table-toolbar{align-items:stretch;flex-direction:column}.table-search{width:100%}.table-counter{white-space:normal}}
@media print{body{background:white}.report-shell{box-shadow:none;margin:0;border-radius:0}.dashboard-header{background:#1e40af !important}.tab-nav,.table-toolbar{display:none}.tab-panel{display:block !important;break-inside:avoid;box-shadow:none}.table-scroll{max-height:none;overflow:visible}.row-hidden{display:table-row !important}}
</style>
</head>
<body>
<div class="report-shell">
  <header class="dashboard-header">
    <div class="header-grid">
      <div class="brand"><div class="brand-icon">📊</div><div><h1>BRAVO SYSTEM REPORT</h1><p>$computerNameHtml | $timestampHtml | Profile: $profileHtml</p><p><span class="status-pill $statusClass">Health Score: $($script:Report.Health.Score)/100 — $statusHtml</span></p></div></div>
      <div class="header-meta"><div class="meta-tile"><div class="meta-label">Computer</div><div class="meta-value">$computerNameHtml</div></div><div class="meta-tile"><div class="meta-label">Uptime</div><div class="meta-value">$uptimeHtml</div></div><div class="meta-tile"><div class="meta-label">Primary IPv4</div><div class="meta-value">$primaryIpv4Html</div></div><div class="meta-tile"><div class="meta-label">Status reason</div><div class="meta-value">$statusReasonHtml</div></div></div>
      <button type="button" id="theme-toggle" class="theme-toggle" onclick="toggleTheme()" aria-label="Перемкнути тему" title="Світла/темна тема">🌙</button>
    </div>
  </header>
  <nav class="tab-nav" aria-label="BRAVO report sections">
    <button type="button" class="tab-button active" data-tab-target="tab-general" onclick="openTab(event, 'tab-general')" aria-controls="tab-general" aria-selected="true">General</button>
    <button type="button" class="tab-button" data-tab-target="tab-os" onclick="openTab(event, 'tab-os')" aria-controls="tab-os" aria-selected="false">OS</button>
    <button type="button" class="tab-button" data-tab-target="tab-hardware" onclick="openTab(event, 'tab-hardware')" aria-controls="tab-hardware" aria-selected="false">Hardware</button>
    <button type="button" class="tab-button" data-tab-target="tab-network" onclick="openTab(event, 'tab-network')" aria-controls="tab-network" aria-selected="false">Network</button>
    <button type="button" class="tab-button" data-tab-target="tab-security" onclick="openTab(event, 'tab-security')" aria-controls="tab-security" aria-selected="false">Security</button>
    <button type="button" class="tab-button" data-tab-target="tab-services" onclick="openTab(event, 'tab-services')" aria-controls="tab-services" aria-selected="false">Services</button>
    <button type="button" class="tab-button" data-tab-target="tab-software" onclick="openTab(event, 'tab-software')" aria-controls="tab-software" aria-selected="false">Software</button>
    <button type="button" class="tab-button" data-tab-target="tab-updates" onclick="openTab(event, 'tab-updates')" aria-controls="tab-updates" aria-selected="false">Updates</button>
    <button type="button" class="tab-button" data-tab-target="tab-findings" onclick="openTab(event, 'tab-findings')" aria-controls="tab-findings" aria-selected="false">Findings</button>
  </nav>
  <main class="content">
    <section id="tab-general" class="tab-panel active"><h2 class="tab-panel-title"><span class="section-icon">📌</span>General Dashboard</h2><div class="metrics-grid">$metricCardsHtml</div><div class="grid"><div class="card"><h3>Підсумок</h3>$(New-BravoInfoRowHtml 'Health Score' "$($script:Report.Health.Score)/100")$(New-BravoInfoRowHtml 'Status' $script:Report.Status)$(New-BravoInfoRowHtml 'Status reason' $script:Report.StatusReason)$(New-BravoInfoRowHtml 'Findings' $script:Report.Health.Findings.Count)$(New-BravoInfoRowHtml 'Collection errors' $script:Report.CollectionErrors.Count)</div><div class="card"><h3>Ключова мережа</h3>$(New-BravoInfoRowHtml 'Primary IPv4' $script:Report.Network.IP.PrimaryIPv4)$(New-BravoInfoRowHtml 'Gateway' ((@($script:Report.Network.Routing.DefaultGateways) | Where-Object { $_ }) -join ', '))$(New-BravoInfoRowHtml 'DNS' ((@($script:Report.Network.Routing.DNSServers) | Where-Object { $_ }) -join ', '))$(New-BravoInfoRowHtml 'Public IPv4 status' $publicIpv4StatusForReport)</div></div></section>
    <section id="tab-os" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">🖥️</span>OS</h2><div class="grid"><div class="card"><h3>Операційна система</h3>$(New-BravoInfoRowHtml 'OS' $script:Report.OS.Caption)$(New-BravoInfoRowHtml 'Version' $script:Report.OS.Version)$(New-BravoInfoRowHtml 'Build' $script:Report.OS.Build)$(New-BravoInfoRowHtml 'Architecture' $script:Report.OS.Architecture)$(New-BravoInfoRowHtml 'Install date' $script:Report.OS.InstallDate)$(New-BravoInfoRowHtml 'Last boot' $script:Report.OS.LastBootUpTime)$(New-BravoInfoRowHtml 'Uptime' $script:Report.Dashboard.Header.UptimeText)</div><div class="card"><h3>Runtime</h3>$(New-BravoInfoRowHtml 'PowerShell' $script:Report.PowerShell.Version)$(New-BravoInfoRowHtml 'Edition' $script:Report.PowerShell.Edition)$(New-BravoInfoRowHtml 'ExecutionPolicy' $script:Report.PowerShell.ExecutionPolicy)$(New-BravoInfoRowHtml '.NET v4' $script:Report.DotNet.v4)$(New-BravoInfoRowHtml '.NET оновлення' $(if($script:Report.DotNet.UpdateAvailable){"Доступне (найновіша: $($script:Report.DotNet.LatestKnownVersion))"}else{'Немає'}))$(New-BravoInfoRowHtml 'PowerShell 7 (Core)' $(if($script:Report.PowerShell.Core7Installed){$script:Report.PowerShell.Core7Version}else{'Не встановлено'}))$(New-BravoInfoRowHtml 'PowerShell 7 оновлення' $(if($script:Report.PowerShell.Core7UpdateAvailable){"Доступне (найновіша: $($script:Report.PowerShell.Core7LatestKnown))"}else{'Немає'}))$(New-BravoInfoRowHtml 'Use CIM' $script:Report.Meta.UseCim)</div><div class="card"><h3>Windows Update</h3>$(New-BravoInfoRowHtml 'Service' $script:Report.WindowsUpdate.ServiceStatus)$(New-BravoInfoRowHtml 'Installed hotfixes' $script:Report.WindowsUpdate.InstalledHotFixCount)$(New-BravoInfoRowHtml 'Last hotfix' "$($script:Report.WindowsUpdate.LastInstalledHotFix) ($($script:Report.WindowsUpdate.LastInstallDate))")$(New-BravoInfoRowHtml 'Pending reboot' $(if($script:Report.WindowsUpdate.PendingRebootRequired){'Так'}else{'Ні'}))$(New-BravoInfoRowHtml 'Pending updates' $script:Report.WindowsUpdate.PendingCount)$(New-BravoInfoRowHtml 'Pending critical / security' "$($script:Report.WindowsUpdate.PendingCritical) / $($script:Report.WindowsUpdate.PendingSecurity)")$(New-BravoInfoRowHtml 'Search status' $script:Report.WindowsUpdate.SearchStatus)</div></div><h3>Pending Windows Updates</h3>$(New-BravoTableToolbarHtml -TableId 'table-pending-updates' -Placeholder 'Пошук по KB, назві, severity...')<div class="table-scroll"><table id="table-pending-updates" class="data-table"><thead><tr><th>KB</th><th>Назва</th><th>Severity</th><th>Категорії</th><th>Завантажено</th><th>Size MB</th><th>Посилання</th></tr></thead><tbody>$updatesPendingRows</tbody></table></div></section>
    <section id="tab-hardware" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">🧠</span>Hardware</h2><div class="grid"><div class="card"><h3>CPU / RAM</h3>$(New-BravoInfoRowHtml 'CPU' $script:Report.Hardware.CPU.Name)$(New-BravoInfoRowHtml 'Cores / threads' "$($script:Report.Hardware.CPU.Cores)/$($script:Report.Hardware.CPU.LogicalProcessors)")<div class="info-row"><span class="info-label">CPU load</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$(Get-BravoSafePercentText $script:Report.Hardware.CPU.LoadPercent)%">$(Get-BravoSafePercentText $script:Report.Hardware.CPU.LoadPercent)%</div></div></span></div>$(New-BravoInfoRowHtml 'RAM total visible' "$($script:Report.Hardware.RAM.TotalVisibleMemoryGB) GB")$(New-BravoInfoRowHtml 'RAM used/free' "$($script:Report.Hardware.RAM.UsedGB) GB / $($script:Report.Hardware.RAM.FreeGB) GB")<div class="info-row"><span class="info-label">RAM used</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$(Get-BravoSafePercentText $script:Report.Hardware.RAM.UsedPercent)%">$(Get-BravoSafePercentText $script:Report.Hardware.RAM.UsedPercent)%</div></div></span></div></div><div class="card"><h3>Disk summary</h3>$(New-BravoInfoRowHtml 'Total' (Format-Size $script:Report.Hardware.Disks.TotalGB))$(New-BravoInfoRowHtml 'Free' (Format-Size $script:Report.Hardware.Disks.FreeGB))<div class="info-row"><span class="info-label">Free percent</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$(Get-BravoSafePercentText $script:Report.Hardware.Disks.FreePercent)%">$(Get-BravoSafePercentText $script:Report.Hardware.Disks.FreePercent)%</div></div></span></div></div><div class="card"><h3>System / Motherboard</h3>$(New-BravoInfoRowHtml 'Manufacturer' $script:Report.Hardware.ComputerSystem.Manufacturer)$(New-BravoInfoRowHtml 'Model' $script:Report.Hardware.ComputerSystem.Model)$(New-BravoInfoRowHtml 'Chassis type' $script:Report.Hardware.ComputerSystem.ChassisType)$(New-BravoInfoRowHtml 'Motherboard' "$($script:Report.Hardware.Motherboard.Manufacturer) $($script:Report.Hardware.Motherboard.Product)")$(New-BravoInfoRowHtml 'Motherboard version' $script:Report.Hardware.Motherboard.Version)</div></div><div class="storage-summary-grid"><div class="storage-summary-item"><div class="storage-summary-label">Critical volumes</div><div class="storage-summary-value"><span class="risk risk-critical">$criticalCount</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">Warning volumes</div><div class="storage-summary-value"><span class="risk risk-warning">$warningCount</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">System warnings</div><div class="storage-summary-value"><span class="risk risk-warning">$systemWarningCount</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">Healthy volumes</div><div class="storage-summary-value"><span class="risk risk-ok">$healthyCount</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">System-reserved (без літери)</div><div class="storage-summary-value"><span class="risk risk-unknown">$reservedCount</span></div></div></div><h3>Storage Critical Findings</h3>$(New-BravoTableToolbarHtml -TableId 'table-storage-critical' -Placeholder 'Пошук по storage findings...')<div class="table-scroll"><table id="table-storage-critical" class="data-table"><thead><tr><th>Том</th><th>Мітка</th><th>FS</th><th>Size GB</th><th>Free GB</th><th>Free %</th><th>Risk</th><th>Причина</th></tr></thead><tbody>$storageCriticalRows</tbody></table></div><h3>Storage Deep</h3>$(New-BravoTableToolbarHtml -TableId 'table-storage-deep' -Placeholder 'Пошук по дисках, FS, health, risk...')<div class="table-scroll"><table id="table-storage-deep" class="data-table"><thead><tr><th>Том</th><th>Мітка</th><th>FS</th><th>Тип</th><th>Health</th><th>Operational</th><th>Size GB</th><th>Free GB</th><th>Free %</th><th>Risk</th><th>Причина</th></tr></thead><tbody>$storageDeepRows</tbody></table></div><h3>BitLocker</h3>$(New-BravoTableToolbarHtml -TableId 'table-bitlocker' -Placeholder 'Пошук по томах, статусу захисту...')<div class="table-scroll"><table id="table-bitlocker" class="data-table"><thead><tr><th>Том</th><th>Тип</th><th>Volume Status</th><th>Protection</th><th>Encryption %</th><th>Method</th><th>Lock Status</th></tr></thead><tbody>$bitlockerRows</tbody></table></div><h3>Shadow Copies (VSS)</h3>$(New-BravoTableToolbarHtml -TableId 'table-shadowcopies' -Placeholder 'Пошук по точках відновлення...')<div class="table-scroll"><table id="table-shadowcopies" class="data-table"><thead><tr><th>Volume</th><th>Install Date</th><th>Client Accessible</th><th>Persistent</th></tr></thead><tbody>$shadowCopyRows</tbody></table></div><h3>Storage Spaces</h3>$(New-BravoTableToolbarHtml -TableId 'table-storagepools' -Placeholder 'Пошук по пулах...')<div class="table-scroll"><table id="table-storagepools" class="data-table"><thead><tr><th>Name</th><th>Health</th><th>Operational</th><th>Size GB</th><th>Allocated GB</th></tr></thead><tbody>$storagePoolRows</tbody></table></div><h3>SMART / Reliability Counters</h3>$(New-BravoTableToolbarHtml -TableId 'table-reliability' -Placeholder 'Пошук по дисках...')<div class="table-scroll"><table id="table-reliability" class="data-table"><thead><tr><th>Disk</th><th>Media</th><th>Temp °C</th><th>Wear</th><th>Uncorrected errors</th><th>Power-on hours</th></tr></thead><tbody>$reliabilityRows</tbody></table></div><h3>SMART Predictive Failure</h3>$(New-BravoTableToolbarHtml -TableId 'table-smartpredict' -Placeholder 'Пошук по дисках...')<div class="table-scroll"><table id="table-smartpredict" class="data-table"><thead><tr><th>Instance</th><th>Predict Failure</th><th>Reason</th></tr></thead><tbody>$smartPredictRows</tbody></table></div><h3>GPU</h3>$(New-BravoTableToolbarHtml -TableId 'table-gpu' -Placeholder 'Пошук по відеокартах...')<div class="table-scroll"><table id="table-gpu" class="data-table"><thead><tr><th>Name</th><th>VRAM</th><th>Driver</th><th>Resolution</th><th>Status</th></tr></thead><tbody>$gpuRows</tbody></table></div><h3>Monitors</h3>$(New-BravoTableToolbarHtml -TableId 'table-monitors' -Placeholder 'Пошук по моніторах...')<div class="table-scroll"><table id="table-monitors" class="data-table"><thead><tr><th>Manufacturer</th><th>Model</th><th>Active</th><th>Size</th><th>Year</th></tr></thead><tbody>$monitorRows</tbody></table></div></section>
    <section id="tab-network" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">🌐</span>Network</h2><div class="grid"><div class="card"><h3>Routing</h3>$(New-BravoInfoRowHtml 'Hostname' $script:Report.Network.General.Hostname)$(New-BravoInfoRowHtml 'Domain' $script:Report.Network.General.Domain)$(New-BravoInfoRowHtml 'IPv4' ((@($script:Report.Network.IP.IPv4) | Where-Object { $_ }) -join ', '))$(New-BravoInfoRowHtml 'Primary IPv4' $script:Report.Network.IP.PrimaryIPv4)$(New-BravoInfoRowHtml 'Gateway' ((@($script:Report.Network.Routing.DefaultGateways) | Where-Object { $_ }) -join ', '))$(New-BravoInfoRowHtml 'DNS' ((@($script:Report.Network.Routing.DNSServers) | Where-Object { $_ }) -join ', '))$(New-BravoInfoRowHtml 'Public IPv4 status' $publicIpv4StatusForReport)</div><div class="card"><h3>Connections</h3>$(New-BravoInfoRowHtml 'Established' $script:Report.Network.Connections.Established)$(New-BravoInfoRowHtml 'Listening' $script:Report.Network.Connections.Listening)$(New-BravoInfoRowHtml 'ISP / Organization' $script:Report.Network.IP.PublicIPv4ISP)$(New-BravoInfoRowHtml 'ASN' $script:Report.Network.IP.PublicIPv4ASN)$(New-BravoInfoRowHtml 'Location' $publicIpv4LocationForReport)$(New-BravoInfoRowHtml 'IP lookup provider' $script:Report.Network.IP.PublicIPv4Provider)$(New-BravoInfoRowHtml 'ISP lookup provider' $script:Report.Network.IP.PublicIPv4LookupProvider)$(New-BravoInfoRowHtml 'Checked at' $script:Report.Network.IP.PublicIPv4CheckedAt)</div></div><h3>Adapters</h3>$(New-BravoTableToolbarHtml -TableId 'table-network-adapters' -Placeholder 'Пошук по adapter, MAC, IPv4, gateway, DNS, driver...')<div class="table-scroll"><table id="table-network-adapters" class="data-table"><thead><tr><th>Description</th><th>MAC</th><th>IPv4</th><th>Gateway</th><th>DNS</th><th>DHCP</th><th>Link Speed</th><th>Status</th><th>Driver</th></tr></thead><tbody>$adapterRows</tbody></table></div><div class="grid"><div class="card"><h3>WinHTTP Proxy</h3>$(New-BravoInfoRowHtml 'Status' $script:Report.Network.WinHttpProxy.Status)$(New-BravoInfoRowHtml 'Details' $winHttpProxyText)</div></div><h3>Routing Table</h3>$(New-BravoTableToolbarHtml -TableId 'table-routing' -Placeholder 'Пошук по маршрутах...')<div class="table-scroll"><table id="table-routing" class="data-table"><thead><tr><th>Destination</th><th>Next Hop</th><th>Metric</th><th>Interface</th></tr></thead><tbody>$routingTableRows</tbody></table></div><h3>ARP Cache</h3>$(New-BravoTableToolbarHtml -TableId 'table-arp' -Placeholder 'Пошук по ARP-кешу...')<div class="table-scroll"><table id="table-arp" class="data-table"><thead><tr><th>IP Address</th><th>MAC Address</th><th>State</th><th>Interface</th></tr></thead><tbody>$arpRows</tbody></table></div><h3>Listening Ports</h3>$(New-BravoTableToolbarHtml -TableId 'table-listening' -Placeholder 'Пошук по портах...')<div class="table-scroll"><table id="table-listening" class="data-table"><thead><tr><th>Local Address</th><th>Port</th><th>PID</th><th>Process</th></tr></thead><tbody>$listeningPortRows</tbody></table></div><h3>Established Connections</h3>$(New-BravoTableToolbarHtml -TableId 'table-established' -Placeholder 'Пошук по з''єднаннях...')<div class="table-scroll"><table id="table-established" class="data-table"><thead><tr><th>Local Address</th><th>Local Port</th><th>Remote Address</th><th>Remote Port</th><th>PID</th><th>Process</th></tr></thead><tbody>$establishedConnectionRows</tbody></table></div><h3>SMB Shares</h3>$(New-BravoTableToolbarHtml -TableId 'table-smbshares' -Placeholder 'Пошук по shares...')<div class="table-scroll"><table id="table-smbshares" class="data-table"><thead><tr><th>Name</th><th>Path</th><th>Type</th><th>Administrative</th></tr></thead><tbody>$smbShareRows</tbody></table></div></section>
    <section id="tab-security" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">🔒</span>Security</h2><div class="grid"><div class="card"><h3>Security baseline</h3>$(New-BravoInfoRowHtml 'UAC' $(if($script:Report.Security.UAC.Enabled){'Ввімкнено'}else{'Вимкнено'}))$(New-BravoInfoRowHtml 'RDP' $(if($script:Report.Security.RemoteAccess.RDPEnabled){'Ввімкнено'}else{'Вимкнено'}))$(New-BravoInfoRowHtml 'Antivirus' $script:Report.Security.Antivirus.Product)$(New-BravoInfoRowHtml 'Local admins' $script:Report.Users.LocalAdmins.Count)</div><div class="card"><h3>UAC full policy</h3>$(New-BravoInfoRowHtml 'Admin prompt behavior' $script:Report.Security.UAC.ConsentPromptBehaviorAdminText)$(New-BravoInfoRowHtml 'User prompt behavior' $script:Report.Security.UAC.ConsentPromptBehaviorUserText)$(New-BravoInfoRowHtml 'Secure desktop prompt' $(if($null -eq $script:Report.Security.UAC.PromptOnSecureDesktop){'N/A'}elseif($script:Report.Security.UAC.PromptOnSecureDesktop){'Так'}else{'Ні'}))$(New-BravoInfoRowHtml 'Filter admin token' $(if($null -eq $script:Report.Security.UAC.FilterAdministratorToken){'N/A'}elseif($script:Report.Security.UAC.FilterAdministratorToken){'Так'}else{'Ні'}))</div><div class="card"><h3>Firewall</h3>$(New-BravoInfoRowHtml 'Profiles collected' $script:Report.Security.Firewall.Count)$(New-BravoInfoRowHtml 'Health status' $script:Report.Health.Status)$(New-BravoInfoRowHtml 'Findings' $script:Report.Health.Findings.Count)</div><div class="card"><h3>Secure Boot / TPM / SMBv1</h3>$(New-BravoInfoRowHtml 'Secure Boot' $script:Report.Security.SecureBoot.Status)$(New-BravoInfoRowHtml 'TPM' $script:Report.Security.TPM.Status)$(New-BravoInfoRowHtml 'TPM Ready' $(if($null -eq $script:Report.Security.TPM.Ready){'N/A'}elseif($script:Report.Security.TPM.Ready){'Так'}else{'Ні'}))$(New-BravoInfoRowHtml 'TPM Manufacturer' $script:Report.Security.TPM.ManufacturerId)$(New-BravoInfoRowHtml 'TPM Spec Version' $script:Report.Security.TPM.SpecVersion)$(New-BravoInfoRowHtml 'SMBv1' $script:Report.Security.SMBv1.Status)</div><div class="card"><h3>Windows Defender</h3>$(New-BravoInfoRowHtml 'Status' $script:Report.Security.Defender.Status)$(New-BravoInfoRowHtml 'Real-Time Protection' $(if($null -eq $script:Report.Security.Defender.RealTimeProtectionEnabled){'N/A'}elseif($script:Report.Security.Defender.RealTimeProtectionEnabled){'Увімкнено'}else{'Вимкнено'}))$(New-BravoInfoRowHtml 'Behavior Monitor' $(if($null -eq $script:Report.Security.Defender.BehaviorMonitorEnabled){'N/A'}elseif($script:Report.Security.Defender.BehaviorMonitorEnabled){'Увімкнено'}else{'Вимкнено'}))$(New-BravoInfoRowHtml 'Signature version' $script:Report.Security.Defender.AntivirusSignatureVersion)$(New-BravoInfoRowHtml 'Signature age, днів' $script:Report.Security.Defender.AntivirusSignatureAgeDays)$(New-BravoInfoRowHtml 'Engine version' $script:Report.Security.Defender.AMEngineVersion)</div><div class="card"><h3>RDP details</h3>$(New-BravoInfoRowHtml 'NLA required' $(if($null -eq $script:Report.Security.RemoteAccess.NLAEnabled){'N/A'}elseif($script:Report.Security.RemoteAccess.NLAEnabled){'Так'}else{'Ні'}))$(New-BravoInfoRowHtml 'Port' $script:Report.Security.RemoteAccess.Port)$(New-BravoInfoRowHtml 'Firewall scope' $script:Report.Security.RemoteAccess.FirewallScope)$(New-BravoInfoRowHtml 'Firewall profiles' $script:Report.Security.RemoteAccess.FirewallProfiles)$(New-BravoInfoRowHtml 'Allowed users' ((@($script:Report.Security.RemoteAccess.AllowedUsers) | Where-Object { $_ }) -join ', '))</div><div class="card"><h3>WinRM</h3>$(New-BravoInfoRowHtml 'Status' $script:Report.Security.WinRM.Status)$(New-BravoInfoRowHtml 'Service' $script:Report.Security.WinRM.ServiceStatus)$(New-BravoInfoRowHtml 'Basic auth' $(if($null -eq $script:Report.Security.WinRM.Auth.Basic){'N/A'}elseif($script:Report.Security.WinRM.Auth.Basic){'Увімкнено'}else{'Вимкнено'}))$(New-BravoInfoRowHtml 'CredSSP' $(if($null -eq $script:Report.Security.WinRM.Auth.CredSSP){'N/A'}elseif($script:Report.Security.WinRM.Auth.CredSSP){'Увімкнено'}else{'Вимкнено'}))$(New-BravoInfoRowHtml 'Listeners' $script:Report.Security.WinRM.Listeners.Count)</div><div class="card"><h3>SMB signing</h3>$(New-BravoInfoRowHtml 'Status' $script:Report.Security.SMB.Status)$(New-BravoInfoRowHtml 'Server signing required' $(if($null -eq $script:Report.Security.SMB.ServerSigningRequired){'N/A'}elseif($script:Report.Security.SMB.ServerSigningRequired){'Так'}else{'Ні'}))$(New-BravoInfoRowHtml 'Insecure guest logons' $(if($null -eq $script:Report.Security.SMB.InsecureGuestLogonsEnabled){'N/A'}elseif($script:Report.Security.SMB.InsecureGuestLogonsEnabled){'Увімкнено'}else{'Вимкнено'}))</div><div class="card"><h3>Password Policy</h3>$(New-BravoInfoRowHtml 'Min password length' $script:Report.Security.PasswordPolicy.MinPasswordLength)$(New-BravoInfoRowHtml 'Max password age, днів' $script:Report.Security.PasswordPolicy.MaxPasswordAgeDays)$(New-BravoInfoRowHtml 'Password history length' $script:Report.Security.PasswordPolicy.PasswordHistoryLength)$(New-BravoInfoRowHtml 'Lockout threshold' $script:Report.Security.PasswordPolicy.LockoutThreshold)$(New-BravoInfoRowHtml 'Lockout duration, хв' $script:Report.Security.PasswordPolicy.LockoutDurationMinutes)</div></div><h3>TLS registry status</h3>$(New-BravoTableToolbarHtml -TableId 'table-tls' -Placeholder 'Пошук по протоколах TLS...')<div class="table-scroll"><table id="table-tls" class="data-table"><thead><tr><th>Protocol</th><th>Side</th><th>Status</th></tr></thead><tbody>$tlsRows</tbody></table></div><h3>Audit Policy</h3>$(New-BravoTableToolbarHtml -TableId 'table-audit-policy' -Placeholder 'Пошук по категоріях audit policy...')<div class="table-scroll"><table id="table-audit-policy" class="data-table"><thead><tr><th>Category</th><th>Subcategory</th><th>Inclusion Setting</th></tr></thead><tbody>$auditPolicyRows</tbody></table></div><h3>Autoruns</h3>$(New-BravoTableToolbarHtml -TableId 'table-autoruns' -Placeholder 'Пошук по autorun-записах...')<div class="table-scroll"><table id="table-autoruns" class="data-table"><thead><tr><th>Name</th><th>Command</th><th>Source</th><th>Hive</th></tr></thead><tbody>$autorunRows</tbody></table></div><h3>Scheduled Tasks (не-Microsoft, $scheduledTaskMicrosoftCount вбудованих Microsoft-задач приховано)</h3>$(New-BravoTableToolbarHtml -TableId 'table-scheduledtasks' -Placeholder 'Пошук по задачах...')<div class="table-scroll"><table id="table-scheduledtasks" class="data-table"><thead><tr><th>Name</th><th>Path</th><th>State</th><th>Author</th><th>Execute</th></tr></thead><tbody>$scheduledTaskRows</tbody></table></div></section>
    <section id="tab-services" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">⚙️</span>Services</h2><div class="grid"><div class="card"><h3>Service summary</h3>$(New-BravoInfoRowHtml 'Processes' $script:Report.Processes.Total)$(New-BravoInfoRowHtml 'Services running' "$($script:Report.Services.Running)/$($script:Report.Services.Total)")$(New-BravoInfoRowHtml 'Automatic stopped' $script:Report.Services.AutomaticStopped.Count)$(New-BravoInfoRowHtml "System errors ($EventLogDays дн.)" $script:Report.EventLogs.SystemErrors)$(New-BravoInfoRowHtml "System warnings ($EventLogDays дн.)" $script:Report.EventLogs.SystemWarnings)</div></div><h3>Automatic stopped services</h3>$(New-BravoTableToolbarHtml -TableId 'table-services-stopped' -Placeholder 'Пошук по службах...')<div class="table-scroll"><table id="table-services-stopped" class="data-table"><thead><tr><th>Name</th><th>DisplayName</th><th>StartType</th><th>Status</th></tr></thead><tbody>$serviceRows</tbody></table></div><h3>Топ джерел помилок System log ($EventLogDays дн.)</h3>$(New-BravoTableToolbarHtml -TableId 'table-events-top-sources' -Placeholder 'Пошук по джерелах помилок...')<div class="table-scroll"><table id="table-events-top-sources" class="data-table"><thead><tr><th>Source</th><th>Count</th><th>Останнє повідомлення</th></tr></thead><tbody>$eventTopErrorRows</tbody></table></div><h3>Event Logs: System / Application / Setup / Security ($EventLogDays дн.)</h3>$(New-BravoTableToolbarHtml -TableId 'table-events-logsummary' -Placeholder 'Пошук по журналах...')<div class="table-scroll"><table id="table-events-logsummary" class="data-table"><thead><tr><th>Log</th><th>Status</th><th>Critical</th><th>Error</th><th>Warning</th></tr></thead><tbody>$eventLogSummaryRows</tbody></table></div><h3>Provider Summary (Critical/Error/Warning)</h3>$(New-BravoTableToolbarHtml -TableId 'table-events-providers' -Placeholder 'Пошук по провайдерах...')<div class="table-scroll"><table id="table-events-providers" class="data-table"><thead><tr><th>Log</th><th>Provider</th><th>Count</th><th>Останнє повідомлення</th></tr></thead><tbody>$eventLogProviderRows</tbody></table></div><h3>Hardware Diagnostics (Disk/Ntfs/StorPort/StorNVMe/WHEA/Kernel-Power/BugCheck)</h3>$(New-BravoTableToolbarHtml -TableId 'table-events-hwdiag' -Placeholder 'Пошук по провайдерах...')<div class="table-scroll"><table id="table-events-hwdiag" class="data-table"><thead><tr><th>Provider</th><th>Status</th><th>Count</th><th>Останнє повідомлення</th></tr></thead><tbody>$hardwareDiagnosticRows</tbody></table></div></section>
    <section id="tab-software" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">📦</span>Software</h2><div class="grid"><div class="card"><h3>Software summary</h3>$(New-BravoInfoRowHtml 'Installed software' $script:Report.Software.Installed.Count)$(New-BravoInfoRowHtml 'Profile' $Profile)</div></div><h3>Installed software</h3>$(New-BravoTableToolbarHtml -TableId 'table-software-installed' -Placeholder 'Пошук по назві, версії або видавцю...')<div class="table-scroll"><table id="table-software-installed" class="data-table"><thead><tr><th>Name</th><th>Version</th><th>Publisher</th><th>Install date</th></tr></thead><tbody>$softwareRows</tbody></table></div></section>
    <section id="tab-updates" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">🔄</span>Updates</h2><div class="grid"><div class="card"><h3>Життєвий цикл ОС</h3>$(New-BravoInfoRowHtml 'Продукт' $script:Report.Updates.OS.Product)$(New-BravoInfoRowHtml 'Версія' $script:Report.Updates.OS.DisplayVersion)$(New-BravoInfoRowHtml 'Версія з реєстру' $script:Report.Updates.OS.RegistryDisplayVersion)$(New-BravoInfoRowHtml 'Full build' $script:Report.Updates.OS.FullBuild)$(New-BravoInfoRowHtml 'Канал' $script:Report.Updates.OS.Channel)$(New-BravoInfoRowHtml 'EditionID' $script:Report.Updates.OS.EditionId)$(New-BravoInfoRowHtml 'Кінець підтримки' $script:Report.Updates.OS.SupportEndDate)$(New-BravoInfoRowHtml 'Днів до кінця підтримки' $script:Report.Updates.OS.DaysToEndOfSupport)<div class="info-row"><span class="info-label">Статус підтримки</span><span class="info-value"><span class="status-pill $updatesSupportStatusClass">$(ConvertTo-BravoHtmlText $updatesSupportStatusText)</span></span></div>$(New-BravoInfoRowHtml 'Дані lifecycle від' $script:Report.Updates.OS.LifecycleDataUpdatedAt)</div><div class="card"><h3>Windows Update</h3>$(New-BravoInfoRowHtml 'Служба wuauserv' $script:Report.Updates.WindowsUpdate.ServiceStatus)$(New-BravoInfoRowHtml 'Тип запуску' $script:Report.Updates.WindowsUpdate.ServiceStartType)$(New-BravoInfoRowHtml 'Політика оновлень' $script:Report.Updates.WindowsUpdate.AutoUpdateOption)$(New-BravoInfoRowHtml 'WSUS' $(if($script:Report.Updates.WindowsUpdate.ManagedByWSUS){$script:Report.Updates.WindowsUpdate.WSUSServer}else{'Ні'}))$(New-BravoInfoRowHtml 'Останній пошук' $script:Report.Updates.WindowsUpdate.LastDetectSuccess)$(New-BravoInfoRowHtml 'Остання установка' $script:Report.Updates.WindowsUpdate.LastInstallSuccess)$(New-BravoInfoRowHtml 'Потрібне перезавантаження' $pendingRebootText)$(New-BravoInfoRowHtml 'Статус пошуку' $updatesSearchStatusText)$(New-BravoInfoRowHtml 'Тривалість пошуку, сек' $script:Report.Updates.Search.DurationSeconds)</div></div><div class="storage-summary-grid"><div class="storage-summary-item"><div class="storage-summary-label">Потрібно встановити</div><div class="storage-summary-value">$($script:Report.Updates.Pending.Total)$(if($script:Report.Updates.Pending.IsTruncated){" <span class=`"risk risk-warning`">детально: $($script:Report.Updates.Pending.Detailed)</span>"})</div></div><div class="storage-summary-item"><div class="storage-summary-label">Security</div><div class="storage-summary-value"><span class="risk risk-critical">$($script:Report.Updates.Pending.Security)</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">Драйвери</div><div class="storage-summary-value"><span class="risk risk-warning">$($script:Report.Updates.Pending.Driver)</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">Завантажено</div><div class="storage-summary-value"><span class="risk risk-ok">$($script:Report.Updates.Pending.Downloaded)</span></div></div><div class="storage-summary-item"><div class="storage-summary-label">Обсяг, MB</div><div class="storage-summary-value">$($script:Report.Updates.Pending.TotalSizeMB)</div></div><div class="storage-summary-item"><div class="storage-summary-label">Встановлено оновлень</div><div class="storage-summary-value">$($script:Report.Updates.Installed.Total)</div></div></div><h3>Оновлення, які потрібно встановити</h3>$(New-BravoTableToolbarHtml -TableId 'table-updates-pending' -Placeholder 'Пошук по назві, KB, категорії...')<div class="table-scroll"><table id="table-updates-pending" class="data-table"><thead><tr><th>Title</th><th>KB</th><th>Categories</th><th>Severity</th><th>Size MB</th><th>Downloaded</th><th>Released</th></tr></thead><tbody>$pendingUpdatesRows</tbody></table></div><h3>Останні встановлені оновлення</h3>$(New-BravoTableToolbarHtml -TableId 'table-updates-installed' -Placeholder 'Пошук по KB, опису, користувачу...')<div class="table-scroll"><table id="table-updates-installed" class="data-table"><thead><tr><th>HotFixID</th><th>Description</th><th>Installed by</th><th>Installed on</th></tr></thead><tbody>$installedUpdatesRows</tbody></table></div></section>
    <section id="tab-findings" class="tab-panel"><h2 class="tab-panel-title"><span class="section-icon">🔎</span>Findings</h2>$(New-BravoTableToolbarHtml -TableId 'table-findings' -Placeholder 'Пошук по severity, category, message...')<div class="table-scroll"><table id="table-findings" class="data-table"><thead><tr><th>Severity</th><th>Category</th><th>Message</th><th>Recommendation</th></tr></thead><tbody>$findingsRows</tbody></table></div><h2 class="tab-panel-title"><span class="section-icon">🛠️</span>Помилки збору даних</h2>$(New-BravoTableToolbarHtml -TableId 'table-collection-errors' -Placeholder 'Пошук по помилках збору...')<div class="table-scroll"><table id="table-collection-errors" class="data-table"><thead><tr><th>Time</th><th>Section</th><th>Message</th></tr></thead><tbody>$errorsRows</tbody></table></div></section>
  </main>
  <footer class="footer"><p>BRAVO SYSTEM REPORT v$ScriptVersion | $(ConvertTo-BravoHtmlText $OutputDir)</p></footer>
</div>
<script>
(function(){
  function getPanels(){ return Array.prototype.slice.call(document.querySelectorAll('.tab-panel')); }
  function getButtons(){ return Array.prototype.slice.call(document.querySelectorAll('.tab-button')); }
  function normalizeText(value){ return (value || '').toString().toLowerCase(); }
  function updateTableCounter(tableId, visibleRows, totalRows){
    var counter = document.querySelector('[data-table-counter="' + tableId + '"]');
    if(counter){ counter.textContent = 'Рядків: ' + visibleRows + ' / ' + totalRows; }
  }
  function filterTable(tableId, query){
    var table = document.getElementById(tableId);
    if(!table || !table.tBodies || table.tBodies.length === 0){ return; }
    var rows = Array.prototype.slice.call(table.tBodies[0].rows);
    var searchText = normalizeText(query).trim();
    var visibleRows = 0;
    rows.forEach(function(row){
      var rowText = normalizeText(row.innerText || row.textContent);
      var isVisible = searchText === '' || rowText.indexOf(searchText) !== -1;
      row.classList.toggle('row-hidden', !isVisible);
      if(isVisible){ visibleRows++; }
    });
    updateTableCounter(tableId, visibleRows, rows.length);
  }
  function initializeTableFilters(){
    var filters = Array.prototype.slice.call(document.querySelectorAll('[data-table-filter]'));
    filters.forEach(function(input){
      var tableId = input.getAttribute('data-table-filter');
      filterTable(tableId, input.value);
      input.addEventListener('input', function(){ filterTable(tableId, input.value); });
    });
  }
  window.openTab = function(event, tabId){
    if(event && event.preventDefault){ event.preventDefault(); }
    var selectedPanel = document.getElementById(tabId);
    if(!selectedPanel){ return false; }
    getPanels().forEach(function(panel){ panel.classList.remove('active'); panel.style.display = 'none'; });
    getButtons().forEach(function(button){ button.classList.remove('active'); button.setAttribute('aria-selected', 'false'); });
    selectedPanel.classList.add('active');
    selectedPanel.style.display = 'block';
    var activeButton = event && event.currentTarget ? event.currentTarget : document.querySelector('.tab-button[data-tab-target="' + tabId + '"]');
    if(activeButton){ activeButton.classList.add('active'); activeButton.setAttribute('aria-selected', 'true'); }
    if(window.history && window.history.replaceState){ window.history.replaceState(null, '', '#' + tabId); }
    return false;
  };
  function activateInitialTab(){
    var requestedTab = window.location.hash ? window.location.hash.substring(1) : 'tab-general';
    if(!document.getElementById(requestedTab)){ requestedTab = 'tab-general'; }
    var button = document.querySelector('.tab-button[data-tab-target="' + requestedTab + '"]');
    window.openTab({ preventDefault:function(){}, currentTarget:button }, requestedTab);
  }
  // Dark mode: :root[data-theme] override CSS-змінних, дефолт — prefers-color-scheme
  // (system-рівень, без явного вибору). Вибір користувача зберігається через
  // localStorage — на file:// протоколі деякі браузери обмежують доступ до
  // localStorage (throws SecurityError), тому обгорнуто в try/catch: тема все
  // одно перемикається в межах поточної сесії перегляду, лише не зберігається
  // між відкриттями файлу.
  function getStoredTheme(){
    try { return window.localStorage.getItem('bravo-theme'); } catch(e) { return null; }
  }
  function setStoredTheme(value){
    try { window.localStorage.setItem('bravo-theme', value); } catch(e) { /* file:// або приватний режим — не критично */ }
  }
  function updateThemeToggleIcon(theme){
    var toggleButton = document.getElementById('theme-toggle');
    if(!toggleButton){ return; }
    var isDark = theme === 'dark' || (!theme && window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches);
    toggleButton.textContent = isDark ? '☀️' : '🌙';
  }
  function applyTheme(theme){
    if(theme === 'dark' || theme === 'light'){
      document.documentElement.setAttribute('data-theme', theme);
    } else {
      document.documentElement.removeAttribute('data-theme');
    }
    updateThemeToggleIcon(theme);
  }
  window.toggleTheme = function(){
    var current = document.documentElement.getAttribute('data-theme');
    var systemPrefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
    var currentlyDark = current === 'dark' || (!current && systemPrefersDark);
    var next = currentlyDark ? 'light' : 'dark';
    applyTheme(next);
    setStoredTheme(next);
  };
  function initTheme(){
    applyTheme(getStoredTheme());
  }
  if(document.readyState === 'loading'){
    document.addEventListener('DOMContentLoaded', function(){ initializeTableFilters(); activateInitialTab(); initTheme(); });
  } else {
    initializeTableFilters();
    activateInitialTab();
    initTheme();
  }
})();
</script>
</body>
</html>
"@

            $htmlContent | Out-File $htmlPath -Encoding utf8
            $script:Report.GeneratedFiles += $htmlPath
            Write-Host "  $IconHtml HTML: $BaseFileName.html" -ForegroundColor Green
        } catch {
            Add-ExportError -Section 'Export.Html' -Message $_.Exception.Message
            Write-Host "  $IconError Помилка HTML: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Чиста-по-суті функція локалізації msedge.exe: спершу PATH (Get-Command),
# потім два стандартних шляхи встановлення (64-bit і 32-bit under
# Program Files (x86) — Edge типово встановлюється як 32-bit застосунок
# навіть на 64-bit Windows). Повертає $null, якщо Edge не знайдено —
# виклик далі трактує це як штатну відсутність опційної залежності, не
# помилку.
function Get-BravoEdgeExecutablePath {
    [CmdletBinding()]
    param()

    $pathCommand = Get-Command msedge.exe -ErrorAction SilentlyContinue
    $candidates = @(
        if ($pathCommand) { $pathCommand.Source }
        'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
        'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }

    return $null
}

# v0.6.1 Advanced UX: автоматична конвертація HTML-звіту в PDF через
# headless Microsoft Edge (`--print-to-pdf`). Опційна фіча (-ExportPdf) —
# відсутність Edge на машині НЕ є помилкою збору чи експорту (лише
# Write-Host Warning), оскільки PDF не є обов'язковим форматом звіту.
function Export-BravoPdfReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputDir,
        [Parameter(Mandatory = $true)]
        [string]$BaseFileName
    )

    $htmlPath = Join-Path $OutputDir "$BaseFileName.html"
    if (-not (Test-Path -LiteralPath $htmlPath)) {
        # Нема з чого конвертувати (HTML не створено/помилка HTML-етапу) —
        # той HTML-етап уже зафіксував власну ExportError, тут дублювати
        # не потрібно.
        return
    }

    $edgePath = Get-BravoEdgeExecutablePath
    if (-not $edgePath) {
        Write-Host "  [INFO] Edge CLI PDF: msedge.exe не знайдено на цій машині — PDF пропущено (не помилка, опційна фіча)." -ForegroundColor Yellow
        return
    }

    try {
        $pdfPath = Join-Path $OutputDir "$BaseFileName.pdf"
        $htmlUri = ([Uri]$htmlPath).AbsoluteUri
        $edgeArguments = @(
            '--headless'
            '--disable-gpu'
            "--print-to-pdf=`"$pdfPath`""
            '--print-to-pdf-no-header'
            $htmlUri
        )

        $process = Start-Process -FilePath $edgePath -ArgumentList $edgeArguments -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop

        if ($process.ExitCode -eq 0 -and (Test-Path -LiteralPath $pdfPath)) {
            $script:Report.GeneratedFiles += $pdfPath
            Write-Host "  $IconHtml PDF: $BaseFileName.pdf" -ForegroundColor White
        } else {
            Add-ExportError -Section 'Export.Pdf' -Message "msedge.exe --print-to-pdf завершився з exit code $($process.ExitCode), PDF-файл не з'явився."
        }
    } catch {
        Add-ExportError -Section 'Export.Pdf' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка PDF: $($_.Exception.Message)" -ForegroundColor Red
    }
}


# ============================================================
# MODULE: src/52-Export-Csv.ps1
# ============================================================

# MODULE: 52-Export-Csv.ps1
# Експорт BRAVO SYSTEM REPORT у CSV.

function Export-BravoCsvReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputDir,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseFileName,

        [Parameter(Mandatory = $true)]
        [bool]$CSV
    )

    # CSV
    if ($CSV) {
        try {
            $csvPath = Join-Path $OutputDir "$BaseFileName.csv"
            $csvData = @(
                [PSCustomObject]@{Parameter='ComputerName'; Value=$script:Report.ComputerName}
                [PSCustomObject]@{Parameter='Timestamp'; Value=$script:Report.Timestamp}
                [PSCustomObject]@{Parameter='Profile'; Value=$script:Report.Profile}
                [PSCustomObject]@{Parameter='HealthScore'; Value=$script:Report.Health.Score}
                [PSCustomObject]@{Parameter='HealthStatus'; Value=$script:Report.Health.Status}
                [PSCustomObject]@{Parameter='OS'; Value=$script:Report.OS.Caption}
                [PSCustomObject]@{Parameter='OSBuild'; Value=$script:Report.OS.Build}
                [PSCustomObject]@{Parameter='UptimeDays'; Value=$script:Report.OS.UptimeDays}
                [PSCustomObject]@{Parameter='CPU_Cores'; Value=$script:Report.Hardware.CPU.Cores}
                [PSCustomObject]@{Parameter='CPU_LogicalProcessors'; Value=$script:Report.Hardware.CPU.LogicalProcessors}
                [PSCustomObject]@{Parameter='CPU_Load'; Value=$script:Report.Hardware.CPU.LoadPercent}
                [PSCustomObject]@{Parameter='RAM_GB'; Value=$script:Report.Hardware.RAM.TotalGB}
                [PSCustomObject]@{Parameter='RAM_Used_Percent'; Value=$script:Report.Hardware.RAM.UsedPercent}
                [PSCustomObject]@{Parameter='Disk_Free_Percent'; Value=$script:Report.Hardware.Disks.FreePercent}
                [PSCustomObject]@{Parameter='IPv4'; Value=($script:Report.Network.IP.IPv4 -join '; ')}
                [PSCustomObject]@{Parameter='RDP_Enabled'; Value=$script:Report.Security.RemoteAccess.RDPEnabled}
                [PSCustomObject]@{Parameter='UAC_Enabled'; Value=$script:Report.Security.UAC.Enabled}
                [PSCustomObject]@{Parameter='SecureBoot_Status'; Value=$script:Report.Security.SecureBoot.Status}
                [PSCustomObject]@{Parameter='TPM_Status'; Value=$script:Report.Security.TPM.Status}
                [PSCustomObject]@{Parameter='Processes'; Value=$script:Report.Processes.Total}
                [PSCustomObject]@{Parameter='Running_Services'; Value=$script:Report.Services.Running}
                [PSCustomObject]@{Parameter='AutomaticStoppedServices'; Value=$script:Report.Services.AutomaticStopped.Count}
                [PSCustomObject]@{Parameter='Errors_24h'; Value=$script:Report.EventLogs.SystemErrors24h}
                [PSCustomObject]@{Parameter='Errors_ProfileDays'; Value=$script:Report.EventLogs.SystemErrors}
                [PSCustomObject]@{Parameter='Installed_Software'; Value=$script:Report.Software.Installed.Count}
                [PSCustomObject]@{Parameter='OS_SupportStatus'; Value=$script:Report.Updates.OS.SupportStatus}
                [PSCustomObject]@{Parameter='OS_SupportEndDate'; Value=$script:Report.Updates.OS.SupportEndDate}
                [PSCustomObject]@{Parameter='Updates_SearchStatus'; Value=$script:Report.Updates.Search.Status}
                [PSCustomObject]@{Parameter='Updates_Pending'; Value=$script:Report.Updates.Pending.Total}
                [PSCustomObject]@{Parameter='Updates_Pending_Security'; Value=$script:Report.Updates.Pending.Security}
                [PSCustomObject]@{Parameter='Updates_PendingReboot'; Value=$script:Report.Updates.PendingReboot.Required}
                [PSCustomObject]@{Parameter='Updates_LastInstalledOn'; Value=$script:Report.Updates.Installed.LastInstalledOn}
                [PSCustomObject]@{Parameter='Updates_DaysSinceLastUpdate'; Value=$script:Report.Updates.Installed.DaysSinceLastUpdate}
                [PSCustomObject]@{Parameter='Local_Admins'; Value=$script:Report.Users.LocalAdmins.Count}
                [PSCustomObject]@{Parameter='Findings'; Value=$script:Report.Health.Findings.Count}
                [PSCustomObject]@{Parameter='CollectionErrors'; Value=$script:Report.CollectionErrors.Count}
            )

            $csvData | Export-Csv $csvPath -NoTypeInformation -Encoding utf8
            $script:Report.GeneratedFiles += $csvPath
            Write-Host "  $IconCsv CSV: $BaseFileName.csv" -ForegroundColor Green
        } catch {
            Add-ExportError -Section 'Export.Csv' -Message $_.Exception.Message
            Write-Host "  $IconError Помилка CSV: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}


# ============================================================
# MODULE: src/53-Export-Zip.ps1
# ============================================================

# MODULE: 53-Export-Zip.ps1
# Експорт BRAVO SYSTEM REPORT у ZIP.

function Import-BravoZipAssemblies {
    [CmdletBinding()]
    param()

    $assemblies = @(
        'System.IO.Compression',
        'System.IO.Compression.FileSystem'
    )

    foreach ($assemblyName in $assemblies) {
        try {
            Add-Type -AssemblyName $assemblyName -ErrorAction Stop
        } catch {
            throw "Не вдалося завантажити .NET assembly $assemblyName`: $($_.Exception.Message)"
        }
    }

    $requiredTypes = @(
        'System.IO.Compression.ZipArchive',
        'System.IO.Compression.ZipArchiveMode',
        'System.IO.Compression.ZipFileExtensions'
    )

    foreach ($typeName in $requiredTypes) {
        if (-not ($typeName -as [type])) {
            throw "Не знайдено .NET тип $typeName після завантаження System.IO.Compression assemblies. Перевірте версію .NET Framework."
        }
    }
}

function Export-BravoZipReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputDir,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseFileName,

        [Parameter(Mandatory = $true)]
        [bool]$Zip
    )

    # ZIP
    if ($Zip) {
        $zipArchive = $null
        $zipStream = $null

        try {
            Import-BravoZipAssemblies

            $zipPath = Join-Path $OutputDir "$BaseFileName.zip"

            if (Test-Path -LiteralPath $zipPath) {
                Remove-Item -LiteralPath $zipPath -Force
            }

            $zipStream = New-Object System.IO.FileStream($zipPath, [System.IO.FileMode]::Create)
            $zipArchive = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)

            foreach ($file in $script:Report.GeneratedFiles) {
                if (Test-Path -LiteralPath $file) {
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                        $zipArchive,
                        $file,
                        (Split-Path $file -Leaf),
                        [System.IO.Compression.CompressionLevel]::Optimal
                    ) | Out-Null
                }
            }

            $script:Report.GeneratedFiles += $zipPath
            Write-Host "  $IconZip ZIP: $BaseFileName.zip" -ForegroundColor Green
        } catch {
            Add-ExportError -Section 'Export.Zip' -Message $_.Exception.Message
            Write-Host "  $IconError Помилка створення ZIP: $($_.Exception.Message)" -ForegroundColor Red
        } finally {
            if ($null -ne $zipArchive) { $zipArchive.Dispose() }
            if ($null -ne $zipStream) { $zipStream.Dispose() }
        }
    }
}


# ============================================================
# MODULE: src/54-Export-Email.ps1
# ============================================================

# MODULE: 54-Export-Email.ps1
# Відправка BRAVO SYSTEM REPORT електронною поштою.

function Send-BravoEmailReport {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$EmailTo,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$EmailFrom,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$SmtpServer
    )

    # Email
    if ($EmailTo) {
        try {
            $smtpToUse = if ($SmtpServer) { $SmtpServer } else { "smtp.$($env:USERDNSDOMAIN.ToLower())" }
            $mailBody = "BRAVO SYSTEM REPORT - $($script:Report.ComputerName)`n`nOS: $($script:Report.OS.Caption)`nHealth: $($script:Report.Health.Score)/100 ($($script:Report.Health.Status))`nCPU: $($script:Report.Hardware.CPU.LoadPercent)%`nRAM: $($script:Report.Hardware.RAM.TotalGB) GB ($($script:Report.Hardware.RAM.UsedPercent)%)`nDisk Free: $($script:Report.Hardware.Disks.FreePercent)%`nUptime: $($script:Report.OS.UptimeDays) days"
            $attachments = @($script:Report.GeneratedFiles | Where-Object { $_ -and (Test-Path -LiteralPath $_) -and ($_ -notlike '*.zip') })

            Send-MailMessage -To $EmailTo -From $EmailFrom -Subject "BRAVO SYSTEM REPORT - $($script:Report.ComputerName)" -Body $mailBody -SmtpServer $smtpToUse -Attachments $attachments -ErrorAction Stop
            Write-Host "  $IconEmail Email відправлено на $EmailTo" -ForegroundColor Green
        } catch {
            Add-ExportError -Section 'Export.Email' -Message $_.Exception.Message
            Write-Host "  $IconError Помилка відправки Email: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}


# ============================================================
# MODULE: src/90-Main.ps1
# ============================================================

# MODULE: 90-Main.ps1
# Основний execution flow BRAVO SYSTEM REPORT.
# Param-блок винесено у src\05-Params.ps1.
# Helper-функції винесено у src\10-Core.ps1.

<#
.SYNOPSIS
    BRAVO SYSTEM REPORT — детальний аудит Windows-машини.
.DESCRIPTION
    Збирає базову інформацію про ОС, апаратне забезпечення, диски, мережу,
    безпеку, користувачів, процеси, служби, події та встановлене ПЗ.

    Версія 0.2.0 стабілізує початковий скрипт:
    - додає профілі аудиту;
    - додає OutputPath, NoOpenFolder, NoPause;
    - виправляє конфлікти змінних іконок з об'єктами CPU/дисків;
    - додає CollectionErrors та Findings;
    - виправляє обчислення часу виконання;
    - прибирає порожні catch-блоки.
.NOTES
    Рекомендована версія: Windows PowerShell 5.1+.
    Для частини даних потрібні права адміністратора.
#>
$ErrorActionPreference = 'Continue'
$ScriptStartTime = Get-Date
$ScriptVersion = "0.5.1"

function Show-Pause {
    param([string]$Message = 'Натисніть будь-яку клавішу для виходу...')

    Write-Host $Message -ForegroundColor Gray
    try {
        if ($Host.Name -eq 'ConsoleHost') {
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
    } catch {}

    try { Read-Host | Out-Null; return } catch {}
    try {
        Write-Host 'Автоматичне закриття через 10 секунд...' -ForegroundColor Gray
        Start-Sleep -Seconds 10
    } catch {}
}

function Get-ScriptDirectory {
    if ($PSScriptRoot -and (Test-Path -LiteralPath $PSScriptRoot)) { return $PSScriptRoot }
    if ($MyInvocation.MyCommand.Path) { return Split-Path -Parent $MyInvocation.MyCommand.Path }
    return (Get-Location).Path
}

function Format-Size {
    param([double]$GB)

    if ($null -eq $GB) { return '0 GB' }
    if ($GB -gt 1024) { return "$([Math]::Round($GB / 1024, 2)) TB" }
    return "$([Math]::Round($GB, 2)) GB"
}

function Convert-AuditDateTime {
    param(
        [Parameter(Mandatory = $false)]$Value,
        [bool]$UseCim = $false
    )

    if (-not $Value) { return $null }

    try {
        if ($UseCim -or $Value -is [datetime]) { return [datetime]$Value }
        return [Management.ManagementDateTimeConverter]::ToDateTime($Value)
    } catch {
        return $null
    }
}

function Add-AuditError {
    param(
        [string]$Section,
        [string]$Message
    )

    if (-not $script:Report) { return }

    $script:Report.CollectionErrors += [PSCustomObject]@{
        Time    = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Section = $Section
        Message = $Message
    }
}

function Add-ExportError {
    # На відміну від Add-AuditError (помилки ЗБОРУ даних, впливають на Health
    # Score), ExportErrors — помилки ЗАПИСУ звітів (JSON/HTML/CSV/ZIP/Email):
    # проблема самого інструмента, а не аудитованої машини. Не впливає на
    # Health Score, але впливає на exit code (P0.5).
    param(
        [string]$Section,
        [string]$Message
    )

    if (-not $script:Report) { return }

    $script:Report.ExportErrors += [PSCustomObject]@{
        Time    = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Section = $Section
        Message = $Message
    }
}

function Add-AuditFinding {
    param(
        [ValidateSet('INFO','WARNING','CRITICAL')]
        [string]$Severity,
        [string]$Category,
        [string]$Message,
        [string]$Recommendation = ''
    )

    if (-not $script:Report) { return }

    $script:Report.Health.Findings += [PSCustomObject]@{
        Severity       = $Severity
        Category       = $Category
        Message        = $Message
        Recommendation = $Recommendation
    }
}

function Get-AuditObject {
    param(
        [string]$ClassName,
        [string]$Filter = '',
        [switch]$First
    )

    if ($script:UseCim) {
        if ($Filter) { $result = Get-CimInstance -ClassName $ClassName -Filter $Filter -ErrorAction Stop }
        else { $result = Get-CimInstance -ClassName $ClassName -ErrorAction Stop }
    } else {
        if ($Filter) { $result = Get-WmiObject -Class $ClassName -Filter $Filter -ErrorAction Stop }
        else { $result = Get-WmiObject -Class $ClassName -ErrorAction Stop }
    }

    if ($First) { return $result | Select-Object -First 1 }
    return $result
}



function Resolve-AuditOutputPath {
    param(
        [string]$RequestedPath,
        [string]$DefaultPath
    )

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) { $RequestedPath = $DefaultPath }

    if (-not [System.IO.Path]::IsPathRooted($RequestedPath)) {
        $RequestedPath = Join-Path $DefaultPath $RequestedPath
    }

    if (-not (Test-Path -LiteralPath $RequestedPath)) {
        New-Item -ItemType Directory -Path $RequestedPath -Force | Out-Null
    }

    return (Resolve-Path -LiteralPath $RequestedPath).Path
}

# Фатальний fallback (P0.5): будь-яка термінуюча помилка, що вислизнула з
# усіх внутрішніх try/catch колекторів/export-функцій нижче (тобто справжній
# баг чи неочікуваний runtime-збій, а не штатна помилка збору/експорту),
# ловиться тут і завершує процес з exit code 2 — "fatal init/runtime error",
# на відміну від 1 (штатні CollectionErrors/ExportErrors, аудит все одно
# завершився й дав результат).
trap {
    Write-Host ''
    Write-Host "[FATAL] Неопрацьована помилка виконання: $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}

try { Clear-Host } catch {}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$PSMajorVersion = $PSVersionTable.PSVersion.Major
$OSVersion = [Environment]::OSVersion.Version
$IsWin8OrHigher = ($OSVersion.Major -ge 6 -and $OSVersion.Minor -ge 2) -or ($OSVersion.Major -ge 10)
$HaveCim = (Get-Command -Name Get-CimInstance -ErrorAction SilentlyContinue) -ne $null
$script:UseCim = $HaveCim -and $IsWin8OrHigher

if ($EventLogDays -le 0) {
    $EventLogDays = switch ($Profile) {
        'Quick'    { 1 }
        'Full'     { 3 }
        'Deep'     { 7 }
        'Forensic' { 14 }
        default    { 3 }
    }
}

# -NoZip явно вимикає ZIP (переопределяє default=$true у -Zip). Див. коментар
# нижче біля forwarding у $arguments — CLI не підтримує -Zip:$false напряму.
if ($NoZip) { $Zip = $false }

$ScriptDirectory = Get-ScriptDirectory

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and -not $NoElevate -and -not $SkipElevation) {
    Write-Host '[INFO] Потрібні права адміністратора. Запит підвищення прав...' -ForegroundColor Yellow
    $scriptFullPath = $MyInvocation.MyCommand.Path
    if (-not $scriptFullPath) { $scriptFullPath = $PSCommandPath }

    if ($scriptFullPath -and (Test-Path -LiteralPath $scriptFullPath)) {
        $arguments = @('-SkipElevation')
        $arguments += "-Profile $Profile"
        $arguments += "-EventLogDays $EventLogDays"
        if ($OutputPath) { $arguments += "-OutputPath `"$OutputPath`"" }
        if ($JSONOnly) { $arguments += '-JSONOnly' }
        if ($CSV) { $arguments += '-CSV' }
        # $Zip не форвардиться напряму: powershell.exe -File не підтримує
        # синтаксис -Zip:$false для switch-параметрів з рядка команди (це
        # PowerShell-мовна конструкція, а не CLI-конвенція — перевірено
        # емпірично, дає ParameterArgumentTransformationError). Тому вимкнення
        # ZIP форвардиться через окремий default-false switch -NoZip, за тим
        # самим патерном, що й -NoPause/-NoEmoji/-NoOpenFolder нижче.
        # Перевіряємо ЕФЕКТИВНЕ значення $Zip (уже враховує і -NoZip, і
        # прямий -Zip:$false — обидва застосовані вище, до elevation-блоку),
        # а не сам прапорець -NoZip, — інакше користувач, що викликав
        # -Zip:$false напряму (старий, задокументований в CHANGELOG спосіб),
        # так само втратить вимкнення ZIP при relaunch під адміном.
        if (-not $Zip) { $arguments += '-NoZip' }
        if ($NoEmoji) { $arguments += '-NoEmoji' }
        if ($NoPause) { $arguments += '-NoPause' }
        if ($NoOpenFolder) { $arguments += '-NoOpenFolder' }
        if ($SkipPublicIP) { $arguments += '-SkipPublicIP' }
        if ($SkipGeoIP) { $arguments += '-SkipGeoIP' }
        if ($Offline) { $arguments += '-Offline' }
        if ($Strict) { $arguments += '-Strict' }
        if ($Sanitize) { $arguments += '-Sanitize' }
        $arguments += "-SanitizeLevel $SanitizeLevel"
        if ($SkipUpdateSearch) { $arguments += '-SkipUpdateSearch' }
        $arguments += "-UpdateSearchTimeoutSec $UpdateSearchTimeoutSec"
        if ($EmailTo) { $arguments += "-EmailTo `"$EmailTo`"" }
        if ($EmailFrom) { $arguments += "-EmailFrom `"$EmailFrom`"" }
        if ($SmtpServer) { $arguments += "-SmtpServer `"$SmtpServer`"" }
        if ($ExportPdf) { $arguments += '-ExportPdf' }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`" $($arguments -join ' ')"
        $psi.Verb = 'runas'
        $psi.WorkingDirectory = $ScriptDirectory

        try {
            # Чекаємо завершення елевованого процесу і прокидаємо його реальний
            # exit code — раніше батьківський процес завершувався одразу (exit 0)
            # незалежно від результату дочірнього, тож зовнішній caller (CI/скрипт),
            # що перевіряє exit code первинного виклику, завжди бачив 0 (P0.5).
            $elevatedProcess = [System.Diagnostics.Process]::Start($psi)
            $elevatedProcess.WaitForExit()
            exit $elevatedProcess.ExitCode
        } catch {
            Write-Host "[INFO] Не вдалося підвищити права: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# У службовому PowerShell-виводі emoji не використовуються.
# HTML-звіт є винятком: emoji дозволені як частина візуального звіту.
$IconOk='[OK]'; $IconError='[ERROR]'; $IconCpu='[OK]'; $IconRam='[OK]'; $IconDisk='[OK]'; $IconNetwork='[OK]'; $IconSecurity='[OK]'
$IconDone='[SUCCESS]'; $IconJson='[OK]'; $IconHtml='[OK]'; $IconCsv='[OK]'; $IconGear='[INFO]'; $IconEvent='[OK]'
$IconFolder='[INFO]'; $IconDb='[OK]'; $IconPc='[INFO]'; $IconService='[OK]'; $IconZip='[OK]'; $IconEmail='[OK]'

Write-Host ''
Write-Host "=== BRAVO SYSTEM REPORT v$ScriptVersion ===" -ForegroundColor Cyan
Write-Host '=== ДЕТАЛЬНИЙ ЗВІТ ПРО WINDOWS-МАШИНУ ===' -ForegroundColor Cyan
Write-Host ''
Write-Host "[INFO] PowerShell: $($PSVersionTable.PSVersion), OS: $OSVersion, метод: $(if($script:UseCim){'CIM'}else{'WMI'}), профіль: $Profile" -ForegroundColor Gray
Write-Host "[INFO] Директорія: $ScriptDirectory" -ForegroundColor Cyan
Write-Host "$(if($isAdmin){'[OK] АДМІНІСТРАТОР'}else{'[INFO] ОБМЕЖЕНІ ПРАВА'})" -ForegroundColor $(if($isAdmin){'Green'}else{'Yellow'})
Write-Host ''

Set-Location $ScriptDirectory -ErrorAction SilentlyContinue

$script:Report = New-BravoReportModel

Write-Host '=== ЗБІР ІНФОРМАЦІЇ ПРО МАШИНУ ===' -ForegroundColor Cyan
Write-Host ''

# --- ОС ---
Get-BravoOperatingSystemAudit

# --- .NET / PowerShell (перевірка можливості оновлення) ---
Get-BravoRuntimeAudit

# --- Апаратне забезпечення ---
Get-BravoHardwareAudit

# --- BIOS ---
try {
    $biosInfo = Get-AuditObject -ClassName 'Win32_BIOS' -First
    $script:Report.BIOS.Version = ($biosInfo.SMBIOSBIOSVersion, $biosInfo.Version | Where-Object { $_ } | Select-Object -First 1)
    $script:Report.BIOS.SerialNumber = $biosInfo.SerialNumber
    $releaseDate = Convert-AuditDateTime -Value $biosInfo.ReleaseDate -UseCim:$script:UseCim
    if ($releaseDate) { $script:Report.BIOS.ReleaseDate = $releaseDate.ToString('yyyy-MM-dd') }
} catch {
    Add-AuditError -Section 'BIOS' -Message $_.Exception.Message
}
# --- Диски ---
Get-BravoStorageAudit

# --- Мережа ---
Get-BravoNetworkAudit

# --- Безпека ---
Get-BravoSecurityAudit

# --- Користувачі ---
Get-BravoUsersAudit

# --- Процеси та служби ---
Get-BravoProcessesServicesAudit

# --- Журнали подій ---
Get-BravoEventLogsAudit

# --- Програмне забезпечення ---
Get-BravoSoftwareAudit

# --- Оновлення ОС ---
Get-BravoUpdatesAudit

# --- Health score ---
# Рахується РІВНО ОДИН РАЗ, одразу після завершення всіх колекторів. До
# стабілізаційного рефакторингу (P0.4) тут існував "гейт" повторного
# перерахунку після export-етапів — бо помилки запису JSON/HTML/ZIP мішались
# у той самий CollectionErrors, що й впливає на Health Score. Тепер
# CollectionErrors (помилки ЗБОРУ) і ExportErrors (помилки ЗАПИСУ звітів)
# розділені: Health Score — властивість аудитованої машини (CollectionErrors
# + Findings), export-етапи більше не можуть його змінити заднім числом,
# тож повторний перерахунок і пов'язаний з ним ризик (self-zip race з
# попередніх версій) став непотрібним.
Update-BravoHealthScore

# --- Sanitize (P1/v0.4.3) ---
# Виконується ПІСЛЯ Health Score (маскування не впливає на Score/Status —
# рахунок уже фінальний) і ДО будь-якого export'а, щоб JSON/HTML/CSV/ZIP
# усі отримали вже замасковані дані з одного проходу.
if ($Sanitize) {
    try {
        Invoke-BravoReportSanitization -Report $script:Report -Level $SanitizeLevel | Out-Null
        Write-Host "$IconOk Sanitize: дані замасковано (рівень $SanitizeLevel)" -ForegroundColor Yellow
    } catch {
        Add-ExportError -Section 'Sanitize' -Message $_.Exception.Message
    }
}

# ============================================================
# ЗБЕРЕЖЕННЯ ЗВІТІВ
# ============================================================

try {
    $outputDir = Resolve-AuditOutputPath -RequestedPath $OutputPath -DefaultPath $ScriptDirectory
} catch {
    # Проблема самого інструмента (не вдалось підготувати каталог виводу),
    # не властивість аудитованої машини — ExportError, не CollectionError.
    Add-ExportError -Section 'OutputPath' -Message $_.Exception.Message
    $outputDir = $ScriptDirectory
}

$script:Report.OutputPath = $outputDir
$baseFileName = "BravoSystemReport_$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

Write-Host ''
Write-Host '=== ГЕНЕРАЦІЯ ЗВІТІВ ===' -ForegroundColor Cyan
Write-Host ''
Write-Host "$IconFolder Збереження: $outputDir" -ForegroundColor Cyan

# JSON — Health Score вже фінальний (рахувався до початку export-етапів),
# тому перший запис одразу авторитетний щодо CollectionErrors/Findings.
# Пишеться ПЕРШИМ (не останнім), щоб потрапити до ZIP нижче — але через це
# ExportErrors від наступних export-етапів (HTML/CSV/ZIP/Email) у ньому ще
# не відомі на момент цього запису. Тому наприкінці пайплайну JSON
# перезаписується ще раз, якщо ExportErrors змінились — це ЄДИНИЙ можливий
# повторний запис (не Health Score, не HTML, без re-zip), набагато простіше
# й безпечніше за попередній "гейт" повторного перерахунку.
$exportErrorCountBeforeExport = @($script:Report.ExportErrors).Count
Export-BravoJsonReport -OutputDir $outputDir -BaseFileName $baseFileName

# HTML
Export-BravoHtmlReport -OutputDir $outputDir -BaseFileName $baseFileName -JSONOnly $JSONOnly -EventLogDays $EventLogDays -Profile $Profile -ScriptVersion $ScriptVersion

# PDF (опційно, через headless Microsoft Edge) — потребує HTML, тому
# виконується одразу після Export-BravoHtmlReport і до ZIP, щоб .pdf
# встиг потрапити в GeneratedFiles до пакування. -JSONOnly вимикає HTML
# взагалі, тож PDF теж пропускається (нема з чого конвертувати).
if ($ExportPdf -and -not $JSONOnly) {
    Export-BravoPdfReport -OutputDir $outputDir -BaseFileName $baseFileName
}

# CSV
Export-BravoCsvReport -OutputDir $outputDir -BaseFileName $baseFileName -CSV $CSV

$script:Report.GeneratedFiles = @($script:Report.GeneratedFiles | Select-Object -Unique)

# ZIP
Export-BravoZipReport -OutputDir $outputDir -BaseFileName $baseFileName -Zip $Zip
$script:Report.GeneratedFiles = @($script:Report.GeneratedFiles | Select-Object -Unique)

# Email — останній export-етап. Тіло листа й вкладення відображають стан на
# момент відправки (Health Score вже фінальний; JSON-вкладення може не
# містити ExportErrors від самого Email — лист не може повідомити про власну
# невдалу відправку заднім числом, це очікуване обмеження).
Send-BravoEmailReport -EmailTo $EmailTo -EmailFrom $EmailFrom -SmtpServer $SmtpServer

# Якщо HTML/CSV/ZIP/Email додали нові ExportErrors після першого запису JSON —
# перезаписуємо JSON ще раз, щоб файл на диску (не копія в ZIP) був
# авторитетним щодо ExportErrors. Health Score тут не перераховується (не
# залежить від ExportErrors), тож це просто один додатковий запис файлу.
if (@($script:Report.ExportErrors).Count -gt $exportErrorCountBeforeExport) {
    Export-BravoJsonReport -OutputDir $outputDir -BaseFileName $baseFileName
    $script:Report.GeneratedFiles = @($script:Report.GeneratedFiles | Select-Object -Unique)
}

# Фінал
$elapsedSeconds = [Math]::Round(((Get-Date) - $ScriptStartTime).TotalSeconds, 2)
$jsonPath = Join-Path $outputDir "$baseFileName.json"
$htmlPath = Join-Path $outputDir "$baseFileName.html"
$csvPath = Join-Path $outputDir "$baseFileName.csv"
$zipPath = Join-Path $outputDir "$baseFileName.zip"

Write-Host ''
Write-Host '=== АУДИТ МАШИНИ ЗАВЕРШЕНО ===' -ForegroundColor Green
Write-Host ''
Write-Host "$IconFolder Звіти збережено: $outputDir" -ForegroundColor Cyan
if (Test-Path -LiteralPath $jsonPath) { Write-Host "$IconJson JSON: $baseFileName.json" -ForegroundColor White }
if ((-not $JSONOnly) -and (Test-Path -LiteralPath $htmlPath)) { Write-Host "$IconHtml HTML: $baseFileName.html" -ForegroundColor White }
if ($CSV -and (Test-Path -LiteralPath $csvPath)) { Write-Host "$IconCsv CSV: $baseFileName.csv" -ForegroundColor White }
if ($Zip -and (Test-Path -LiteralPath $zipPath)) {
    Write-Host "$IconZip ZIP: $baseFileName.zip" -ForegroundColor White
} elseif ($Zip) {
    Write-Host "$IconError ZIP не створено: $baseFileName.zip" -ForegroundColor Red
}
Write-Host "Оцінка стану: $($script:Report.Health.Score)/100 ($($script:Report.Health.Status))" -ForegroundColor Cyan
Write-Host "Знахідки: $($script:Report.Health.Findings.Count); помилки збору: $($script:Report.CollectionErrors.Count); помилки експорту: $($script:Report.ExportErrors.Count)" -ForegroundColor Cyan
Write-Host "Час виконання: $elapsedSeconds сек" -ForegroundColor Cyan
Write-Host ''

# --- Exit code contract (P0.5, розширено -Strict у P1) ---
# 0 = аудит успішно завершено, без помилок збору/експорту (і, у -Strict
#     режимі, без CRITICAL Health.Status);
# 1 = аудит завершено, але були CollectionErrors і/або ExportErrors;
# 2 = фатальна неопрацьована помилка виконання (top-level trap, вище в файлі);
# 3 = обов'язковий вихідний файл (JSON) не згенеровано;
# 4 = лише у -Strict режимі: аудит завершено без CollectionErrors/ExportErrors,
#     але Health.Status аудитованої машини = CRITICAL.
#
# За замовчуванням (без -Strict) Health Status (WARNING/CRITICAL) НЕ впливає
# на exit code — це властивість аудитованої машини (наскільки вона здорова),
# а не ознака збою самого інструмента. -Strict вмикає цю поведінку явно —
# для CI-гейтів, яким потрібен ненульовий exit code саме на "машина в
# критичному стані", а не лише на "інструмент не зміг щось зібрати/записати".
$script:ExitCode = 0
if (-not (Test-Path -LiteralPath $jsonPath)) {
    $script:ExitCode = 3
} elseif ((@($script:Report.CollectionErrors).Count -gt 0) -or (@($script:Report.ExportErrors).Count -gt 0)) {
    $script:ExitCode = 1
} elseif ($Strict -and $script:Report.Health.Status -eq 'CRITICAL') {
    $script:ExitCode = 4
}

if (-not $NoOpenFolder) {
    try { Start-Process explorer.exe -ArgumentList "`"$outputDir`"" -ErrorAction SilentlyContinue } catch {
        Add-ExportError -Section 'OpenFolder' -Message $_.Exception.Message
    }
}

if (-not $NoPause) { Show-Pause }
exit $script:ExitCode

