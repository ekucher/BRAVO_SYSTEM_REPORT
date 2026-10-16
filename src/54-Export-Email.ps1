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
    if ($EmailTo) {
        try {
            $smtpToUse = if ($SmtpServer) { $SmtpServer } else { "smtp.$($env:USERDNSDOMAIN.ToLower())" }
            $mailBody = "BRAVO SYSTEM REPORT - $($script:Report.ComputerName)`n`nOS: $($script:Report.OS.Caption)`nHealth: $($script:Report.Health.Score)/100 ($($script:Report.Health.Status))`nCPU: $($script:Report.Hardware.CPU.LoadPercent)%`nRAM: $($script:Report.Hardware.RAM.TotalGB) GB ($($script:Report.Hardware.RAM.UsedPercent)%)`nDisk Free: $($script:Report.Hardware.Disks.FreePercent)%`nUptime: $($script:Report.OS.UptimeDays) days"
            $attachments = @($script:Report.GeneratedFiles | Where-Object { $_ -and (Test-Path -LiteralPath $_) -and ($_ -notlike '*.zip') })

            $mailParams = @{
                To          = $EmailTo
                From        = $EmailFrom
                Subject     = "BRAVO SYSTEM REPORT - $($script:Report.ComputerName)"
                Body        = $mailBody
                SmtpServer  = $smtpToUse
                Attachments = $attachments
                ErrorAction = 'Stop'
            }
            if ($SmtpPort -gt 0) { $mailParams.Port = $SmtpPort }
            if ($EmailUseSsl) { $mailParams.UseSsl = $true }
            if ($EmailCredential) { $mailParams.Credential = $EmailCredential }

            Send-MailMessage @mailParams
            Write-Host "  $IconEmail Email відправлено на $EmailTo $(if ($EmailUseSsl) { '(TLS)' } else { '(plaintext SMTP — вкажіть -EmailUseSsl для шифрування)' })" -ForegroundColor Green
        } catch {
            Add-AuditError -Section 'Export.Email' -Message $_.Exception.Message
            Write-Host "  $IconError Помилка відправки Email: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
