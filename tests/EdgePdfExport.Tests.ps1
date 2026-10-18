# MODULE: tests/EdgePdfExport.Tests.ps1
# Pester-тести для Get-BravoEdgeExecutablePath (src/51-Export-Html.ps1,
# v0.6.1 Advanced UX: -ExportPdf через headless Microsoft Edge).

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\51-Export-Html.ps1')
}

Describe 'Get-BravoEdgeExecutablePath' {
    It 'повертає шлях до msedge.exe, якщо Edge встановлено, або $null — без винятку в обох випадках' {
        { Get-BravoEdgeExecutablePath } | Should -Not -Throw

        $result = Get-BravoEdgeExecutablePath
        if ($null -ne $result) {
            $result | Should -Match 'msedge\.exe$'
            Test-Path -LiteralPath $result | Should -BeTrue
        }
    }
}
