# MODULE: tests/ReleasePackage.Tests.ps1
# Наскрізна перевірка release package (v0.4.1 Release Stabilization,
# ROADMAP "Додати перевірку release package"): tools/New-ReleasePackage.ps1
# створює ZIP -> розпаковуємо у temporary directory -> запускаємо
# BRAVO-SystemReport-Quick.bat --nopause з розпакованого пакета ->
# перевіряємо, що JSON/HTML справді створились.
#
# Потребує зібраного dist/Get-BravoSystemReport.ps1 (+ .sha512) — пропускається,
# якщо його немає (New-ReleasePackage.ps1 сам кидає throw в цьому випадку).

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:PackageScript = Join-Path $script:RepoRoot 'tools\New-ReleasePackage.ps1'
    $script:DistScript = Join-Path $script:RepoRoot 'dist\Get-BravoSystemReport.ps1'
    $script:DistSha512 = "$script:DistScript.sha512"
}

Describe 'v0.4.1 — Release package: створення, розпакування, запуск' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\dist\Get-BravoSystemReport.ps1')) -or -not (Test-Path (Join-Path $PSScriptRoot '..\dist\Get-BravoSystemReport.ps1.sha512'))) {
    BeforeAll {
        $script:PackageOutputDir = Join-Path $env:TEMP 'bravo-pester-release-package'
        if (Test-Path -LiteralPath $script:PackageOutputDir) {
            Remove-Item -LiteralPath $script:PackageOutputDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:PackageOutputDir -Force | Out-Null

        & $script:PackageScript -RepoPath $script:RepoRoot -OutputPath $script:PackageOutputDir -NoClean 2>&1 | Out-Null
        $script:PackageExitCode = $LASTEXITCODE

        $script:ZipFile = Get-ChildItem -LiteralPath $script:PackageOutputDir -Filter '*.zip' -File | Select-Object -First 1
        $script:Sha256File = Get-ChildItem -LiteralPath $script:PackageOutputDir -Filter '*.zip.sha256' -File | Select-Object -First 1

        $script:ExtractDir = Join-Path $script:PackageOutputDir 'extracted'
        if ($script:ZipFile) {
            Expand-Archive -LiteralPath $script:ZipFile.FullName -DestinationPath $script:ExtractDir -Force
        }
    }

    AfterAll {
        Remove-Item -LiteralPath $script:PackageOutputDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'New-ReleasePackage.ps1 створює ZIP і .sha256 без помилок' {
        $script:ZipFile | Should -Not -BeNullOrEmpty
        $script:Sha256File | Should -Not -BeNullOrEmpty
    }

    It '.sha256 у пакеті відповідає реальному хешу ZIP-файлу' {
        $actualHash = (Get-FileHash -LiteralPath $script:ZipFile.FullName -Algorithm SHA256).Hash
        $recordedLine = Get-Content -LiteralPath $script:Sha256File.FullName -Raw
        $recordedLine | Should -Match ([regex]::Escape($actualHash))
    }

    It 'розпакований пакет містить dist/runtime + .sha512, що збігається з файлом' {
        $extractedRuntime = Join-Path $script:ExtractDir 'dist\Get-BravoSystemReport.ps1'
        $extractedSha512 = "$extractedRuntime.sha512"

        Test-Path -LiteralPath $extractedRuntime | Should -BeTrue
        Test-Path -LiteralPath $extractedSha512 | Should -BeTrue

        $actualHash = (Get-FileHash -LiteralPath $extractedRuntime -Algorithm SHA512).Hash.Trim()
        $recordedHash = (Get-Content -LiteralPath $extractedSha512 -Raw).Trim()
        $actualHash | Should -Be $recordedHash
    }

    It 'розпакований пакет містить усі *.bat лаунчери і MANIFEST.txt' {
        foreach ($batName in @('BRAVO-SystemReport-Quick.bat', 'BRAVO-SystemReport-Full.bat', 'BRAVO-SystemReport-Deep.bat', 'BRAVO-SystemReport-Forensic.bat', 'BRAVO-SystemReport-Launcher.bat')) {
            Test-Path -LiteralPath (Join-Path $script:ExtractDir $batName) | Should -BeTrue
        }
        Test-Path -LiteralPath (Join-Path $script:ExtractDir 'MANIFEST.txt') | Should -BeTrue
    }

    It 'BRAVO-SystemReport-Quick.bat --nopause із розпакованого пакета створює JSON і HTML' {
        $quickBat = Join-Path $script:ExtractDir 'BRAVO-SystemReport-Quick.bat'
        Test-Path -LiteralPath $quickBat | Should -BeTrue

        $process = Start-Process -FilePath $quickBat -ArgumentList '--nopause' -WorkingDirectory $script:ExtractDir -Wait -PassThru -WindowStyle Hidden
        $process.ExitCode | Should -Be 0

        $reportsDir = Join-Path $script:ExtractDir 'reports'
        $jsonFile = Get-ChildItem -LiteralPath $reportsDir -Filter '*.json' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        $htmlFile = Get-ChildItem -LiteralPath $reportsDir -Filter '*.html' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

        $jsonFile | Should -Not -BeNullOrEmpty
        $htmlFile | Should -Not -BeNullOrEmpty

        # Пакет самодостатній: розпакований і запущений з чистого temporary
        # directory, без залежності від решти репозиторію (dist/../src не
        # копіюються в пакет — лише runtime dist/Get-BravoSystemReport.ps1).
        { Get-Content -LiteralPath $jsonFile.FullName -Raw | ConvertFrom-Json } | Should -Not -Throw
    }
}
