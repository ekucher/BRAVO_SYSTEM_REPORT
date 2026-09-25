# MODULE: tests/StorageThresholds.Tests.ps1
# Pester-тести для централізованих storage thresholds (P1) з src/32-Collectors-Storage.ps1.
# Get-BravoStorageFreeSpaceSeverity — чиста функція, безпечна для dot-source
# без запуску решти колектора.

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\32-Collectors-Storage.ps1')

    # Get-BravoStorageRiskSummary викликає Add-AuditFinding (визначену в
    # src/90-Main.ps1, який небезпечно dot-source'ити цілком — виконує
    # elevation-логіку на top-level). Легкий локальний stub з тим самим
    # сигнатурним контрактом, щоб перехоплювати виклики без побічних ефектів.
    function Add-AuditFinding {
        param(
            [string]$Severity,
            [string]$Category,
            [string]$Message,
            [string]$Recommendation = ''
        )
        $script:CapturedFindings += [PSCustomObject]@{
            Severity = $Severity
            Category = $Category
            Message  = $Message
        }
    }
}

Describe 'Get-BravoStorageThresholds' {
    It 'повертає узгоджений набір порогів (critical < warning < systemWarning)' {
        $thresholds = Get-BravoStorageThresholds
        $thresholds.CriticalFreePercent | Should -BeLessThan $thresholds.WarningFreePercent
        $thresholds.WarningFreePercent | Should -BeLessThan $thresholds.SystemWarningFreePercent
    }
}

Describe 'Get-BravoStorageFreeSpaceSeverity' {
    It 'позначає том нижче critical-порогу як Critical' {
        Get-BravoStorageFreeSpaceSeverity -FreePercent 3 | Should -Be 'Critical'
    }

    It 'позначає том між critical і warning порогами як Warning' {
        Get-BravoStorageFreeSpaceSeverity -FreePercent 8 | Should -Be 'Warning'
    }

    It 'позначає системний том між warning і systemWarning порогами як SystemWarning' {
        Get-BravoStorageFreeSpaceSeverity -FreePercent 12 -IsSystemDrive $true | Should -Be 'SystemWarning'
    }

    It 'НЕ позначає несистемний том між warning і systemWarning порогами (Healthy)' {
        Get-BravoStorageFreeSpaceSeverity -FreePercent 12 -IsSystemDrive $false | Should -Be 'Healthy'
    }

    It 'позначає том вище всіх порогів як Healthy' {
        Get-BravoStorageFreeSpaceSeverity -FreePercent 50 | Should -Be 'Healthy'
    }

    It 'CD-ROM/оптичний том завжди Healthy, незалежно від FreePercent' {
        Get-BravoStorageFreeSpaceSeverity -FreePercent 0 -DriveType 'CD-ROM' | Should -Be 'Healthy'
    }

    It 'повертає Unknown, якщо FreePercent відсутній' {
        Get-BravoStorageFreeSpaceSeverity -FreePercent $null | Should -Be 'Unknown'
    }
}

Describe 'Get-BravoStorageRiskSummary' {
    BeforeEach {
        $script:CapturedFindings = @()
    }

    It 'EFI System Partition без літери диска (PartitionType=System) НЕ породжує Critical/Warning finding, навіть при 5.98% вільного' {
        $storageDeep = [PSCustomObject]@{
            Volumes = @(
                [PSCustomObject]@{
                    DriveLetter = $null
                    FileSystemLabel = ''
                    FileSystem = 'FAT32'
                    DriveType = 'Fixed'
                    HealthStatus = 'Healthy'
                    SizeGB = 0.88
                    FreeGB = 0.05
                    FreePercent = 5.98
                    PartitionType = 'System'
                }
            )
        }

        $risk = Get-BravoStorageRiskSummary -StorageDeep $storageDeep

        $risk.Summary.CriticalCount | Should -Be 0
        $risk.Summary.WarningCount | Should -Be 0
        $risk.Summary.ReservedCount | Should -Be 1
        @($risk.ReservedVolumes).Count | Should -Be 1
        @($script:CapturedFindings).Count | Should -Be 0
    }

    It 'WinRE Partition без літери диска (PartitionType=Recovery) НЕ породжує Critical/Warning finding' {
        $storageDeep = [PSCustomObject]@{
            Volumes = @(
                [PSCustomObject]@{
                    DriveLetter = $null
                    FileSystemLabel = ''
                    FileSystem = 'NTFS'
                    DriveType = 'Fixed'
                    HealthStatus = 'Healthy'
                    SizeGB = 0.75
                    FreeGB = 0.03
                    FreePercent = 4.0
                    PartitionType = 'Recovery'
                }
            )
        }

        $risk = Get-BravoStorageRiskSummary -StorageDeep $storageDeep

        $risk.Summary.CriticalCount | Should -Be 0
        $risk.Summary.WarningCount | Should -Be 0
        $risk.Summary.ReservedCount | Should -Be 1
        @($script:CapturedFindings).Count | Should -Be 0
    }

    It 'folder-mounted NTFS том без літери диска (PartitionType=Basic, 4% вільно) ДАЛІ породжує Critical finding — не Reserved' {
        $storageDeep = [PSCustomObject]@{
            Volumes = @(
                [PSCustomObject]@{
                    DriveLetter = $null
                    FileSystemLabel = 'PostgreSQL'
                    FileSystem = 'NTFS'
                    DriveType = 'Fixed'
                    HealthStatus = 'Healthy'
                    SizeGB = 500
                    FreeGB = 20
                    FreePercent = 4.0
                    PartitionType = 'Basic'
                }
            )
        }

        $risk = Get-BravoStorageRiskSummary -StorageDeep $storageDeep

        $risk.Summary.CriticalCount | Should -Be 1
        $risk.Summary.ReservedCount | Should -Be 0
        @($risk.ReservedVolumes).Count | Should -Be 0
    }

    It 'folder-mounted ReFS том без літери диска (PartitionType=Basic, 8% вільно) ДАЛІ породжує Warning finding — не Reserved' {
        $storageDeep = [PSCustomObject]@{
            Volumes = @(
                [PSCustomObject]@{
                    DriveLetter = $null
                    FileSystemLabel = 'Backups'
                    FileSystem = 'ReFS'
                    DriveType = 'Fixed'
                    HealthStatus = 'Healthy'
                    SizeGB = 1000
                    FreeGB = 80
                    FreePercent = 8.0
                    PartitionType = 'Basic'
                }
            )
        }

        $risk = Get-BravoStorageRiskSummary -StorageDeep $storageDeep

        $risk.Summary.WarningCount | Should -Be 1
        $risk.Summary.ReservedCount | Should -Be 0
    }

    It 'folder-mounted NTFS том без літери диска, здоровий (PartitionType="", невідомо) потрапляє в Healthy — не Reserved' {
        $storageDeep = [PSCustomObject]@{
            Volumes = @(
                [PSCustomObject]@{
                    DriveLetter = $null
                    FileSystemLabel = 'Archive'
                    FileSystem = 'NTFS'
                    DriveType = 'Fixed'
                    HealthStatus = 'Healthy'
                    SizeGB = 2000
                    FreeGB = 1000
                    FreePercent = 50.0
                    PartitionType = ''
                }
            )
        }

        $risk = Get-BravoStorageRiskSummary -StorageDeep $storageDeep

        $risk.Summary.ReservedCount | Should -Be 0
        @($risk.HealthyVolumes).Count | Should -Be 1
    }

    It 'некорельований том без літери (PartitionType="", 4% вільно) НЕ породжує Critical — INFO Storage.UnknownVolume + виключення з capacity-аналізу (v0.6.1 acceptance-review)' {
        $storageDeep = [PSCustomObject]@{
            Volumes = @(
                [PSCustomObject]@{
                    DriveLetter = $null
                    FileSystemLabel = ''
                    FileSystem = 'NTFS'
                    DriveType = 'Fixed'
                    HealthStatus = 'Healthy'
                    SizeGB = 1.0
                    FreeGB = 0.04
                    FreePercent = 4.0
                    PartitionType = ''
                }
            )
        }

        $risk = Get-BravoStorageRiskSummary -StorageDeep $storageDeep

        $risk.Summary.CriticalCount | Should -Be 0
        $risk.Summary.WarningCount | Should -Be 0
        $risk.Summary.ReservedCount | Should -Be 1
        @($script:CapturedFindings | Where-Object { $_.Severity -eq 'CRITICAL' }).Count | Should -Be 0
        $unknownFindings = @($script:CapturedFindings | Where-Object { $_.Category -eq 'Storage.UnknownVolume' })
        $unknownFindings.Count | Should -Be 1
        $unknownFindings[0].Severity | Should -Be 'INFO'
    }

    It 'некорельований том без літери (PartitionType="Unknown", 8% вільно) — та сама поведінка: без Warning, INFO + Reserved' {
        $storageDeep = [PSCustomObject]@{
            Volumes = @(
                [PSCustomObject]@{
                    DriveLetter = $null
                    FileSystemLabel = ''
                    FileSystem = ''
                    DriveType = 'Fixed'
                    HealthStatus = 'Healthy'
                    SizeGB = 0.75
                    FreeGB = 0.06
                    FreePercent = 8.0
                    PartitionType = 'Unknown'
                }
            )
        }

        $risk = Get-BravoStorageRiskSummary -StorageDeep $storageDeep

        $risk.Summary.WarningCount | Should -Be 0
        $risk.Summary.ReservedCount | Should -Be 1
        @($script:CapturedFindings | Where-Object { $_.Category -eq 'Storage.UnknownVolume' }).Count | Should -Be 1
    }

    It 'звичайний том З літерою диска (C:, 4% вільно) ДАЛІ породжує Critical finding — canonical thresholds не зламані' {
        $storageDeep = [PSCustomObject]@{
            Volumes = @(
                [PSCustomObject]@{
                    DriveLetter = 'C'
                    FileSystemLabel = 'System'
                    FileSystem = 'NTFS'
                    DriveType = 'Fixed'
                    HealthStatus = 'Healthy'
                    SizeGB = 500
                    FreeGB = 20
                    FreePercent = 4.0
                    PartitionType = 'Basic'
                }
            )
        }

        $risk = Get-BravoStorageRiskSummary -StorageDeep $storageDeep

        $risk.Summary.CriticalCount | Should -Be 1
        @($script:CapturedFindings | Where-Object { $_.Severity -eq 'CRITICAL' -and $_.Category -eq 'Storage.FreeSpace' }).Count | Should -Be 1
    }

    It 'том З літерою диска і тим самим % вільного місця ДАЛІ породжує Warning finding' {
        $storageDeep = [PSCustomObject]@{
            Volumes = @(
                [PSCustomObject]@{
                    DriveLetter = 'D'
                    FileSystemLabel = 'DATA'
                    FileSystem = 'NTFS'
                    DriveType = 'Fixed'
                    HealthStatus = 'Healthy'
                    SizeGB = 1863
                    FreeGB = 84.21
                    FreePercent = 5.98
                }
            )
        }

        $risk = Get-BravoStorageRiskSummary -StorageDeep $storageDeep

        $risk.Summary.WarningCount | Should -Be 1
        $risk.Summary.ReservedCount | Should -Be 0
        @($script:CapturedFindings).Count | Should -Be 1
        $script:CapturedFindings[0].Category | Should -Be 'Storage.FreeSpace'
    }

    It 'зарезервований том (PartitionType=System) ІЗ достатнім вільним місцем також потрапляє у ReservedVolumes, а не HealthyVolumes' {
        $storageDeep = [PSCustomObject]@{
            Volumes = @(
                [PSCustomObject]@{
                    DriveLetter = $null
                    FileSystemLabel = ''
                    FileSystem = 'FAT32'
                    DriveType = 'Fixed'
                    HealthStatus = 'Healthy'
                    SizeGB = 0.09
                    FreeGB = 0.06
                    FreePercent = 63.93
                    PartitionType = 'System'
                }
            )
        }

        $risk = Get-BravoStorageRiskSummary -StorageDeep $storageDeep

        $risk.Summary.ReservedCount | Should -Be 1
        $risk.Summary.HealthyCount | Should -Be 0
    }
}

Describe 'Resolve-BravoPartitionType (канонічна класифікація партицій, v0.6.1 acceptance-review)' {
    It 'GPT EFI System GUID -> System (незалежно від Type)' {
        Resolve-BravoPartitionType -Type 'Unknown' -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' | Should -Be 'System'
    }

    It 'GPT MSR GUID -> Reserved' {
        Resolve-BravoPartitionType -Type '' -GptType 'e3c9e316-0b5c-4db8-817d-f92df00215ae' | Should -Be 'Reserved'
    }

    It 'GPT Recovery GUID -> Recovery (upper-case GUID теж матчиться)' {
        Resolve-BravoPartitionType -Type 'Unknown' -GptType '{DE94BBA4-06D1-4D40-A16A-BFD50179D6AC}' | Should -Be 'Recovery'
    }

    It 'MBR WinRE (MbrType=39, десяткова форма Get-Partition) -> Recovery, навіть коли Type=IFS' {
        Resolve-BravoPartitionType -Type 'IFS' -MbrType 39 | Should -Be 'Recovery'
    }

    It 'MBR WinRE у hex-формі (0x27) -> Recovery' {
        Resolve-BravoPartitionType -Type 'Unknown' -MbrType '0x27' | Should -Be 'Recovery'
    }

    It 'IsSystem=true без GPT/MBR-збігу -> System (явна системна партиція не стає data-томом)' {
        Resolve-BravoPartitionType -Type 'IFS' -MbrType 7 -IsSystem $true | Should -Be 'System'
    }

    It 'GPT basic-data + Type=Basic -> Basic (data-том, НЕ Reserved)' {
        Resolve-BravoPartitionType -Type 'Basic' -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}' | Should -Be 'Basic'
    }

    It 'MBR IFS data-партиція (MbrType=7) без IsSystem -> IFS (passthrough, НЕ Recovery)' {
        Resolve-BravoPartitionType -Type 'IFS' -MbrType 7 | Should -Be 'IFS'
    }

    It 'порожні входи -> Unknown' {
        Resolve-BravoPartitionType -Type '' -GptType '' -MbrType $null -IsSystem $null | Should -Be 'Unknown'
    }

    It 'null-и не ламають функцію (кореляція без даних) -> Unknown' {
        Resolve-BravoPartitionType | Should -Be 'Unknown'
    }
}
