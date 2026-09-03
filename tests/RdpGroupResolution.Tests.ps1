# MODULE: tests/RdpGroupResolution.Tests.ps1
# Pester-тести для Resolve-BravoWellKnownGroupName (src/35-Collectors-Users.ps1,
# Release Blocker Fixes v0.6.1) — locale-independent резолвінг вбудованих
# локальних груп (S-1-5-32-*) через SID замість жорсткого англ. літералу.
#
# Чиста функція, але залежить від .NET SecurityIdentifier.Translate() — не
# мокабельного Pester-ом cmdlet-виклику. S-1-5-32-544 (Administrators) і
# S-1-5-32-555 (Remote Desktop Users) — стандартні вбудовані локальні SID,
# присутні й резолвні на БУДЬ-ЯКІЙ Windows-машині (включно з CI-раннерами)
# незалежно від домену/локалі — тому пряма перевірка (без мокання
# нижнього рівня) тут детермінована й безпечна.

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\35-Collectors-Users.ps1')
}

Describe 'Resolve-BravoWellKnownGroupName' {
    It 'резолвить Administrators (S-1-5-32-544) у непорожню локалізовану назву' {
        $result = Resolve-BravoWellKnownGroupName -Sid 'S-1-5-32-544' -FallbackName 'Administrators'
        $result | Should -Not -BeNullOrEmpty
    }

    It 'резолвить Remote Desktop Users (S-1-5-32-555) у непорожню локалізовану назву' {
        $result = Resolve-BravoWellKnownGroupName -Sid 'S-1-5-32-555' -FallbackName 'Remote Desktop Users'
        $result | Should -Not -BeNullOrEmpty
    }

    It 'при невалідному SID повертає fallback-назву, не кидає виняток' {
        { $script:result = Resolve-BravoWellKnownGroupName -Sid 'NOT-A-VALID-SID' -FallbackName 'FallbackGroupName' } | Should -Not -Throw
        $script:result | Should -Be 'FallbackGroupName'
    }
}
