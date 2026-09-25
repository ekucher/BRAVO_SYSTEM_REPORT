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

    # src\90-Main.ps1 — основне, завжди актуальне джерело версії (ScriptVersion).
    # CHANGELOG.md — fallback: у поточному форматі заголовки мають вигляд
    # "## Unreleased — ..." (не "## vX.Y.Z"), тому регекс нижче зазвичай не
    # спрацьовує — це очікувано, не помилка; спрацює лише якщо колись
    # з'явиться заголовок конкретного релізу в форматі "## vX.Y.Z".
    $MainScript = Join-Path $RepoPath "src\90-Main.ps1"
    if (Test-Path -LiteralPath $MainScript) {
        $MainContent = Get-Content -LiteralPath $MainScript -Raw -Encoding UTF8
        $ScriptVersionMatch = [regex]::Match($MainContent, '\$ScriptVersion\s*=\s*["''](?<Version>[^"'']+)["'']')
        if ($ScriptVersionMatch.Success) {
            return $ScriptVersionMatch.Groups["Version"].Value
        }
    }

    $ChangelogPath = Join-Path $RepoPath "CHANGELOG.md"
    if (Test-Path -LiteralPath $ChangelogPath) {
        $Changelog = Get-Content -LiteralPath $ChangelogPath -Raw -Encoding UTF8
        $ChangelogMatch = [regex]::Match($Changelog, '(?m)^##\s+v?(?<Version>\d+\.\d+\.\d+)')
        if ($ChangelogMatch.Success) {
            return $ChangelogMatch.Groups["Version"].Value
        }
    }

    throw "Cannot detect package version from CHANGELOG.md or src\90-Main.ps1"
}

Write-Host "=== BRAVO SYSTEM REPORT RELEASE PACKAGE ==="

if (-not (Test-Path -LiteralPath $RepoPath)) {
    throw "RepoPath not found: $RepoPath"
}

$RepoPath = (Resolve-Path -LiteralPath $RepoPath).Path
Set-Location -LiteralPath $RepoPath

# Кросплатформна нормалізація відносних шляхів пакета.
function Resolve-PackageRelativePath {
    param(
        [string]$RepoPath,
        [string]$RelativePath
    )

    $normalized = $RelativePath -replace '[\\/]', [System.IO.Path]::DirectorySeparatorChar
    return (Join-Path $RepoPath $normalized)
}

$DistScript = Resolve-PackageRelativePath -RepoPath $RepoPath -RelativePath "dist/Get-BravoSystemReport.ps1"
$DistSha512 = "$DistScript.sha512"
if (-not (Test-Path -LiteralPath $DistScript) -or -not (Test-Path -LiteralPath $DistSha512)) {
    throw "dist\Get-BravoSystemReport.ps1 (+ .sha512) не знайдено. Спершу виконайте: .\Build-BRAVO-SystemReport.ps1 -CreateSha512"
}

$ActualHash = (Get-FileHash -LiteralPath $DistScript -Algorithm SHA512).Hash.Trim()
$RecordedHash = (Get-Content -LiteralPath $DistSha512 -Raw).Trim()
if ($ActualHash -ne $RecordedHash) {
    throw "dist\Get-BravoSystemReport.ps1.sha512 не відповідає dist\Get-BravoSystemReport.ps1. Перезберіть через .\Build-BRAVO-SystemReport.ps1 -CreateSha512"
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
$StagingRoot = Join-Path (Join-Path $OutputPath "_staging") $PackageName
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
    "dist/Get-BravoSystemReport.ps1",
    "BRAVO-SystemReport-Quick.bat",
    "BRAVO-SystemReport-Full.bat",
    "BRAVO-SystemReport-Deep.bat",
    "BRAVO-SystemReport-Forensic.bat",
    "BRAVO-SystemReport-Launcher.bat",
    "README.md",
    "CHANGELOG.md",
    "LICENSE.md",
    "docs/AI_RULES.md",
    "docs/ARCHITECTURE.md",
    "docs/PROJECT_RULES.md",
    "docs/ROADMAP.md",
    "docs/SECURITY.md",
    "examples/README.md"
)

$CopiedFiles = New-Object System.Collections.Generic.List[string]

foreach ($RelativePath in $IncludeFiles) {
    $SourcePath = Resolve-PackageRelativePath -RepoPath $RepoPath -RelativePath $RelativePath
    if (-not (Test-Path -LiteralPath $SourcePath)) {
        throw "Required file not found: $RelativePath"
    }

    $DestinationPath = Resolve-PackageRelativePath -RepoPath $StagingRoot -RelativePath $RelativePath
    $DestinationDir = Split-Path -Parent $DestinationPath

    if (-not (Test-Path -LiteralPath $DestinationDir)) {
        New-Item -ItemType Directory -Path $DestinationDir | Out-Null
    }

    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
    $CopiedFiles.Add($RelativePath) | Out-Null
}

# Пакет призначений для Windows: усі текстові файли нормалізуються до CRLF,
# щоб контрольна сума в пакеті відповідала саме тому файлу, який отримує користувач.
$TextExtensions = @('.ps1', '.bat', '.md', '.txt')
$Latin1 = [System.Text.Encoding]::GetEncoding(28591)

Get-ChildItem -LiteralPath $StagingRoot -Recurse -File |
    Where-Object { $TextExtensions -contains $_.Extension.ToLowerInvariant() } |
    ForEach-Object {
        $rawBytes = [System.IO.File]::ReadAllBytes($_.FullName)
        $rawText = $Latin1.GetString($rawBytes)
        $normalizedText = ($rawText -replace "`r`n", "`n") -replace "`n", "`r`n"

        if ($normalizedText -ne $rawText) {
            [System.IO.File]::WriteAllBytes($_.FullName, $Latin1.GetBytes($normalizedText))
        }
    }

$StagedRuntime = Resolve-PackageRelativePath -RepoPath $StagingRoot -RelativePath "dist/Get-BravoSystemReport.ps1"
$StagedSha512Path = "$StagedRuntime.sha512"
$StagedHash = Get-FileHash -LiteralPath $StagedRuntime -Algorithm SHA512
$StagedHash.Hash | Set-Content -LiteralPath $StagedSha512Path -Encoding ASCII
$CopiedFiles.Add("dist/Get-BravoSystemReport.ps1.sha512") | Out-Null

Write-Info "SHA512 runtime у пакеті: $($StagedHash.Hash.Substring(0,32))..."

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
    # Push-Location + Resolve-Path -Relative замість ручного
    # .Substring($StagingRoot.Length): на машинах, де $OutputPath (напр.
    # побудований з $env:TEMP) резолвиться у 8.3 коротку форму (типу
    # "BRAVOR~1"), а Get-ChildItem повертає .FullName у довгій формі,
    # наївна арифметика по довжині рядка з'їжджає — файли пакувались із
    # "хвостом" шляху замість чистого відносного імені (напр.
    # "5.1/BRAVO-SystemReport-Quick.bat" замість "BRAVO-SystemReport-Quick.bat",
    # спостережено на self-hosted CI runner). Resolve-Path -Relative рахує
    # відносний шлях через провайдер PowerShell від поточної локації —
    # коректно незалежно від того, в якій формі (коротка/довга) виражені
    # проміжні сегменти шляху.
    Push-Location -LiteralPath $StagingRoot
    try {
        Get-ChildItem -LiteralPath $StagingRoot -Recurse -File |
            Sort-Object FullName |
            ForEach-Object {
                $EntryName = (Resolve-Path -LiteralPath $_.FullName -Relative) -replace '^\.[\\/]', '' -replace '\\', '/'
                Add-ZipEntry -Archive $ZipArchive -SourcePath $_.FullName -EntryName $EntryName
            }
    }
    finally {
        Pop-Location
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
    foreach ($Entry in ($Zip.Entries | Sort-Object FullName)) {
        Write-Host ("{0,10}  {1}" -f $Entry.Length, $Entry.FullName)
    }

    Write-Host ""
    Write-Host ("Файлів у пакеті: {0}" -f $Zip.Entries.Count)
}
finally {
    $Zip.Dispose()
}

Write-Host ""
Write-Host "=== SHA256 ==="
Get-Content -LiteralPath $Sha256Path

Write-Host ""
Write-Ok "Release package build completed"