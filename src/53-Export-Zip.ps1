# MODULE: 53-Export-Zip.ps1
# Експорт BRAVO SYSTEM REPORT у ZIP.

function Export-BravoZipReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputDir,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseFileName,

        [Parameter(Mandatory = $true)]
        [bool]$Zip
    )

    # ZIP
    if ($Zip) {
        try {
            $zipPath = Join-Path $OutputDir "$BaseFileName.zip"
            Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop

            if (Test-Path -LiteralPath $zipPath) {
                Remove-Item -LiteralPath $zipPath -Force
            }

            $zipStream = New-Object System.IO.FileStream($zipPath, [System.IO.FileMode]::Create)
            $zipArchive = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)

            foreach ($file in $script:Report.GeneratedFiles) {
                if (Test-Path -LiteralPath $file) {
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $file, (Split-Path $file -Leaf), [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
                }
            }

            $zipArchive.Dispose()
            $zipStream.Dispose()

            $script:Report.GeneratedFiles += $zipPath
            Write-Host "  $IconZip ZIP: $BaseFileName.zip" -ForegroundColor Green
        } catch {
            Add-AuditError -Section 'Export.Zip' -Message $_.Exception.Message
            Write-Host "  $IconError Помилка створення ZIP: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
