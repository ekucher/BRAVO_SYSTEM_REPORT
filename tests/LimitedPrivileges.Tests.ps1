# MODULE: tests/LimitedPrivileges.Tests.ps1
# Регресійні тести режиму обмежених привілеїв (робоча станція без прав
# адміністратора): маршрутизація Add-AuditError -> SkippedChecks/CollectionErrors,
# дедуплікація, Register-BravoElevationSkippedStatus, незмінність Health Score
# і видимість пропусків у TXT/Markdown.
#
# 90-Main.ps1 не можна dot-source'ити цілком (top-level elevation-логіка) —
# функції витягуються з АКТУАЛЬНОГО файлу через AST, як у
# tests/MainExportSyncAndArgEscaping.Tests.ps1.

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\10-Core.ps1')
    . (Join-Path $PSScriptRoot '..\src\40-Health.ps1')
    . (Join-Path $PSScriptRoot '..\src\49-Export-Result.ps1')
    . (Join-Path $PSScriptRoot '..\src\55-Export-Txt.ps1')
    . (Join-Path $PSScriptRoot '..\src\56-Export-Md.ps1')

    $mainContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\src\90-Main.ps1') -Raw
    $tokens = $null
    $parseErrors = $null
    $mainAst = [System.Management.Automation.Language.Parser]::ParseInput($mainContent, [ref]$tokens, [ref]$parseErrors)
    foreach ($name in @('Add-AuditError', 'Add-AuditSkipped', 'Register-BravoElevationSkippedStatus')) {
        $funcAst = $mainAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true) | Select-Object -First 1
        if (-not $funcAst) { throw "Функцію '$name' не знайдено в src/90-Main.ps1 через AST." }
        . ([scriptblock]::Create($funcAst.Extent.Text))
    }

    function Add-ExportError { param($Section, $Message) }
    $IconDone = '[OK]'; $IconCsv = '[C]'

    function New-BravoLimitedFakeReport {
        param([bool]$Elevated)
        [ordered]@{
            ComputerName = 'TEST-PC'; Profile = 'Deep'; Timestamp = '2026-10-23 12:00:00'
            ScriptVersion = '0.6.1'; SchemaVersion = '0.6.21'; Elevated = $Elevated
            Status = 'OK'; StatusReason = ''
            Health = [ordered]@{ Score = 0; Status = 'OK'; Findings = @() }
            OS = [ordered]@{ Caption = 'Test OS'; Version = '10.0'; Build = '20348'; UptimeDays = 1; UptimeHours = 1 }
            Hardware = [ordered]@{
                CPU = [ordered]@{ Name = 'Test CPU'; LoadPercent = 1 }
                RAM = [ordered]@{ TotalGB = 1; UsedGB = 1; UsedPercent = 1 }
                Disks = [ordered]@{ FreePercent = 50; TotalGB = 1; FreeGB = 1 }
            }
            Security = [ordered]@{
                SecureBoot = [ordered]@{ Status = 'Unavailable'; Error = 'Unable to set proper privileges. Access was denied.' }
                TPM = [ordered]@{ Status = 'Unavailable'; Error = 'Отказано в доступе ' }
                AuditPolicy = [ordered]@{ Status = 'Unavailable' }
                Defender = [ordered]@{ Status = 'Detected'; Error = '' }
                PasswordPolicy = [ordered]@{ Status = 'Unavailable'; Error = 'The RPC server is unavailable.' }
            }
            CollectionErrors = @()
            ExportErrors = @()
            SkippedChecks = @()
        }
    }
}

Describe 'Add-AuditError: маршрутизація за Elevated' {
    It 'без прав адміністратора: admin-only розділ і відмова в доступі -> SkippedChecks, CollectionErrors порожній' {
        $script:Report = New-BravoLimitedFakeReport -Elevated $false
        Add-AuditError -Section 'StorageDeep.ShadowCopies' -Message 'Сбой инициализации '
        Add-AuditError -Section 'Security.Autoruns' -Message "Access to the registry key 'HKEY_LOCAL_MACHINE\SOFTWARE\X' is denied."

        @($script:Report.CollectionErrors).Count | Should -Be 0
        @($script:Report.SkippedChecks | ForEach-Object { $_.Section }) | Should -Be @('StorageDeep.ShadowCopies', 'Security.Autoruns')
        @($script:Report.SkippedChecks | ForEach-Object { $_.Reason } | Select-Object -Unique) | Should -Be @('RequiresElevation')
    }

    It 'без прав адміністратора: збій, не пов''язаний з правами, лишається помилкою збору' {
        $script:Report = New-BravoLimitedFakeReport -Elevated $false
        Add-AuditError -Section 'StorageDeep.ShadowCopies' -Message 'The RPC server is unavailable.'

        @($script:Report.CollectionErrors).Count | Should -Be 1
        @($script:Report.SkippedChecks).Count | Should -Be 0
    }

    It 'з правами адміністратора: та сама відмова -> CollectionErrors (поведінка без змін)' {
        $script:Report = New-BravoLimitedFakeReport -Elevated $true
        Add-AuditError -Section 'StorageDeep.ShadowCopies' -Message 'Сбой инициализации '
        Add-AuditError -Section 'Security.Autoruns' -Message 'Access is denied.'

        @($script:Report.CollectionErrors).Count | Should -Be 2
        @($script:Report.SkippedChecks).Count | Should -Be 0
    }

    It 'Add-AuditSkipped: один запис на розділ' {
        $script:Report = New-BravoLimitedFakeReport -Elevated $false
        Add-AuditSkipped -Section 'Security.WinRM' -Message 'a'
        Add-AuditSkipped -Section 'Security.WinRM' -Message 'b'

        @($script:Report.SkippedChecks).Count | Should -Be 1
        $script:Report.SkippedChecks[0].Message | Should -Be 'a'
    }
}

Describe 'Register-BravoElevationSkippedStatus' {
    It 'без прав адміністратора реєструє Unavailable через брак прав і не чіпає інші статуси' {
        $script:Report = New-BravoLimitedFakeReport -Elevated $false
        Register-BravoElevationSkippedStatus

        $sections = @($script:Report.SkippedChecks | ForEach-Object { $_.Section })
        $sections | Should -Contain 'Security.SecureBoot'
        $sections | Should -Contain 'Security.TPM'
        $sections | Should -Contain 'Security.AuditPolicy'
        # Unavailable не через права (RPC) і Detected - не пропуски.
        $sections | Should -Not -Contain 'Security.PasswordPolicy'
        $sections | Should -Not -Contain 'Security.Defender'
        $script:Report.Security.TPM.Status | Should -Be 'Unavailable'
    }

    It 'розділ, що вже має помилку збору, не дублюється як пропуск' {
        $script:Report = New-BravoLimitedFakeReport -Elevated $false
        $script:Report.CollectionErrors += [PSCustomObject]@{ Time = 't'; Section = 'Security.AuditPolicy'; Message = 'auditpol crashed' }
        Register-BravoElevationSkippedStatus

        @($script:Report.SkippedChecks | ForEach-Object { $_.Section }) | Should -Not -Contain 'Security.AuditPolicy'
    }

    It 'з правами адміністратора нічого не реєструє' {
        $script:Report = New-BravoLimitedFakeReport -Elevated $true
        Register-BravoElevationSkippedStatus

        @($script:Report.SkippedChecks).Count | Should -Be 0
    }
}

Describe 'SkippedChecks не впливають на Health Score і видні у звітах' {
    BeforeAll {
        $script:Report = New-BravoLimitedFakeReport -Elevated $false
        Add-AuditError -Section 'Security.WinRM' -Message "Cannot find path 'localhost\Listener' because it does not exist."
        Register-BravoElevationSkippedStatus
        Update-BravoHealthScore 6>$null
    }

    It 'Health Score 100 і StatusReason без помилок збору, хоча пропусків кілька' {
        @($script:Report.SkippedChecks).Count | Should -BeGreaterThan 1
        $script:Report.Health.Score | Should -Be 100
        $script:Report.Status | Should -Be 'OK'
        $script:Report.StatusReason | Should -Match 'collectionErrors=0'
    }

    It 'TXT і Markdown містять секцію пропусків з розділами' {
        $outDir = Join-Path $TestDrive 'limited'
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        (Export-BravoTxtReport -OutputDir $outDir -BaseFileName 'r' -TXT $true 6>$null).Success | Should -BeTrue
        (Export-BravoMdReport -OutputDir $outDir -BaseFileName 'r' -MD $true 6>$null).Success | Should -BeTrue

        $txt = Get-Content -LiteralPath (Join-Path $outDir 'r.txt') -Raw -Encoding UTF8
        $md = Get-Content -LiteralPath (Join-Path $outDir 'r.md') -Raw -Encoding UTF8
        foreach ($content in @($txt, $md)) {
            $content | Should -Match 'Пропущено без прав адміністратора'
            $content | Should -Match 'Security\.WinRM'
            $content | Should -Match 'RequiresElevation'
        }
    }
}
