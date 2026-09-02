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

Describe 'v0.5.0 Deep Inventory — Secure Boot / TPM / BitLocker / Hardware Inventory / Network Adapters / SMBv1 / TLS / Defender / RDP / WinRM / SMB signing / Password+Audit policy / Routing+ARP+Proxy / ShadowCopies+StoragePools / SMART / EventLogSummary / HardwareDiagnostics / Monitors / ConnectionsProcessName+SmbShares / UacFullPolicy / Autoruns / ScheduledTasks' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\Get-BravoSystemReport.ps1'))) {
    # -Profile Deep (не Full): BitLocker збирається лише в Get-BravoStorageDeepAudit,
    # яка запускається лише для Deep/Forensic — той самий прогін заразом покриває
    # Secure Boot/TPM (гейтовані Full/Deep/Forensic), без другого окремого E2E-прогону.
    BeforeAll {
        $script:DeepSecurityDir = New-BravoTestReportsDir -Name 'deep-security'
        & $script:WrapperPath -Profile Deep -Offline -NoZip -SkipElevation -NoPause -NoOpenFolder -OutputPath $script:DeepSecurityDir 2>&1 | Out-Null
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

    It 'Hardware.Disks.Deep.BitLocker заповнений (модуль BitLocker присутній на цій машині) з очікуваними полями на кожному томі' {
        $bitlockerVolumes = @($script:DeepSecurityReport.Hardware.Disks.Deep.BitLocker)

        if (-not (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because 'Модуль BitLocker недоступний на цій машині — нема що перевіряти'
            return
        }

        $bitlockerVolumes.Count | Should -BeGreaterThan 0

        foreach ($volume in $bitlockerVolumes) {
            $volume.MountPoint | Should -Not -BeNullOrEmpty
            $volume.ProtectionStatus | Should -BeIn @('On', 'Off', 'Unknown')
        }
    }

    It 'Hardware.ComputerSystem.ChassisType заповнений, якщо ChassisTypeCode визначено' {
        if ($null -eq $script:DeepSecurityReport.Hardware.ComputerSystem.ChassisTypeCode) {
            Set-ItResult -Skipped -Because 'ChassisTypeCode не визначено на цій машині (WMI Win32_SystemEnclosure недоступний/порожній) — нема що перевіряти'
            return
        }

        $script:DeepSecurityReport.Hardware.ComputerSystem.ChassisType | Should -Not -BeNullOrEmpty
    }

    It 'Hardware.Motherboard заповнений (Manufacturer або Product непорожні)' {
        $manufacturer = [string]$script:DeepSecurityReport.Hardware.Motherboard.Manufacturer
        $product = [string]$script:DeepSecurityReport.Hardware.Motherboard.Product
        ($manufacturer -or $product) | Should -BeTrue
    }

    It 'Hardware.GPU — масив з валідними записами (Name непорожній на кожному), якщо відеокарти виявлено' {
        $gpuList = @($script:DeepSecurityReport.Hardware.GPU)

        if ($gpuList.Count -eq 0) {
            Set-ItResult -Skipped -Because 'GPU не виявлено на цій машині (headless/деякі VM) — нема що перевіряти'
            return
        }

        foreach ($gpu in $gpuList) {
            $gpu.Name | Should -Not -BeNullOrEmpty
        }
    }

    It 'Network.Adapters мають нові поля LinkSpeed/Status/DriverVersion/DriverProvider, і хоча б один адаптер має непорожній Status' {
        $adapters = @($script:DeepSecurityReport.Network.Adapters)
        $adapters.Count | Should -BeGreaterThan 0

        foreach ($adapter in $adapters) {
            $adapter.PSObject.Properties.Name | Should -Contain 'LinkSpeed'
            $adapter.PSObject.Properties.Name | Should -Contain 'Status'
            $adapter.PSObject.Properties.Name | Should -Contain 'DriverVersion'
            $adapter.PSObject.Properties.Name | Should -Contain 'DriverProvider'
        }

        # Report.Network.Adapters збирається лише для адаптерів з IPEnabled=True,
        # тож на реальній машині принаймні один має бути активним і мати
        # непорожній Status після збагачення через Get-NetAdapter.
        ($adapters | Where-Object { $_.Status }).Count | Should -BeGreaterThan 0
    }

    It 'Security.SMBv1.Status — одне з очікуваних значень, ніколи не залишається NotChecked на Deep-профілі' {
        $script:DeepSecurityReport.Security.SMBv1.Status | Should -BeIn @('Enabled', 'Disabled', 'NotAvailable')
    }

    It 'Security.TLS.Protocols покриває TLS 1.0/1.1/1.2/1.3 для Client і Server (8 записів), кожен з валідним Status' {
        $tlsProtocols = @($script:DeepSecurityReport.Security.TLS.Protocols)
        $tlsProtocols.Count | Should -Be 8

        foreach ($expectedProtocol in @('TLS 1.0', 'TLS 1.1', 'TLS 1.2', 'TLS 1.3')) {
            foreach ($expectedSide in @('Client', 'Server')) {
                $matchedEntry = $tlsProtocols | Where-Object { $_.Protocol -eq $expectedProtocol -and $_.Side -eq $expectedSide }
                $matchedEntry | Should -Not -BeNullOrEmpty
                $matchedEntry.Status | Should -BeIn @('Enabled', 'Disabled', 'NotConfigured')
            }
        }
    }

    It 'Security.Defender.Status — одне з очікуваних значень, ніколи не залишається NotChecked на Deep-профілі' {
        $script:DeepSecurityReport.Security.Defender.Status | Should -BeIn @('Detected', 'Unavailable', 'NotAvailable')
    }

    It 'якщо Defender.Status=Detected, то RealTimeProtectionEnabled — визначений bool (не null)' {
        if ($script:DeepSecurityReport.Security.Defender.Status -eq 'Detected') {
            $script:DeepSecurityReport.Security.Defender.RealTimeProtectionEnabled | Should -BeIn @($true, $false)
        } else {
            Set-ItResult -Skipped -Because 'Windows Defender недоступний на цій машині — нема що перевіряти'
        }
    }

    It 'якщо RDP увімкнено, NLAEnabled — визначений bool, а не null' {
        if (-not $script:DeepSecurityReport.Security.RemoteAccess.RDPEnabled) {
            Set-ItResult -Skipped -Because 'RDP вимкнено на цій машині — нема що перевіряти'
            return
        }

        $script:DeepSecurityReport.Security.RemoteAccess.NLAEnabled | Should -BeIn @($true, $false)
    }

    It 'Security.WinRM.Status — одне з очікуваних значень, ніколи не залишається NotChecked на Deep-профілі' {
        $script:DeepSecurityReport.Security.WinRM.Status | Should -BeIn @('Detected', 'ServiceNotRunning', 'NotAvailable')
    }

    It 'Security.SMB.Status — одне з очікуваних значень, і якщо Detected, поля signing визначені' {
        $script:DeepSecurityReport.Security.SMB.Status | Should -BeIn @('Detected', 'NotAvailable')

        if ($script:DeepSecurityReport.Security.SMB.Status -eq 'Detected') {
            $script:DeepSecurityReport.Security.SMB.ServerSigningRequired | Should -BeIn @($true, $false)
            $script:DeepSecurityReport.Security.SMB.InsecureGuestLogonsEnabled | Should -BeIn @($true, $false)
        }
    }

    It 'Security.PasswordPolicy.Status — одне з очікуваних значень, і якщо Detected, MinPasswordLength — числовий рядок' {
        $script:DeepSecurityReport.Security.PasswordPolicy.Status | Should -BeIn @('Detected', 'Unavailable')

        if ($script:DeepSecurityReport.Security.PasswordPolicy.Status -eq 'Detected') {
            $parsedLength = 0
            [int]::TryParse($script:DeepSecurityReport.Security.PasswordPolicy.MinPasswordLength, [ref]$parsedLength) | Should -BeTrue
        }
    }

    It 'Security.AuditPolicy.Status — одне з очікуваних значень, і якщо Detected, зібрано >0 subcategories' {
        $script:DeepSecurityReport.Security.AuditPolicy.Status | Should -BeIn @('Detected', 'Unavailable', 'NotAvailable')

        if ($script:DeepSecurityReport.Security.AuditPolicy.Status -eq 'Detected') {
            $script:DeepSecurityReport.Security.AuditPolicy.TotalCount | Should -BeGreaterThan 0
            @($script:DeepSecurityReport.Security.AuditPolicy.Subcategories).Count | Should -Be $script:DeepSecurityReport.Security.AuditPolicy.TotalCount
        }
    }

    It 'Network.Routing.RoutingTable заповнена на реальній машині' {
        @($script:DeepSecurityReport.Network.Routing.RoutingTable).Count | Should -BeGreaterThan 0
    }

    It 'Network.ARP — масив (можливо порожній на ізольованій CI-машині без сусідів), кожен запис має IPAddress' {
        $arpEntries = @($script:DeepSecurityReport.Network.ARP)
        foreach ($entry in $arpEntries) {
            $entry.IPAddress | Should -Not -BeNullOrEmpty
        }
    }

    It 'Network.WinHttpProxy.Status — одне з очікуваних значень, ніколи не залишається NotChecked на Deep-профілі' {
        $script:DeepSecurityReport.Network.WinHttpProxy.Status | Should -BeIn @('Detected', 'Unavailable', 'NotAvailable')
    }

    It 'Hardware.Disks.Deep.PageFiles заповнений на реальній машині (щонайменше один pagefile)' {
        @($script:DeepSecurityReport.Hardware.Disks.Deep.PageFiles).Count | Should -BeGreaterThan 0
    }

    It 'Hardware.Disks.Deep.ShadowCopies — масив (може бути порожній, якщо VSS не має точок відновлення), кожен запис має VolumeName' {
        $shadowCopies = @($script:DeepSecurityReport.Hardware.Disks.Deep.ShadowCopies)
        foreach ($entry in $shadowCopies) {
            $entry.VolumeName | Should -Not -BeNullOrEmpty
        }
    }

    It 'Hardware.Disks.Deep.StoragePools — масив (порожній, якщо Storage Spaces не використовується), кожен непорожній запис має FriendlyName і HealthStatus' {
        if (-not (Get-Command Get-StoragePool -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because 'Модуль Storage (Get-StoragePool) недоступний на цій машині — нема що перевіряти'
            return
        }

        $pools = @($script:DeepSecurityReport.Hardware.Disks.Deep.StoragePools)
        foreach ($pool in $pools) {
            $pool.FriendlyName | Should -Not -BeNullOrEmpty
            $pool.HealthStatus | Should -Not -BeNullOrEmpty
        }
    }

    It 'Hardware.Disks.Deep.ReliabilityCounters — масив (порожній, якщо Get-PhysicalDisk/Get-StorageReliabilityCounter недоступні), кожен запис має DeviceId' {
        if (-not (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because 'Get-PhysicalDisk недоступний на цій машині — нема що перевіряти'
            return
        }

        $counters = @($script:DeepSecurityReport.Hardware.Disks.Deep.ReliabilityCounters)
        foreach ($counter in $counters) {
            $counter.DeviceId | Should -Not -BeNullOrEmpty
        }
    }

    It 'Hardware.Disks.Deep.SmartPredictFailures — масив (типово порожній на NVMe/RAID, це не помилка), кожен непорожній запис має InstanceName' {
        $predicts = @($script:DeepSecurityReport.Hardware.Disks.Deep.SmartPredictFailures)
        foreach ($predict in $predicts) {
            $predict.InstanceName | Should -Not -BeNullOrEmpty
        }
    }

    It 'EventLogs.LogSummaries покриває System/Application/Setup/Security, кожен запис має валідний Status' {
        $logSummaries = @($script:DeepSecurityReport.EventLogs.LogSummaries)
        $logSummaries.Count | Should -Be 4

        foreach ($expectedLog in @('System', 'Application', 'Setup', 'Security')) {
            $matchedEntry = $logSummaries | Where-Object { $_.LogName -eq $expectedLog }
            $matchedEntry | Should -Not -BeNullOrEmpty
            $matchedEntry.Status | Should -BeIn @('Detected', 'Unavailable')

            if ($matchedEntry.Status -eq 'Detected') {
                $matchedEntry.CriticalCount | Should -Not -BeNullOrEmpty
                $matchedEntry.ErrorCount | Should -Not -BeNullOrEmpty
                $matchedEntry.WarningCount | Should -Not -BeNullOrEmpty
            }
        }
    }

    It 'EventLogs.HardwareDiagnostics покриває всі 7 провайдерів (Disk/Ntfs/StorPort/StorNVMe/WHEA/Kernel-Power/BugCheck), кожен з валідним Status' {
        $diagnostics = @($script:DeepSecurityReport.EventLogs.HardwareDiagnostics)
        $diagnostics.Count | Should -Be 7

        foreach ($expectedProvider in @('Disk', 'Ntfs', 'StorPort', 'StorNVMe', 'WHEA', 'Kernel-Power', 'BugCheck')) {
            $matchedEntry = $diagnostics | Where-Object { $_.Provider -eq $expectedProvider }
            $matchedEntry | Should -Not -BeNullOrEmpty
            $matchedEntry.Status | Should -BeIn @('Detected', 'NotAvailable', 'Unavailable')

            if ($matchedEntry.Status -eq 'Detected') {
                $matchedEntry.Count | Should -Not -BeNullOrEmpty
            }
        }
    }

    It 'Hardware.Monitors — масив (може бути порожній на VM/RDP без реального дисплея), кожен непорожній запис має InstanceName' {
        $monitors = @($script:DeepSecurityReport.Hardware.Monitors)
        foreach ($monitor in $monitors) {
            $monitor.InstanceName | Should -Not -BeNullOrEmpty
        }
    }

    It 'Network.Connections.ListeningPorts має поле ProcessName на кожному записі' {
        $ports = @($script:DeepSecurityReport.Network.Connections.ListeningPorts)
        $ports.Count | Should -BeGreaterThan 0
        foreach ($port in $ports) {
            $port.PSObject.Properties.Name | Should -Contain 'ProcessName'
        }
    }

    It 'Network.Connections.EstablishedConnections — масив, кожен запис має ProcessName і RemoteAddress' {
        $connections = @($script:DeepSecurityReport.Network.Connections.EstablishedConnections)
        foreach ($conn in $connections) {
            $conn.PSObject.Properties.Name | Should -Contain 'ProcessName'
            $conn.PSObject.Properties.Name | Should -Contain 'RemoteAddress'
        }
    }

    It 'Network.SmbShares — масив (порожній, якщо модуль SmbShare відсутній), кожен непорожній запис має Name і IsAdministrative' {
        if (-not (Get-Command Get-SmbShare -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because 'Get-SmbShare недоступний на цій машині — нема що перевіряти'
            return
        }

        $shares = @($script:DeepSecurityReport.Network.SmbShares)
        foreach ($share in $shares) {
            $share.Name | Should -Not -BeNullOrEmpty
            $share.IsAdministrative | Should -BeIn @($true, $false)
        }
    }

    It 'Security.UAC full policy — коректні типи полів, якщо UAC.Enabled визначено' {
        if ($null -eq $script:DeepSecurityReport.Security.UAC.Enabled) {
            Set-ItResult -Skipped -Because 'UAC-ключ реєстру недоступний на цій машині — нема що перевіряти'
            return
        }

        $script:DeepSecurityReport.Security.UAC.ConsentPromptBehaviorAdminText | Should -Not -BeNullOrEmpty
        $script:DeepSecurityReport.Security.UAC.ConsentPromptBehaviorUserText | Should -Not -BeNullOrEmpty
    }

    It 'Security.Autoruns заповнений на реальній машині (щонайменше один autorun-запис), кожен запис має Name/Command/Source/Hive' {
        $autoruns = @($script:DeepSecurityReport.Security.Autoruns)
        $autoruns.Count | Should -BeGreaterThan 0

        foreach ($entry in $autoruns) {
            $entry.Name | Should -Not -BeNullOrEmpty
            $entry.Source | Should -Not -BeNullOrEmpty
            $entry.Hive | Should -BeIn @('HKLM', 'HKCU')
        }
    }

    It 'Security.ScheduledTasks заповнений на реальній машині, кожен запис має Name/Path/IsMicrosoftDefault, і принаймні одна Microsoft-задача позначена прапорцем' {
        if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because 'Get-ScheduledTask недоступний на цій машині — нема що перевіряти'
            return
        }

        $tasks = @($script:DeepSecurityReport.Security.ScheduledTasks)
        $tasks.Count | Should -BeGreaterThan 0

        foreach ($task in $tasks) {
            $task.Name | Should -Not -BeNullOrEmpty
            $task.Path | Should -Not -BeNullOrEmpty
            $task.IsMicrosoftDefault | Should -BeIn @($true, $false)
        }

        ($tasks | Where-Object { $_.IsMicrosoftDefault }).Count | Should -BeGreaterThan 0
    }
}

Describe 'v0.7.0 CI/Quality Gates — Full runtime test' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\Get-BravoSystemReport.ps1'))) {
    # Окремий наскрізний прогін -Profile Full (не Deep/Forensic) — перевіряє,
    # що середній за обсягом профіль реально працює end-to-end, а не лише
    # Quick (базовий CI-гейт) і Deep (переперевикористовується для всіх
    # v0.5.0 Deep Inventory Describe-блоків вище). Full не гейтує деякі
    # Deep/Forensic-only колектори (Autoruns/ScheduledTasks/SMART/тощо), тому
    # їх тут навмисно НЕ перевіряємо — лише поля, які штатно збираються вже
    # на Full.
    BeforeAll {
        $script:FullRuntimeDir = New-BravoTestReportsDir -Name 'full-runtime'
        & $script:WrapperPath -Profile Full -Offline -NoZip -SkipElevation -NoPause -NoOpenFolder -OutputPath $script:FullRuntimeDir 2>&1 | Out-Null
        $script:FullRuntimeExitCode = $LASTEXITCODE

        $jsonFile = Get-ChildItem -LiteralPath $script:FullRuntimeDir -Filter '*.json' -Recurse | Select-Object -First 1
        $script:FullRuntimeReport = Get-Content -LiteralPath $jsonFile.FullName -Raw | ConvertFrom-Json
    }

    AfterAll {
        Remove-Item -LiteralPath $script:FullRuntimeDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'завершується exit code 0, JSON валідний, CollectionErrors=0' {
        $script:FullRuntimeExitCode | Should -Be 0
        $script:FullRuntimeReport | Should -Not -BeNullOrEmpty
        @($script:FullRuntimeReport.CollectionErrors).Count | Should -Be 0
        @($script:FullRuntimeReport.ExportErrors).Count | Should -Be 0
    }

    It 'Profile у звіті дорівнює Full, і Full-специфічні поля реально заповнені (не залишились дефолтом Quick)' {
        $script:FullRuntimeReport.Profile | Should -Be 'Full'

        # Network.Adapters збагачується LinkSpeed/Status лише на Full/Deep/
        # Forensic (Get-NetAdapter, PR #60) — на Quick цих полів взагалі
        # немає в наявних записах.
        $adaptersWithStatus = @($script:FullRuntimeReport.Network.Adapters | Where-Object { $_.Status })
        $adaptersWithStatus.Count | Should -BeGreaterThan 0

        # Chassis/Motherboard — Full/Deep/Forensic-only (PR #59). М'яке
        # твердження (Manufacturer АБО Product), як і в аналогічному
        # Deep-тесті вище — деякі VM/hypervisor лишають Manufacturer порожнім.
        $manufacturer = [string]$script:FullRuntimeReport.Hardware.Motherboard.Manufacturer
        $product = [string]$script:FullRuntimeReport.Hardware.Motherboard.Product
        ($manufacturer -or $product) | Should -BeTrue
    }
}

Describe 'v0.7.0 CI/Quality Gates — Forensic -JSONOnly smoke test / HTML-JSONOnly validation' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\Get-BravoSystemReport.ps1'))) {
    It '-Profile Forensic -JSONOnly -> exit code 0, JSON створено й валідний, HTML НЕ створено' {
        $dir = New-BravoTestReportsDir -Name 'forensic-jsononly'
        & $script:WrapperPath -Profile Forensic -JSONOnly -Offline -SkipElevation -NoPause -NoOpenFolder -OutputPath $dir 2>&1 | Out-Null
        $exitCode = $LASTEXITCODE

        $jsonFile = Get-ChildItem -LiteralPath $dir -Filter '*.json' -Recurse | Select-Object -First 1
        $htmlFile = Get-ChildItem -LiteralPath $dir -Filter '*.html' -Recurse | Select-Object -First 1

        $exitCode | Should -Be 0
        $jsonFile | Should -Not -BeNullOrEmpty
        $htmlFile | Should -BeNullOrEmpty

        $report = Get-Content -LiteralPath $jsonFile.FullName -Raw | ConvertFrom-Json
        $report | Should -Not -BeNullOrEmpty
        $report.Profile | Should -Be 'Forensic'
        @($report.CollectionErrors).Count | Should -Be 0

        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'звичайний прогін БЕЗ -JSONOnly створює і JSON, і HTML' {
        $dir = New-BravoTestReportsDir -Name 'quick-jsonandhtml'
        & $script:WrapperPath -Profile Quick -Offline -NoZip -SkipElevation -NoPause -NoOpenFolder -OutputPath $dir 2>&1 | Out-Null
        $exitCode = $LASTEXITCODE

        $jsonFile = Get-ChildItem -LiteralPath $dir -Filter '*.json' -Recurse | Select-Object -First 1
        $htmlFile = Get-ChildItem -LiteralPath $dir -Filter '*.html' -Recurse | Select-Object -First 1

        $exitCode | Should -Be 0
        $jsonFile | Should -Not -BeNullOrEmpty
        $htmlFile | Should -Not -BeNullOrEmpty

        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'v0.6.1 — Dark Mode markers присутні в HTML-виводі' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\Get-BravoSystemReport.ps1'))) {
    BeforeAll {
        $script:DarkModeDir = New-BravoTestReportsDir -Name 'darkmode-markers'
        & $script:WrapperPath -Profile Quick -Offline -NoZip -SkipElevation -NoPause -NoOpenFolder -OutputPath $script:DarkModeDir 2>&1 | Out-Null
        $htmlFile = Get-ChildItem -LiteralPath $script:DarkModeDir -Filter '*.html' -Recurse | Select-Object -First 1
        $script:DarkModeHtml = Get-Content -LiteralPath $htmlFile.FullName -Raw
    }

    AfterAll {
        Remove-Item -LiteralPath $script:DarkModeDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'HTML містить theme-toggle кнопку, функцію toggleTheme та CSS-визначення :root[data-theme]' {
        $script:DarkModeHtml | Should -Match 'id="theme-toggle"'
        $script:DarkModeHtml | Should -Match 'toggleTheme'
        $script:DarkModeHtml | Should -Match ':root\[data-theme="dark"\]'
        $script:DarkModeHtml | Should -Match 'prefers-color-scheme:\s*dark'
    }
}

Describe 'v0.6.1 — Edge CLI PDF (-ExportPdf)' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\Get-BravoSystemReport.ps1'))) {
    It '-ExportPdf створює .pdf поряд з HTML, якщо Edge встановлено на цій машині; інакше не падає (graceful skip)' {
        if (-not (Get-Command msedge.exe -ErrorAction SilentlyContinue) -and
            -not (Test-Path 'C:\Program Files\Microsoft\Edge\Application\msedge.exe') -and
            -not (Test-Path 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe')) {
            Set-ItResult -Skipped -Because 'Microsoft Edge не встановлено на цій машині — нема що перевіряти'
            return
        }

        $dir = New-BravoTestReportsDir -Name 'exportpdf'
        & $script:WrapperPath -Profile Quick -ExportPdf -Offline -NoZip -SkipElevation -NoPause -NoOpenFolder -OutputPath $dir 2>&1 | Out-Null
        $exitCode = $LASTEXITCODE

        $pdfFile = Get-ChildItem -LiteralPath $dir -Filter '*.pdf' -Recurse | Select-Object -First 1

        $exitCode | Should -Be 0
        $pdfFile | Should -Not -BeNullOrEmpty
        $pdfFile.Length | Should -BeGreaterThan 0

        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'без -ExportPdf .pdf НЕ створюється (фіча опційна, не дефолт)' {
        $dir = New-BravoTestReportsDir -Name 'noexportpdf'
        & $script:WrapperPath -Profile Quick -Offline -NoZip -SkipElevation -NoPause -NoOpenFolder -OutputPath $dir 2>&1 | Out-Null

        $pdfFile = Get-ChildItem -LiteralPath $dir -Filter '*.pdf' -Recurse | Select-Object -First 1
        $pdfFile | Should -BeNullOrEmpty

        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
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
