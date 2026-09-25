# План впровадження доробок BRAVO SYSTEM REPORT

> **Статус (звірено 2026-09-25, гілка `integration/v0.6.1-secure`):** цей план написаний
> до v0.5.0 Deep Inventory та v0.6.x Reports/Sanitize/CI-циклів. Переважна більшість
> задач нижче (Етапи 1, 2, 5-9, 11 повністю; Етапи 3-4, 10 частково) з того часу
> реалізована й перевірена проти живого коду цим циклом — позначки `[x]` нижче звірені
> індивідуально, не перенесені механічно зі старого плану. Живий, регулярно оновлюваний
> статус — `docs/ROADMAP.md` ("Поточний статус") і `CHANGELOG.md`; цей документ лишається
> як історичний план і довідник "де саме в коді шукати конкретну можливість" для вже
> реалізованих пунктів.

## Мета документа

Цей документ фіксує практичний план доробок після глибокого аналізу репозиторію.

План орієнтований на поетапне доведення BRAVO SYSTEM REPORT до стабільного release-ready стану:

- релізний пакет має запускатися без ручних доробок;
- документація має відповідати фактичній архітектурі;
- звіти мають бути безпечними для передачі третім сторонам;
- Deep і Forensic профілі мають давати справді глибоку діагностику;
- CI має ловити регресії до merge/release.

## Поточна база

Уже реалізовано:

- модульна архітектура `src/*.ps1`;
- build у `dist/Get-BravoSystemReport.ps1`;
- SHA512 для runtime;
- root wrapper `Get-BravoSystemReport.ps1`;
- BAT-запускачі Quick/Full/Deep/Forensic/Launcher;
- JSON/HTML/CSV/ZIP export;
- Email export;
- Health Score;
- Storage Deep Audit skeleton;
- Storage Critical Findings;
- Local Windows Validation workflow.

## Ключові ризики

### 1. Release package може бути неповним

Root wrapper запускає `dist/Get-BravoSystemReport.ps1`, тому release package повинен містити `dist`.

Поточний release script має бути перевірений і виправлений так, щоб у release ZIP точно потрапляли:

```text
dist/Get-BravoSystemReport.ps1
dist/Get-BravoSystemReport.ps1.sha512
```

### 2. Старий моноліт у `src/Get-BravoSystemReport.ps1` — ВИРІШЕНО

Файл видалено. Актуальний runtime — виключно `dist/Get-BravoSystemReport.ps1`, зібраний з `src/*.ps1` через `Build-BRAVO-SystemReport.ps1`; `powershell-static-check.yml` більше не перевіряє наявність старого моноліту.

### 3. Health Score не враховує export errors — ВИРІШЕНО

`Update-BravoHealthScore` (`src/40-Health.ps1`) викликається вдруге в `src/90-Main.ps1` після export-етапів (JSON/HTML/CSV); JSON і HTML перегенеровуються з фінальною оцінкою, але лише якщо export-етапи додали нові `CollectionErrors` (щоб не дублювати дорогий HTML-рендер без потреби).

### 4. Немає безпечного режиму передачі звітів

Звіти можуть містити:

- computer name;
- user name;
- domain/workgroup;
- DNS suffix;
- IP addresses;
- MAC addresses;
- serial numbers;
- local administrators;
- service account names;
- installed software paths;
- фрагменти event logs.

Потрібен `-Sanitize`.

## Етап 1. Release Stabilization

### Ціль

Зробити так, щоб release ZIP був самодостатнім і запускався після розпакування.

### Задачі

- [x] Оновити `tools/New-ReleasePackage.ps1` — раніше скрипт взагалі не запускався (посилався на видалений `src/Get-BravoSystemReport.ps1`).
- [x] Додати у package include list:
  - [x] `dist/Get-BravoSystemReport.ps1`;
  - [x] `dist/Get-BravoSystemReport.ps1.sha512`.
- [x] Перевірити, що package не включає сформовані звіти з `reports/` (`$IncludeFiles` — явний allowlist, `reports/` там немає).
- [x] Перевірити, що package не включає sensitive artifacts (той самий allowlist-принцип).
- [x] Додати локальний тест release package (`tests/ReleasePackage.Tests.ps1`, Describe "v0.4.1 — Release package: створення, розпакування, запуск", входить у стандартний `Invoke-Pester -Path tests`):
  - [x] build runtime;
  - [x] create release ZIP (`tools/New-ReleasePackage.ps1`);
  - [x] unpack to temp;
  - [x] run `BRAVO-SystemReport-Quick.bat --nopause`;
  - [x] validate JSON (парситься, не порожній);
  - [x] validate HTML;
  - [x] validate exit code (`$process.ExitCode | Should -Be 0`).
  Додатково (v0.6.1): окремий "Unpack-and-run smoke test" крок безпосередньо в `.github/workflows/release.yml` — розпаковує САМЕ той package, що йде в реліз, у `$env:RUNNER_TEMP` (поза `$env:GITHUB_WORKSPACE`), звіряє `ScriptVersion`/`SchemaVersion`/`CollectionErrors`/`ExportErrors` у згенерованому JSON (Issue #100).
- [x] Описати процес у `docs/RELEASE.md` (розділ "Локальна перевірка перед релізом", кроки 1-4).

### Acceptance criteria

- Release ZIP містить `dist/Get-BravoSystemReport.ps1`.
- Root wrapper запускається з розпакованого ZIP.
- BAT Quick запускається з розпакованого ZIP.
- Створюються JSON і HTML.
- `CollectionErrors=0` у Quick smoke test.
- Немає sensitive generated reports у package.

## Етап 2. Legacy Cleanup

### Ціль

Прибрати плутанину між старим монолітом і новим модульним runtime.

### Задачі

- [x] Перевірити, чи використовується `src/Get-BravoSystemReport.ps1` — не редагувався з переходу на модульну архітектуру, реального використання не було.
- [x] Видалено після review (`git rm`), `legacy/`-перенесення визнано зайвим — уся історія доступна в git log.
- [x] Оновити README (дерево структури, борги, плани розвитку).
- [x] Оновити CHANGELOG.

### Acceptance criteria

- [x] У документації є один основний runtime flow: root wrapper → `dist/Get-BravoSystemReport.ps1`.
- [x] У release package немає старого моноліту.
- [x] Немає розбіжності між README, CHANGELOG, ROADMAP і фактичним запуском.

## Етап 3. Runtime Quality

### Ціль

Зробити runtime behavior передбачуваним і зручним для автоматизації.

### Задачі

- [x] Стале-success після export-помилки вирішено — АЛЕ не жодним із двох варіантів нижче
      (обидва залишились нереалізованими навмисно, після explicit рішення в Issue #91):
      `Update-BravoHealthScore` НЕ викликається повторно (Health лишається
      deterministic-lише-з-collection), і `Health.Collection`/`Health.Export`/`Health.Overall`
      schema-split НЕ впроваджено (issue сам дозволяв це пропустити заради мінімального
      backward-incompatible шляху). Замість цього: `Sync-BravoJsonIfExportErrorsChanged`
      (`src/90-Main.ps1`) пересинхронізує вже записаний JSON після кожної export-стадії
      (HTML/CSV, ZIP, Email), якщо `ExportErrors`/`GeneratedFiles` змінились — той самий
      файл на диску ніколи не лишається "stale success".
  - [ ] ~~Додати повторний `Update-BravoHealthScore` після export-етапів.~~ (свідомо не обрано)
  - [ ] ~~Або створити окрему секцію `Health.Collection`/`Health.Export`/`Health.Overall`~~ (свідомо не обрано)
- [x] Додати `-Strict`.
- [x] Додати контроль exit code — реалізовано, але з ІНШОЮ нумерацією, ніж запропонована
      тут (детально обґрунтовано при закритті Issue #90; канонічний контракт — `README.md`
      розділ "Exit code contract"):
  - [x] `0` — успішно;
  - [x] `1` — `CollectionErrors`/`ExportErrors` (тут запропоновано як "runtime failure" — фактично об'єднано з export errors, не окремий код);
  - [x] код collection errors у strict mode реалізовано, але як `4` (Strict + `Health.Status=CRITICAL`), не `2`;
  - [x] export errors впливають на exit code, але той самий код `1`, що й collection errors, не окремий `3`;
  - [x] `2` фактично зайнято під фатальну неопрацьовану помилку (top-level trap), `3` — під "JSON не згенеровано" (validation failed, найближчий аналог запропонованого тут "4 — validation failed").
- [ ] Уніфікувати network schema. (не перевірено цим циклом — потребує окремої ревізії)
- [x] Уніфікувати storage thresholds — `Get-BravoStorageThresholds` (`src/32-Collectors-Storage.ps1`) канонічна функція, обидва реальні call sites (`Get-BravoStorageRiskSummary`, базова перевірка вільного місця) використовують саме її, а не дубльовану inline-логіку; `tests/StorageThresholds.Tests.ps1` (29 тестів).
- [ ] HTML-encode всі динамічні значення. (не перевірено цим циклом — `HtmlEncode` використовується в `src/51-Export-Html.ps1`, але повнота покриття "всіх динамічних значень" потребує окремої ревізії, не зроблено тут)

### Acceptance criteria

- Export errors впливають на фінальний статус.
- CI може перевіряти exit code.
- JSON schema не дублює одні й ті самі network values у різних місцях без потреби.
- HTML не вставляє сирі значення без encoding.

## Етап 4. Safe Sharing / Sanitize

### Ціль

Дозволити безпечну передачу звітів третім сторонам.

**Статус: реалізовано** (`src/45-Sanitize.ps1`, fail-closed з v0.6.1). Усі 4 параметри
нижче існують і покриті `tests/Sanitize.Tests.ps1` (34 тести). Один нюанс проти acceptance
criteria нижче: "CI regex scan на IP/MAC/serial/user/domain literals" свідомо НЕ
реалізовано як сліпий regex — `CHANGELOG.md` документує явну відмову (версії встановленого
ПЗ на кшталт `10.0.11.50` масово збігаються з форматом IPv4 і дають сотні false positive);
замість цього — точкові sentinel-based перевірки конкретних полів схеми в
`tests/Sanitize.Tests.ps1`, що реально покривають той самий намір (довести відсутність
витоку) надійнішим способом.

### Нові параметри

```powershell
-Sanitize
-SanitizeLevel Basic|Strict
-SkipPublicIP
-Offline
```

### Basic sanitize

Маскувати:

- public IPv4;
- MAC addresses;
- serial numbers;
- local administrators;
- user name;
- computer name;
- domain/workgroup.

### Strict sanitize

Додатково маскувати:

- private IPv4;
- DNS suffix;
- service account names;
- install locations;
- event log messages, якщо вони містять імена/шляхи/IP.

### Acceptance criteria

- `-Sanitize` не ламає JSON structure.
- HTML/CSV/ZIP також містять sanitized values.
- У CI є regex scan на IP/MAC/serial/user/domain literals.
- `-Offline` не виконує зовнішні HTTPS-запити.
- `-SkipPublicIP` пропускає public IP detection без помилки.

## Етап 5. Hardware Deep Inventory

### Ціль

Розширити hardware audit до рівня повної інвентаризації.

### Задачі

- [x] Secure Boot (`src/34-Collectors-Security.ps1`, `Get-BravoSecureBootStatus`).
- [x] TPM (`src/34-Collectors-Security.ps1`, `Test-BravoTpmAccessDeniedError` + колектор).
- [x] Motherboard (`src/31-Collectors-Hardware.ps1`, `Win32_BaseBoard`).
- [x] GPU (`src/31-Collectors-Hardware.ps1`, `Win32_VideoController`).
- [x] Monitors (`src/31-Collectors-Hardware.ps1`, `WmiMonitorID`, `tests/WmiMonitorCharArray.Tests.ps1`).
- [x] Chassis type (`src/31-Collectors-Hardware.ps1`, `Get-BravoChassisTypeText` + `Win32_SystemEnclosure`).
- [x] CPU socket (`src/31-Collectors-Hardware.ps1`, `Win32_Processor`).

### Джерела даних

- `Confirm-SecureBootUEFI`, якщо доступно;
- `Get-Tpm`, якщо доступно;
- `Win32_BaseBoard`;
- `Win32_VideoController`;
- `WmiMonitorID`, якщо доступно;
- `Win32_SystemEnclosure`;
- `Win32_Processor`.

### Acceptance criteria

- Quick не стає важким.
- Deep/Forensic збирають розширені hardware дані.
- Якщо cmdlet/class недоступні, додається collection warning/error без падіння всього скрипта.

## Етап 6. Storage Deep Inventory

### Ціль

Додати діагностику storage, корисну для серверів, VM і робочих станцій.

### Задачі

- [x] BitLocker status (`src/32-Collectors-Storage.ps1`, `Get-BitLockerVolume`).
- [x] Pagefile (`src/32-Collectors-Storage.ps1`, `PageFiles`).
- [x] Shadow Copies / VSS (`src/32-Collectors-Storage.ps1`, `ShadowCopies`).
- [x] Storage Spaces (`src/32-Collectors-Storage.ps1`, `StoragePools`).
- [x] SMART/NVMe health (`src/32-Collectors-Storage.ps1`, `SmartPredictFailures`/`ReliabilityCounters`).
- [x] Єдині thresholds для всіх storage findings (`Get-BravoStorageThresholds`, `tests/StorageThresholds.Tests.ps1` — 29 тестів).

### Acceptance criteria

- Storage findings не дублюються.
- Для системного тому є окрема логіка warning threshold.
- У HTML є зрозуміла storage summary.
- У JSON є структуровані storage-секції.

## Етап 7. Network Deep Audit

### Ціль

Зробити network audit придатним для діагностики підключень, портів і мережевих проблем.

### Задачі

- [x] Adapter speed/status/driver (`src/33-Collectors-Network.ps1`, `LinkSpeed`/`Status`/`DriverVersion`/`DriverProvider`).
- [x] Routing table (`src/33-Collectors-Network.ps1`, `Network.Routing`).
- [x] ARP/Neighbor table (`src/33-Collectors-Network.ps1`).
- [x] Listening ports з ProcessName (`src/33-Collectors-Network.ps1`, `Get-BravoProcessNameLookup`, `tests/ProcessNameLookup.Tests.ps1`).
- [x] Established connections з ProcessName (`src/33-Collectors-Network.ps1`, `Network.Connections.EstablishedConnections`).
- [x] WinHTTP proxy (`src/33-Collectors-Network.ps1`, `Network.WinHttpProxy`).
- [x] SMB shares (`src/33-Collectors-Network.ps1`, `Get-SmbShare`).
- [x] DNS suffix/search list (`src/33-Collectors-Network.ps1`, `DNSSuffixSearchOrder`).

### Acceptance criteria

- Listening ports показують не тільки PID, а й ProcessName.
- Established connections доступні у Deep/Forensic.
- Public IP detection можна вимкнути.
- Network schema узгоджена між JSON/HTML/CSV.

## Етап 8. Security Baseline

### Ціль

Дати практичну security-картину Windows-машини без збору секретів.

### Задачі

- [x] UAC full policy (`src/34-Collectors-Security.ps1`, `tests/UacPromptText.Tests.ps1`).
- [x] RDP NLA (`src/34-Collectors-Security.ps1`, "RDP details: NLA, port, firewall scope, allowed users").
- [x] RDP port.
- [x] RDP allowed users (`AllowedUsers`, `tests/RdpGroupResolution.Tests.ps1`).
- [x] WinRM listeners (`Security.WinRM.Listeners`).
- [x] WinRM auth flags.
- [x] SMBv1 (`Security.SMBv1`).
- [x] SMB signing (`Security.SMB.ServerSigningRequired`/`ServerSigningEnabled`).
- [x] Insecure guest access (`Security.SMB.InsecureGuestLogonsEnabled`).
- [x] TLS registry baseline (`Get-BravoTlsProtocolStatus`, `tests/TlsProtocolStatus.Tests.ps1`).
- [x] Defender details (`Security.Defender`, включно з `AMRunningMode` passive-detection).
- [x] Password policy (`Get-BravoNetAccountsOutput`/`ConvertFrom-BravoNetAccountsOutput`, `tests/NetAccountsParsing.Tests.ps1`).
- [x] Audit policy (`ConvertFrom-BravoAuditPolicyCsv`, регресію auditpol-парсингу виправлено цим циклом).
- [x] Autoruns (`Security.Autoruns`, гейтовано Deep/Forensic).
- [x] Scheduled tasks (гейтовано Deep/Forensic — explicit inner-gate фікс цього циклу, `src/34-Collectors-Security.ps1`).

### Acceptance criteria

- Findings мають рекомендації.
- Не збираються паролі, токени, cookies, private keys або browser credentials.
- Security data доступні в JSON і коротко відображаються в HTML.

## Етап 9. Updates and Event Diagnostics

### Ціль

Додати діагностику оновлень, pending reboot і ключових event log provider-ів.

### Задачі

- [x] Installed hotfixes (`Updates.Installed.Recent`).
- [x] Pending reboot detection (`src/39-Collectors-Updates.ps1`, `Get-BravoPendingRebootInfo`).
- [x] Windows Update errors (`Get-BravoWindowsUpdateAgentInfo`).
- [x] System provider summary (`src/37-Collectors-Events.ps1`, `EventLogs.TopErrorSources`/`LogSummaries`).
- [x] Application provider summary.
- [x] Setup log summary.
- [x] Security summary без дампу чутливих подій (лише агреговані лічильники/LastMessage — сирі security events не дампляться; `LastMessage` повністю редагується під `-Sanitize`).
- [x] Disk/Ntfs/storport diagnostics (`EventLogs.HardwareDiagnostics`, провайдери Disk/Ntfs/storport/stornvme).
- [x] WHEA diagnostics (`Microsoft-Windows-WHEA-Logger`).
- [x] Kernel-Power diagnostics (`Microsoft-Windows-Kernel-Power`).
- [x] BugCheck diagnostics (`Microsoft-Windows-WER-SystemErrorReporting`).

### Acceptance criteria

- Event log збір не робить Forensic профіль надмірно повільним.
- Є grouping by ProviderName/EventId/Level.
- Є LastSeen/Count.
- Є top recurring errors.

## Етап 10. Reports and Support UX

### Ціль

Зробити звіт зручним для підтримки, Redmine/GitHub і ручного аналізу.

### Задачі

- [x] TXT summary (`src/55-Export-Txt.ps1`, параметр `-TXT`).
- [x] Markdown summary (`src/56-Export-Md.ps1`, параметр `-MD`).
- [ ] HTML collapsible sections. (не реалізовано — залишається в `docs/ROADMAP.md` "Next")
- [ ] HTML filters by severity/category. (не реалізовано — залишається в `docs/ROADMAP.md` "Next")
- [x] Copy-friendly support summary (TXT/MD формати саме для цього і призначені).
- [x] JSON schema documentation (`docs/SCHEMA.md`).
- [ ] Окрема секція `Recommendations`. (не реалізовано як окрема top-level секція — рекомендації й далі лише per-finding поле `Recommendation`, не агреговані окремо)

### Acceptance criteria

- Markdown можна вставити в Redmine/GitHub без ручного форматування.
- TXT summary можна швидко надіслати у чат підтримки.
- HTML залишається читабельним на великих звітах.

## Етап 11. CI / Quality Gates

### Ціль

Автоматично ловити регресії до merge/release.

### Задачі

- [x] Parser check для всіх `src/*.ps1` (`powershell-static-check.yml` + `local-windows-validation.yml`, обидва).
- [x] Quick BAT test (`local-windows-validation.yml`, "Quick runtime test").
- [x] Full runtime test (`local-windows-validation.yml`, "Full runtime test і валідація секції Updates").
- [x] Deep runtime test з `-CSV -Zip` (`local-windows-validation.yml`, "Deep runtime test (CSV + ZIP)").
- [x] Forensic smoke test з `-JSONOnly` (`tests/ExecutionContract.Tests.ps1`, "Forensic -JSONOnly smoke test" — live-підтверджено цим циклом: exit code 0, JSON валідний, HTML НЕ створено).
- [x] Release package build test (`tests/ReleasePackage.Tests.ps1`).
- [x] Release package unpack-and-run test (`tests/ReleasePackage.Tests.ps1` локально + `.github/workflows/release.yml` "Unpack-and-run smoke test" безпосередньо в release-пайплайні, v0.6.1/Issue #100).
- [x] ZIP content validation (`release.yml`, "Verify package content" — SHA512, структура, версія).
- [x] HTML generated validation (наскрізно в `tests/ExecutionContract.Tests.ps1`).
- [x] JSONOnly no HTML validation (`tests/ExecutionContract.Tests.ps1`, live-підтверджено: `-JSONOnly` не створює HTML).
- [x] Sanitize validation (`tests/Sanitize.Tests.ps1`, 34 тести + live CI-тест `-SanitizeLevel Strict`).

### Acceptance criteria

- PR не проходить, якщо build/runtime/JSON validation падає.
- Release package перевіряється до merge.
- CI не друкує public IP value у logs.
- Sensitive generated reports не потрапляють у tracked files.

## Рекомендований порядок реалізації

1. **Release package fix**.
2. **Legacy cleanup**.
3. **CI release package test**.
4. **Health/export status fix**.
5. **Network schema cleanup**.
6. **Storage thresholds cleanup**.
7. **HTML encoding**.
8. **`-Sanitize`, `-SkipPublicIP`, `-Offline`**.
9. **TPM/Secure Boot/BitLocker/Pending Reboot**.
10. **RDP/WinRM/SMB/TLS baseline**.
11. **EventLog provider summary**.
12. **Markdown/TXT summary**.
13. **Full/Deep/Forensic CI coverage**.

## Definition of Done для кожної задачі

Кожна задача вважається завершеною, якщо:

- код або документація оновлені;
- README/ROADMAP/CHANGELOG оновлені, якщо зміна впливає на користувача;
- build проходить;
- parser check проходить;
- runtime smoke test проходить;
- `CollectionErrors` перевірено;
- немає випадково закомічених звітів;
- commit message українською мовою;
- підготовлено короткий review результату.
