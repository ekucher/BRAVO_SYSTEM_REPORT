# MODULE: tests/RuntimeCollectors.Tests.ps1
# Pester-тести для Get-BravoRuntimeAudit (src/39b-Collectors-Runtime.ps1) —
# Release Blocker Fixes v0.6.1: .NET Framework 4.8.1 build-matrix і
# PowerShell 7 full-version comparison. Функція НЕ чиста (читає реєстр і
# мутує $script:Report), тому Test-Path/Get-ItemProperty/Get-ChildItem
# замокані — той самий підхід, що й для інших не-чистих колекторів у цій
# репозиторії (мокати I/O, перевіряти результат у $script:Report).

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\39b-Collectors-Runtime.ps1')

    function Add-AuditFinding {
        param(
            [string]$Severity,
            [string]$Category,
            [string]$Message,
            [string]$Recommendation = ''
        )
        $script:CapturedFindings += [PSCustomObject]@{ Severity = $Severity; Category = $Category; Message = $Message }
    }

    function Add-AuditError {
        param([string]$Section, [string]$Message)
        $script:CapturedErrors += [PSCustomObject]@{ Section = $Section; Message = $Message }
    }

    function New-BravoFakeRuntimeReport {
        param([string]$OsBuild)
        [ordered]@{
            OS = [ordered]@{ Build = $OsBuild }
            DotNet = [ordered]@{
                v4 = ''
                ReleaseKey = 0
                LatestKnownVersion = ''
                UpdateAvailable = $false
            }
            PowerShell = [ordered]@{
                Version = $PSVersionTable.PSVersion
                Edition = $PSVersionTable.PSEdition
                Core7Installed = $false
                Core7Version = ''
                Core7LatestKnown = ''
                Core7UpdateAvailable = $false
            }
        }
    }
}

Describe 'Get-BravoRuntimeAudit — .NET Framework 4.8.1 build matrix' {
    BeforeEach {
        $script:CapturedFindings = @()
        $script:CapturedErrors = @()
        Mock Test-Path { $false }
    }

    It 'Win10 22H2 (build 19045) — 4.8.1 сумісна версія (bekported build, Release Blocker Fixes v0.6.1)' {
        $script:Report = New-BravoFakeRuntimeReport -OsBuild '19045'
        Get-BravoRuntimeAudit
        $script:Report.DotNet.LatestKnownVersion | Should -Be '4.8.1'
    }

    It 'Server 2022 RTM (build 20348) — 4.8.1 сумісна версія (bekported build, Release Blocker Fixes v0.6.1)' {
        $script:Report = New-BravoFakeRuntimeReport -OsBuild '20348'
        Get-BravoRuntimeAudit
        $script:Report.DotNet.LatestKnownVersion | Should -Be '4.8.1'
    }

    It 'Windows 11 22H2 (build 22621) — 4.8.1 сумісна версія (вже працювало раніше)' {
        $script:Report = New-BravoFakeRuntimeReport -OsBuild '22621'
        Get-BravoRuntimeAudit
        $script:Report.DotNet.LatestKnownVersion | Should -Be '4.8.1'
    }

    It 'новіший build (25398) — 4.8.1 сумісна версія' {
        $script:Report = New-BravoFakeRuntimeReport -OsBuild '25398'
        Get-BravoRuntimeAudit
        $script:Report.DotNet.LatestKnownVersion | Should -Be '4.8.1'
    }

    It 'старіший build (19044, Windows 10 21H2) — максимум 4.8, НЕ 4.8.1' {
        $script:Report = New-BravoFakeRuntimeReport -OsBuild '19044'
        Get-BravoRuntimeAudit
        $script:Report.DotNet.LatestKnownVersion | Should -Be '4.8'
    }
}

Describe 'Get-BravoRuntimeAudit — PowerShell 7 full-version comparison' {
    BeforeEach {
        $script:CapturedFindings = @()
        $script:CapturedErrors = @()

        Mock Test-Path {
            param($Path)
            if ($Path -eq 'HKLM:\SOFTWARE\Microsoft\PowerShellCore\InstalledVersions') { return $true }
            return $false
        }
        Mock Get-ChildItem { return @([PSCustomObject]@{ PSPath = 'fake-path' }) }
    }

    It 'найновіша відома версія (Core7LatestKnown) заповнюється незалежно від встановленого PS7' {
        Mock Get-ItemProperty { [PSCustomObject]@{ SemanticVersion = '7.4.0' } }
        $script:Report = New-BravoFakeRuntimeReport -OsBuild '19045'
        Get-BravoRuntimeAudit
        $script:Report.PowerShell.Core7LatestKnown | Should -Be '7.6.5'
    }

    It '7.4.0 проти найновішої відомої 7.6.5 — оновлення доступне' {
        Mock Get-ItemProperty { [PSCustomObject]@{ SemanticVersion = '7.4.0' } }
        $script:Report = New-BravoFakeRuntimeReport -OsBuild '19045'
        Get-BravoRuntimeAudit
        $script:Report.PowerShell.Core7UpdateAvailable | Should -Be $true
    }

    It '7.5.10 проти найновішої відомої 7.6.5 — оновлення доступне (Minor нижчий, попередній Major/Minor-only compare теж це вловив би, але тепер через повний [version])' {
        Mock Get-ItemProperty { [PSCustomObject]@{ SemanticVersion = '7.5.10' } }
        $script:Report = New-BravoFakeRuntimeReport -OsBuild '19045'
        Get-BravoRuntimeAudit
        $script:Report.PowerShell.Core7UpdateAvailable | Should -Be $true
    }

    It '7.6.0 проти найновішої відомої 7.6.5 — оновлення доступне (Major/Minor рівні, лише Patch нижчий — це саме те, що Major/Minor-only порівняння раніше пропускало)' {
        Mock Get-ItemProperty { [PSCustomObject]@{ SemanticVersion = '7.6.0' } }
        $script:Report = New-BravoFakeRuntimeReport -OsBuild '19045'
        Get-BravoRuntimeAudit
        $script:Report.PowerShell.Core7UpdateAvailable | Should -Be $true
    }

    It '7.6.4 проти найновішої відомої 7.6.5 — оновлення доступне (Patch на 1 нижчий)' {
        Mock Get-ItemProperty { [PSCustomObject]@{ SemanticVersion = '7.6.4' } }
        $script:Report = New-BravoFakeRuntimeReport -OsBuild '19045'
        Get-BravoRuntimeAudit
        $script:Report.PowerShell.Core7UpdateAvailable | Should -Be $true
    }

    It '7.6.5 проти найновішої відомої 7.6.5 — оновлення НЕ потрібне (рівні версії)' {
        Mock Get-ItemProperty { [PSCustomObject]@{ SemanticVersion = '7.6.5' } }
        $script:Report = New-BravoFakeRuntimeReport -OsBuild '19045'
        Get-BravoRuntimeAudit
        $script:Report.PowerShell.Core7UpdateAvailable | Should -Be $false
    }

    It '7.6.6 проти найновішої відомої 7.6.5 — новіший за latest known, оновлення НЕ потрібне (раніше хибно позначалось як застаріле через Major/Minor-only порівняння)' {
        Mock Get-ItemProperty { [PSCustomObject]@{ SemanticVersion = '7.6.6' } }
        $script:Report = New-BravoFakeRuntimeReport -OsBuild '19045'
        Get-BravoRuntimeAudit
        $script:Report.PowerShell.Core7UpdateAvailable | Should -Be $false
    }
}
