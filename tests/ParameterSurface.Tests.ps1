# MODULE: tests/ParameterSurface.Tests.ps1
# Release Sync & Governance Fixes (v0.6.1): regression-захист від класу
# багу, знайденого PR #86 — новий параметр був доданий у canonical
# src/05-Params.ps1 (компілюється в dist), але забутий у root wrapper
# Get-BravoSystemReport.ps1 (окремий, вручну підтримуваний param()-блок,
# який форвардить лише явно передані параметри — див. коментар у самому
# wrapper-і). Наслідок для користувача: -MD падав з
# ParameterBindingException при виклику через root wrapper, хоча працював
# напряму через dist.
#
# Тест порівнює МНОЖИНУ ІМЕН параметрів (не дефолти — дефолти свідомо
# різні: wrapper не дублює дефолтні значення, единий canonical default
# живе в src/05-Params.ps1) через AST-парсинг обох param()-блоків. Той
# самий [Parser]::ParseFile підхід, що й tests/SourceParserCheck.Tests.ps1.
# Не виконує жоден файл (жодних side-effects/залежності від параметрів
# запуску).

Describe 'Parameter surface: root wrapper vs src/05-Params.ps1' {
    BeforeAll {
        # Визначено всередині BeforeAll (не на top-level файлу) — Pester v6
        # розділяє Discovery/Run фази, і top-level функції поза Describe не
        # гарантовано видимі в It-блоках; функції, оголошені в BeforeAll,
        # живуть у скоупі Describe і доступні в усіх його It.
        function Get-BravoParameterNames {
            param([Parameter(Mandatory = $true)][string]$Path)

            $tokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $Path,
                [ref]$tokens,
                [ref]$parseErrors
            )

            if ($parseErrors.Count -gt 0) {
                throw "Parser errors у ${Path}: $(($parseErrors | ForEach-Object { $_.Message }) -join '; ')"
            }
            if (-not $ast.ParamBlock) {
                throw "У $Path не знайдено top-level param()-блоку."
            }

            return @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }) | Sort-Object -Unique
        }

        $script:WrapperPath = Join-Path $PSScriptRoot '..\Get-BravoSystemReport.ps1'
        $script:ParamsPath = Join-Path $PSScriptRoot '..\src\05-Params.ps1'

        # Allowlist для свідомо односторонніх параметрів (наразі порожній —
        # обидва param()-блоки мають бути ідентичними за іменами; додавати
        # сюди лише з явним коментарем-обґрунтуванням, чому розбіжність
        # навмисна).
        $script:WrapperOnlyAllowed = @()
        $script:ParamsOnlyAllowed = @()
    }

    It 'обидва файли існують і мають top-level param()-блок' {
        Test-Path -LiteralPath $script:WrapperPath | Should -BeTrue
        Test-Path -LiteralPath $script:ParamsPath | Should -BeTrue
    }

    It 'кожен параметр у src/05-Params.ps1 (canonical dist source) можна передати через root wrapper' {
        $wrapperNames = Get-BravoParameterNames -Path $script:WrapperPath
        $paramsNames = Get-BravoParameterNames -Path $script:ParamsPath

        $missingInWrapper = @($paramsNames | Where-Object { $_ -notin $wrapperNames -and $_ -notin $script:ParamsOnlyAllowed })

        if ($missingInWrapper.Count -gt 0) {
            ($missingInWrapper -join ', ') | Should -BeNullOrEmpty -Because 'ці параметри є в src/05-Params.ps1, але root wrapper їх не форвардить (ParameterBindingException при виклику через wrapper)'
        }
    }

    It 'root wrapper не має параметрів, яких немає в src/05-Params.ps1 (без свідомого allowlist)' {
        $wrapperNames = Get-BravoParameterNames -Path $script:WrapperPath
        $paramsNames = Get-BravoParameterNames -Path $script:ParamsPath

        $extraInWrapper = @($wrapperNames | Where-Object { $_ -notin $paramsNames -and $_ -notin $script:WrapperOnlyAllowed })

        if ($extraInWrapper.Count -gt 0) {
            ($extraInWrapper -join ', ') | Should -BeNullOrEmpty -Because 'ці параметри є у wrapper, але відсутні в canonical src/05-Params.ps1 — або помилка, або потребують явного запису в allowlist з обґрунтуванням'
        }
    }
}
