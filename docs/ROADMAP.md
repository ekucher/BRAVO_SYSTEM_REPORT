# Roadmap BRAVO SYSTEM REPORT

## Поточний статус

Поточна стабільна версія: **ScriptVersion 0.5.0** (SchemaVersion 0.6.0).

## Stabilization milestone (зовнішнє ТЗ P0-P3)

За результатами зовнішнього технічного завдання на стабілізацію реалізовано **P0-A (Runtime stabilization)** та **P0-B (Lifecycle correctness)** — **P0 завершено повністю**. P0-A злито в `developer` через PR #45 ("Stabilization P0: execution contract, exit codes, CollectionErrors/ExportErrors", merge commit `7b951a075b5d3ea3ef7c1516c5fec6da98d2c935`) — деталі в `CHANGELOG.md` ("Stabilization P0"). P0-B закрито окремим PR (гілка `fix/lifecycle-data-model`).

**P0-A — Runtime stabilization → DONE**

- [x] P0.1 Уніфікувати execution contract (root wrapper мав власний, розбіжний з `dist` param-блок — переписано на transparent passthrough).
- [x] P0.2 `-Zip:$false`/`-NoZip` коректно форвардяться через обидва хопи (wrapper→dist, dist→elevation).
- [x] P0.3 Єдиний default `Profile` (`Forensic`, лише в `src/05-Params.ps1`).
- [x] P0.4 CollectionErrors/ExportErrors розділені, export-pipeline спрощено (Health Score рахується один раз).
- [x] P0.5 Детермінований exit code contract (0/1/2/3), elevation прокидає реальний exit code дочірнього процесу.

**P0-B — Lifecycle correctness → DONE**

- [x] P0.6 Актуалізація Windows Lifecycle database — усі записи звірено з офіційними lifecycle-сторінками Microsoft Learn (learn.microsoft.com/lifecycle) станом на 2026-09-01. Виявлено й виправлено помилкову дату Windows Server 2025 (Extended End Date був `2034-10-10`, коректно `2034-11-14` за офіційною raw-датою `11/15/2034 6:59:59 AM PT`); знята позначка "не звірено" з Windows 11 25H2 — офіційна дата (`2027-10-12` Home/Pro, `2028-10-10` Enterprise/Education) підтверджена. Регулярний процес актуалізації: звіряти `$script:BravoLifecycleTableUpdatedAt` під час кожного релізу нової версії Windows.
- [x] P0.7 Винесення lifecycle records у централізований dataset/data model — таблиця перенесена з inline-масиву в `src/39-Collectors-Updates.ps1` у окремий модуль `src/39a-Data-WindowsLifecycle.ps1` (додано в `src/BRAVO.build.json` перед колектором), щоб оновлення дат не вимагало правок логіки колектора `Get-BravoOsSupportInfo`.
- [ ] P1 (collector/analyzer розділення, `-SanitizeLevel`, розширення Pester/CI) — окремі майбутні PR. Централізовані storage thresholds, CPU/RAM findings, `-Offline`/`-SkipGeoIP` з цього пункту вже закрито, деталі в "v0.4.2 Runtime Quality" і "v0.4.3 Safe Sharing" нижче.
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
- [x] Додати перевірку release package (`tests/ReleasePackage.Tests.ps1`, 5 тестів, входить у звичайний `Invoke-Pester -Path tests`):
  - [x] створити ZIP (`tools/New-ReleasePackage.ps1`);
  - [x] розпакувати у temporary directory;
  - [x] запустити `BRAVO-SystemReport-Quick.bat --nopause` з розпакованого пакета;
  - [x] перевірити створення JSON/HTML (+ що JSON валідно парситься, sha512 runtime всередині пакета відповідає файлу, sha256 самого ZIP коректний, усі 5 `.bat`-лаунчерів і `MANIFEST.txt` присутні).
- [x] Визначити долю старого моноліту `src/Get-BravoSystemReport.ps1`: видалено (весь runtime формується з `src/*.ps1` модулів через `Build-BRAVO-SystemReport.ps1`).
- [x] Оновити `examples/README.md` відповідно до поточного wrapper/dist flow (`-Zip` за замовчуванням, `-NoZip` для вимкнення).
- [x] Додати `docs/RELEASE.md` з описом створення й перевірки release package (локальний флоу + як фактично працює `.github/workflows/release.yml`: resolve version, build, quick runtime test, package, verify, publish; таблиця типових причин падіння).

## v0.4.2 Runtime Quality

Ціль: прибрати логічні ризики runtime і зробити результат звіту більш передбачуваним.

- [x] Перераховувати Health Score після export-етапів (`Update-BravoHealthScore` викликається вдруге в `90-Main.ps1`, JSON і HTML перегенеровуються лише якщо з'явились нові `CollectionErrors`).
- [x] Додати режим strict validation (P1, `src/90-Main.ps1`):
  - [x] `-Strict`;
  - [x] ненульовий exit code, коли Health.Status аудитованої машини = `CRITICAL` (окремий exit code `4`, лише в `-Strict` режимі — за замовчуванням Health.Status і далі НЕ впливає на exit code, це властивість машини, не збій інструмента).
  - [ ] `CollectionErrors`/`ExportErrors` і далі дають один exit code `1` незалежно від "критичності" — окремих кодів для parser/build/runtime/export failures немає (є лише 2=fatal trap, 3=JSON не згенеровано); розділення за типом failure — окрема майбутня задача, якщо знадобиться.
- [x] Уніфікувати network schema (перевірено 2026-09-02: єдине джерело правди — вкладене `Network.IP.*`, top-level дублікатів немає):
  - [x] `Network.IP.IPv4`;
  - [x] `Network.IP.PrimaryIPv4`;
  - [x] `Network.IP.PrimaryInterface`;
  - [x] `Network.IP.PublicIPv4`;
  - [x] top-level `Network.IPv4`/`Network.PrimaryIPv4`/`Network.PublicIPv4` в поточному коді відсутні (`src/20-ReportModel.ps1`, `src/33-Collectors-Network.ps1`, `src/51-Export-Html.ps1`, `src/52-Export-Csv.ps1`, `src/45-Sanitize.ps1` — усі звертаються лише через `Network.IP.*`); минулі баги з неправильним шляхом (`CHANGELOG.md`) вже виправлені раніше.
- [x] Уніфікувати storage thresholds (P1, `src/32-Collectors-Storage.ps1`):
  - [x] один набір порогів для basic і deep storage audit (`Get-BravoStorageThresholds`: 5% critical / 10% warning / 15% системний);
  - [x] уникнути дублювання findings для одного й того самого тому (у Deep/Forensic профілях basic-прохід більше не емітить власні findings — рішення делегується `Get-BravoStorageRiskSummary`, який покриває ті самі томи глибше);
  - [x] винести thresholds у helper/config-блок (`Get-BravoStorageThresholds` + чиста функція `Get-BravoStorageFreeSpaceSeverity`, покриті `tests/StorageThresholds.Tests.ps1`).
  - [x] системно-зарезервовані томи без літери диска (WinRE Partition, EFI System Partition) виключено з Critical/Warning findings у `Get-BravoStorageRiskSummary` — такі томи фіксованого розміру майже завжди заповнені образом відновлення на 90%+, і оцінка їх тими самими порогами вільного місця, що й для томів з даними, породжувала systematic false positive WARNING на кожній Windows-машині. Новий бакет `ReservedVolumes`/`Summary.ReservedCount`, видимий окремо в HTML Dashboard ("System-reserved (без літери)"), без впливу на Health Score.
- [x] CPU/RAM findings (P1, `src/31-Collectors-Hardware.ps1`): перевантаження CPU/RAM раніше впливало лише на колір Dashboard-плитки (`Dashboard.Metrics.CPU/RAM.Status`), але не потрапляло в `Health.Findings` — тобто не впливало на Health Score і не показувалось у Findings tab. Додано `Get-BravoHardwareThresholds` (CPU: 75%/90% warning/critical, RAM: 85%/95%) як спільне джерело для Dashboard-статусу й нових `Add-AuditFinding` (Category `Hardware.CPU`/`Hardware.RAM`); CPU-finding пропускається, якщо `LoadPercent` невідомий (`$null` на щойно піднятій VM — не помилка). Побічно виправлено неузгодженість: `src/40-Health.ps1` (Disk dashboard tile) досі мав захардкожені пороги `10%`/`20%`, хоча `src/32-Collectors-Storage.ps1` вже перейшов на `Get-BravoStorageThresholds` (5%/10%/15%) — тепер обидва місця узгоджені.
- [x] HTML export (закрито в попередньому раунді код-ревю, деталі в `CHANGELOG.md` "четвертий раунд глибокого код-ревю: XSS-екранування"; чекбокс тут не був позначений):
  - [x] HTML-encode всі динамічні значення (`ConvertTo-BravoHtmlText` у `src/51-Export-Html.ps1`, включно з прогрес-барами через `Get-BravoSafePercentText`);
  - [x] HTML-encode findings/errors rows (перевірено систематично — усі `$_.*`-поля в `<td>` проходять через `ConvertTo-BravoHtmlText`);
  - [x] перевірено коректність великих таблиць (client-side пошук/фільтр по рядках, `table-scroll` з `max-height`).

## v0.4.3 Safe Sharing / Sanitize

Ціль: зробити звіти безпечними для передачі третім сторонам.

- [x] Додати параметр `-Sanitize` (P1, `src/05-Params.ps1`).
- [x] Додати параметр `-SanitizeLevel Basic|Strict` (P1, `src/05-Params.ps1`, дефолт `Basic`).
- [x] Додати параметр `-SkipPublicIP` (`src/05-Params.ps1`, гейтинг профілем Full/Deep/Forensic).
- [x] Додати параметр `-SkipGeoIP` (P1, `src/05-Params.ps1`): визначає Public IPv4, але не відправляє її на geo-lookup сервіс `ipapi.co` — окремо від `-SkipPublicIP`.
- [x] Додати параметр `-Offline` (P1, `src/05-Params.ps1`), який вимикає зовнішні HTTPS-запити — Public IPv4, GeoIP і онлайн-пошук оновлень одразу (`src/33-Collectors-Network.ps1`, `src/39-Collectors-Updates.ps1`).
- [x] Маскувати у JSON/HTML/CSV (P1, новий модуль `src/45-Sanitize.ps1`, `Invoke-BravoReportSanitization` — одна точка застосування одразу після Health Score і до будь-якого export'а, тож усі формати отримують уже замасковані дані з `$script:Report`; TXT/Markdown export ще не існує в кодовій базі — застосується автоматично, коли з'явиться):
  - [x] computer name;
  - [x] user name;
  - [x] domain/workgroup;
  - [x] DNS suffix;
  - [x] public IPv4;
  - [x] private IPv4, якщо `Strict` (IP-масив, PrimaryIPv4, PrimaryInterface, adapters, routing/gateway/DNS-сервери, listening ports);
  - [x] MAC addresses;
  - [x] serial numbers (BIOS, RAM modules, PhysicalDisks, Storage Deep Audit disks);
  - [x] local administrators;
  - [ ] service account names — **не реалізовано**: колектор служб (`src/36-Collectors-ProcessesServices.ps1`) не збирає LogOnAs/StartName, маскувати нема чого; додати разом зі збором цих даних, якщо колись знадобиться;
  - [x] sensitive install paths (`Software.Installed[].InstallLocation`).
  - Відоме обмеження: ім'я файлу звіту (`BravoSystemReport_<COMPUTERNAME>_...`) і далі містить реальне ім'я машини — маскується лише вміст файлів, не назва; поза межами явного переліку цього пункту ТЗ.
- [x] Додати CI validation для sanitize (`tests/ExecutionContract.Tests.ps1`, `Describe 'P1 — CI validation для -SanitizeLevel Strict'`, наскрізний прогін через wrapper з `-Profile Full -Sanitize -SanitizeLevel Strict -Offline`):
  - [x] запуск `-Sanitize`;
  - [x] точкові перевірки полів JSON на маскування (ComputerName/UserName/UserDomainName/Hostname/Network.IP.\*/MAC/serial numbers) — **не** "сліпий" regex-скан усього тексту на IP/MAC-патерн: версії встановленого ПЗ (`Software.Installed[].Version`) масово збігаються з форматом IPv4 і дають сотні false positive; `OutputPath` (шлях збереження звіту під профілем Windows-користувача) легітимно й свідомо не маскується, тож full-text-скан на `$env:USERNAME` теж хибно спрацьовує — перевірено вручну обидва випадки перед фіналізацією тесту;
  - [x] перевірка, що структура звіту не ламається після маскування (`ConvertFrom-Json` успішний, `CollectionErrors`/`ExportErrors` = 0, `exit code 0`).

## v0.5.0 Deep Inventory

Ціль: розширити фактичний збір даних для Deep і Forensic профілів.

### Hardware Inventory

- [x] BIOS/UEFI: version, release date, serial number.
- [x] RAM modules: slot, vendor, serial, speed, size.
- [~] CPU: cores, logical processors, max clock; socket — наступний етап.
- [x] ComputerSystem: chassis type (`Win32_SystemEnclosure.ChassisTypes[0]`, `src/31-Collectors-Hardware.ps1`, гейтовано Full/Deep/Forensic; `Get-BravoChassisTypeText` — чиста функція, мапить SMBIOS chassis type code на людяний опис; `Hardware.ComputerSystem.{ChassisType,ChassisTypeCode}`).
- [x] Secure Boot (`Confirm-SecureBootUEFI`, `src/34-Collectors-Security.ps1`, гейтовано Full/Deep/Forensic; `Security.SecureBoot.{Supported,Enabled,Status}`; Legacy BIOS/VM без UEFI — штатний стан `NotSupported`, не помилка збору).
- [x] TPM (`Win32_Tpm` CIM у `root\cimv2\Security\MicrosoftTpm`, `src/34-Collectors-Security.ps1`, гейтовано Full/Deep/Forensic; `Security.TPM.{Present,Ready,Enabled,Activated,ManufacturerId,ManufacturerVersion,SpecVersion,Status}`; відсутність TPM — штатний стан `NotPresent`, не помилка збору).
- [x] Motherboard (`Win32_BaseBoard`, `src/31-Collectors-Hardware.ps1`, гейтовано Full/Deep/Forensic; `Hardware.Motherboard.{Manufacturer,Product,SerialNumber,Version}`).
- [x] GPU (`Win32_VideoController`, `src/31-Collectors-Hardware.ps1`, гейтовано Full/Deep/Forensic; `Hardware.GPU[]` — Name/AdapterRAMBytes/DriverVersion/VideoProcessor/CurrentResolution/Status; відоме обмеження WMI: `AdapterRAM` — 32-bit DWORD, для карт з >4 GB VRAM значення переповнюється/спотворюється, публікується як є).
- [ ] Monitors.

### Storage Audit

- [x] Logical disks: drive letter, filesystem, total/free/used.
- [x] Volumes: health, operational status, size/free/risk.
- [x] Physical disks: basic model, serial, size, media type/status.
- [x] Findings для низького вільного місця.
- [x] BitLocker status (`Get-BitLockerVolume`, `src/32-Collectors-Storage.ps1`, гейтовано Deep/Forensic через `Get-BravoStorageDeepAudit`; `Hardware.Disks.Deep.BitLocker[]` — MountPoint/VolumeType/VolumeStatus/EncryptionPercentage/EncryptionMethod/ProtectionStatus/LockStatus/AutoUnlockEnabled; WARNING-finding лише для незахищеного системного тому, не для data-томів — той самий принцип, що й WinRE-фікс, аби уникнути WARNING на кожній звичайній робочій станції).
- [x] Pagefile (`Win32_PageFileUsage`, `src/32-Collectors-Storage.ps1`, вже було реалізовано в `Get-BravoStorageDeepAudit` — `Hardware.Disks.Deep.PageFiles[]`; помічено при перегляді ROADMAP і позначено заднім числом).
- [x] Shadow Copies / VSS (`Win32_ShadowCopy`, `src/32-Collectors-Storage.ps1`, гейтовано Deep/Forensic через `Get-BravoStorageDeepAudit`; `Hardware.Disks.Deep.ShadowCopies[]` — ID/VolumeName/InstallDate/ClientAccessible/Persistent; відсутність точок відновлення — штатний стан, не помилка).
- [x] Storage Spaces (`Get-StoragePool`, `src/32-Collectors-Storage.ps1`, гейтовано Deep/Forensic; `Hardware.Disks.Deep.StoragePools[]` — FriendlyName/HealthStatus/OperationalStatus/SizeGB/AllocatedGB/IsReadOnly; виключено `IsPrimordial` пул — прихований "сирий" пул фізичних дисків, не реальний Storage Spaces; WARNING якщо HealthStatus не Healthy; модуль Storage відсутній або Storage Spaces не використовується — штатний стан, порожній масив).
- [x] SMART/NVMe health, якщо доступно штатними засобами (`src/32-Collectors-Storage.ps1`, гейтовано Deep/Forensic; `Hardware.Disks.Deep.ReliabilityCounters[]` через `Get-PhysicalDisk | Get-StorageReliabilityCounter` — Temperature/Wear/ReadErrorsUncorrected/WriteErrorsUncorrected/PowerOnHours, WARNING на некоригованих помилках або Wear≥90%; `Hardware.Disks.Deep.SmartPredictFailures[]` через легасі `MSStorageDriver_FailurePredictStatus` WMI-клас у `root\wmi` — типово недоступний на NVMe/RAID-контролерах, це штатне обмеження драйвера, не помилка збору; CRITICAL-finding при PredictFailure=True).

### Network Audit

- [x] IP/DNS/Gateway/DHCP/static.
- [x] Primary IPv4 detection.
- [x] Public IPv4 detection без виводу значення у консоль.
- [x] Listening ports з OwningProcess.
- [x] Network adapters: name, MAC, speed, status, driver (name/MAC вже збирались; `Get-NetAdapter` у `src/33-Collectors-Network.ps1`, гейтовано Full/Deep/Forensic, збагачує наявні записи `Network.Adapters[]` за MAC-адресою — `LinkSpeed`/`Status`/`DriverVersion`/`DriverProvider`; НЕ додає нові рядки для адаптерів без IP, щоб не змінювати семантику "Adapters" з "інтерфейси з IP" на "усі мережеві інтерфейси в системі").
- [x] Routing table (`Get-NetRoute`, `src/33-Collectors-Network.ps1`, гейтовано Full/Deep/Forensic; `Network.Routing.RoutingTable[]`, до 200 записів).
- [x] ARP/Neighbor table (`Get-NetNeighbor`, `src/33-Collectors-Network.ps1`, гейтовано Full/Deep/Forensic; `Network.ARP[]`, виключено Unreachable/Incomplete записи, до 200; MAC маскується Sanitize завжди, IP — лише Strict).
- [ ] Listening ports з ProcessName.
- [ ] Established connections з ProcessName.
- [x] WinHTTP proxy (`netsh winhttp show proxy`, `src/33-Collectors-Network.ps1`, гейтовано Full/Deep/Forensic; `Network.WinHttpProxy.{RawOutput,Status}`; свідомо публікується сирий текст без інтерпретації — локалізований вивід netsh, той самий принцип, що й audit policy).
- [ ] SMB shares.

### Security Baseline

- [x] UAC basic enabled/disabled.
- [x] RDP basic enabled/disabled.
- [x] Antivirus через `SecurityCenter2`.
- [x] Firewall profiles.
- [x] Local admins через SID `S-1-5-32-544`.
- [ ] UAC full policy.
- [x] RDP NLA, port, firewall scope, allowed users (`src/34-Collectors-Security.ps1`, гейтовано Full/Deep/Forensic, лише коли RDP увімкнено; `Security.RemoteAccess.{NLAEnabled,Port,FirewallScope,FirewallProfiles,AllowedUsers}`; firewall-правило шукається за незалежним від локалізації ім'ям `RemoteDesktop-UserMode-In-TCP`, не за локалізованим `DisplayGroup`; WARNING якщо NLA не вимагається, WARNING якщо `RemoteAddress=Any` у Public-профілі; `AllowedUsers` маскується Sanitize так само, як `LocalAdmins`).
- [x] WinRM listeners and auth (`WSMan:\localhost\Listener` + `\Service\Auth` PSDrive, `src/34-Collectors-Security.ps1`, гейтовано Full/Deep/Forensic, лише коли служба WinRM `Running`; `Security.WinRM.{ServiceStatus,Listeners,Auth,Status}`; WARNING якщо Basic auth або CredSSP увімкнено).
- [x] SMBv1 (`Get-SmbServerConfiguration`, `src/34-Collectors-Security.ps1`, гейтовано Full/Deep/Forensic; `Security.SMBv1.{Enabled,Status}`; WARNING-finding, якщо `EnableSMB1Protocol=$true`; модуль SmbShare відсутній -> `NotAvailable`, не помилка).
- [x] SMB signing / insecure guest access (`Get-SmbServerConfiguration`/`Get-SmbClientConfiguration`, `src/34-Collectors-Security.ps1`, гейтовано Full/Deep/Forensic; `Security.SMB.{ServerSigningRequired,ServerSigningEnabled,ClientSigningRequired,InsecureGuestLogonsEnabled,Status}`; WARNING якщо server signing не обов'язковий, WARNING якщо insecure guest logons увімкнено).
- [x] TLS 1.0/1.1/1.2/1.3 registry status (SCHANNEL registry, `src/34-Collectors-Security.ps1`, гейтовано Full/Deep/Forensic; `Get-BravoTlsProtocolStatus` — чиста функція, інтерпретує `Enabled`/`DisabledByDefault` DWORD -> `Enabled`/`Disabled`/`NotConfigured`, покрито `tests/TlsProtocolStatus.Tests.ps1`; `Security.TLS.Protocols[]` — Client+Server на кожен протокол; findings лише для явних відхилень від безпечного дефолту (застарілий протокол явно увімкнено / TLS 1.2 явно вимкнено), `NotConfigured` — не помилка, найпоширеніший стан).
- [x] Defender details: realtime protection, signature age, engine/platform version (`Get-MpComputerStatus`, `src/34-Collectors-Security.ps1`, гейтовано Full/Deep/Forensic; `Security.Defender.{Available,AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,BehaviorMonitorEnabled,AntivirusSignatureVersion,AntivirusSignatureLastUpdated,AntivirusSignatureAgeDays,AMEngineVersion,AMProductVersion,Status}`; WARNING якщо RealTimeProtection вимкнено або сигнатури старіші 7 днів; Defender вимкнено/відсутній — штатний стан `Unavailable`/`NotAvailable`, не помилка).
- [x] Password policy (`net accounts`, `src/34-Collectors-Security.ps1`, гейтовано Full/Deep/Forensic; нова чиста функція `ConvertFrom-BravoNetAccountsOutput` парсить вивід за ФІКСОВАНОЮ ПОЗИЦІЄЮ рядка, не за текстом мітки — мітки локалізуються, порядок рядків net.exe — ні; покрито `tests/NetAccountsParsing.Tests.ps1`, включно з симуляцією нелатинської локалі; `Security.PasswordPolicy.{MinPasswordLength,MaxPasswordAgeDays,MinPasswordAgeDays,PasswordHistoryLength,LockoutThreshold,LockoutDurationMinutes,LockoutObservationWindowMinutes,Status}`; findings рахуються лише з числових значень — locale-безпечно).
- [x] Audit policy (`auditpol /get /category:* /r`, `src/34-Collectors-Security.ps1`, гейтовано Full/Deep/Forensic; `Security.AuditPolicy.{Subcategories,TotalCount,Status}`; свідомо без findings на основі тексту `Inclusion Setting` — ці значення локалізовані, на відміну від числових password policy полів, судити "недостатньо аудиту" за англійським текстом було б ненадійно на не-EN системах).
- [ ] Autoruns.
- [ ] Scheduled tasks.

### Updates and Event Logs

- [x] System errors/warnings за 24h і за період профілю.
- [x] Installed hotfixes (`39-Collectors-Updates.ps1`, `WindowsUpdate.InstalledHotFixes`).
- [x] Pending reboot detection (`WindowsUpdate.PendingRebootRequired`).
- [x] Windows Update errors (`WindowsUpdate.SearchError`; pending updates з Catalog-посиланням у Deep/Forensic).
- [x] Event logs: System, Application, Setup, Security summary (`ConvertTo-BravoEventLogSummary` + `Get-WinEvent -FilterHashtable`, `src/37-Collectors-Events.ps1`, гейтовано Full/Deep/Forensic; `EventLogs.LogSummaries[]` — LogName/Status/CriticalCount/ErrorCount/WarningCount/TopProviders; benign "немає записів" розпізнається за locale-незалежним `FullyQualifiedErrorId` (`NoMatchingEventsFound`), не за текстом повідомлення).
- [x] Provider summary (топ-10 провайдерів на кожен журнал, `EventLogs.LogSummaries[].TopProviders`, той самий колектор).
- [x] Critical/Error/Warning grouping (той самий колектор; CRITICAL-finding при Critical-подіях у будь-якому з 4 журналів).
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
- [x] Quick BAT test (`tests/ReleasePackage.Tests.ps1` — `BRAVO-SystemReport-Quick.bat --nopause` з розпакованого release package, наскрізно через справжній `.bat`, не лише через wrapper).
- [ ] Full runtime test.
- [ ] Forensic smoke test з `-JSONOnly`.
- [x] Release package build test (`tests/ReleasePackage.Tests.ps1`).
- [x] Release package unpack-and-run test (`tests/ReleasePackage.Tests.ps1`).
- [x] ZIP content validation (`tests/ReleasePackage.Tests.ps1`: sha256 ZIP, sha512 runtime всередині пакета, наявність усіх `.bat`/`MANIFEST.txt`).
- [ ] HTML generated / JSONOnly no HTML validation.
- [x] Sanitize validation після реалізації `-Sanitize` (`tests/ExecutionContract.Tests.ps1`, `Describe 'P1 — CI validation для -SanitizeLevel Strict'`).

## Технічний борг

- [x] Усунути плутанину між `src/Get-BravoSystemReport.ps1` і модульним runtime у `dist` — застарілий моноліт видалено, `powershell-static-check.yml` більше не посилається на нього.
- [x] Уніфікувати версії `ScriptVersion`, `SchemaVersion`, README, CHANGELOG — README/ROADMAP синхронізовані з фактичними версіями (release package все ще потребує окремої перевірки, див. v0.4.1 Release Stabilization вище).
- [ ] Додати `docs/SCHEMA.md`.
- [ ] Додати `docs/TESTING.md` (базовий Pester-набір уже є в `tests/`, документ ще не написаний).
- [x] Додати `docs/RELEASE.md` (див. v0.4.1 Release Stabilization вище).
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
