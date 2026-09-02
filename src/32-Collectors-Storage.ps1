# MODULE: 32-Collectors-Storage.ps1
# Збір інформації про диски, Storage Deep Audit та storage-ризики.

# --- P1: централізовані storage thresholds ---
# Єдине джерело порогів вільного місця для basic (Get-BravoStorageAudit)
# і deep (Get-BravoStorageRiskSummary) audit — щоб обидва шляхи узгоджено
# оцінювали один і той самий том і не породжували суперечливих findings.
function Get-BravoStorageThresholds {
    [CmdletBinding()]
    param()

    return [ordered]@{
        CriticalFreePercent      = 5
        WarningFreePercent       = 10
        SystemWarningFreePercent = 15
    }
}

# Чиста функція без побічних ефектів: за відсотком вільного місця повертає
# рівень ризику тому. CD-ROM/оптичні носії завжди 'Healthy' (read-only,
# "вільне місце" не є показником ризику — примонтований ISO завжди 0%).
function Get-BravoStorageFreeSpaceSeverity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [Nullable[double]]$FreePercent,
        [bool]$IsSystemDrive = $false,
        [string]$DriveType = ''
    )

    if ($null -eq $FreePercent) { return 'Unknown' }
    if ($DriveType -eq 'CD-ROM') { return 'Healthy' }

    $thresholds = Get-BravoStorageThresholds

    if ($FreePercent -lt $thresholds.CriticalFreePercent) { return 'Critical' }
    if ($FreePercent -lt $thresholds.WarningFreePercent) { return 'Warning' }
    if ($IsSystemDrive -and $FreePercent -lt $thresholds.SystemWarningFreePercent) { return 'SystemWarning' }

    return 'Healthy'
}

function Convert-BravoBytesToGB {
    param([Parameter(Mandatory = $false)]$Bytes)

    if ($null -eq $Bytes -or $Bytes -eq '') {
        return $null
    }

    try {
        return [Math]::Round(([double]$Bytes / 1GB), 2)
    } catch {
        return $null
    }
}

function Get-BravoStorageDeepAudit {
    # Заповнюються нижче в цій функції: CollectedAt, LogicalDisks, Volumes,
    # Disks, Partitions, PageFiles, BitLocker, ShadowCopies, StoragePools,
    # ReliabilityCounters, SmartPredictFailures (обидва — SMART/NVMe health,
    # можуть лишатись порожніми, якщо апаратура/драйвер не підтримує).
    #
    # НЕ реалізовано (завжди порожній масив @() — не заплановано окремо,
    # PhysicalDisks тут дублювало б $script:Report.Hardware.Disks.PhysicalDisks
    # — це різні поля з однаковою назвою в різних секціях моделі):
    # PhysicalDisks, StorageSubsystems.
    $storage = [ordered]@{
        CollectedAt  = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        LogicalDisks = @()
        Volumes      = @()
        Disks        = @()
        Partitions            = @()
        PhysicalDisks         = @()
        ReliabilityCounters   = @()
        BitLocker             = @()
        ShadowCopies          = @()
        StoragePools          = @()
        StorageSubsystems     = @()
        SmartPredictFailures  = @()
        PageFiles             = @()
    }

    try {
        $logicalDisks = Get-AuditObject -ClassName 'Win32_LogicalDisk' -Filter 'DriveType=3'
        foreach ($disk in $logicalDisks) {
            $freePercent = if ($disk.Size -gt 0) {
                [Math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)
            } else {
                $null
            }

            $storage.LogicalDisks += [PSCustomObject]@{
                DeviceID    = $disk.DeviceID
                VolumeName  = $disk.VolumeName
                FileSystem  = $disk.FileSystem
                TotalGB     = Convert-BravoBytesToGB $disk.Size
                FreeGB      = Convert-BravoBytesToGB $disk.FreeSpace
                FreePercent = $freePercent
                Compressed  = $disk.Compressed
            }
        }
    } catch {
        Add-AuditError -Section 'StorageDeep.LogicalDisks' -Message $_.Exception.Message
    }

    if (Get-Command Get-Volume -ErrorAction SilentlyContinue) {
        try {
            $volumes = Get-Volume -ErrorAction Stop
            foreach ($volume in $volumes) {
                $freePercent = if ($volume.Size -gt 0) {
                    [Math]::Round(($volume.SizeRemaining / $volume.Size) * 100, 2)
                } else {
                    $null
                }

                $storage.Volumes += [PSCustomObject]@{
                    DriveLetter       = $volume.DriveLetter
                    FileSystemLabel   = $volume.FileSystemLabel
                    FileSystem        = $volume.FileSystem
                    DriveType         = [string]$volume.DriveType
                    HealthStatus      = [string]$volume.HealthStatus
                    OperationalStatus = ($volume.OperationalStatus -join ', ')
                    SizeGB            = Convert-BravoBytesToGB $volume.Size
                    FreeGB            = Convert-BravoBytesToGB $volume.SizeRemaining
                    FreePercent       = $freePercent
                }

                if ($volume.HealthStatus -and [string]$volume.HealthStatus -notin @('Healthy','Unknown')) {
                    Add-AuditFinding -Severity 'WARNING' -Category 'Storage' -Message "Том $($volume.DriveLetter): HealthStatus=$($volume.HealthStatus)" -Recommendation 'Перевірте стан тому через Get-Volume, Event Viewer та інструменти виробника диска.'
                }
            }
        } catch {
            Add-AuditError -Section 'StorageDeep.GetVolume' -Message $_.Exception.Message
        }
    }

    if (Get-Command Get-Disk -ErrorAction SilentlyContinue) {
        try {
            $disks = Get-Disk -ErrorAction Stop
            foreach ($disk in $disks) {
                $storage.Disks += [PSCustomObject]@{
                    Number            = $disk.Number
                    FriendlyName      = $disk.FriendlyName
                    SerialNumber      = $disk.SerialNumber
                    BusType           = [string]$disk.BusType
                    MediaType         = [string]$disk.MediaType
                    PartitionStyle    = [string]$disk.PartitionStyle
                    OperationalStatus = ($disk.OperationalStatus -join ', ')
                    HealthStatus      = [string]$disk.HealthStatus
                    IsBoot            = $disk.IsBoot
                    IsSystem          = $disk.IsSystem
                    IsOffline         = $disk.IsOffline
                    IsReadOnly        = $disk.IsReadOnly
                    SizeGB            = Convert-BravoBytesToGB $disk.Size
                }

                if ($disk.IsOffline -or $disk.IsReadOnly) {
                    Add-AuditFinding -Severity 'CRITICAL' -Category 'Storage' -Message "Disk $($disk.Number): IsOffline=$($disk.IsOffline), IsReadOnly=$($disk.IsReadOnly)" -Recommendation 'Перевірте Get-Disk, diskpart, SAN policy, стан носія та контролер.'
                }

                if ($disk.HealthStatus -and [string]$disk.HealthStatus -notin @('Healthy','Unknown')) {
                    Add-AuditFinding -Severity 'CRITICAL' -Category 'Storage' -Message "Disk $($disk.Number): HealthStatus=$($disk.HealthStatus)" -Recommendation 'Негайно перевірте SMART, журнали та резервні копії.'
                }
            }
        } catch {
            Add-AuditError -Section 'StorageDeep.GetDisk' -Message $_.Exception.Message
        }
    }


    if (Get-Command Get-Partition -ErrorAction SilentlyContinue) {
        try {
            $partitions = Get-Partition -ErrorAction Stop
            foreach ($partition in $partitions) {
                $storage.Partitions += [PSCustomObject]@{
                    DiskNumber      = $partition.DiskNumber
                    PartitionNumber = $partition.PartitionNumber
                    DriveLetter     = $partition.DriveLetter
                    Type            = [string]$partition.Type
                    GptType         = [string]$partition.GptType
                    MbrType         = [string]$partition.MbrType
                    IsActive        = $partition.IsActive
                    IsBoot          = $partition.IsBoot
                    IsSystem        = $partition.IsSystem
                    IsHidden        = $partition.IsHidden
                    IsReadOnly      = $partition.IsReadOnly
                    OffsetGB        = Convert-BravoBytesToGB $partition.Offset
                    SizeGB          = Convert-BravoBytesToGB $partition.Size
                }
            }
        } catch {
            Add-AuditError -Section 'StorageDeep.GetPartition' -Message $_.Exception.Message
        }
    }

    if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
        try {
            $bitlockerVolumes = Get-BitLockerVolume -ErrorAction Stop
            foreach ($volume in $bitlockerVolumes) {
                $storage.BitLocker += [PSCustomObject]@{
                    MountPoint           = $volume.MountPoint
                    VolumeType           = [string]$volume.VolumeType
                    CapacityGB           = if ($null -ne $volume.CapacityGB) { [Math]::Round($volume.CapacityGB, 2) } else { $null }
                    VolumeStatus         = [string]$volume.VolumeStatus
                    EncryptionPercentage = $volume.EncryptionPercentage
                    EncryptionMethod     = [string]$volume.EncryptionMethod
                    ProtectionStatus     = [string]$volume.ProtectionStatus
                    LockStatus           = [string]$volume.LockStatus
                    AutoUnlockEnabled    = $volume.AutoUnlockEnabled
                }

                # Незашифрований системний том — окрема, свідомо вужча знахідка:
                # відсутність BitLocker на data-томах занадто поширена на
                # звичайних робочих станціях, щоб бути WARNING на кожному
                # прогоні (той самий принцип, що й з WinRE/EFI-розділами
                # раніше в цій сесії); системний том — інша вага ризику.
                if ($volume.VolumeType -eq 'OperatingSystem' -and [string]$volume.ProtectionStatus -eq 'Off') {
                    # INFO, не WARNING: відсутність BitLocker на системному
                    # томі — поширений і часто свідомий вибір (dev-машини,
                    # десктопи без фізичного ризику крадіжки, альтернативне
                    # шифрування) — не впливає на Health Score/Status, лише
                    # фіксується в звіті як факт стану (той самий принцип, що
                    # й Secure Boot/TPM: "не є помилкою", лише публікація стану).
                    Add-AuditFinding -Severity 'INFO' -Category 'Storage.BitLocker' -Message "Системний том $($volume.MountPoint) не захищений BitLocker (ProtectionStatus=Off)." -Recommendation 'Розгляньте увімкнення BitLocker для системного тому, особливо на портативних пристроях.'
                }
            }
        } catch {
            # Get-BitLockerVolume вимагає прав адміністратора й може падати з
            # access denied на непідвищеній сесії — не помилка збору per se,
            # оскільки решта Deep Audit продовжує працювати; фіксуємо окремо.
            Add-AuditError -Section 'StorageDeep.BitLocker' -Message $_.Exception.Message
        }
    }
    # BitLocker-модуль не встановлено (напр. Windows Home edition, деякі
    # Server Core збірки без feature BitLocker) — $storage.BitLocker
    # лишається порожнім масивом, це штатний стан машини, не помилка.

    try {
        $pageFiles = Get-AuditObject -ClassName 'Win32_PageFileUsage'
        foreach ($pageFile in $pageFiles) {
            $storage.PageFiles += [PSCustomObject]@{
                Name            = $pageFile.Name
                AllocatedBaseMB = $pageFile.AllocatedBaseSize
                CurrentUsageMB  = $pageFile.CurrentUsage
                PeakUsageMB     = $pageFile.PeakUsage
                InstallDate     = if ($pageFile.InstallDate) {
                    $pageFileInstallDate = Convert-AuditDateTime -Value $pageFile.InstallDate -UseCim:$script:UseCim
                    if ($pageFileInstallDate) { $pageFileInstallDate.ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
                } else {
                    ''
                }
                Status          = $pageFile.Status
            }
        }
    } catch {
        Add-AuditError -Section 'StorageDeep.PageFiles' -Message $_.Exception.Message
    }

    try {
        # Win32_ShadowCopy — точки відновлення VSS (System Restore/File
        # History/backup-софт їх створюють). Порожній масив — штатний стан
        # (VSS вимкнено, немає точок відновлення), не помилка збору.
        $shadowCopies = Get-AuditObject -ClassName 'Win32_ShadowCopy'
        foreach ($shadowCopy in $shadowCopies) {
            $storage.ShadowCopies += [PSCustomObject]@{
                ID                = $shadowCopy.ID
                VolumeName        = $shadowCopy.VolumeName
                InstallDate       = if ($shadowCopy.InstallDate) {
                    $shadowCopyDate = Convert-AuditDateTime -Value $shadowCopy.InstallDate -UseCim:$script:UseCim
                    if ($shadowCopyDate) { $shadowCopyDate.ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
                } else {
                    ''
                }
                ClientAccessible = $shadowCopy.ClientAccessible
                Persistent       = $shadowCopy.Persistent
            }
        }
    } catch {
        # Win32_ShadowCopy-провайдер може бути недоступний (служба VSS
        # вимкнена/недоступна) — фіксуємо як помилку збору, оскільки клас
        # штатно присутній на всіх підтримуваних Windows.
        Add-AuditError -Section 'StorageDeep.ShadowCopies' -Message $_.Exception.Message
    }

    if (Get-Command Get-StoragePool -ErrorAction SilentlyContinue) {
        try {
            # IsPrimordial=$true — це прихований "сирий" пул, що представляє
            # фізичні диски системи саму по собі, не реальний Storage Spaces
            # пул, створений користувачем; виключаємо як шум без цінності
            # (той самий принцип, що й Unreachable/Incomplete у ARP-кеші).
            $storagePools = Get-StoragePool -ErrorAction Stop | Where-Object { -not $_.IsPrimordial }
            foreach ($pool in $storagePools) {
                $storage.StoragePools += [PSCustomObject]@{
                    FriendlyName      = $pool.FriendlyName
                    HealthStatus      = [string]$pool.HealthStatus
                    OperationalStatus = [string]$pool.OperationalStatus
                    SizeGB            = Convert-BravoBytesToGB $pool.Size
                    AllocatedGB       = Convert-BravoBytesToGB $pool.AllocatedSize
                    IsReadOnly        = $pool.IsReadOnly
                }

                if ([string]$pool.HealthStatus -notin @('Healthy', '')) {
                    Add-AuditFinding -Severity 'WARNING' -Category 'Storage.StoragePools' -Message "Storage Pool '$($pool.FriendlyName)' має статус HealthStatus=$($pool.HealthStatus)." -Recommendation 'Перевірте стан пулу та фізичних дисків, що входять до нього (Get-PhysicalDisk).'
                }
            }
        } catch {
            Add-AuditError -Section 'StorageDeep.StoragePools' -Message $_.Exception.Message
        }
    }
    # Get-StoragePool відсутній (модуль Storage не встановлено, напр. деякі
    # Server Core/старіші Windows) або Storage Spaces не використовується —
    # $storage.StoragePools лишається порожнім масивом, штатний стан.

    if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
        try {
            $physicalDisksForReliability = Get-PhysicalDisk -ErrorAction Stop
            foreach ($physicalDisk in $physicalDisksForReliability) {
                try {
                    # Get-StorageReliabilityCounter може падати для окремого
                    # диска (напр. USB/віртуальний диск без SMART-контролера) —
                    # обробляємо кожен диск незалежно, один збій не має гасити
                    # решту.
                    $counter = $physicalDisk | Get-StorageReliabilityCounter -ErrorAction Stop
                    if (-not $counter) { continue }

                    $storage.ReliabilityCounters += [PSCustomObject]@{
                        DeviceId                = $physicalDisk.DeviceId
                        FriendlyName             = $physicalDisk.FriendlyName
                        MediaType                = [string]$physicalDisk.MediaType
                        TemperatureCelsius       = $counter.Temperature
                        TemperatureMaxCelsius    = $counter.TemperatureMax
                        WearPercent              = $counter.Wear
                        ReadErrorsTotal          = $counter.ReadErrorsTotal
                        ReadErrorsUncorrected    = $counter.ReadErrorsUncorrected
                        WriteErrorsTotal         = $counter.WriteErrorsTotal
                        WriteErrorsUncorrected   = $counter.WriteErrorsUncorrected
                        PowerOnHours             = $counter.PowerOnHours
                    }

                    # Некориговані помилки читання/запису — однозначний сигнал
                    # апаратної проблеми диска (на відміну від Total, які
                    # включають штатно-скориговані помилки і завжди >0 на
                    # робочому диску). Wear >= 90% — SSD/NVMe близько до
                    # кінця ресурсу за специфікацією виробника.
                    if (($counter.ReadErrorsUncorrected -gt 0) -or ($counter.WriteErrorsUncorrected -gt 0)) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Storage.Reliability' -Message "Диск '$($physicalDisk.FriendlyName)' має некориговані помилки читання/запису (SMART reliability counters)." -Recommendation 'Перевірте стан диска (chkdsk, виробничий diagnostic tool) і за потреби замініть.'
                    }
                    if ($null -ne $counter.Wear -and [double]$counter.Wear -ge 90) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Storage.Reliability' -Message "Диск '$($physicalDisk.FriendlyName)' має Wear=$($counter.Wear)% — близько до кінця ресурсу SSD/NVMe." -Recommendation 'Заплануйте заміну диска та перевірте резервні копії.'
                    }
                } catch {
                    Add-AuditError -Section 'StorageDeep.ReliabilityCounters' -Message $_.Exception.Message
                }
            }
        } catch {
            Add-AuditError -Section 'StorageDeep.ReliabilityCounters' -Message $_.Exception.Message
        }
    }
    # Get-PhysicalDisk/Get-StorageReliabilityCounter відсутні (модуль Storage
    # не встановлено) — $storage.ReliabilityCounters лишається порожнім
    # масивом, штатний стан.

    try {
        # MSStorageDriver_FailurePredictStatus (namespace root\wmi) — легасі
        # SMART predictive-failure API, доступний лише для деяких контролерів
        # (переважно старі ATA/SATA, часто НЕ покриває NVMe чи RAID-контролери
        # з власним драйвером) і вимагає прав адміністратора. Відсутність
        # класу/інстансів — штатний стан для більшості сучасних машин, не
        # помилка збору.
        if ($script:UseCim) {
            $failurePredicts = Get-CimInstance -Namespace 'root\wmi' -ClassName 'MSStorageDriver_FailurePredictStatus' -ErrorAction Stop
        } else {
            $failurePredicts = Get-WmiObject -Namespace 'root\wmi' -Class 'MSStorageDriver_FailurePredictStatus' -ErrorAction Stop
        }

        foreach ($predict in $failurePredicts) {
            $storage.SmartPredictFailures += [PSCustomObject]@{
                InstanceName   = $predict.InstanceName
                PredictFailure = $predict.PredictFailure
                Reason         = $predict.Reason
            }

            if ($predict.PredictFailure) {
                Add-AuditFinding -Severity 'CRITICAL' -Category 'Storage.SMART' -Message "SMART передбачає можливий збій диска '$($predict.InstanceName)' (PredictFailure=True)." -Recommendation 'Негайно створіть резервну копію даних і заплануйте заміну диска.'
            }
        }
    } catch {
        # Клас відсутній у namespace (WMI-провайдер SMART не встановлено/не
        # підтримується контролером) — це не помилка збору, а обмеження
        # апаратної/драйверної підтримки; не фіксуємо Add-AuditError, аби не
        # створювати CollectionErrors на переважній більшості сучасних машин
        # (NVMe/RAID), де цей клас штатно відсутній.
    }

    return [PSCustomObject]$storage
}


# --- BRAVO v0.3.2 Storage Critical Findings ---
function Get-BravoStorageRiskSummary {
    param(
        [Parameter(Mandatory = $true)]
        $StorageDeep
    )

    $thresholds = Get-BravoStorageThresholds
    $criticalThreshold = $thresholds.CriticalFreePercent
    $warningThreshold = $thresholds.WarningFreePercent
    $systemWarningThreshold = $thresholds.SystemWarningFreePercent
    $systemDrive = ($env:SystemDrive -replace ':','').ToUpperInvariant()

    $risk = [ordered]@{
        CollectedAt                = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        CriticalFreePercent        = $criticalThreshold
        WarningFreePercent         = $warningThreshold
        SystemWarningFreePercent   = $systemWarningThreshold
        CriticalVolumes            = @()
        WarningVolumes             = @()
        SystemVolumeWarnings       = @()
        HealthyVolumes             = @()
        ReservedVolumes            = @()
        Summary                    = [ordered]@{
            CriticalCount           = 0
            WarningCount            = 0
            SystemWarningCount      = 0
            HealthyCount            = 0
            ReservedCount           = 0
        }
    }

    if (-not $StorageDeep -or -not $StorageDeep.Volumes) {
        return [PSCustomObject]$risk
    }

    foreach ($volume in @($StorageDeep.Volumes)) {
        $driveLetter = ''
        if ($null -ne $volume.DriveLetter -and [string]$volume.DriveLetter -ne '') {
            $driveLetter = ([string]$volume.DriveLetter).TrimEnd(':').ToUpperInvariant()
        }

        $label = [string]$volume.FileSystemLabel
        $displayName = if ($driveLetter) {
            if ($label) { "$driveLetter`: $label" } else { "$driveLetter`:" }
        } elseif ($label) {
            $label
        } else {
            'Volume без літери'
        }

        $freePercent = $null
        try {
            if ($null -ne $volume.FreePercent -and [string]$volume.FreePercent -ne '') {
                $freePercent = [double]$volume.FreePercent
            }
        } catch {
            $freePercent = $null
        }

        $freeGB = $volume.FreeGB
        $sizeGB = $volume.SizeGB

        $volumeRisk = [PSCustomObject]@{
            DriveLetter  = $driveLetter
            Name         = $displayName
            Label        = $label
            FileSystem   = $volume.FileSystem
            HealthStatus = $volume.HealthStatus
            SizeGB       = $sizeGB
            FreeGB       = $freeGB
            FreePercent  = $freePercent
        }

        if ($null -eq $freePercent) {
            continue
        }

        # CD-ROM/оптичні носії — read-only, "вільне місце" не є показником ризику
        # (наприклад ISO-образ примонтований як том завжди показує 0% вільно).
        if ([string]$volume.DriveType -eq 'CD-ROM') {
            $risk.HealthyVolumes += $volumeRisk
            continue
        }

        # Томи без літери диска (WinRE/EFI System Partition/MSR) — системно-
        # зарезервовані розділи фіксованого розміру, недоступні користувачу
        # через Провідник чи звичайне очищення файлів. WinRE Partition (типово
        # ~0.5-1 GB) майже завжди заповнений на 90%+ образом відновлення — це
        # штатний стан Windows, а не ризик, що потребує дій. Виводити їх у
        # Critical/Warning findings і знижувати Health Score на КОЖНІЙ Windows-
        # машині було б систематичним false positive. Дані про них лишаються
        # видимими в таблиці Storage Deep (без Add-AuditFinding).
        if (-not $driveLetter) {
            $risk.ReservedVolumes += $volumeRisk
            continue
        }

        if ($freePercent -lt $criticalThreshold) {
            $risk.CriticalVolumes += $volumeRisk

            Add-AuditFinding `
                -Severity 'CRITICAL' `
                -Category 'Storage.FreeSpace' `
                -Message ("Том {0} має критично мало вільного місця: {1} GB з {2} GB ({3}%)." -f $displayName, $freeGB, $sizeGB, $freePercent) `
                -Recommendation 'Терміново звільніть місце або розширте том. Для VM/backup/workload томів перевірте snapshots, ISO, тимчасові файли, кеші, старі архіви та дублікати.'

            continue
        }

        if ($freePercent -lt $warningThreshold) {
            $risk.WarningVolumes += $volumeRisk

            Add-AuditFinding `
                -Severity 'WARNING' `
                -Category 'Storage.FreeSpace' `
                -Message ("Том {0} має мало вільного місця: {1} GB з {2} GB ({3}%)." -f $displayName, $freeGB, $sizeGB, $freePercent) `
                -Recommendation 'Заплануйте очищення або розширення тому, щоб уникнути переходу в критичний стан.'

            continue
        }

        if ($driveLetter -eq $systemDrive -and $freePercent -lt $systemWarningThreshold) {
            $risk.SystemVolumeWarnings += $volumeRisk

            Add-AuditFinding `
                -Severity 'WARNING' `
                -Category 'Storage.SystemDrive' `
                -Message ("Системний том {0} має менше {1}% вільного місця: {2}%." -f $displayName, $systemWarningThreshold, $freePercent) `
                -Recommendation 'Для системного тому бажано тримати запас вільного місця для оновлень Windows, кешів, crash dumps і тимчасових файлів.'

            continue
        }

        $risk.HealthyVolumes += $volumeRisk
    }

    $risk.Summary.CriticalCount = @($risk.CriticalVolumes).Count
    $risk.Summary.WarningCount = @($risk.WarningVolumes).Count
    $risk.Summary.SystemWarningCount = @($risk.SystemVolumeWarnings).Count
    $risk.Summary.HealthyCount = @($risk.HealthyVolumes).Count
    $risk.Summary.ReservedCount = @($risk.ReservedVolumes).Count

    return [PSCustomObject]$risk
}

function Get-BravoStorageAudit {
    [CmdletBinding()]
    param()

    # --- Диски ---
    try {
        $logicalDiskInfo = Get-AuditObject -ClassName 'Win32_LogicalDisk' -Filter 'DriveType=3'
        $totalSpace = 0
        $totalFree = 0

        # Deep/Forensic профілі нижче в цій же функції запускають
        # Get-BravoStorageRiskSummary, який оцінює ті самі томи з тими самими
        # централізованими порогами (Get-BravoStorageThresholds), але глибше
        # (включно з томами без літери диска й системним порогом). Щоб не
        # породжувати для одного тому два findings різної суворості —
        # basic-прохід у Deep/Forensic суто збирає TotalGB/FreeGB, а рішення
        # про findings делегує risk summary.
        $emitBasicFindings = ($Profile -notin @('Deep','Forensic'))
        $thresholds = Get-BravoStorageThresholds

        foreach ($logicalDisk in $logicalDiskInfo) {
            $totalSpace += [double]$logicalDisk.Size
            $totalFree += [double]$logicalDisk.FreeSpace

            $volume = [PSCustomObject]@{
                DeviceID    = $logicalDisk.DeviceID
                VolumeName  = $logicalDisk.VolumeName
                FileSystem  = $logicalDisk.FileSystem
                TotalGB     = [Math]::Round($logicalDisk.Size / 1GB, 2)
                FreeGB      = [Math]::Round($logicalDisk.FreeSpace / 1GB, 2)
                FreePercent = if ($logicalDisk.Size -gt 0) { [Math]::Round(($logicalDisk.FreeSpace / $logicalDisk.Size) * 100, 2) } else { 0 }
            }
            $script:Report.Hardware.Disks.Volumes += $volume

            if ($emitBasicFindings) {
                if ($volume.FreePercent -lt $thresholds.CriticalFreePercent) {
                    Add-AuditFinding -Severity 'CRITICAL' -Category 'Storage.FreeSpace' -Message "На диску $($volume.DeviceID) менше $($thresholds.CriticalFreePercent)% вільного місця: $($volume.FreePercent)%" -Recommendation 'Звільніть місце або розширте том.'
                } elseif ($volume.FreePercent -lt $thresholds.WarningFreePercent) {
                    Add-AuditFinding -Severity 'WARNING' -Category 'Storage.FreeSpace' -Message "На диску $($volume.DeviceID) менше $($thresholds.WarningFreePercent)% вільного місця: $($volume.FreePercent)%" -Recommendation 'Перевірте темп росту даних і заплануйте очищення.'
                }
            }
        }

        if ($totalSpace -gt 0) {
            $script:Report.Hardware.Disks.TotalGB = [Math]::Round($totalSpace / 1GB, 2)
            $script:Report.Hardware.Disks.FreeGB = [Math]::Round($totalFree / 1GB, 2)
            $script:Report.Hardware.Disks.FreePercent = [Math]::Round(($totalFree / $totalSpace) * 100, 2)
        }

        if ($Profile -in @('Full','Deep','Forensic')) {
            try {
                $physicalDisks = Get-AuditObject -ClassName 'Win32_DiskDrive'
                foreach ($physicalDisk in $physicalDisks) {
                    $script:Report.Hardware.Disks.PhysicalDisks += [PSCustomObject]@{
                        Model        = $physicalDisk.Model
                        SerialNumber = $physicalDisk.SerialNumber
                        Interface    = $physicalDisk.InterfaceType
                        MediaType    = $physicalDisk.MediaType
                        SizeGB       = [Math]::Round($physicalDisk.Size / 1GB, 2)
                        Status       = $physicalDisk.Status
                    }
                }
            } catch {
                Add-AuditError -Section 'Storage.PhysicalDisks' -Message $_.Exception.Message
            }
        }

        Write-Host "  $IconDisk Диски: $(Format-Size $script:Report.Hardware.Disks.FreeGB) вільно ($($script:Report.Hardware.Disks.FreePercent)%)" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Storage' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка збору дисків: $($_.Exception.Message)" -ForegroundColor Red
    }


    # --- BRAVO v0.3.0 Storage Deep Audit Skeleton ---
    if ($Profile -in @('Deep','Forensic')) {
        try {
            Write-Host "  [INFO] Storage Deep Audit: збір базових storage-даних..."

            $storageDeep = Get-BravoStorageDeepAudit

            if ($script:Report.Hardware.Disks -is [System.Collections.IDictionary]) {
                $script:Report.Hardware.Disks['Deep'] = $storageDeep
            } else {
                $script:Report.Hardware.Disks | Add-Member -MemberType NoteProperty -Name 'Deep' -Value $storageDeep -Force
            }

            Write-Host ("  [OK] Storage Deep Audit: logicalDisks={0}, volumes={1}, disks={2}" -f @($storageDeep.LogicalDisks).Count, @($storageDeep.Volumes).Count, @($storageDeep.Disks).Count)
            $storageRisk = Get-BravoStorageRiskSummary -StorageDeep $storageDeep

            if ($script:Report.Hardware.Disks -is [System.Collections.IDictionary]) {
                $script:Report.Hardware.Disks['StorageRisk'] = $storageRisk
            } else {
                $script:Report.Hardware.Disks | Add-Member -MemberType NoteProperty -Name 'StorageRisk' -Value $storageRisk -Force
            }

            Write-Host ("  [OK] Storage Risk: critical={0}, warning={1}, systemWarning={2}, healthy={3}" -f $storageRisk.Summary.CriticalCount, $storageRisk.Summary.WarningCount, $storageRisk.Summary.SystemWarningCount, $storageRisk.Summary.HealthyCount)
        } catch {
            Add-AuditError -Section 'StorageDeep' -Message $_.Exception.Message
            Write-Host "  [ERROR] Storage Deep Audit: $($_.Exception.Message)"
        }
    }
}
