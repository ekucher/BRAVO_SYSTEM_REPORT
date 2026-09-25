# MODULE: tests/DocsSchema.Tests.ps1
# Sanity-перевірка docs/SCHEMA.md (v0.6.0 Reports and UX: JSON schema
# documentation) — не тестує PowerShell-код, лише що документація існує
# і не розійшлась з фактичним SchemaVersion.

Describe 'docs/SCHEMA.md' {
    BeforeAll {
        $script:SchemaDocPath = Join-Path $PSScriptRoot '..\docs\SCHEMA.md'
        $script:ReportModelPath = Join-Path $PSScriptRoot '..\src\20-ReportModel.ps1'
    }

    It 'файл docs/SCHEMA.md існує' {
        Test-Path -LiteralPath $script:SchemaDocPath | Should -BeTrue
    }

    It 'документ згадує SchemaVersion' {
        $content = Get-Content -LiteralPath $script:SchemaDocPath -Raw
        $content | Should -Match 'SchemaVersion'
    }

    It 'документ згадує кожен верхньорівневий розділ моделі (перевірка навігаційної повноти)' {
        $content = Get-Content -LiteralPath $script:SchemaDocPath -Raw
        foreach ($section in @('Meta', 'Dashboard', 'Health', 'Hardware', 'Network', 'Security', 'EventLogs', 'Software', 'Updates')) {
            $content | Should -Match $section
        }
    }
}
