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
