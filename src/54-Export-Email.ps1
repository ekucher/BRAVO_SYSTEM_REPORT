# MODULE: 54-Export-Email.ps1
# Відправка BRAVO SYSTEM REPORT електронною поштою.

function Send-BravoEmailReport {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$EmailTo,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$EmailFrom,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$SmtpServer,

        [int]$SmtpPort = 0,

        [switch]$EmailUseSsl,

        [AllowNull()]
        [System.Management.Automation.PSCredential]$EmailCredential
    )

    # Email
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    if ($EmailTo) {
        try {
            $smtpToUse = $SmtpServer
            if (-not $smtpToUse) {
                # Workgroup-хост: USERDNSDOMAIN порожній, автовизначити SMTP неможливо.
                if (-not $env:USERDNSDOMAIN) {
                    $noSmtpMessage = 'SMTP-сервер не визначено (хост поза доменом): вкажіть -SmtpServer'
                    Add-ExportError -Section 'Export.Email' -Message $noSmtpMessage
                    Write-Host "  $IconError Помилка відправки Email: $noSmtpMessage" -ForegroundColor Red
                    return New-BravoExportResult -Type 'Email' -Success $false -ErrorMessage $noSmtpMessage -DurationSeconds $stopwatch.Elapsed.TotalSeconds
                }
                $smtpToUse = "smtp.$($env:USERDNSDOMAIN.ToLower())"
            }
            $mailBody = "BRAVO SYSTEM REPORT - $($script:Report.ComputerName)`n`nOS: $($script:Report.OS.Caption)`nHealth: $($script:Report.Health.Score)/100 ($($script:Report.Health.Status))`nCPU: $($script:Report.Hardware.CPU.LoadPercent)%`nRAM: $($script:Report.Hardware.RAM.TotalGB) GB ($($script:Report.Hardware.RAM.UsedPercent)%)`nDisk Free: $($script:Report.Hardware.Disks.FreePercent)%`nUptime: $($script:Report.OS.UptimeDays) days"
            $attachments = @($script:Report.GeneratedFiles | Where-Object { $_ -and (Test-Path -LiteralPath $_) -and ($_ -notlike '*.zip') })

            $mailParams = @{
                To          = $EmailTo
                From        = $EmailFrom
                Subject     = "BRAVO SYSTEM REPORT - $($script:Report.ComputerName)"
                Body        = $mailBody
                SmtpServer  = $smtpToUse
                ErrorAction = 'Stop'
            }
            # Send-MailMessage валідує -Attachments як ValidateNotNullOrEmpty
            # (реальний Microsoft.PowerShell.Utility cmdlet) — передача
            # порожнього масиву (напр. якщо жоден не-ZIP файл ще не
            # згенеровано) падала б ще до спроби відправки, маскуючи
            # справжню причину під "помилку Email". Той самий патерн, що й
            # опційні Port/UseSsl/Credential нижче.
            if ($attachments.Count -gt 0) { $mailParams.Attachments = $attachments }
            if ($SmtpPort -gt 0) { $mailParams.Port = $SmtpPort }
            if ($EmailUseSsl) { $mailParams.UseSsl = $true }
            if ($EmailCredential) { $mailParams.Credential = $EmailCredential }

            Send-MailMessage @mailParams
            Write-Host "  $IconEmail Email відправлено на $EmailTo $(if ($EmailUseSsl) { '(TLS)' } else { '(plaintext SMTP — вкажіть -EmailUseSsl для шифрування)' })" -ForegroundColor Green
            return New-BravoExportResult -Type 'Email' -Success $true -DurationSeconds $stopwatch.Elapsed.TotalSeconds
        } catch {
            Add-ExportError -Section 'Export.Email' -Message $_.Exception.Message
            Write-Host "  $IconError Помилка відправки Email: $($_.Exception.Message)" -ForegroundColor Red
            return New-BravoExportResult -Type 'Email' -Success $false -ErrorMessage $_.Exception.Message -DurationSeconds $stopwatch.Elapsed.TotalSeconds
        }
    }

    return New-BravoExportResult -Type 'Email' -Success $true -Skipped -DurationSeconds $stopwatch.Elapsed.TotalSeconds
}
