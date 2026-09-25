# MODULE: tests/WindowsLifecycle.Tests.ps1
# Table-driven Pester-тести для Get-BravoOsSupportInfo (src/39-Collectors-Updates.ps1)
# та статичної таблиці Get-BravoWindowsLifecycleTable (src/39a-Data-WindowsLifecycle.ps1)
# — Issue #94. Get-BravoOsSupportInfo — чиста функція за даними (лише приймає
# Caption/Build/EditionId/ReferenceDate, повертає result), безпечна для
# dot-source без запуску решти Updates-колектора.
#
# ReferenceDate — injectable параметр (додано цим циклом саме для цього
# issue), тому жоден тест тут не залежить від реального поточного Get-Date:
# усі reference-дати обчислюються відносно відомих дат у самій таблиці
# життєвого циклу, а не від "сьогодні".

BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\39a-Data-WindowsLifecycle.ps1')
    . (Join-Path $PSScriptRoot '..\src\39-Collectors-Updates.ps1')
}

Describe 'Get-BravoWindowsLifecycleTable' {
    It 'повертає непорожню таблицю з обов''язковими полями на кожному рядку' {
        $table = Get-BravoWindowsLifecycleTable
        $table.Count | Should -BeGreaterThan 0
        foreach ($row in $table) {
            $row.Build | Should -BeOfType [int]
            $row.Product | Should -Not -BeNullOrEmpty
            $row.SupportEndConsumer | Should -Not -BeNullOrEmpty
        }
    }

    It 'не містить дублікатів (Build, IsServer)' {
        $table = Get-BravoWindowsLifecycleTable
        $grouped = $table | Group-Object -Property Build, IsServer | Where-Object { $_.Count -gt 1 }
        $grouped | Should -BeNullOrEmpty
    }
}

Describe 'Get-BravoOsSupportInfo — розпізнавання відомих build (client)' {
    It 'Windows 10 22H2 (build 19045)' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 10 Pro' -Build '19045' -ReferenceDate ([datetime]'2025-01-01')
        $r.Product | Should -Be 'Windows 10'
        $r.DisplayVersion | Should -Be '22H2'
    }

    It 'Windows 11 22H2 (build 22621)' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 11 Pro' -Build '22621' -ReferenceDate ([datetime]'2024-01-01')
        $r.Product | Should -Be 'Windows 11'
        $r.DisplayVersion | Should -Be '22H2'
    }

    It 'Windows 11 23H2 (build 22631)' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 11 Pro' -Build '22631' -ReferenceDate ([datetime]'2025-01-01')
        $r.Product | Should -Be 'Windows 11'
        $r.DisplayVersion | Should -Be '23H2'
    }

    It 'Windows 11 24H2 (build 26100, client)' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 11 Pro' -Build '26100' -ReferenceDate ([datetime]'2025-11-01')
        $r.Product | Should -Be 'Windows 11'
        $r.DisplayVersion | Should -Be '24H2'
    }

    It 'Windows 11 25H2 (build 26200, client)' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 11 Pro' -Build '26200' -ReferenceDate ([datetime]'2026-01-01')
        $r.Product | Should -Be 'Windows 11'
        $r.DisplayVersion | Should -Be '25H2'
    }
}

Describe 'Get-BravoOsSupportInfo — розпізнавання відомих build (server)' {
    It 'Windows Server 2012 (build 9200, server)' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows Server 2012 Standard' -Build '9200' -ReferenceDate ([datetime]'2020-01-01')
        $r.Product | Should -Be 'Windows Server 2012'
    }

    It 'Windows Server 2012 R2 (build 9600, server)' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows Server 2012 R2 Standard' -Build '9600' -ReferenceDate ([datetime]'2020-01-01')
        $r.Product | Should -Be 'Windows Server 2012 R2'
    }

    It 'той самий build 9600 як client (Windows 8.1) розпізнається окремо від server-рядка' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 8.1 Pro' -Build '9600' -ReferenceDate ([datetime]'2020-01-01')
        $r.Product | Should -Be 'Windows 8.1'
    }

    It 'Windows Server 2016 (build 14393, server)' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows Server 2016 Standard' -Build '14393' -ReferenceDate ([datetime]'2020-01-01')
        $r.Product | Should -Be 'Windows Server 2016'
    }

    It 'Windows Server 2019 (build 17763, server)' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows Server 2019 Standard' -Build '17763' -ReferenceDate ([datetime]'2022-01-01')
        $r.Product | Should -Be 'Windows Server 2019'
    }

    It 'Windows Server 2022 (build 20348, server)' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows Server 2022 Standard' -Build '20348' -ReferenceDate ([datetime]'2023-01-01')
        $r.Product | Should -Be 'Windows Server 2022'
    }

    It 'Windows Server 2025 / сучасний build (26100, server)' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows Server 2025 Standard' -Build '26100' -ReferenceDate ([datetime]'2026-01-01')
        $r.Product | Should -Be 'Windows Server 2025'
    }
}

Describe 'Get-BravoOsSupportInfo — LTSC distinction' {
    It 'EditionId=EnterpriseS (build 19044) визначає LTSC-канал і використовує SupportEndLtsc, не Enterprise' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 10 Enterprise LTSC' -Build '19044' -EditionId 'EnterpriseS' -ReferenceDate ([datetime]'2026-01-01')
        $r.Channel | Should -Be 'LTSC / LTSB'
        $r.SupportEndDate | Should -Be '2027-01-12'
    }

    It 'EditionId=EnterpriseSN (IoT LTSC N-варіант) також визначає LTSC-канал' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 10 Enterprise LTSC' -Build '19044' -EditionId 'EnterpriseSN' -ReferenceDate ([datetime]'2026-01-01')
        $r.Channel | Should -Be 'LTSC / LTSB'
    }

    It 'fallback без EditionId: Caption із "LTSC" також визначає LTSC-канал' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 10 Enterprise LTSC 2021' -Build '19044' -ReferenceDate ([datetime]'2026-01-01')
        $r.Channel | Should -Be 'LTSC / LTSB'
    }

    It 'той самий build БЕЗ LTSC EditionId класифікується як Enterprise/Education, інша дата підтримки' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 10 Enterprise' -Build '19044' -EditionId 'Enterprise' -ReferenceDate ([datetime]'2023-01-01')
        $r.Channel | Should -Be 'Enterprise / Education'
        $r.SupportEndDate | Should -Be '2024-06-11'
    }

    It 'build без LTSC-варіанту в таблиці (SupportEndLtsc порожній, напр. 22631) falls back на Enterprise-дату' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 11 Enterprise' -Build '22631' -EditionId 'Enterprise' -ReferenceDate ([datetime]'2025-01-01')
        $r.Channel | Should -Be 'Enterprise / Education'
        $r.SupportEndDate | Should -Be '2026-11-10'
    }
}

Describe 'Get-BravoOsSupportInfo — консюмерські/Pro edition винятки' {
    It 'EditionId=Professional (Pro Education/Pro for Workstations) залишається у Consumer-каналі' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 10 Pro Education' -Build '19045' -EditionId 'ProfessionalEducation' -ReferenceDate ([datetime]'2025-01-01')
        $r.Channel | Should -Be 'Consumer'
        $r.SupportEndDate | Should -Be '2025-10-14'
    }
}

Describe 'Get-BravoOsSupportInfo — невідомий/непарсований build' {
    It 'невідомий build (не в таблиці) повертає Product/DisplayVersion порожні, SupportStatus=Unknown' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 12 Pro' -Build '99999' -ReferenceDate ([datetime]'2030-01-01')
        $r.Product | Should -BeNullOrEmpty
        $r.SupportStatus | Should -Be 'Unknown'
        $r.DaysToEndOfSupport | Should -BeNullOrEmpty
    }

    It 'непарсований Build (порожній рядок) не кидає виняток і повертає Unknown' {
        { Get-BravoOsSupportInfo -Caption 'Microsoft Windows 10 Pro' -Build '' -ReferenceDate ([datetime]'2025-01-01') } | Should -Not -Throw
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 10 Pro' -Build '' -ReferenceDate ([datetime]'2025-01-01')
        $r.SupportStatus | Should -Be 'Unknown'
    }

    It 'непарсований Build (нечислове сміття) не кидає виняток і повертає Unknown' {
        { Get-BravoOsSupportInfo -Caption 'Microsoft Windows 10 Pro' -Build 'notabuild' -ReferenceDate ([datetime]'2025-01-01') } | Should -Not -Throw
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 10 Pro' -Build 'notabuild' -ReferenceDate ([datetime]'2025-01-01')
        $r.SupportStatus | Should -Be 'Unknown'
    }
}

Describe 'Get-BravoOsSupportInfo — status boundaries (Supported / EndingSoon / EndOfSupport)' {
    BeforeAll {
        # Build 19045 (Windows 10 22H2, Consumer): SupportEndConsumer = 2025-10-14.
        $script:BoundaryEndDate = [datetime]'2025-10-14'
    }

    It 'далеко до завершення підтримки (200 днів) -> Supported' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 10 Pro' -Build '19045' -ReferenceDate $script:BoundaryEndDate.AddDays(-200)
        $r.SupportStatus | Should -Be 'Supported'
        $r.DaysToEndOfSupport | Should -Be 200
    }

    It 'рівно 181 день до завершення -> ще Supported (межа: <=180 це EndingSoon)' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 10 Pro' -Build '19045' -ReferenceDate $script:BoundaryEndDate.AddDays(-181)
        $r.SupportStatus | Should -Be 'Supported'
        $r.DaysToEndOfSupport | Should -Be 181
    }

    It 'рівно 180 днів до завершення -> EndingSoon (межа включно)' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 10 Pro' -Build '19045' -ReferenceDate $script:BoundaryEndDate.AddDays(-180)
        $r.SupportStatus | Should -Be 'EndingSoon'
        $r.DaysToEndOfSupport | Should -Be 180
    }

    It '1 день до завершення -> EndingSoon' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 10 Pro' -Build '19045' -ReferenceDate $script:BoundaryEndDate.AddDays(-1)
        $r.SupportStatus | Should -Be 'EndingSoon'
        $r.DaysToEndOfSupport | Should -Be 1
    }

    It 'саме в день завершення (0 днів) -> EndingSoon (межа: EndOfSupport лише коли daysLeft < 0)' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 10 Pro' -Build '19045' -ReferenceDate $script:BoundaryEndDate
        $r.SupportStatus | Should -Be 'EndingSoon'
        $r.DaysToEndOfSupport | Should -Be 0
    }

    It '1 день після завершення -> EndOfSupport' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 10 Pro' -Build '19045' -ReferenceDate $script:BoundaryEndDate.AddDays(1)
        $r.SupportStatus | Should -Be 'EndOfSupport'
        $r.DaysToEndOfSupport | Should -Be -1
    }

    It 'давно після завершення (500 днів) -> EndOfSupport' {
        $r = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 10 Pro' -Build '19045' -ReferenceDate $script:BoundaryEndDate.AddDays(500)
        $r.SupportStatus | Should -Be 'EndOfSupport'
        $r.DaysToEndOfSupport | Should -Be -500
    }
}

Describe 'Get-BravoOsSupportInfo — reproducibility (детермінізм відносно ReferenceDate)' {
    It 'той самий вхід з тим самим ReferenceDate завжди дає ідентичний результат' {
        $ref = [datetime]'2025-06-15'
        $r1 = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 11 Pro' -Build '22631' -ReferenceDate $ref
        $r2 = Get-BravoOsSupportInfo -Caption 'Microsoft Windows 11 Pro' -Build '22631' -ReferenceDate $ref
        $r1.SupportStatus | Should -Be $r2.SupportStatus
        $r1.DaysToEndOfSupport | Should -Be $r2.DaysToEndOfSupport
    }

    It 'параметр ReferenceDate не є mandatory — дефолт зберігає зворотну сумісність виклику без нього' {
        (Get-Command Get-BravoOsSupportInfo).Parameters['ReferenceDate'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
            ForEach-Object { $_.Mandatory | Should -BeFalse }
    }
}
