# MODULE: 52-Export-Csv.ps1
# Експорт BRAVO SYSTEM REPORT у CSV.

function Export-BravoCsvReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputDir,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseFileName,

        [Parameter(Mandatory = $true)]
        [bool]$CSV
    )

    # CSV
    if ($CSV) {
        try {
            $csvPath = Join-Path $OutputDir "$BaseFileName.csv"
            $csvData = @(
                [PSCustomObject]@{Parameter='ComputerName'; Value=$script:Report.ComputerName}
                [PSCustomObject]@{Parameter='Timestamp'; Value=$script:Report.Timestamp}
                [PSCustomObject]@{Parameter='Profile'; Value=$script:Report.Profile}
                [PSCustomObject]@{Parameter='HealthScore'; Value=$script:Report.Health.Score}
                [PSCustomObject]@{Parameter='HealthStatus'; Value=$script:Report.Health.Status}
                [PSCustomObject]@{Parameter='OS'; Value=$script:Report.OS.Caption}
                [PSCustomObject]@{Parameter='OSBuild'; Value=$script:Report.OS.Build}
                [PSCustomObject]@{Parameter='UptimeDays'; Value=$script:Report.OS.UptimeDays}
                [PSCustomObject]@{Parameter='CPU_Cores'; Value=$script:Report.Hardware.CPU.Cores}
                [PSCustomObject]@{Parameter='CPU_LogicalProcessors'; Value=$script:Report.Hardware.CPU.LogicalProcessors}
                [PSCustomObject]@{Parameter='CPU_Load'; Value=$script:Report.Hardware.CPU.LoadPercent}
                [PSCustomObject]@{Parameter='RAM_GB'; Value=$script:Report.Hardware.RAM.TotalGB}
                [PSCustomObject]@{Parameter='RAM_Used_Percent'; Value=$script:Report.Hardware.RAM.UsedPercent}
                [PSCustomObject]@{Parameter='Disk_Free_Percent'; Value=$script:Report.Hardware.Disks.FreePercent}
                [PSCustomObject]@{Parameter='IPv4'; Value=($script:Report.Network.IP.IPv4 -join '; ')}
                [PSCustomObject]@{Parameter='RDP_Enabled'; Value=$script:Report.Security.RemoteAccess.RDPEnabled}
                [PSCustomObject]@{Parameter='UAC_Enabled'; Value=$script:Report.Security.UAC.Enabled}
                [PSCustomObject]@{Parameter='Processes'; Value=$script:Report.Processes.Total}
                [PSCustomObject]@{Parameter='Running_Services'; Value=$script:Report.Services.Running}
                [PSCustomObject]@{Parameter='AutomaticStoppedServices'; Value=$script:Report.Services.AutomaticStopped.Count}
                [PSCustomObject]@{Parameter='Errors_24h'; Value=$script:Report.EventLogs.SystemErrors24h}
                [PSCustomObject]@{Parameter='Errors_ProfileDays'; Value=$script:Report.EventLogs.SystemErrors}
                [PSCustomObject]@{Parameter='Installed_Software'; Value=$script:Report.Software.Installed.Count}
                [PSCustomObject]@{Parameter='Local_Admins'; Value=$script:Report.Users.LocalAdmins.Count}
                [PSCustomObject]@{Parameter='Findings'; Value=$script:Report.Health.Findings.Count}
                [PSCustomObject]@{Parameter='CollectionErrors'; Value=$script:Report.CollectionErrors.Count}
            )

            $csvData | Export-Csv $csvPath -NoTypeInformation -Encoding utf8
            $script:Report.GeneratedFiles += $csvPath
            Write-Host "  $IconCsv CSV: $BaseFileName.csv" -ForegroundColor Green
        } catch {
            Add-AuditError -Section 'Export.Csv' -Message $_.Exception.Message
            Write-Host "  $IconError Помилка CSV: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
