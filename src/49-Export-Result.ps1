# MODULE: 49-Export-Result.ps1
# Уніфікований структурований результат export-функцій (Issue #99).
#
# До цього фіксу кожен Export-Bravo*Report/Send-BravoEmailReport нічого не
# повертав — Main (src/90-Main.ps1) визначав success/failure лише
# опосередковано, діфом $script:Report.ExportErrors.Count/GeneratedFiles.Count
# "до" і "після" викликів. Це працювало, але не давало Main жодного прямого
# сигналу "саме ЦЕЙ виклик зробив/не зробив" — лише "щось змінилось відтоді".
#
# Кожен exporter тепер ЯВНО повертає New-BravoExportResult. Існуючі канали
# (Add-ExportError для audit trail, Write-Host для console UX,
# $script:Report.GeneratedFiles += для фактичного списку файлів) лишаються
# незмінними поряд з цим — нова структура доповнює їх, а не замінює
# (помилка не повинна губитись, якщо хтось дивиться лише на один канал).
function New-BravoExportResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Json', 'Html', 'Pdf', 'Csv', 'Zip', 'Email', 'Txt', 'Md')]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [bool]$Success,

        # Exporter не виконав роботу через свідомий вибір (switch вимкнено,
        # опційна залежність відсутня, передумова не виконана) — НЕ помилка.
        # Skipped завжди йде разом із Success=$true.
        [switch]$Skipped,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$Path = $null,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$ErrorMessage = $null,

        [AllowNull()]
        [Nullable[double]]$DurationSeconds = $null
    )

    return [PSCustomObject]@{
        Type            = $Type
        Success         = $Success
        Skipped         = [bool]$Skipped
        Path            = if ($Path) { $Path } else { $null }
        Error           = if ($ErrorMessage) { $ErrorMessage } else { $null }
        DurationSeconds = if ($null -ne $DurationSeconds) { [Math]::Round($DurationSeconds, 2) } else { $null }
    }
}
