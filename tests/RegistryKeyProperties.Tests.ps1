# MODULE: tests/RegistryKeyProperties.Tests.ps1
# Pester-тести для чистої функції ConvertFrom-BravoRegistryKeyProperties
# (src/34-Collectors-Security.ps1, Security.Autoruns).

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\34-Collectors-Security.ps1')
}

Describe 'ConvertFrom-BravoRegistryKeyProperties' {
    It 'витягує реальні Name/Value пари, відкидаючи PS*-метавластивості' {
        $fakeRegistryObject = [PSCustomObject]@{
            OneDrive   = 'C:\Users\jdoe\AppData\Local\Microsoft\OneDrive\OneDrive.exe /background'
            SecurityHealth = '%windir%\System32\SecurityHealthSystray.exe'
            PSPath       = 'Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\SOFTWARE\...'
            PSParentPath = 'Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\SOFTWARE'
            PSChildName  = 'Run'
            PSDrive      = 'HKCU'
            PSProvider   = 'Microsoft.PowerShell.Core\Registry'
        }

        $result = ConvertFrom-BravoRegistryKeyProperties -PropertiesObject $fakeRegistryObject
        $result.Count | Should -Be 2
        ($result | Where-Object { $_.Name -eq 'OneDrive' }).Value | Should -Be 'C:\Users\jdoe\AppData\Local\Microsoft\OneDrive\OneDrive.exe /background'
        ($result | Where-Object { $_.Name -eq 'SecurityHealth' }).Value | Should -Be '%windir%\System32\SecurityHealthSystray.exe'
    }

    It '$null повертає порожній масив (AllowNull)' {
        $result = ConvertFrom-BravoRegistryKeyProperties -PropertiesObject $null
        @($result).Count | Should -Be 0
    }

    It 'ключ без жодного реального значення (лише PS*-метавластивості) повертає порожній масив' {
        $fakeRegistryObject = [PSCustomObject]@{
            PSPath       = 'x'
            PSParentPath = 'x'
            PSChildName  = 'RunOnce'
            PSDrive      = 'HKLM'
            PSProvider   = 'Microsoft.PowerShell.Core\Registry'
        }

        $result = ConvertFrom-BravoRegistryKeyProperties -PropertiesObject $fakeRegistryObject
        @($result).Count | Should -Be 0
    }
}
