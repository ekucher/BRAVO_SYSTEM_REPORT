# MODULE: 53-Export-Zip.ps1
# Експорт BRAVO SYSTEM REPORT у ZIP.

function Import-BravoZipAssemblies {
    [CmdletBinding()]
    param()

    $assemblies = @(
        'System.IO.Compression',
        'System.IO.Compression.FileSystem'
    )

    foreach ($assemblyName in $assemblies) {
        try {
            Add-Type -AssemblyName $assemblyName -ErrorAction Stop
        } catch {
            throw "Не вдалося завантажити .NET assembly $assemblyName`: $($_.Exception.Message)"
        }
    }

    $requiredTypes = @(
        'System.IO.Compression.ZipArchive',
        'System.IO.Compression.ZipArchiveMode',
        'System.IO.Compression.ZipFileExtensions'
    )

    foreach ($typeName in $requiredTypes) {
        if (-not ($typeName -as [type])) {
            throw "Не знайдено .NET тип $typeName після завантаження System.IO.Compression assemblies. Перевірте версію .NET Framework."
        }
    }
}

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
        $zipArchive = $null
        $zipStream = $null

        try {
            Import-BravoZipAssemblies

            $zipPath = Join-Path $OutputDir "$BaseFileName.zip"

            if (Test-Path -LiteralPath $zipPath) {
                Remove-Item -LiteralPath $zipPath -Force
            }

            $zipStream = New-Object System.IO.FileStream($zipPath, [System.IO.FileMode]::Create)
            $zipArchive = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)

            foreach ($file in $script:Report.GeneratedFiles) {
                if (Test-Path -LiteralPath $file) {
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                        $zipArchive,
                        $file,
                        (Split-Path $file -Leaf),
                        [System.IO.Compression.CompressionLevel]::Optimal
                    ) | Out-Null
                }
            }

            $script:Report.GeneratedFiles += $zipPath
            Write-Host "  $IconZip ZIP: $BaseFileName.zip" -ForegroundColor Green
        } catch {
            Add-ExportError -Section 'Export.Zip' -Message $_.Exception.Message
            Write-Host "  $IconError Помилка створення ZIP: $($_.Exception.Message)" -ForegroundColor Red
        } finally {
            if ($null -ne $zipArchive) { $zipArchive.Dispose() }
            if ($null -ne $zipStream) { $zipStream.Dispose() }
        }
    }
}
