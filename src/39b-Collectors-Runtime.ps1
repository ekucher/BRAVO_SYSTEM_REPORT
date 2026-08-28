# MODULE: 39b-Collectors-Runtime.ps1
# Перевірка можливості оновлення .NET Framework (4.x) та PowerShell.
# Працює повністю офлайн: "найновіша відома версія" — константи в коді,
# без звернень в інтернет. Періодично варто оновлювати ці константи.

function Get-BravoRuntimeAudit {
    [CmdletBinding()]
    param()

    # --- .NET Framework 4.x ---
    try {
        # .NET Framework 4.8.1 підтримується лише на Windows 11 22H2+ (build 22621+)
        # та Windows Server 2022 23H2/Annual Channel+ (build 25398+, теж >= 22621).
        # На старіших ОС (Windows 7 SP1–10, Server 2012–2022 LTSC) 4.8.1 не існує
        # як окремий пакет — інсталятор там блокується "не підтримується цією ОС",
        # тож максимум, який можна рекомендувати, — 4.8.
        $osBuildNumber = 0
        $osBuildParsed = [int]::TryParse([string]$script:Report.OS.Build, [ref]$osBuildNumber)
        $supports481 = $osBuildParsed -and ($osBuildNumber -ge 22621)

        if ($supports481) {
            $maxCompatibleVersion = '4.8.1'
            $maxCompatibleReleaseKey = 533320
        } else {
            $maxCompatibleVersion = '4.8'
            $maxCompatibleReleaseKey = 528040
        }
        $script:Report.DotNet.LatestKnownVersion = $maxCompatibleVersion

        if (Test-Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full') {
            $release = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue).Release

            if ($release) {
                $script:Report.DotNet.ReleaseKey = $release

                if ($release -ge 533320) { $script:Report.DotNet.v4 = '4.8.1+' }
                elseif ($release -ge 528040) { $script:Report.DotNet.v4 = '4.8' }
                elseif ($release -ge 461808) { $script:Report.DotNet.v4 = '4.7.2+' }
                else { $script:Report.DotNet.v4 = "Release $release" }

                $script:Report.DotNet.UpdateAvailable = ($release -lt $maxCompatibleReleaseKey)

                if ($script:Report.DotNet.UpdateAvailable) {
                    if ($supports481) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'DotNet' -Message ".NET Framework застарів: $($script:Report.DotNet.v4) (максимальна сумісна версія для цієї ОС: 4.8.1)" -Recommendation 'Встановіть оновлення через Windows Update (.NET Framework 4.8.1 постачається як компонент ОС) або офлайн-інсталятор із microsoft.com/net/download/dotnet-framework/net481, якщо Windows Update недоступний.'
                    } else {
                        Add-AuditFinding -Severity 'WARNING' -Category 'DotNet' -Message ".NET Framework застарів: $($script:Report.DotNet.v4) (максимальна сумісна версія для цієї ОС: 4.8; 4.8.1 на цій версії Windows НЕ підтримується)" -Recommendation 'Встановіть .NET Framework 4.8 (максимум, підтримуваний цією ОС) через Windows Update або офлайн-інсталятор. Не намагайтесь ставити 4.8.1 — інсталятор заблокує встановлення як несумісне з цією ОС.'
                    }
                }
            }
        }

        Write-Host "  $IconOk .NET Framework: $($script:Report.DotNet.v4)" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Runtime.DotNet' -Message $_.Exception.Message
    }

    # --- Windows PowerShell (Desktop edition) ---
    try {
        $psVersion = $PSVersionTable.PSVersion
        $currentPSEdition = $PSVersionTable.PSEdition

        if ($currentPSEdition -eq 'Desktop' -and $psVersion.Major -lt 5) {
            Add-AuditFinding -Severity 'WARNING' -Category 'PowerShell' -Message "Застаріла версія Windows PowerShell: $psVersion" -Recommendation 'Оновіть до Windows PowerShell 5.1 (Windows Management Framework 5.1) — це остання версія Desktop-редакції.'
        }
    } catch {
        Add-AuditError -Section 'Runtime.PowerShell' -Message $_.Exception.Message
    }

    # --- PowerShell 7 (Core), встановлений поруч ---
    try {
        $latestKnownCore7 = '7.4'
        $script:Report.PowerShell.Core7LatestKnown = $latestKnownCore7

        $core7InstallsPath = 'HKLM:\SOFTWARE\Microsoft\PowerShellCore\InstalledVersions'
        if (Test-Path $core7InstallsPath) {
            $core7Install = Get-ChildItem -LiteralPath $core7InstallsPath -ErrorAction SilentlyContinue |
                ForEach-Object { Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue } |
                Where-Object { $_.SemanticVersion } |
                Sort-Object { [version]($_.SemanticVersion -replace '-.*$','') } -Descending |
                Select-Object -First 1

            if ($core7Install) {
                $script:Report.PowerShell.Core7Installed = $true
                $script:Report.PowerShell.Core7Version = $core7Install.SemanticVersion

                $core7VersionParsed = [version]($core7Install.SemanticVersion -replace '-.*$','')
                $latestKnownParsed = [version]$latestKnownCore7

                if (($core7VersionParsed.Major -lt $latestKnownParsed.Major) -or
                    ($core7VersionParsed.Major -eq $latestKnownParsed.Major -and $core7VersionParsed.Minor -lt $latestKnownParsed.Minor)) {
                    $script:Report.PowerShell.Core7UpdateAvailable = $true
                    Add-AuditFinding -Severity 'WARNING' -Category 'PowerShell' -Message "PowerShell 7 застарів: $($script:Report.PowerShell.Core7Version) (найновіша відома версія: $latestKnownCore7)" -Recommendation 'Оновіть PowerShell 7 через winget (winget upgrade Microsoft.PowerShell) або MSI з github.com/PowerShell/PowerShell.'
                }
            }
        }

        if (-not $script:Report.PowerShell.Core7Installed -and $PSVersionTable.PSEdition -eq 'Desktop' -and $PSVersionTable.PSVersion.Major -ge 5) {
            Add-AuditFinding -Severity 'INFO' -Category 'PowerShell' -Message 'PowerShell 7 (Core) не встановлено' -Recommendation 'За потреби встановіть сучасний PowerShell 7 для розширеної функціональності та кросплатформної сумісності.'
        }

        Write-Host "  $IconOk PowerShell 7 (Core): $(if($script:Report.PowerShell.Core7Installed){$script:Report.PowerShell.Core7Version}else{'не встановлено'})" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Runtime.PowerShellCore' -Message $_.Exception.Message
    }
}
