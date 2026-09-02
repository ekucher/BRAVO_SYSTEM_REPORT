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
    }

    return $Report
}
