# MODULE: tests/NetAccountsParsing.Tests.ps1
# Pester-тести для чистої функції ConvertFrom-BravoNetAccountsOutput (v0.5.0
# Deep Inventory, Security Baseline: Password policy) з
# src/34-Collectors-Security.ps1.

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\34-Collectors-Security.ps1')
}

Describe 'ConvertFrom-BravoNetAccountsOutput' {
    It 'парсить типовий англомовний вивід net accounts за фіксованою позицією рядків' {
        $lines = @(
            'Force user logoff how long after time expires?:       Never'
            'Minimum password age (days):                          0'
            'Maximum password age (days):                          42'
            'Minimum password length:                              0'
            'Length of password history maintained:                None'
            'Lockout threshold:                                    10'
            'Lockout duration (minutes):                           10'
            'Lockout observation window (minutes):                 10'
            'Computer role:                                        WORKSTATION'
            'The command completed successfully.'
            ''
        )

        $result = ConvertFrom-BravoNetAccountsOutput -Lines $lines

        $result.MinPasswordAgeDays | Should -Be '0'
        $result.MaxPasswordAgeDays | Should -Be '42'
        $result.MinPasswordLength | Should -Be '0'
        $result.PasswordHistoryLength | Should -Be 'None'
        $result.LockoutThreshold | Should -Be '10'
        $result.LockoutDurationMinutes | Should -Be '10'
        $result.LockoutObservationWindowMinutes | Should -Be '10'
    }

    It 'парсить умовно "локалізований" вивід за тією самою позицією рядків (мітки інші, порядок той самий)' {
        # Симулює нелатинську локаль: мітки замінені на довільний текст, але
        # порядок рядків і формат "мітка: значення" — той самий, що й
        # документує Microsoft для net.exe незалежно від мови інтерфейсу.
        $lines = @(
            'Примусовий вихід користувача:                          Ніколи'
            'Мінімальний вік пароля (днів):                         1'
            'Максимальний вік пароля (днів):                        30'
            'Мінімальна довжина пароля:                             8'
            'Довжина історії паролів:                               5'
            'Поріг блокування:                                      5'
            'Тривалість блокування (хвилин):                        15'
            'Вікно спостереження блокування (хвилин):               15'
            'Роль комп''ютера:                                       РОБОЧА СТАНЦІЯ'
        )

        $result = ConvertFrom-BravoNetAccountsOutput -Lines $lines

        $result.MinPasswordAgeDays | Should -Be '1'
        $result.MaxPasswordAgeDays | Should -Be '30'
        $result.MinPasswordLength | Should -Be '8'
        $result.PasswordHistoryLength | Should -Be '5'
        $result.LockoutThreshold | Should -Be '5'
    }

    It 'порожній ввід -> усі поля $null, без помилки' {
        $result = ConvertFrom-BravoNetAccountsOutput -Lines @()

        $result.MinPasswordAgeDays | Should -Be $null
        $result.LockoutThreshold | Should -Be $null
    }
}
