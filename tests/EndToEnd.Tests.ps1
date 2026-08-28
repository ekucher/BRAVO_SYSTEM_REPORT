# MODULE: tests/EndToEnd.Tests.ps1
# Pester-обгортка над наскрізним прогоном зібраного dist/Get-BravoSystemReport.ps1
# у профілі Quick -JSONOnly. Робить локально запускаваною (Invoke-Pester tests/)
# ту саму перевірку, яку CI виконує вручну кроками "Quick runtime test" +
# "Validate latest JSON" у .github/workflows/local-windows-validation.yml.
#
# Потребує адміністративних прав і реального Windows-оточення (WMI/CIM) —
# пропускається, якщо dist відсутній (наприклад, до першого build).

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:DistPath = Join-Path $script:RepoRoot 'dist\Get-BravoSystemReport.ps1'
    $script:ReportsDir = Join-Path $script:RepoRoot 'reports\pester-e2e'
    $script:Report = $null

    if (Test-Path -LiteralPath $script:DistPath) {
        if (Test-Path -LiteralPath $script:ReportsDir) {
            Remove-Item -LiteralPath $script:ReportsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:ReportsDir -Force | Out-Null

        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:DistPath `
            -Profile Quick -NoPause -NoOpenFolder -JSONOnly -OutputPath $script:ReportsDir | Out-Null

        $latestJson = Get-ChildItem -LiteralPath $script:ReportsDir -Filter 'BravoSystemReport_*.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1

        if ($latestJson) {
            $script:Report = Get-Content -LiteralPath $latestJson.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        }
    }
}

Describe 'Наскрізний прогін dist (Quick, JSONOnly)' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\dist\Get-BravoSystemReport.ps1'))) {
    It 'генерує валідний JSON-звіт' {
        $script:Report | Should -Not -BeNullOrEmpty
    }

    It 'має SchemaVersion' {
        $script:Report.SchemaVersion | Should -Not -BeNullOrEmpty
    }

    It 'Health.Score у діапазоні 0..100' {
        $script:Report.Health.Score | Should -BeGreaterOrEqual 0
        $script:Report.Health.Score | Should -BeLessOrEqual 100
    }

    It 'не має CollectionErrors у чистому профілі Quick' {
        @($script:Report.CollectionErrors).Count | Should -Be 0
    }

    It 'Profile відповідає запитаному (Quick)' {
        $script:Report.Profile | Should -Be 'Quick'
    }

    It 'DotNet.LatestKnownVersion заповнений і відповідає 4.8 або 4.8.1' {
        $script:Report.DotNet.LatestKnownVersion | Should -BeIn @('4.8', '4.8.1')
    }
}
