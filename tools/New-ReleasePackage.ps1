param(
    [string]$RepoPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$Version = "",
    [string]$OutputPath = "",
    [switch]$NoClean
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message"
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message"
}

function Add-ZipEntry {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$SourcePath,
        [string]$EntryName
    )

    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $Archive,
        $SourcePath,
        $EntryName.Replace('\', '/'),
        [System.IO.Compression.CompressionLevel]::Optimal
    ) | Out-Null
}

function Resolve-PackageVersion {
    param(
        [string]$RepoPath
    )

    $ChangelogPath = Join-Path $RepoPath "CHANGELOG.md"
    if (Test-Path -LiteralPath $ChangelogPath) {
        $Changelog = Get-Content -LiteralPath $ChangelogPath -Raw -Encoding UTF8
        $ChangelogMatch = [regex]::Match($Changelog, '(?m)^##\s+v?(?<Version>\d+\.\d+\.\d+)')
        if ($ChangelogMatch.Success) {
            return $ChangelogMatch.Groups["Version"].Value
        }
    }

    $SourceScript = Join-Path $RepoPath "src\Get-BravoSystemReport.ps1"
    if (Test-Path -LiteralPath $SourceScript) {
        $SourceContent = Get-Content -LiteralPath $SourceScript -Raw -Encoding UTF8
        $ScriptVersionMatch = [regex]::Match($SourceContent, '\$ScriptVersion\s*=\s*["''](?<Version>[^"'']+)["'']')
        if ($ScriptVersionMatch.Success) {
            return $ScriptVersionMatch.Groups["Version"].Value
        }
    }

    throw "Cannot detect package version from CHANGELOG.md or src\Get-BravoSystemReport.ps1"
}

Write-Host "=== BRAVO SYSTEM REPORT RELEASE PACKAGE ==="

if (-not (Test-Path -LiteralPath $RepoPath)) {
    throw "RepoPath not found: $RepoPath"
}

$RepoPath = (Resolve-Path -LiteralPath $RepoPath).Path
Set-Location -LiteralPath $RepoPath

$SourceScript = Join-Path $RepoPath "src\Get-BravoSystemReport.ps1"
if (-not (Test-Path -LiteralPath $SourceScript)) {
    throw "Source script not found: $SourceScript"
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Resolve-PackageVersion -RepoPath $RepoPath
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $RepoPath "artifacts"
}

if (-not (Test-Path -LiteralPath $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

$PackageName = "BRAVO_SYSTEM_REPORT_v$Version"
$StagingRoot = Join-Path $OutputPath "_staging\$PackageName"
$ZipPath = Join-Path $OutputPath "$PackageName.zip"
$Sha256Path = "$ZipPath.sha256"

if ((Test-Path -LiteralPath $StagingRoot) -and (-not $NoClean)) {
    Remove-Item -LiteralPath $StagingRoot -Recurse -Force
}

if (-not (Test-Path -LiteralPath $StagingRoot)) {
    New-Item -ItemType Directory -Path $StagingRoot | Out-Null
}

$IncludeFiles = @(
    "Get-BravoSystemReport.ps1",
    "src\Get-BravoSystemReport.ps1",
    "BRAVO-SystemReport-Quick.bat",
    "BRAVO-SystemReport-Full.bat",
    "BRAVO-SystemReport-Deep.bat",
    "BRAVO-SystemReport-Forensic.bat",
    "BRAVO-SystemReport-Launcher.bat",
    "README.md",
    "CHANGELOG.md",
    "LICENSE.md",
    "docs\ARCHITECTURE.md",
    "docs\PROJECT_RULES.md",
    "docs\ROADMAP.md",
    "docs\SECURITY.md",
    "examples\README.md"
)

$CopiedFiles = New-Object System.Collections.Generic.List[string]

foreach ($RelativePath in $IncludeFiles) {
    $SourcePath = Join-Path $RepoPath $RelativePath
    if (-not (Test-Path -LiteralPath $SourcePath)) {
        throw "Required file not found: $RelativePath"
    }

    $DestinationPath = Join-Path $StagingRoot $RelativePath
    $DestinationDir = Split-Path -Parent $DestinationPath

    if (-not (Test-Path -LiteralPath $DestinationDir)) {
        New-Item -ItemType Directory -Path $DestinationDir | Out-Null
    }

    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
    $CopiedFiles.Add($RelativePath) | Out-Null
}

$ManifestPath = Join-Path $StagingRoot "MANIFEST.txt"
$ManifestLines = @(
    "BRAVO SYSTEM REPORT release package"
    "Version: $Version"
    "CreatedAt: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    ""
    "Files:"
)

foreach ($RelativePath in ($CopiedFiles | Sort-Object)) {
    $ManifestLines += "- $RelativePath"
}

$ManifestLines | Set-Content -LiteralPath $ManifestPath -Encoding UTF8

if (Test-Path -LiteralPath $ZipPath) {
    Remove-Item -LiteralPath $ZipPath -Force
}

if (Test-Path -LiteralPath $Sha256Path) {
    Remove-Item -LiteralPath $Sha256Path -Force
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$ZipStream = New-Object System.IO.FileStream($ZipPath, [System.IO.FileMode]::Create)
$ZipArchive = New-Object System.IO.Compression.ZipArchive($ZipStream, [System.IO.Compression.ZipArchiveMode]::Create)

try {
    Get-ChildItem -LiteralPath $StagingRoot -Recurse -File |
        Sort-Object FullName |
        ForEach-Object {
            $EntryName = $_.FullName.Substring($StagingRoot.Length).TrimStart('\')
            Add-ZipEntry -Archive $ZipArchive -SourcePath $_.FullName -EntryName $EntryName
        }
}
finally {
    $ZipArchive.Dispose()
    $ZipStream.Dispose()
}

$Hash = Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256
"$($Hash.Hash)  $(Split-Path -Leaf $ZipPath)" | Set-Content -LiteralPath $Sha256Path -Encoding ASCII

if (-not $NoClean) {
    $StagingParent = Split-Path -Parent $StagingRoot
    if (Test-Path -LiteralPath $StagingParent) {
        Remove-Item -LiteralPath $StagingParent -Recurse -Force
    }
}

Write-Ok "Package created: $ZipPath"
Write-Ok "SHA256 created: $Sha256Path"

Write-Host ""
Write-Host "=== PACKAGE CONTENT ==="

$Zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
try {
    $Zip.Entries |
        Select-Object FullName,Length |
        Format-Table -AutoSize
}
finally {
    $Zip.Dispose()
}

Write-Host ""
Write-Host "=== SHA256 ==="
Get-Content -LiteralPath $Sha256Path

Write-Host ""
Write-Ok "Release package build completed"