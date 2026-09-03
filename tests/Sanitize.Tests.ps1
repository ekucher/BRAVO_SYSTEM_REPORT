# MODULE: tests/Sanitize.Tests.ps1
# Pester-тести для src/45-Sanitize.ps1 (P1/v0.4.3 Safe Sharing).

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\45-Sanitize.ps1')

    function New-BravoFakeReport {
        [ordered]@{
            ComputerName = 'REAL-PC'
            OutputPath = 'C:\Users\jdoe\Reports'
            Dashboard = [ordered]@{ Header = [ordered]@{ ComputerName = 'REAL-PC' } }
            Meta = [ordered]@{ UserName = 'jdoe'; UserDomainName = 'CORP' }
            Hardware = [ordered]@{
                ComputerSystem = [ordered]@{ Domain = 'corp.local' }
                Motherboard = [ordered]@{ Manufacturer = 'ASUS'; Product = 'ROG STRIX'; SerialNumber = 'SN-MB-1'; Version = 'Rev 1.0' }
                RAM = [ordered]@{ Modules = @([PSCustomObject]@{ SerialNumber = 'SN-RAM-1' }) }
                Disks = [ordered]@{
                    PhysicalDisks = @([PSCustomObject]@{ SerialNumber = 'SN-DISK-1' })
                    Deep = [PSCustomObject]@{ Disks = @([PSCustomObject]@{ SerialNumber = 'SN-DEEPDISK-1' }) }
                }
                Monitors = @([PSCustomObject]@{ SerialNumber = 'SN-MONITOR-1'; Model = 'XG27ACS' })
            }
            BIOS = [ordered]@{ SerialNumber = 'SN-BIOS-1' }
            Services = [ordered]@{
                AutomaticStopped = @(
                    [PSCustomObject]@{ Name = 'SvcA'; DisplayName = 'Service A'; StartName = 'CORP\svc-account' }
                    [PSCustomObject]@{ Name = 'SvcB'; DisplayName = 'Service B'; StartName = 'LocalSystem' }
                    [PSCustomObject]@{ Name = 'SvcC'; DisplayName = 'Service C'; StartName = 'NT AUTHORITY\NETWORK SERVICE' }
                )
            }
            Network = [ordered]@{
                General = [ordered]@{ Hostname = 'REAL-PC'; Domain = 'corp.local' }
                IP = [ordered]@{
                    IPv4 = @('192.168.1.10', '192.168.1.10')
                    PrimaryIPv4 = '192.168.1.10'
                    PrimaryInterface = [PSCustomObject]@{ IPv4 = '192.168.1.10'; Gateway = '192.168.1.1' }
                    PublicIPv4 = '203.0.113.5'
                    PublicIPv4ISP = 'Example ISP LLC'
                    PublicIPv4Organization = 'Example Org'
                    PublicIPv4ASN = 'AS64500'
                    PublicIPv4Country = 'Ukraine'
                    PublicIPv4Region = 'Kyiv Oblast'
                    PublicIPv4City = 'Kyiv'
                    PublicIPv4Timezone = 'Europe/Kyiv'
                }
                Routing = [ordered]@{
                    DefaultGateway = '192.168.1.1'
                    DefaultGateways = @('192.168.1.1')
                    DNSServers = @('192.168.1.1', '192.168.1.2')
                    DNSSuffixSearchOrder = @('corp.local')
                    RoutingTable = @([PSCustomObject]@{ DestinationPrefix = '192.168.1.0/24'; NextHop = '192.168.1.1' })
                }
                Adapters = @([PSCustomObject]@{ MACAddress = 'AA-BB-CC-DD-EE-FF'; IPv4 = @('192.168.1.10'); Gateway = @('192.168.1.1'); DNS = @('192.168.1.1') })
                Connections = [ordered]@{
                    ListeningPorts = @([PSCustomObject]@{ LocalAddress = '192.168.1.10' })
                    EstablishedConnections = @([PSCustomObject]@{ LocalAddress = '192.168.1.10'; RemoteAddress = '192.168.1.20' })
                }
                ARP = @([PSCustomObject]@{ IPAddress = '192.168.1.1'; LinkLayerAddress = '11-22-33-44-55-66' })
                SmbShares = @([PSCustomObject]@{ Name = 'Share1'; Path = 'C:\Users\jdoe\Share1' })
            }
            Users = [ordered]@{ LocalAdmins = @('jdoe', 'Administrator') }
            Security = [ordered]@{
                RemoteAccess = [ordered]@{ AllowedUsers = @('jdoe', 'RemoteWorker') }
                Autoruns = @([PSCustomObject]@{ Name = 'OneDrive'; Command = 'C:\Users\jdoe\AppData\Local\Microsoft\OneDrive\OneDrive.exe /background'; Source = 'Run'; Hive = 'HKCU' })
                ScheduledTasks = @([PSCustomObject]@{ Name = 'MyTask'; Path = '\'; State = 'Ready'; Author = 'CORP\jdoe'; Execute = 'C:\Users\jdoe\script.exe'; Arguments = ''; IsMicrosoftDefault = $false })
            }
            Software = [ordered]@{ Installed = @([PSCustomObject]@{ InstallLocation = 'C:\Users\jdoe\AppData\Local\SomeApp' }) }
        }
    }
}

Describe 'New-BravoSanitizeMasker' {
    It 'та сама вхідна строка завжди дає той самий токен' {
        $masker = New-BravoSanitizeMasker -Prefix 'TEST'
        (& $masker 'value-a') | Should -Be (& $masker 'value-a')
    }

    It 'різні вхідні значення дають різні токени з наростаючим номером' {
        $masker = New-BravoSanitizeMasker -Prefix 'TEST'
        (& $masker 'value-a') | Should -Be 'REDACTED-TEST-1'
        (& $masker 'value-b') | Should -Be 'REDACTED-TEST-2'
    }

    It 'порожнє/null значення повертається без змін (нема що маскувати)' {
        $masker = New-BravoSanitizeMasker -Prefix 'TEST'
        (& $masker '') | Should -Be ''
        (& $masker $null) | Should -Be $null
    }
}

Describe 'Invoke-BravoReportSanitization -Level Basic' {
    BeforeEach {
        $script:report = New-BravoFakeReport
        Invoke-BravoReportSanitization -Report $script:report -Level 'Basic' | Out-Null
    }

    It 'маскує ComputerName у всіх трьох місцях однаково' {
        $script:report.ComputerName | Should -Match '^REDACTED-COMPUTERNAME-'
        $script:report.ComputerName | Should -Be $script:report.Dashboard.Header.ComputerName
        $script:report.ComputerName | Should -Be $script:report.Network.General.Hostname
    }

    It 'маскує user name і domain' {
        $script:report.Meta.UserName | Should -Match '^REDACTED-USER-'
        $script:report.Meta.UserDomainName | Should -Match '^REDACTED-DOMAIN-'
        $script:report.Hardware.ComputerSystem.Domain | Should -Match '^REDACTED-DOMAIN-'
    }

    It 'маскує DNS suffix і public IPv4' {
        $script:report.Network.Routing.DNSSuffixSearchOrder[0] | Should -Match '^REDACTED-DNSSUFFIX-'
        $script:report.Network.IP.PublicIPv4 | Should -Match '^REDACTED-PUBLIC-IP-'
    }

    It 'маскує MAC-адреси і серійні номери (BIOS, RAM, PhysicalDisks, Storage Deep)' {
        $script:report.Network.Adapters[0].MACAddress | Should -Match '^REDACTED-MAC-'
        $script:report.BIOS.SerialNumber | Should -Match '^REDACTED-SERIAL-'
        $script:report.Hardware.RAM.Modules[0].SerialNumber | Should -Match '^REDACTED-SERIAL-'
        $script:report.Hardware.Disks.PhysicalDisks[0].SerialNumber | Should -Match '^REDACTED-SERIAL-'
        $script:report.Hardware.Disks.Deep.Disks[0].SerialNumber | Should -Match '^REDACTED-SERIAL-'
    }

    It 'маскує серійний номер монітора (v0.5.0-tail), Model лишається' {
        $script:report.Hardware.Monitors[0].SerialNumber | Should -Match '^REDACTED-SERIAL-'
        $script:report.Hardware.Monitors[0].Model | Should -Be 'XG27ACS'
    }

    It 'маскує серійний номер материнської плати (Release Blocker Fixes v0.6.1), Manufacturer/Product лишаються' {
        $script:report.Hardware.Motherboard.SerialNumber | Should -Match '^REDACTED-SERIAL-'
        $script:report.Hardware.Motherboard.Manufacturer | Should -Be 'ASUS'
        $script:report.Hardware.Motherboard.Product | Should -Be 'ROG STRIX'
    }

    It 'маскує Report.OutputPath (Release Blocker Fixes v0.6.1)' {
        $script:report.OutputPath | Should -Match '^REDACTED-PATH-'
    }

    It 'маскує StartName облікових записів служб (Release Blocker Fixes v0.6.1), крім вбудованих ідентичностей' {
        $script:report.Services.AutomaticStopped[0].StartName | Should -Match '^REDACTED-ADMIN-'
        $script:report.Services.AutomaticStopped[1].StartName | Should -Be 'LocalSystem'
        $script:report.Services.AutomaticStopped[2].StartName | Should -Be 'NT AUTHORITY\NETWORK SERVICE'
    }

    It 'маскує MAC-адреси в ARP-кеші (v0.5.0) навіть у Basic, IP-адреса в ARP лишається' {
        $script:report.Network.ARP[0].LinkLayerAddress | Should -Match '^REDACTED-MAC-'
        $script:report.Network.ARP[0].IPAddress | Should -Be '192.168.1.1'
    }

    It 'маскує Command в Autoruns (v0.5.0-tail) навіть у Basic, Name лишається' {
        $script:report.Security.Autoruns[0].Command | Should -Match '^REDACTED-PATH-'
        $script:report.Security.Autoruns[0].Name | Should -Be 'OneDrive'
    }

    It 'маскує Author і Execute у ScheduledTasks (v0.5.0-tail) навіть у Basic, Name лишається' {
        $script:report.Security.ScheduledTasks[0].Author | Should -Match '^REDACTED-ADMIN-'
        $script:report.Security.ScheduledTasks[0].Execute | Should -Match '^REDACTED-PATH-'
        $script:report.Security.ScheduledTasks[0].Name | Should -Be 'MyTask'
    }

    It 'маскує шлях SMB share (v0.5.0-tail) навіть у Basic' {
        $script:report.Network.SmbShares[0].Path | Should -Match '^REDACTED-PATH-'
        $script:report.Network.SmbShares[0].Name | Should -Be 'Share1'
    }

    It 'маскує локальних адміністраторів, дозволених RDP-користувачів і install path ПЗ' {
        $script:report.Users.LocalAdmins | Should -Match '^REDACTED-ADMIN-'
        $script:report.Security.RemoteAccess.AllowedUsers | Should -Match '^REDACTED-ADMIN-'
        $script:report.Software.Installed[0].InstallLocation | Should -Match '^REDACTED-PATH-'
    }

    It 'НЕ маскує приватні IPv4 у Basic-режимі' {
        $script:report.Network.IP.PrimaryIPv4 | Should -Be '192.168.1.10'
        $script:report.Network.Routing.DefaultGateway | Should -Be '192.168.1.1'
    }

    It 'НЕ маскує GeoIP/ISP-метадані у Basic-режимі (задокументована поведінка — лише Strict)' {
        $script:report.Network.IP.PublicIPv4ISP | Should -Be 'Example ISP LLC'
        $script:report.Network.IP.PublicIPv4Organization | Should -Be 'Example Org'
        $script:report.Network.IP.PublicIPv4ASN | Should -Be 'AS64500'
        $script:report.Network.IP.PublicIPv4Country | Should -Be 'Ukraine'
        $script:report.Network.IP.PublicIPv4Region | Should -Be 'Kyiv Oblast'
        $script:report.Network.IP.PublicIPv4City | Should -Be 'Kyiv'
        $script:report.Network.IP.PublicIPv4Timezone | Should -Be 'Europe/Kyiv'
    }
}

Describe 'Invoke-BravoReportSanitization -Level Strict' {
    BeforeEach {
        $script:report = New-BravoFakeReport
        Invoke-BravoReportSanitization -Report $script:report -Level 'Strict' | Out-Null
    }

    It 'маскує приватні IPv4 (IP-масив, PrimaryIPv4, PrimaryInterface, adapters, routing, listening ports)' {
        $script:report.Network.IP.IPv4 | ForEach-Object { $_ | Should -Match '^REDACTED-PRIVATE-IP-' }
        $script:report.Network.IP.PrimaryIPv4 | Should -Match '^REDACTED-PRIVATE-IP-'
        $script:report.Network.IP.PrimaryInterface.IPv4 | Should -Match '^REDACTED-PRIVATE-IP-'
        $script:report.Network.IP.PrimaryInterface.Gateway | Should -Match '^REDACTED-PRIVATE-IP-'
        $script:report.Network.Routing.DefaultGateway | Should -Match '^REDACTED-PRIVATE-IP-'
        $script:report.Network.Routing.DNSServers | ForEach-Object { $_ | Should -Match '^REDACTED-PRIVATE-IP-' }
        $script:report.Network.Adapters[0].IPv4[0] | Should -Match '^REDACTED-PRIVATE-IP-'
        $script:report.Network.Connections.ListeningPorts[0].LocalAddress | Should -Match '^REDACTED-PRIVATE-IP-'
    }

    It 'маскує LocalAddress/RemoteAddress в EstablishedConnections (v0.5.0-tail), лише в Strict' {
        $script:report.Network.Connections.EstablishedConnections[0].LocalAddress | Should -Match '^REDACTED-PRIVATE-IP-'
        $script:report.Network.Connections.EstablishedConnections[0].RemoteAddress | Should -Match '^REDACTED-PRIVATE-IP-'
    }

    It 'маскує IP-адреси в ARP-кеші і Routing table (v0.5.0), лише в Strict' {
        $script:report.Network.ARP[0].IPAddress | Should -Match '^REDACTED-PRIVATE-IP-'
        $script:report.Network.Routing.RoutingTable[0].DestinationPrefix | Should -Match '^REDACTED-PRIVATE-IP-'
        $script:report.Network.Routing.RoutingTable[0].NextHop | Should -Match '^REDACTED-PRIVATE-IP-'
    }

    It 'той самий IPv4, що зустрічається кілька разів (masив і PrimaryIPv4), маскується в один і той самий токен' {
        $script:report.Network.IP.IPv4[0] | Should -Be $script:report.Network.IP.IPv4[1]
        $script:report.Network.IP.IPv4[0] | Should -Be $script:report.Network.IP.PrimaryIPv4
    }

    It 'все з Basic лишається замаскованим і в Strict' {
        $script:report.ComputerName | Should -Match '^REDACTED-COMPUTERNAME-'
        $script:report.Network.IP.PublicIPv4 | Should -Match '^REDACTED-PUBLIC-IP-'
    }

    It 'редагує GeoIP/ISP-метадані (Release Sync & Governance Fixes, v0.6.1) — лише в Strict' {
        $script:report.Network.IP.PublicIPv4ISP | Should -Be 'REDACTED-GEOIP'
        $script:report.Network.IP.PublicIPv4Organization | Should -Be 'REDACTED-GEOIP'
        $script:report.Network.IP.PublicIPv4ASN | Should -Be 'REDACTED-GEOIP'
        $script:report.Network.IP.PublicIPv4Country | Should -Be 'REDACTED-GEOIP'
        $script:report.Network.IP.PublicIPv4Region | Should -Be 'REDACTED-GEOIP'
        $script:report.Network.IP.PublicIPv4City | Should -Be 'REDACTED-GEOIP'
        $script:report.Network.IP.PublicIPv4Timezone | Should -Be 'REDACTED-GEOIP'
    }
}

Describe 'Invoke-BravoReportSanitizationGated (fail-closed gate, Release Blocker Fixes v0.6.1)' {
    It 'успішне маскування — Success=$true, порожній ErrorMessage' {
        $report = New-BravoFakeReport
        $result = Invoke-BravoReportSanitizationGated -Report $report -Level 'Basic'
        $result.Success | Should -Be $true
        $result.ErrorMessage | Should -Be ''
    }

    It 'збій усередині Invoke-BravoReportSanitization — Success=$false, виняток НЕ прокидається назовні' {
        Mock Invoke-BravoReportSanitization { throw 'Симульований збій маскування посередині проходу' }
        $report = New-BravoFakeReport
        { $script:gatedResult = Invoke-BravoReportSanitizationGated -Report $report -Level 'Basic' } | Should -Not -Throw
        $script:gatedResult.Success | Should -Be $false
        $script:gatedResult.ErrorMessage | Should -Match 'Симульований збій'
    }
}

Describe 'Sanitize leakage — жодне чутливе значення НЕ потрапляє в серіалізований JSON (Strict)' {
    It 'sentinel-значення відсутні в ConvertTo-Json виводі після Strict-санітизації' {
        $report = New-BravoFakeReport
        $report.ComputerName = 'HOSTNAME_SENTINEL'
        $report.Dashboard.Header.ComputerName = 'HOSTNAME_SENTINEL'
        $report.Network.General.Hostname = 'HOSTNAME_SENTINEL'
        $report.Meta.UserName = 'USERNAME_SENTINEL'
        $report.Meta.UserDomainName = 'DOMAIN_SENTINEL'
        $report.Hardware.Motherboard.SerialNumber = 'MOTHERBOARD_SERIAL_SENTINEL'
        $report.Services.AutomaticStopped[0].StartName = 'CORP\SERVICE_ACCOUNT_SENTINEL'
        $report.Network.IP.PublicIPv4 = '203.0.113.99'
        $report.Network.IP.PublicIPv4ISP = 'ISP_SENTINEL'
        $report.Network.IP.PublicIPv4City = 'CITY_SENTINEL'
        $report.Network.IP.PrimaryIPv4 = '10.20.30.40'
        $report.OutputPath = 'C:\Users\SECRETUSER\Reports'

        Invoke-BravoReportSanitization -Report $report -Level 'Strict' | Out-Null
        $json = $report | ConvertTo-Json -Depth 10

        $json | Should -Not -Match 'HOSTNAME_SENTINEL'
        $json | Should -Not -Match 'USERNAME_SENTINEL'
        $json | Should -Not -Match 'DOMAIN_SENTINEL'
        $json | Should -Not -Match 'MOTHERBOARD_SERIAL_SENTINEL'
        $json | Should -Not -Match 'SERVICE_ACCOUNT_SENTINEL'
        $json | Should -Not -Match '203\.0\.113\.99'
        $json | Should -Not -Match 'ISP_SENTINEL'
        $json | Should -Not -Match 'CITY_SENTINEL'
        $json | Should -Not -Match '10\.20\.30\.40'
        $json | Should -Not -Match 'SECRETUSER'
        $json | Should -Not -Match 'C:\\\\Users\\\\SECRETUSER'
    }
}
