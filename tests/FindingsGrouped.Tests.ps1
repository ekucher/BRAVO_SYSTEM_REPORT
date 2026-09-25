# MODULE: tests/FindingsGrouped.Tests.ps1
# Pester-тести для чистої функції Get-BravoFindingsGrouped
# (src/40-Health.ps1, v0.6.0 Reports and UX: findings grouped by
# severity/category).

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\40-Health.ps1')
}

Describe 'Get-BravoFindingsGrouped' {
    It 'сортує findings за severity: CRITICAL -> WARNING -> INFO' {
        $findings = @(
            [PSCustomObject]@{ Severity = 'WARNING'; Category = 'B'; Message = 'w' }
            [PSCustomObject]@{ Severity = 'INFO'; Category = 'A'; Message = 'i' }
            [PSCustomObject]@{ Severity = 'CRITICAL'; Category = 'C'; Message = 'c' }
        )

        $result = Get-BravoFindingsGrouped -Findings $findings
        $sorted = @($result.Sorted)
        $sorted[0].Severity | Should -Be 'CRITICAL'
        $sorted[1].Severity | Should -Be 'WARNING'
        $sorted[2].Severity | Should -Be 'INFO'
    }

    It 'у межах одного severity сортує за Category' {
        $findings = @(
            [PSCustomObject]@{ Severity = 'WARNING'; Category = 'Zebra'; Message = 'z' }
            [PSCustomObject]@{ Severity = 'WARNING'; Category = 'Alpha'; Message = 'a' }
        )

        $result = Get-BravoFindingsGrouped -Findings $findings
        $sorted = @($result.Sorted)
        $sorted[0].Category | Should -Be 'Alpha'
        $sorted[1].Category | Should -Be 'Zebra'
    }

    It 'рахує CriticalCount/WarningCount/InfoCount коректно' {
        $findings = @(
            [PSCustomObject]@{ Severity = 'CRITICAL'; Category = 'A'; Message = '1' }
            [PSCustomObject]@{ Severity = 'CRITICAL'; Category = 'B'; Message = '2' }
            [PSCustomObject]@{ Severity = 'WARNING'; Category = 'C'; Message = '3' }
            [PSCustomObject]@{ Severity = 'INFO'; Category = 'D'; Message = '4' }
        )

        $result = Get-BravoFindingsGrouped -Findings $findings
        $result.CriticalCount | Should -Be 2
        $result.WarningCount | Should -Be 1
        $result.InfoCount | Should -Be 1
    }

    It '$null/порожній масив повертає нульові лічильники, без винятку' {
        $result = Get-BravoFindingsGrouped -Findings $null
        $result.CriticalCount | Should -Be 0
        $result.WarningCount | Should -Be 0
        $result.InfoCount | Should -Be 0
        @($result.Sorted).Count | Should -Be 0
    }

    It 'невідомий severity потрапляє в кінець сортування, не ламає функцію' {
        $findings = @(
            [PSCustomObject]@{ Severity = 'UNKNOWN-CODE'; Category = 'X'; Message = 'x' }
            [PSCustomObject]@{ Severity = 'CRITICAL'; Category = 'A'; Message = 'a' }
        )

        $result = Get-BravoFindingsGrouped -Findings $findings
        $sorted = @($result.Sorted)
        $sorted[0].Severity | Should -Be 'CRITICAL'
        $sorted[1].Severity | Should -Be 'UNKNOWN-CODE'
    }
}
