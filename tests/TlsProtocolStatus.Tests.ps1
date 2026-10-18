# MODULE: tests/TlsProtocolStatus.Tests.ps1
# Pester-тести для чистої функції Get-BravoTlsProtocolStatus (v0.5.0 Deep
# Inventory, Security Baseline: TLS registry status) з
# src/34-Collectors-Security.ps1.

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\34-Collectors-Security.ps1')
}

Describe 'Get-BravoTlsProtocolStatus' {
    It 'обидва ключі відсутні -> NotConfigured (ОС-дефолт, адмін нічого не налаштовував)' {
        Get-BravoTlsProtocolStatus -Enabled $null -DisabledByDefault $null | Should -Be 'NotConfigured'
    }

    It 'Enabled=0 -> Disabled, незалежно від DisabledByDefault' {
        Get-BravoTlsProtocolStatus -Enabled 0 -DisabledByDefault $null | Should -Be 'Disabled'
        Get-BravoTlsProtocolStatus -Enabled 0 -DisabledByDefault 0 | Should -Be 'Disabled'
    }

    It 'DisabledByDefault=1 (Enabled відсутній) -> Disabled' {
        Get-BravoTlsProtocolStatus -Enabled $null -DisabledByDefault 1 | Should -Be 'Disabled'
    }

    It 'Enabled=1, DisabledByDefault=0 -> Enabled (явно увімкнено)' {
        Get-BravoTlsProtocolStatus -Enabled 1 -DisabledByDefault 0 | Should -Be 'Enabled'
    }

    It 'Enabled=1, DisabledByDefault відсутній -> Enabled' {
        Get-BravoTlsProtocolStatus -Enabled 1 -DisabledByDefault $null | Should -Be 'Enabled'
    }

    It 'лише Enabled=1 явно задано (типовий випадок адміністративного увімкнення) -> Enabled' {
        Get-BravoTlsProtocolStatus -Enabled 1 -DisabledByDefault $null | Should -Be 'Enabled'
    }
}
