# MODULE: tests/StorageThresholds.Tests.ps1
# Pester-тести для централізованих storage thresholds (P1) з src/32-Collectors-Storage.ps1.
# Get-BravoStorageFreeSpaceSeverity — чиста функція, безпечна для dot-source
# без запуску решти колектора.

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\32-Collectors-Storage.ps1')
}

Describe 'Get-BravoStorageThresholds' {
    It 'повертає узгоджений набір порогів (critical < warning < systemWarning)' {
        $thresholds = Get-BravoStorageThresholds
        $thresholds.CriticalFreePercent | Should -BeLessThan $thresholds.WarningFreePercent
        $thresholds.WarningFreePercent | Should -BeLessThan $thresholds.SystemWarningFreePercent
    }
}

Describe 'Get-BravoStorageFreeSpaceSeverity' {
    It 'позначає том нижче critical-порогу як Critical' {
        Get-BravoStorageFreeSpaceSeverity -FreePercent 3 | Should -Be 'Critical'
    }

    It 'позначає том між critical і warning порогами як Warning' {
        Get-BravoStorageFreeSpaceSeverity -FreePercent 8 | Should -Be 'Warning'
    }

    It 'позначає системний том між warning і systemWarning порогами як SystemWarning' {
        Get-BravoStorageFreeSpaceSeverity -FreePercent 12 -IsSystemDrive $true | Should -Be 'SystemWarning'
    }

    It 'НЕ позначає несистемний том між warning і systemWarning порогами (Healthy)' {
        Get-BravoStorageFreeSpaceSeverity -FreePercent 12 -IsSystemDrive $false | Should -Be 'Healthy'
    }

    It 'позначає том вище всіх порогів як Healthy' {
        Get-BravoStorageFreeSpaceSeverity -FreePercent 50 | Should -Be 'Healthy'
    }

    It 'CD-ROM/оптичний том завжди Healthy, незалежно від FreePercent' {
        Get-BravoStorageFreeSpaceSeverity -FreePercent 0 -DriveType 'CD-ROM' | Should -Be 'Healthy'
    }

    It 'повертає Unknown, якщо FreePercent відсутній' {
        Get-BravoStorageFreeSpaceSeverity -FreePercent $null | Should -Be 'Unknown'
    }
}
