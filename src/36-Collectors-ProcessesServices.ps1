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
            try {
                # WorkingSet64 обчислюється лениво при першому зверненні (потребує
                # handle до процесу), а не кешується в момент Get-Process — якщо
                # короткоживучий процес завершується між Get-Process і Sort-Object,
                # звернення до .WorkingSet64 усередині сортування кидає виняток
                # "process has exited" і валить весь TopMemory разом з рештою
                # процесів. Тому знімаємо WorkingSet64 у власному try/catch на
                # кожен процес окремо — процес, що встиг завершитись, просто
                # пропускається, решта топ-10 все одно рахується.
                $processSnapshot = New-Object System.Collections.Generic.List[object]
                foreach ($proc in $processInfo) {
                    try {
                        $processSnapshot.Add([PSCustomObject]@{
                            ProcessName = $proc.ProcessName
                            Id          = $proc.Id
                            MemoryMB    = [Math]::Round($proc.WorkingSet64 / 1MB, 2)
                        })
                    } catch {
                        # Свідомо ігноруємо: процес завершився між Get-Process і
                        # зверненням до WorkingSet64 — не переривляємо збір топ-10
                        # через один короткоживучий процес.
                    }
                }
                $script:Report.Processes.TopMemory = @($processSnapshot | Sort-Object -Property MemoryMB -Descending | Select-Object -First 10)
            } catch {
                Add-AuditError -Section 'Processes.TopMemory' -Message $_.Exception.Message
            }
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
