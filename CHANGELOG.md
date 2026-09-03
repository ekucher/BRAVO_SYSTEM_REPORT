## v0.6.1 — 2026-09-03

### v0.6.0: Markdown summary

- Новий опційний параметр `-MD` (`src/05-Params.ps1`), форвардиться через wrapper і elevation-relaunch тим самим генеричним механізмом, що й `-TXT`.
- `Export-BravoMdReport` (`src/56-Export-Md.ps1`) генерує `$BaseFileName.md` — Markdown summary для Redmine/GitHub: заголовок, таблиця ключових метрик (OS/Uptime/CPU/RAM/Disk), таблиця findings через `Get-BravoFindingsGrouped` (PR #82, той самий формат сортування, що й TXT/HTML), таблиця collection errors якщо є.
- Закриває пункт ROADMAP "Markdown summary для Redmine/GitHub" — той самий принцип, що й TXT summary, але з таблицями Markdown замість plain text.
- `.md` додається в `GeneratedFiles`, тож потрапляє в ZIP-пакування, якщо `-Zip` активний. Не гейтується `-JSONOnly`.
- Тести: +2 E2E (`-MD` створює `.md` з очікуваними маркерами / без `-MD` файл не створюється).

### v0.6.0: TXT summary (закриває заодно Copy-friendly support summary)

- Новий опційний параметр `-TXT` (`src/05-Params.ps1`), форвардиться через wrapper і elevation-relaunch тим самим генеричним механізмом, що й решта параметрів.
- `Export-BravoTxtReport` (`src/55-Export-Txt.ps1`) генерує `$BaseFileName.txt` — plain-text summary: заголовок (ComputerName/Profile/Timestamp/Health Score/Status/StatusReason), ключові метрики (OS/Uptime/CPU/RAM/Disk коротко), findings через `Get-BravoFindingsGrouped` (PR #82, той самий формат сортування, що й HTML), collection errors якщо є.
- Закриває одразу два пункти ROADMAP: "TXT summary" і "Copy-friendly support summary" — той самий простий, легко-копійований у тікет підтримки файл.
- `.txt` додається в `GeneratedFiles`, тож потрапляє в ZIP-пакування, якщо `-Zip` активний. Не гейтується `-JSONOnly` (генерується прямо з моделі, не залежить від HTML).
- Тести: +2 E2E (`-TXT` створює `.txt` з очікуваними маркерами / без `-TXT` файл не створюється).

### v0.6.0: JSON schema documentation

- Новий `docs/SCHEMA.md` — навігаційна документація структури `$script:Report`: кожен верхньорівневий розділ моделі (`Meta`, `Dashboard`, `Health`, `OS`, `Hardware`, `Network`, `Security`, `EventLogs`, `Software`, `Updates` тощо) з коротким описом призначення, ключовими полями та посиланням на відповідний `src/3X-Collectors-*.ps1`. Не документує кожне поле дослівно — фокус на навігації для розробника, що вперше бачить схему.
- Розділ про `SchemaVersion` (поточне значення, семантика PATCH-інкременту) і явно сформульоване правило "нова/змінена форма моделі → бампнути SchemaVersion в тому самому коміті" — те саме правило, яке вже застосовувалось у кожному PR цієї сесії, тепер задокументоване в одному місці.
- Закриває одночасно два пункти ROADMAP: "JSON schema documentation" (v0.6.0 Reports and UX) і "Додати `docs/SCHEMA.md`" (Технічний борг) — той самий документ.
- Тести: +3 sanity (`tests/DocsSchema.Tests.ps1` — файл існує, згадує `SchemaVersion`, згадує кожен верхньорівневий розділ моделі).

### v0.6.0: Findings grouped by severity/category

- Нова чиста функція `Get-BravoFindingsGrouped` (`src/40-Health.ps1`) — сортує `Health.Findings` за severity (`CRITICAL` → `WARNING` → `INFO`, невідомий severity в кінець), потім за `Category`; рахує підсумкові лічильники `CriticalCount`/`WarningCount`/`InfoCount`. Покрита 5 unit-тестами (`tests/FindingsGrouped.Tests.ps1`).
- Вкладка Findings у HTML-звіті тепер показує findings у сортованому порядку (раніше — у порядку збору, без структури) + нові плитки-лічильники Critical/Warning/Info зверху таблиці (той самий стиль `storage-summary-grid`, що й на вкладці Hardware/Storage).
- Функція спроєктована для перевикористання в TXT/Markdown summary (наступні пункти v0.6.0 Reports and UX) — єдина точка групування для всіх форматів звіту.
- Тести: +5 unit +1 E2E (перевикористовує наявний Dark Mode E2E-прогін, без додаткового запуску).

### v0.6.1: Edge CLI PDF (закриває v0.6.1 повністю)

**v0.6.1 Interactive HTML Dashboard & Tabs секцію тепер повністю закрито.**

- Новий опційний параметр `-ExportPdf` (`src/05-Params.ps1`), форвардиться транспарентно через root wrapper і elevation-relaunch у `src/90-Main.ps1` (той самий генеричний `$ForwardParameters`/`$arguments` механізм, що й решта параметрів).
- `Get-BravoEdgeExecutablePath` (`src/51-Export-Html.ps1`) — шукає `msedge.exe` через PATH (`Get-Command`), потім два стандартних шляхи встановлення (`Program Files\Microsoft\Edge` і `Program Files (x86)\Microsoft\Edge` — Edge типово встановлюється як 32-bit застосунок навіть на 64-bit Windows).
- `Export-BravoPdfReport` — викликає `msedge.exe --headless --disable-gpu --print-to-pdf="<path>" --print-to-pdf-no-header <file:// URI HTML>` одразу після генерації HTML, до ZIP-пакування (щоб PDF встиг потрапити в `GeneratedFiles`).
- Відсутність Edge на машині — НЕ помилка збору/експорту (лише `[INFO]` у консоль), опційна фіча. Помилка самого виклику Edge (ненульовий exit code, PDF не з'явився) — `Add-ExportError 'Export.Pdf'`.
- `-JSONOnly` вимикає й PDF (нема з чого конвертувати — HTML взагалі не генерується).
- Тести: +1 unit (`Get-BravoEdgeExecutablePath`) +2 E2E (`-ExportPdf` створює `.pdf` якщо Edge присутній / без `-ExportPdf` `.pdf` не створюється).

### v0.6.1: Dark Mode

- CSS-змінні для card/nav/table поверхонь HTML-звіту (`--panel`, `--nav-bg`, `--btn-bg`, `--tab-panel-bg`, `--metric-card-bg`, `--toolbar-bg`, `--search-bg`, `--table-scroll-bg`, `--th-bg`, `--storage-item-bg`, `--progress-track`, `--title-text`) — заміняють раніше hardcoded hex-кольори в `src/51-Export-Html.ps1`.
- `@media (prefers-color-scheme: dark)` — дефолтна темна палітра без явного вибору користувача (system-рівень).
- `:root[data-theme="dark"]`/`[data-theme="light"]` override — явний вибір користувача перемагає системний дефолт в обидва боки.
- Кнопка `theme-toggle` в header (🌙/☀️), JS `toggleTheme()` перемикає атрибут `data-theme` на `<html>`.
- Вибір теми зберігається через `localStorage`, обгорнуто в try/catch — на `file://` протоколі деякі браузери обмежують доступ (SecurityError), тоді тема перемикається лише в межах поточної сесії перегляду, без збереження між відкриттями файлу (не критично, звіт відкривається offline).
- Print CSS (`@media print`) свідомо лишається завжди білим — для друку тема не має значення.

### v0.7.0 CI: Forensic -JSONOnly smoke test + HTML/JSONOnly validation (закриває v0.7.0 CI/Quality Gates повністю)

**v0.7.0 CI/Quality Gates тепер повністю закрито.**

- Новий `Describe 'v0.7.0 CI/Quality Gates — Forensic -JSONOnly smoke test / HTML-JSONOnly validation'` (`tests/ExecutionContract.Tests.ps1`), два `It`:
  - `-Profile Forensic -JSONOnly` -> exit code 0, JSON створено й валідний, HTML НЕ створено, `Profile='Forensic'`, `CollectionErrors=0`.
  - звичайний прогін БЕЗ `-JSONOnly` (`-Profile Quick`) -> і JSON, і HTML присутні.
- Без змін коду `src/`, без rebuild `dist`.

### v0.7.0 CI: Full runtime test

- Новий `Describe 'v0.7.0 CI/Quality Gates — Full runtime test'` (`tests/ExecutionContract.Tests.ps1`) — окремий наскрізний прогін `-Profile Full -Offline` (не Deep/Forensic, які вже переперевикористовуються всіма v0.5.0 Deep Inventory Describe-блоками). Перевіряє exit code 0, `CollectionErrors=0`/`ExportErrors=0`, JSON валідний, `Profile='Full'` у звіті, та Full-специфічні поля реально заповнені (не залишились дефолтом Quick): `Network.Adapters[].Status` (збагачення `Get-NetAdapter`, PR #60), `Hardware.Motherboard` (PR #59).
- М'яке твердження для Motherboard (Manufacturer АБО Product непорожні) — той самий принцип, що й у аналогічному Deep-тесті вище, деякі VM/hypervisor лишають `Manufacturer` порожнім.

### v0.7.0 CI: Parser check per-file для src/*.ps1

- Новий `tests/SourceParserCheck.Tests.ps1` — синтаксична перевірка КОЖНОГО `src/*.ps1` файлу окремо через `[System.Management.Automation.Language.Parser]::ParseFile` (той самий AST-based підхід, що й уже наявний крок "PowerShell parser check for dist" у `.github/workflows/local-windows-validation.yml`, застосований до окремих модулів, а не лише до зібраного монолітного `dist/Get-BravoSystemReport.ps1`).
- Перевага над "лише dist": помилка вказує на конкретний вихідний файл і рядок, а не на зсунуту позицію всередині згенерованого монолітного файлу.
- Жоден `src/*.ps1` не виконується (не dot-source) — лише токенізація/AST-парсинг, безпечно для модулів із побічними ефектами й залежністю від параметрів скрипту.
- Тест входить у звичайний `Invoke-Pester -Path tests`, тож автоматично запускається і локально, і в CI ("Run Pester tests" крок).

### Security Baseline: Scheduled tasks (закриває секцію повністю)

**Security Baseline секцію v0.5.0 Deep Inventory тепер повністю закрито.**

- **Security.ScheduledTasks[]** через `Get-ScheduledTask` — Name/Path/State/Author/Execute/Arguments/IsMicrosoftDefault. Гейтовано Deep/Forensic (`src/34-Collectors-Security.ps1`).
- Вбудовані задачі Windows (`TaskPath` під `\Microsoft\Windows\*`, типово 200-300+ на кожній машині) не приховуються з моделі — позначаються прапорцем `IsMicrosoftDefault=true`. HTML-таблиця за замовчуванням показує лише не-Microsoft задачі, з лічильником прихованих у заголовку — той самий принцип "дані видимі, findings обережні", що вже застосований для ARP/Storage ReservedVolumes.
- Sanitize: `Author` (часто `DOMAIN\username`) — категорія ADMIN (та сама, що й `LocalAdmins`/`AllowedUsers`). `Execute`/`Arguments` — категорія PATH (як і `Autoruns[].Command`).
- Модуль `Get-ScheduledTask` відсутній (деякі Server Core збірки) — штатний стан, порожній масив.
- Поле існувало як завжди-порожня заглушка; тепер реально заповнюється — `SchemaVersion` піднято `0.6.18` → `0.6.19`.
- HTML: нова таблиця 'Scheduled Tasks' на вкладці Security.
- Тести: +1 Sanitize +1 E2E.

### Security Baseline: Autoruns

- **Security.Autoruns[]** — реєстрові ключі Run/RunOnce у HKLM/HKCU (+ Wow6432Node на 64-bit) та папки автозавантаження User/AllUsers Startup. Кожен запис: Name/Command/Source/Hive. Гейтовано окремо `-Profile Deep/Forensic` (не Full — суттєво більший обсяг даних, ніж решта Security-блоку).
- Нова чиста функція `ConvertFrom-BravoRegistryKeyProperties` (`src/34-Collectors-Security.ps1`) витягує реальні Name/Value пари з `Get-ItemProperty`, відкидаючи службові `PS*`-метавластивості (`PSPath`/`PSParentPath`/`PSChildName`/`PSDrive`/`PSProvider`) — покрита 3 unit-тестами (`tests/RegistryKeyProperties.Tests.ps1`).
- `desktop.ini` у папках автозавантаження виключено — системний файл, не autorun-запис.
- Sanitize: `Autoruns[].Command` — категорія PATH (та сама, що й `Software.Installed[].InstallLocation`), маскується завжди (Basic) — команда часто містить повний шлях з профілю користувача.
- Поле існувало як завжди-порожня заглушка; тепер реально заповнюється — `SchemaVersion` піднято `0.6.17` → `0.6.18`.
- HTML: нова таблиця 'Autoruns' на вкладці Security.
- Тести: +3 unit +1 Sanitize +1 E2E.

### Security Baseline: UAC full policy

- **Security.UAC** розширено повною політикою (`HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`): `ConsentPromptBehaviorAdminCode`/`ConsentPromptBehaviorAdminText`, `ConsentPromptBehaviorUserCode`/`ConsentPromptBehaviorUserText`, `PromptOnSecureDesktop`, `FilterAdministratorToken`.
- Дві нові чисті функції `Get-BravoUacAdminPromptText`/`Get-BravoUacUserPromptText` (`src/34-Collectors-Security.ps1`) мапують DWORD-код у людяний опис (Elevate without prompting / Prompt for credentials/consent / ...) — покриті 6 unit-тестами (`tests/UacPromptText.Tests.ps1`).
- WARNING лише для найризикованішого `ConsentPromptBehaviorAdmin=0` ("Elevate without prompting" — підвищення привілеїв без запиту, повністю нівелює захист UAC). Відсутність налаштування (`$null`) — штатний дефолт групової політики, не помилка.
- Поля існували як завжди-порожня заглушка (`UAC=[ordered]@{Enabled=$false}`); тепер реально заповнюються — `SchemaVersion` піднято `0.6.16` → `0.6.17`.
- HTML: нова картка 'UAC full policy' на вкладці Security.
- Тести: +6 unit +1 E2E.

### fix: BitLocker/Secure Boot вимкнено — INFO, не WARNING; Storage Deep таблиця узгоджена з Findings

За результатами аналізу Health Score на реальному звіті виявлено дві проблеми:

1. **Дві знахідки штрафували Health Score/Status як реальні проблеми**, хоча є поширеним свідомим станом машини (dev-машина, десктоп без фізичного ризику крадіжки, обґрунтований виняток):
   - `Storage.BitLocker` — "Системний том C: не захищений BitLocker" (`src/32-Collectors-Storage.ps1`).
   - `Security.SecureBoot` — "Secure Boot підтримується, але вимкнено" (`src/34-Collectors-Security.ps1`).

   Обидві знахідки понижено з `WARNING` до `INFO` — інформація й далі публікується в звіті (`Health.Findings`), але `Update-BravoHealthScore` рахує в Score/Status лише `CRITICAL`/`WARNING`, тож `INFO`-знахідки більше не знижують оцінку і не переводять Status у `WARNING`.

2. **HTML-таблиця "Storage Deep" незалежно рахувала WARNING/CRITICAL** для томів без літери диска (WinRE/EFI/MSR), розбігаючись із Findings-зведенням вище на тій самій сторінці — `Get-BravoStorageRiskSummary` (`src/32-Collectors-Storage.ps1`, PR #54) вже виключає такі томи як `ReservedVolumes`, але сама таблиця "Storage Deep" (`src/51-Export-Html.ps1`) рахувала risk по тому самому FreePercent-порогу для ВСІХ томів, включно з майже завжди заповненим WinRE (~0.88 GB, 5.98% вільно → хибний WARNING). Виправлено: том без `DriveLetter` тепер отримує `RESERVED` (клас `risk-unknown`, той самий, що й "System-reserved" плитка в summary), а не `CRITICAL`/`WARNING` за порогом.

Без змін контракту моделі, без бампу SchemaVersion.

### Network Audit: ProcessName для з'єднань + SMB shares (закриває секцію повністю)

**Network Audit секцію тепер повністю закрито.**

- **ProcessName** для `Network.Connections.ListeningPorts[]` і нового **`Network.Connections.EstablishedConnections[]`** (LocalAddress/LocalPort/RemoteAddress/RemotePort/OwningProcess/ProcessName, до 200 записів, гейтовано Full/Deep/Forensic). Нова чиста функція `Get-BravoProcessNameLookup` будує PID->Name lookup з одного `Get-Process`-виклику (не по виклику на кожне з'єднання) — покрита 4 unit-тестами (`tests/ProcessNameLookup.Tests.ps1`).
- **Network.SmbShares[]** через `Get-SmbShare` — Name/Path/Description/ShareType/ScopeName/IsAdministrative. Адміністративні $-шари (C$/ADMIN$/IPC$) не приховуються — позначаються `IsAdministrative=true` (визначається як `Name -match '\$$'`), окрема корисна інформація для аудиту.
- Sanitize: `EstablishedConnections[].{LocalAddress,RemoteAddress}` — приватні IPv4, лише Strict (та сама категорія, що й `ListeningPorts[].LocalAddress`). `SmbShares[].Path` — категорія PATH (та сама, що й `Software.Installed[].InstallLocation`), маскується завжди (Basic) — шлях шари може містити username (`C:\Users\jdoe\Share`).
- Поля існували як завжди-порожні заглушки; тепер реально заповнюються — `SchemaVersion` піднято `0.6.15` → `0.6.16`.
- HTML: нові таблиці 'Listening Ports', 'Established Connections', 'SMB Shares' на вкладці Network.
- Тести: +4 unit (lookup) +2 Sanitize +3 E2E.

### Hardware Inventory: Monitors (закриває секцію повністю)

**Hardware Inventory секцію тепер повністю закрито.**

- **Hardware.Monitors[]** через `WmiMonitorID`/`WmiMonitorBasicDisplayParams` (namespace `root\wmi`) — Manufacturer/Model/SerialNumber/Active/WidthCm/HeightCm/YearOfManufacture/WeekOfManufacture. Гейтовано `-Profile Full/Deep/Forensic` (`src/31-Collectors-Hardware.ps1`).
- Нова чиста функція `ConvertFrom-BravoWmiMonitorCharArray` конвертує EDID UInt16-масиви символів (з нульовим заповненням у хвості) у звичайний рядок — покрита 4 unit-тестами (`tests/WmiMonitorCharArray.Tests.ps1`).
- Відсутність EDID-даних (VM/RDP-сесія без реального дисплея, або namespace недоступний) — штатний стан, свідомо НЕ `Add-AuditError`.
- Sanitize: `Monitors[].SerialNumber` маскується тією ж категорією `SERIAL`, що й BIOS/RAM/Disks (`src/45-Sanitize.ps1`).
- Поле існувало як завжди-порожня заглушка; тепер реально заповнюється — `SchemaVersion` піднято `0.6.14` → `0.6.15`.
- HTML: нова таблиця 'Monitors' на вкладці Hardware.
- Тести: +4 unit +1 Sanitize (Basic).

### v0.5.0 Deep Inventory: Hardware Diagnostics (Disk/Ntfs/StorPort/StorNVMe/WHEA/Kernel-Power/BugCheck)

**Останній пункт "Updates and Event Logs" v0.5.0 Deep Inventory. Уся секція v0.5.0 Deep Inventory (Hardware Inventory / Storage Audit / Network Audit / Security Baseline / Updates and Event Logs) тепер ПОВНІСТЮ закрита** (крім свідомо відкладених Autoruns/Scheduled tasks).

- **EventLogs.HardwareDiagnostics[]** — провайдер-специфічний зріз System log за 7 критичними драйверами/апаратними підсистемами: `disk`, `Ntfs`, `Microsoft-Windows-StorPort`, `stornvme`, `Microsoft-Windows-WHEA-Logger`, `Microsoft-Windows-Kernel-Power`, `Microsoft-Windows-WER-SystemErrorReporting` (BugCheck/краш-дампи). Гейтовано `-Profile Full/Deep/Forensic`.
- **Свідоме рішення**: кожен провайдер запитується ОКРЕМИМ `Get-WinEvent`-викликом, а не одним `FilterHashtable` з масивом `ProviderName` — перевірено локальним репро, що один незареєстрований провайдер (напр. `stornvme` на машині без NVMe) валить `NoMatchingProvidersFound` увесь комбінований запит, ховаючи дані решти провайдерів.
- `Status='NotAvailable'`, якщо провайдер не зареєстрований у системі (штатна апаратна відмінність — напр. немає ні StorPort, ні StorNVMe одночасно, залежно від контролера). `Status='Detected'` з `Count=0`, якщо провайдер є, але Critical/Error/Warning подій за період немає (здоровий стан). WARNING-finding при `Count>0`.
- Поле існувало як завжди-порожня заглушка; тепер реально заповнюється — `SchemaVersion` піднято `0.6.13` → `0.6.14`.
- HTML: нова таблиця 'Hardware Diagnostics' на вкладці Services.
- Тести: +1 E2E (`ExecutionContract.Tests.ps1`, той самий `-Profile Deep` прогін, перейменовано на `.../HardwareDiagnostics`).

### v0.5.0 Deep Inventory: Event Logs summary (System/Application/Setup/Security)

Три пункти v0.5.0 Deep Inventory / Updates and Event Logs в одному PR: per-log summary (System/Application/Setup/Security), Provider summary, Critical/Error/Warning grouping.

- Нова чиста функція `ConvertTo-BravoEventLogSummary` (`src/37-Collectors-Events.ps1`) групує вже отримані `Get-WinEvent`-записи в Critical/Error/Warning-лічильники й топ-10 провайдерів — винесена окремо від I/O, покрита 4 unit-тестами (`tests/EventLogSummary.Tests.ps1`).
- **EventLogs.LogSummaries[]** — по одному запису на кожен з 4 журналів (System/Application/Setup/Security): LogName/Status/CriticalCount/ErrorCount/WarningCount/TopProviders. Гейтовано `-Profile Full/Deep/Forensic` (4 окремих `Get-WinEvent`-запити дорожчі за Quick-профільний бюджет часу).
- **Свідоме рішення (locale-safety)**: "за період немає жодного запису" — штатний benign-результат `Get-WinEvent`, розпізнається за locale-незалежним `FullyQualifiedErrorId` (`NoMatchingEventsFound,Microsoft.PowerShell.Commands.GetWinEventCommand`), а НЕ за текстом винятку `.Exception.Message` (локалізується разом з MUI-пакетом Windows) — той самий принцип, що вже застосовувався для `Get-EventLog` вище в тому самому файлі.
- CRITICAL-finding, якщо будь-який з 4 журналів містить хоча б одну Critical-подію за період.
- Журнал відсутній (напр. Setup log на деяких Server Core збірках) або недоступний — `Status='Unavailable'`, окремо для цього журналу, решта журналів продовжують оброблятись.
- Поле вже існувало як завжди-порожня заглушка (`EventLogs.LogSummaries=@()`); тепер реально заповнюється — `SchemaVersion` піднято `0.6.12` → `0.6.13`.
- HTML: нові таблиці 'Event Logs: System / Application / Setup / Security' і 'Provider Summary' на вкладці Services.
- Sanitize: НЕ додано — узгоджено з уже наявним `EventLogs.TopErrorSources[].LastMessage` (System log), який теж не маскується; повідомлення подій журналів свідомо поза межами поточної Sanitize-моделі (як і раніше).
- Тести: +4 unit + 1 E2E (`ExecutionContract.Tests.ps1`, той самий `-Profile Deep` прогін, перейменовано на `.../EventLogSummary`).

### v0.5.0 Deep Inventory: SMART/NVMe health (останній пункт Storage Audit)

**Storage Audit секцію v0.5.0 Deep Inventory тепер повністю закрито.**

- **Hardware.Disks.Deep.ReliabilityCounters[]** через `Get-PhysicalDisk | Get-StorageReliabilityCounter` — Temperature/TemperatureMax/Wear/ReadErrorsTotal/ReadErrorsUncorrected/WriteErrorsTotal/WriteErrorsUncorrected/PowerOnHours на кожен фізичний диск. WARNING якщо є некориговані помилки читання/запису (однозначний сигнал апаратної проблеми, на відміну від Total-лічильників, які штатно >0) або Wear ≥ 90% (SSD/NVMe близько до кінця ресурсу).
- **Hardware.Disks.Deep.SmartPredictFailures[]** через легасі `MSStorageDriver_FailurePredictStatus` WMI-клас (`root\wmi`) — InstanceName/PredictFailure/Reason. Клас типово відсутній на NVMe/RAID-контролерах із власним драйвером (легасі ATA/SATA SMART API) — це штатне обмеження апаратури/драйвера, свідомо НЕ фіксується як `Add-AuditError`. CRITICAL-finding при `PredictFailure=True`.

Обидва — новий блок у `src/32-Collectors-Storage.ps1` (`Get-BravoStorageDeepAudit`), гейтовано `-Profile Deep/Forensic`.

- Поля вже існували як завжди-порожні заглушки в моделі даних; тепер реально заповнюються — `SchemaVersion` піднято `0.6.11` → `0.6.12`.
- HTML: нові таблиці "SMART / Reliability Counters" і "SMART Predictive Failure" на вкладці Hardware/Storage (`src/51-Export-Html.ps1`).
- Sanitize: не потрібен — `FriendlyName` (модель диска) і `DeviceId` (індекс) не є PII.
- 4 нових E2E Pester-тести в тому самому `Describe 'v0.5.0 Deep Inventory — ... / SMART'` (перейменовано), той самий `-Profile Deep` прогін.

### v0.5.0 Deep Inventory: Shadow Copies (VSS) + Storage Spaces

Два пункти v0.5.0 Deep Inventory / Storage Audit в одному PR: Shadow Copies/VSS, Storage Spaces. Заразом виявлено й позначено заднім числом уже реалізований раніше пункт "Pagefile" (`Win32_PageFileUsage`, був у коді, але не позначений у ROADMAP).

- **Shadow Copies / VSS** через `Win32_ShadowCopy` — `Hardware.Disks.Deep.ShadowCopies[]` (ID/VolumeName/InstallDate/ClientAccessible/Persistent). Відсутність точок відновлення — штатний стан, не помилка збору.
- **Storage Spaces** через `Get-StoragePool` — `Hardware.Disks.Deep.StoragePools[]` (FriendlyName/HealthStatus/OperationalStatus/SizeGB/AllocatedGB/IsReadOnly). Виключено прихований `IsPrimordial`-пул (представляє "сирі" фізичні диски системи, не реальний Storage Spaces пул — той самий принцип фільтрації шуму, що й Unreachable/Incomplete у ARP-кеші попереднього PR). WARNING якщо `HealthStatus` не `Healthy`. Модуль Storage відсутній (напр. деякі Server Core збірки) — штатний стан, порожній масив.

Обидва — новий блок у `src/32-Collectors-Storage.ps1` (`Get-BravoStorageDeepAudit`), гейтовано `-Profile Deep/Forensic`.

- Поля вже існували як завжди-порожні заглушки в моделі даних (`ShadowCopies`/`StoragePools` у `$storage`-об'єкті); тепер реально заповнюються — `SchemaVersion` піднято `0.6.10` → `0.6.11` за встановленим правилом (заповнення раніше завжди-порожнього поля вважається контрактною зміною).
- HTML: нові таблиці "Shadow Copies (VSS)" і "Storage Spaces" на вкладці Hardware/Storage (`src/51-Export-Html.ps1`).
- Sanitize: не потрібен — жодне з нових полів не містить MAC/IP/username (VolumeName — це шлях `\\?\Volume{guid}\`, FriendlyName — довільна назва пулу, не PII).
- 3 нових E2E Pester-тести в тому самому `Describe 'v0.5.0 Deep Inventory — ... / ShadowCopies+StoragePools'` (перейменовано), той самий `-Profile Deep` прогін.

### v0.5.0 Deep Inventory: Routing table + ARP + WinHTTP proxy

Три пункти v0.5.0 Deep Inventory / Network Audit в одному PR: Routing table, ARP/Neighbor table, WinHTTP proxy.

- **Routing table** через `Get-NetRoute` — `Network.Routing.RoutingTable[]` (до 200 записів).
- **ARP/Neighbor table** через `Get-NetNeighbor` — `Network.ARP[]` (до 200 записів, виключено Unreachable/Incomplete — тимчасові стани резолюції, не реальні записи кешу).
- **WinHTTP proxy** через `netsh winhttp show proxy` — `Network.WinHttpProxy.{RawOutput,Status}`.

Усі три — новий блок у `src/33-Collectors-Network.ps1`, гейтовано `-Profile Full/Deep/Forensic`.

- **Свідоме рішення (WinHTTP proxy)**: публікуємо сирий текстовий вивід `netsh` БЕЗ інтерпретації/парсингу — той самий локалізований-CLI принцип, що вже застосовувався для `auditpol` у попередньому PR: судити "проксі увімкнено/вимкнено" за англійською фразою на кшталт "Direct access (no proxy server)" було б ненадійно на не-EN системах.
- **Sanitize**: нові поля `Network.ARP[]`/`Network.Routing.RoutingTable[]` тепер теж маскуються (`src/45-Sanitize.ps1`) — MAC у ARP завжди (та сама категорія, що й `Adapters[].MACAddress`), IP-адреси в ARP і `DestinationPrefix`/`NextHop` у Routing table — лише в Strict (та сама категорія, що й решта приватних IPv4). Нові тест-кейси в `tests/Sanitize.Tests.ps1` (Basic і Strict).
- Нові поля моделі (`src/20-ReportModel.ps1`): `Network.Routing.RoutingTable`, `Network.ARP`, `Network.WinHttpProxy.{RawOutput,Status,Error}`. `SchemaVersion` піднято `0.6.9` → `0.6.10`.
- HTML: нова картка "WinHTTP Proxy" + нові таблиці "Routing Table" і "ARP Cache" на вкладці Network (`src/51-Export-Html.ps1`).
- 3 нових E2E Pester-тести в тому самому `Describe 'v0.5.0 Deep Inventory — ... / Routing+ARP+Proxy'` (перейменовано), той самий `-Profile Deep` прогін.

Усі 111 Pester-тестів проходять (106 попередніх + 5 нових). `dist` перебудовано, sha512 звірено.
### v0.5.0 Deep Inventory: Password policy + Audit policy

Десятий і одинадцятий пункти v0.5.0 Deep Inventory (Security Baseline) — останні два класичні compliance-показники цього розділу.

- **Password policy** через `net accounts`. Нова чиста функція `ConvertFrom-BravoNetAccountsOutput` парсить вивід за ФІКСОВАНОЮ ПОЗИЦІЄЮ рядка, а не за текстом мітки — `net.exe` локалізує самі мітки на не-EN збірках Windows, але порядок рядків фіксований у самому net.exe незалежно від мовного пакета. Покрито `tests/NetAccountsParsing.Tests.ps1` (3 тести, включно з симуляцією "локалізованого" виводу — інші мітки, той самий порядок рядків, той самий результат парсингу). Findings рахуються лише з числових значень (`[int]::TryParse`) — locale-безпечно, на відміну від текстових значень типу "Never"/"None"/"Unlimited".
- **Audit policy** через `auditpol /get /category:* /r`. Свідомо БЕЗ findings на основі тексту `Inclusion Setting` (напр. "No Auditing"/"Success and Failure") — ці значення локалізовані рядки `auditpol.exe`, на відміну від числових полів password policy; судити "недостатньо аудиту" за англійським текстом було б ненадійно на не-EN системах (той самий принцип, що вже застосовувався для RDP firewall-правил і `net accounts` у цій сесії) — просто публікуємо сирі дані.
- Findings: WARNING якщо мінімальна довжина пароля < 8; WARNING якщо lockout threshold = 0 (немає захисту від brute-force); WARNING якщо password history = 0 (дозволено миттєве повторне використання пароля).
- Нові поля моделі (`src/20-ReportModel.ps1`): `Security.PasswordPolicy.{MinPasswordLength,MaxPasswordAgeDays,MinPasswordAgeDays,PasswordHistoryLength,LockoutThreshold,LockoutDurationMinutes,LockoutObservationWindowMinutes,Status,Error}`, `Security.AuditPolicy.{Subcategories,TotalCount,Status,Error}`. `SchemaVersion` піднято `0.6.8` → `0.6.9`.
- HTML: нова картка "Password Policy" і нова таблиця "Audit Policy" на вкладці Security (`src/51-Export-Html.ps1`).
- 2 нових E2E Pester-тести в тому самому `Describe 'v0.5.0 Deep Inventory — ... / Password+Audit policy'` (перейменовано), той самий `-Profile Deep` прогін; + 3 unit-тести для `ConvertFrom-BravoNetAccountsOutput`.

Усі 106 Pester-тестів проходять (101 попередніх + 2 E2E + 3 unit). `dist` перебудовано, sha512 звірено. **Security Baseline у v0.5.0 Deep Inventory тепер повністю закрито** (крім свідомо відкладених Autoruns/Scheduled tasks — більший обсяг даних).
### v0.5.0 Deep Inventory: RDP NLA/scope + WinRM + SMB signing

Сьомий, восьмий і дев'ятий пункти v0.5.0 Deep Inventory (Security Baseline) — три remote-access security перевірки в одному PR.

- **RDP details**: NLA, port, firewall scope, дозволені користувачі. Firewall-правило шукається за незалежним від локалізації ім'ям `RemoteDesktop-UserMode-In-TCP` (не за `DisplayGroup`/`DisplayName`, які на не-EN збірках Windows перекладені й ненадійні для програмного пошуку — перевірено вручну на UA-локалізованій машині, `Get-NetFirewallRule -DisplayGroup 'Remote Desktop'` не знаходить нічого). WARNING якщо NLA не вимагається; WARNING якщо `RemoteAddress=Any` у Public-профілі фаєрвола.
- **WinRM**: listeners (`WSMan:\localhost\Listener`) і auth-методи (`WSMan:\localhost\Service\Auth`) — лише коли служба `WinRM` реально `Running` (інакше WSMan-провайдер недоступний). WARNING якщо Basic auth увімкнено; WARNING якщо CredSSP увімкнено.
- **SMB signing / insecure guest access**: `Get-SmbServerConfiguration`/`Get-SmbClientConfiguration`. WARNING якщо server signing не обов'язковий (`RequireSecuritySignature=False`); WARNING якщо `EnableInsecureGuestLogons=True`.
- Усі три — гейтовано `-Profile Full/Deep/Forensic`; RDP-блок додатково виконується лише коли `RDPEnabled=True` (немає сенсу перевіряти NLA/scope на вимкненому RDP).
- **Sanitize**: нове поле `Security.RemoteAccess.AllowedUsers` (список імен облікових записів — та сама категорія чутливості, що й `Users.LocalAdmins`) тепер теж маскується (`src/45-Sanitize.ps1`, той самий `$maskAdmin`), і в Basic, і в Strict рівні. Новий тест-кейс у `tests/Sanitize.Tests.ps1`.
- Нові поля моделі (`src/20-ReportModel.ps1`): `Security.RemoteAccess.{NLAEnabled,Port,FirewallScope,FirewallProfiles,AllowedUsers}`, `Security.WinRM.{ServiceStatus,Listeners,Auth,Status,Error}`, `Security.SMB.{ServerSigningRequired,ServerSigningEnabled,ClientSigningRequired,InsecureGuestLogonsEnabled,Status,Error}`. `SchemaVersion` піднято `0.6.7` → `0.6.8`.
- HTML: три нові картки — "RDP details", "WinRM", "SMB signing" на вкладці Security (`src/51-Export-Html.ps1`).
- 3 нових E2E Pester-тести в тому самому `Describe 'v0.5.0 Deep Inventory — ... / RDP / WinRM / SMB signing'` (перейменовано), той самий `-Profile Deep` прогін.

Усі 101 Pester-тест проходить (98 попередніх + 3 нових). `dist` перебудовано, sha512 звірено.
### v0.5.0 Deep Inventory: Defender details

Шостий пункт v0.5.0 Deep Inventory (Security Baseline) — деталі Windows Defender.

- `Get-MpComputerStatus` — новий блок у `src/34-Collectors-Security.ps1`, гейтовано `-Profile Full/Deep/Forensic`. Real-Time Protection, Behavior Monitor, версії сигнатур/engine/product, вік сигнатур у днях (`AntivirusSignatureAgeDays`, обчислюється з `AntivirusSignatureLastUpdated`).
- Findings: WARNING якщо Real-Time Protection вимкнено; WARNING якщо сигнатури старіші 7 днів.
- **Свідоме рішення**: НЕ звіряємо стан Defender з `Security.Antivirus.Product` (окрема, вже зібрана SecurityCenter2-знахідка про активний AV) — Defender у passive mode (типово, коли активний сторонній антивірус) законно показує `RealTimeProtectionEnabled=$false`, і спроба "вгадати, чи це нормально" за непрямими ознаками дала б крихкий, ненадійний результат; звіт лише констатує факт, висновок — за адміністратором.
- Defender вимкнено GPO/сторонім антивірусом або взагалі відсутній (Server Core без feature) — штатний стан машини (`Status='Unavailable'`/`'NotAvailable'`), не помилка збору.
- Нові поля моделі (`src/20-ReportModel.ps1`): `Security.Defender.{Available,AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,BehaviorMonitorEnabled,AntivirusSignatureVersion,AntivirusSignatureLastUpdated,AntivirusSignatureAgeDays,AMEngineVersion,AMProductVersion,Status,Error}`. `SchemaVersion` піднято `0.6.6` → `0.6.7`.
- HTML: нова картка "Windows Defender" на вкладці Security (`src/51-Export-Html.ps1`).
- 2 нових E2E Pester-тести в тому самому `Describe 'v0.5.0 Deep Inventory — ... / Defender'` (перейменовано), той самий `-Profile Deep` прогін.

Усі 98 Pester-тестів проходять (96 попередніх + 2 нових). `dist` перебудовано, sha512 звірено.
### v0.5.0 Deep Inventory: SMBv1 + TLS registry status

П'ятий пункт v0.5.0 Deep Inventory (Security Baseline) — два класичні security-показники.

- **SMBv1** через `Get-SmbServerConfiguration` (`EnableSMB1Protocol`) — новий блок у `src/34-Collectors-Security.ps1`, гейтовано `-Profile Full/Deep/Forensic`. WARNING-finding, якщо увімкнено (застарілий, вразливий протокол — EternalBlue/WannaCry). Модуль `SmbShare` відсутній (застарілий Windows) -> `Security.SMBv1.Status='NotAvailable'`, не помилка збору.
- **TLS registry status** (TLS 1.0/1.1/1.2/1.3, Client+Server — 8 записів) через SCHANNEL registry (`HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\<protocol>\<side>`). Нова чиста функція `Get-BravoTlsProtocolStatus` інтерпретує пару `Enabled`/`DisabledByDefault` DWORD у `Enabled`/`Disabled`/`NotConfigured` за документованою Microsoft семантикою; покрито 6 unit-тестами (`tests/TlsProtocolStatus.Tests.ps1`).
- Findings лише для явних відхилень від безпечного дефолту: TLS 1.0/1.1 явно увімкнено через реєстр (WARNING) або TLS 1.2 явно вимкнено (WARNING, ризик сумісності). `NotConfigured` (найпоширеніший стан — адмін нічого не змінював, діє ОС-дефолт) НЕ породжує finding.
- Нові поля моделі (`src/20-ReportModel.ps1`): `Security.SMBv1.{Enabled,Status,Error}`, `Security.TLS.Protocols[].{Protocol,Side,Enabled,DisabledByDefault,Status}`. `SchemaVersion` піднято `0.6.5` → `0.6.6`.
- HTML Dashboard: SMBv1 додано до картки "Secure Boot / TPM / SMBv1", нова таблиця "TLS registry status" на вкладці Security (`src/51-Export-Html.ps1`).
- 2 нових E2E Pester-тести в тому самому `Describe 'v0.5.0 Deep Inventory — ... / SMBv1 / TLS'` (перейменовано), той самий `-Profile Deep` прогін.

Усі 96 Pester-тестів проходять (88 попередніх + 6 unit + 2 E2E). `dist` перебудовано, sha512 звірено.
### v0.5.0 Deep Inventory: Network adapters speed/status/driver

Четвертий пункт v0.5.0 Deep Inventory (Network Audit) — деталі мережевих адаптерів.

- `Get-NetAdapter` у `src/33-Collectors-Network.ps1`, гейтовано `-Profile Full/Deep/Forensic` (той самий принцип, що й RAM.Modules/Chassis/Motherboard/GPU у попередніх PR цієї сесії) — збагачує вже наявні записи `Network.Adapters[]` (побудовані з `Win32_NetworkAdapterConfiguration`, `IPEnabled=True`) за MAC-адресою: `LinkSpeed`, `Status`, `DriverVersion`, `DriverProvider`.
- **Свідоме архітектурне рішення**: збагачення відбувається лише для вже наявних адаптерів (з IP), НЕ додає нові рядки з `Get-NetAdapter` для адаптерів без IP (вимкнені/від'єднані) — інакше змінилась би семантика поля "Adapters" з "інтерфейси з IP" на "усі мережеві інтерфейси в системі", що є окремою потенційною задачею, не цим пунктом ROADMAP.
- `SchemaVersion` піднято `0.6.4` → `0.6.5`.
- HTML: таблиця Network Adapters отримала колонки Link Speed/Status/Driver (`src/51-Export-Html.ps1`).
- 1 новий Pester-тест у тому самому `Describe 'v0.5.0 Deep Inventory — ... / Network Adapters'` (перейменовано), той самий `-Profile Deep` E2E-прогін.

Усі 88 Pester-тестів проходять (87 попередніх + 1 новий). `dist` перебудовано, sha512 звірено.
### v0.5.0 Deep Inventory: Chassis type, Motherboard, GPU

Третій пункт v0.5.0 Deep Inventory (Hardware Inventory) — базові дані про корпус, материнську плату й відеокарти.

- **Chassis type** через `Win32_SystemEnclosure.ChassisTypes[0]` + нова чиста функція `Get-BravoChassisTypeText` (SMBIOS chassis type code -> людяний опис, невідомий код -> `"Unknown ($code)"`, не помилка).
- **Motherboard** через `Win32_BaseBoard`.
- **GPU** через `Win32_VideoController` (масив — підтримка multi-GPU систем).
- Усі три — новий блок у `src/31-Collectors-Hardware.ps1`, гейтовано `-Profile Full/Deep/Forensic` (той самий блок, що вже збирав `RAM.Modules`).
- Нові поля моделі (`src/20-ReportModel.ps1`): `Hardware.ComputerSystem.{ChassisType,ChassisTypeCode}`, `Hardware.Motherboard.{Manufacturer,Product,SerialNumber,Version}`, `Hardware.GPU[].{Name,AdapterRAMBytes,DriverVersion,VideoProcessor,CurrentResolution,Status}`. `SchemaVersion` піднято `0.6.3` → `0.6.4`.
- **Відоме обмеження WMI** (задокументовано в коді й ROADMAP, не "виправляється" здогадками): `Win32_VideoController.AdapterRAM` — 32-bit DWORD, для карт з >4 GB VRAM значення переповнюється/спотворюється (напр. RTX 3060 12GB показує ~4GB) — публікується як є (`AdapterRAMBytes`).
- HTML Dashboard: нова картка "System / Motherboard" і нова таблиця "GPU" на вкладці Hardware (`src/51-Export-Html.ps1`).
- 3 нових Pester-тести в тому самому `Describe 'v0.5.0 Deep Inventory — ... / Hardware Inventory'` (`tests/ExecutionContract.Tests.ps1`, перейменовано), той самий `-Profile Deep` E2E-прогін — без додаткового окремого прогону.

Усі 87 Pester-тестів проходять (84 попередніх + 3 нових). `dist` перебудовано, sha512 звірено.
### v0.5.0 Deep Inventory: BitLocker status

Другий пункт v0.5.0 Deep Inventory (Storage Audit) — статус шифрування томів.

- **BitLocker** через `Get-BitLockerVolume` — новий блок у `Get-BravoStorageDeepAudit` (`src/32-Collectors-Storage.ps1`), заповнює раніше завжди порожнє поле `Hardware.Disks.Deep.BitLocker[]` (гейтовано `-Profile Deep/Forensic`, так само як решта Storage Deep Audit). Поля на кожному томі: `MountPoint`, `VolumeType`, `CapacityGB`, `VolumeStatus`, `EncryptionPercentage`, `EncryptionMethod`, `ProtectionStatus`, `LockStatus`, `AutoUnlockEnabled`.
- `SchemaVersion` піднято `0.6.2` → `0.6.3` (адитивне збагачення контракту: поле існувало, тепер має визначену форму об'єктів замість завжди порожнього масиву).
- Findings: WARNING лише для незахищеного (`ProtectionStatus=Off`) **системного** тому — свідомо НЕ для data-томів, інакше WARNING спрацьовував би на кожній звичайній робочій станції без керованого шифрування (той самий принцип, що й WinRE-фікс раніше в цій сесії).
- Відсутність модуля BitLocker (Windows Home edition, деякі Server Core збірки) — штатний стан, `Hardware.Disks.Deep.BitLocker` лишається порожнім масивом, не `Add-AuditError`.
- HTML Dashboard: нова таблиця "BitLocker" на вкладці Hardware, одразу після Storage Deep (`src/51-Export-Html.ps1`).
- Тест-блок `Describe 'v0.5.0 Deep Inventory — Secure Boot / TPM / BitLocker'` (`tests/ExecutionContract.Tests.ps1`) переведено з `-Profile Full` на `-Profile Deep` — той самий E2E-прогін тепер покриває й BitLocker (гейтовано лише Deep/Forensic), без другого окремого прогону; додано 1 новий тест.

Усі 84 Pester-тести проходять (83 попередніх + 1 новий). `dist` перебудовано, sha512 звірено.
### v0.5.0 Deep Inventory: Secure Boot + TPM

Перший пункт v0.5.0 Deep Inventory (Hardware Inventory) — Deep Security базові дані.

- **Secure Boot** (`Confirm-SecureBootUEFI`) і **TPM** (`Win32_Tpm` CIM-клас у `root\cimv2\Security\MicrosoftTpm`) — новий блок у `src/34-Collectors-Security.ps1`, гейтовано `-Profile Full/Deep/Forensic` (не критично для найшвидшого Quick-профілю).
- Нові поля моделі (`src/20-ReportModel.ps1`): `Security.SecureBoot.{Supported,Enabled,Status,Error}`, `Security.TPM.{Present,Ready,Enabled,Activated,ManufacturerId,ManufacturerVersion,SpecVersion,Status,Error}`. `SchemaVersion` піднято `0.6.1` → `0.6.2` (адитивна зміна контракту, п.6 `docs/AI_RULES.md`).
- **Свідоме рішення**: Legacy BIOS (Secure Boot фізично неможливий) і відсутність TPM (VM без vTPM, старе обладнання) — штатні стани машини (`Status = 'NotSupported'`/`'NotPresent'`), НЕ `Add-AuditError` — інакше кожна VM чи Legacy BIOS машина отримувала б `CollectionErrors > 0` і, як наслідок, exit code 1 за замовчуванням (той самий принцип, що й для WinRE-розділів раніше в цій сесії).
- Findings: WARNING, якщо Secure Boot підтримується, але вимкнено; WARNING, якщо TPM присутній, але не увімкнений/активований повністю (`Ready = Enabled -and Activated`).
- HTML Dashboard: нова картка "Secure Boot / TPM" на вкладці Security (`src/51-Export-Html.ps1`). CSV: `SecureBoot_Status`/`TPM_Status` (`src/52-Export-Csv.ps1`).
- 4 нових Pester-тести (`tests/ExecutionContract.Tests.ps1`, `Describe 'v0.5.0 Deep Inventory — Secure Boot / TPM'`): наскрізний `-Profile Full -Offline` прогін, `CollectionErrors=0`, `Status` завжди в очікуваному переліку значень (ніколи не лишається `NotChecked`), узгодженість `TPM.Present`/`Ready` при `Status=Detected`.

Усі 83 Pester-тести проходять (79 попередніх + 4 нових). `dist` перебудовано, sha512 звірено.

### v0.4.1 Release Stabilization: перевірка release package + docs/RELEASE.md

- Новий `tests/ReleasePackage.Tests.ps1` (5 тестів): `tools/New-ReleasePackage.ps1` створює ZIP -> розпаковується у temporary directory -> запускається `BRAVO-SystemReport-Quick.bat --nopause` з розпакованого пакета -> перевіряється створення валідного JSON/HTML, sha512 runtime всередині пакета, sha256 самого ZIP, наявність усіх `.bat`-лаунчерів і `MANIFEST.txt`.
- **Побічно спіймано й виправлено реальний баг** у `tools/New-ReleasePackage.ps1`, який до цього ніколи не запускався в CI: на self-hosted раннері з коротким 8.3-ім'ям облікового запису (`BRAVOR~1`) ручна арифметика `.Substring($StagingRoot.Length)` при формуванні імен файлів у ZIP з'їжджала - файли пакувались з "хвостом" шляху (напр. `5.1/BRAVO-SystemReport-Quick.bat` замість `BRAVO-SystemReport-Quick.bat`). Відтворено локально (штучний 8.3-каталог), виправлено на `Push-Location` + `Resolve-Path -Relative` (робастно незалежно від форми проміжних сегментів шляху).
- Новий `docs/RELEASE.md`: локальний release-флоу + опис фактичної роботи `.github/workflows/release.yml`, таблиця типових причин падіння.
- Побічно: `docs/SECURITY.md` більше не називає `-Sanitize` "майбутнім" параметром.

Усі 79 Pester-тестів проходять (74 попередніх + 5 нових). `dist` перебудовано, sha512 звірено. Закриває решту ROADMAP v0.4.1 Release Stabilization.
### P1/v0.4.3: CI validation для -Sanitize (закриває останній пункт v0.4.3)

- Новий блок `Describe 'P1 — CI validation для -SanitizeLevel Strict'` у `tests/ExecutionContract.Tests.ps1` (6 тестів): наскрізний прогін через wrapper з `-Profile Full -Sanitize -SanitizeLevel Strict -Offline`, перевіряє exit code 0, валідність структури JSON після маскування (`CollectionErrors`/`ExportErrors` = 0), і точково — що `ComputerName`/`Meta.UserName`/`Meta.UserDomainName`/`Network.General.Hostname`/`Dashboard.Header.ComputerName` замасковані у відповідний `REDACTED-*` формат, `Network.IP.IPv4`/`PrimaryIPv4`/adapters IPv4 замасковані, MAC-адреси замасковані (плюс regex-перевірка відсутності будь-якого literal MAC-патерну в сирому JSON), серійні номери BIOS/PhysicalDisks замасковані, і що HTML-експорт теж містить `REDACTED-*` токени (маскування дійшло до export-етапу, не лише до JSON).
- **Свідомо відхилено** підхід "сліпий regex-скан усього JSON/HTML на IPv4-патерн", запропонований у ROADMAP: перевірено вручну на реальному звіті (`-Profile Full`) — версії встановленого ПЗ (`Software.Installed[].Version`, напр. `10.0.11.50`) масово збігаються з форматом IPv4 (кожен октет ≤255) і дають десятки false positive. Замінено на точкові перевірки конкретних полів схеми, які реально маскує `Invoke-BravoReportSanitization`.
- Аналогічно відхилено "сліпий full-text-скан на $env:USERNAME" — перша версія тесту саме так і впала: `OutputPath` (шлях збереження звіту під профілем Windows-користувача, напр. `C:\Users\<username>\AppData\Local\Temp\...`) легітимно й свідомо НЕ маскується Sanitize (це операційний шлях, не PII про аудитовану машину), тож завжди міститиме `$env:USERNAME` як частину шляху профілю — замінено на структурну перевірку конкретних полів моделі.

Усі 74 Pester-тести проходять (68 попередніх + 6 нових). `dist` перебудовано, sha512 звірено. Закриває останній відкритий пункт ROADMAP v0.4.3 Safe Sharing (окрім свідомо відкладеного "service account names" — колектор служб не збирає ці дані).

### fix: false-positive WARNING на WinRE/EFI-розділах без літери диска

- **Проблема**: Get-BravoStorageRiskSummary (src/32-Collectors-Storage.ps1) оцінював томи без літери диска (Windows Recovery Environment partition, EFI System Partition) тими самими порогами вільного місця (5%/10%), що й звичайні томи з даними. WinRE Partition — фіксованого розміру (типово ~0.5-1 GB) і майже завжди заповнений на 90%+ образом відновлення, недоступний користувачу через Провідник чи звичайне очищення файлів. Це породжувало WARNING finding (`Storage.FreeSpace`) практично на КОЖНІЙ Windows 10/11 машині — systematic false positive, що штучно знижував Health Score.
- **Фікс**: томи без `DriveLetter` тепер виносяться в окремий бакет `ReservedVolumes` (`Summary.ReservedCount`) — не потрапляють у `CriticalVolumes`/`WarningVolumes`, не викликають `Add-AuditFinding`, не впливають на Health Score. Дані про них лишаються видимими в таблиці `Storage Deep` (HTML), і в Dashboard додано окрему плитку "System-reserved (без літери)" (`src/51-Export-Html.ps1`) — щоб не ховати інформацію мовчки, а явно показати, що ці томи свідомо виключені з ризик-оцінки.
- Нові тести в `tests/StorageThresholds.Tests.ps1` (`Describe 'Get-BravoStorageRiskSummary'`, 3 тести): том без літери з 5.98% вільного НЕ породжує finding; той самий % З літерою диска — далі породжує Warning; том без літери з достатнім вільним місцем потрапляє у `ReservedVolumes`, а не `HealthyVolumes`.

Усі 68 Pester-тестів проходять (65 попередніх + 3 нових). `dist` перебудовано, sha512 звірено.

### docs: закрито пункт "уніфікувати network schema" (ROADMAP v0.4.2)

Пункт ROADMAP "Уніфікувати network schema" перевірено і закрито без змін коду — станом на 2026-09-02 у кодовій базі й так немає top-level дублікатів `Network.IPv4`/`Network.PrimaryIPv4`/`Network.PublicIPv4`. Єдине джерело правди — вкладена структура `Network.IP.{IPv4, PrimaryIPv4, PrimaryInterface, PublicIPv4*}`, оголошена в `src/20-ReportModel.ps1` і послідовно використовувана в `src/33-Collectors-Network.ps1`, `src/45-Sanitize.ps1`, `src/51-Export-Html.ps1`, `src/52-Export-Csv.ps1`. Історичні баги з неправильним шляхом (`Network.PrimaryIPv4` замість `Network.IP.PrimaryIPv4`) вже виправлені в попередніх раундах (див. записи нижче про CI/HTML export).

### P1/v0.4.3: -Sanitize / -SanitizeLevel (маскування чутливих даних)

П'ятий пункт P1 / v0.4.3 Safe Sharing — маскування чутливих даних перед передачею звіту третім сторонам.

- **Новий модуль `src/45-Sanitize.ps1`**: `Invoke-BravoReportSanitization -Report $script:Report -Level Basic|Strict` — одна точка застосування, що виконується в `src/90-Main.ps1` одразу після `Update-BravoHealthScore` (маскування не впливає на Score/Status — рахунок уже фінальний) і ДО будь-якого export'а. Оскільки JSON/HTML/CSV/Email усі читають той самий `$script:Report`, один прохід покриває всі формати одразу — перевірено (CSV/Email читають `$script:Report.ComputerName` напряму, не дублюють `$env:COMPUTERNAME`).
- **`New-BravoSanitizeMasker`** — чиста функція-фабрика: кожна категорія (computer name, user, domain, DNS suffix, public IP, MAC, serial, admin, install path, private IP) отримує власний маскер із замиканням-станом. Те саме вхідне значення завжди дає той самий токен (`REDACTED-<PREFIX>-<N>`) у межах одного звіту — зберігає читабельність ("той самий MAC у трьох місцях") без розкриття реальних даних.
- **`-Sanitize`** (`src/05-Params.ps1`) вмикає маскування; **`-SanitizeLevel Basic|Strict`** (дефолт `Basic`) визначає обсяг. `Basic` маскує: computer name, user name, domain/workgroup, DNS suffix, public IPv4, MAC-адреси, серійні номери (BIOS/RAM/PhysicalDisks/Storage Deep Audit), локальних адміністраторів, install path ПЗ. `Strict` додає: приватні IPv4 (IP-масив, PrimaryIPv4, PrimaryInterface, adapters, routing/gateway/DNS-сервери, listening ports).
- Обидва параметри форвардяться через wrapper і elevation relaunch (`src/90-Main.ps1`), за патерном попередніх P1 параметрів.
- **Свідомо НЕ реалізовано**: "service account names" з чекліста ТЗ — колектор служб не збирає LogOnAs/StartName, маскувати нема чого (позначено в `docs/ROADMAP.md`). Ім'я файлу звіту (`BravoSystemReport_<COMPUTERNAME>_...`) і далі містить реальну назву машини — маскується лише вміст файлів.
- Новий `tests/Sanitize.Tests.ps1` (12 тестів): чисті unit-тести `New-BravoSanitizeMasker` і `Invoke-BravoReportSanitization` (Basic/Strict) на фейковому об'єкті звіту, без залежності від WMI/CIM.
- Новий блок у `tests/ExecutionContract.Tests.ps1` (2 тести): наявність `-Sanitize`/`-SanitizeLevel` у wrapper; наскрізний прогін `-Sanitize` через wrapper — підтверджено, що реальна назва машини (`$env:COMPUTERNAME`) не потрапляє у JSON-файл на диску.

Усі 65 Pester-тестів проходять (51 попередніх + 14 нових). `dist` перебудовано, sha512 звірено.

### P1/v0.4.2: -Strict (exit code 4 на CRITICAL Health.Status)

Четвертий пункт P1 / v0.4.2 Runtime Quality — режим strict validation.

- **Раніше**: `Health.Status` (`OK`/`WARNING`/`CRITICAL`) свідомо НЕ впливав на exit code — задокументована властивість контракту (P0.5): exit code відображає стан ІНСТРУМЕНТА (чи зміг зібрати/записати дані), не стан АУДИТОВАНОЇ машини. Для CI-гейтів, яким потрібен ненульовий exit code саме на "машина в критичному стані" (наприклад, security-скан у пайплайні), такого способу не було.
- **Новий `-Strict`** (`src/05-Params.ps1`): у цьому режимі, якщо аудит завершився без `CollectionErrors`/`ExportErrors`, але `Health.Status = CRITICAL` — exit code стає `4` (новий, окремий від існуючих 0/1/2/3). Без `-Strict` поведінка не змінюється (backward-compatible, опційна). Форвардиться через wrapper (transparent passthrough) і elevation relaunch (`src/90-Main.ps1`, за патерном `-SkipPublicIP`/`-Offline`).
- `README.md`: оновлено таблицю exit code contract, додано рядок `4` і пояснення `-Strict`.
- Свідомо НЕ реалізовано (залишено відкритим у `docs/ROADMAP.md`): розділення `CollectionErrors`/`ExportErrors` на "критичні"/"некритичні" з різними exit code, і окремі коди для parser/build/runtime/export failures — існуючий контракт (1=помилки збору/експорту, 2=fatal trap, 3=JSON не згенеровано) лишається як є, `-Strict` додає лише вимір Health.Status.
- Новий блок тестів у `tests/ExecutionContract.Tests.ps1` (3 тести): наявність `-Strict` у wrapper, без `-Strict` CRITICAL не впливає на exit code (лишається 0), з `-Strict` CRITICAL → exit code 4. Тести умовні на реальний `Health.Status` тестової машини (не мокають дані) — на цій сесії підтверджено фактичним прогоном (машина реально CRITICAL, exit code 4 отримано).

Усі 51 Pester-тест проходить (48 попередніх + 3 нових). `dist` перебудовано, sha512 звірено.

### P1: параметри -Offline та -SkipGeoIP

Третій пункт P1 / v0.4.3 Safe Sharing — контроль над зовнішніми HTTPS-запитами скрипта.

- **Раніше**: `-SkipPublicIP` вимикав ОДНОЧАСНО і визначення Public IPv4, і geo/ISP-лукап (`ipapi.co`) — не було способу лишити Public IPv4 у звіті, не відправляючи її третій стороні для геолокації. Окремого "вимкнути все мережеве одразу" також не було — доводилось комбінувати `-SkipPublicIP -SkipUpdateSearch`.
- **Новий `-SkipGeoIP`** (`src/05-Params.ps1`): визначає Public IPv4 як і раніше, але не викликає `Get-BravoPublicIPv4ProviderInfo` (запит до `ipapi.co` з публічною IPv4 в URL) — `PublicIPv4ProviderInfoStatus` стає `Skipped` з причиною в `PublicIPv4ProviderInfoError`.
- **Новий `-Offline`** (`src/05-Params.ps1`): єдиний перемикач, що вимикає геть усі зовнішні HTTPS-запити скрипта одночасно — Public IPv4 (`src/33-Collectors-Network.ps1`), GeoIP і онлайн-пошук оновлень (`src/39-Collectors-Updates.ps1`, той самий гейт, що й `-SkipUpdateSearch`).
- Обидва параметри форвардяться через wrapper (transparent `$PSBoundParameters` passthrough, P0.1) і через elevation relaunch (`src/90-Main.ps1`, ручний CLI-forwarding — додано явні рядки, за тим самим патерном, що й `-SkipPublicIP`).
- `README.md` оновлено (таблиця параметрів Updates-секції, "Плани розвитку").
- Новий тест у `tests/ExecutionContract.Tests.ps1`: `-Offline` через wrapper з профілем `Full` (де Public IP інакше виконувався б) → `Network.IP.PublicIPv4Status`/`PublicIPv4ProviderInfoStatus`/`Updates.Search.Status` усі `Skipped`, exit code 0.

Усі 48 Pester-тестів проходять (46 попередніх + 2 нових: наявність параметрів у wrapper, наскрізна поведінка `-Offline`). `dist` перебудовано, sha512 звірено.

### P1: CPU/RAM findings, узгодження Disk threshold у Health Score

Другий пункт P1 — CPU/RAM findings, за тим самим патерном, що й попередній storage thresholds PR.

- **Проблема**: `Get-BravoHardwareAudit` (`src/31-Collectors-Hardware.ps1`) обчислював `Dashboard.Metrics.CPU.Status`/`RAM.Status` (CRITICAL/WARNING/OK) для кольору dashboard-плитки, але жодного разу не викликав `Add-AuditFinding` — перевантаження CPU/RAM ніяк не впливало на `Health.Score`/`Health.Status` і не потрапляло у вкладку Findings, на відміну від storage/security, де ризики й Health Score узгоджені.
- **Fix**: нова `Get-BravoHardwareThresholds` (CPU: 75%/90% warning/critical; RAM: 85%/95%) — спільне джерело для Dashboard-статусу й нових findings (`Category 'Hardware.CPU'`/`'Hardware.RAM'`). CPU-finding не пишеться, якщо `LoadPercent` невідомий (`$null` на щойно піднятій VM — задокументована, не помилкова ситуація).
- **Побічно знайдено й виправлено**: `src/40-Health.ps1` (розрахунок статусу Disk dashboard-плитки за найгіршим томом) досі мав захардкожені пороги `10%`/`20%`, хоча `src/32-Collectors-Storage.ps1` вже перейшов на централізовану `Get-BravoStorageThresholds` (5%/10%/15%) у попередньому P1 PR — коментар у коді прямо стверджував "тим самим порогом", що вже не відповідало дійсності. Тепер обидва місця читають той самий `Get-BravoStorageThresholds`.
- Новий `tests/HardwareThresholds.Tests.ps1` (2 тести): чисті unit-тести `Get-BravoHardwareThresholds`.

Усі 46 Pester-тестів проходять (44 попередніх + 2 нових). `dist` перебудовано, sha512 звірено. На тестовій машині (CPU/RAM у межах норми) кількість findings не змінилась — підтверджено відсутність хибних спрацювань.

### P1: централізовані storage thresholds

Перший пункт milestone "v0.4.2 Runtime Quality" / P1 зовнішнього ТЗ — уніфікація порогів вільного місця для basic і Deep/Forensic storage audit.

- **Проблема**: `Get-BravoStorageAudit` (basic, усі профілі) використовував пороги `10%`/`20%` для CRITICAL/WARNING, а `Get-BravoStorageRiskSummary` (лише Deep/Forensic) — окремі, неузгоджені `5%`/`10%`/`15%`. Для одного й того самого тому в Deep/Forensic профілі це породжувало два findings різної суворості з різних порогових наборів одночасно (наприклад, том з 8% вільного місця отримував і CRITICAL від basic-проходу, і WARNING від risk summary).
- **Fix**: `src/32-Collectors-Storage.ps1` — нова централізована `Get-BravoStorageThresholds` (5% critical / 10% warning / 15% системний том) як єдине джерело порогів для обох шляхів, і чиста функція `Get-BravoStorageFreeSpaceSeverity` для класифікації тому за FreePercent. У Deep/Forensic профілях basic-прохід у `Get-BravoStorageAudit` більше не емітить власні findings — лише збирає TotalGB/FreeGB/FreePercent, а рішення про findings повністю делегується `Get-BravoStorageRiskSummary` (яка й так глибше покриває ті самі томи, включно з томами без літери диска й системним порогом). У Quick/Full профілях (де Deep audit не запускається) basic-прохід і далі сам генерує findings, але вже з тими самими централізованими порогами.
- Категорію findings уніфіковано на `Storage.FreeSpace` в обох шляхах (раніше basic писав `Storage`, deep — `Storage.FreeSpace`); на Health Score/тести це не впливає — там враховується лише `Severity`.
- Новий `tests/StorageThresholds.Tests.ps1` (8 тестів): чисті unit-тести `Get-BravoStorageThresholds`/`Get-BravoStorageFreeSpaceSeverity` без залежності від WMI/CIM.

Усі 44 Pester-тести проходять (36 попередніх + 8 нових). `dist` перебудовано, sha512 звірено.

### Stabilization P0-B: Windows Lifecycle data model

Закриває P0.6/P0.7 з зовнішнього ТЗ на стабілізацію — **Stabilization P0 тепер повністю завершено** (P0-A виконано раніше, див. запис нижче).

- **[P0.7]** Таблиця життєвого циклу Windows (`Get-BravoWindowsLifecycleTable`) винесена з `src/39-Collectors-Updates.ps1` у окремий data-модуль `src/39a-Data-WindowsLifecycle.ps1`, доданий у `src/BRAVO.build.json` перед колектором. Логіка колектора (`Get-BravoOsSupportInfo`) не змінилась — оновлення дат тепер не потребує правок коду колектора.
- **[P0.6]** Усі записи таблиці звірено з офіційними lifecycle-сторінками Microsoft Learn (`learn.microsoft.com/lifecycle`). Знайдено й виправлено помилку: **Windows Server 2025** мав `SupportEndConsumer`/`SupportEndEnterprise = 2034-10-10`, коректна дата — `2034-11-14` (офіційна raw "Extended End Date" — `11/15/2034 6:59:59 AM PT`, у публічно оголошеному форматі мінус 1 день). Знято позначку "не звірено з lifecycle-сторінкою" з Windows 11 25H2 — офіційні дати (`2027-10-12` Home/Pro, `2028-10-10` Enterprise/Education) підтверджено збіглись з уже наявними в таблиці. Інші звірені записи (24H2, 23H2, 22H2, 21H2 для Windows 11 та Windows 10, LTSC 2019/2021, Server 2022, Server 23H2 Annual Channel) — усі коректні, розбіжностей не знайдено. `$script:BravoLifecycleTableUpdatedAt` оновлено на `2026-09-01`.
- `tests/Manifest.Tests.ps1` підтверджує коректність нового модуля в `BRAVO.build.json` (жодних змін самого тесту не знадобилось — існуюче регресійне покриття вже ловить розсинхронізацію manifest/`src/*.ps1`).

Усі 36 Pester-тестів проходять (36/36, без пропусків). `dist` перебудовано, sha512 звірено.

### Stabilization P0: execution contract, exit codes, ExportErrors

За зовнішнім технічним завданням на стабілізацію (P0-P3) реалізовано **P0** (execution contract, exit codes, розділення CollectionErrors/ExportErrors). P0.6/P0.7 (Windows Lifecycle dataset — повноцінна нова функція, якої в коді не існувало) і P1-P3 свідомо відкладені в окремі майбутні PR.

**Ключова знахідка технічного аудиту**: кореневий `Get-BravoSystemReport.ps1` мав власний, вручну продубльований `param()`-блок, незалежний від `src/05-Params.ps1`/`dist`. Він розійшовся: `$Profile='Full'` (wrapper) vs `$Profile='Forensic'` (`dist`), `[switch]$Zip` без дефолту (wrapper) vs `=$true` (`dist`), forwarding `if ($Zip) {...}` губив явний `-Zip:$false`, не форвардив `-NoZip`/`-SkipPublicIP` (яких у wrapper не було взагалі). Усі попередні фікси `-Zip:$false`/`-NoZip` цієї сесії стосувались лише `dist`/елевації — цей окремий прошарок wrapper→dist лишався непоміченим і зламаним.

- **[P0.1/P0.2/P0.3]** `Get-BravoSystemReport.ps1` (root wrapper) переписано на транспарентний passthrough через `$PSBoundParameters` замість ручного `if ($X) {...}` на кожен параметр — джерела дрейфу. Дефолти прибрано з wrapper там, де вони й так є в `src/05-Params.ps1` (`Profile`, `EmailFrom`) — єдине джерело істини. Додано відсутні `-NoZip`, `-SkipPublicIP`. Функціонально перевірено: `-NoZip`/`-Zip:$false` через wrapper тепер коректно вимикають ZIP; default `Profile` через wrapper без явного `-Profile` = `Forensic` (як і напряму через `dist`).
- **[P0.4]** `CollectionErrors` (помилки збору — WMI/CIM/реєстр, властивість аудитованої машини) і `ExportErrors` (помилки запису JSON/HTML/CSV/ZIP/Email — проблема самого інструмента) розділені. Нова функція `Add-ExportError`, нове поле моделі `ExportErrors`, `SchemaVersion` піднято `0.5.2` → `0.6.0`. Health Score більше НЕ залежить від ExportErrors — рахується рівно один раз (одразу після колекторів), прибрано весь попередній "гейт" повторного перерахунку і пов'язаний з ним ризик self-zip-race (обидва існували лише через змішування CollectionErrors/ExportErrors). JSON пишеться першим (щоб потрапити в ZIP) і перезаписується ще раз наприкінці лише якщо ExportErrors змінились після першого запису — щоб файл на диску (не копія в ZIP) завжди відображав фінальний стан.
- **[Знайдено й виправлено під час верифікації P0.4]** Повторний запис JSON одразу після невдалої відправки email падав з "file used by another process" — `Send-MailMessage`/`SmtpClient` звільняє file handle вкладення лише через .NET finalizer, не одразу при винятку (підтверджено: простий `Start-Sleep` до 5 секунд не допомагав). Виправлено явним `[GC]::Collect(); [GC]::WaitForPendingFinalizers()` у retry-циклі `Export-BravoJsonReport`. Також виявлено, що PowerShell 5.1 обгортає виключення `.NET static method call` у `MethodInvocationException` — типізований `catch [System.IO.IOException]` не спрацьовує, потрібна перевірка через `InnerException`.
- **[P0.5]** Детермінований exit code contract: `0` = успіх без помилок; `1` = завершено, але були CollectionErrors і/або ExportErrors; `2` = фатальна неопрацьована помилка (новий top-level `trap`); `3` = обов'язковий JSON не згенеровано. Health Status (WARNING/CRITICAL) НЕ впливає на exit code — це властивість аудитованої машини, не ознака збою інструмента. Elevation relaunch тепер чекає завершення елевованого процесу і прокидає його реальний exit code (`WaitForExit` + `$process.ExitCode`) — раніше батьківський процес завершувався одразу з `exit 0` незалежно від результату, тож зовнішній caller завжди бачив `0`.
- Новий `tests/ExecutionContract.Tests.ps1` (10 тестів): статична перевірка джерела дефолтів, наскрізна перевірка `-NoZip`/`-Zip:$false` через wrapper, перевірка exit code 0/1 і розділення CollectionErrors/ExportErrors. Усі тести гоняються проти РЕАЛЬНОГО wrapper (не напряму проти `dist`), бо саме там був корінь проблеми.
- CI (`local-windows-validation.yml`): новий крок "Exit code contract test" — навмисно провокує export-помилку (невалідний SMTP) і перевіряє exit code 1 + коректне розділення CollectionErrors/ExportErrors.

Усі 33 Pester-тести проходять (23 попередні + 10 нових). `dist` перебудовано, sha512 звірено. Функціонально перевірено через кореневий wrapper (не лише `dist`): успішний прогін (exit 0), `-NoZip`, `-Zip:$false`, default Profile, форсована export-помилка (exit 1, ExportErrors у фінальному JSON).

### п'ятий раунд глибокого код-ревю: ще локале-баги, race condition, CSV-injection аудит

Два незалежні паралельні ревю: (1) систематичний пошук того самого класу локале-залежних багів по всій кодовій базі (уже двічі знаходили цей клас у попередніх раундах), (2) CSV-injection ризик + повторний глибокий прохід Users/ProcessesServices колекторів.

- **[Локале-баг, той самий клас]** `39-Collectors-Updates.ps1`: визначення "security-оновлення" звірялось з англійським літералом `'Security'` проти `Categories.Name` — а це **локалізована** назва категорії від WUA API (на uk-UA/ru-UA буде "Оновлення для системи безпеки"/"Обновления безопасности", не "Security"). `PendingSecurity` на не-англійських Windows завжди показував 0, навіть маючи реальні security-оновлення в черзі. Виправлено — звірка тепер йде через стабільний, локале-незалежний `CategoryID` (GUID `0FA1201D-4330-4FA8-8AE9-B877473B6441` = офіційний WUA-ідентифікатор "Security Updates").
- **[Локале-баг, той самий клас, часткова латка з минулого разу виявилась неповною]** `35-Collectors-Users.ps1`: fallback через `net localgroup` (коли `Get-LocalGroupMember` недоступний) досі покривав лише en+uk завершальний рядок ("command completed"/"Команда виконана") — на ru/de/pl/... локалізаціях фальшивий службовий рядок потрапляв у `Users.LocalAdmins` як нібито ім'я адміністратора. Замість розширення списку мов (нескінченна латка) — структурний фікс: `net localgroup` завжди завершує вивід рівно одним статус-рядком одразу після переліку членів, тож тепер просто відкидається останній непорожній рядок після роздільника, а не матчиться текст.
- **[Race condition]** `36-Collectors-ProcessesServices.ps1`: `WorkingSet64` — лінива властивість `System.Diagnostics.Process` (обчислюється при першому зверненні, не кешується в момент `Get-Process`). Якщо короткоживучий процес завершувався між `Get-Process` і зверненням до `.WorkingSet64` усередині `Sort-Object`, кидався виняток "process has exited", що валило весь `Processes.TopMemory` (не лише проблемний процес). Тепер кожен процес знімається у власному try/catch — завершений процес просто пропускається, решта топ-10 рахується коректно.

**Перевірено і підтверджено відсутність проблем**: CSV-injection у `52-Export-Csv.ps1` неможливий (жодне "багате" текстове поле — назви процесів/служб/ПЗ — у CSV не потрапляє, лише агреговані числа/`.Count`); `35-Collectors-Users.ps1`/`36-Collectors-ProcessesServices.ps1` — інші edge-cases (порожня група Administrators, відсутній модуль LocalAccounts, одиниці виміру) коректні; `MsrcSeverity`-порівняння в `39-Collectors-Updates.ps1` (на відміну від `Categories.Name`) НЕ локалізоване, ризику там немає; `[version]`-каст у `39b-Collectors-Runtime.ps1` культуро-незалежний за дизайном `System.Version`; `ConvertTo-Json` серіалізує числа через `InvariantCulture` за дизайном.

Усі 23 Pester-тести проходять. `dist` перебудовано, sha512 звірено. Функціонально перевірено на Full-профілі: `Processes.TopMemory` (10 записів, без помилок), `Users.LocalAdmins` (коректний список без сміттєвих записів).

### четвертий раунд глибокого код-ревю: XSS-екранування, локале-баг у власному фіксі

Два незалежні паралельні ревю: (1) регресія в найостаннішому коміті + COM-ресурси Windows Update collector'а + мертві поля моделі даних, (2) систематичний аудит `51-Export-Html.ps1` на предмет пропущеного HTML-екранування. Під час верифікації власного фіксу знайдено й одразу виправлено ще один локале-баг (той самий клас, що й у попередньому раунді).

- **[HTML-екранування]** `51-Export-Html.ps1`: прогрес-бари CPU/RAM/Disk (`style="width:...%"`) вставляли значення напряму, без екранування й без гарантії, що це справді число. Додано `Get-BravoSafePercentText` — clamp 0-100 + валідація типу перед вставкою в HTML-атрибут і текст. Ризик був низький (значення обчислюються скриптом, не сирий системний текст), фіксили для консистентності з рештою файлу.
- **[Новий локале-баг, знайдений і виправлений одразу]** Перша версія `Get-BravoSafePercentText` використовувала `[double]::TryParse(string, ref double)` без явної культури — цей overload звіряється з `CurrentCulture`, тоді як `[string]$double`-каст у PowerShell форматує через `InvariantCulture` (крапка). На uk-UA системі (кома як десятковий роздільник) парсинг мовчки провалювався, і RAM/Disk progress-bar показували "0%" замість реального значення (44.57%/17.65%) — підтверджено реальним прогоном перед фіксом і після. Виправлено явним `NumberStyles.Float` + `CultureInfo.InvariantCulture`.
- **[Ресурси]** `39-Collectors-Updates.ps1`: WUA COM-об'єкти (`Microsoft.Update.Session`, `UpdateSearcher`, `SearchResult`) тепер явно звільняються через `Marshal.ReleaseComObject` у `finally`-блоці. Практичного ефекту для одноразового запуску скрипта немає (процес і так завершується), але страхує від накопичення RCW, якщо колектор колись викликатиметься кілька разів у межах одного процесу.
- **[Документація коду]** `32-Collectors-Storage.ps1`, `20-ReportModel.ps1`: додано явні коментарі про поля моделі, які завжди порожні, бо відповідні колектори ще не реалізовані (`PhysicalDisks`/`ReliabilityCounters`/`BitLocker`/`ShadowCopies`/`StoragePools`/`StorageSubsystems`/`SmartPredictFailures` у Storage Deep Audit; `Software.WindowsFeatures`, `USBDevices` на верхньому рівні) — це заплановані (див. `docs/ROADMAP.md`), а не забуті чи зламані поля; повна реалізація цих колекторів — окрема, значно більша задача, не точковий фікс.
- **[Release-скрипт]** `tools/New-ReleasePackage.ps1`: `Resolve-PackageVersion` мала мертву першу гілку (регекс на `CHANGELOG.md` формату `## vX.Y.Z`, якого в поточному CHANGELOG ніколи не буває — усі заголовки `## Unreleased — ...`). Не падало (fallback на `src/90-Main.ps1` спрацьовував), але вводило в оману. Поміняно пріоритет: `src/90-Main.ps1` тепер основне джерело, CHANGELOG — fallback.

**Перевірено і підтверджено відсутність проблем**: фільтр `*.zip` в гейті перерахунку (порядок pipeline, немає хибних збігів), регістр SHA512-порівняння, дублювання `PhysicalDisks` між Storage Deep Audit і `Hardware.Disks.PhysicalDisks` (різні поля, не конфліктують), увесь HTML-файл систематично екранований через `ConvertTo-BravoHtmlText` окрім уже знайдених прогрес-барів — жодних полів, потенційно контрольованих власником машини (назви процесів/USB/задач), у HTML-звіті взагалі не рендериться.

Усі 23 Pester-тести проходять. `dist` перебудовано, sha512 звірено. Функціонально перевірено: `New-ReleasePackage.ps1` (реальна збірка ZIP), HTML progress-bar значення (до і після локале-фіксу, побайтова звірка з консольним виводом).

### третій раунд глибокого код-ревю: release-скрипт не запускався, self-zip race

Два незалежні паралельні ревю: (1) накопичена логіка `src/90-Main.ps1` (редагувався в кожному з 4 попередніх коміти поспіль — найбільший ризик прихованих регресій), (2) периферійні файли, які ще не рев'ювались (bat-лаунчери, `tools/*.ps1`, актуальність документації). Кожна знахідка перевірена особисто перед фіксом.

- **[Release-скрипт взагалі не запускався]** `tools/New-ReleasePackage.ps1` посилався на видалений `src/Get-BravoSystemReport.ps1` (визначення версії + hard-required перевірка на самому старті) і не включав `dist/Get-BravoSystemReport.ps1`/`.sha512` у release ZIP — навіть без падіння скрипт зібрав би нефункціональний пакет (root wrapper викликає `dist\...`, якого там нема). Версія тепер читається з `src/90-Main.ps1`; скрипт вимагає наявності свіжого `dist` і звіряє sha512 перед пакуванням; `dist/Get-BravoSystemReport.ps1` + `.sha512` додані в package. Функціонально перевірено — реліз-пакет успішно збирається.
- **[Self-zip race]** `90-Main.ps1`: якщо export-етапи вище (JSON/HTML/CSV/ZIP) додали нову помилку, гейт перерахунку перезбирає ZIP — але до фіксу шлях до вже створеного першим проходом архіву лишався в `GeneratedFiles`, і `Export-BravoZipReport` намагався запакувати сам себе (щойно відкритий ексклюзивно на запис файл) → `IOException`, ще одна непідхоплена помилка вже після того, як Health Score/JSON/HTML зафіксовані як фінальні. Тепер `*.zip` явно виключається з `GeneratedFiles` перед повторним викликом (той самий патерн, що вже використовувався для Email-вкладень).
- `examples/README.md`: синхронізовано з поточною поведінкою (`-Zip` за замовчуванням, `-NoZip` для вимкнення; уточнено, що `-JSONOnly` не вимикає ZIP сам по собі).
- `docs/ROADMAP.md`, `docs/IMPLEMENTATION_PLAN.md`: відмічено вирішені пункти release-package tech debt.

**Перевірено і підтверджено відсутність проблем**: elevation-forwarding усіх параметрів з `05-Params.ps1`, порядок `if ($NoZip) { $Zip = $false }` відносно всіх використань `$Zip` нижче, синхронність `dist/` з `src/` (побайтова звірка + sha512), коректність `BRAVO.build.json` (немає forward-залежностей між модулями), усі 5 `.bat`-лаунчерів, `tools/Publish-ToGitHub.ps1` (немає ризикованих force-дій).

Усі 23 Pester-тести проходять. `dist` перебудовано, sha512 звірено.

### другий раунд глибокого код-ревю: CI завжди падав, Email зі старими даними

Два незалежні паралельні ревю: (1) саме останні 2 коміти попереднього ревю на предмет нових регресій, (2) раніше нерев'юєні модулі (Network/Users/ProcessesServices/Software collectors, Csv/Zip/Email export, Core, ReportModel, tests/, CI). Кожна знахідка перевірена особисто перед фіксом.

- **[CI завжди падав]** `.github/workflows/local-windows-validation.yml`: крок "Validate latest JSON" звертався до неіснуючого `$report.Network.PrimaryIPv4`/`PublicIPv4Status` (реальний шлях — `Network.IP.PrimaryIPv4`/`PublicIPv4Status`, поле переїхало ще при переході на `SchemaVersion 0.5.0`). Кожен PR на `main` мав падати на цьому кроці — pre-existing баг, не з цієї сесії, але критичний для довіри до CI.
- **[Email зі старими даними]** `90-Main.ps1`: `Send-BravoEmailReport` тепер викликається останнім, ПІСЛЯ гейту повторного перерахунку Health Score. Раніше лист відправлявся до гейту — якщо саме ZIP-етап спричиняв нову помилку, лист ішов зі старим (вищим) Health Score в тілі й застарілими JSON/HTML-вкладеннями, хоча файли на диску вже мали виправлене значення. Це саме той розсинхрон, який попередній фікс мав усунути, просто перенесений з диска в надіслану пошту.
- **[Регресія все ще не закрита повністю]** `90-Main.ps1`: `-Zip:$false` (старий, задокументований в історії CHANGELOG спосіб вимкнути ZIP) досі губився при elevation-relaunch навіть після додавання `-NoZip` в попередньому коміті — форвардилось лише за прапорцем `-NoZip`, не за ефективним значенням `$Zip`. Тепер перевіряється `if (-not $Zip)`, що коректно охоплює обидва способи вимкнення.
- **[Локале-залежність]** `37-Collectors-Events.ps1`: фільтр "порожній результат Get-EventLog" тепер звіряє `FullyQualifiedErrorId` (`GetEventLogNoEntriesFound`, стабільний) замість тексту `Exception.Message` ("No matches found", локалізується разом з MUI-пакетом Windows — на uk-UA/ru-UA системах текст інший, і штатний порожній результат помилково потрапляв би в `CollectionErrors`).
- **[Конфлікт з тестом]** `31-Collectors-Hardware.ps1`: прибрано `Add-AuditError` для `LoadPercentage=$null` (додано в попередньому раунді) — це очікуваний, не помилковий стан на щойно піднятих VM/CI-раннерах, і штрафував Health Score та ламав інваріант `CollectionErrors=0` в `EndToEnd.Tests.ps1` на кожному такому прогоні. 0% залишається значенням-заглушкою для "невідомо", як і до фіксу.
- `README.md`: задокументовано `-NoZip` і те, що `-Zip` увімкнений за замовчуванням.

**Свідомо не виправлено**: дублювання `$zipPath` у `GeneratedFiles` між першим і другим викликом `Export-BravoZipReport` (самокоригується через `Select-Object -Unique`, крихко, але не бажає окремого фіксу зараз); прогалини Pester-покриття нових гілок (`-NoZip`-forwarding при елевації, UAC null-case, worst-volume розрахунок) — потребують рефакторингу для unit-тестування (90-Main.ps1 не dot-source-безпечний), окрема задача.

Усі 23 Pester-тести проходять. `dist` перебудовано, sha512 звірено. Функціонально перевірено: `-Zip:$false` (прямий виклик), sha512-звірка, повний Quick-прогін з CollectionErrors=0.

### глибоке код-ревю: виправлено 9 підтверджених багів і 3 правдоподібні

Знайдено двома незалежними глибокими ревю (collector-и та export/core/main), кожна знахідка перевірена особисто читанням коду перед фіксом.

- **[Регресія функціональності]** `05-Params.ps1`/`90-Main.ps1`: додано `-NoZip`. `-Zip:$false` губився при elevation-relaunch — `powershell.exe -File` не підтримує синтаксис `-Switch:$false` з командного рядка (емпірично перевірено: `ParameterArgumentTransformationError`), тому елевований процес завжди створював ZIP, ігноруючи явну відмову користувача. `-NoZip` форвардиться за тим самим патерном, що й `-NoPause`/`-NoEmoji`/`-NoOpenFolder`.
- **[Хибний security-finding]** `34-Collectors-Security.ps1`: WARNING "UAC вимкнено" і INFO "RDP увімкнено" тепер генеруються лише якщо відповідний реєстровий ключ реально вдалось прочитати. Раніше недоступність ключа (Server Core, GPO) мовчки трактувалась як "вимкнено" через дефолтне значення моделі — хибна CRITICAL-подібна знахідка в security-аудиті.
- **[Неузгоджені пороги]** `40-Health.ps1`: статус Disk-плитки на dashboard тепер рахується по найгіршому тому (`Hardware.Disks.Volumes`, пороги 10/20%, ті самі що й у findings), а не по агрегованому вільному місцю по всіх дисках разом. Підтверджено реальним прогоном: диск з 4.57% вільного ховався за агрегатом 17.66% і показував dashboard "WARNING" замість "CRITICAL".
- **[Втрачені помилки]** `90-Main.ps1`: гейт повторного перерахунку Health Score/re-export JSON+HTML тепер стоїть після ZIP і Email (раніше — лише після CSV), тож помилки саме ZIP/Email-етапів більше не ігноруються; ZIP після re-export перезбирається, щоб не пакувати застарілі JSON/HTML.
- **[Втрачені помилки]** `37-Collectors-Events.ps1`: помилки `Get-EventLog` (крім штатного "No matches found") тепер логуються в `CollectionErrors` — раніше `-ErrorAction SilentlyContinue` ковтав їх мовчки, і провал збору виглядав як "0 помилок/попереджень".
- **[Мертвий код]** `51-Export-Html.ps1`: прибрано fallback-гілку, що зверталась до неіснуючого поля `Network.PublicIPv4` (правильний шлях — `Network.IP.PublicIPv4`) — ніколи не виконувалась.
- **[HTML-екранування]** `51-Export-Html.ps1`: `$OutputDir` у футері тепер проходить через `ConvertTo-BravoHtmlText`, як і всі інші динамічні значення у файлі.
- **[Сумісність]** `50-Export-Json.ps1`: JSON пишеться через `[System.IO.File]::WriteAllText` з `UTF8Encoding($false)` замість `Out-File -Encoding utf8` — прибрано BOM, який ламав суворі JSON-парсери (RFC 8259) у зовнішніх CI/monitoring pipeline.
- **[Захист]** `51-Export-Html.ps1`: `CatalogUrl` у href тепер проходить allow-list схеми (`^https://`) перед вставкою — захист від потенційного `javascript:`-URI, якщо патерн буде скопійований для менш контрольованого поля.
- **[Хибне значення]** `31-Collectors-Hardware.ps1`: якщо `Win32_Processor.LoadPercentage` повертає `$null` (буває на VM), тепер логується `Add-AuditError` замість мовчазного показу CPU 0%.
- **[Застаріла константа]** `39b-Collectors-Runtime.ps1`: еталон "найновіша відома версія PowerShell 7" піднято `7.4` → `7.6`.

**Свідомо не виправлено** (LOW/PLAUSIBLE, ризик змін не виправдовує вигоду): `Add-AuditFinding`/`Add-AuditError` досі `+=` в циклі по всій кодовій базі (O(n²), але викликається лише десятки разів за прогін — реальний вплив незначний, конвертація в `List` торкнулась би 15+ місць виклику); окрема Deep-профільна система порогів Storage Risk Summary (5/10/15%) лишається відмінною від basic-аудиту (10/20%) — повна уніфікація вже в `docs/ROADMAP.md` як окремий tech-debt пункт, це більший архітектурний рефакторинг, не точковий фікс.

Усі 23 Pester-тести проходять. `dist/Get-BravoSystemReport.ps1` + `.sha512` перебудовані.

### ревю проєкту: OS-aware .NET-сумісність, прибирання legacy, CI-гварди, Pester-тести

- **[Bugfix]** `39b-Collectors-Runtime.ps1`: `Get-BravoRuntimeAudit` більше не радить сліпо ставити .NET Framework 4.8.1 — тепер визначає максимальну сумісну версію за `OS.Build` (Windows 11 22H2+/Server 2022 23H2+, build ≥ 22621 → 4.8.1; старіші ОС, включно з Windows Server 2019, → 4.8). Раніше на Windows Server 2019 рекомендація "встановіть 4.8.1" блокувалась інсталятором з повідомленням "не підтримується цією операційною системою" — підтверджено реальним прогоном на Server 2019 (build 17763), тепер коректно показує `4.8`.
- Видалено застарілий монолітний `src/Get-BravoSystemReport.ps1` (не редагувався з моменту переходу на модульну архітектуру; вводив в оману щодо "основного" скрипта, зокрема в `powershell-static-check.yml`).
- Видалено `BRAVO_SYSTEM_REPORT.git.bundle` (орфанний бекап-артефакт у корені репо, ніде не використовувався).
- `.github/workflows/powershell-static-check.yml`: перевірка структури репозиторію оновлена під реальну модульну архітектуру (замість застарілого моноліту — `src/90-Main.ps1`, `src/BRAVO.build.json`, `dist/Get-BravoSystemReport.ps1`).
- `.github/workflows/local-windows-validation.yml`: додано звірку `dist/Get-BravoSystemReport.ps1.sha512` з реальним хешем після build; додано гвард, що вимагає підняття `SchemaVersion` і запису в `CHANGELOG.md` разом зі зміною `src/20-ReportModel.ps1`; додано крок `Invoke-Pester tests/`; додано `Deep`-прогін з `-CSV -Zip`, що перевіряє реальне виконання Windows Update COM-пошуку (`WindowsUpdate.SearchStatus -ne 'Skipped'`).
- Додано `tests/` — базовий Pester 5.x набір: `Core.Tests.ps1` (чисті IPv4-хелпери з `10-Core.ps1`), `Manifest.Tests.ps1` (консистентність `BRAVO.build.json` ↔ фактичні файли `src/*.ps1` — ловить клас багів "забув зареєструвати новий модуль"), `EndToEnd.Tests.ps1` (наскрізний прогін `dist` у профілі Quick, локально запускається через `Invoke-Pester tests/`).
- `README.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/IMPLEMENTATION_PLAN.md`: синхронізовано з фактичним станом коду (версії `ScriptVersion 0.4.1`/`SchemaVersion 0.5.2`, дерево структури проєкту, виконані пункти backlog позначені `[x]`, прибрано згадки видаленого моноліту).
- `docs/AI_RULES.md`: усунуто протиріччя між п.6 (обов'язковий бамп `SchemaVersion` при зміні контракту) і п.9 (заборона змінювати `SchemaVersion` без явного запиту) — уточнено, що п.9 стосується довільних бампів, не пов'язаних із поточним запитом.
- `patch/v0.2.0-stabilization.*` свідомо залишено без змін — історичний артефакт міграції, не заважає поточній роботі.

### перевірка оновлень .NET Framework/PowerShell, Catalog-посилання для pending updates

- Додано модуль `39b-Collectors-Runtime.ps1` (`Get-BravoRuntimeAudit`): офлайн-перевірка можливості оновлення .NET Framework 4.x (порівняння release-key з еталоном 4.8.1) та Windows PowerShell/PowerShell 7 (Core) (порівняння з еталоном 7.4, виявлення встановлення через `HKLM:\SOFTWARE\Microsoft\PowerShellCore\InstalledVersions`). Генерує WARNING/INFO-знахідки через `Add-AuditFinding` — раніше версія .NET лише відображалась, ніяк не впливаючи на Health Score.
- `20-ReportModel.ps1`: нові поля `DotNet.ReleaseKey`, `DotNet.LatestKnownVersion`, `DotNet.UpdateAvailable`, `PowerShell.Core7Installed`, `PowerShell.Core7Version`, `PowerShell.Core7LatestKnown`, `PowerShell.Core7UpdateAvailable`.
- `39-Collectors-Updates.ps1`: до кожного запису `WindowsUpdate.PendingUpdates` додано `CatalogUrl` — пряме посилання на Microsoft Update Catalog для відповідного KB.
- `51-Export-Html.ps1`: картка "Runtime" показує статус оновлень .NET/PowerShell 7; таблиця "Pending Windows Updates" отримала клікабельну колонку "Посилання" на Catalog.
- `90-Main.ps1`: inline-блок визначення версії .NET Framework замінено викликом `Get-BravoRuntimeAudit`.
- `SchemaVersion` піднято `0.5.1` → `0.5.2` (нові поля `DotNet.*`, `PowerShell.Core7*`, `WindowsUpdate.PendingUpdates[].CatalogUrl`).

### менше шуму в findings: trigger-start служби, деталі помилок System log

- `36-Collectors-ProcessesServices.ps1`: додано whitelist відомих trigger-start/опціональних служб (`edgeupdate`, `edgeupdatem`, `gupdate`, `gupdatem`, `MapsBroker`, `sppsvc`, `WbioSrvc`, `RemoteRegistry`) — вони більше не рахуються у WARNING-знахідці "Автоматичних служб не запущено" (лишаються видимими в `Services.AutomaticStopped` для прозорості, просто не впливають на severity/score).
- `37-Collectors-Events.ps1`: додано `EventLogs.TopErrorSources` — топ-10 джерел помилок System log (Source, Count, останнє повідомлення) за період, замість самого лише лічильника. Знахідка тепер містить топ-3 джерела прямо в тексті.
- `20-ReportModel.ps1`: `SchemaVersion` `0.5.0` → `0.5.1` (нове поле `EventLogs.TopErrorSources`).
- `51-Export-Html.ps1`: додано таблицю "Топ джерел помилок System log" у вкладку Services. Заразом виправлено супутній баг — таблиця "Automatic stopped services" мапилась на неіснуючі властивості `StartType`/`Status` (мали бути `StartMode`/`State`) і завжди показувала порожні колонки.

### ScriptVersion 0.4.1

- `ScriptVersion` (`src/90-Main.ps1`) піднято `0.4.0` → `0.4.1` — версія релізу інструмента, що друкується в банері консолі та в JSON (`ScriptVersion`), відображає накопичені зміни цього PR (Windows Update collector, privacy public IP, health score, CD-ROM fix тощо). Відрізняється від `SchemaVersion` (`0.5.0`), яка версіонує лише структуру JSON-контракту.

### виправлено false positive CRITICAL для CD-ROM томів

- Виправлено `32-Collectors-Storage.ps1`: томи з `DriveType='CD-ROM'` більше не потрапляють у CRITICAL/WARNING знахідки Storage Risk через "0% вільно" (оптичні носії read-only, поняття вільного місця до них не застосовне). Такі томи тепер класифікуються як `HealthyVolumes`.
- Знайдено під час валідації PR на Windows Server 2016: CD-ROM том з ISO показував `Health.Score` штучно нижчим через хибну CRITICAL-знахідку.

### код-рев'ю: privacy, health score, dist rebuild

- **[Blocker]** Перезібрано `dist/Get-BravoSystemReport.ps1` — Windows Update collector нарешті потрапив у виконуваний артефакт.
- Додано прапорець `-SkipPublicIP` та гейтинг профілем (`Full`/`Deep`/`Forensic`) для запитів публічного IP/ISP/geo до сторонніх сервісів — для профілю `Quick` та за наявності прапорця дані більше не відправляються.
- `Update-BravoHealthScore` тепер перераховується вдруге після export-етапів (JSON/HTML/CSV), а JSON перезаписується з фінальною оцінкою — виправлено розсинхронізацію `Health.Score` при помилках експорту.
- Прибрано порожні `catch {}` у `10-Core.ps1` — додано коментарі, що пояснюють свідомо ігноровані сценарії (відповідно до `docs/AI_RULES.md`).
- Виправлено `33-Collectors-Network.ps1`: усунено звернення до `$Report` без `script:`-префіксу, прибрано недосяжний (мертвий) `else`-код для не-`IDictionary` типу, прибрано дублювання CIM-запиту при формуванні fallback-списку IPv4.
- Додано severity-класи `Moderate`/`Low` у HTML-мапінг ризику Windows Update (раніше потрапляли в `risk-unknown`).
- Видалено застарілий сміттєвий файл `tools/Publish-ToGitHub.ps1.broken`.
- `SchemaVersion` піднято `0.4.1` → `0.5.0` (контракт звіту змінено: додана секція `WindowsUpdate`, нове поле `PublicIPv4Status='Skipped'`).

### Windows Update audit

- Додано модуль `39-Collectors-Updates.ps1` зі збором даних Windows Update.
- Додано секцію `WindowsUpdate` у модель звіту (`SchemaVersion` піднято до `0.5.0`, див. запис вище).
- Додано збір встановлених оновлень через `Get-HotFix` з датою останнього встановлення.
- Додано перевірку pending reboot через ключі реєстру Windows Update та CBS.
- Додано пошук відсутніх оновлень через Windows Update Agent COM API (лише профілі `Deep`/`Forensic`).
- Додано findings: CRITICAL для невстановлених критичних оновлень; WARNING для застарілості >60 днів, pending reboot, вимкненої служби wuauserv та черги оновлень.
- Додано картку `Windows Update` та таблицю `Pending Windows Updates` з пошуком у вкладку OS HTML-звіту.
- Додано `src/39-Collectors-Updates.ps1` у `BRAVO.build.json`.

### автоматизація релізу

- Додано workflow `.github/workflows/release.yml`: реліз публікується при push-і тега `v*`.
- Додано звірку версії між `src\90-Main.ps1`, `CHANGELOG.md` і тегом перед публікацією.
- Додано перевірку зібраного пакета: збіг SHA512, parser check runtime і версія запакованого скрипта.
- Додано вкладення `BRAVO_SYSTEM_REPORT_v<version>.zip` і `.zip.sha256` у GitHub Release.
- Додано ручний dry run через `workflow_dispatch` без публікації релізу.
- Виправлено кодування у кроках workflow: не-ASCII текст усередині `run:` ламав консольний вивід, бо Windows PowerShell 5.1 читає тіло кроку як ANSI.

## v0.5.0 — аналіз ОС і оновлень Windows

### реліз-пакет

- Виправлено склад реліз-пакета: замість застарілого моноліту `src\Get-BravoSystemReport.ps1` пакується робочий runtime `dist\Get-BravoSystemReport.ps1`.
- Контрольна сума runtime генерується з файлу, який реально потрапляє в пакет, а всі текстові файли нормалізуються до CRLF.
- Fallback визначення версії переведено з застарілого моноліту на `src\90-Main.ps1`.
- `tools\New-ReleasePackage.ps1` зроблено кросплатформним і додано читабельний перелік вмісту пакета.
- Нормалізовано переноси рядків у `dist\Get-BravoSystemReport.ps1` до CRLF.

### колектор Updates

- Додано модуль `src\39-Collectors-Updates.ps1` з колектором `Get-BravoUpdatesAudit`.
- Додано секцію `Updates` у модель звіту та підвищено `SchemaVersion` до `0.5.0`.
- Додано аналіз життєвого циклу ОС: продукт, DisplayVersion, full build з UBR, канал, дата завершення підтримки і статус `Supported` / `EndingSoon` / `EndOfSupport`.
- Додано пошук доступних оновлень через COM `Microsoft.Update.Session` з таймаутом і виконанням у фоновому job.
- Додано зведення по оновленнях: total, security, critical, driver, definition, other, downloaded, розмір і вік найстарішого оновлення.
- Додано збір стану Windows Update: служба `wuauserv`, політика `AUOptions`, WSUS, час останнього пошуку та встановлення.
- Додано визначення pending reboot з переліком причин.
- Додано збір встановлених оновлень через `Get-HotFix` з fallback на `Win32_QuickFixEngineering`.
- Додано знахідки Health Score для ОС поза підтримкою, невстановлених оновлень безпеки, pending reboot і зупиненого циклу оновлень.
- Додано метричну картку `Updates` і вкладку `Updates` у HTML-звіт із таблицями доступних і встановлених оновлень.
- Додано поля оновлень у CSV-експорт.
- Додано параметри `-SkipUpdateSearch` і `-UpdateSearchTimeoutSec`; профіль `Quick` онлайн-пошук не виконує.
- Додано дати завершення підтримки для Windows 11 25H2 (build 26200) у таблицю життєвого циклу.
- Додано у local Windows validation кроки `Full runtime test` і `Validate updates section` для перевірки онлайн-пошуку оновлень.
- Виправлено помилку `TryParse` з `[ref]` на неініціалізованих змінних, через яку успішний пошук оновлень позначався як `Failed`, а `MaxAgeDays` не обчислювався.
- Захищено `Search.Status = OK` від перезапису помилкою пост-обробки.
- Додано третій канал підтримки `LTSC / LTSB` з окремими датами замість змішування з Enterprise.
- Розширено таблицю життєвого циклу до повного покриття: від Windows 2000 і Windows 2000 Server до Windows 11 25H2 і Windows Server 2025, включно з Windows 10 1511/1703/1709/1803/1903 і Windows Server SAC.
- Посилено CI-перевірку секції `Updates`: неконсистентність `Search.Status`/`Pending.Total` і ненульові `CollectionErrors` тепер валять збірку.
- Класифікацію оновлень переведено на стабільні `CategoryID` замість локалізованих назв категорій; англомовні назви лишились як fallback.
- Додано `Pending.Detailed` і `Pending.IsTruncated`: якщо знайдено більше оновлень, ніж зберігається детально, це видно у звіті та у знахідці.
- LTSC/LTSB тепер визначається за `EditionID` (`EnterpriseS`, `EnterpriseSN`, `IoTEnterpriseS`), а не лише за `Caption`; `EditionID` виводиться у звіті.
- Додано перевірку політики `NoAutoUpdate=1`, яка має пріоритет над застарілим значенням `AUOptions`.
- Статус життєвого циклу `Unknown` більше не дає зелену метрику Updates.
- `-UpdateSearchTimeoutSec` зі значенням `0` або від'ємним більше не вимикає таймаут, а повертається до 180 сек.
- Контрольна сума `dist` рахується на CRLF-варіанті файлу, як його бачить Windows після checkout.
- Додано Windows Server 23H2 (build 25398) у таблицю життєвого циклу.
- Pro Education і Pro for Workstations тепер обслуговуються за споживчим циклом, а не за Enterprise.
- Метрика Updates стає CRITICAL і за наявності critical-оновлень, а не лише security.


## Unreleased — Forensic ZIP default та Storage Deep Inventory v2

- Змінено профіль запуску за замовчуванням з `Full` на `Forensic`.
- Увімкнено створення ZIP-архіву за замовчуванням.
- Додано можливість вимкнути ZIP через `-Zip:$false`.
- Розширено `StorageDeep` полями `Partitions` і `PageFiles`.
- Додано збір partition-даних через `Get-Partition`.
- Додано збір pagefile-даних через `Win32_PageFileUsage`.
- Збережено існуючу логіку `StorageRisk` без змін.
- Перевірено default runtime test: `Forensic + ZIP`, `CollectionErrors=0`, `Partitions=10`, `PageFiles=1`.
### інтерактивний HTML dashboard polish

- Додано пошук по великих HTML-таблицях без зовнішніх CDN.
- Додано helper `New-BravoTableToolbarHtml` для генерації toolbar біля таблиць.
- Додано `.table-toolbar`, `.table-search`, `.table-counter` і `.row-hidden` CSS-класи.
- Додано JS-функції `initializeTableFilters`, `filterTable` і `updateTableCounter`.
- Додано лічильник видимих/загальних рядків для фільтрованих таблиць.
- Додано пошук для Storage Critical Findings, Storage Deep, Network Adapters, Automatic stopped services, Installed software, Findings і Collection errors.
- Збережено print/PDF fallback: toolbar приховується, а всі рядки таблиць показуються при друку.

### інтерактивний HTML dashboard JS tabs

- Додано автономний inline JavaScript без зовнішніх CDN.
- Додано функцію `openTab(event, tabId)` для перемикання вкладок.
- Додано приховування неактивних `.tab-panel` через `display: none`.
- Додано показ активної `.tab-panel.active` через `display: block`.
- Додано керування класом `.active` для `.tab-button`.
- Додано `aria-selected` для активної/неактивних кнопок вкладок.
- Додано ініціалізацію першої вкладки `tab-general` після завантаження HTML.
- Додано підтримку відкриття вкладки з URL hash, наприклад `#tab-network`.
- Збережено print/PDF fallback: у режимі друку всі `.tab-panel` показуються.

### інтерактивний HTML dashboard UI

- Оновлено `src\51-Export-Html.ps1` під HTML dashboard layout.
- Додано автономний CSS-каркас без зовнішніх CDN.
- Додано `dashboard-header` з computer name, uptime, primary IPv4, health/status і status reason.
- Додано `tab-nav` з anchor-кнопками для майбутньої JS-логіки вкладок.
- Додано секції `tab-panel`: General, OS, Hardware, Network, Security, Services, Software, Findings.
- Додано метричні картки `metric-card` для CPU, RAM, Disk і OS.
- Додано універсальні таблиці `.data-table` та scroll-контейнери `.table-scroll` для великих списків.
- Додано адаптивну верстку для вузьких екранів.
- Додано print CSS, який приховує навігацію та прибирає обмеження scroll-контейнерів для друку/PDF.
- JS-перемикання вкладок реалізовано окремим Sprint 3.

### інтерактивний HTML dashboard backend

- Підготовлено backend-структуру для майбутнього інтерактивного HTML-звіту Dashboard & Tabs.
- Оновлено `SchemaVersion` до `0.4.1`.
- Додано top-level поля `Status` і `StatusReason` у модель звіту.
- Додано секцію `Dashboard` з `Header`, `Metrics` і `Tabs`.
- Додано dashboard-метрики `CPU`, `RAM`, `Disk`, `OS`.
- Виправлено RAM-метрики: додано `TotalVisibleMemoryGB`, `FreeGB`, `UsedGB`, `UsedPercent`, `Source`.
- Розширено network-модель для HTML-вкладки: `DefaultGateways`, `DNSServers`, `DNSSuffixSearchOrder`, nested `Network.IP.PrimaryIPv4`, `PrimaryInterface`, `PublicIPv4*`.
- Синхронізовано `Health.Status` з `Report.Status` і `Dashboard.Header.Status`.
- Локально перевірено smoke test профілю `Forensic` з `CSV` і `ZIP`: `SchemaVersion=0.4.1`, `Dashboard` заповнено, `CollectionErrors=0`.

### документація та план впровадження

- Оновлено `README.md` відповідно до фактичної структури проєкту після переходу на модульну архітектуру.
- Додано посилання на `docs/IMPLEMENTATION_PLAN.md`.
- Актуалізовано опис GitHub Actions / Local Windows Validation.
- Актуалізовано структуру проєкту з урахуванням `dist/`, `docs/`, модулів `src/` і workflow-файлів.
- Додано секцію відомого технічного боргу.
- Оновлено `docs/ROADMAP.md`: додано milestones `v0.4.1` ... `v0.7.0`, release stabilization, sanitize, runtime quality, deep inventory, reports і CI gates.
