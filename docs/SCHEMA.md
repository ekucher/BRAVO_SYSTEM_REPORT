# SCHEMA — структура звіту BRAVO SYSTEM REPORT

Цей документ описує структуру `$script:Report` — об'єкта, що заповнюється колекторами й записується у JSON-звіт (`Export-BravoJsonReport`, `src/50-Export-Json.ps1`). HTML/CSV/TXT/Markdown-звіти — похідні представлення того самого об'єкта.

Модель визначається в **`src/20-ReportModel.ps1`** (`New-BravoReportModel`) — єдине джерело правди для форми звіту. Кожен колектор (`src/3X-Collectors-*.ps1`) заповнює свою частину вже існуючої моделі; жоден колектор не створює нових верхньорівневих полів на льоту.

## SchemaVersion

Поточне значення визначене в `src/20-ReportModel.ps1`:

```powershell
SchemaVersion = '0.6.19'
```

**Правило**: будь-яка зміна форми моделі — новий верхньорівневий розділ, нове поле в наявному розділі, зміна типу поля — вимагає підняти `SchemaVersion` **в тому самому коміті**, що й сама зміна. Те саме стосується заповнення раніше завжди-порожнього поля новою об'єктною формою (напр. заглушка `@()`, яку колектор починає реально наповнювати, — це теж контрактна зміна для споживачів JSON). CI-крок "Contract change guard" (`local-windows-validation.yml`) перевіряє це автоматично для diff у `src/20-ReportModel.ps1`, але правило ширше — застосовується й тоді, коли модель не змінюється текстово, а змінюється семантика вже наявного поля.

Версіювання — семантичне за замовчуванням PATCH-інкремент (`0.6.18` → `0.6.19`) для кожної контрактної зміни; MINOR/MAJOR — на розсуд, якщо зміна ламає зворотну сумісність споживачів (напр. перейменування поля, зміна типу з рядка на об'єкт).

## Верхньорівневі поля

| Поле | Тип | Опис |
|---|---|---|
| `SchemaVersion` | string | версія контракту моделі (див. вище) |
| `ScriptVersion` | string | версія самого інструмента (`src/90-Main.ps1`, `$ScriptVersion`) |
| `Profile` | string | профіль збору: `Quick`/`Full`/`Deep`/`Forensic` |
| `Timestamp` | string | час початку формування моделі |
| `ComputerName` | string | ім'я аудитованої машини (маскується `-Sanitize`) |
| `Elevated` | bool | чи запущено з правами адміністратора |
| `Status` | string | підсумковий статус: `OK`/`WARNING`/`CRITICAL` (з `Health.Status`, після `Update-BravoHealthScore`) |
| `StatusReason` | string | короткий текст-обґрунтування статусу (`critical=N; warning=N; collectionErrors=N`) |
| `OutputPath` | string | директорія збереження звітів |
| `GeneratedFiles` | array\<string\> | шляхи всіх фактично створених файлів (JSON/HTML/CSV/ZIP/PDF) — джерело для ZIP-пакування |
| `CollectionErrors` | array | помилки **збору** даних (WMI/CIM/реєстр недоступні) — властивість аудитованої машини, впливає на Health Score |
| `ExportErrors` | array | помилки **запису** звітів (JSON/HTML/CSV/ZIP/Email/PDF) — проблема інструмента, НЕ впливає на Health Score, впливає на exit code |

## Розділи моделі

### `Meta`
Метадані самого прогону: `StartedAt`, `PowerShellHost`, `UserName`/`UserDomainName` (маскуються `-Sanitize`), `UseCim` (CIM чи WMI fallback), `EventLogDays`.

### `Dashboard`
Дані для верхньої панелі HTML-звіту: `Header` (ComputerName/GeneratedAt/UptimeText/Status), `Metrics` (CPU/RAM/Disk/OS/Updates — картки з Value/Status/Details), `Tabs` (які вкладки увімкнені). Заповнюється частково кожним колектором під час збору, фіналізується в `Update-BravoHealthScore` (`src/40-Health.ps1`).

### `Health`
`Score` (0-100), `Status` (`OK`/`WARNING`/`CRITICAL`), `Findings[]` — масив знахідок (`Severity`/`Category`/`Message`/`Recommendation`), наповнюється через `Add-AuditFinding` (`src/10-Core.ps1`) з усіх колекторів. Групування/сортування — `Get-BravoFindingsGrouped` (`src/40-Health.ps1`).

### `OS`
Базова інформація про ОС: `Caption`, `Version`, `Build`, `Architecture`, `InstallDate`, `LastBootUpTime`, `UptimeDays`/`UptimeHours`. Колектор: `src/30-Collectors-OS.ps1`.

### `PowerShell` / `DotNet`
Версії середовищ виконання: PowerShell (поточна + PowerShell 7 Core detection), .NET Framework (`v4`, `ReleaseKey`, оновлення доступне). Колектор: `src/30-Collectors-OS.ps1`.

### `WindowsUpdate`
Легасі-поле (частково витіснене `Updates`, див. нижче) — сервіс Windows Update, встановлені hotfix, pending reboot. Історично перше поле, `Updates` — новіша й повніша модель того самого домену.

### `BIOS` / `Virtualization`
`BIOS.{Version,SerialNumber,ReleaseDate}` (SerialNumber маскується `-Sanitize`). `Virtualization.{IsVirtual,Hypervisor}`. Колектор: `src/31-Collectors-Hardware.ps1`.

### `Hardware`
Найбільший розділ. `ComputerSystem` (Manufacturer/Model/Domain/ChassisType), `CPU`, `RAM` (+`Modules[]`), `Disks` (`FreePercent`/`TotalGB`/`FreeGB`/`Volumes[]`/`PhysicalDisks[]`/**`Deep`** — глибокий Storage Audit: `BitLocker[]`/`ShadowCopies[]`/`StoragePools[]`/`PageFiles[]`/`ReliabilityCounters[]`/`SmartPredictFailures[]`, гейтовано Deep/Forensic), `Motherboard`, `GPU[]`, `Monitors[]`. Колектори: `src/31-Collectors-Hardware.ps1` (базове), `src/32-Collectors-Storage.ps1` (`Disks.Deep`/`Disks.StorageRisk`).

### `Network`
`General` (Hostname/Domain), `IP` (IPv4/PrimaryIPv4/PublicIPv4 + geo/ISP-дані), `Routing` (DefaultGateway(s)/DNSServers/RoutingTable), `Adapters[]`, `Connections` (Established/Listening/`ListeningPorts[]`/`EstablishedConnections[]` — з ProcessName), `ARP[]`, `WinHttpProxy`, `SmbShares[]`. Колектор: `src/33-Collectors-Network.ps1`.

### `Security`
Другий за розміром розділ. `UAC` (+ full policy: ConsentPromptBehavior Admin/User), `RemoteAccess` (RDP + NLA/port/firewall scope/allowed users), `Antivirus`, `Firewall`, `SecureBoot`, `TPM`, `SMBv1`, `TLS.Protocols[]` (SCHANNEL registry), `Defender`, `WinRM`, `SMB` (signing), `PasswordPolicy`, `AuditPolicy`, `Autoruns[]` (Run/RunOnce + startup folders), `ScheduledTasks[]` (з прапорцем `IsMicrosoftDefault`). Колектор: `src/34-Collectors-Security.ps1`.

### `Users` / `Processes` / `Services`
`Users.LocalAdmins[]` (маскується `-Sanitize`), `Processes.{Total,TopMemory[]}`, `Services.{Total,Running,AutomaticStopped[]}`. Колектори: `src/35-Collectors-Users.ps1`, `src/36-Collectors-ProcessesServices.ps1`.

### `EventLogs`
`SystemErrors`/`SystemWarnings` (24h + за період профілю), `TopErrorSources[]`, `LogSummaries[]` (per-log System/Application/Setup/Security: Critical/Error/Warning + Provider summary), `HardwareDiagnostics[]` (Disk/Ntfs/StorPort/StorNVMe/WHEA/Kernel-Power/BugCheck). Колектор: `src/37-Collectors-Events.ps1`.

### `Software`
`Installed[]` (повний список, без штучного обрізання), `WindowsFeatures[]` (заплановано, ще не реалізовано — завжди `@()`). Колектор: `src/38-Collectors-Software.ps1`.

### `Updates`
Новіша модель домену Windows Update (доповнює legacy `WindowsUpdate` вище): `OS` (SupportEndDate/DaysToEndOfSupport/SupportStatus з Windows Lifecycle database, `src/39a-Data-WindowsLifecycle.ps1`), `WindowsUpdate` (service/WSUS), `PendingReboot`, `Search` (онлайн-пошук pending updates), `Pending`/`Installed` (деталізовані лічильники + `Items[]`/`Recent[]`). Колектор: `src/39-Collectors-Updates.ps1`.

### `USBDevices`
Заплановано, ще не реалізовано — завжди `@()`.

## Навігація по колекторах

| Файл | Розділи моделі |
|---|---|
| `src/30-Collectors-OS.ps1` | `OS`, `PowerShell`, `DotNet` |
| `src/31-Collectors-Hardware.ps1` | `Hardware` (базове), `BIOS`, `Virtualization` |
| `src/32-Collectors-Storage.ps1` | `Hardware.Disks` (+`.Deep`, `.StorageRisk`) |
| `src/33-Collectors-Network.ps1` | `Network` |
| `src/34-Collectors-Security.ps1` | `Security` |
| `src/35-Collectors-Users.ps1` | `Users` |
| `src/36-Collectors-ProcessesServices.ps1` | `Processes`, `Services` |
| `src/37-Collectors-Events.ps1` | `EventLogs` |
| `src/38-Collectors-Software.ps1` | `Software` |
| `src/39-Collectors-Updates.ps1` | `Updates`, `WindowsUpdate` |
| `src/39a-Data-WindowsLifecycle.ps1` | статичні дані Windows lifecycle (використовуються `Updates.OS`) |
| `src/40-Health.ps1` | `Health`, фіналізація `Status`/`Dashboard` |
| `src/45-Sanitize.ps1` | маскування чутливих полів перед експортом (не змінює форму моделі, лише значення) |

## Пов'язана документація

- `docs/ARCHITECTURE.md` — загальна архітектура модулів і build-процес.
- `docs/AI_RULES.md` — правила для агентів, що працюють з кодом (включно з правилом SchemaVersion).
- `CHANGELOG.md` — історія контрактних змін по PR.
