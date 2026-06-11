# MODULE: 20-ReportModel.ps1
# Створення базової моделі звіту BRAVO SYSTEM REPORT.

function New-BravoReportModel {
    [CmdletBinding()]
    param()

return [ordered]@{
    SchemaVersion = '0.4.1'
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
        }
        Tabs = [ordered]@{
            General = $true
            OS = $true
            Hardware = $true
            Network = $true
            Security = $true
            Services = $true
            Software = $true
        }
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
        RAM = [ordered]@{ TotalGB=0; TotalVisibleMemoryGB=0; FreeGB=0; UsedGB=0; UsedPercent=0; Source=''; Modules=@() }
        Disks = [ordered]@{ FreePercent=0; TotalGB=0; FreeGB=0; Volumes=@(); PhysicalDisks=@() }
    }
    Network = [ordered]@{
        General = [ordered]@{ Hostname=''; Domain='' }
        IP = [ordered]@{
            IPv4=@()
            PrimaryIPv4=''
            PrimaryInterface=$null
            PublicIPv4=''
            PublicIPv4Provider=''
            PublicIPv4CheckedAt=''
            PublicIPv4Status='NotChecked'
        }
        Routing = [ordered]@{ DefaultGateway=''; DefaultGateways=@(); DNSServers=@(); DNSSuffixSearchOrder=@() }
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
