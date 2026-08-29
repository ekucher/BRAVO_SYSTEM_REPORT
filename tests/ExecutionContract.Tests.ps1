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
