# MODULE: tests/Manifest.Tests.ps1
# Статична перевірка: кожен src/*.ps1 зареєстрований у src/BRAVO.build.json
# і навпаки. Ловить клас багів "додали новий модуль, забули зареєструвати
# в маніфесті" (уже траплялось: Windows Update collector не потрапляв
# у зібраний dist попри готовий src).

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:ManifestPath = Join-Path $script:RepoRoot 'src\BRAVO.build.json'
    $script:Manifest = Get-Content -LiteralPath $script:ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

    $script:ManifestFiles = @($script:Manifest.files | ForEach-Object { $_ -replace '/', '\' })

    $script:ActualSrcFiles = @(
        Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'src') -Filter '*.ps1' -File |
            ForEach-Object { "src\$($_.Name)" }
    )
}

Describe 'BRAVO.build.json manifest' {
    It 'посилається лише на файли, які реально існують у src/' {
        foreach ($file in $script:ManifestFiles) {
            $fullPath = Join-Path $script:RepoRoot $file
            Test-Path -LiteralPath $fullPath | Should -BeTrue -Because "$file вказаний у BRAVO.build.json, але відсутній на диску"
        }
    }

    It 'містить кожен src/*.ps1, що реально існує на диску' {
        $missing = @($script:ActualSrcFiles | Where-Object { $script:ManifestFiles -notcontains $_ })
        $missing | Should -BeNullOrEmpty -Because "ці файли є у src/, але не зареєстровані у BRAVO.build.json: $($missing -join ', ')"
    }

    It 'не містить дублікатів' {
        $duplicates = @($script:ManifestFiles | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
        $duplicates | Should -BeNullOrEmpty -Because "дублікати у BRAVO.build.json: $($duplicates -join ', ')"
    }

    It 'вказує на існуючий output і sha512 шлях' {
        $script:Manifest.output | Should -Not -BeNullOrEmpty
        $script:Manifest.sha512 | Should -Not -BeNullOrEmpty
    }
}
