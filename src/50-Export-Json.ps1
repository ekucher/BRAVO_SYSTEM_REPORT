# MODULE: 50-Export-Json.ps1
# Експорт BRAVO SYSTEM REPORT у JSON.

function Export-BravoJsonReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputDir,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseFileName
    )

    # JSON
    try {
        $jsonPath = Join-Path $OutputDir "$BaseFileName.json"
        $jsonContent = ConvertTo-Json $script:Report -Depth 12
        # Out-File -Encoding utf8 у Windows PowerShell 5.1 завжди додає BOM,
        # що ламає суворі JSON-парсери (RFC 8259 не допускає BOM) у зовнішніх
        # CI/monitoring-пайплайнах, які читають цей файл. Пишемо через
        # .NET напряму з UTF8Encoding($false) — без BOM.
        [System.IO.File]::WriteAllText($jsonPath, $jsonContent, (New-Object System.Text.UTF8Encoding($false)))
        $script:Report.GeneratedFiles += $jsonPath
        Write-Host "  $IconJson JSON: $BaseFileName.json" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Export.Json' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка JSON: $($_.Exception.Message)" -ForegroundColor Red
    }
}
