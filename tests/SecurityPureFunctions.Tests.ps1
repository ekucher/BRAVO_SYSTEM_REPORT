# MODULE: tests/SecureBootStatus.Tests.ps1
# Pester-тести для Get-BravoSecureBootStatus (src/34-Collectors-Security.ps1,
# Release Blocker Fixes v0.6.1) — розрізнення access-denied (непідвищена
# сесія) від справжнього NotSupported (Legacy BIOS/VM без UEFI).

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\34-Collectors-Security.ps1')
}

Describe 'Get-BravoSecureBootStatus' {
    It 'Secure Boot увімкнено — Supported=true, Enabled=true, Status=Enabled' {
        Mock Confirm-SecureBootUEFI { $true }
        $result = Get-BravoSecureBootStatus
        $result.Supported | Should -Be $true
        $result.Enabled | Should -Be $true
        $result.Status | Should -Be 'Enabled'
    }

    It 'Secure Boot підтримується, але вимкнено — Supported=true, Enabled=false, Status=Disabled' {
        Mock Confirm-SecureBootUEFI { $false }
        $result = Get-BravoSecureBootStatus
        $result.Supported | Should -Be $true
        $result.Enabled | Should -Be $false
        $result.Status | Should -Be 'Disabled'
    }

    It 'UnauthorizedAccessException (непідвищена сесія) — Status=Unavailable, Supported=$null (НЕ NotSupported)' {
        Mock Confirm-SecureBootUEFI { throw [System.UnauthorizedAccessException]::new('Access is denied.') }
        $result = Get-BravoSecureBootStatus
        $result.Status | Should -Be 'Unavailable'
        $result.Supported | Should -Be $null
        $result.Error | Should -Not -BeNullOrEmpty
    }

    It 'інший виняток (Legacy BIOS/VM, напр. PlatformNotSupportedException) — Status=NotSupported, Supported=false' {
        Mock Confirm-SecureBootUEFI { throw [System.PlatformNotSupportedException]::new('This platform does not support UEFI Secure Boot.') }
        $result = Get-BravoSecureBootStatus
        $result.Status | Should -Be 'NotSupported'
        $result.Supported | Should -Be $false
        $result.Error | Should -Not -BeNullOrEmpty
    }
}

Describe 'Test-BravoDefenderRealTimeProtectionWarning' {
    It 'RealTimeProtectionEnabled=$false, AMRunningMode=Normal — WARNING потрібен' {
        Test-BravoDefenderRealTimeProtectionWarning -RealTimeProtectionEnabled $false -AMRunningMode 'Normal' | Should -Be $true
    }

    It 'RealTimeProtectionEnabled=$false, AMRunningMode=Passive (сторонній AV) — WARNING НЕ потрібен (Release Blocker Fixes v0.6.1)' {
        Test-BravoDefenderRealTimeProtectionWarning -RealTimeProtectionEnabled $false -AMRunningMode 'Passive' | Should -Be $false
    }

    It 'RealTimeProtectionEnabled=$false, AMRunningMode=SxS Passive — WARNING НЕ потрібен' {
        Test-BravoDefenderRealTimeProtectionWarning -RealTimeProtectionEnabled $false -AMRunningMode 'SxS Passive' | Should -Be $false
    }

    It 'RealTimeProtectionEnabled=$true — WARNING не потрібен незалежно від AMRunningMode' {
        Test-BravoDefenderRealTimeProtectionWarning -RealTimeProtectionEnabled $true -AMRunningMode 'Normal' | Should -Be $false
    }

    It 'RealTimeProtectionEnabled=$null (не зібрано), AMRunningMode порожній — WARNING потрібен (той самий default, що й раніше)' {
        Test-BravoDefenderRealTimeProtectionWarning -RealTimeProtectionEnabled $null -AMRunningMode '' | Should -Be $true
    }
}

Describe 'Test-BravoTpmAccessDeniedError (delta review 2026-09-25)' {
    It '$null ErrorRecord — не access-denied' {
        Test-BravoTpmAccessDeniedError -ErrorRecord $null | Should -Be $false
    }

    It 'UnauthorizedAccessException — access-denied' {
        $err = $null
        try { throw [System.UnauthorizedAccessException]::new('Access is denied.') } catch { $err = $_ }
        Test-BravoTpmAccessDeniedError -ErrorRecord $err | Should -Be $true
    }

    It 'CategoryInfo.Category=PermissionDenied (типовий CimException-wrapping) — access-denied' {
        $err = $null
        try { throw [System.Management.Automation.RuntimeException]::new('CIM error: Access denied') } catch { $err = $_ }
        $errorRecord = New-Object Management.Automation.ErrorRecord($err.Exception, 'CimAccessDenied', [Management.Automation.ErrorCategory]::PermissionDenied, $null)
        Test-BravoTpmAccessDeniedError -ErrorRecord $errorRecord | Should -Be $true
    }

    It 'повідомлення містить "Access is denied" без спеціального типу винятку — access-denied' {
        $err = $null
        try { throw [System.Exception]::new('Access is denied while querying namespace.') } catch { $err = $_ }
        Test-BravoTpmAccessDeniedError -ErrorRecord $err | Should -Be $true
    }

    It 'звичайний "namespace not found" (реальна відсутність TPM/класу) — НЕ access-denied' {
        $err = $null
        try { throw [System.Exception]::new('Invalid namespace') } catch { $err = $_ }
        Test-BravoTpmAccessDeniedError -ErrorRecord $err | Should -Be $false
    }
}

Describe 'ConvertFrom-BravoAuditPolicyCsv (delta review 2026-09-25, локалізовані заголовки auditpol /r)' {
    It 'англ. заголовки — парсить позиційно, ігноруючи текст заголовка' {
        $lines = @(
            'Machine Name,Policy Target,Subcategory,Subcategory GUID,Inclusion Setting,Exclusion Setting',
            'HOST1,System,Security System Extension,{0CCE9211-69AE-11D9-BED3-505054503030},Success and Failure,'
        )
        $result = @(ConvertFrom-BravoAuditPolicyCsv -Lines $lines)
        $result.Count | Should -Be 1
        $result[0].PolicyTarget | Should -Be 'System'
        $result[0].Subcategory | Should -Be 'Security System Extension'
        $result[0].SubcategoryGuid | Should -Be '{0CCE9211-69AE-11D9-BED3-505054503030}'
        $result[0].InclusionSetting | Should -Be 'Success and Failure'
    }

    It 'локалізований (напр. UA) заголовок — все одно коректно парсить дані позиційно (репродукує баг PR#85 до фіксу)' {
        $lines = @(
            'Ім''я комп''ютера,Ціль політики,Підкатегорія,GUID підкатегорії,Параметр включення,Параметр виключення',
            'HOST1,Система,Розширення системи безпеки,{0CCE9211-69AE-11D9-BED3-505054503030},Успіх і відмова,'
        )
        $result = @(ConvertFrom-BravoAuditPolicyCsv -Lines $lines)
        $result.Count | Should -Be 1
        $result[0].PolicyTarget | Should -Be 'Система'
        $result[0].Subcategory | Should -Be 'Розширення системи безпеки'
        $result[0].SubcategoryGuid | Should -Be '{0CCE9211-69AE-11D9-BED3-505054503030}'
        $result[0].InclusionSetting | Should -Be 'Успіх і відмова'
    }

    It 'порожній/недостатній вивід — повертає порожню колекцію без винятку' {
        @(ConvertFrom-BravoAuditPolicyCsv -Lines @()) | Should -BeNullOrEmpty
        @(ConvertFrom-BravoAuditPolicyCsv -Lines @('лише заголовок')) | Should -BeNullOrEmpty
    }

    It 'декілька рядків даних — усі присутні у виводі' {
        $lines = @(
            'Machine Name,Policy Target,Subcategory,Subcategory GUID,Inclusion Setting,Exclusion Setting',
            'HOST1,System,Sub A,{guid-a},Success,',
            'HOST1,Logon/Logoff,Sub B,{guid-b},No Auditing,'
        )
        $result = @(ConvertFrom-BravoAuditPolicyCsv -Lines $lines)
        $result.Count | Should -Be 2
        $result[1].PolicyTarget | Should -Be 'Logon/Logoff'
        $result[1].InclusionSetting | Should -Be 'No Auditing'
    }
}

Describe 'Get-ScheduledTask профіль-гейт (delta review 2026-09-25, PR#85: Full не мав власного гейту)' {
    BeforeAll {
        $script:SecuritySource = Get-Content (Join-Path $PSScriptRoot '..\src\34-Collectors-Security.ps1') -Raw
    }

    It 'виклик Get-ScheduledTask -ErrorAction Stop захищений умовою Profile -in Deep/Forensic в тому самому if' {
        $script:SecuritySource | Should -Match "\`$Profile -in @\('Deep','Forensic'\) -and \(Get-Command Get-ScheduledTask"
    }
}
