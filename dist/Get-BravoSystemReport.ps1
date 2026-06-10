<#
    BRAVO SYSTEM REPORT
    Згенерований монолітний runtime-скрипт.
    GeneratedAt: 2026-06-11 02:46:19

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
    [string]$Profile = 'Full',

    [string]$OutputPath = '',

    [switch]$JSONOnly,
    [switch]$CSV,
    [switch]$Zip,
    [switch]$NoEmoji,
    [switch]$NoElevate,
    [switch]$NoPause,
    [switch]$NoOpenFolder,
    [switch]$SkipElevation,

    [int]$EventLogDays = 0,

    [string]$EmailTo,
    [string]$EmailFrom = "systemaudit@$($env:COMPUTERNAME).local",
    [string]$SmtpServer = ''
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


# ============================================================
# MODULE: src/20-ReportModel.ps1
# ============================================================

# MODULE: 20-ReportModel.ps1
# Створення базової моделі звіту BRAVO SYSTEM REPORT.

function New-BravoReportModel {
    [CmdletBinding()]
    param()

return [ordered]@{
    SchemaVersion = '0.3.2'
    ScriptVersion = $ScriptVersion
    Profile = $Profile
    Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    ComputerName = $env:COMPUTERNAME
    Elevated = $isAdmin
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
    Health = [ordered]@{
        Score = 100
        Status = 'OK'
        Findings = @()
    }
    OS = [ordered]@{ Caption=''; Version=''; Build=''; Architecture=''; InstallDate=''; LastBootUpTime=''; UptimeDays=0; UptimeHours=0 }
    PowerShell = [ordered]@{ Version=$PSVersionTable.PSVersion.ToString(); Edition=$PSVersionTable.PSEdition; ExecutionPolicy=(Get-ExecutionPolicy).ToString() }
    DotNet = [ordered]@{ v4='Not Installed' }
    BIOS = [ordered]@{ Version=''; SerialNumber=''; ReleaseDate='' }
    Virtualization = [ordered]@{ IsVirtual=$false; Hypervisor='' }
    Hardware = [ordered]@{
        ComputerSystem = [ordered]@{ Manufacturer=''; Model=''; Domain=''; TotalPhysicalMemoryGB=0 }
        CPU = [ordered]@{ Name=''; Cores=0; LogicalProcessors=0; MaxClockSpeedMHz=0; LoadPercent=0 }
        RAM = [ordered]@{ TotalGB=0; UsedPercent=0; Modules=@() }
        Disks = [ordered]@{ FreePercent=0; TotalGB=0; FreeGB=0; Volumes=@(); PhysicalDisks=@() }
    }
    Network = [ordered]@{
        General = [ordered]@{ Hostname=''; Domain='' }
        IP = [ordered]@{ IPv4=@() }
        Routing = [ordered]@{ DefaultGateway=''; DNSServers=@() }
        Adapters = @()
        Connections = [ordered]@{ Established=0; Listening=0; ListeningPorts=@() }
    }
    Security = [ordered]@{ UAC=[ordered]@{Enabled=$false}; RemoteAccess=[ordered]@{RDPEnabled=$false}; Antivirus=[ordered]@{Product=''}; Firewall=[ordered]@{} }
    Users = [ordered]@{ LocalAdmins=@() }
    Processes = [ordered]@{ Total=0; TopMemory=@() }
    Services = [ordered]@{ Total=0; Running=0; AutomaticStopped=@() }
    EventLogs = [ordered]@{ Days=$EventLogDays; SystemErrors=0; SystemWarnings=0; SystemErrors24h=0; SystemWarnings24h=0 }
    Software = [ordered]@{ Installed=@(); WindowsFeatures=@() }
    USBDevices = @()
    CollectionErrors = @()
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
        }

        if ($script:Report.OS.UptimeDays -gt 90) {
            Add-AuditFinding -Severity 'WARNING' -Category 'OS' -Message "Uptime більше 90 днів: $($script:Report.OS.UptimeDays)" -Recommendation 'Заплануйте контрольоване перезавантаження після перевірки критичних служб.'
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
# Збір базової інформації про апаратне забезпечення.

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
        $script:Report.Hardware.CPU.LoadPercent = [Math]::Round(($cpuInfo.LoadPercentage | Measure-Object -Average).Average)

        $script:Report.Hardware.RAM.TotalGB = [Math]::Round($computerSystemInfo.TotalPhysicalMemory / 1GB, 2)
        if ($osInfo.TotalVisibleMemorySize -gt 0) {
            $script:Report.Hardware.RAM.UsedPercent = [Math]::Round((($osInfo.TotalVisibleMemorySize - $osInfo.FreePhysicalMemory) / $osInfo.TotalVisibleMemorySize) * 100)
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

# --- BRAVO v0.3.0 Storage Deep Audit Skeleton ---
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
    $storage = [ordered]@{
        CollectedAt  = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        LogicalDisks = @()
        Volumes      = @()
        Disks        = @()
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

    return [PSCustomObject]$storage
}


# --- BRAVO v0.3.2 Storage Critical Findings ---
function Get-BravoStorageRiskSummary {
    param(
        [Parameter(Mandatory = $true)]
        $StorageDeep
    )

    $criticalThreshold = 5
    $warningThreshold = 10
    $systemWarningThreshold = 15
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
        Summary                    = [ordered]@{
            CriticalCount           = 0
            WarningCount            = 0
            SystemWarningCount      = 0
            HealthyCount            = 0
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

            if ($volume.FreePercent -lt 10) {
                Add-AuditFinding -Severity 'CRITICAL' -Category 'Storage' -Message "На диску $($volume.DeviceID) менше 10% вільного місця: $($volume.FreePercent)%" -Recommendation 'Звільніть місце або розширте том.'
            } elseif ($volume.FreePercent -lt 20) {
                Add-AuditFinding -Severity 'WARNING' -Category 'Storage' -Message "На диску $($volume.DeviceID) менше 20% вільного місця: $($volume.FreePercent)%" -Recommendation 'Перевірте темп росту даних і заплануйте очищення.'
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
# Збір інформації про мережеві адаптери, IP, TCP-з'єднання, primary IPv4 та public IPv4.

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

            if ($adapterConfig.DefaultIPGateway -and -not $script:Report.Network.Routing.DefaultGateway) {
                $script:Report.Network.Routing.DefaultGateway = $adapterConfig.DefaultIPGateway[0]
            }

            if ($adapterConfig.DNSServerSearchOrder) {
                $script:Report.Network.Routing.DNSServers = @($script:Report.Network.Routing.DNSServers + $adapterConfig.DNSServerSearchOrder) | Select-Object -Unique
            }

            $script:Report.Network.Adapters += [PSCustomObject]@{
                Description = $adapterConfig.Description
                MACAddress  = $adapterConfig.MACAddress
                DHCPEnabled = $adapterConfig.DHCPEnabled
                IPv4        = @($adapterConfig.IPAddress | Where-Object { $_ -notlike '*:*' })
                Gateway     = $adapterConfig.DefaultIPGateway
                DNS         = $adapterConfig.DNSServerSearchOrder
            }
        }

        if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
            try {
                $tcpConnections = Get-NetTCPConnection -ErrorAction Stop
                $script:Report.Network.Connections.Established = @($tcpConnections | Where-Object { $_.State -eq 'Established' }).Count
                $listening = @($tcpConnections | Where-Object { $_.State -eq 'Listen' })
                $script:Report.Network.Connections.Listening = $listening.Count

                if ($Profile -in @('Full','Deep','Forensic')) {
                    $script:Report.Network.Connections.ListeningPorts = $listening |
                        Select-Object -First 200 -Property LocalAddress, LocalPort, OwningProcess
                }
            } catch {
                Add-AuditError -Section 'Network.TcpConnections' -Message $_.Exception.Message
            }
        }
    # BRAVO IP ORDER OUTPUT START
    $bravoPrimaryNetwork = Get-BravoPrimaryNetworkInterface
    $bravoPrimaryIPv4 = $null

    if ($bravoPrimaryNetwork -and $bravoPrimaryNetwork.IPv4) {
        $bravoPrimaryIPv4 = $bravoPrimaryNetwork.IPv4
    }

    $bravoIPv4Source = @(Get-BravoAllUsableIPv4AddressList)

    if ($bravoIPv4Source.Count -eq 0 -and $Report.Network) {
        if ($Report.Network -is [System.Collections.IDictionary]) {
            if ($Report.Network.Contains("IPv4")) {
                $bravoIPv4Source = @($Report.Network["IPv4"])
            }
        } elseif ($Report.Network.IPv4) {
            $bravoIPv4Source = @($Report.Network.IPv4)
        }
    }

    $bravoOrderedIPv4 = @(Move-BravoIPv4ToFront -IPv4 $bravoIPv4Source -PrimaryIPv4 $bravoPrimaryIPv4)

    if ($bravoOrderedIPv4.Count -gt 0) {
        $bravoPrimaryIPv4 = $bravoOrderedIPv4[0]
        $bravoIPv4Text = $bravoOrderedIPv4 -join ", "
    } else {
        $bravoPrimaryIPv4 = "N/A"
        $bravoIPv4Text = "N/A"
    }

    if ($Report.Network) {
        if ($Report.Network -is [System.Collections.IDictionary]) {
            $Report.Network["IPv4"] = @($bravoOrderedIPv4)
            $Report.Network["PrimaryIPv4"] = $bravoPrimaryIPv4
            $Report.Network["PrimaryInterface"] = $bravoPrimaryNetwork
        } else {
            $Report.Network | Add-Member -NotePropertyName "IPv4" -NotePropertyValue @($bravoOrderedIPv4) -Force
            $Report.Network | Add-Member -NotePropertyName "PrimaryIPv4" -NotePropertyValue $bravoPrimaryIPv4 -Force
            $Report.Network | Add-Member -NotePropertyName "PrimaryInterface" -NotePropertyValue $bravoPrimaryNetwork -Force
        }
    }

    Write-Host "  [OK] IP: $bravoIPv4Text" -ForegroundColor Green
    # BRAVO IP ORDER OUTPUT END


    # BRAVO PUBLIC IP OUTPUT START
    $bravoPublicIPv4Info = Get-BravoPublicIPv4Address

    if ($Report.Network) {
        if ($Report.Network -is [System.Collections.IDictionary]) {
            $Report.Network["PublicIPv4"] = $bravoPublicIPv4Info.IPv4
            $Report.Network["PublicIPv4Provider"] = $bravoPublicIPv4Info.Provider
            $Report.Network["PublicIPv4CheckedAt"] = $bravoPublicIPv4Info.CheckedAt
            $Report.Network["PublicIPv4Status"] = $bravoPublicIPv4Info.Status
        } else {
            $Report.Network | Add-Member -NotePropertyName "PublicIPv4" -NotePropertyValue $bravoPublicIPv4Info.IPv4 -Force
            $Report.Network | Add-Member -NotePropertyName "PublicIPv4Provider" -NotePropertyValue $bravoPublicIPv4Info.Provider -Force
            $Report.Network | Add-Member -NotePropertyName "PublicIPv4CheckedAt" -NotePropertyValue $bravoPublicIPv4Info.CheckedAt -Force
            $Report.Network | Add-Member -NotePropertyName "PublicIPv4Status" -NotePropertyValue $bravoPublicIPv4Info.Status -Force
        }
    }

    if ($bravoPublicIPv4Info.Status -eq "Detected") {
        Write-Host "  [OK] Public IP: визначено, записано у звіт" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Public IP: не визначено" -ForegroundColor Yellow
    }
    # BRAVO PUBLIC IP OUTPUT END
    } catch {
        Add-AuditError -Section 'Network' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка мережевих даних: $($_.Exception.Message)" -ForegroundColor Red
    }
}


# ============================================================
# MODULE: src/34-Collectors-Security.ps1
# ============================================================

# MODULE: 34-Collectors-Security.ps1
# Збір інформації про UAC, RDP, антивірус та Windows Firewall.

function Get-BravoSecurityAudit {
    [CmdletBinding()]
    param()

    # --- Безпека ---
    try {
        $uac = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction SilentlyContinue
        if ($uac) { $script:Report.Security.UAC.Enabled = ($uac.EnableLUA -eq 1) }

        if (-not $script:Report.Security.UAC.Enabled) {
            Add-AuditFinding -Severity 'WARNING' -Category 'Security' -Message 'UAC вимкнено.' -Recommendation 'Увімкніть UAC, якщо немає обґрунтованого винятку.'
        }

        $rdp = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -ErrorAction SilentlyContinue
        if ($rdp) { $script:Report.Security.RemoteAccess.RDPEnabled = ($rdp.fDenyTSConnections -eq 0) }

        if ($script:Report.Security.RemoteAccess.RDPEnabled) {
            Add-AuditFinding -Severity 'INFO' -Category 'RemoteAccess' -Message 'RDP увімкнено.' -Recommendation 'Перевірте NLA, firewall scope і список дозволених користувачів.'
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
            $capture = $false
            foreach ($line in $raw) {
                $text = ($line | Out-String).Trim()
                if (-not $text) { continue }
                if ($text -match '^-{3,}$') { $capture = $true; continue }
                if ($text -match 'command completed|Команда виконана|completed successfully') { break }
                if ($capture) { $members += $text }
            }
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
            $script:Report.Processes.TopMemory = $processInfo |
                Sort-Object -Property WorkingSet64 -Descending |
                Select-Object -First 10 @{Name='ProcessName';Expression={$_.ProcessName}}, Id, @{Name='MemoryMB';Expression={[Math]::Round($_.WorkingSet64 / 1MB, 2)}}
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
                $autoStopped = Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State<>'Running'" -ErrorAction Stop
                $script:Report.Services.AutomaticStopped = @($autoStopped | Select-Object Name, DisplayName, State, StartMode, StartName)
                if ($script:Report.Services.AutomaticStopped.Count -gt 0) {
                    Add-AuditFinding -Severity 'WARNING' -Category 'Services' -Message "Автоматичних служб не запущено: $($script:Report.Services.AutomaticStopped.Count)." -Recommendation 'Перевірте, чи ці служби мають бути запущені.'
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

        if ($script:Report.EventLogs.SystemErrors -gt 0) {
            Add-AuditFinding -Severity 'WARNING' -Category 'EventLogs' -Message "За $EventLogDays днів знайдено системних помилок: $($script:Report.EventLogs.SystemErrors)." -Recommendation 'Перегляньте System log і визначте повторювані джерела помилок.'
        }

        Write-Host "  $IconEvent Події System: помилок=$($script:Report.EventLogs.SystemErrors), попереджень=$($script:Report.EventLogs.SystemWarnings) за $EventLogDays дн." -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'EventLogs' -Message $_.Exception.Message
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

        $script:Report.Health.Score = $score
        $script:Report.Health.Status = if ($criticalCount -gt 0) { 'CRITICAL' } elseif ($warningCount -gt 0 -or $errorCount -gt 0) { 'WARNING' } else { 'OK' }
    } catch {
        Add-AuditError -Section 'HealthScore' -Message $_.Exception.Message
    }

    Write-Host ''
    Write-Host "$IconDone Збір даних завершено! Оцінка стану: $($script:Report.Health.Score)/100 ($($script:Report.Health.Status))" -ForegroundColor Green
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
        ConvertTo-Json $script:Report -Depth 12 | Out-File $jsonPath -Encoding utf8
        $script:Report.GeneratedFiles += $jsonPath
        Write-Host "  $IconJson JSON: $BaseFileName.json" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Export.Json' -Message $_.Exception.Message
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
# HTML
if (-not $JSONOnly) {
    try {
        $htmlPath = Join-Path $outputDir "$baseFileName.html"
        $findingsRows = if ($script:Report.Health.Findings.Count -gt 0) {
            ($script:Report.Health.Findings | ForEach-Object {
                "<tr><td>$($_.Severity)</td><td>$($_.Category)</td><td>$($_.Message)</td><td>$($_.Recommendation)</td></tr>"
            }) -join "`n"
        } else {
            '<tr><td colspan="4">Критичних зауважень не знайдено.</td></tr>'
        }

        $errorsRows = if ($script:Report.CollectionErrors.Count -gt 0) {
            ($script:Report.CollectionErrors | ForEach-Object {
                "<tr><td>$($_.Time)</td><td>$($_.Section)</td><td>$($_.Message)</td></tr>"
            }) -join "`n"
        } else {
            '<tr><td colspan="3">Помилок збору даних не зафіксовано.</td></tr>'
        }

        function ConvertTo-BravoHtmlText {
            param(
                [AllowNull()]
                [object]$Value
            )

            if ($null -eq $Value) {
                return ''
            }

            return [System.Net.WebUtility]::HtmlEncode([string]$Value)
        }

        function Get-BravoStorageRiskClass {
            param(
                [AllowNull()]
                [object]$Risk
            )

            switch (([string]$Risk).ToUpperInvariant()) {
                'CRITICAL' { return 'risk-critical' }
                'WARNING'  { return 'risk-warning' }
                'OK'       { return 'risk-ok' }
                default    { return 'risk-unknown' }
            }
        }

        function Get-BravoStorageDisplayText {
            param(
                [AllowNull()]
                [object]$Volume
            )

            if ($null -eq $Volume) {
                return ''
            }

            if ($Volume.DriveLetter) {
                return ("{0}:" -f ([string]$Volume.DriveLetter).TrimEnd(':'))
            }

            if ($Volume.Drive) {
                return [string]$Volume.Drive
            }

            if ($Volume.DeviceID) {
                return [string]$Volume.DeviceID
            }

            if ($Volume.VolumeKey) {
                return [string]$Volume.VolumeKey
            }

            return 'Volume без літери'
        }

        function Get-BravoStoragePropertyText {
            param(
                [AllowNull()]
                [object]$Value
            )

            if ($null -eq $Value -or [string]$Value -eq '') {
                return '—'
            }

            return [string]$Value
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

        $storageFindingItems = @()

        foreach ($item in @($storageRisk.CriticalVolumes)) {
            if ($item) {
                $storageFindingItems += [PSCustomObject]@{ Group = 'CRITICAL'; Volume = $item }
            }
        }

        foreach ($item in @($storageRisk.WarningVolumes)) {
            if ($item) {
                $storageFindingItems += [PSCustomObject]@{ Group = 'WARNING'; Volume = $item }
            }
        }

        foreach ($item in @($storageRisk.SystemVolumeWarnings)) {
            if ($item) {
                $storageFindingItems += [PSCustomObject]@{ Group = 'WARNING'; Volume = $item }
            }
        }

        $storageCriticalRows = if (@($storageFindingItems).Count -gt 0) {
            ($storageFindingItems | ForEach-Object {
                $volume = $_.Volume
                $riskText = if ($volume.Risk) { [string]$volume.Risk } else { [string]$_.Group }
                $riskClass = Get-BravoStorageRiskClass $riskText
                $reason = if ($volume.Reason) { $volume.Reason } elseif ($volume.Message) { $volume.Message } else { 'Потребує перевірки storage thresholds.' }

                "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStorageDisplayText $volume))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.Label))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FileSystem))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.SizeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreePercent))%</td><td><span class=""risk $riskClass"">$(ConvertTo-BravoHtmlText $riskText)</span></td><td>$(ConvertTo-BravoHtmlText $reason)</td></tr>"
            }) -join "`n"
        } else {
            '<tr><td colspan="8" class="muted">Критичних або попереджувальних storage-знахідок немає.</td></tr>'
        }

        $storageVolumes = @($storageDeep.Volumes)

        $storageDeepRows = if ($storageVolumes.Count -gt 0) {
            ($storageVolumes | ForEach-Object {
                $volume = $_
                $freePercent = $null

                if ($null -ne $volume.FreePercent -and [string]$volume.FreePercent -ne '') {
                    $freePercent = [double]$volume.FreePercent
                }

                $riskText = if ($null -eq $freePercent) {
                    'UNKNOWN'
                } elseif ($freePercent -lt $criticalThreshold) {
                    'CRITICAL'
                } elseif ($freePercent -lt $warningThreshold) {
                    'WARNING'
                } else {
                    'OK'
                }

                $riskClass = Get-BravoStorageRiskClass $riskText

                $reason = if ($riskText -eq 'CRITICAL') {
                    "Вільного місця менше $criticalThreshold%."
                } elseif ($riskText -eq 'WARNING') {
                    "Вільного місця менше $warningThreshold%."
                } elseif ($riskText -eq 'UNKNOWN') {
                    'Не вдалося визначити free percent.'
                } else {
                    'Показники в межах порогів.'
                }

                "<tr><td>$(ConvertTo-BravoHtmlText (Get-BravoStorageDisplayText $volume))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FileSystemLabel))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FileSystem))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.DriveType))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.HealthStatus))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.OperationalStatus))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.SizeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreeGB))</td><td>$(ConvertTo-BravoHtmlText (Get-BravoStoragePropertyText $volume.FreePercent))%</td><td><span class=""risk $riskClass"">$(ConvertTo-BravoHtmlText $riskText)</span></td><td>$(ConvertTo-BravoHtmlText $reason)</td></tr>"
            }) -join "`n"
        } else {
            '<tr><td colspan="11" class="muted">Storage Deep дані відсутні для поточного профілю або збір завершився з помилкою.</td></tr>'
        }

        $storageHtmlSection = @"
<div class="section storage-critical-section">
  <h2>💽 Storage Critical Findings</h2>
  <div class="storage-summary-grid">
    <div class="storage-summary-item"><div class="storage-summary-label">Critical volumes</div><div class="storage-summary-value"><span class="risk risk-critical">$criticalCount</span></div></div>
    <div class="storage-summary-item"><div class="storage-summary-label">Warning volumes</div><div class="storage-summary-value"><span class="risk risk-warning">$warningCount</span></div></div>
    <div class="storage-summary-item"><div class="storage-summary-label">System warnings</div><div class="storage-summary-value"><span class="risk risk-warning">$systemWarningCount</span></div></div>
    <div class="storage-summary-item"><div class="storage-summary-label">Healthy volumes</div><div class="storage-summary-value"><span class="risk risk-ok">$healthyCount</span></div></div>
  </div>

  <table class="storage-table">
    <thead>
      <tr>
        <th>Том</th>
        <th>Мітка</th>
        <th>FS</th>
        <th>Size GB</th>
        <th>Free GB</th>
        <th>Free %</th>
        <th>Risk</th>
        <th>Причина</th>
      </tr>
    </thead>
    <tbody>
      $storageCriticalRows
    </tbody>
  </table>
</div>

<div class="section storage-deep-section">
  <h2>🧱 Storage Deep</h2>
  <table class="storage-table">
    <thead>
      <tr>
        <th>Том</th>
        <th>Мітка</th>
        <th>FS</th>
        <th>Тип</th>
        <th>Health</th>
        <th>Operational</th>
        <th>Size GB</th>
        <th>Free GB</th>
        <th>Free %</th>
        <th>Risk</th>
        <th>Причина</th>
      </tr>
    </thead>
    <tbody>
      $storageDeepRows
    </tbody>
  </table>
</div>
"@
        $htmlContent = @"
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>BRAVO SYSTEM REPORT - $($script:Report.ComputerName)</title>
<style>
:root{
  --bg:#0b1020;
  --panel:#ffffff;
  --panel-soft:#f8fafc;
  --text:#0f172a;
  --muted:#64748b;
  --line:#e2e8f0;
  --primary:#2563eb;
  --primary-dark:#1e40af;
  --accent:#06b6d4;
  --success:#16a34a;
  --warning:#d97706;
  --critical:#dc2626;
  --shadow:0 22px 60px rgba(15,23,42,.24);
}
*{box-sizing:border-box}
body{
  margin:0;
  font-family:'Segoe UI',Roboto,Arial,sans-serif;
  background:
    radial-gradient(circle at 15% 8%,rgba(37,99,235,.34),transparent 28%),
    radial-gradient(circle at 92% 18%,rgba(6,182,212,.28),transparent 30%),
    linear-gradient(135deg,#0b1020,#111827 48%,#020617);
  color:var(--text);
}
.container{
  max-width:1360px;
  margin:28px auto;
  background:var(--panel);
  border-radius:24px;
  overflow:hidden;
  box-shadow:var(--shadow);
}
.header{
  position:relative;
  padding:34px 38px;
  color:white;
  background:
    linear-gradient(135deg,rgba(37,99,235,.96),rgba(14,165,233,.86)),
    linear-gradient(135deg,#0f172a,#1e293b);
}
.header:after{
  content:'';
  position:absolute;
  right:-70px;
  bottom:-120px;
  width:280px;
  height:280px;
  border-radius:999px;
  background:rgba(255,255,255,.13);
}
.brand{
  display:flex;
  align-items:center;
  gap:18px;
  position:relative;
  z-index:1;
}
.brand-icon{
  width:68px;
  height:68px;
  display:flex;
  align-items:center;
  justify-content:center;
  border-radius:20px;
  background:rgba(255,255,255,.18);
  border:1px solid rgba(255,255,255,.28);
  font-size:36px;
}
.header h1{
  margin:0;
  font-size:34px;
  letter-spacing:.4px;
}
.header p{
  margin:8px 0 0 0;
  opacity:.92;
}
.badge{
  display:inline-flex;
  align-items:center;
  gap:8px;
  border-radius:999px;
  padding:8px 14px;
  background:rgba(255,255,255,.16);
  border:1px solid rgba(255,255,255,.28);
  color:white;
  font-weight:800;
}
.content{padding:30px}
.summary-grid{
  display:grid;
  grid-template-columns:repeat(auto-fit,minmax(190px,1fr));
  gap:16px;
  margin-bottom:28px;
}
.summary-card{
  background:linear-gradient(180deg,#ffffff,#f8fafc);
  border:1px solid var(--line);
  border-radius:18px;
  padding:18px;
  box-shadow:0 8px 24px rgba(15,23,42,.07);
}
.summary-icon{
  font-size:28px;
  margin-bottom:8px;
}
.summary-label{
  color:var(--muted);
  font-size:13px;
  font-weight:800;
  text-transform:uppercase;
  letter-spacing:.06em;
}
.summary-value{
  margin-top:6px;
  font-size:22px;
  font-weight:900;
  color:var(--text);
  line-height:1.15;
}
h2{
  display:flex;
  align-items:center;
  gap:10px;
  margin:30px 0 16px 0;
  color:#0f172a;
  font-size:22px;
}
h2:after{
  content:'';
  flex:1;
  height:1px;
  background:var(--line);
}
.section-icon{
  width:38px;
  height:38px;
  display:inline-flex;
  align-items:center;
  justify-content:center;
  border-radius:12px;
  background:#eff6ff;
  color:var(--primary);
}
.grid{
  display:grid;
  grid-template-columns:repeat(auto-fit,minmax(340px,1fr));
  gap:18px;
}
.card{
  background:var(--panel-soft);
  border:1px solid var(--line);
  border-radius:18px;
  padding:20px;
  box-shadow:0 8px 24px rgba(15,23,42,.06);
}
.card h3{
  display:flex;
  align-items:center;
  gap:8px;
  margin:0 0 14px 0;
  font-size:18px;
  color:#0f172a;
}
.info-row{
  display:flex;
  justify-content:space-between;
  gap:16px;
  padding:10px 0;
  border-bottom:1px solid var(--line);
}
.info-row:last-child{border-bottom:none}
.info-label{
  font-weight:800;
  color:var(--muted);
}
.info-value{
  color:var(--text);
  text-align:right;
  word-break:break-word;
  font-weight:650;
}
.progress-bar{
  background:#e2e8f0;
  border-radius:999px;
  overflow:hidden;
  min-width:170px;
  height:24px;
}
.progress-fill{
  height:24px;
  line-height:24px;
  background:linear-gradient(90deg,var(--primary),var(--accent));
  color:white;
  text-align:center;
  font-size:12px;
  font-weight:900;
}
table{
  width:100%;
  border-collapse:separate;
  border-spacing:0;
  margin-top:12px;
  overflow:hidden;
  border:1px solid var(--line);
  border-radius:14px;
}
th,td{
  padding:11px 12px;
  text-align:left;
  border-bottom:1px solid var(--line);
}
th{
  background:#eff6ff;
  color:#1e3a8a;
  font-size:13px;
  text-transform:uppercase;
  letter-spacing:.04em;
}
tr:last-child td{border-bottom:none}
.footer{
  background:#f8fafc;
  border-top:1px solid var(--line);
  padding:18px 24px;
  text-align:center;
  color:var(--muted);
  font-size:13px;
}
@media print{
  body{background:white}
  .container{box-shadow:none;margin:0;border-radius:0}
  .header{background:#1e40af !important}
}

  .storage-summary-grid{
    display:grid;
    grid-template-columns:repeat(auto-fit,minmax(160px,1fr));
    gap:12px;
    margin:12px 0 16px 0;
  }
  .storage-summary-item{
    background:#f8fafc;
    border:1px solid var(--border,#e5e7eb);
    border-radius:10px;
    padding:10px 12px;
  }
  .storage-summary-label{
    color:#64748b;
    font-size:12px;
    margin-bottom:4px;
  }
  .storage-summary-value{
    font-size:20px;
    font-weight:700;
  }
  .storage-table{
    width:100%;
    border-collapse:collapse;
    margin-top:12px;
    font-size:13px;
  }
  .storage-table th,
  .storage-table td{
    text-align:left;
    padding:8px 10px;
    border-bottom:1px solid var(--border,#e5e7eb);
    vertical-align:top;
  }
  .storage-table th{
    background:#f1f5f9;
    color:#334155;
    font-weight:700;
  }
  .risk{
    font-weight:700;
    white-space:nowrap;
  }
  .risk-critical{color:var(--critical,#dc2626);}
  .risk-warning{color:var(--warning,#f59e0b);}
  .risk-ok{color:var(--success,#16a34a);}
  .risk-unknown{color:#64748b;}
  .muted{color:#64748b;}
</style></head>
<body><div class="container"><div class="header">
<div class="brand">
  <div class="brand-icon">📊</div>
  <div>
    <h1>BRAVO SYSTEM REPORT</h1>
    <p>$($script:Report.ComputerName) | $($script:Report.Timestamp) | Profile: $Profile</p>
    <p><span class="badge">🎯 Health Score: $($script:Report.Health.Score)/100 — $($script:Report.Health.Status)</span></p>
  </div>
</div>
</div>
<div class="content">
<div class="summary-grid">
  <div class="summary-card"><div class="summary-icon">🖥️</div><div class="summary-label">ОС</div><div class="summary-value">$($script:Report.OS.Caption)</div></div>
  <div class="summary-card"><div class="summary-icon">🧠</div><div class="summary-label">CPU</div><div class="summary-value">$($script:Report.Hardware.CPU.Cores)/$($script:Report.Hardware.CPU.LogicalProcessors)</div></div>
  <div class="summary-card"><div class="summary-icon">💾</div><div class="summary-label">RAM</div><div class="summary-value">$($script:Report.Hardware.RAM.TotalGB) GB</div></div>
  <div class="summary-card"><div class="summary-icon">💿</div><div class="summary-label">Диски</div><div class="summary-value">$($script:Report.Hardware.Disks.FreePercent)% free</div></div>
  <div class="summary-card"><div class="summary-icon">🔒</div><div class="summary-label">Security</div><div class="summary-value">$($script:Report.Health.Status)</div></div>
</div>
<h2><span class="section-icon">🖥️</span>Система та обладнання</h2>
<div class="grid">
<div class="card"><h3>🖥️ Система</h3>
<div class="info-row"><span class="info-label">OS:</span><span class="info-value">$($script:Report.OS.Caption)</span></div>
<div class="info-row"><span class="info-label">Build:</span><span class="info-value">$($script:Report.OS.Build)</span></div>
<div class="info-row"><span class="info-label">Архітектура:</span><span class="info-value">$($script:Report.OS.Architecture)</span></div>
<div class="info-row"><span class="info-label">PowerShell:</span><span class="info-value">$($script:Report.PowerShell.Version)</span></div>
<div class="info-row"><span class="info-label">.NET:</span><span class="info-value">$($script:Report.DotNet.v4)</span></div>
<div class="info-row"><span class="info-label">Uptime:</span><span class="info-value">$($script:Report.OS.UptimeDays) днів</span></div>
</div>
<div class="card"><h3>🧠 Процесор та пам'ять</h3>
<div class="info-row"><span class="info-label">CPU:</span><span class="info-value">$($script:Report.Hardware.CPU.Name)</span></div>
<div class="info-row"><span class="info-label">Ядра/потоки:</span><span class="info-value">$($script:Report.Hardware.CPU.Cores)/$($script:Report.Hardware.CPU.LogicalProcessors)</span></div>
<div class="info-row"><span class="info-label">Завантаження CPU:</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$($script:Report.Hardware.CPU.LoadPercent)%">$($script:Report.Hardware.CPU.LoadPercent)%</div></div></span></div>
<div class="info-row"><span class="info-label">RAM:</span><span class="info-value">$($script:Report.Hardware.RAM.TotalGB) GB</span></div>
<div class="info-row"><span class="info-label">RAM використано:</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$($script:Report.Hardware.RAM.UsedPercent)%">$($script:Report.Hardware.RAM.UsedPercent)%</div></div></span></div>
</div>
<div class="card"><h3>💿 Диски</h3>
<div class="info-row"><span class="info-label">Всього місця:</span><span class="info-value">$(Format-Size $script:Report.Hardware.Disks.TotalGB)</span></div>
<div class="info-row"><span class="info-label">Вільно місця:</span><span class="info-value">$(Format-Size $script:Report.Hardware.Disks.FreeGB)</span></div>
<div class="info-row"><span class="info-label">Вільно %:</span><span class="info-value"><div class="progress-bar"><div class="progress-fill" style="width:$($script:Report.Hardware.Disks.FreePercent)%">$($script:Report.Hardware.Disks.FreePercent)%</div></div></span></div>
$storageHtmlSection
</div>
<div class="card"><h3>🌐 Мережа</h3>
<div class="info-row"><span class="info-label">Хостнейм:</span><span class="info-value">$($script:Report.Network.General.Hostname)</span></div>
<div class="info-row"><span class="info-label">Домен:</span><span class="info-value">$($script:Report.Network.General.Domain)</span></div>
<div class="info-row"><span class="info-label">IPv4:</span><span class="info-value">$($script:Report.Network.IP.IPv4 -join ', ')</span></div>
<div class="info-row"><span class="info-label">Шлюз:</span><span class="info-value">$($script:Report.Network.Routing.DefaultGateway)</span></div>
<div class="info-row"><span class="info-label">DNS:</span><span class="info-value">$($script:Report.Network.Routing.DNSServers -join ', ')</span></div>
</div>
<div class="card"><h3>🔒 Безпека</h3>
<div class="info-row"><span class="info-label">UAC:</span><span class="info-value">$(if($script:Report.Security.UAC.Enabled){'Ввімкнено'}else{'Вимкнено'})</span></div>
<div class="info-row"><span class="info-label">RDP:</span><span class="info-value">$(if($script:Report.Security.RemoteAccess.RDPEnabled){'Ввімкнено'}else{'Вимкнено'})</span></div>
<div class="info-row"><span class="info-label">Антивірус:</span><span class="info-value">$($script:Report.Security.Antivirus.Product)</span></div>
</div>
</div>
<h2><span class="section-icon">📈</span>Статистика</h2>
<div class="grid"><div class="card">
<div class="info-row"><span class="info-label">Процеси:</span><span class="info-value">$($script:Report.Processes.Total)</span></div>
<div class="info-row"><span class="info-label">Служб запущено:</span><span class="info-value">$($script:Report.Services.Running)/$($script:Report.Services.Total)</span></div>
<div class="info-row"><span class="info-label">Автоматичних служб зупинено:</span><span class="info-value">$($script:Report.Services.AutomaticStopped.Count)</span></div>
<div class="info-row"><span class="info-label">Помилок System ($EventLogDays дн.):</span><span class="info-value">$($script:Report.EventLogs.SystemErrors)</span></div>
<div class="info-row"><span class="info-label">Попереджень System ($EventLogDays дн.):</span><span class="info-value">$($script:Report.EventLogs.SystemWarnings)</span></div>
<div class="info-row"><span class="info-label">Встановлено ПЗ:</span><span class="info-value">$($script:Report.Software.Installed.Count)</span></div>
<div class="info-row"><span class="info-label">Локальних адмінів:</span><span class="info-value">$($script:Report.Users.LocalAdmins.Count)</span></div>
</div></div>
<h2><span class="section-icon">🔎</span>Findings</h2><table><tr><th>Severity</th><th>Category</th><th>Message</th><th>Recommendation</th></tr>$findingsRows</table>
<h2><span class="section-icon">🛠️</span>Помилки збору даних</h2><table><tr><th>Time</th><th>Section</th><th>Message</th></tr>$errorsRows</table>
</div>
<div class="footer"><p>BRAVO SYSTEM REPORT v$ScriptVersion | $outputDir</p></div>
</div></body></html>
"@
        $htmlContent | Out-File $htmlPath -Encoding utf8
        $script:Report.GeneratedFiles += $htmlPath
        Write-Host "  $IconHtml HTML: $baseFileName.html" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Export.Html' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка HTML: $($_.Exception.Message)" -ForegroundColor Red
    }
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
                [PSCustomObject]@{Parameter='Processes'; Value=$script:Report.Processes.Total}
                [PSCustomObject]@{Parameter='Running_Services'; Value=$script:Report.Services.Running}
                [PSCustomObject]@{Parameter='AutomaticStoppedServices'; Value=$script:Report.Services.AutomaticStopped.Count}
                [PSCustomObject]@{Parameter='Errors_24h'; Value=$script:Report.EventLogs.SystemErrors24h}
                [PSCustomObject]@{Parameter='Errors_ProfileDays'; Value=$script:Report.EventLogs.SystemErrors}
                [PSCustomObject]@{Parameter='Installed_Software'; Value=$script:Report.Software.Installed.Count}
                [PSCustomObject]@{Parameter='Local_Admins'; Value=$script:Report.Users.LocalAdmins.Count}
                [PSCustomObject]@{Parameter='Findings'; Value=$script:Report.Health.Findings.Count}
                [PSCustomObject]@{Parameter='CollectionErrors'; Value=$script:Report.CollectionErrors.Count}
            )

            $csvData | Export-Csv $csvPath -NoTypeInformation -Encoding utf8
            $script:Report.GeneratedFiles += $csvPath
            Write-Host "  $IconCsv CSV: $BaseFileName.csv" -ForegroundColor Green
        } catch {
            Add-AuditError -Section 'Export.Csv' -Message $_.Exception.Message
            Write-Host "  $IconError Помилка CSV: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}


# ============================================================
# MODULE: src/53-Export-Zip.ps1
# ============================================================

# MODULE: 53-Export-Zip.ps1
# Експорт BRAVO SYSTEM REPORT у ZIP.

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
        try {
            $zipPath = Join-Path $OutputDir "$BaseFileName.zip"
            Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop

            if (Test-Path -LiteralPath $zipPath) {
                Remove-Item -LiteralPath $zipPath -Force
            }

            $zipStream = New-Object System.IO.FileStream($zipPath, [System.IO.FileMode]::Create)
            $zipArchive = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)

            foreach ($file in $script:Report.GeneratedFiles) {
                if (Test-Path -LiteralPath $file) {
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $file, (Split-Path $file -Leaf), [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
                }
            }

            $zipArchive.Dispose()
            $zipStream.Dispose()

            $script:Report.GeneratedFiles += $zipPath
            Write-Host "  $IconZip ZIP: $BaseFileName.zip" -ForegroundColor Green
        } catch {
            Add-AuditError -Section 'Export.Zip' -Message $_.Exception.Message
            Write-Host "  $IconError Помилка створення ZIP: $($_.Exception.Message)" -ForegroundColor Red
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
            Add-AuditError -Section 'Export.Email' -Message $_.Exception.Message
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
$ScriptVersion = "0.3.4"

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
        if ($Zip) { $arguments += '-Zip' }
        if ($NoEmoji) { $arguments += '-NoEmoji' }
        if ($NoPause) { $arguments += '-NoPause' }
        if ($NoOpenFolder) { $arguments += '-NoOpenFolder' }
        if ($EmailTo) { $arguments += "-EmailTo `"$EmailTo`"" }
        if ($EmailFrom) { $arguments += "-EmailFrom `"$EmailFrom`"" }
        if ($SmtpServer) { $arguments += "-SmtpServer `"$SmtpServer`"" }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`" $($arguments -join ' ')"
        $psi.Verb = 'runas'
        $psi.WorkingDirectory = $ScriptDirectory

        try {
            [System.Diagnostics.Process]::Start($psi) | Out-Null
            exit 0
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

# --- .NET ---
try {
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full') {
        $release = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue).Release
        if ($release -ge 533320) { $script:Report.DotNet.v4 = '4.8.1+' }
        elseif ($release -ge 528040) { $script:Report.DotNet.v4 = '4.8' }
        elseif ($release -ge 461808) { $script:Report.DotNet.v4 = '4.7.2+' }
        elseif ($release) { $script:Report.DotNet.v4 = "Release $release" }
    }
} catch {
    Add-AuditError -Section 'DotNet' -Message $_.Exception.Message
}

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

# --- Health score ---
Update-BravoHealthScore

# ============================================================
# ЗБЕРЕЖЕННЯ ЗВІТІВ
# ============================================================

try {
    $outputDir = Resolve-AuditOutputPath -RequestedPath $OutputPath -DefaultPath $ScriptDirectory
} catch {
    Add-AuditError -Section 'OutputPath' -Message $_.Exception.Message
    $outputDir = $ScriptDirectory
}

$script:Report.OutputPath = $outputDir
$baseFileName = "BravoSystemReport_$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

Write-Host ''
Write-Host '=== ГЕНЕРАЦІЯ ЗВІТІВ ===' -ForegroundColor Cyan
Write-Host ''
Write-Host "$IconFolder Збереження: $outputDir" -ForegroundColor Cyan

# JSON
Export-BravoJsonReport -OutputDir $outputDir -BaseFileName $baseFileName

# HTML
Export-BravoHtmlReport -OutputDir $outputDir -BaseFileName $baseFileName -JSONOnly $JSONOnly -EventLogDays $EventLogDays -Profile $Profile -ScriptVersion $ScriptVersion

# CSV
Export-BravoCsvReport -OutputDir $outputDir -BaseFileName $baseFileName -CSV $CSV

# ZIP
Export-BravoZipReport -OutputDir $outputDir -BaseFileName $baseFileName -Zip $Zip

# Email
Send-BravoEmailReport -EmailTo $EmailTo -EmailFrom $EmailFrom -SmtpServer $SmtpServer

# Фінал
$elapsedSeconds = [Math]::Round(((Get-Date) - $ScriptStartTime).TotalSeconds, 2)

Write-Host ''
Write-Host '=== АУДИТ МАШИНИ ЗАВЕРШЕНО ===' -ForegroundColor Green
Write-Host ''
Write-Host "$IconFolder Звіти збережено: $outputDir" -ForegroundColor Cyan
Write-Host "$IconJson JSON: $baseFileName.json" -ForegroundColor White
if (-not $JSONOnly) { Write-Host "$IconHtml HTML: $baseFileName.html" -ForegroundColor White }
if ($CSV) { Write-Host "$IconCsv CSV: $baseFileName.csv" -ForegroundColor White }
if ($Zip) { Write-Host "$IconZip ZIP: $baseFileName.zip" -ForegroundColor White }
Write-Host "Оцінка стану: $($script:Report.Health.Score)/100 ($($script:Report.Health.Status))" -ForegroundColor Cyan
Write-Host "Знахідки: $($script:Report.Health.Findings.Count); помилки збору: $($script:Report.CollectionErrors.Count)" -ForegroundColor Cyan
Write-Host "Час виконання: $elapsedSeconds сек" -ForegroundColor Cyan
Write-Host ''

if (-not $NoOpenFolder) {
    try { Start-Process explorer.exe -ArgumentList "`"$outputDir`"" -ErrorAction SilentlyContinue } catch {
        Add-AuditError -Section 'OpenFolder' -Message $_.Exception.Message
    }
}

if (-not $NoPause) { Show-Pause }
exit 0

