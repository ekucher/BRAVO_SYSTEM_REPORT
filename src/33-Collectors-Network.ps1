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