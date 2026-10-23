# MODULE: tests/Core.Tests.ps1
# Pester-тести для чистих helper-функцій з src/10-Core.ps1.
# Файл безпечний для dot-source: містить лише function-визначення,
# без top-level виконання (на відміну від 90-Main.ps1).

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\10-Core.ps1')
}

Describe 'Test-BravoUsableIPv4Address' {
    It 'вважає звичайну публічну/приватну IPv4-адресу придатною' {
        Test-BravoUsableIPv4Address -Address '192.168.1.10' | Should -BeTrue
        Test-BravoUsableIPv4Address -Address '203.0.113.5' | Should -BeTrue
    }

    It 'відхиляє порожню або відсутню адресу' {
        Test-BravoUsableIPv4Address -Address '' | Should -BeFalse
        Test-BravoUsableIPv4Address -Address $null | Should -BeFalse
    }

    It 'відхиляє некоректний формат' {
        Test-BravoUsableIPv4Address -Address 'не-ip-адреса' | Should -BeFalse
        Test-BravoUsableIPv4Address -Address '999.999.999.999' | Should -BeFalse
    }

    It 'відхиляє IPv6-адресу' {
        Test-BravoUsableIPv4Address -Address '::1' | Should -BeFalse
    }

    It 'відхиляє 0.0.0.0' {
        Test-BravoUsableIPv4Address -Address '0.0.0.0' | Should -BeFalse
    }

    It 'відхиляє loopback (127.x.x.x)' {
        Test-BravoUsableIPv4Address -Address '127.0.0.1' | Should -BeFalse
    }

    It 'відхиляє APIPA (169.254.x.x)' {
        Test-BravoUsableIPv4Address -Address '169.254.1.1' | Should -BeFalse
    }
}

Describe 'Move-BravoIPv4ToFront' {
    It 'ставить PrimaryIPv4 першим, якщо він є у списку' {
        $result = Move-BravoIPv4ToFront -IPv4 @('10.0.0.2', '10.0.0.1', '10.0.0.3') -PrimaryIPv4 '10.0.0.3'
        $result[0] | Should -Be '10.0.0.3'
        $result.Count | Should -Be 3
    }

    It 'додає PrimaryIPv4 першим, навіть якщо його не було у списку' {
        $result = Move-BravoIPv4ToFront -IPv4 @('10.0.0.1', '10.0.0.2') -PrimaryIPv4 '10.0.0.9'
        $result[0] | Should -Be '10.0.0.9'
        $result.Count | Should -Be 3
    }

    It 'дедуплікує адреси' {
        $result = Move-BravoIPv4ToFront -IPv4 @('10.0.0.1', '10.0.0.1', '10.0.0.2') -PrimaryIPv4 ''
        ($result | Measure-Object).Count | Should -Be 2
    }

    It 'відкидає непридатні адреси (loopback/APIPA/невалідні)' {
        $result = Move-BravoIPv4ToFront -IPv4 @('10.0.0.1', '127.0.0.1', '169.254.1.1', 'not-an-ip') -PrimaryIPv4 ''
        $result | Should -Be @('10.0.0.1')
    }

    It 'повертає порожній масив без винятку, якщо вхідний список порожній' {
        $result = Move-BravoIPv4ToFront -IPv4 @() -PrimaryIPv4 ''
        $result.Count | Should -Be 0
    }

    It 'ігнорує невалідний PrimaryIPv4 і не додає його в результат' {
        $result = Move-BravoIPv4ToFront -IPv4 @('10.0.0.1') -PrimaryIPv4 'not-an-ip'
        $result | Should -Be @('10.0.0.1')
    }
}

Describe 'Test-BravoAccessDeniedMessage' {
    It 'розпізнає відмову в доступі різними мовами і за кодом E_ACCESSDENIED' {
        foreach ($message in @(
                'Access is denied.',
                'Unable to set proper privileges. Access was denied.',
                'Відмовлено в доступі',
                'Отказано в доступе ',
                'Exception from HRESULT: 0x80070005',
                'Exception from HRESULT: 0x80041003',
                "Access to the path 'C:\Windows\System32\config\SAM' is denied.",
                "Access to the registry key 'HKEY_LOCAL_MACHINE\SECURITY\Policy' is denied.",
                'Requested registry access is not allowed.',
                'Доступ заборонено.',
                'Доступ запрещен.',
                'The requested operation requires elevation.')) {
            Test-BravoAccessDeniedMessage -Message $message | Should -BeTrue -Because $message
        }
    }

    It 'не вважає відмовою в доступі інші помилки й порожнє повідомлення' {
        foreach ($message in @('Invalid class', 'The RPC server is unavailable.', 'Not found',
                "Could not find a part of the path 'C:\Temp\x'.", 'Initialization failure', '', $null)) {
            Test-BravoAccessDeniedMessage -Message $message | Should -BeFalse -Because "'$message'"
        }
    }
}

Describe 'Test-BravoElevationSkip' {
    It 'з правами адміністратора ніколи не перетворює помилку збору на пропущену перевірку' {
        Test-BravoElevationSkip -Elevated $true -Section 'Security.WinRM' -Message 'Access is denied.' | Should -BeFalse
        Test-BravoElevationSkip -Elevated $true -Section 'StorageDeep.ShadowCopies' -Message 'Initialization failure' | Should -BeFalse
    }

    It 'без прав адміністратора: admin-only розділ пропускається за його характерного повідомлення' {
        # Реальні тексти з робочої станції без прав адміністратора (Windows Server 2022, ru/en).
        Test-BravoElevationSkip -Elevated $false -Section 'Security.WinRM' -Message "Cannot find path 'localhost\Listener' because it does not exist." | Should -BeTrue
        Test-BravoElevationSkip -Elevated $false -Section 'StorageDeep.ShadowCopies' -Message 'Сбой инициализации ' | Should -BeTrue
        Test-BravoElevationSkip -Elevated $false -Section 'StorageDeep.ShadowCopies' -Message 'Initialization failure' | Should -BeTrue
        Test-BravoElevationSkip -Elevated $false -Section 'StorageDeep.BitLocker' -Message 'Invalid namespace ' | Should -BeTrue
    }

    It 'без прав адміністратора: інший збій admin-only розділу лишається помилкою збору' {
        Test-BravoElevationSkip -Elevated $false -Section 'Security.WinRM' -Message 'String was not recognized as a valid Boolean.' | Should -BeFalse
        Test-BravoElevationSkip -Elevated $false -Section 'StorageDeep.ShadowCopies' -Message 'The RPC server is unavailable.' | Should -BeFalse
        Test-BravoElevationSkip -Elevated $false -Section 'StorageDeep.BitLocker' -Message '' | Should -BeFalse
    }

    It 'без прав адміністратора: інший розділ пропускається лише при відмові в доступі' {
        Test-BravoElevationSkip -Elevated $false -Section 'Security.Firewall' -Message 'Access is denied.' | Should -BeTrue
        Test-BravoElevationSkip -Elevated $false -Section 'Security.Autoruns' -Message "Access to the registry key 'HKEY_LOCAL_MACHINE\SOFTWARE\X' is denied." | Should -BeTrue
        Test-BravoElevationSkip -Elevated $false -Section 'Security.Firewall' -Message 'The RPC server is unavailable.' | Should -BeFalse
        Test-BravoElevationSkip -Elevated $false -Section 'Security.Firewall' -Message 'Initialization failure' | Should -BeFalse
    }
}
