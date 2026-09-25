# MODULE: 50-Export-Json.ps1
# Експорт BRAVO SYSTEM REPORT у JSON.

function Export-BravoJsonReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputDir,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseFileName
    )

    # JSON
    try {
        $jsonPath = Join-Path $OutputDir "$BaseFileName.json"
        $jsonContent = ConvertTo-Json $script:Report -Depth 12
        # Out-File -Encoding utf8 у Windows PowerShell 5.1 завжди додає BOM,
        # що ламає суворі JSON-парсери (RFC 8259 не допускає BOM) у зовнішніх
        # CI/monitoring-пайплайнах, які читають цей файл. Пишемо через
        # .NET напряму з UTF8Encoding($false) — без BOM.
        #
        # Ретрай на IOException: якщо цей файл уже існує (90-Main.ps1 повторно
        # викликає цю функцію наприкінці, щоб зафіксувати фінальні ExportErrors),
        # він міг лишитись коротко заблокованим попереднім кроком — наприклад,
        # Send-MailMessage асинхронно звільняє handle вкладення не миттєво
        # (garbage collector/finalizer), і негайний повторний запис ловить
        # sharing violation. Підтверджено реальним прогоном. 3 спроби з
        # короткою паузою покривають цей транзієнтний випадок.
        # Примітка: виключення від .NET static method call (WriteAllText)
        # PowerShell 5.1 обгортає в MethodInvocationException — типізований
        # `catch [System.IO.IOException]` НЕ спрацьовує (тип не збігається,
        # перевірено емпірично), тому тут навмисно catch-all із перевіркою
        # реальної причини через InnerException.
        #
        # Важливо: сам по собі Start-Sleep НЕ допомагає — підтверджено
        # емпірично, lock тримається 5+ секунд і довше без дій. Причина:
        # Send-MailMessage (SmtpClient/MailMessage/Attachment) звільняє
        # file handle вкладення лише через finalizer, а не одразу при
        # виключенні — GC не запускається сам по собі негайно. Явний
        # [GC]::Collect() + WaitForPendingFinalizers() форсує звільнення
        # миттєво (перевірено емпірично — без цього retry марний).
        $maxAttempts = 3
        for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
            try {
                [System.IO.File]::WriteAllText($jsonPath, $jsonContent, (New-Object System.Text.UTF8Encoding($false)))
                break
            } catch {
                $isShareViolation = ($_.Exception.InnerException -is [System.IO.IOException]) -or ($_.Exception -is [System.IO.IOException])
                if (-not $isShareViolation -or $attempt -ge $maxAttempts) { throw }
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
            }
        }
        $script:Report.GeneratedFiles += $jsonPath
        Write-Host "  $IconJson JSON: $BaseFileName.json" -ForegroundColor Green
    } catch {
        Add-ExportError -Section 'Export.Json' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка JSON: $($_.Exception.Message)" -ForegroundColor Red
    }
}
