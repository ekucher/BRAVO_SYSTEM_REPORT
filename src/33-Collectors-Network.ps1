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
            $Report.Network.IP.IPv4 = @($bravoOrderedIPv4)
            $Report.Network.IP.PrimaryIPv4 = $bravoPrimaryIPv4
            $Report.Network.IP.PrimaryInterface = $bravoPrimaryNetwork
        } else {
            $Report.Network | Add-Member -NotePropertyName "IPv4" -NotePropertyValue @($bravoOrderedIPv4) -Force
            $Report.Network | Add-Member -NotePropertyName "PrimaryIPv4" -NotePropertyValue $bravoPrimaryIPv4 -Force
            $Report.Network | Add-Member -NotePropertyName "PrimaryInterface" -NotePropertyValue $bravoPrimaryNetwork -Force
            $Report.Network.IP.IPv4 = @($bravoOrderedIPv4)
            $Report.Network.IP.PrimaryIPv4 = $bravoPrimaryIPv4
            $Report.Network.IP.PrimaryInterface = $bravoPrimaryNetwork
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
            $Report.Network.IP.PublicIPv4 = $bravoPublicIPv4Info.IPv4
            $Report.Network.IP.PublicIPv4Provider = $bravoPublicIPv4Info.Provider
            $Report.Network.IP.PublicIPv4CheckedAt = $bravoPublicIPv4Info.CheckedAt
            $Report.Network.IP.PublicIPv4Status = $bravoPublicIPv4Info.Status
        } else {
            $Report.Network | Add-Member -NotePropertyName "PublicIPv4" -NotePropertyValue $bravoPublicIPv4Info.IPv4 -Force
            $Report.Network | Add-Member -NotePropertyName "PublicIPv4Provider" -NotePropertyValue $bravoPublicIPv4Info.Provider -Force
            $Report.Network | Add-Member -NotePropertyName "PublicIPv4CheckedAt" -NotePropertyValue $bravoPublicIPv4Info.CheckedAt -Force
            $Report.Network | Add-Member -NotePropertyName "PublicIPv4Status" -NotePropertyValue $bravoPublicIPv4Info.Status -Force
            $Report.Network.IP.PublicIPv4 = $bravoPublicIPv4Info.IPv4
            $Report.Network.IP.PublicIPv4Provider = $bravoPublicIPv4Info.Provider
            $Report.Network.IP.PublicIPv4CheckedAt = $bravoPublicIPv4Info.CheckedAt
            $Report.Network.IP.PublicIPv4Status = $bravoPublicIPv4Info.Status
        }
    }

    $bravoPublicIPv4ProviderInfo = Get-BravoPublicIPv4ProviderInfo -PublicIPv4 $bravoPublicIPv4Info.IPv4

    if ($Report.Network -and $Report.Network.IP) {
        $Report.Network.IP.PublicIPv4LookupProvider = $bravoPublicIPv4ProviderInfo.LookupProvider
        $Report.Network.IP.PublicIPv4ISP = $bravoPublicIPv4ProviderInfo.ISP
        $Report.Network.IP.PublicIPv4Organization = $bravoPublicIPv4ProviderInfo.Organization
        $Report.Network.IP.PublicIPv4ASN = $bravoPublicIPv4ProviderInfo.ASN
        $Report.Network.IP.PublicIPv4Country = $bravoPublicIPv4ProviderInfo.Country
        $Report.Network.IP.PublicIPv4Region = $bravoPublicIPv4ProviderInfo.Region
        $Report.Network.IP.PublicIPv4City = $bravoPublicIPv4ProviderInfo.City
        $Report.Network.IP.PublicIPv4Timezone = $bravoPublicIPv4ProviderInfo.Timezone
        $Report.Network.IP.PublicIPv4ProviderInfoCheckedAt = $bravoPublicIPv4ProviderInfo.CheckedAt
        $Report.Network.IP.PublicIPv4ProviderInfoStatus = $bravoPublicIPv4ProviderInfo.Status
        $Report.Network.IP.PublicIPv4ProviderInfoError = $bravoPublicIPv4ProviderInfo.Error
    }
    if ($bravoPublicIPv4Info.Status -eq "Detected") {
        if (-not [string]::IsNullOrWhiteSpace([string]$bravoPublicIPv4ProviderInfo.ISP)) {
            Write-Host "  [OK] Public IP: визначено, ISP: $($bravoPublicIPv4ProviderInfo.ISP)" -ForegroundColor Green
        } else {
            Write-Host "  [OK] Public IP: визначено, записано у звіт" -ForegroundColor Green
        }
    } else {
        Write-Host "  [INFO] Public IP: не визначено" -ForegroundColor Yellow
    }
    # BRAVO PUBLIC IP OUTPUT END
    } catch {
        Add-AuditError -Section 'Network' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка мережевих даних: $($_.Exception.Message)" -ForegroundColor Red
    }
}