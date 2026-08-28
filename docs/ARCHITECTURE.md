# Архітектура BRAVO SYSTEM REPORT

## Модель

Скрипт побудований як набір незалежних collector-модулів у `src/`, кожен з яких заповнює свою секцію спільного `$script:Report` і не зупиняє весь аудит через власну помилку. Генерація звітів (JSON/HTML/CSV/ZIP) відокремлена від збору даних: export-модулі лише читають вже заповнений `$script:Report`.

`src/*.ps1` конкатенуються build-скриптом (`Build-BRAVO-SystemReport.ps1`, за порядком у `src/BRAVO.build.json`) в один монолітний runtime-файл `dist/Get-BravoSystemReport.ps1` — саме він виконується кінцевим користувачем (через `Get-BravoSystemReport.ps1`-wrapper у корені або `.bat`-лаунчери).

## Потік виконання (`90-Main.ps1`)

```text
Parameters (05-Params.ps1)
    ↓
Elevation / self-relaunch as admin
    ↓
$script:Report = New-BravoReportModel (20-ReportModel.ps1)
    ↓
Get-Bravo<Область>Audit  ×N  (30-39-* collector-и, заповнюють $script:Report.<Секція>)
    ↓
Update-BravoHealthScore (40-Health.ps1) — попередній розрахунок
    ↓
Export-BravoJsonReport / Export-BravoHtmlReport / Export-BravoCsvReport (50-54-*)
    ↓
Update-BravoHealthScore — фінальний перерахунок (враховує помилки export-етапів)
    ↓
Export-BravoJsonReport / Export-BravoHtmlReport — перегенерація з фінальною оцінкою
    ↓
Export-BravoZipReport, Send-BravoEmailReport
    ↓
Підсумок у консоль, ExitCode
```

## Конвенція collector-а

Кожен collector — одна функція `Get-Bravo<Область>Audit` з `[CmdletBinding()]` і `param()`, яка:

- читає/пише лише `$script:Report.<Секція>` (секція заздалегідь описана з дефолтними значеннями у `20-ReportModel.ps1`);
- обгортає кожну логічну підсекцію в `try { ... } catch { Add-AuditError -Section '<Секція>' -Message $_.Exception.Message }` — порожні `catch {}` заборонені, крім свідомо ігнорованих сценаріїв із поясненням-коментарем;
- додає знахідки через `Add-AuditFinding -Severity 'INFO|WARNING|CRITICAL' -Category '<Категорія>' -Message '...' -Recommendation '...'` (лише `WARNING`/`CRITICAL` впливають на Health Score);
- звертається до WMI/CIM лише через `Get-AuditObject` (CIM з fallback на WMI для старих ОС), дати конвертує через `Convert-AuditDateTime`;
- повільні або мережево-залежні перевірки гейтує профілем (`Deep`/`Forensic`) або окремим switch-параметром.

Повний перелік конвенцій і нумерації модулів — у `docs/AI_RULES.md` (розділи 3–4), він є джерелом істини для правил кодогенерації.

## Реальна структура `$script:Report`

Верхньорівневі секції (див. `New-BravoReportModel` у `src/20-ReportModel.ps1`):

```powershell
$script:Report = [ordered]@{
    SchemaVersion = '...'   # версія JSON-контракту, окремо від ScriptVersion
    Health = [ordered]@{ Score = 100; Status = ''; Findings = @() }
    OS = [ordered]@{}
    PowerShell = [ordered]@{}          # версія PS, PowerShell 7 (Core) side-by-side
    DotNet = [ordered]@{}              # .NET Framework 4.x, сумісність з ОС
    WindowsUpdate = [ordered]@{}       # hotfix-и, pending updates, Catalog-посилання
    BIOS = [ordered]@{}
    Hardware = [ordered]@{}            # CPU, RAM, Disks
    Network = [ordered]@{}
    Security = [ordered]@{}
    Users = [ordered]@{}
    Processes = [ordered]@{}
    Services = [ordered]@{}
    EventLogs = [ordered]@{}
    Software = [ordered]@{}
    USBDevices = @()
    CollectionErrors = @()
}
```

Зміна цієї структури — зміна контракту JSON: обов'язково супроводжується підняттям `SchemaVersion`, синхронним оновленням HTML/CSV-експорту і записом у `CHANGELOG.md` (`docs/AI_RULES.md` п.6).

## Принципи

- Жодних порожніх `catch {}`.
- Кожен collector повертає дані або контрольовану помилку в `CollectionErrors`.
- Скрипт не зупиняє весь аудит через помилку одного розділу.
- HTML/JSON/CSV/ZIP формуються з одного `$script:Report`.
- Для старих Windows — fallback WMI, для нових — CIM.
- Скрипт лишається **read-only аудитом**: не пише в registry/служби/файли поза `OutputPath` (`docs/AI_RULES.md` п.8).
- Маскування чутливих даних через `-Sanitize` — заплановане, ще не реалізоване (див. `docs/ROADMAP.md`).
