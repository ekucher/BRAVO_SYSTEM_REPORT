# Архітектура BRAVO SYSTEM REPORT

## Модель

Скрипт побудований як набір незалежних collector-модулів у `src/`, кожен з яких заповнює свою секцію спільного `$script:Report` і не зупиняє весь аудит через власну помилку. Генерація звітів (JSON/HTML/CSV/ZIP) відокремлена від збору даних: export-модулі лише читають вже заповнений `$script:Report`.

`src/*.ps1` конкатенуються build-скриптом (`Build-BRAVO-SystemReport.ps1`, за порядком у `src/BRAVO.build.json`) в один монолітний runtime-файл `dist/Get-BravoSystemReport.ps1`.

Кінцевий користувач викликає кореневий `Get-BravoSystemReport.ps1` (або `.bat`-лаунчери, які його викликають) — **тонкий transparent-passthrough wrapper**: він резолвить `OutputPath` (база — корінь репо, не `dist`) і форвардить `& dist\Get-BravoSystemReport.ps1 @ForwardParameters`, де `$ForwardParameters` будується з `$PSBoundParameters` (лише параметри, які користувач ЯВНО передав). Wrapper **не визначає власних дефолтів** для жодного параметра — єдине джерело дефолтів (`Profile`, `Zip` тощо) це `src/05-Params.ps1`. Це навмисний архітектурний принцип після стабілізаційного рефакторингу: wrapper і `dist` довго мали незалежні, вручну продубльовані `param()`-блоки, які розійшлись (різні дефолти `Profile`, втрачений forwarding `-Zip:$false`) — детально в `CHANGELOG.md` ("Stabilization P0").

## Потік виконання (`90-Main.ps1`)

```text
Parameters (05-Params.ps1) — єдине джерело дефолтів
    ↓
Elevation / self-relaunch as admin (форвардить ЕФЕКТИВНІ значення; після
    завершення елевованого процесу батьківський чекає його і прокидає
    реальний exit code, не завжди 0)
    ↓
$script:Report = New-BravoReportModel (20-ReportModel.ps1)
    ↓
Get-Bravo<Область>Audit  ×N  (30-39-* collector-и, заповнюють $script:Report.<Секція>)
    ↓
Update-BravoHealthScore (40-Health.ps1) — РІВНО ОДИН РАЗ, одразу після
    колекторів. Залежить лише від CollectionErrors + Findings — властивостей
    аудитованої машини, тому export-етапи нижче більше не можуть його змінити
    заднім числом (повторний перерахунок і self-zip-race, що існували через
    змішування CollectionErrors/ExportErrors, прибрані)
    ↓
Export-BravoJsonReport (перший запис — щоб потрапити в ZIP)
    ↓
Export-BravoHtmlReport / Export-BravoCsvReport / Export-BravoZipReport /
    Send-BravoEmailReport — помилки цих кроків пишуться в ExportErrors,
    НЕ в CollectionErrors, і НЕ впливають на Health Score
    ↓
Export-BravoJsonReport (повторний запис, лише якщо ExportErrors змінились —
    щоб файл на диску відображав фінальний стан)
    ↓
Підсумок у консоль, детермінований exit code (0/1/2/3/4/5):
    0 — успіх; 1 — Collection/ExportErrors; 2 — фатальна неопрацьована
    помилка (top-level trap); 3 — обов'язковий JSON не згенеровано;
    4 — лише -Strict: Health.Status = CRITICAL; 5 — Sanitize fail-closed
    (жоден звіт не записано)
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
    CollectionErrors = @()   # помилки ЗБОРУ (WMI/CIM/реєстр) — впливають на Health Score
    ExportErrors = @()       # помилки ЗАПИСУ звітів (JSON/HTML/CSV/ZIP/Email) — НЕ впливають на Health Score, впливають на exit code
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
- **Помилки збору vs помилки експорту**: `Add-AuditError` — для помилок колекторів (WMI/CIM/реєстр недоступні тощо), пише в `CollectionErrors`, впливає на Health Score. `Add-ExportError` — для помилок export-функцій (не вдалось записати JSON/HTML/CSV/ZIP, відправити email), пише в `ExportErrors`, НЕ впливає на Health Score (це проблема інструмента, не аудитованої машини), але впливає на exit code.
- **Exit code contract**: `0` — успіх, без помилок; `1` — завершено, але були `CollectionErrors`/`ExportErrors`; `2` — фатальна неопрацьована помилка (top-level `trap` у `90-Main.ps1`); `3` — обов'язковий JSON не згенеровано. Health Status (WARNING/CRITICAL) НЕ впливає на exit code — Health описує стан аудитованої машини, а не збій самого інструмента.
