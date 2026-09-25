# MODULE: tests/MainExportSyncAndArgEscaping.Tests.ps1
# Регресійні тести для двох виправлень у src/90-Main.ps1 (Release Blocker
# Fixes v0.6.1 / delta review 2026-09-25):
#
# 1. Sync-BravoJsonIfExportErrorsChanged мав перезаписувати JSON на диску
#    лише коли ExportErrors.Count змінився — GeneratedFiles.Count (HTML/PDF/
#    TXT/MD/CSV додають себе ПІСЛЯ першого JSON-запису) ніколи не тригерив
#    перезапис, тож фінальний JSON на диску завжди мав неповний
#    GeneratedFiles.
# 2. Значення -OutputPath/-EmailTo/-EmailFrom/-SmtpServer, що йдуть у
#    ArgumentList елевованого relaunch, не екранувались (вбудована лапка —
#    argument injection; бекслеш перед закриваючою лапкою — класичний
#    Windows CLI quoting bug).
#
# 90-Main.ps1 не можна dot-source'ити цілком (top-level elevation-логіка з
# побічними ефектами — той самий застережний коментар, що й у
# tests/StorageThresholds.Tests.ps1). Тому обидві функції витягуються з
# АКТУАЛЬНОГО файлу через AST (FindAll FunctionDefinitionAst) і виконуються
# ізольовано — тест перевіряє реальний production-код, а не копію логіки.

BeforeAll {
    $script:MainPath = Join-Path $PSScriptRoot '..\src\90-Main.ps1'
    $script:MainContent = Get-Content -LiteralPath $script:MainPath -Raw

    function Get-BravoFunctionSourceFromAst {
        param([string]$Content, [string]$FunctionName)

        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$tokens, [ref]$parseErrors)

        $funcAst = $ast.FindAll(
            { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $FunctionName },
            $true
        ) | Select-Object -First 1

        if (-not $funcAst) { throw "Функцію '$FunctionName' не знайдено в джерелі через AST." }
        return $funcAst.Extent.Text
    }
}

Describe 'ConvertTo-BravoQuotedProcessArgument (src/90-Main.ps1) — екранування аргументів елевованого relaunch' {
    BeforeAll {
        $source = Get-BravoFunctionSourceFromAst -Content $script:MainContent -FunctionName 'ConvertTo-BravoQuotedProcessArgument'
        . ([scriptblock]::Create($source))
    }

    It 'не змінює просте значення без пробілів/лапок (без зайвого квотування)' {
        ConvertTo-BravoQuotedProcessArgument -Value 'C:\Reports' | Should -Be 'C:\Reports'
    }

    It 'квотує значення з пробілом' {
        ConvertTo-BravoQuotedProcessArgument -Value 'C:\Program Files\Reports' | Should -Be '"C:\Program Files\Reports"'
    }

    It 'екранує вбудовану подвійну лапку (запобігає argument injection у -EmailTo)' {
        # Без екранування ця лапка замкнула б аргумент передчасно, і решта
        # значення інтерпретувалась би як ДОДАТКОВІ CLI-параметри
        # елевованого процесу (напр. `-Strict:$false` чи довільний інший
        # перемикач) — саме тому регресія P1.
        $malicious = 'a"@evil.com -NoOpenFolder'
        $result = ConvertTo-BravoQuotedProcessArgument -Value $malicious

        $result | Should -Be '"a\"@evil.com -NoOpenFolder"'

        # Авторитетна перевірка проти Win32 CommandLineToArgvW quoting rules:
        # закриваюча лапка рядка має бути РІВНО в кінці (єдина незекранована),
        # жодна внутрішня лапка не повинна лишитись незекранованою — інакше
        # аргумент розпадається на кілька CLI-токенів у дочірньому процесі.
        $unescapedQuoteIndexes = @()
        for ($i = 1; $i -lt ($result.Length - 1); $i++) {
            if ($result[$i] -eq '"' -and $result[$i - 1] -ne '\') { $unescapedQuoteIndexes += $i }
        }
        $unescapedQuoteIndexes.Count | Should -Be 0 -Because 'жодна внутрішня лапка не повинна лишитись незекранованою (це і є injection-діра)'
    }

    It 'подвоює бекслеш(и) безпосередньо перед закриваючою лапкою (класичний Windows CLI quoting bug)' {
        # Значення з пробілом (щоб узагалі квотувалось) і що закінчується
        # одним бекслешем — без подвоєння цей бекслеш екранував би саму
        # закриваючу лапку, і аргумент "виривався" б назовні.
        $result = ConvertTo-BravoQuotedProcessArgument -Value 'C:\Temp Path\'
        $result | Should -Be '"C:\Temp Path\\"'
    }

    It 'подвоює лише бекслеші, що безпосередньо передують лапці або кінцю рядка (внутрішні бекслеші не чіпає)' {
        ConvertTo-BravoQuotedProcessArgument -Value 'C:\Program Files\Reports\' | Should -Be '"C:\Program Files\Reports\\"'
    }

    It 'обробляє $null як порожній рядок (квотується як "")' {
        ConvertTo-BravoQuotedProcessArgument -Value $null | Should -Be '""'
    }
}

Describe 'Елевований relaunch (src/90-Main.ps1) — усі чотири CLI-значення проходять через екранування' {
    It '-OutputPath/-EmailTo/-EmailFrom/-SmtpServer обгортаються через ConvertTo-BravoQuotedProcessArgument, а не сирі `"..`"' {
        $script:MainContent | Should -Match '"-OutputPath \$\(ConvertTo-BravoQuotedProcessArgument -Value \$OutputPath\)"'
        $script:MainContent | Should -Match '"-EmailTo \$\(ConvertTo-BravoQuotedProcessArgument -Value \$EmailTo\)"'
        $script:MainContent | Should -Match '"-EmailFrom \$\(ConvertTo-BravoQuotedProcessArgument -Value \$EmailFrom\)"'
        $script:MainContent | Should -Match '"-SmtpServer \$\(ConvertTo-BravoQuotedProcessArgument -Value \$SmtpServer\)"'
    }
}

Describe 'Sync-BravoJsonIfExportErrorsChanged (src/90-Main.ps1) — перезапис JSON також при зміні GeneratedFiles' {
    BeforeAll {
        $source = Get-BravoFunctionSourceFromAst -Content $script:MainContent -FunctionName 'Sync-BravoJsonIfExportErrorsChanged'
    }

    BeforeEach {
        $script:outputDir = 'TestDrive:\out'
        $script:baseFileName = 'BravoSystemReport_TEST'
        $script:exportCallCount = 0

        function Export-BravoJsonReport {
            param([string]$OutputDir, [string]$BaseFileName)
            $script:exportCallCount++
        }

        . ([scriptblock]::Create($source))
    }

    It 'НЕ перезаписує JSON, якщо ні ExportErrors, ні GeneratedFiles не змінились (регресія-контроль: не vacuous)' {
        $script:Report = [PSCustomObject]@{
            ExportErrors    = @()
            GeneratedFiles  = @('a.json')
        }

        $result = Sync-BravoJsonIfExportErrorsChanged -PriorCount 0 -PriorGeneratedFilesCount 1

        $script:exportCallCount | Should -Be 0
        $result.ExportErrorCount | Should -Be 0
        $result.GeneratedFilesCount | Should -Be 1
    }

    It 'ПЕРЕЗАПИСУЄ JSON, коли змінився лише GeneratedFiles.Count (ExportErrors незмінний) — це і є регресія до фіксу' {
        # Сценарій з опису багу: HTML/CSV/TXT/MD додали себе в GeneratedFiles
        # ПІСЛЯ першого JSON-запису, ExportErrors при цьому не змінився. До
        # фіксу тригер перевіряв лише ExportErrors.Count -gt PriorCount і
        # цей виклик НІКОЛИ не перезаписував JSON.
        $script:Report = [PSCustomObject]@{
            ExportErrors    = @()
            GeneratedFiles  = @('a.json', 'a.html', 'a.csv')
        }

        $result = Sync-BravoJsonIfExportErrorsChanged -PriorCount 0 -PriorGeneratedFilesCount 1

        $script:exportCallCount | Should -Be 1 -Because 'GeneratedFiles.Count змінився (1 -> 3), навіть без нових ExportErrors'
        $result.ExportErrorCount | Should -Be 0
        $result.GeneratedFilesCount | Should -Be 3
    }

    It 'ПЕРЕЗАПИСУЄ JSON, коли змінився лише ExportErrors.Count (існуюча поведінка — не зламана фіксом)' {
        $script:Report = [PSCustomObject]@{
            ExportErrors    = @([PSCustomObject]@{ Section = 'Export.Zip'; Message = 'boom' })
            GeneratedFiles  = @('a.json')
        }

        $result = Sync-BravoJsonIfExportErrorsChanged -PriorCount 0 -PriorGeneratedFilesCount 1

        $script:exportCallCount | Should -Be 1
        $result.ExportErrorCount | Should -Be 1
        $result.GeneratedFilesCount | Should -Be 1
    }
}

Describe 'New-BravoReportBaseFileName (src/90-Main.ps1) — унікальність basename при -Sanitize (P1, exact-head review Phase 10)' {
    BeforeAll {
        $source = Get-BravoFunctionSourceFromAst -Content $script:MainContent -FunctionName 'New-BravoReportBaseFileName'
        . ([scriptblock]::Create($source))
    }

    It 'без -SanitizeActive повертає стабільний basename на основі реального ComputerName, без суфікса' {
        $result = New-BravoReportBaseFileName -Timestamp '20260925_120000' -RealComputerName 'REAL-PC' -SanitizedComputerName 'REDACTED-COMPUTERNAME-1'
        $result | Should -Be 'BravoSystemReport_REAL-PC_20260925_120000'
    }

    It 'з -SanitizeActive використовує замаскований ComputerName, а не реальний' {
        $result = New-BravoReportBaseFileName -Timestamp '20260925_120000' -SanitizeActive -RealComputerName 'REAL-PC' -SanitizedComputerName 'REDACTED-COMPUTERNAME-1'
        $result | Should -Match '^BravoSystemReport_REDACTED-COMPUTERNAME-1_20260925_120000_[0-9a-f]{8}$'
        $result | Should -Not -Match 'REAL-PC'
    }

    It 'два послідовні виклики з -SanitizeActive і ОДНАКОВИМ замаскованим ComputerName дають РІЗНІ basename (запобігає колізії флоту, P1)' {
        # New-BravoSanitizeMasker скидає Counter щоразу -> замаскований
        # ComputerName ІДЕНТИЧНИЙ на кожній машині флоту в межах одного
        # timestamp (наприклад, обидва завжди "REDACTED-COMPUTERNAME-1").
        # Без випадкового суфікса ці дві машини перезаписали б артефакти
        # одна одної в спільному OutputPath.
        $first = New-BravoReportBaseFileName -Timestamp '20260925_120000' -SanitizeActive -RealComputerName 'REAL-PC-1' -SanitizedComputerName 'REDACTED-COMPUTERNAME-1'
        $second = New-BravoReportBaseFileName -Timestamp '20260925_120000' -SanitizeActive -RealComputerName 'REAL-PC-2' -SanitizedComputerName 'REDACTED-COMPUTERNAME-1'

        $first | Should -Not -Be $second
    }

    It 'суфікс НЕ є похідним від реального ComputerName (не GetHashCode/hostname-based) — той самий реальний хост, різні виклики, різні суфікси' {
        $first = New-BravoReportBaseFileName -Timestamp '20260925_120000' -SanitizeActive -RealComputerName 'REAL-PC' -SanitizedComputerName 'REDACTED-COMPUTERNAME-1'
        $second = New-BravoReportBaseFileName -Timestamp '20260925_120000' -SanitizeActive -RealComputerName 'REAL-PC' -SanitizedComputerName 'REDACTED-COMPUTERNAME-1'

        $first | Should -Not -Be $second -Because 'детермінований (hostname-based) суфікс дав би однаковий результат для того самого реального хоста'
    }
}

Describe 'Export-BravoJsonReport / $script:SanitizeActive (src/50-Export-Json.ps1) — GeneratedFiles: серіалізований JSON без абсолютних шляхів, операційний масив незмінний (P1, exact-head review Phase 10; fail-open call-site gap закрито фреш-ревʼю Phase 10)' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\src\50-Export-Json.ps1')
    }

    BeforeEach {
        $script:outputDir = Join-Path $TestDrive 'out'
        New-Item -ItemType Directory -Path $script:outputDir -Force | Out-Null

        function Add-ExportError { param($Section, $Message) }
        function Add-AuditFinding { param($Severity, $Category, $Message, $Recommendation) }
    }

    AfterEach {
        # $script:SanitizeActive — глобальний run-wide прапорець (90-Main.ps1);
        # не повинен просочуватись між тестами.
        Remove-Variable -Name SanitizeActive -Scope Script -ErrorAction SilentlyContinue
    }

    It '$script:SanitizeActive=$true: серіалізований JSON на диску містить лише basenames у GeneratedFiles, без абсолютного шляху реального OutputPath' {
        $script:SanitizeActive = $true
        $realOutputDir = 'C:\Users\SECRETUSER\Reports\corp-host'
        $script:Report = [PSCustomObject]@{
            GeneratedFiles = @((Join-Path $realOutputDir 'BravoSystemReport_REDACTED-COMPUTERNAME-1_20260925_120000.html'))
        }

        Export-BravoJsonReport -OutputDir $script:outputDir -BaseFileName 'BravoSystemReport_REDACTED-COMPUTERNAME-1_20260925_120000'

        $jsonPath = Join-Path $script:outputDir 'BravoSystemReport_REDACTED-COMPUTERNAME-1_20260925_120000.json'
        $jsonContent = Get-Content -LiteralPath $jsonPath -Raw

        $jsonContent | Should -Not -Match 'SECRETUSER'
        $jsonContent | Should -Not -Match 'corp-host'
        $jsonContent | Should -Match 'BravoSystemReport_REDACTED-COMPUTERNAME-1_20260925_120000\.html'
    }

    It '$script:SanitizeActive=$true: після виклику $script:Report.GeneratedFiles (операційний масив у пам''яті) лишається з РЕАЛЬНИМИ абсолютними шляхами — ZIP/Email далі можуть Test-Path/attach' {
        $script:SanitizeActive = $true
        $realHtmlPath = 'C:\Users\SECRETUSER\Reports\corp-host\BravoSystemReport_REDACTED-COMPUTERNAME-1_20260925_120000.html'
        $script:Report = [PSCustomObject]@{
            GeneratedFiles = @($realHtmlPath)
        }

        Export-BravoJsonReport -OutputDir $script:outputDir -BaseFileName 'BravoSystemReport_REDACTED-COMPUTERNAME-1_20260925_120000'

        $script:Report.GeneratedFiles | Should -Contain $realHtmlPath -Because 'операційне використання (ZIP-пакування/email attach через Test-Path) вимагає реальних абсолютних шляхів, не basenames'
    }

    It '$script:SanitizeActive=$false: серіалізований JSON лишається з реальним абсолютним шляхом (задокументована поведінка не-sanitize запуску)' {
        $script:SanitizeActive = $false
        $realHtmlPath = 'C:\Reports\BravoSystemReport_REAL-PC_20260925_120000.html'
        $script:Report = [PSCustomObject]@{
            GeneratedFiles = @($realHtmlPath)
        }

        Export-BravoJsonReport -OutputDir $script:outputDir -BaseFileName 'BravoSystemReport_REAL-PC_20260925_120000'

        $jsonPath = Join-Path $script:outputDir 'BravoSystemReport_REAL-PC_20260925_120000.json'
        $jsonContent = Get-Content -LiteralPath $jsonPath -Raw

        $jsonContent | Should -Match 'REAL-PC'
    }

    It '$script:SanitizeActive не встановлено взагалі: fail-safe до НЕ-sanitize поведінки (реальний шлях серіалізується) — регресія на fail-open call-site gap, знайдену фреш-ревʼю Phase 10' {
        # До фіксу привʼязка до caller-переданого -Sanitize switch означала,
        # що будь-який майбутній виклик, який забув би передати прапорець,
        # мовчки серіалізував би реальний шлях у звіт, який оператор вважає
        # санітизованим. Після фіксу поведінка похідна від run-wide стану —
        # цей тест лише документує, що НЕвстановлена змінна (яку тут
        # AfterEach явно прибирає) не кидає виняток під Set-StrictMode-less
        # виконанням і трактується як $false (той самий default, що й раніше).
        $realHtmlPath = 'C:\Reports\BravoSystemReport_REAL-PC_20260925_120000.html'
        $script:Report = [PSCustomObject]@{
            GeneratedFiles = @($realHtmlPath)
        }

        { Export-BravoJsonReport -OutputDir $script:outputDir -BaseFileName 'BravoSystemReport_REAL-PC_20260925_120000' } | Should -Not -Throw

        $jsonPath = Join-Path $script:outputDir 'BravoSystemReport_REAL-PC_20260925_120000.json'
        Test-Path -LiteralPath $jsonPath | Should -Be $true
        # Друга хвиля фреш-ревʼю Phase 10: попередня версія цього тесту лише
        # перевіряла Should -Not -Throw/Test-Path — не читала JSON, тому була
        # vacuous і не впала б, навіть якби фікс нейтралізували (mutation
        # testing підтвердив). Явна перевірка реального шляху в серіалізації.
        (Get-Content -LiteralPath $jsonPath -Raw) | Should -Match 'C:\\\\Reports\\\\BravoSystemReport_REAL-PC'
    }
}
