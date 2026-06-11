# MODULE: 38-Collectors-Software.ps1
# Збір інформації про встановлене програмне забезпечення.

function Get-BravoSoftwareAudit {
    [CmdletBinding()]
    param()

    # --- Програмне забезпечення ---
    try {
        $softwareRegistryPaths = @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )

        if ($Profile -in @('Deep','Forensic')) {
            $softwareRegistryPaths += 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        }

        $softwareInfo = Get-ItemProperty $softwareRegistryPaths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayName -notlike '*Update*' } |
            Sort-Object DisplayName -Unique

        foreach ($softwareItem in $softwareInfo) {
            if ($Profile -eq 'Quick') {
                $script:Report.Software.Installed += $softwareItem.DisplayName
            } else {
                $script:Report.Software.Installed += [PSCustomObject]@{
                    DisplayName    = $softwareItem.DisplayName
                    DisplayVersion = $softwareItem.DisplayVersion
                    Publisher      = $softwareItem.Publisher
                    InstallDate    = $softwareItem.InstallDate
                    InstallLocation = $softwareItem.InstallLocation
                }
            }
        }

        Write-Host "  $IconDb ПЗ: $($script:Report.Software.Installed.Count) програм" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Software' -Message $_.Exception.Message
    }
}
