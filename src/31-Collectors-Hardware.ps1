# MODULE: 31-Collectors-Hardware.ps1
# Збір базової інформації про апаратне забезпечення.

# --- P1: централізовані CPU/RAM thresholds ---
# Єдине джерело порогів для Dashboard-плиток CPU/RAM і для Health.Findings —
# щоб перевантаження CPU/RAM (на відміну від попередньої поведінки) впливало
# на Health Score і потрапляло у Findings tab, а не лише в колір dashboard-картки.
function Get-BravoHardwareThresholds {
    [CmdletBinding()]
    param()

    return [ordered]@{
        CpuWarningPercent = 75
        CpuCriticalPercent = 90
        RamWarningPercent = 85
        RamCriticalPercent = 95
    }
}

function Get-BravoHardwareAudit {
    [CmdletBinding()]
    param()

    # --- Апаратне забезпечення ---
    try {
        $cpuInfo = Get-AuditObject -ClassName 'Win32_Processor' -First
        $computerSystemInfo = Get-AuditObject -ClassName 'Win32_ComputerSystem' -First
        $osInfo = Get-AuditObject -ClassName 'Win32_OperatingSystem' -First

        $script:Report.Hardware.ComputerSystem.Manufacturer = $computerSystemInfo.Manufacturer
        $script:Report.Hardware.ComputerSystem.Model = $computerSystemInfo.Model
        $script:Report.Hardware.ComputerSystem.Domain = $computerSystemInfo.Domain
        $script:Report.Hardware.ComputerSystem.TotalPhysicalMemoryGB = [Math]::Round($computerSystemInfo.TotalPhysicalMemory / 1GB, 2)

        $script:Report.Hardware.CPU.Name = ($cpuInfo.Name | ForEach-Object { $_.Trim() })
        $script:Report.Hardware.CPU.Cores = $cpuInfo.NumberOfCores
        $script:Report.Hardware.CPU.LogicalProcessors = $cpuInfo.NumberOfLogicalProcessors
        $script:Report.Hardware.CPU.MaxClockSpeedMHz = $cpuInfo.MaxClockSpeed

        # LoadPercentage — опціональна властивість WMI, на частині VM (особливо
        # одразу після старту) повертає $null. Це очікуваний, не помилковий стан
        # (не CollectionError) — трапляється регулярно на щойно піднятих VM,
        # включно з CI-раннерами, і не мало б штрафувати Health Score чи ламати
        # інваріант "CollectionErrors=0" в EndToEnd-тесті на кожному такому
        # прогоні. [Math]::Round($null) мовчки стає 0 — залишаємо цю поведінку,
        # 0% тут означає "невідомо", а не підтверджений нуль.
        $cpuLoadAverage = ($cpuInfo.LoadPercentage | Measure-Object -Average).Average
        if ($null -ne $cpuLoadAverage) {
            $script:Report.Hardware.CPU.LoadPercent = [Math]::Round($cpuLoadAverage)
        }

        $totalPhysicalMemoryGB = [Math]::Round($computerSystemInfo.TotalPhysicalMemory / 1GB, 2)
        $script:Report.Hardware.RAM.TotalGB = $totalPhysicalMemoryGB
        $script:Report.Hardware.RAM.Source = 'Win32_OperatingSystem.TotalVisibleMemorySize/FreePhysicalMemory'

        if ($osInfo.TotalVisibleMemorySize -gt 0) {
            $totalVisibleMemoryGB = [Math]::Round(($osInfo.TotalVisibleMemorySize * 1KB) / 1GB, 2)
            $freeMemoryGB = [Math]::Round(($osInfo.FreePhysicalMemory * 1KB) / 1GB, 2)
            $usedMemoryGB = [Math]::Round(($totalVisibleMemoryGB - $freeMemoryGB), 2)
            $usedPercent = [Math]::Round((($totalVisibleMemoryGB - $freeMemoryGB) / $totalVisibleMemoryGB) * 100, 2)

            if ($usedMemoryGB -lt 0) { $usedMemoryGB = 0 }
            if ($usedPercent -lt 0) { $usedPercent = 0 }
            if ($usedPercent -gt 100) { $usedPercent = 100 }

            $script:Report.Hardware.RAM.TotalVisibleMemoryGB = $totalVisibleMemoryGB
            $script:Report.Hardware.RAM.FreeGB = $freeMemoryGB
            $script:Report.Hardware.RAM.UsedGB = $usedMemoryGB
            $script:Report.Hardware.RAM.UsedPercent = $usedPercent
        }

        $hardwareThresholds = Get-BravoHardwareThresholds

        $script:Report.Dashboard.Metrics.CPU.Value = "$($script:Report.Hardware.CPU.LoadPercent)%"
        $script:Report.Dashboard.Metrics.CPU.Details = "$($script:Report.Hardware.CPU.Cores) ядер / $($script:Report.Hardware.CPU.LogicalProcessors) потоків"
        $script:Report.Dashboard.Metrics.CPU.Status = if ($script:Report.Hardware.CPU.LoadPercent -ge $hardwareThresholds.CpuCriticalPercent) { 'CRITICAL' } elseif ($script:Report.Hardware.CPU.LoadPercent -ge $hardwareThresholds.CpuWarningPercent) { 'WARNING' } else { 'OK' }

        $script:Report.Dashboard.Metrics.RAM.Value = "$($script:Report.Hardware.RAM.UsedPercent)%"
        $script:Report.Dashboard.Metrics.RAM.Details = "$($script:Report.Hardware.RAM.UsedGB) GB використано з $($script:Report.Hardware.RAM.TotalVisibleMemoryGB) GB"
        $script:Report.Dashboard.Metrics.RAM.Status = if ($script:Report.Hardware.RAM.UsedPercent -ge $hardwareThresholds.RamCriticalPercent) { 'CRITICAL' } elseif ($script:Report.Hardware.RAM.UsedPercent -ge $hardwareThresholds.RamWarningPercent) { 'WARNING' } else { 'OK' }

        # CPU LoadPercent буває $null (щойно піднята VM — див. коментар вище,
        # це не помилка), тож findings пишемо лише коли значення реально відоме.
        if ($null -ne $script:Report.Hardware.CPU.LoadPercent) {
            if ($script:Report.Hardware.CPU.LoadPercent -ge $hardwareThresholds.CpuCriticalPercent) {
                Add-AuditFinding -Severity 'CRITICAL' -Category 'Hardware.CPU' -Message "Завантаження CPU критично високе: $($script:Report.Hardware.CPU.LoadPercent)%." -Recommendation 'Перевірте процеси з найбільшим споживанням CPU (Processes.TopCPU) — можливий runaway-процес або недостатня продуктивність для навантаження.'
            } elseif ($script:Report.Hardware.CPU.LoadPercent -ge $hardwareThresholds.CpuWarningPercent) {
                Add-AuditFinding -Severity 'WARNING' -Category 'Hardware.CPU' -Message "Завантаження CPU підвищене: $($script:Report.Hardware.CPU.LoadPercent)%." -Recommendation 'Спостерігайте за динамікою навантаження CPU, за потреби перевірте Processes.TopCPU.'
            }
        }

        if ($script:Report.Hardware.RAM.UsedPercent -ge $hardwareThresholds.RamCriticalPercent) {
            Add-AuditFinding -Severity 'CRITICAL' -Category 'Hardware.RAM' -Message "Використання RAM критично високе: $($script:Report.Hardware.RAM.UsedPercent)% ($($script:Report.Hardware.RAM.UsedGB) GB з $($script:Report.Hardware.RAM.TotalVisibleMemoryGB) GB)." -Recommendation 'Перевірте процеси з найбільшим споживанням пам''яті (Processes.TopMemory) — можливий memory leak або недостатньо RAM для навантаження.'
        } elseif ($script:Report.Hardware.RAM.UsedPercent -ge $hardwareThresholds.RamWarningPercent) {
            Add-AuditFinding -Severity 'WARNING' -Category 'Hardware.RAM' -Message "Використання RAM підвищене: $($script:Report.Hardware.RAM.UsedPercent)% ($($script:Report.Hardware.RAM.UsedGB) GB з $($script:Report.Hardware.RAM.TotalVisibleMemoryGB) GB)." -Recommendation 'Спостерігайте за динамікою використання RAM, за потреби перевірте Processes.TopMemory.'
        }

        if ($Profile -in @('Full','Deep','Forensic')) {
            try {
                $memoryModules = Get-AuditObject -ClassName 'Win32_PhysicalMemory'
                foreach ($module in $memoryModules) {
                    $script:Report.Hardware.RAM.Modules += [PSCustomObject]@{
                        BankLabel    = $module.BankLabel
                        DeviceLocator = $module.DeviceLocator
                        Manufacturer = $module.Manufacturer
                        PartNumber   = ($module.PartNumber | ForEach-Object { if ($_) { $_.Trim() } })
                        SerialNumber = $module.SerialNumber
                        CapacityGB   = [Math]::Round($module.Capacity / 1GB, 2)
                        SpeedMHz     = $module.Speed
                    }
                }
            } catch {
                Add-AuditError -Section 'Hardware.RAM.Modules' -Message $_.Exception.Message
            }
        }

        Write-Host "  $IconCpu CPU: $($script:Report.Hardware.CPU.Cores) ядер / $($script:Report.Hardware.CPU.LogicalProcessors) потоків ($($script:Report.Hardware.CPU.LoadPercent)%)" -ForegroundColor Green
        Write-Host "  $IconRam RAM: $($script:Report.Hardware.RAM.TotalGB) GB ($($script:Report.Hardware.RAM.UsedPercent)% використано)" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Hardware' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка апаратних даних: $($_.Exception.Message)" -ForegroundColor Red
    }
}