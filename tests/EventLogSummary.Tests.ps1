# MODULE: tests/EventLogSummary.Tests.ps1
# Pester-тести для чистої функції ConvertTo-BravoEventLogSummary
# (src/37-Collectors-Events.ps1, v0.5.0 Deep Inventory / Updates+Event Logs).

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\37-Collectors-Events.ps1')
}

Describe 'ConvertTo-BravoEventLogSummary' {
    It 'порожній масив подій дає нульові лічильники й порожній TopProviders' {
        $result = ConvertTo-BravoEventLogSummary -Events @()
        $result.CriticalCount | Should -Be 0
        $result.ErrorCount | Should -Be 0
        $result.WarningCount | Should -Be 0
        @($result.TopProviders).Count | Should -Be 0
    }

    It '$null дає той самий результат, що й порожній масив (AllowNull)' {
        $result = ConvertTo-BravoEventLogSummary -Events $null
        $result.CriticalCount | Should -Be 0
        $result.ErrorCount | Should -Be 0
        $result.WarningCount | Should -Be 0
    }

    It 'правильно рахує Critical/Error/Warning окремо (за числовим .Level), ігнорує Information' {
        $events = @(
            [PSCustomObject]@{ Level = 1; LevelDisplayName = 'Critical'; ProviderName = 'ProviderA'; Message = 'crit-1' }
            [PSCustomObject]@{ Level = 2; LevelDisplayName = 'Error'; ProviderName = 'ProviderA'; Message = 'err-1' }
            [PSCustomObject]@{ Level = 2; LevelDisplayName = 'Error'; ProviderName = 'ProviderB'; Message = 'err-2' }
            [PSCustomObject]@{ Level = 3; LevelDisplayName = 'Warning'; ProviderName = 'ProviderB'; Message = 'warn-1' }
            [PSCustomObject]@{ Level = 4; LevelDisplayName = 'Information'; ProviderName = 'ProviderC'; Message = 'info-1' }
        )

        $result = ConvertTo-BravoEventLogSummary -Events $events
        $result.CriticalCount | Should -Be 1
        $result.ErrorCount | Should -Be 2
        $result.WarningCount | Should -Be 1
    }

    It 'рахує коректно навіть коли LevelDisplayName локалізований (не англ.) — .Level locale-independent (Release Blocker Fixes v0.6.1)' {
        $events = @(
            [PSCustomObject]@{ Level = 1; LevelDisplayName = 'Критичний'; ProviderName = 'ProviderA'; Message = 'crit-1' }
            [PSCustomObject]@{ Level = 2; LevelDisplayName = 'Помилка'; ProviderName = 'ProviderA'; Message = 'err-1' }
            [PSCustomObject]@{ Level = 3; LevelDisplayName = 'Попередження'; ProviderName = 'ProviderB'; Message = 'warn-1' }
            [PSCustomObject]@{ Level = 4; LevelDisplayName = 'Відомості'; ProviderName = 'ProviderC'; Message = 'info-1' }
        )

        $result = ConvertTo-BravoEventLogSummary -Events $events
        $result.CriticalCount | Should -Be 1
        $result.ErrorCount | Should -Be 1
        $result.WarningCount | Should -Be 1
    }

    It 'TopProviders — топ-10 провайдерів за кількістю, з LastMessage першого запису кожної групи' {
        $events = @(
            [PSCustomObject]@{ Level = 2; LevelDisplayName = 'Error'; ProviderName = 'ProviderA'; Message = 'a-first' }
            [PSCustomObject]@{ Level = 2; LevelDisplayName = 'Error'; ProviderName = 'ProviderA'; Message = 'a-second' }
            [PSCustomObject]@{ Level = 3; LevelDisplayName = 'Warning'; ProviderName = 'ProviderB'; Message = 'b-first' }
        )

        $result = ConvertTo-BravoEventLogSummary -Events $events
        $providers = @($result.TopProviders)
        $providers.Count | Should -Be 2

        $providerA = $providers | Where-Object { $_.ProviderName -eq 'ProviderA' }
        $providerA.Count | Should -Be 2
        $providerA.LastMessage | Should -Be 'a-first'

        $providerB = $providers | Where-Object { $_.ProviderName -eq 'ProviderB' }
        $providerB.Count | Should -Be 1
    }
}
