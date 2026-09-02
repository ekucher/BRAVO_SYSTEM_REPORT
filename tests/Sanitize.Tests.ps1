# MODULE: tests/Sanitize.Tests.ps1
# Pester-тести для src/45-Sanitize.ps1 (P1/v0.4.3 Safe Sharing).

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\45-Sanitize.ps1')

    function New-BravoFakeReport {
        [ordered]@{
            ComputerName = 'REAL-PC'
            Dashboard = [ordered]@{ Header = [ordered]@{ ComputerName = 'REAL-PC' } }
            Meta = [ordered]@{ UserName = 'jdoe'; UserDomainName = 'CORP' }
            Hardware = [ordered]@{
                ComputerSystem = [ordered]@{ Domain = 'corp.local' }
                RAM = [ordered]@{ Modules = @([PSCustomObject]@{ SerialNumber = 'SN-RAM-1' }) }
                Disks = [ordered]@{
                    PhysicalDisks = @([PSCustomObject]@{ SerialNumber = 'SN-DISK-1' })
                    Deep = [PSCustomObject]@{ Disks = @([PSCustomObject]@{ SerialNumber = 'SN-DEEPDISK-1' }) }
                }
                Monitors = @([PSCustomObject]@{ SerialNumber = 'SN-MONITOR-1'; Model = 'XG27ACS' })
            }
            BIOS = [ordered]@{ SerialNumber = 'SN-BIOS-1' }
            Network = [ordered]@{
                General = [ordered]@{ Hostname = 'REAL-PC'; Domain = 'corp.local' }
                IP = [ordered]@{
                    IPv4 = @('192.168.1.10', '192.168.1.10')
                    PrimaryIPv4 = '192.168.1.10'
                    PrimaryInterface = [PSCustomObject]@{ IPv4 = '192.168.1.10'; Gateway = '192.168.1.1' }
                    PublicIPv4 = '203.0.113.5'
                }
                Routing = [ordered]@{
                    DefaultGateway = '192.168.1.1'
                    DefaultGateways = @('192.168.1.1')
                    DNSServers = @('192.168.1.1', '192.168.1.2')
                    DNSSuffixSearchOrder = @('corp.local')
                    RoutingTable = @([PSCustomObject]@{ DestinationPrefix = '192.168.1.0/24'; NextHop = '192.168.1.1' })
                }
                Adapters = @([PSCustomObject]@{ MACAddress = 'AA-BB-CC-DD-EE-FF'; IPv4 = @('192.168.1.10'); Gateway = @('192.168.1.1'); DNS = @('192.168.1.1') })
                Connections = [ordered]@{ ListeningPorts = @([PSCustomObject]@{ LocalAddress = '192.168.1.10' }) }
                ARP = @([PSCustomObject]@{ IPAddress = '192.168.1.1'; LinkLayerAddress = '11-22-33-44-55-66' })
            }
            Users = [ordered]@{ LocalAdmins = @('jdoe', 'Administrator') }
            Security = [ordered]@{ RemoteAccess = [ordered]@{ AllowedUsers = @('jdoe', 'RemoteWorker') } }
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

    It 'маскує MAC-адреси в ARP-кеші (v0.5.0) навіть у Basic, IP-адреса в ARP лишається' {
        $script:report.Network.ARP[0].LinkLayerAddress | Should -Match '^REDACTED-MAC-'
        $script:report.Network.ARP[0].IPAddress | Should -Be '192.168.1.1'
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
}
