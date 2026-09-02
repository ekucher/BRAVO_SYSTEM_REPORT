# MODULE: tests/ExecutionContract.Tests.ps1
# Регресійні тести для P0-стабілізації: єдиний execution contract між
# кореневим wrapper (Get-BravoSystemReport.ps1) і dist/Get-BravoSystemReport.ps1,
# коректний forwarding параметрів через ОБИДВА хопи (wrapper→dist,
# dist→elevated relaunch), розділення CollectionErrors/ExportErrors,
# детермінований exit code contract.
#
# Тести проти wrapper (не напряму проти dist) — саме там був корінь P0.1-P0.3:
# wrapper мав власний, вручну продубльований param()-блок, що розійшовся з
# src/05-Params.ps1 (інший default Profile, forwarding switch-параметрів
# губив явний -Zip:$false, відсутні -NoZip/-SkipPublicIP).
#
# Потребує адміністративних прав і реального Windows-оточення — пропускається,
# якщо wrapper/dist відсутні.

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:WrapperPath = Join-Path $script:RepoRoot 'Get-BravoSystemReport.ps1'
    $script:DistPath = Join-Path $script:RepoRoot 'dist\Get-BravoSystemReport.ps1'
    $script:ParamsSrcPath = Join-Path $script:RepoRoot 'src\05-Params.ps1'

    function New-BravoTestReportsDir {
        param([string]$Name)
        $dir = Join-Path $env:TEMP "bravo-pester-$Name"
        if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        return $dir
    }
}

Describe 'P0.1/P0.3 — єдиний default Profile (статична перевірка джерела)' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\Get-BravoSystemReport.ps1'))) {
    It 'wrapper НЕ визначає власний default для -Profile (єдине джерело — src/05-Params.ps1)' {
        $wrapperContent = Get-Content -LiteralPath $script:WrapperPath -Raw
        $wrapperContent | Should -Not -Match "\[string\]\`$Profile\s*=\s*['`"]"
    }

    It 'src/05-Params.ps1 залишається єдиним місцем з дефолтом Profile' {
        $paramsContent = Get-Content -LiteralPath $script:ParamsSrcPath -Raw
        $paramsContent | Should -Match "\[string\]\`$Profile\s*=\s*'Forensic'"
    }

    It 'wrapper НЕ визначає власний default для -EmailFrom (щоб не дублювати обчислення)' {
        $wrapperContent = Get-Content -LiteralPath $script:WrapperPath -Raw
        $wrapperContent | Should -Not -Match "\[string\]\`$EmailFrom\s*=\s*[^\)]"
    }
}

Describe 'P0.1/P0.2 — wrapper приймає й форвардить усі switch/bool-параметри' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\Get-BravoSystemReport.ps1'))) {
    It 'wrapper має -NoZip (раніше був відсутній повністю)' {
        (Get-Command $script:WrapperPath).Parameters.Keys | Should -Contain 'NoZip'
    }

    It 'wrapper має -SkipPublicIP (раніше був відсутній повністю)' {
        (Get-Command $script:WrapperPath).Parameters.Keys | Should -Contain 'SkipPublicIP'
    }

    It 'wrapper має -SkipGeoIP і -Offline (P1)' {
        (Get-Command $script:WrapperPath).Parameters.Keys | Should -Contain 'SkipGeoIP'
        (Get-Command $script:WrapperPath).Parameters.Keys | Should -Contain 'Offline'
    }

    It 'forwarding-логіка — transparent passthrough через $PSBoundParameters, не ручний if-блок на кожен параметр' {
        $wrapperContent = Get-Content -LiteralPath $script:WrapperPath -Raw
        $wrapperContent | Should -Match '\$PSBoundParameters\.Keys'
    }
}

Describe 'P0.2 — -NoZip і -Zip:$false коректно вимикають ZIP через wrapper (наскрізно)' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\Get-BravoSystemReport.ps1'))) {
    It '-NoZip через wrapper -> жодного ZIP-файлу' {
        $dir = New-BravoTestReportsDir -Name 'nozip'
        & $script:WrapperPath -Profile Quick -NoZip -SkipElevation -NoPause -NoOpenFolder -OutputPath $dir 2>&1 | Out-Null
        $exitCode = $LASTEXITCODE
        $zipFiles = Get-ChildItem -LiteralPath $dir -Filter '*.zip' -Recurse -ErrorAction SilentlyContinue
        $zipFiles | Should -BeNullOrEmpty
        $exitCode | Should -Be 0
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It '-Zip:$false через wrapper -> жодного ZIP-файлу' {
        $dir = New-BravoTestReportsDir -Name 'zipfalse'
        & $script:WrapperPath -Profile Quick -Zip:$false -SkipElevation -NoPause -NoOpenFolder -OutputPath $dir 2>&1 | Out-Null
        $exitCode = $LASTEXITCODE
        $zipFiles = Get-ChildItem -LiteralPath $dir -Filter '*.zip' -Recurse -ErrorAction SilentlyContinue
        $zipFiles | Should -BeNullOrEmpty
        $exitCode | Should -Be 0
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'P1 — -Offline вимикає всі зовнішні HTTPS-запити (Public IPv4, GeoIP, онлайн-пошук оновлень)' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\Get-BravoSystemReport.ps1'))) {
    It '-Offline через wrapper (профіль Full, де Public IP інакше виконувався б) -> усе Skipped, exit code 0' {
        $dir = New-BravoTestReportsDir -Name 'offline'
        & $script:WrapperPath -Profile Full -Offline -NoZip -SkipElevation -NoPause -NoOpenFolder -OutputPath $dir 2>&1 | Out-Null
        $exitCode = $LASTEXITCODE
        $json = Get-ChildItem -LiteralPath $dir -Filter '*.json' -Recurse | Select-Object -First 1
        $report = Get-Content -LiteralPath $json.FullName -Raw | ConvertFrom-Json

        $exitCode | Should -Be 0
        $report.Network.IP.PublicIPv4Status | Should -Be 'Skipped'
        $report.Network.IP.PublicIPv4ProviderInfoStatus | Should -Be 'Skipped'
        $report.Updates.Search.Status | Should -Be 'Skipped'
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'P1 — -Strict дає окремий exit code 4 на CRITICAL Health.Status' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\Get-BravoSystemReport.ps1'))) {
    It 'wrapper має -Strict (раніше був відсутній повністю)' {
        (Get-Command $script:WrapperPath).Parameters.Keys | Should -Contain 'Strict'
    }

    It 'без -Strict: CRITICAL Health.Status НЕ впливає на exit code (лишається 0)' {
        $dir = New-BravoTestReportsDir -Name 'strict-off'
        & $script:WrapperPath -Profile Quick -NoZip -SkipElevation -NoPause -NoOpenFolder -OutputPath $dir 2>&1 | Out-Null
        $exitCode = $LASTEXITCODE
        $json = Get-ChildItem -LiteralPath $dir -Filter '*.json' -Recurse | Select-Object -First 1
        $report = Get-Content -LiteralPath $json.FullName -Raw | ConvertFrom-Json

        # Ця тестова машина реально звітує CRITICAL (Health.Score нижче порогу) —
        # саме тому тест значущий: без -Strict це не мало б впливати на exit code.
        if ($report.Health.Status -eq 'CRITICAL') {
            $exitCode | Should -Be 0
        }
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It '-Strict через wrapper: CRITICAL Health.Status -> exit code 4' {
        $dir = New-BravoTestReportsDir -Name 'strict-on'
        & $script:WrapperPath -Profile Quick -Strict -NoZip -SkipElevation -NoPause -NoOpenFolder -OutputPath $dir 2>&1 | Out-Null
        $exitCode = $LASTEXITCODE
        $json = Get-ChildItem -LiteralPath $dir -Filter '*.json' -Recurse | Select-Object -First 1
        $report = Get-Content -LiteralPath $json.FullName -Raw | ConvertFrom-Json

        if ($report.Health.Status -eq 'CRITICAL') {
            $exitCode | Should -Be 4
        } else {
            $exitCode | Should -Be 0
        }
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'P1 — -Sanitize маскує ComputerName у JSON (наскрізно через wrapper)' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\Get-BravoSystemReport.ps1'))) {
    It 'wrapper має -Sanitize і -SanitizeLevel' {
        (Get-Command $script:WrapperPath).Parameters.Keys | Should -Contain 'Sanitize'
        (Get-Command $script:WrapperPath).Parameters.Keys | Should -Contain 'SanitizeLevel'
    }

    It '-Sanitize через wrapper -> ComputerName у JSON замаскований, реальна назва машини не потрапляє у файл' {
        $dir = New-BravoTestReportsDir -Name 'sanitize'
        & $script:WrapperPath -Profile Quick -Sanitize -NoZip -SkipElevation -NoPause -NoOpenFolder -OutputPath $dir 2>&1 | Out-Null
        $exitCode = $LASTEXITCODE
        $json = Get-ChildItem -LiteralPath $dir -Filter '*.json' -Recurse | Select-Object -First 1
        $rawJson = Get-Content -LiteralPath $json.FullName -Raw
        $report = $rawJson | ConvertFrom-Json

        $exitCode | Should -Be 0
        $report.ComputerName | Should -Match '^REDACTED-COMPUTERNAME-'
        $rawJson | Should -Not -Match ([regex]::Escape($env:COMPUTERNAME))
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'P1 — CI validation для -SanitizeLevel Strict (ROADMAP v0.4.3)' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\Get-BravoSystemReport.ps1'))) {
    # -Profile Full, щоб зібрати всі поля, які маскує Strict (adapters/MAC,
    # PhysicalDisks serials, listening ports) — Quick їх не збирає взагалі.
    # -Offline вимикає Public IP/GeoIP HTTP-запити (детермінізм у CI, без
    # мережевої залежності); структурні перевірки нижче не залежать від
    # мережі, бо оцінюють лише приватні/локальні поля.
    #
    # Навмисно НЕ використовуємо "сліпий" regex-скан усього файлу на IPv4-
    # патерн: версії встановленого ПЗ (Software.Installed[].Version, напр.
    # "10.0.11.50") масово збігаються з форматом IPv4 і дають сотні false
    # positive на реальній машині — перевірено вручну перед додаванням цього
    # тесту. Замість цього — точкові перевірки конкретних полів схеми, які
    # Invoke-BravoReportSanitization маскує (src/45-Sanitize.ps1).
    BeforeAll {
        $script:SanitizeStrictDir = New-BravoTestReportsDir -Name 'sanitize-strict'
        & $script:WrapperPath -Profile Full -Sanitize -SanitizeLevel Strict -Offline -NoZip -SkipElevation -NoPause -NoOpenFolder -OutputPath $script:SanitizeStrictDir 2>&1 | Out-Null
        $script:SanitizeStrictExitCode = $LASTEXITCODE

        $jsonFile = Get-ChildItem -LiteralPath $script:SanitizeStrictDir -Filter '*.json' -Recurse | Select-Object -First 1
        $htmlFile = Get-ChildItem -LiteralPath $script:SanitizeStrictDir -Filter '*.html' -Recurse | Select-Object -First 1
        $script:SanitizeStrictRawJson = Get-Content -LiteralPath $jsonFile.FullName -Raw
        $script:SanitizeStrictRawHtml = Get-Content -LiteralPath $htmlFile.FullName -Raw
        $script:SanitizeStrictReport = $script:SanitizeStrictRawJson | ConvertFrom-Json
    }

    AfterAll {
        Remove-Item -LiteralPath $script:SanitizeStrictDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'завершується exit code 0, структура JSON не зламана маскуванням (валідний ConvertFrom-Json, CollectionErrors=0)' {
        $script:SanitizeStrictExitCode | Should -Be 0
        $script:SanitizeStrictReport | Should -Not -BeNullOrEmpty
        @($script:SanitizeStrictReport.CollectionErrors).Count | Should -Be 0
        @($script:SanitizeStrictReport.ExportErrors).Count | Should -Be 0
    }

    It 'ComputerName/UserName/UserDomainName/Hostname структурно замасковані у відповідних полях схеми' {
        # НЕ скануємо весь сирий текст на literal $env:USERNAME/$env:COMPUTERNAME:
        # OutputPath (звіт зберігається під $env:TEMP\...\<username>\...) свідомо
        # НЕ маскується Sanitize — це операційний шлях збереження файлу, а не
        # PII про аудитовану машину, і легітимно містить $env:USERNAME як частину
        # шляху профілю Windows. Блимаючий full-text-скан тому дає false positive
        # на кожному прогоні. Перевіряємо точково лише поля, які реально маскує
        # Invoke-BravoReportSanitization (src/45-Sanitize.ps1).
        $script:SanitizeStrictReport.ComputerName | Should -Match '^REDACTED-COMPUTERNAME-\d+$'
        $script:SanitizeStrictReport.Meta.UserName | Should -Match '^REDACTED-USER-\d+$'
        $script:SanitizeStrictReport.Meta.UserDomainName | Should -Match '^REDACTED-DOMAIN-\d+$'
        $script:SanitizeStrictReport.Network.General.Hostname | Should -Match '^REDACTED-COMPUTERNAME-\d+$'
        $script:SanitizeStrictReport.Dashboard.Header.ComputerName | Should -Match '^REDACTED-COMPUTERNAME-\d+$'
    }

    It 'Network.IP.IPv4/PrimaryIPv4 та адреси адаптерів замасковані (REDACTED-PRIVATE-IP-N)' {
        foreach ($ip in @($script:SanitizeStrictReport.Network.IP.IPv4)) {
            $ip | Should -Match '^REDACTED-PRIVATE-IP-\d+$'
        }
        if ($script:SanitizeStrictReport.Network.IP.PrimaryIPv4 -and $script:SanitizeStrictReport.Network.IP.PrimaryIPv4 -ne 'N/A') {
            $script:SanitizeStrictReport.Network.IP.PrimaryIPv4 | Should -Match '^REDACTED-PRIVATE-IP-\d+$'
        }
        foreach ($adapter in @($script:SanitizeStrictReport.Network.Adapters)) {
            foreach ($ip in @($adapter.IPv4)) {
                $ip | Should -Match '^REDACTED-PRIVATE-IP-\d+$'
            }
        }
    }

    It 'MAC-адреси адаптерів замасковані (REDACTED-MAC-N), у сирому JSON немає жодного literal MAC-патерну' {
        foreach ($adapter in @($script:SanitizeStrictReport.Network.Adapters)) {
            if ($adapter.MACAddress) {
                $adapter.MACAddress | Should -Match '^REDACTED-MAC-\d+$'
            }
        }
        $script:SanitizeStrictRawJson | Should -Not -Match '([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}'
    }

    It 'серійні номери BIOS/PhysicalDisks замасковані (REDACTED-SERIAL-N)' {
        if ($script:SanitizeStrictReport.BIOS.SerialNumber) {
            $script:SanitizeStrictReport.BIOS.SerialNumber | Should -Match '^REDACTED-SERIAL-\d+$'
        }
        foreach ($disk in @($script:SanitizeStrictReport.Hardware.Disks.PhysicalDisks)) {
            if ($disk.SerialNumber) {
                $disk.SerialNumber | Should -Match '^REDACTED-SERIAL-\d+$'
            }
        }
    }

    It 'HTML-експорт містить REDACTED-токени (маскування дійшло до export-етапу, а не лише до JSON)' {
        $script:SanitizeStrictRawHtml | Should -Match 'REDACTED-COMPUTERNAME-'
    }
}

Describe 'v0.5.0 Deep Inventory — Secure Boot / TPM' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\Get-BravoSystemReport.ps1'))) {
    BeforeAll {
        $script:DeepSecurityDir = New-BravoTestReportsDir -Name 'deep-security'
        & $script:WrapperPath -Profile Full -Offline -NoZip -SkipElevation -NoPause -NoOpenFolder -OutputPath $script:DeepSecurityDir 2>&1 | Out-Null
        $script:DeepSecurityExitCode = $LASTEXITCODE
        $jsonFile = Get-ChildItem -LiteralPath $script:DeepSecurityDir -Filter '*.json' -Recurse | Select-Object -First 1
        $script:DeepSecurityReport = Get-Content -LiteralPath $jsonFile.FullName -Raw | ConvertFrom-Json
    }

    AfterAll {
        Remove-Item -LiteralPath $script:DeepSecurityDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'завершується exit code 0, CollectionErrors=0 (відсутність Secure Boot/TPM на машині — не помилка збору)' {
        $script:DeepSecurityExitCode | Should -Be 0
        @($script:DeepSecurityReport.CollectionErrors).Count | Should -Be 0
    }

    It 'Security.SecureBoot.Status — одне з очікуваних значень, ніколи не залишається NotChecked на Full-профілі' {
        $script:DeepSecurityReport.Security.SecureBoot.Status | Should -BeIn @('Enabled', 'Disabled', 'NotSupported', 'Unknown')
    }

    It 'Security.TPM.Status — одне з очікуваних значень, ніколи не залишається NotChecked на Full-профілі' {
        $script:DeepSecurityReport.Security.TPM.Status | Should -BeIn @('Detected', 'NotPresent')
    }

    It 'якщо TPM.Status=Detected, то Present=true і Ready — визначений bool (не null)' {
        if ($script:DeepSecurityReport.Security.TPM.Status -eq 'Detected') {
            $script:DeepSecurityReport.Security.TPM.Present | Should -Be $true
            $script:DeepSecurityReport.Security.TPM.Ready | Should -BeIn @($true, $false)
        } else {
            Set-ItResult -Skipped -Because 'TPM не виявлено на цій машині (Status=NotPresent) — нема що перевіряти'
        }
    }
}

Describe 'P0.4/P0.5 — CollectionErrors/ExportErrors розділені, exit code відповідає стану' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\Get-BravoSystemReport.ps1'))) {
    It 'успішний Quick-прогін -> exit code 0, CollectionErrors=0, ExportErrors=0' {
        $dir = New-BravoTestReportsDir -Name 'exit0'
        & $script:WrapperPath -Profile Quick -NoZip -SkipElevation -NoPause -NoOpenFolder -OutputPath $dir 2>&1 | Out-Null
        $exitCode = $LASTEXITCODE
        $json = Get-ChildItem -LiteralPath $dir -Filter '*.json' -Recurse | Select-Object -First 1
        $report = Get-Content -LiteralPath $json.FullName -Raw | ConvertFrom-Json

        $exitCode | Should -Be 0
        @($report.CollectionErrors).Count | Should -Be 0
        @($report.ExportErrors).Count | Should -Be 0
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'export-помилка (невалідний SMTP) -> exit code 1, ExportErrors>0, CollectionErrors не зачеплено, JSON відображає фінальний стан' {
        $dir = New-BravoTestReportsDir -Name 'exit1'
        & $script:WrapperPath -Profile Quick -NoZip -SkipElevation -NoPause -NoOpenFolder -EmailTo 'test@example.com' -SmtpServer 'nonexistent.invalid.smtp.local' -OutputPath $dir 2>&1 | Out-Null
        $exitCode = $LASTEXITCODE

        $json = Get-ChildItem -LiteralPath $dir -Filter '*.json' -Recurse | Select-Object -First 1
        $report = Get-Content -LiteralPath $json.FullName -Raw | ConvertFrom-Json

        $exitCode | Should -Be 1
        @($report.CollectionErrors).Count | Should -Be 0
        @($report.ExportErrors).Count | Should -BeGreaterThan 0
        ($report.ExportErrors | Where-Object { $_.Section -eq 'Export.Email' }) | Should -Not -BeNullOrEmpty
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
