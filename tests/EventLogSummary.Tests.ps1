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

    It 'правильно рахує Critical/Error/Warning окремо, ігнорує Information' {
        $events = @(
            [PSCustomObject]@{ LevelDisplayName = 'Critical'; ProviderName = 'ProviderA'; Message = 'crit-1' }
            [PSCustomObject]@{ LevelDisplayName = 'Error'; ProviderName = 'ProviderA'; Message = 'err-1' }
            [PSCustomObject]@{ LevelDisplayName = 'Error'; ProviderName = 'ProviderB'; Message = 'err-2' }
            [PSCustomObject]@{ LevelDisplayName = 'Warning'; ProviderName = 'ProviderB'; Message = 'warn-1' }
            [PSCustomObject]@{ LevelDisplayName = 'Information'; ProviderName = 'ProviderC'; Message = 'info-1' }
        )

        $result = ConvertTo-BravoEventLogSummary -Events $events
        $result.CriticalCount | Should -Be 1
        $result.ErrorCount | Should -Be 2
        $result.WarningCount | Should -Be 1
    }

    It 'TopProviders — топ-10 провайдерів за кількістю, з LastMessage першого запису кожної групи' {
        $events = @(
            [PSCustomObject]@{ LevelDisplayName = 'Error'; ProviderName = 'ProviderA'; Message = 'a-first' }
            [PSCustomObject]@{ LevelDisplayName = 'Error'; ProviderName = 'ProviderA'; Message = 'a-second' }
            [PSCustomObject]@{ LevelDisplayName = 'Warning'; ProviderName = 'ProviderB'; Message = 'b-first' }
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
