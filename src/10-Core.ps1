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
