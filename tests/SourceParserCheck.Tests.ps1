# MODULE: tests/SourceParserCheck.Tests.ps1
# v0.7.0 CI/Quality Gates: parser check для КОЖНОГО src/*.ps1 окремо (не
# лише для зібраного dist/Get-BravoSystemReport.ps1, як уже робить крок
# "PowerShell parser check for dist" у local-windows-validation.yml).
#
# Синтаксична перевірка через [System.Management.Automation.Language.Parser]::ParseFile
# — той самий AST-based підхід, що й existing dist-перевірка в CI, лише
# застосований до кожного модуля окремо. НЕ dot-source виконання (жоден
# файл не виконується — модулі src/90-Main.ps1 і колектори мають побічні
# ефекти й залежність від параметрів скрипту, які тут не надаються).
#
# Локальна перевага над "лише dist": помилка вказує на конкретний src/*.ps1
# файл і рядок, а не на позицію всередині згенерованого монолітного
# dist-файлу (де рядки зсунуті відносно вихідних модулів).

Describe 'Parser check для кожного src/*.ps1 окремо' {
    BeforeAll {
        $script:SrcDir = Join-Path $PSScriptRoot '..\src'
        $script:SrcFiles = Get-ChildItem -Path $script:SrcDir -Filter '*.ps1' -File
    }

    It 'у папці src/ є хоча б один *.ps1 файл (sanity-перевірка, що тест не пропускає всі файли мовчки)' {
        @($script:SrcFiles).Count | Should -BeGreaterThan 0
    }

    It 'кожен src/*.ps1 файл синтаксично коректний (без parser errors)' {
        $filesWithErrors = @()

        foreach ($file in $script:SrcFiles) {
            $tokens = $null
            $parseErrors = $null

            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $file.FullName,
                [ref]$tokens,
                [ref]$parseErrors
            )

            if ($parseErrors.Count -gt 0) {
                $errorMessages = ($parseErrors | ForEach-Object { "$($_.Message) (line $($_.Extent.StartLineNumber))" }) -join '; '
                $filesWithErrors += "$($file.Name): $errorMessages"
            }
        }

        if ($filesWithErrors.Count -gt 0) {
            ($filesWithErrors -join "`n") | Should -BeNullOrEmpty
        }
    }
}
