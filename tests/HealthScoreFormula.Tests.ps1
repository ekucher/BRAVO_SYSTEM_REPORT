# MODULE: tests/HealthScoreFormula.Tests.ps1
# Pester-тести для формули Health Score (Update-BravoHealthScore,
# src/40-Health.ps1) — Issue #93: formula, мінімум = 0, status precedence
# CRITICAL > WARNING > OK. Функція не чиста (читає/пише $script:Report), тому
# тестується через мінімальний $script:Report без запуску решти collectors —
# той самий підхід, що й tests/StorageThresholds.Tests.ps1.

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\40-Health.ps1')

    # Add-AuditError визначена в src/90-Main.ps1 (небезпечно dot-source'ити
    # цілком — виконує elevation-логіку на top-level). Легкий stub з тим самим
    # сигнатурним контрактом лише для catch-гілки.
    function Add-AuditError {
        param(
            [string]$Section,
            [string]$Message
        )
        $script:CapturedErrors += [PSCustomObject]@{ Section = $Section; Message = $Message }
    }

    function New-TestHealthReport {
        param(
            [int]$CriticalCount = 0,
            [int]$WarningCount = 0,
            [int]$InfoCount = 0,
            [int]$CollectionErrorCount = 0
        )

        $findings = @()
        for ($i = 0; $i -lt $CriticalCount; $i++) { $findings += [PSCustomObject]@{ Severity = 'CRITICAL'; Category = 'Test' } }
        for ($i = 0; $i -lt $WarningCount; $i++) { $findings += [PSCustomObject]@{ Severity = 'WARNING'; Category = 'Test' } }
        for ($i = 0; $i -lt $InfoCount; $i++) { $findings += [PSCustomObject]@{ Severity = 'INFO'; Category = 'Test' } }

        $errors = @()
        for ($i = 0; $i -lt $CollectionErrorCount; $i++) { $errors += [PSCustomObject]@{ Section = 'Test'; Message = 'x' } }

        return [PSCustomObject]@{
            Health           = [PSCustomObject]@{ Score = 100; Status = 'OK'; Findings = $findings }
            CollectionErrors = $errors
            Status           = ''
            StatusReason     = ''
            Dashboard        = $null
        }
    }
}

Describe 'Update-BravoHealthScore — базова формула' {
    It 'без findings/errors: Score=100, Status=OK' {
        $script:Report = New-TestHealthReport
        Update-BravoHealthScore
        $script:Report.Health.Score | Should -Be 100
        $script:Report.Health.Status | Should -Be 'OK'
    }

    It '1 CRITICAL finding: -20 балів (Score=80)' {
        $script:Report = New-TestHealthReport -CriticalCount 1
        Update-BravoHealthScore
        $script:Report.Health.Score | Should -Be 80
    }

    It '1 WARNING finding: -7 балів (Score=93)' {
        $script:Report = New-TestHealthReport -WarningCount 1
        Update-BravoHealthScore
        $script:Report.Health.Score | Should -Be 93
    }

    It 'INFO findings не впливають на Score' {
        $script:Report = New-TestHealthReport -InfoCount 5
        Update-BravoHealthScore
        $script:Report.Health.Score | Should -Be 100
        $script:Report.Health.Status | Should -Be 'OK'
    }

    It 'CollectionError: -2 бали за кожну (Score=98 при 1 помилці)' {
        $script:Report = New-TestHealthReport -CollectionErrorCount 1
        Update-BravoHealthScore
        $script:Report.Health.Score | Should -Be 98
    }

    It 'CollectionErrors штраф обмежений максимумом 20 балів (9 помилок -> -18)' {
        $script:Report = New-TestHealthReport -CollectionErrorCount 9
        Update-BravoHealthScore
        $script:Report.Health.Score | Should -Be 82
    }

    It 'CollectionErrors штраф капується на 20 балах при 10 помилках' {
        $script:Report = New-TestHealthReport -CollectionErrorCount 10
        Update-BravoHealthScore
        $script:Report.Health.Score | Should -Be 80
    }

    It 'CollectionErrors штраф лишається капованим на 20 балах при 15 помилках (не -30)' {
        $script:Report = New-TestHealthReport -CollectionErrorCount 15
        Update-BravoHealthScore
        $script:Report.Health.Score | Should -Be 80
    }

    It 'комбінація critical+warning+errors підсумовується коректно' {
        $script:Report = New-TestHealthReport -CriticalCount 1 -WarningCount 3 -CollectionErrorCount 2
        Update-BravoHealthScore
        # 100 - 20 - 21 - 4 = 55
        $script:Report.Health.Score | Should -Be 55
    }
}

Describe 'Update-BravoHealthScore — мінімум Score = 0 (не від''ємний)' {
    It '5 CRITICAL findings (100-100=0) не йде у від''ємне значення' {
        $script:Report = New-TestHealthReport -CriticalCount 5
        Update-BravoHealthScore
        $script:Report.Health.Score | Should -Be 0
    }

    It '6 CRITICAL findings (номінально -120) все одно капується на 0, не -20' {
        $script:Report = New-TestHealthReport -CriticalCount 6
        Update-BravoHealthScore
        $script:Report.Health.Score | Should -Be 0
    }

    It 'екстремальна комбінація (10 critical + 10 warning + 50 errors) капується на 0' {
        $script:Report = New-TestHealthReport -CriticalCount 10 -WarningCount 10 -CollectionErrorCount 50
        Update-BravoHealthScore
        $script:Report.Health.Score | Should -Be 0
        $script:Report.Health.Score | Should -Not -BeLessThan 0
    }
}

Describe 'Update-BravoHealthScore — status precedence CRITICAL > WARNING > OK' {
    It 'без findings/errors -> OK' {
        $script:Report = New-TestHealthReport
        Update-BravoHealthScore
        $script:Report.Health.Status | Should -Be 'OK'
    }

    It 'лише WARNING findings -> WARNING' {
        $script:Report = New-TestHealthReport -WarningCount 1
        Update-BravoHealthScore
        $script:Report.Health.Status | Should -Be 'WARNING'
    }

    It 'лише CollectionErrors (без findings) -> WARNING, не OK' {
        $script:Report = New-TestHealthReport -CollectionErrorCount 1
        Update-BravoHealthScore
        $script:Report.Health.Status | Should -Be 'WARNING'
    }

    It 'хоча б 1 CRITICAL finding -> CRITICAL, незалежно від warnings/errors' {
        $script:Report = New-TestHealthReport -CriticalCount 1 -WarningCount 5 -CollectionErrorCount 5
        Update-BravoHealthScore
        $script:Report.Health.Status | Should -Be 'CRITICAL'
    }

    It 'CRITICAL має пріоритет над WARNING навіть при 1 CRITICAL проти багатьох WARNING' {
        $script:Report = New-TestHealthReport -CriticalCount 1 -WarningCount 20
        Update-BravoHealthScore
        $script:Report.Health.Status | Should -Be 'CRITICAL'
    }

    It '$script:Report.Status та .StatusReason синхронізовані з Health.Status' {
        $script:Report = New-TestHealthReport -WarningCount 2
        Update-BravoHealthScore
        $script:Report.Status | Should -Be $script:Report.Health.Status
        $script:Report.StatusReason | Should -Match 'critical=0; warning=2; collectionErrors=0'
    }
}
