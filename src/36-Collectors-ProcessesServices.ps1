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
                # Відомі trigger-start/опціональні служби Windows: WMI показує їх як
                # StartMode='Auto', але вони штатно стоять Stopped, поки їх не розбудить
                # тригер (подія/пристрій/попит) — це не ознака проблеми на машині.
                # RemoteRegistry особливо: зупинена = добре (security best practice).
                $bravoKnownTriggerStartServices = @(
                    'edgeupdate', 'edgeupdatem', 'gupdate', 'gupdatem',
                    'MapsBroker', 'sppsvc', 'WbioSrvc', 'RemoteRegistry'
                )

                $autoStopped = Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State<>'Running'" -ErrorAction Stop
                $script:Report.Services.AutomaticStopped = @($autoStopped | Select-Object Name, DisplayName, State, StartMode, StartName)

                $noteworthyStopped = @($script:Report.Services.AutomaticStopped | Where-Object { $_.Name -notin $bravoKnownTriggerStartServices })

                if ($noteworthyStopped.Count -gt 0) {
                    $totalStoppedCount = $script:Report.Services.AutomaticStopped.Count
                    $noiseCount = $totalStoppedCount - $noteworthyStopped.Count
                    $noiseNote = if ($noiseCount -gt 0) { " (ще $noiseCount — відомі trigger-start/опціональні служби, не є ризиком)" } else { '' }

                    Add-AuditFinding -Severity 'WARNING' -Category 'Services' -Message "Автоматичних служб не запущено: $($noteworthyStopped.Count)$noiseNote." -Recommendation 'Перевірте, чи ці служби мають бути запущені.'
                }
            } catch {
                Add-AuditError -Section 'Services.AutomaticStopped' -Message $_.Exception.Message
            }
        }
    } catch {
        Add-AuditError -Section 'Services' -Message $_.Exception.Message
    }
}
