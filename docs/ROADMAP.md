# Roadmap BRAVO SYSTEM REPORT

## Поточний статус

Поточна стабільна версія: **ScriptVersion 0.5.0** (SchemaVersion 0.6.0).

## Stabilization milestone (зовнішнє ТЗ P0-P3)

За результатами зовнішнього технічного завдання на стабілізацію реалізовано **P0-A (Runtime stabilization)** — execution contract, exit codes, розділення CollectionErrors/ExportErrors. Злито в `developer` через PR #45 ("Stabilization P0: execution contract, exit codes, CollectionErrors/ExportErrors", merge commit `7b951a075b5d3ea3ef7c1516c5fec6da98d2c935`) — деталі в `CHANGELOG.md` ("Stabilization P0"). **P0 не завершено повністю**: P0-B (Lifecycle correctness) лишається відкритим, статус нижче.

**P0-A — Runtime stabilization → DONE**

- [x] P0.1 Уніфікувати execution contract (root wrapper мав власний, розбіжний з `dist` param-блок — переписано на transparent passthrough).
- [x] P0.2 `-Zip:$false`/`-NoZip` коректно форвардяться через обидва хопи (wrapper→dist, dist→elevation).
- [x] P0.3 Єдиний default `Profile` (`Forensic`, лише в `src/05-Params.ps1`).
- [x] P0.4 CollectionErrors/ExportErrors розділені, export-pipeline спрощено (Health Score рахується один раз).
- [x] P0.5 Детермінований exit code contract (0/1/2/3), elevation прокидає реальний exit code дочірнього процесу.

**P0-B — Lifecycle correctness → TODO**

Під час злиття PR #45 з `main` до гілки незалежно потрапив колектор Windows Update/Lifecycle (`Get-BravoUpdatesAudit`, таблиця дат підтримки Windows 2000..11 25H2/Server 2025) — але це не закриває P0.6/P0.7: таблиця лишається inline-масивом усередині `src/39-Collectors-Updates.ps1`, а не централізованим dataset/data model, і потребує окремого процесу актуалізації.

- [ ] P0.6 Актуалізація Windows Lifecycle database (звірка дат підтримки з офіційними джерелами Microsoft, процес регулярного оновлення).
- [ ] P0.7 Винесення lifecycle records у централізований dataset/data model (окремий JSON/PS-data файл замість inline-масиву в колекторі, щоб оновлення дат не вимагало правок логіки колектора).
- [ ] P1 (централізовані storage thresholds, collector/analyzer розділення, CPU/RAM findings, `-Offline`, `-SkipGeoIP`, `-SanitizeLevel`, розширення Pester/CI) — окремі майбутні PR.
- [ ] P2 (cleanup, dead parameters, `.editorconfig`/`.gitattributes` — частину вже закрито попередніми раундами код-ревю цієї сесії, гл. `CHANGELOG.md`).
- [ ] P3 (Deep Security: TPM/Secure Boot/BitLocker, повноцінний Forensic profile) — явно поза межами stabilization-етапу, окремі майбутні PR.

**Додаткові результати PR #45** (виявлені й закриті під час верифікації/CI-циклу, не входили в оригінальний обсяг P0-A):

- Pester regression suite: **35 passed / 0 failed / 1 skipped** на merge SHA `98ba948144bd033e2e28051651bf91c9a5752ab1`.
- `tests/WorkflowEncoding.Tests.ps1` — regression-guard: жоден `run:`-крок з ефективним `shell: powershell` (Windows PowerShell 5.1) у `.github/workflows/*.yml` не містить небезпечного non-ASCII тексту (self-hosted раннер читає temp-скрипт без BOM у ANSI-кодуванні, не UTF-8; `pwsh`/`bash`-кроки та YAML-коментарі поза перевіркою).
- CI-тригер `local-windows-validation.yml` розширено на `pull_request.branches: developer` (раніше PR у `developer` взагалі не запускав валідацію).
- `tests/EndToEnd.Tests.ps1` — regression-покриття актуального `Updates.*` контракту моделі (замість застарілого мертвого `WindowsUpdate.*`, який залишився незаповненим після заміни колектора при злитті з `main`).
- CI-верифікація на Quick/Full/Deep профілях (build, SHA512, parser check, JSON validation, Updates validation, Public IPv4 scan).
- Exit-code contract regression test — виправлено test harness (`Start-Process -Wait -PassThru` замість голого `powershell.exe`, щоб навмисний ненульовий exit code дочірнього процесу не протікав у стан самого CI-кроку).
- Bootstrap NuGet provider для `Install-Module Pester` на self-hosted Windows-раннері (non-interactive `Install-Module` падав без явного `Install-PackageProvider -Name NuGet -Force` + TLS 1.2).

Проєкт перейшов на модульну архітектуру:

- параметри запуску винесені у `src/05-Params.ps1`;
- helper-функції винесені у `src/10-Core.ps1`;
- модель звіту винесена у `src/20-ReportModel.ps1`;
- collector-и винесені у модулі `src/30-*` ... `src/38-*`;
- Health Score винесено у `src/40-Health.ps1`;
- export-и винесені у `src/50-*` ... `src/54-*`;
- монолітний runtime збирається у `dist/Get-BravoSystemReport.ps1` через `Build-BRAVO-SystemReport.ps1`.

## Найближчий milestone: v0.4.1 Release Stabilization

Ціль: зробити релізний пакет і документацію узгодженими з фактичною модульною архітектурою.

- [x] Виправити `tools/New-ReleasePackage.ps1`, щоб release ZIP включав:
  - [x] `dist/Get-BravoSystemReport.ps1`;
  - [x] `dist/Get-BravoSystemReport.ps1.sha512`.
  (скрипт до цього фіксу взагалі не запускався — посилався на видалений `src/Get-BravoSystemReport.ps1`; тепер додатково звіряє sha512 перед пакуванням і використовує `src/90-Main.ps1` для визначення версії).
- [ ] Додати перевірку release package:
  - [ ] створити ZIP;
  - [ ] розпакувати у temporary directory;
  - [ ] запустити `BRAVO-SystemReport-Quick.bat --nopause` з розпакованого пакета;
  - [ ] перевірити створення JSON/HTML.
- [x] Визначити долю старого моноліту `src/Get-BravoSystemReport.ps1`: видалено (весь runtime формується з `src/*.ps1` модулів через `Build-BRAVO-SystemReport.ps1`).
- [x] Оновити `examples/README.md` відповідно до поточного wrapper/dist flow (`-Zip` за замовчуванням, `-NoZip` для вимкнення).
- [ ] Додати `docs/RELEASE.md` з описом створення й перевірки release package.

## v0.4.2 Runtime Quality

Ціль: прибрати логічні ризики runtime і зробити результат звіту більш передбачуваним.

- [x] Перераховувати Health Score після export-етапів (`Update-BravoHealthScore` викликається вдруге в `90-Main.ps1`, JSON і HTML перегенеровуються лише якщо з'явились нові `CollectionErrors`).
- [ ] Додати режим strict validation:
  - [ ] `-Strict`;
  - [ ] ненульовий exit code при критичних collection/export помилках;
  - [ ] окремий exit code для parser/build/runtime/export failures.
- [ ] Уніфікувати network schema:
  - [ ] `Network.IP.IPv4`;
  - [ ] `Network.IP.PrimaryIPv4`;
  - [ ] `Network.IP.PrimaryInterface`;
  - [ ] `Network.IP.PublicIPv4`;
  - [ ] прибрати дублювання top-level `Network.IPv4`, якщо воно не потрібне.
- [ ] Уніфікувати storage thresholds:
  - [ ] один набір порогів для basic і deep storage audit;
  - [ ] уникнути дублювання findings для одного й того самого тому;
  - [ ] винести thresholds у helper/config-блок.
- [ ] HTML export:
  - [ ] HTML-encode всі динамічні значення;
  - [ ] HTML-encode findings/errors rows;
  - [ ] перевірити коректність великих таблиць.

## v0.4.3 Safe Sharing / Sanitize

Ціль: зробити звіти безпечними для передачі третім сторонам.

- [ ] Додати параметр `-Sanitize`.
- [ ] Додати параметр `-SanitizeLevel Basic|Strict`.
- [x] Додати параметр `-SkipPublicIP` (`src/05-Params.ps1`, гейтинг профілем Full/Deep/Forensic).
- [ ] Додати параметр `-Offline`, який вимикає зовнішні HTTPS-запити.
- [ ] Маскувати у JSON/HTML/CSV/TXT/Markdown:
  - [ ] computer name;
  - [ ] user name;
  - [ ] domain/workgroup;
  - [ ] DNS suffix;
  - [ ] public IPv4;
  - [ ] private IPv4, якщо `Strict`;
  - [ ] MAC addresses;
  - [ ] serial numbers;
  - [ ] local administrators;
  - [ ] service account names;
  - [ ] sensitive install paths.
- [ ] Додати CI validation для sanitize:
  - [ ] запуск `-Sanitize`;
  - [ ] regex scan JSON/HTML на IP/MAC/serial/user/domain literals;
  - [ ] перевірка, що структура звіту не ламається після маскування.

## v0.5.0 Deep Inventory

Ціль: розширити фактичний збір даних для Deep і Forensic профілів.

### Hardware Inventory

- [x] BIOS/UEFI: version, release date, serial number.
- [x] RAM modules: slot, vendor, serial, speed, size.
- [~] CPU: cores, logical processors, max clock; socket — наступний етап.
- [ ] ComputerSystem: chassis type.
- [ ] Secure Boot.
- [ ] TPM.
- [ ] Motherboard.
- [ ] GPU.
- [ ] Monitors.

### Storage Audit

- [x] Logical disks: drive letter, filesystem, total/free/used.
- [x] Volumes: health, operational status, size/free/risk.
- [x] Physical disks: basic model, serial, size, media type/status.
- [x] Findings для низького вільного місця.
- [ ] BitLocker status.
- [ ] Pagefile.
- [ ] Shadow Copies / VSS.
- [ ] Storage Spaces.
- [ ] SMART/NVMe health, якщо доступно штатними засобами.

### Network Audit

- [x] IP/DNS/Gateway/DHCP/static.
- [x] Primary IPv4 detection.
- [x] Public IPv4 detection без виводу значення у консоль.
- [x] Listening ports з OwningProcess.
- [ ] Network adapters: name, MAC, speed, status, driver.
- [ ] Routing table.
- [ ] ARP/Neighbor table.
- [ ] Listening ports з ProcessName.
- [ ] Established connections з ProcessName.
- [ ] WinHTTP proxy.
- [ ] SMB shares.

### Security Baseline

- [x] UAC basic enabled/disabled.
- [x] RDP basic enabled/disabled.
- [x] Antivirus через `SecurityCenter2`.
- [x] Firewall profiles.
- [x] Local admins через SID `S-1-5-32-544`.
- [ ] UAC full policy.
- [ ] RDP NLA, port, firewall scope, allowed users.
- [ ] WinRM listeners and auth.
- [ ] SMBv1.
- [ ] SMB signing / insecure guest access.
- [ ] TLS 1.0/1.1/1.2/1.3 registry status.
- [ ] Defender details: realtime protection, signature age, engine/platform version.
- [ ] Password policy.
- [ ] Audit policy.
- [ ] Autoruns.
- [ ] Scheduled tasks.

### Updates and Event Logs

- [x] System errors/warnings за 24h і за період профілю.
- [x] Installed hotfixes (`39-Collectors-Updates.ps1`, `WindowsUpdate.InstalledHotFixes`).
- [x] Pending reboot detection (`WindowsUpdate.PendingRebootRequired`).
- [x] Windows Update errors (`WindowsUpdate.SearchError`; pending updates з Catalog-посиланням у Deep/Forensic).
- [ ] Event logs: System, Application, Setup, Security summary.
- [ ] Provider summary.
- [ ] Critical/Error/Warning grouping.
- [ ] Disk/Ntfs/storport/WHEA/Kernel-Power/BugCheck diagnostics.

## v0.6.0 Reports and UX

Ціль: зробити результати зручнішими для підтримки, Redmine/GitHub і передачі замовнику.

- [x] JSON — повні структуровані дані.
- [x] HTML — базовий візуальний звіт.
- [x] CSV — коротка інвентаризація.
- [x] ZIP — пакет звітів.
- [ ] TXT summary.
- [ ] Markdown summary для Redmine/GitHub.
- [ ] HTML filters/collapsible sections.
- [ ] Findings grouped by severity/category.
- [ ] Copy-friendly support summary.
- [ ] JSON schema documentation.

## v0.6.1 Interactive HTML Dashboard & Tabs

Ціль: перетворити HTML-звіт з лінійної сторінки на автономний інтерактивний dashboard із вкладками, метричними картками, health-індикаторами, таблицями та майбутніми UX-функціями.

Ключова вимога: HTML-звіт має залишатися повністю автономним і відкриватися на ізольованих серверах без доступу до інтернету. Заборонено використовувати зовнішні CDN для CSS/JS.

### Етап 1. Архітектура даних та підготовка бекенду PowerShell

- [ ] Рефакторинг об'єкта `$Report`:
  - [ ] структурувати дані так, щоб вони логічно відповідали майбутнім вкладкам:
    - [ ] `OS`;
    - [ ] `Hardware`;
    - [ ] `Network`;
    - [ ] `Security`;
    - [ ] `Services`;
    - [ ] `Software`.
- [ ] Виправлення порожніх та обмежених метрик:
  - [ ] реалізувати чесний розрахунок відсотка утилізації RAM;
  - [ ] прибрати ліміт `Select-Object -First 50` для встановленого ПЗ;
  - [ ] додати збір шлюзів `Gateway` для мережевої вкладки;
  - [ ] додати збір DNS-серверів для мережевої вкладки.
- [ ] Підготовка контенту для індикаторів стану Health Status:
  - [ ] додати в `$Report` експрес-оцінку стану;
  - [ ] приклад: `$Report.Status = "OK"`;
  - [ ] приклад: `$Report.Status = "Warning"`, якщо місце на диску менше 15%;
  - [ ] узгодити `$Report.Status` з наявною секцією `$Report.Health.Status`.

### Етап 2. Проєктування UI/UX шаблону HTML / CSS

- [ ] Верстка каркасу Layout:
  - [ ] фіксований або адаптивний Header;
  - [ ] у Header показувати назву ПК;
  - [ ] у Header показувати uptime;
  - [ ] у Header показувати health/status;
  - [ ] у Header показувати дату формування звіту;
  - [ ] додати блок навігації з кнопками-перемикачами вкладок.
- [ ] Дизайн головного дашборду General Tab:
  - [ ] створити метричні картки Grid Cards для CPU;
  - [ ] створити метричні картки Grid Cards для RAM;
  - [ ] створити метричні картки Grid Cards для Disk;
  - [ ] створити метричні картки Grid Cards для OS;
  - [ ] додати колірне кодування:
    - [ ] зелений = OK;
    - [ ] жовтий = Увага;
    - [ ] червоний = Критично.
- [ ] Верстка контенту для вкладок:
  - [ ] спроєктувати універсальний стиль таблиць `.data-table`;
  - [ ] використовувати `.data-table` для системних параметрів;
  - [ ] створити прокручувані списки для великих масивів даних;
  - [ ] для великих таблиць використовувати `max-height` з `overflow-y: auto`;
  - [ ] застосувати прокручувані блоки для ПЗ, процесів і логів подій.

### Етап 3. Інтеграція логіки перемикання JavaScript

- [ ] Написання таборування на Vanilla JS:
  - [ ] реалізувати функцію `openTab(event, tabId)`;
  - [ ] функція має приховувати всі блоки контенту через `display: none`;
  - [ ] функція має показувати тільки обраний блок через `display: block`;
  - [ ] автоматично керувати CSS-класом `.active` для кнопок вкладок;
  - [ ] користувач має чітко бачити, у якій вкладці перебуває.
- [ ] Оптимізація та автономність:
  - [ ] інтегрувати JS-код безпосередньо всередину тегу `<script>` в HTML-шаблоні;
  - [ ] не використовувати зовнішні JavaScript-файли;
  - [ ] не використовувати CDN;
  - [ ] перевірити відкриття HTML-звіту на ізольованому сервері без інтернету.

### Етап 4. Динамічна збірка звіту в PowerShell

- [ ] Злиття логіки та дизайну:
  - [ ] загорнути HTML-код у PowerShell here-string `@" ... "@`;
  - [ ] відокремити генерацію даних від HTML-розмітки настільки, наскільки це можливо в межах поточної архітектури.
- [ ] Цикли для масивів даних:
  - [ ] замінити статичні рядки на PowerShell-вирази генерації всередині HTML;
  - [ ] автоматично генерувати рядки таблиць на основі масивів даних;
  - [ ] використовувати `foreach` для програм;
  - [ ] використовувати `foreach` для дисків;
  - [ ] використовувати `foreach` для мережевих адаптерів;
  - [ ] використовувати `foreach` для процесів, служб і подій, де це доречно.

### Етап 5. Просунутий функціонал, фічі на майбутнє

- [ ] Живий пошук / фільтрація:
  - [ ] додати поле пошуку над списком програм;
  - [ ] реалізувати швидку фільтрацію софту на льоту через JavaScript;
  - [ ] у майбутньому поширити пошук на процеси, служби та event logs.
- [ ] Друк та експорт у PDF через Edge CLI:
  - [ ] додати друковані CSS-стилі `@media print`;
  - [ ] під час друку приховувати кнопки вкладок;
  - [ ] зробити так, щоб звіт акуратно лягав на сторінки A4;
  - [ ] передбачити автоматичну конвертацію HTML у PDF через Edge CLI.
- [ ] Темна тема Dark Mode:
  - [ ] додати перемикач теми день/ніч;
  - [ ] реалізувати темну тему на основі CSS-змінних;
  - [ ] зберегти читабельність таблиць, статусів і health-індикаторів у темній темі.

### Графік реалізації інтерактивного HTML-звіту

```text
[Спринт 1: Бекенд, 1-2 дні]
    ↓
[Спринт 2: CSS/UI, 1-2 дні]
    ↓
[Спринт 3: JS/Вкладки, 1 день]
    ↓
[Спринт 4: Інтеграція, 1-2 дні]
```

### Acceptance criteria для Dashboard & Tabs

- [ ] HTML-звіт відкривається без інтернету.
- [ ] Усі CSS і JS вбудовані в HTML.
- [ ] Є вкладки General, OS, Hardware, Network, Security, Services, Software.
- [ ] Вкладки перемикаються без перезавантаження сторінки.
- [ ] Активна вкладка має видимий `.active` стан.
- [ ] General Tab містить метричні картки CPU, RAM, Disk, OS.
- [ ] Великі таблиці не розтягують сторінку безконтрольно, а мають scroll-контейнери.
- [ ] Встановлене ПЗ не обрізається штучним `Select-Object -First 50`.
- [ ] Gateway і DNS відображаються в Network tab.
- [ ] Health/status показується у Header і General Tab.

## v0.7.0 CI / Quality Gates

Ціль: посилити автоматичні перевірки перед merge/release.

- [x] `git diff --check`.
- [x] Build modular monolith.
- [x] PowerShell parser check для `dist`.
- [x] Quick runtime test.
- [x] JSON validation.
- [x] `CollectionErrors=0` для Quick CI.
- [x] Public IPv4 literal scan.
- [x] Deep runtime test з `-CSV -Zip`.
- [x] Базовий Pester-набір (`tests/`: чисті helper-функції, консистентність build-маніфесту, наскрізний E2E-прогін), запускається і в CI, і локально через `Invoke-Pester tests/`.
- [ ] Parser check для всіх `src/*.ps1` (окремо від `dist`).
- [ ] Quick BAT test.
- [ ] Full runtime test.
- [ ] Forensic smoke test з `-JSONOnly`.
- [ ] Release package build test.
- [ ] Release package unpack-and-run test.
- [ ] ZIP content validation.
- [ ] HTML generated / JSONOnly no HTML validation.
- [ ] Sanitize validation після реалізації `-Sanitize`.

## Технічний борг

- [x] Усунути плутанину між `src/Get-BravoSystemReport.ps1` і модульним runtime у `dist` — застарілий моноліт видалено, `powershell-static-check.yml` більше не посилається на нього.
- [x] Уніфікувати версії `ScriptVersion`, `SchemaVersion`, README, CHANGELOG — README/ROADMAP синхронізовані з фактичними версіями (release package все ще потребує окремої перевірки, див. v0.4.1 Release Stabilization вище).
- [ ] Додати `docs/SCHEMA.md`.
- [ ] Додати `docs/TESTING.md` (базовий Pester-набір уже є в `tests/`, документ ще не написаний).
- [ ] Додати `docs/RELEASE.md`.
- [ ] Описати правила сумісності Windows PowerShell 5.1 / PowerShell 7.

## Правило виконання етапів

Після кожного етапу потрібно:

1. виконати build;
2. виконати parser check;
3. виконати runtime smoke test;
4. перевірити `CollectionErrors`;
5. перевірити, чи потрібно оновити README/ROADMAP/CHANGELOG/docs;
6. зробити commit українською мовою;
7. підготувати короткий review зміни.
