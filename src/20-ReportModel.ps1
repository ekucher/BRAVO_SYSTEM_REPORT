# MODULE: 20-ReportModel.ps1
# Створення базової моделі звіту BRAVO SYSTEM REPORT.

function New-BravoReportModel {
    [CmdletBinding()]
    param()

return [ordered]@{
    SchemaVersion = '0.6.5'
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
        Routing = [ordered]@{ DefaultGateway=''; DefaultGateways=@(); DNSServers=@(); DNSSuffixSearchOrder=@() }
        Adapters = @()
        Connections = [ordered]@{ Established=0; Listening=0; ListeningPorts=@() }
    }
    Security = [ordered]@{
        UAC=[ordered]@{Enabled=$false}
        RemoteAccess=[ordered]@{RDPEnabled=$false}
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
    }
    Users = [ordered]@{ LocalAdmins=@() }
    Processes = [ordered]@{ Total=0; TopMemory=@() }
    Services = [ordered]@{ Total=0; Running=0; AutomaticStopped=@() }
    EventLogs = [ordered]@{ Days=$EventLogDays; SystemErrors=0; SystemWarnings=0; SystemErrors24h=0; SystemWarnings24h=0; TopErrorSources=@() }
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
