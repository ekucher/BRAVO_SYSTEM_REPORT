# MODULE: tests/ExportResult.Tests.ps1
# Pester-тести для структурованого export-контракту (Issue #99,
# src/49-Export-Result.ps1) — New-BravoExportResult як чиста функція, і
# кожен Export-Bravo*Report/Send-BravoEmailReport повертає коректний
# Type/Success/Skipped/Path/Error/DurationSeconds для свого
# success/skip/failure шляху. Існуючі E2E-тести (ExecutionContract.Tests.ps1)
# уже перевіряють ПОВЕДІНКУ (файли реально створюються, зміст коректний) —
# тут перевіряється саме RETURN VALUE, якого раніше не існувало взагалі.

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\49-Export-Result.ps1')

    $IconJson = '[J]'; $IconHtml = '[H]'; $IconCsv = '[C]'; $IconZip = '[Z]'
    $IconEmail = '[E]'; $IconError = '[!]'

    function New-BravoFakeExportReport {
        [ordered]@{
            ComputerName  = 'TEST-PC'
            Timestamp     = '2026-10-18 12:00:00'
            Profile       = 'Quick'
            Status        = 'OK'
            StatusReason  = 'test'
            ScriptVersion = '0.6.1'
            SchemaVersion = '0.6.20'
            Health        = [ordered]@{ Score = 100; Status = 'OK'; Findings = @() }
            OS            = [ordered]@{ Caption = 'Test OS'; Version = '10.0'; Build = '19045'; UptimeDays = 1; UptimeHours = 1 }
            Hardware      = [ordered]@{
                CPU   = [ordered]@{ Cores = 1; LogicalProcessors = 1; LoadPercent = 1; Name = 'Test CPU' }
                RAM   = [ordered]@{ TotalGB = 1; UsedPercent = 1; UsedGB = 1 }
                Disks = [ordered]@{ FreePercent = 50; TotalGB = 1; FreeGB = 1 }
            }
            Network       = [ordered]@{ IP = [ordered]@{ IPv4 = @('10.0.0.1') } }
            Security      = [ordered]@{
                RemoteAccess = [ordered]@{ RDPEnabled = $false }
                UAC          = [ordered]@{ Enabled = $true }
                SecureBoot   = [ordered]@{ Status = 'Enabled' }
                TPM          = [ordered]@{ Status = 'Detected' }
            }
            Processes     = [ordered]@{ Total = 1 }
            Services      = [ordered]@{ Running = 1; AutomaticStopped = @() }
            EventLogs     = [ordered]@{ SystemErrors24h = 0; SystemErrors = 0 }
            Software      = [ordered]@{ Installed = @() }
            Updates       = [ordered]@{
                OS        = [ordered]@{ SupportStatus = 'OK'; SupportEndDate = '' }
                Search    = [ordered]@{ Status = 'Skipped' }
                Pending   = [ordered]@{ Total = 0; Security = 0 }
                PendingReboot = [ordered]@{ Required = $false }
                Installed = [ordered]@{ LastInstalledOn = ''; DaysSinceLastUpdate = 0 }
            }
            Users         = [ordered]@{ LocalAdmins = @() }
            CollectionErrors = @()
            ExportErrors  = @()
            GeneratedFiles = @()
        }
    }
}

Describe 'New-BravoExportResult' {
    It 'Success без Path/Error/Duration -> усі опційні поля $null, Skipped=$false' {
        $r = New-BravoExportResult -Type 'Json' -Success $true
        $r.Type | Should -Be 'Json'
        $r.Success | Should -BeTrue
        $r.Skipped | Should -BeFalse
        $r.Path | Should -BeNullOrEmpty
        $r.Error | Should -BeNullOrEmpty
        $r.DurationSeconds | Should -BeNullOrEmpty
    }

    It 'Success з Path і DurationSeconds -> округлення до 2 знаків' {
        $r = New-BravoExportResult -Type 'Html' -Success $true -Path 'C:\x\report.html' -DurationSeconds 1.23456
        $r.Path | Should -Be 'C:\x\report.html'
        $r.DurationSeconds | Should -Be 1.23
    }

    It 'Failure -> Success=$false, Error заповнено' {
        $r = New-BravoExportResult -Type 'Zip' -Success $false -ErrorMessage 'boom'
        $r.Success | Should -BeFalse
        $r.Error | Should -Be 'boom'
        $r.Path | Should -BeNullOrEmpty
    }

    It 'Skipped -> Success=$true, Skipped=$true, без Path/Error' {
        $r = New-BravoExportResult -Type 'Csv' -Success $true -Skipped
        $r.Success | Should -BeTrue
        $r.Skipped | Should -BeTrue
        $r.Path | Should -BeNullOrEmpty
        $r.Error | Should -BeNullOrEmpty
    }

    It 'невідомий Type відхиляється ValidateSet-ом' {
        { New-BravoExportResult -Type 'Unknown' -Success $true } | Should -Throw
    }
}

Describe 'Export-BravoJsonReport result contract' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\src\50-Export-Json.ps1')
        $script:CapturedErrors = @()
        function Add-ExportError { param($Section, $Message) $script:CapturedErrors += [PSCustomObject]@{Section=$Section;Message=$Message} }
    }

    BeforeEach {
        $script:CapturedErrors = @()
        $script:SanitizeActive = $false
        $script:outDir = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:outDir -Force | Out-Null
        $script:Report = New-BravoFakeExportReport
    }

    It 'успіх -> Success=$true, Type=Json, Path існує, DurationSeconds >= 0' {
        $result = Export-BravoJsonReport -OutputDir $script:outDir -BaseFileName 'report'
        $result.Type | Should -Be 'Json'
        $result.Success | Should -BeTrue
        $result.Skipped | Should -BeFalse
        $result.Path | Should -Be (Join-Path $script:outDir 'report.json')
        Test-Path -LiteralPath $result.Path | Should -BeTrue
        $result.Error | Should -BeNullOrEmpty
        $result.DurationSeconds | Should -BeGreaterOrEqual 0
    }

    It 'невалідний OutputDir -> Success=$false, Error заповнено, і Add-ExportError теж викликано (audit trail не губиться)' {
        $result = Export-BravoJsonReport -OutputDir 'Z:\does-not-exist\nested' -BaseFileName 'report'
        $result.Success | Should -BeFalse
        $result.Error | Should -Not -BeNullOrEmpty
        $script:CapturedErrors.Count | Should -Be 1
        $script:CapturedErrors[0].Message | Should -Be $result.Error
    }
}

Describe 'Export-BravoCsvReport result contract' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\src\49-Export-Result.ps1')
        . (Join-Path $PSScriptRoot '..\src\52-Export-Csv.ps1')
        function Add-ExportError { param($Section, $Message) }
    }

    BeforeEach {
        $script:outDir = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:outDir -Force | Out-Null
        $script:Report = New-BravoFakeExportReport
    }

    It '-CSV:$false -> Skipped=$true, Success=$true, без Path' {
        $result = Export-BravoCsvReport -OutputDir $script:outDir -BaseFileName 'report' -CSV $false
        $result.Skipped | Should -BeTrue
        $result.Success | Should -BeTrue
        $result.Path | Should -BeNullOrEmpty
        Test-Path -LiteralPath (Join-Path $script:outDir 'report.csv') | Should -BeFalse
    }

    It '-CSV:$true -> Success=$true, Path існує' {
        $result = Export-BravoCsvReport -OutputDir $script:outDir -BaseFileName 'report' -CSV $true
        $result.Success | Should -BeTrue
        $result.Skipped | Should -BeFalse
        $result.Path | Should -Be (Join-Path $script:outDir 'report.csv')
        Test-Path -LiteralPath $result.Path | Should -BeTrue
    }
}

Describe 'Export-BravoZipReport result contract' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\src\49-Export-Result.ps1')
        . (Join-Path $PSScriptRoot '..\src\53-Export-Zip.ps1')
        function Add-ExportError { param($Section, $Message) }
    }

    BeforeEach {
        $script:outDir = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:outDir -Force | Out-Null
        $script:Report = New-BravoFakeExportReport
    }

    It '-Zip:$false -> Skipped=$true' {
        $result = Export-BravoZipReport -OutputDir $script:outDir -BaseFileName 'report' -Zip $false
        $result.Skipped | Should -BeTrue
        $result.Success | Should -BeTrue
        $result.Path | Should -BeNullOrEmpty
    }

    It '-Zip:$true, GeneratedFiles порожній -> Success=$true, порожній ZIP створено, Path вказує на реальний файл' {
        $result = Export-BravoZipReport -OutputDir $script:outDir -BaseFileName 'report' -Zip $true
        $result.Success | Should -BeTrue
        $result.Path | Should -Be (Join-Path $script:outDir 'report.zip')
        Test-Path -LiteralPath $result.Path | Should -BeTrue
    }

    # Загальне покриття успішного шляху: цей тест проходив би й до виправлення (finally виконувався до повернення).
    # Регресію фіналізації ловить наступний тест (виняток у Dispose).
    It 'Success-шлях: ZIP валідний (відкривається ZipFile::OpenRead) і містить файли, zipPath у GeneratedFiles' {
        $src = Join-Path $script:outDir 'a.txt'
        Set-Content -LiteralPath $src -Value 'hello'
        $script:Report.GeneratedFiles = @($src)

        $result = Export-BravoZipReport -OutputDir $script:outDir -BaseFileName 'report' -Zip $true
        $result.Success | Should -BeTrue
        $script:Report.GeneratedFiles | Should -Contain $result.Path

        $zip = [System.IO.Compression.ZipFile]::OpenRead($result.Path)
        try {
            @($zip.Entries | ForEach-Object { $_.Name }) | Should -Contain 'a.txt'
        } finally {
            $zip.Dispose()
        }
    }

    It 'Виняток під час фіналізації (Dispose) -> Success=$false, ExportError Export.Zip, zipPath не в GeneratedFiles, недописаний ZIP видалено' {
        # Fake ZipArchive не підтримує CreateEntryFromFile, тож список файлів має бути порожнім:
        # тест перевіряє саме фіналізацію (Dispose), а не додавання записів.
        $script:Report.GeneratedFiles = @()
        $script:errSections = @()
        Mock Add-ExportError { $script:errSections += $Section }
        Mock New-Object {
            $fake = [pscustomobject]@{}
            $fake | Add-Member -MemberType ScriptMethod -Name Dispose -Value { throw 'finalize boom' }
            $fake
        } -ParameterFilter { $TypeName -eq 'System.IO.Compression.ZipArchive' }

        $result = Export-BravoZipReport -OutputDir $script:outDir -BaseFileName 'report' -Zip $true
        $result.Success | Should -BeFalse
        $result.Error | Should -Match 'finalize boom'
        $script:errSections | Should -Contain 'Export.Zip'
        $script:Report.GeneratedFiles | Should -Not -Contain (Join-Path $script:outDir 'report.zip')
        Test-Path -LiteralPath (Join-Path $script:outDir 'report.zip') | Should -BeFalse
    }
}

Describe 'Export-BravoTxtReport / Export-BravoMdReport result contract' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\src\49-Export-Result.ps1')
        . (Join-Path $PSScriptRoot '..\src\40-Health.ps1')
        . (Join-Path $PSScriptRoot '..\src\55-Export-Txt.ps1')
        . (Join-Path $PSScriptRoot '..\src\56-Export-Md.ps1')
        function Add-ExportError { param($Section, $Message) }
    }

    BeforeEach {
        $script:outDir = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:outDir -Force | Out-Null
        $script:Report = New-BravoFakeExportReport
    }

    It 'TXT: -TXT:$false -> Skipped; -TXT:$true -> Success з Path' {
        $skipped = Export-BravoTxtReport -OutputDir $script:outDir -BaseFileName 'report' -TXT $false
        $skipped.Skipped | Should -BeTrue

        $ok = Export-BravoTxtReport -OutputDir $script:outDir -BaseFileName 'report' -TXT $true
        $ok.Success | Should -BeTrue
        $ok.Path | Should -Be (Join-Path $script:outDir 'report.txt')
        Test-Path -LiteralPath $ok.Path | Should -BeTrue
    }

    It 'MD: -MD:$false -> Skipped; -MD:$true -> Success з Path' {
        $skipped = Export-BravoMdReport -OutputDir $script:outDir -BaseFileName 'report' -MD $false
        $skipped.Skipped | Should -BeTrue

        $ok = Export-BravoMdReport -OutputDir $script:outDir -BaseFileName 'report' -MD $true
        $ok.Success | Should -BeTrue
        $ok.Path | Should -Be (Join-Path $script:outDir 'report.md')
        Test-Path -LiteralPath $ok.Path | Should -BeTrue
    }
}

Describe 'Send-BravoEmailReport result contract' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\src\49-Export-Result.ps1')
        . (Join-Path $PSScriptRoot '..\src\54-Export-Email.ps1')
        function Add-ExportError { param($Section, $Message) }
    }

    BeforeEach {
        $script:Report = New-BravoFakeExportReport
    }

    It 'без -EmailTo -> Skipped=$true' {
        $result = Send-BravoEmailReport -EmailTo '' -EmailFrom 'a@b.c' -SmtpServer 'smtp.example.com'
        $result.Skipped | Should -BeTrue
        $result.Success | Should -BeTrue
    }

    It 'Send-MailMessage кидає виняток -> Success=$false, Error заповнено' {
        Mock Send-MailMessage { throw 'simulated SMTP failure' }
        $result = Send-BravoEmailReport -EmailTo 'to@example.com' -EmailFrom 'from@example.com' -SmtpServer 'smtp.example.com'
        $result.Success | Should -BeFalse
        $result.Error | Should -Match 'simulated SMTP failure'
    }

    It 'GeneratedFiles порожній (нема жодного не-ZIP файлу) -> Attachments НЕ передається, Send-MailMessage не падає на ValidateNotNullOrEmpty' {
        $script:Report.GeneratedFiles = @()
        Mock Send-MailMessage { }
        $result = Send-BravoEmailReport -EmailTo 'to@example.com' -EmailFrom 'from@example.com' -SmtpServer 'smtp.example.com'
        $result.Success | Should -BeTrue
        $result.Error | Should -BeNullOrEmpty
        Should -Invoke Send-MailMessage -Times 1 -ParameterFilter { -not $PSBoundParameters.ContainsKey('Attachments') }
    }

    It 'без -SmtpServer і з порожнім USERDNSDOMAIN -> Success=$false, повідомлення про SMTP, Send-MailMessage не викликається' {
        Mock Send-MailMessage { }
        $savedDnsDomain = $env:USERDNSDOMAIN
        try {
            $env:USERDNSDOMAIN = $null
            $result = Send-BravoEmailReport -EmailTo 'to@example.com' -EmailFrom 'from@example.com'
        } finally {
            $env:USERDNSDOMAIN = $savedDnsDomain
        }
        $result.Success | Should -BeFalse
        $result.Error | Should -Match 'SMTP'
        $result.Error | Should -Match '-SmtpServer'
        Should -Invoke Send-MailMessage -Times 0
    }

    It 'успішна відправка -> Success=$true, без Path (Email не генерує файл)' {
        Mock Send-MailMessage { }
        $result = Send-BravoEmailReport -EmailTo 'to@example.com' -EmailFrom 'from@example.com' -SmtpServer 'smtp.example.com'
        $result.Success | Should -BeTrue
        $result.Skipped | Should -BeFalse
        $result.Path | Should -BeNullOrEmpty
    }
}

Describe 'Export-BravoHtmlReport / Export-BravoPdfReport result contract' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\src\49-Export-Result.ps1')
        . (Join-Path $PSScriptRoot '..\src\51-Export-Html.ps1')
        function Add-ExportError { param($Section, $Message) }
    }

    BeforeEach {
        $script:outDir = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:outDir -Force | Out-Null
        $script:Report = New-BravoFakeExportReport
    }

    It 'HTML: -JSONOnly:$true -> Skipped=$true, HTML-файл не створюється' {
        $result = Export-BravoHtmlReport -OutputDir $script:outDir -BaseFileName 'report' -JSONOnly $true -EventLogDays 1 -Profile 'Quick' -ScriptVersion '0.6.1'
        $result.Skipped | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:outDir 'report.html') | Should -BeFalse
    }

    It 'PDF: HTML-файл відсутній -> Skipped=$true (нема з чого конвертувати)' {
        $result = Export-BravoPdfReport -OutputDir $script:outDir -BaseFileName 'report'
        $result.Skipped | Should -BeTrue
        $result.Success | Should -BeTrue
    }

    It 'PDF: HTML присутній, msedge.exe не знайдено -> Skipped=$true (опційна залежність)' {
        Set-Content -LiteralPath (Join-Path $script:outDir 'report.html') -Value '<html></html>'
        Mock Get-BravoEdgeExecutablePath { $null }
        $result = Export-BravoPdfReport -OutputDir $script:outDir -BaseFileName 'report'
        $result.Skipped | Should -BeTrue
        $result.Success | Should -BeTrue
    }

    It 'PDF: Edge повертає ненульовий exit code -> Success=$false, Error заповнено' {
        Set-Content -LiteralPath (Join-Path $script:outDir 'report.html') -Value '<html></html>'
        Mock Get-BravoEdgeExecutablePath { 'C:\fake\msedge.exe' }
        Mock Start-Process { [PSCustomObject]@{ ExitCode = 1 } }
        $result = Export-BravoPdfReport -OutputDir $script:outDir -BaseFileName 'report'
        $result.Success | Should -BeFalse
        $result.Error | Should -Match 'exit code 1'
    }
}
