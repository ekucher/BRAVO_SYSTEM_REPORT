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
# Fail-closed (v0.6.1): маскування виконується через
# Invoke-BravoReportSanitizationGated — якщо воно впаде посередині проходу
# (частина полів замаскована, частина ні), виклик у src/90-Main.ps1
# перериває ВЕСЬ export-пайплайн (жоден звіт не пишеться на диск), а не
# лише реєструє ExportError і продовжує з частково замаскованими даними.

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

# Чиста функція: маскує лише адресоподібні токени у комма-роздільному
# Security.RemoteAccess.FirewallScope (Get-NetFirewallAddressFilter.RemoteAddress
# join, src/34-Collectors-Security.ps1) — значення тут суміш реальних
# приватних IP/CIDR/діапазонів (напр. "10.21.0.0/24") і семантичних
# ключових слів Windows Firewall ("Any", "LocalSubnet", "DefaultGateway"
# тощо), тому суцільне маскування всього рядка одним маскером зробило б
# "Any"/"LocalSubnet" нечитабельними без жодної privacy-користі (P1,
# exact-head review Phase 10).
function ConvertTo-BravoSanitizedFirewallScope {
    [CmdletBinding()]
    param(
        [AllowNull()][AllowEmptyString()][string]$Scope,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Masker
    )

    if ([string]::IsNullOrWhiteSpace($Scope)) { return $Scope }

    # Windows Firewall семантичні ключові слова для RemoteAddress
    # (задокументовано в Get-NetFirewallAddressFilter/netsh advfirewall) —
    # не адреси, не потребують і не повинні маскуватись. 'RmtIntranet' —
    # правильне написання токена (не 'RemoteIntranet', виправлено
    # фреш-ревʼю Phase 10); PlayToDevice/PlayToRenderers/LocalSubnet6 додані
    # як додаткові задокументовані токени.
    $knownScopeKeywords = @(
        'Any', 'LocalSubnet', 'LocalSubnet6', 'DNS', 'DHCP', 'WINS', 'DefaultGateway',
        'Intranet', 'RmtIntranet', 'Internet', 'Ply2Renders', 'PlayToDevice', 'PlayToRenderers'
    )

    $tokens = $Scope -split ',\s*'
    $maskedTokens = foreach ($token in $tokens) {
        if ($token -in $knownScopeKeywords) {
            $token
        } else {
            & $Masker $token
        }
    }

    return ($maskedTokens -join ', ')
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
    $maskWsus     = New-BravoSanitizeMasker -Prefix 'WSUS'

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

        # GeoIP/ISP-метадані (Release Sync & Governance Fixes, v0.6.1) —
        # похідні від PublicIPv4 (ipapi.co lookup, src/33-Collectors-Network.ps1),
        # самі по собі ідентифікують локацію/провайдера машини навіть якщо
        # сама IP-адреса замаскована вище. Лише Strict (Basic-поведінку
        # свідомо не чіпаємо — див. header-коментар цього файлу): не
        # повторюваний ідентифікатор на кшталт MAC/serial (один профіль на
        # звіт), тому фіксований токен без per-value унікальності.
        if ($Level -eq 'Strict') {
            foreach ($geoField in @('PublicIPv4ISP', 'PublicIPv4Organization', 'PublicIPv4ASN', 'PublicIPv4Country', 'PublicIPv4Region', 'PublicIPv4City', 'PublicIPv4Timezone')) {
                if ($Report.Network.IP.$geoField) { $Report.Network.IP.$geoField = 'REDACTED-GEOIP' }
            }
        }
    }

    # --- MAC-адреси + per-adapter DNS suffix ---
    if ($Report.Network -and $Report.Network.Adapters) {
        foreach ($adapter in @($Report.Network.Adapters)) {
            if ($adapter.MACAddress) { $adapter.MACAddress = & $maskMac $adapter.MACAddress }

            # Per-adapter DNSSuffixSearchOrder (Release Blocker Fixes v0.6.1) —
            # та сама категорія DNSSUFFIX, що й Routing.DNSSuffixSearchOrder
            # вище: той самий маскер, тож однаковий suffix у Routing і в
            # адаптера отримує однаковий токен. Маскується завжди (Basic) —
            # DNS suffix ідентифікує домен/організацію так само незалежно від
            # того, в якій секції звіту він з'явився.
            if ($adapter.DNSSuffixSearchOrder) {
                $adapter.DNSSuffixSearchOrder = @($adapter.DNSSuffixSearchOrder | ForEach-Object { & $maskDnsSuffix $_ })
            }
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

        # SmartPredictFailures[].InstanceName (MSStorageDriver_FailurePredictStatus,
        # root\wmi legacy SMART API, Get-BravoStorageDeepAudit) — PNP device
        # instance path (напр. "IDE\DiskWDC_WD10EZEX...\4&2413cfbc&0&0.0.0"),
        # та сама категорія SERIAL, що й BIOS/RAM/Disks/Monitors/Motherboard
        # вище (Issue #105, Phase 10.1): унікальний ідентифікатор фізичного
        # пристрою, часто вбудовує vendor/product/серійноподібний рядок
        # контролера чи диска. Той самий raw-рядок інтерполюється у вільний
        # текст Health.Findings[].Message (Storage.SMART finding,
        # src/32-Collectors-Storage.ps1) — маскується тим самим маскером
        # (консистентний токен) і там, інакше серійний ідентифікатор просто
        # дублюється в іншому полі того самого звіту.
        if ($storageDeep -and $storageDeep.SmartPredictFailures) {
            foreach ($predictEntry in @($storageDeep.SmartPredictFailures)) {
                if (-not $predictEntry.InstanceName) { continue }

                $rawInstanceName = $predictEntry.InstanceName
                $maskedInstanceName = & $maskSerial $rawInstanceName
                $predictEntry.InstanceName = $maskedInstanceName

                if ($Report.Health -and $Report.Health.Findings) {
                    foreach ($findingEntry in @($Report.Health.Findings)) {
                        if ($findingEntry.Message -and $findingEntry.Message.Contains($rawInstanceName)) {
                            $findingEntry.Message = $findingEntry.Message.Replace($rawInstanceName, $maskedInstanceName)
                        }
                    }
                }
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

    # Материнська плата (Hardware.Motherboard.SerialNumber, Release Blocker
    # Fixes v0.6.1) — та сама категорія SERIAL, раніше пропущена поряд з
    # BIOS/RAM/Disks/Monitors, хоча поле збирається тим самим колектором.
    if ($Report.Hardware -and $Report.Hardware.Motherboard -and $Report.Hardware.Motherboard.SerialNumber) {
        $Report.Hardware.Motherboard.SerialNumber = & $maskSerial $Report.Hardware.Motherboard.SerialNumber
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

    # --- Облікові записи автоматичних служб (Services.AutomaticStopped[].StartName,
    # Release Blocker Fixes v0.6.1) — та сама категорія ADMIN, що й
    # LocalAdmins/AllowedUsers/ScheduledTasks.Author вище. Вбудовані системні
    # ідентичності (LocalSystem, NT AUTHORITY\*) НЕ є персональними обліковими
    # записами — маскувати їх лише додало б шуму без користі для privacy.
    if ($Report.Services -and $Report.Services.AutomaticStopped) {
        $builtInServiceIdentities = @('LocalSystem', 'NT AUTHORITY\SYSTEM', 'NT AUTHORITY\LOCAL SERVICE', 'NT AUTHORITY\NETWORK SERVICE')
        foreach ($service in @($Report.Services.AutomaticStopped)) {
            if ($service.StartName -and $service.StartName -notin $builtInServiceIdentities) {
                $service.StartName = & $maskAdmin $service.StartName
            }
        }
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

    # --- RDP firewall scope (Security.RemoteAccess.FirewallScope, P1
    # exact-head review Phase 10) — та сама категорія PRIVATE-IP, що й решта
    # мережевих адрес вище: RemoteAddress фаєрвол-правила часто містить
    # конкретні внутрішні підмережі/VPN-діапазони, лишені незамаскованими
    # раніше. ConvertTo-BravoSanitizedFirewallScope маскує лише адресоподібні
    # токени, зберігаючи семантичні ключові слова ("Any"/"LocalSubnet")
    # читабельними. Власний блок-умова окремо від "$Level -eq 'Strict' -and
    # $Report.Network" вище (fresh-review Phase 10): це Security-поле, і його
    # маскування не повинно залежати від наявності секції Network у звіті —
    # раніше воно ненавмисно було вкладене в перевірку $Report.Network.
    if ($Level -eq 'Strict' -and $Report.Security -and $Report.Security.RemoteAccess -and $Report.Security.RemoteAccess.FirewallScope) {
        $Report.Security.RemoteAccess.FirewallScope = ConvertTo-BravoSanitizedFirewallScope -Scope $Report.Security.RemoteAccess.FirewallScope -Masker $maskPrivateIP
    }

    # --- SMB shares: шлях може містити username (напр. C:\Users\jdoe\Share) —
    # та сама категорія PATH, що й Software.Installed[].InstallLocation,
    # маскується завжди (Basic), незалежно від рівня.
    if ($Report.Network -and $Report.Network.SmbShares) {
        foreach ($share in @($Report.Network.SmbShares)) {
            if ($share.Path) { $share.Path = & $maskPath $share.Path }
        }
    }

    # --- Updates: встановлені оновлення (InstalledBy) і WSUS-сервер
    # (delta review v0.6.1) — та сама категорія ADMIN, що й LocalAdmins/
    # AllowedUsers/ScheduledTasks.Author: Get-HotFix.InstalledBy зазвичай
    # DOMAIN\user. WSUSServer — внутрішній hostname/URL, ідентифікує
    # організацію так само, як DNS suffix, тому маскується завжди (Basic),
    # окремим маскером (не той самий Counter, що й DNSSUFFIX).
    if ($Report.Updates -and $Report.Updates.Installed -and $Report.Updates.Installed.Recent) {
        foreach ($hotfix in @($Report.Updates.Installed.Recent)) {
            if ($hotfix.InstalledBy) { $hotfix.InstalledBy = & $maskAdmin $hotfix.InstalledBy }
        }
    }
    if ($Report.Updates -and $Report.Updates.WindowsUpdate -and $Report.Updates.WindowsUpdate.WSUSServer) {
        $Report.Updates.WindowsUpdate.WSUSServer = & $maskWsus $Report.Updates.WindowsUpdate.WSUSServer
    }

    # --- Network.WinHttpProxy.RawOutput (P1, exact-head review Phase 10) —
    # сирий вивід `netsh winhttp show proxy` (Full/Deep/Forensic) часто
    # містить внутрішній proxy hostname, bypass-list домени й топологію —
    # та сама категорія ризику, що й WSUSServer вище (внутрішній
    # hostname/URL, ідентифікує організацію). Свідомо Option A (повна
    # редакція фіксованим токеном, а не вибірковий regex-парсинг): сирий
    # текст — діагностична зручність, не контрактне поле схеми, тож
    # вибірковий парсер лише додав би крихкість без реальної користі.
    # Завжди (Basic), не лише Strict — той самий рівень ризику, що й
    # WSUSServer/EventLogs LastMessage вище. Уже розпарсений Status
    # (enum-подібне значення 'Detected'/'Unavailable'/'NotAvailable') не є
    # чутливим і лишається як є.
    if ($Report.Network -and $Report.Network.WinHttpProxy -and $Report.Network.WinHttpProxy.RawOutput -and @($Report.Network.WinHttpProxy.RawOutput).Count -gt 0) {
        $Report.Network.WinHttpProxy.RawOutput = @('REDACTED-WINHTTP-PROXY')
    }
    # Той самий ризик-підклас, що й RawOutput вище (fresh-review Phase 10):
    # Error — це $_.Exception.Message від невдалого виклику netsh, теоретично
    # міг би містити фрагмент команди/шляху; редагується так само на всякий
    # випадок, хоча типовий текст помилки netsh малоймовірно несе топологію.
    # ОКРЕМИЙ токен від RawOutput (друга хвиля фреш-ревʼю Phase 10) — той
    # самий токен для обох робив санітизований JSON неоднозначним: неможливо
    # відрізнити "netsh відпрацював, вивід відредаговано" від "netsh
    # провалився, помилку відредаговано", а це діагностично корисна
    # відмінність навіть у sanitized-звіті.
    if ($Report.Network -and $Report.Network.WinHttpProxy -and $Report.Network.WinHttpProxy.Error) {
        $Report.Network.WinHttpProxy.Error = 'REDACTED-WINHTTP-PROXY-ERROR'
    }

    # --- CollectionErrors/ExportErrors: $_.Exception.Message з довільного
    # виключення (P1, fresh-review Phase 10) — доступ-заборонено, помилки
    # шляхів тощо часто містять реальний шлях/hostname/обліковий запис
    # (напр. "Access to the path 'C:\Users\jdoe\...' is denied"). Той самий
    # ризик-клас, що й EventLogs LastMessage нижче — повна редакція
    # фіксованим токеном, завжди (Basic), той самий підхід.
    # CollectionErrors повністю наповнюється ДО цього одноразового проходу
    # (усі колектори виконуються до Update-BravoHealthScore/Sanitize) — тут
    # покриваються всі записи. ExportErrors можуть з'являтись і ПІСЛЯ цього
    # проходу (export-фаза йде після санітизації) — ці пізніші записи
    # редагуються при додаванні в Add-ExportError (src/90-Main.ps1), що
    # читає той самий $script:SanitizeActive; цей блок тут покриває лише
    # записи, наявні НА МОМЕНТ виклику санітизації (напр. помилку
    # резолюції OutputPath, що трапляється до export-фази).
    if ($Report.CollectionErrors) {
        foreach ($errorEntry in @($Report.CollectionErrors)) {
            if ($errorEntry.Message) { $errorEntry.Message = 'REDACTED-ERROR-MESSAGE' }
        }
    }
    if ($Report.ExportErrors) {
        foreach ($errorEntry in @($Report.ExportErrors)) {
            if ($errorEntry.Message) { $errorEntry.Message = 'REDACTED-ERROR-MESSAGE' }
        }
    }

    # --- EventLogs: сирий текст подій (delta review v0.6.1) — LastMessage
    # (TopErrorSources, per-log LogSummaries.TopProviders, HardwareDiagnostics)
    # — повний необроблений текст події (Security-лог часто містить
    # account/domain/workstation/IP). Повна редакція фіксованим токеном
    # (не per-value масив, як інші поля) — вибірковий парсинг вільного
    # тексту небезпечний і непотрібний, самого факту "яка подія найчастіша"
    # достатньо без розкриття вмісту повідомлення. Завжди (Basic), не лише
    # Strict — той самий рівень ризику, що й DNS suffix/шляхи вище.
    if ($Report.EventLogs) {
        if ($Report.EventLogs.TopErrorSources) {
            foreach ($source in @($Report.EventLogs.TopErrorSources)) {
                if ($source.LastMessage) { $source.LastMessage = 'REDACTED-EVENTLOG-MESSAGE' }
            }
        }
        if ($Report.EventLogs.LogSummaries) {
            foreach ($logSummary in @($Report.EventLogs.LogSummaries)) {
                if ($logSummary.TopProviders) {
                    foreach ($provider in @($logSummary.TopProviders)) {
                        if ($provider.LastMessage) { $provider.LastMessage = 'REDACTED-EVENTLOG-MESSAGE' }
                    }
                }
            }
        }
        if ($Report.EventLogs.HardwareDiagnostics) {
            foreach ($diag in @($Report.EventLogs.HardwareDiagnostics)) {
                if ($diag.LastMessage) { $diag.LastMessage = 'REDACTED-EVENTLOG-MESSAGE' }
            }
        }
    }

    # --- Report.OutputPath (Release Blocker Fixes v0.6.1) — реальний
    # локальний шлях, куди збережено звіти (напр. C:\Users\jdoe\Reports) —
    # та сама категорія PATH, що й InstallLocation/Autoruns/SmbShares. Це
    # поле встановлюється в src/90-Main.ps1 ДО виклику санітизації (щоб
    # маскування встигло його покрити), тому на момент цього виклику вже
    # заповнене.
    if ($Report.OutputPath) { $Report.OutputPath = & $maskPath $Report.OutputPath }

    return $Report
}

# Fail-closed gate (v0.6.1) навколо Invoke-BravoReportSanitization: сама
# функція вище мутує $Report по посиланню (властивість вкладених
# PSCustomObject/hashtable — не value type), тому виняток, кинутий
# ПОСЕРЕДИНІ проходу, залишає $Report у частково замаскованому стані.
# Ця обгортка не намагається відкотити часткові зміни (немає дешевого
# способу без deep-clone усього звіту заздалегідь) — натомість повертає
# Success=$false, і виклик у src/90-Main.ps1 на підставі цього прапорця
# свідомо не пише ЖОДЕН файл на диск, замість ризикувати випадковим
# витоком через недомаскований звіт.
function Invoke-BravoReportSanitizationGated {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Report,

        [ValidateSet('Basic', 'Strict')]
        [string]$Level = 'Basic'
    )

    try {
        Invoke-BravoReportSanitization -Report $Report -Level $Level | Out-Null
        return [PSCustomObject]@{ Success = $true; ErrorMessage = '' }
    } catch {
        return [PSCustomObject]@{ Success = $false; ErrorMessage = $_.Exception.Message }
    }
}
