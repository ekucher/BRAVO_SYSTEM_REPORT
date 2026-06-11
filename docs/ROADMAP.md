# Roadmap BRAVO SYSTEM REPORT

## Поточний статус

Поточна стабільна версія: **v0.4.0**.

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

- [ ] Виправити `tools/New-ReleasePackage.ps1`, щоб release ZIP включав:
  - [ ] `dist/Get-BravoSystemReport.ps1`;
  - [ ] `dist/Get-BravoSystemReport.ps1.sha512`.
- [ ] Додати перевірку release package:
  - [ ] створити ZIP;
  - [ ] розпакувати у temporary directory;
  - [ ] запустити `BRAVO-SystemReport-Quick.bat --nopause` з розпакованого пакета;
  - [ ] перевірити створення JSON/HTML.
- [ ] Визначити долю старого моноліту `src/Get-BravoSystemReport.ps1`:
  - [ ] прибрати з release package;
  - [ ] перенести у `legacy/`;
  - [ ] або видалити після перевірки, що весь runtime формується з модулів.
- [ ] Оновити `examples/README.md` відповідно до поточного wrapper/dist flow.
- [ ] Додати `docs/RELEASE.md` з описом створення й перевірки release package.

## v0.4.2 Runtime Quality

Ціль: прибрати логічні ризики runtime і зробити результат звіту більш передбачуваним.

- [ ] Перераховувати Health Score після export-етапів або додати окремий `ExportHealth`.
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
- [ ] Додати параметр `-SkipPublicIP`.
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
- [ ] Installed hotfixes.
- [ ] Pending reboot detection.
- [ ] Windows Update errors.
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

## v0.7.0 CI / Quality Gates

Ціль: посилити автоматичні перевірки перед merge/release.

- [x] `git diff --check`.
- [x] Build modular monolith.
- [x] PowerShell parser check для `dist`.
- [x] Quick runtime test.
- [x] JSON validation.
- [x] `CollectionErrors=0` для Quick CI.
- [x] Public IPv4 literal scan.
- [ ] Parser check для всіх `src/*.ps1`.
- [ ] Quick BAT test.
- [ ] Full runtime test.
- [ ] Deep runtime test з `-CSV -Zip`.
- [ ] Forensic smoke test з `-JSONOnly`.
- [ ] Release package build test.
- [ ] Release package unpack-and-run test.
- [ ] ZIP content validation.
- [ ] HTML generated / JSONOnly no HTML validation.
- [ ] Sanitize validation після реалізації `-Sanitize`.

## Технічний борг

- [ ] Усунути плутанину між `src/Get-BravoSystemReport.ps1` і модульним runtime у `dist`.
- [ ] Вирішити, чи потрібен `src/Get-BravoSystemReport.ps1` як legacy artifact.
- [ ] Уніфікувати версії `ScriptVersion`, `SchemaVersion`, README, CHANGELOG і release package.
- [ ] Додати `docs/SCHEMA.md`.
- [ ] Додати `docs/TESTING.md`.
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
