# MODULE: tests/ProcessNameLookup.Tests.ps1
# Pester-тести для чистої функції Get-BravoProcessNameLookup
# (src/33-Collectors-Network.ps1, TCP connections ProcessName enrichment).

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\33-Collectors-Network.ps1')
}

Describe 'Get-BravoProcessNameLookup' {
    It 'будує PID -> ProcessName lookup з масиву процесів' {
        $processes = @(
            [PSCustomObject]@{ Id = 1234; ProcessName = 'svchost' }
            [PSCustomObject]@{ Id = 5678; ProcessName = 'explorer' }
        )

        $map = Get-BravoProcessNameLookup -Processes $processes
        $map[1234] | Should -Be 'svchost'
        $map[5678] | Should -Be 'explorer'
    }

    It '$null повертає порожній hashtable (AllowNull)' {
        $map = Get-BravoProcessNameLookup -Processes $null
        $map.Count | Should -Be 0
    }

    It 'порожній масив повертає порожній hashtable' {
        $map = Get-BravoProcessNameLookup -Processes @()
        $map.Count | Should -Be 0
    }

    It 'пошук за PID, якого немає в мапі, повертає $null (не помилка)' {
        $processes = @([PSCustomObject]@{ Id = 1; ProcessName = 'foo' })
        $map = Get-BravoProcessNameLookup -Processes $processes
        $map[9999] | Should -BeNullOrEmpty
    }
}
