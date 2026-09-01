# MODULE: tests/HardwareThresholds.Tests.ps1
# Pester-тести для централізованих CPU/RAM thresholds (P1) з src/31-Collectors-Hardware.ps1.

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\31-Collectors-Hardware.ps1')
}

Describe 'Get-BravoHardwareThresholds' {
    It 'повертає узгоджений набір порогів (warning < critical) для CPU і RAM' {
        $thresholds = Get-BravoHardwareThresholds
        $thresholds.CpuWarningPercent | Should -BeLessThan $thresholds.CpuCriticalPercent
        $thresholds.RamWarningPercent | Should -BeLessThan $thresholds.RamCriticalPercent
    }

    It 'CPU і RAM пороги в діапазоні 0..100' {
        $thresholds = Get-BravoHardwareThresholds
        foreach ($key in @('CpuWarningPercent','CpuCriticalPercent','RamWarningPercent','RamCriticalPercent')) {
            $thresholds[$key] | Should -BeGreaterThan 0
            $thresholds[$key] | Should -BeLessOrEqual 100
        }
    }
}
