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

Describe 'CPU/RAM findings recommendations reference an existing report field (PR#85 P2)' {
    BeforeAll {
        $script:HardwareSource = Get-Content (Join-Path $PSScriptRoot '..\src\31-Collectors-Hardware.ps1') -Raw
        $script:ReportModelSource = Get-Content (Join-Path $PSScriptRoot '..\src\20-ReportModel.ps1') -Raw
    }

    It 'ніколи не посилається на неіснуюче поле Processes.TopCPU' {
        $script:HardwareSource | Should -Not -Match 'TopCPU'
    }

    It 'CRITICAL/WARNING рекомендації для CPU і RAM посилаються на Processes.TopMemory' {
        $recommendationLines = $script:HardwareSource -split "`r?`n" | Where-Object {
            $_ -match "Add-AuditFinding.*-Category 'Hardware\.(CPU|RAM)'"
        }
        $recommendationLines.Count | Should -Be 4
        foreach ($line in $recommendationLines) {
            $line | Should -Match 'TopMemory'
        }
    }

    It 'Processes.TopMemory дійсно існує в моделі звіту (20-ReportModel.ps1)' {
        $script:ReportModelSource | Should -Match 'Processes\s*=\s*\[ordered\]@\{[^}]*TopMemory'
    }
}
