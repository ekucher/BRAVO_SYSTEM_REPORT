# MODULE: 31-Collectors-Hardware.ps1
# Збір базової інформації про апаратне забезпечення: CPU, RAM, ComputerSystem/
# chassis type, Motherboard, GPU.

# Чиста функція: SMBIOS chassis type code (Win32_SystemEnclosure.ChassisTypes)
# -> людяний опис. Повний перелік значно довший (SMBIOS specification,
# System Enclosure or Chassis Types), тут — найпоширеніші коди для робочих
# станцій/ноутбуків/серверів; невідомий код повертається як "Unknown ($code)",
# а не помилка.
function Get-BravoChassisTypeText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [Nullable[int]]$ChassisTypeCode
    )

    if ($null -eq $ChassisTypeCode) { return 'Unknown' }

    $chassisTypeMap = @{
        1 = 'Other'; 2 = 'Unknown'; 3 = 'Desktop'; 4 = 'Low Profile Desktop'
        5 = 'Pizza Box'; 6 = 'Mini Tower'; 7 = 'Tower'; 8 = 'Portable'
        9 = 'Laptop'; 10 = 'Notebook'; 11 = 'Hand Held'; 12 = 'Docking Station'
        13 = 'All in One'; 14 = 'Sub Notebook'; 15 = 'Space-saving'; 16 = 'Lunch Box'
        17 = 'Main System Chassis'; 18 = 'Expansion Chassis'; 19 = 'SubChassis'
        20 = 'Bus Expansion Chassis'; 21 = 'Peripheral Chassis'; 22 = 'Storage Chassis'
        23 = 'Rack Mount Chassis'; 24 = 'Sealed-case PC'; 30 = 'Tablet'
        31 = 'Convertible'; 32 = 'Detachable'
    }

    if ($chassisTypeMap.ContainsKey($ChassisTypeCode)) { return $chassisTypeMap[$ChassisTypeCode] }
    return "Unknown ($ChassisTypeCode)"
}

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

            try {
                $chassisInfo = Get-AuditObject -ClassName 'Win32_SystemEnclosure' -First
                if ($chassisInfo -and $chassisInfo.ChassisTypes -and $chassisInfo.ChassisTypes.Count -gt 0) {
                    $chassisTypeCode = [int]$chassisInfo.ChassisTypes[0]
                    $script:Report.Hardware.ComputerSystem.ChassisTypeCode = $chassisTypeCode
                    $script:Report.Hardware.ComputerSystem.ChassisType = Get-BravoChassisTypeText -ChassisTypeCode $chassisTypeCode
                }
            } catch {
                Add-AuditError -Section 'Hardware.ChassisType' -Message $_.Exception.Message
            }

            try {
                $baseBoardInfo = Get-AuditObject -ClassName 'Win32_BaseBoard' -First
                if ($baseBoardInfo) {
                    $script:Report.Hardware.Motherboard.Manufacturer = $baseBoardInfo.Manufacturer
                    $script:Report.Hardware.Motherboard.Product = $baseBoardInfo.Product
                    $script:Report.Hardware.Motherboard.SerialNumber = $baseBoardInfo.SerialNumber
                    $script:Report.Hardware.Motherboard.Version = $baseBoardInfo.Version
                }
            } catch {
                Add-AuditError -Section 'Hardware.Motherboard' -Message $_.Exception.Message
            }

            try {
                $videoControllers = Get-AuditObject -ClassName 'Win32_VideoController'
                foreach ($videoController in $videoControllers) {
                    $script:Report.Hardware.GPU += [PSCustomObject]@{
                        Name           = $videoController.Name
                        # AdapterRAM — 32-bit DWORD у WMI: для карт з >4 GB VRAM
                        # значення переповнюється/спотворюється (відома проблема
                        # Win32_VideoController, не баг цього колектора) —
                        # публікуємо як є, з приміткою в docs, а не намагаємось
                        # "виправити" здогадками.
                        AdapterRAMBytes = $videoController.AdapterRAM
                        DriverVersion  = $videoController.DriverVersion
                        VideoProcessor = $videoController.VideoProcessor
                        CurrentResolution = if ($videoController.CurrentHorizontalResolution -and $videoController.CurrentVerticalResolution) { "$($videoController.CurrentHorizontalResolution)x$($videoController.CurrentVerticalResolution)" } else { '' }
                        Status         = $videoController.Status
                    }
                }
            } catch {
                Add-AuditError -Section 'Hardware.GPU' -Message $_.Exception.Message
            }
        }

        Write-Host "  $IconCpu CPU: $($script:Report.Hardware.CPU.Cores) ядер / $($script:Report.Hardware.CPU.LogicalProcessors) потоків ($($script:Report.Hardware.CPU.LoadPercent)%)" -ForegroundColor Green
        Write-Host "  $IconRam RAM: $($script:Report.Hardware.RAM.TotalGB) GB ($($script:Report.Hardware.RAM.UsedPercent)% використано)" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Hardware' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка апаратних даних: $($_.Exception.Message)" -ForegroundColor Red
    }
}