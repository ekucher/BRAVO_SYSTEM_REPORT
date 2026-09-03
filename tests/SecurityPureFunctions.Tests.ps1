# MODULE: tests/SecureBootStatus.Tests.ps1
# Pester-тести для Get-BravoSecureBootStatus (src/34-Collectors-Security.ps1,
# Release Blocker Fixes v0.6.1) — розрізнення access-denied (непідвищена
# сесія) від справжнього NotSupported (Legacy BIOS/VM без UEFI).

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\34-Collectors-Security.ps1')
}

Describe 'Get-BravoSecureBootStatus' {
    It 'Secure Boot увімкнено — Supported=true, Enabled=true, Status=Enabled' {
        Mock Confirm-SecureBootUEFI { $true }
        $result = Get-BravoSecureBootStatus
        $result.Supported | Should -Be $true
        $result.Enabled | Should -Be $true
        $result.Status | Should -Be 'Enabled'
    }

    It 'Secure Boot підтримується, але вимкнено — Supported=true, Enabled=false, Status=Disabled' {
        Mock Confirm-SecureBootUEFI { $false }
        $result = Get-BravoSecureBootStatus
        $result.Supported | Should -Be $true
        $result.Enabled | Should -Be $false
        $result.Status | Should -Be 'Disabled'
    }

    It 'UnauthorizedAccessException (непідвищена сесія) — Status=Unavailable, Supported=$null (НЕ NotSupported)' {
        Mock Confirm-SecureBootUEFI { throw [System.UnauthorizedAccessException]::new('Access is denied.') }
        $result = Get-BravoSecureBootStatus
        $result.Status | Should -Be 'Unavailable'
        $result.Supported | Should -Be $null
        $result.Error | Should -Not -BeNullOrEmpty
    }

    It 'інший виняток (Legacy BIOS/VM, напр. PlatformNotSupportedException) — Status=NotSupported, Supported=false' {
        Mock Confirm-SecureBootUEFI { throw [System.PlatformNotSupportedException]::new('This platform does not support UEFI Secure Boot.') }
        $result = Get-BravoSecureBootStatus
        $result.Status | Should -Be 'NotSupported'
        $result.Supported | Should -Be $false
        $result.Error | Should -Not -BeNullOrEmpty
    }
}

Describe 'Test-BravoDefenderRealTimeProtectionWarning' {
    It 'RealTimeProtectionEnabled=$false, AMRunningMode=Normal — WARNING потрібен' {
        Test-BravoDefenderRealTimeProtectionWarning -RealTimeProtectionEnabled $false -AMRunningMode 'Normal' | Should -Be $true
    }

    It 'RealTimeProtectionEnabled=$false, AMRunningMode=Passive (сторонній AV) — WARNING НЕ потрібен (Release Blocker Fixes v0.6.1)' {
        Test-BravoDefenderRealTimeProtectionWarning -RealTimeProtectionEnabled $false -AMRunningMode 'Passive' | Should -Be $false
    }

    It 'RealTimeProtectionEnabled=$false, AMRunningMode=SxS Passive — WARNING НЕ потрібен' {
        Test-BravoDefenderRealTimeProtectionWarning -RealTimeProtectionEnabled $false -AMRunningMode 'SxS Passive' | Should -Be $false
    }

    It 'RealTimeProtectionEnabled=$true — WARNING не потрібен незалежно від AMRunningMode' {
        Test-BravoDefenderRealTimeProtectionWarning -RealTimeProtectionEnabled $true -AMRunningMode 'Normal' | Should -Be $false
    }

    It 'RealTimeProtectionEnabled=$null (не зібрано), AMRunningMode порожній — WARNING потрібен (той самий default, що й раніше)' {
        Test-BravoDefenderRealTimeProtectionWarning -RealTimeProtectionEnabled $null -AMRunningMode '' | Should -Be $true
    }
}
