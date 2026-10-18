# MODULE: tests/WorkflowEncoding.Tests.ps1
# Регресія: GitHub Actions генерує тимчасовий .ps1-файл для кожного run:-кроку
# БЕЗ UTF-8 BOM. Windows PowerShell 5.1 (powershell.exe) без BOM читає файл
# у системній ANSI-кодовій сторінці, а не в UTF-8 — будь-який не-ASCII символ
# (кирилиця, тире "—" тощо) у тілі такого кроку ламає парсер із незрозумілими
# помилками ("Missing closing '}'", "Unexpected token" у мовою, що виглядає
# як побитий текст). PowerShell 7 (pwsh) цієї вади не має — Core коректно
# визначає UTF-8 без BOM. Той самий клас бага вже виправлявся для
# .github/workflows/release.yml (див. CHANGELOG "Виправлено кодування у
# кроках release workflow"), але лишався непоміченим у
# local-windows-validation.yml, доки не завалив CI на PR #45.
#
# Тест НЕ забороняє кирилицю в YAML узагалі (name:, коментарі поза run:,
# bash/pwsh-кроки на ubuntu — усе це безпечне UTF-8-оточення й лишається
# українською). Перевіряється лише текст усередині `run:` для кроків, де
# ефективний shell — 'powershell' (Windows PowerShell 5.1).

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:WorkflowsDir = Join-Path $script:RepoRoot '.github\workflows'

    # Повертає для кожного (job, step) з run:-тілом ефективний shell:
    # step.shell, якщо заданий явно, інакше job.defaults.run.shell.
    function Get-BravoPowerShellRunSteps {
        param([string]$WorkflowPath)

        Import-Module powershell-yaml -ErrorAction Stop
        $doc = ConvertFrom-Yaml (Get-Content -LiteralPath $WorkflowPath -Raw -Encoding UTF8) -Ordered

        $results = @()
        foreach ($jobEntry in $doc.jobs.GetEnumerator()) {
            $job = $jobEntry.Value
            $jobDefaultShell = $null
            if ($job.defaults -and $job.defaults.run -and $job.defaults.run.shell) {
                $jobDefaultShell = $job.defaults.run.shell
            }

            foreach ($step in @($job.steps)) {
                if (-not $step.run) { continue }

                $effectiveShell = if ($step.shell) { $step.shell } else { $jobDefaultShell }

                # Небезпечний контекст лише для Windows PowerShell 5.1
                # ('powershell'). 'pwsh' (PowerShell 7/Core) і bash/sh коректно
                # визначають UTF-8 без BOM і сюди не потрапляють.
                if ($effectiveShell -eq 'powershell') {
                    $results += [PSCustomObject]@{
                        JobName  = $jobEntry.Key
                        StepName = $step.name
                        RunBody  = [string]$step.run
                    }
                }
            }
        }

        return $results
    }
}

Describe 'Windows PowerShell run:-кроки не містять небезпечного non-ASCII' -Skip:(-not (Get-Module -ListAvailable -Name powershell-yaml | Select-Object -First 1)) {
    It 'усі .github/workflows/*.yml мають лише ASCII-текст у shell: powershell run:-блоках' {
        $offenders = New-Object System.Collections.Generic.List[string]

        foreach ($workflowFile in (Get-ChildItem -LiteralPath $script:WorkflowsDir -Filter '*.yml' -File)) {
            $steps = Get-BravoPowerShellRunSteps -WorkflowPath $workflowFile.FullName

            foreach ($step in $steps) {
                # Будь-який символ поза друкованим ASCII (0x20-0x7E) чи табуляцією/переносом
                # рядка вважається небезпечним у цьому контексті.
                if ($step.RunBody -match '[^\x09\x0A\x0D\x20-\x7E]') {
                    $offenders.Add("$($workflowFile.Name) :: job '$($step.JobName)' :: step '$($step.StepName)'") | Out-Null
                }
            }
        }

        $offenders | Should -BeNullOrEmpty -Because (
            "ці кроки виконуються через Windows PowerShell 5.1 (shell: powershell) і мають у тілі run: " +
            "не-ASCII символи — на self-hosted Windows-раннері temp-скрипт без BOM буде прочитано в " +
            "ANSI-кодуванні й парсер впаде. Або переведіть текст на ASCII/англійську, або явно вкажіть " +
            "`shell: pwsh` для цього кроку (PowerShell 7 коректно визначає UTF-8 без BOM): " +
            ($offenders -join '; ')
        )
    }
}
