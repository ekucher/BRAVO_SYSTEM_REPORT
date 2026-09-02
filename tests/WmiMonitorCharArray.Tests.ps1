# MODULE: tests/WmiMonitorCharArray.Tests.ps1
# Pester-тести для чистої функції ConvertFrom-BravoWmiMonitorCharArray
# (src/31-Collectors-Hardware.ps1, Hardware.Monitors, EDID char-array parsing).

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\31-Collectors-Hardware.ps1')
}

Describe 'ConvertFrom-BravoWmiMonitorCharArray' {
    It 'конвертує масив UInt16-кодів символів у звичайний рядок' {
        $value = [int[]]@(65, 83, 85, 83)  # 'ASUS'
        ConvertFrom-BravoWmiMonitorCharArray -Value $value | Should -Be 'ASUS'
    }

    It 'відкидає нульове заповнення у хвості (EDID fixed-length array)' {
        $value = [int[]]@(88, 71, 50, 55, 0, 0, 0, 0)  # 'XG27' + padding
        ConvertFrom-BravoWmiMonitorCharArray -Value $value | Should -Be 'XG27'
    }

    It '$null повертає порожній рядок (AllowNull)' {
        ConvertFrom-BravoWmiMonitorCharArray -Value $null | Should -Be ''
    }

    It 'порожній масив повертає порожній рядок' {
        ConvertFrom-BravoWmiMonitorCharArray -Value @() | Should -Be ''
    }
}
