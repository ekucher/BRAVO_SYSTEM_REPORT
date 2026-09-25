# MODULE: 90-Main.ps1
# Основний execution flow BRAVO SYSTEM REPORT.
# Param-блок винесено у src\05-Params.ps1.
# Helper-функції винесено у src\10-Core.ps1.

<#
.SYNOPSIS
    BRAVO SYSTEM REPORT — детальний аудит Windows-машини.
.DESCRIPTION
    Збирає базову інформацію про ОС, апаратне забезпечення, диски, мережу,
    безпеку, користувачів, процеси, служби, події та встановлене ПЗ.

    Версія 0.2.0 стабілізує початковий скрипт:
    - додає профілі аудиту;
    - додає OutputPath, NoOpenFolder, NoPause;
    - виправляє конфлікти змінних іконок з об'єктами CPU/дисків;
    - додає CollectionErrors та Findings;
    - виправляє обчислення часу виконання;
    - прибирає порожні catch-блоки.
.NOTES
    Рекомендована версія: Windows PowerShell 5.1+.
    Для частини даних потрібні права адміністратора.
#>
$ErrorActionPreference = 'Continue'
$ScriptStartTime = Get-Date
$ScriptVersion = "0.6.1"

function Show-Pause {
    param([string]$Message = 'Натисніть будь-яку клавішу для виходу...')

    Write-Host $Message -ForegroundColor Gray
    try {
        if ($Host.Name -eq 'ConsoleHost') {
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
    } catch {}

    try { Read-Host | Out-Null; return } catch {}
    try {
        Write-Host 'Автоматичне закриття через 10 секунд...' -ForegroundColor Gray
        Start-Sleep -Seconds 10
    } catch {}
}

function Get-ScriptDirectory {
    if ($PSScriptRoot -and (Test-Path -LiteralPath $PSScriptRoot)) { return $PSScriptRoot }
    if ($MyInvocation.MyCommand.Path) { return Split-Path -Parent $MyInvocation.MyCommand.Path }
    return (Get-Location).Path
}

function Format-Size {
    param([double]$GB)

    if ($null -eq $GB) { return '0 GB' }
    if ($GB -gt 1024) { return "$([Math]::Round($GB / 1024, 2)) TB" }
    return "$([Math]::Round($GB, 2)) GB"
}

function Convert-AuditDateTime {
    param(
        [Parameter(Mandatory = $false)]$Value,
        [bool]$UseCim = $false
    )

    if (-not $Value) { return $null }

    try {
        if ($UseCim -or $Value -is [datetime]) { return [datetime]$Value }
        return [Management.ManagementDateTimeConverter]::ToDateTime($Value)
    } catch {
        return $null
    }
}

function Add-AuditError {
    param(
        [string]$Section,
        [string]$Message
    )

    if (-not $script:Report) { return }

    $script:Report.CollectionErrors += [PSCustomObject]@{
        Time    = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Section = $Section
        Message = $Message
    }
}

function Add-ExportError {
    # На відміну від Add-AuditError (помилки ЗБОРУ даних, впливають на Health
    # Score), ExportErrors — помилки ЗАПИСУ звітів (JSON/HTML/CSV/ZIP/Email):
    # проблема самого інструмента, а не аудитованої машини. Не впливає на
    # Health Score, але впливає на exit code (P0.5).
    param(
        [string]$Section,
        [string]$Message
    )

    if (-not $script:Report) { return }

    $script:Report.ExportErrors += [PSCustomObject]@{
        Time    = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Section = $Section
        Message = $Message
    }
}

function Add-AuditFinding {
    param(
        [ValidateSet('INFO','WARNING','CRITICAL')]
        [string]$Severity,
        [string]$Category,
        [string]$Message,
        [string]$Recommendation = ''
    )

    if (-not $script:Report) { return }

    $script:Report.Health.Findings += [PSCustomObject]@{
        Severity       = $Severity
        Category       = $Category
        Message        = $Message
        Recommendation = $Recommendation
    }
}

function Get-AuditObject {
    param(
        [string]$ClassName,
        [string]$Filter = '',
        [switch]$First
    )

    if ($script:UseCim) {
        if ($Filter) { $result = Get-CimInstance -ClassName $ClassName -Filter $Filter -ErrorAction Stop }
        else { $result = Get-CimInstance -ClassName $ClassName -ErrorAction Stop }
    } else {
        if ($Filter) { $result = Get-WmiObject -Class $ClassName -Filter $Filter -ErrorAction Stop }
        else { $result = Get-WmiObject -Class $ClassName -ErrorAction Stop }
    }

    if ($First) { return $result | Select-Object -First 1 }
    return $result
}



function Resolve-AuditOutputPath {
    param(
        [string]$RequestedPath,
        [string]$DefaultPath
    )

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) { $RequestedPath = $DefaultPath }

    if (-not [System.IO.Path]::IsPathRooted($RequestedPath)) {
        $RequestedPath = Join-Path $DefaultPath $RequestedPath
    }

    if (-not (Test-Path -LiteralPath $RequestedPath)) {
        New-Item -ItemType Directory -Path $RequestedPath -Force | Out-Null
    }

    return (Resolve-Path -LiteralPath $RequestedPath).Path
}

# Фатальний fallback (P0.5): будь-яка термінуюча помилка, що вислизнула з
# усіх внутрішніх try/catch колекторів/export-функцій нижче (тобто справжній
# баг чи неочікуваний runtime-збій, а не штатна помилка збору/експорту),
# ловиться тут і завершує процес з exit code 2 — "fatal init/runtime error",
# на відміну від 1 (штатні CollectionErrors/ExportErrors, аудит все одно
# завершився й дав результат).
trap {
    Write-Host ''
    Write-Host "[FATAL] Неопрацьована помилка виконання: $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}

try { Clear-Host } catch {}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$PSMajorVersion = $PSVersionTable.PSVersion.Major
$OSVersion = [Environment]::OSVersion.Version
$IsWin8OrHigher = ($OSVersion.Major -ge 6 -and $OSVersion.Minor -ge 2) -or ($OSVersion.Major -ge 10)
$HaveCim = (Get-Command -Name Get-CimInstance -ErrorAction SilentlyContinue) -ne $null
$script:UseCim = $HaveCim -and $IsWin8OrHigher

if ($EventLogDays -le 0) {
    $EventLogDays = switch ($Profile) {
        'Quick'    { 1 }
        'Full'     { 3 }
        'Deep'     { 7 }
        'Forensic' { 14 }
        default    { 3 }
    }
}

# -NoZip явно вимикає ZIP (переопределяє default=$true у -Zip). Див. коментар
# нижче біля forwarding у $arguments — CLI не підтримує -Zip:$false напряму.
if ($NoZip) { $Zip = $false }

$ScriptDirectory = Get-ScriptDirectory

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and -not $NoElevate -and -not $SkipElevation) {
    Write-Host '[INFO] Потрібні права адміністратора. Запит підвищення прав...' -ForegroundColor Yellow
    $scriptFullPath = $MyInvocation.MyCommand.Path
    if (-not $scriptFullPath) { $scriptFullPath = $PSCommandPath }

    if ($scriptFullPath -and (Test-Path -LiteralPath $scriptFullPath)) {
        $arguments = @('-SkipElevation')
        $arguments += "-Profile $Profile"
        $arguments += "-EventLogDays $EventLogDays"
        if ($OutputPath) { $arguments += "-OutputPath `"$OutputPath`"" }
        if ($JSONOnly) { $arguments += '-JSONOnly' }
        if ($CSV) { $arguments += '-CSV' }
        if ($TXT) { $arguments += '-TXT' }
        if ($MD) { $arguments += '-MD' }
        # $Zip не форвардиться напряму: powershell.exe -File не підтримує
        # синтаксис -Zip:$false для switch-параметрів з рядка команди (це
        # PowerShell-мовна конструкція, а не CLI-конвенція — перевірено
        # емпірично, дає ParameterArgumentTransformationError). Тому вимкнення
        # ZIP форвардиться через окремий default-false switch -NoZip, за тим
        # самим патерном, що й -NoPause/-NoEmoji/-NoOpenFolder нижче.
        # Перевіряємо ЕФЕКТИВНЕ значення $Zip (уже враховує і -NoZip, і
        # прямий -Zip:$false — обидва застосовані вище, до elevation-блоку),
        # а не сам прапорець -NoZip, — інакше користувач, що викликав
        # -Zip:$false напряму (старий, задокументований в CHANGELOG спосіб),
        # так само втратить вимкнення ZIP при relaunch під адміном.
        if (-not $Zip) { $arguments += '-NoZip' }
        if ($NoEmoji) { $arguments += '-NoEmoji' }
        if ($NoPause) { $arguments += '-NoPause' }
        if ($NoOpenFolder) { $arguments += '-NoOpenFolder' }
        if ($SkipPublicIP) { $arguments += '-SkipPublicIP' }
        if ($SkipGeoIP) { $arguments += '-SkipGeoIP' }
        if ($Offline) { $arguments += '-Offline' }
        if ($Strict) { $arguments += '-Strict' }
        if ($Sanitize) { $arguments += '-Sanitize' }
        $arguments += "-SanitizeLevel $SanitizeLevel"
        if ($SkipUpdateSearch) { $arguments += '-SkipUpdateSearch' }
        $arguments += "-UpdateSearchTimeoutSec $UpdateSearchTimeoutSec"
        if ($EmailTo) { $arguments += "-EmailTo `"$EmailTo`"" }
        if ($EmailFrom) { $arguments += "-EmailFrom `"$EmailFrom`"" }
        if ($SmtpServer) { $arguments += "-SmtpServer `"$SmtpServer`"" }
        if ($ExportPdf) { $arguments += '-ExportPdf' }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`" $($arguments -join ' ')"
        $psi.Verb = 'runas'
        $psi.WorkingDirectory = $ScriptDirectory

        try {
            # Чекаємо завершення елевованого процесу і прокидаємо його реальний
            # exit code — раніше батьківський процес завершувався одразу (exit 0)
            # незалежно від результату дочірнього, тож зовнішній caller (CI/скрипт),
            # що перевіряє exit code первинного виклику, завжди бачив 0 (P0.5).
            $elevatedProcess = [System.Diagnostics.Process]::Start($psi)
            $elevatedProcess.WaitForExit()
            exit $elevatedProcess.ExitCode
        } catch {
            Write-Host "[INFO] Не вдалося підвищити права: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# У службовому PowerShell-виводі emoji не використовуються.
# HTML-звіт є винятком: emoji дозволені як частина візуального звіту.
$IconOk='[OK]'; $IconError='[ERROR]'; $IconCpu='[OK]'; $IconRam='[OK]'; $IconDisk='[OK]'; $IconNetwork='[OK]'; $IconSecurity='[OK]'
$IconDone='[SUCCESS]'; $IconJson='[OK]'; $IconHtml='[OK]'; $IconCsv='[OK]'; $IconGear='[INFO]'; $IconEvent='[OK]'
$IconFolder='[INFO]'; $IconDb='[OK]'; $IconPc='[INFO]'; $IconService='[OK]'; $IconZip='[OK]'; $IconEmail='[OK]'

Write-Host ''
Write-Host "=== BRAVO SYSTEM REPORT v$ScriptVersion ===" -ForegroundColor Cyan
Write-Host '=== ДЕТАЛЬНИЙ ЗВІТ ПРО WINDOWS-МАШИНУ ===' -ForegroundColor Cyan
Write-Host ''
Write-Host "[INFO] PowerShell: $($PSVersionTable.PSVersion), OS: $OSVersion, метод: $(if($script:UseCim){'CIM'}else{'WMI'}), профіль: $Profile" -ForegroundColor Gray
Write-Host "[INFO] Директорія: $ScriptDirectory" -ForegroundColor Cyan
Write-Host "$(if($isAdmin){'[OK] АДМІНІСТРАТОР'}else{'[INFO] ОБМЕЖЕНІ ПРАВА'})" -ForegroundColor $(if($isAdmin){'Green'}else{'Yellow'})
Write-Host ''

Set-Location $ScriptDirectory -ErrorAction SilentlyContinue

$script:Report = New-BravoReportModel

Write-Host '=== ЗБІР ІНФОРМАЦІЇ ПРО МАШИНУ ===' -ForegroundColor Cyan
Write-Host ''

# --- ОС ---
Get-BravoOperatingSystemAudit

# --- .NET / PowerShell (перевірка можливості оновлення) ---
Get-BravoRuntimeAudit

# --- Апаратне забезпечення ---
Get-BravoHardwareAudit

# --- BIOS ---
try {
    $biosInfo = Get-AuditObject -ClassName 'Win32_BIOS' -First
    $script:Report.BIOS.Version = ($biosInfo.SMBIOSBIOSVersion, $biosInfo.Version | Where-Object { $_ } | Select-Object -First 1)
    $script:Report.BIOS.SerialNumber = $biosInfo.SerialNumber
    $releaseDate = Convert-AuditDateTime -Value $biosInfo.ReleaseDate -UseCim:$script:UseCim
    if ($releaseDate) { $script:Report.BIOS.ReleaseDate = $releaseDate.ToString('yyyy-MM-dd') }
} catch {
    Add-AuditError -Section 'BIOS' -Message $_.Exception.Message
}
# --- Диски ---
Get-BravoStorageAudit

# --- Мережа ---
Get-BravoNetworkAudit

# --- Безпека ---
Get-BravoSecurityAudit

# --- Користувачі ---
Get-BravoUsersAudit

# --- Процеси та служби ---
Get-BravoProcessesServicesAudit

# --- Журнали подій ---
Get-BravoEventLogsAudit

# --- Програмне забезпечення ---
Get-BravoSoftwareAudit

# --- Оновлення ОС ---
Get-BravoUpdatesAudit

# --- Health score ---
# Рахується РІВНО ОДИН РАЗ, одразу після завершення всіх колекторів. До
# стабілізаційного рефакторингу (P0.4) тут існував "гейт" повторного
# перерахунку після export-етапів — бо помилки запису JSON/HTML/ZIP мішались
# у той самий CollectionErrors, що й впливає на Health Score. Тепер
# CollectionErrors (помилки ЗБОРУ) і ExportErrors (помилки ЗАПИСУ звітів)
# розділені: Health Score — властивість аудитованої машини (CollectionErrors
# + Findings), export-етапи більше не можуть його змінити заднім числом,
# тож повторний перерахунок і пов'язаний з ним ризик (self-zip race з
# попередніх версій) став непотрібним.
Update-BravoHealthScore

# ============================================================
# ЗБЕРЕЖЕННЯ ЗВІТІВ
# ============================================================

try {
    $outputDir = Resolve-AuditOutputPath -RequestedPath $OutputPath -DefaultPath $ScriptDirectory
} catch {
    # Проблема самого інструмента (не вдалось підготувати каталог виводу),
    # не властивість аудитованої машини — ExportError, не CollectionError.
    Add-ExportError -Section 'OutputPath' -Message $_.Exception.Message
    $outputDir = $ScriptDirectory
}

$script:Report.OutputPath = $outputDir
$reportTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

# --- Sanitize (P1/v0.4.3, fail-closed з v0.6.1) ---
# Виконується ПІСЛЯ Health Score (маскування не впливає на Score/Status —
# рахунок уже фінальний), ПІСЛЯ Report.OutputPath (щоб саме поле теж
# потрапило під маскування), і ДО будь-якого export'а, щоб JSON/HTML/CSV/ZIP
# усі отримали вже замасковані дані з одного проходу. Fail-closed: якщо
# маскування впало посередині (частина полів замаскована, частина — ні),
# жоден звіт НЕ пишеться на диск (exit code 5) — часткове маскування
# небезпечніше за відсутність звіту.
$script:SanitizeFailed = $false
if ($Sanitize) {
    $sanitizeResult = Invoke-BravoReportSanitizationGated -Report $script:Report -Level $SanitizeLevel
    if ($sanitizeResult.Success) {
        Write-Host "$IconOk Sanitize: дані замасковано (рівень $SanitizeLevel)" -ForegroundColor Yellow
    } else {
        $script:SanitizeFailed = $true
        Write-Host "[ERROR] Sanitize перервано помилкою — жоден звіт НЕ згенеровано (fail-closed): $($sanitizeResult.ErrorMessage)" -ForegroundColor Red
    }
}

# Ім'я файлу теж має бути безпечним при -Sanitize: реальний $env:COMPUTERNAME
# використовується лише коли sanitize вимкнено або провалився (у разі
# провалу звіти взагалі не пишуться нижче, тому ім'я тут не потрапляє на
# диск, але лишається консистентним з рештою пайплайна).
$baseFileNameComputer = if ($Sanitize -and -not $script:SanitizeFailed) { $script:Report.ComputerName } else { $env:COMPUTERNAME }
$baseFileName = "BravoSystemReport_${baseFileNameComputer}_$reportTimestamp"

Write-Host ''
Write-Host '=== ГЕНЕРАЦІЯ ЗВІТІВ ===' -ForegroundColor Cyan
Write-Host ''
if ($script:SanitizeFailed) {
    Write-Host "[ERROR] Sanitize fail-closed: жоден звіт НЕ записано в $outputDir" -ForegroundColor Red
} else {
    Write-Host "$IconFolder Збереження: $outputDir" -ForegroundColor Cyan

    # Локальний helper — синхронізує JSON на диску з поточним станом
    # ExportErrors, якщо він змінився з моменту попереднього запису. JSON
    # пишеться ПЕРШИМ (щоб потрапити до ZIP), але наступні export-етапи
    # (HTML/PDF/TXT/MD/CSV/ZIP/Email) можуть додати власні ExportErrors —
    # тому виклик повторюється в кількох контрольних точках нижче (після
    # CSV/до ZIP, після ZIP/до Email, після Email), а не лише один раз
    # наприкінці — щоб і ZIP-вкладення, і Email-вкладення відображали
    # актуальний на момент пакування/відправки стан ExportErrors.
    function Sync-BravoJsonIfExportErrorsChanged {
        param([int]$PriorCount)
        if (@($script:Report.ExportErrors).Count -gt $PriorCount) {
            Export-BravoJsonReport -OutputDir $outputDir -BaseFileName $baseFileName
            $script:Report.GeneratedFiles = @($script:Report.GeneratedFiles | Select-Object -Unique)
        }
        return @($script:Report.ExportErrors).Count
    }

    # JSON — Health Score вже фінальний (рахувався до початку export-етапів),
    # тому перший запис одразу авторитетний щодо CollectionErrors/Findings.
    $exportErrorCount = @($script:Report.ExportErrors).Count
    Export-BravoJsonReport -OutputDir $outputDir -BaseFileName $baseFileName

    # HTML
    Export-BravoHtmlReport -OutputDir $outputDir -BaseFileName $baseFileName -JSONOnly $JSONOnly -EventLogDays $EventLogDays -Profile $Profile -ScriptVersion $ScriptVersion

    # PDF (опційно, через headless Microsoft Edge) — потребує HTML, тому
    # виконується одразу після Export-BravoHtmlReport і до ZIP, щоб .pdf
    # встиг потрапити в GeneratedFiles до пакування. -JSONOnly вимикає HTML
    # взагалі, тож PDF теж пропускається (нема з чого конвертувати).
    if ($ExportPdf -and -not $JSONOnly) {
        Export-BravoPdfReport -OutputDir $outputDir -BaseFileName $baseFileName
    }

    # TXT (plain-text summary — v0.6.0 Reports and UX, той самий формат
    # слугує й copy-friendly support summary) — не залежить від HTML/PDF,
    # генерується прямо з $script:Report, тож не гейтується -JSONOnly.
    Export-BravoTxtReport -OutputDir $outputDir -BaseFileName $baseFileName -TXT $TXT

    # MD (Markdown summary — v0.6.0 Reports and UX, для Redmine/GitHub) — той
    # самий принцип, що й TXT: не залежить від HTML/PDF, генерується прямо з
    # $script:Report, тож не гейтується -JSONOnly.
    Export-BravoMdReport -OutputDir $outputDir -BaseFileName $baseFileName -MD $MD

    # CSV
    Export-BravoCsvReport -OutputDir $outputDir -BaseFileName $baseFileName -CSV $CSV

    $script:Report.GeneratedFiles = @($script:Report.GeneratedFiles | Select-Object -Unique)

    # JSON у ZIP має відображати ExportErrors від HTML/PDF/TXT/MD/CSV, а не
    # лише від початкового запису — синхронізуємо перед пакуванням.
    $exportErrorCount = Sync-BravoJsonIfExportErrorsChanged -PriorCount $exportErrorCount

    # ZIP
    Export-BravoZipReport -OutputDir $outputDir -BaseFileName $baseFileName -Zip $Zip
    $script:Report.GeneratedFiles = @($script:Report.GeneratedFiles | Select-Object -Unique)

    # Якщо сам ZIP додав ExportError — JSON на диску (не копія всередині вже
    # запакованого ZIP) все одно має бути авторитетним перед відправкою Email.
    $exportErrorCount = Sync-BravoJsonIfExportErrorsChanged -PriorCount $exportErrorCount

    # Email — останній export-етап. Тіло листа й вкладення відображають стан на
    # момент відправки (Health Score вже фінальний; JSON-вкладення може не
    # містити ExportErrors від самого Email — лист не може повідомити про власну
    # невдалу відправку заднім числом, це очікуване обмеження).
    Send-BravoEmailReport -EmailTo $EmailTo -EmailFrom $EmailFrom -SmtpServer $SmtpServer

    # Фінальна синхронізація — якщо Email додав ExportError, файл на диску
    # (не вкладення вже відправленого листа) відображає це.
    $exportErrorCount = Sync-BravoJsonIfExportErrorsChanged -PriorCount $exportErrorCount
}

# Фінал
$elapsedSeconds = [Math]::Round(((Get-Date) - $ScriptStartTime).TotalSeconds, 2)
$jsonPath = Join-Path $outputDir "$baseFileName.json"
$htmlPath = Join-Path $outputDir "$baseFileName.html"
$csvPath = Join-Path $outputDir "$baseFileName.csv"
$txtPath = Join-Path $outputDir "$baseFileName.txt"
$mdPath = Join-Path $outputDir "$baseFileName.md"
$zipPath = Join-Path $outputDir "$baseFileName.zip"

Write-Host ''
Write-Host '=== АУДИТ МАШИНИ ЗАВЕРШЕНО ===' -ForegroundColor Green
Write-Host ''
if ($script:SanitizeFailed) {
    Write-Host "$IconError Звіти НЕ згенеровано (Sanitize fail-closed): $outputDir" -ForegroundColor Red
} else {
    Write-Host "$IconFolder Звіти збережено: $outputDir" -ForegroundColor Cyan
}
if (Test-Path -LiteralPath $jsonPath) { Write-Host "$IconJson JSON: $baseFileName.json" -ForegroundColor White }
if ((-not $JSONOnly) -and (Test-Path -LiteralPath $htmlPath)) { Write-Host "$IconHtml HTML: $baseFileName.html" -ForegroundColor White }
if ($CSV -and (Test-Path -LiteralPath $csvPath)) { Write-Host "$IconCsv CSV: $baseFileName.csv" -ForegroundColor White }
if ($TXT -and (Test-Path -LiteralPath $txtPath)) { Write-Host "$IconCsv TXT: $baseFileName.txt" -ForegroundColor White }
if ($MD -and (Test-Path -LiteralPath $mdPath)) { Write-Host "$IconCsv MD: $baseFileName.md" -ForegroundColor White }
if ($Zip -and (Test-Path -LiteralPath $zipPath)) {
    Write-Host "$IconZip ZIP: $baseFileName.zip" -ForegroundColor White
} elseif ($Zip) {
    Write-Host "$IconError ZIP не створено: $baseFileName.zip" -ForegroundColor Red
}
Write-Host "Оцінка стану: $($script:Report.Health.Score)/100 ($($script:Report.Health.Status))" -ForegroundColor Cyan
Write-Host "Знахідки: $($script:Report.Health.Findings.Count); помилки збору: $($script:Report.CollectionErrors.Count); помилки експорту: $($script:Report.ExportErrors.Count)" -ForegroundColor Cyan
Write-Host "Час виконання: $elapsedSeconds сек" -ForegroundColor Cyan
Write-Host ''

# --- Exit code contract (P0.5, розширено -Strict у P1, code 5 у v0.6.1) ---
# 0 = аудит успішно завершено, без помилок збору/експорту (і, у -Strict
#     режимі, без CRITICAL Health.Status);
# 1 = аудит завершено, але були CollectionErrors і/або ExportErrors;
# 2 = фатальна неопрацьована помилка виконання (top-level trap, вище в файлі);
# 3 = обов'язковий вихідний файл (JSON) не згенеровано;
# 4 = лише у -Strict режимі: аудит завершено без CollectionErrors/ExportErrors,
#     але Health.Status аудитованої машини = CRITICAL.
# 5 = -Sanitize провалився посередині маскування (fail-closed) — жоден звіт
#     не записано на диск, щоб частково замаскований звіт ніколи не потрапив
#     користувачу. Перевіряється ПЕРШИМ у ланцюжку — причина відсутності
#     JSON тут інша (свідома відмова писати), ніж у коді 3 (export-баг).
#
# За замовчуванням (без -Strict) Health Status (WARNING/CRITICAL) НЕ впливає
# на exit code — це властивість аудитованої машини (наскільки вона здорова),
# а не ознака збою самого інструмента. -Strict вмикає цю поведінку явно —
# для CI-гейтів, яким потрібен ненульовий exit code саме на "машина в
# критичному стані", а не лише на "інструмент не зміг щось зібрати/записати".
$script:ExitCode = 0
if ($script:SanitizeFailed) {
    $script:ExitCode = 5
} elseif (-not (Test-Path -LiteralPath $jsonPath)) {
    $script:ExitCode = 3
} elseif ((@($script:Report.CollectionErrors).Count -gt 0) -or (@($script:Report.ExportErrors).Count -gt 0)) {
    $script:ExitCode = 1
} elseif ($Strict -and $script:Report.Health.Status -eq 'CRITICAL') {
    $script:ExitCode = 4
}

# Відкриття директорії звітів — UX-зручність, не частина export-контракту:
# $script:ExitCode вже зафіксований вище і не залежить від успіху цього
# кроку. Невдача тут НЕ реєструється через Add-ExportError (не помилка
# запису звіту, самі звіти вже записані) — лише консольне попередження,
# щоб не спотворювати ExportErrors/Health невидимим для користувача чином
# (JSON на цей момент уже записаний, повторний запис не відбувається).
# При $script:SanitizeFailed директорія свідомо не відкривається — там
# немає звітів, які варто показувати оператору.
if (-not $NoOpenFolder -and -not $script:SanitizeFailed) {
    try { Start-Process explorer.exe -ArgumentList "`"$outputDir`"" -ErrorAction SilentlyContinue } catch {
        Write-Host "[WARNING] Не вдалося відкрити директорію звітів: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if (-not $NoPause) { Show-Pause }
exit $script:ExitCode
