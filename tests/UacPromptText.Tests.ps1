# MODULE: tests/UacPromptText.Tests.ps1
# Pester-тести для чистих функцій Get-BravoUacAdminPromptText/
# Get-BravoUacUserPromptText (src/34-Collectors-Security.ps1, UAC full policy).

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\34-Collectors-Security.ps1')
}

Describe 'Get-BravoUacAdminPromptText' {
    It 'мапить усі відомі коди ConsentPromptBehaviorAdmin (0-5)' {
        Get-BravoUacAdminPromptText -Code 0 | Should -Be 'Elevate without prompting'
        Get-BravoUacAdminPromptText -Code 1 | Should -Be 'Prompt for credentials on the secure desktop'
        Get-BravoUacAdminPromptText -Code 2 | Should -Be 'Prompt for consent on the secure desktop'
        Get-BravoUacAdminPromptText -Code 3 | Should -Be 'Prompt for credentials'
        Get-BravoUacAdminPromptText -Code 4 | Should -Be 'Prompt for consent'
        Get-BravoUacAdminPromptText -Code 5 | Should -Be 'Prompt for consent for non-Windows binaries'
    }

    It '$null повертає "Unknown (not set)"' {
        Get-BravoUacAdminPromptText -Code $null | Should -Be 'Unknown (not set)'
    }

    It 'невідомий код повертає "Unknown ($code)", не помилку' {
        Get-BravoUacAdminPromptText -Code 99 | Should -Be 'Unknown (99)'
    }
}

Describe 'Get-BravoUacUserPromptText' {
    It 'мапить усі відомі коди ConsentPromptBehaviorUser (0, 1, 3)' {
        Get-BravoUacUserPromptText -Code 0 | Should -Be 'Automatically deny elevation requests'
        Get-BravoUacUserPromptText -Code 1 | Should -Be 'Prompt for credentials on the secure desktop'
        Get-BravoUacUserPromptText -Code 3 | Should -Be 'Prompt for credentials'
    }

    It '$null повертає "Unknown (not set)"' {
        Get-BravoUacUserPromptText -Code $null | Should -Be 'Unknown (not set)'
    }

    It 'невідомий код повертає "Unknown ($code)", не помилку' {
        Get-BravoUacUserPromptText -Code 2 | Should -Be 'Unknown (2)'
    }
}
