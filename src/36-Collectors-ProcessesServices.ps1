# MODULE: 36-Collectors-ProcessesServices.ps1
# Збір інформації про процеси, служби та автоматичні служби, які не запущені.

function Get-BravoProcessesServicesAudit {
    [CmdletBinding()]
    param()

    # --- Процеси ---
    try {
        $processInfo = Get-Process -ErrorAction Stop
        $script:Report.Processes.Total = $processInfo.Count
        if ($Profile -in @('Full','Deep','Forensic')) {
            $script:Report.Processes.TopMemory = $processInfo |
                Sort-Object -Property WorkingSet64 -Descending |
                Select-Object -First 10 @{Name='ProcessName';Expression={$_.ProcessName}}, Id, @{Name='MemoryMB';Expression={[Math]::Round($_.WorkingSet64 / 1MB, 2)}}
        }
        Write-Host "  $IconService Процеси: $($script:Report.Processes.Total)" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Processes' -Message $_.Exception.Message
    }

    # --- Служби ---
    try {
        $serviceInfo = Get-Service -ErrorAction Stop
        $script:Report.Services.Total = $serviceInfo.Count
        $script:Report.Services.Running = @($serviceInfo | Where-Object { $_.Status -eq 'Running' }).Count

        if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
            try {
                $autoStopped = Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State<>'Running'" -ErrorAction Stop
                $script:Report.Services.AutomaticStopped = @($autoStopped | Select-Object Name, DisplayName, State, StartMode, StartName)
                if ($script:Report.Services.AutomaticStopped.Count -gt 0) {
                    Add-AuditFinding -Severity 'WARNING' -Category 'Services' -Message "Автоматичних служб не запущено: $($script:Report.Services.AutomaticStopped.Count)." -Recommendation 'Перевірте, чи ці служби мають бути запущені.'
                }
            } catch {
                Add-AuditError -Section 'Services.AutomaticStopped' -Message $_.Exception.Message
            }
        }
    } catch {
        Add-AuditError -Section 'Services' -Message $_.Exception.Message
    }
}
