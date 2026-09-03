# BRAVO SYSTEM REPORT

BRAVO SYSTEM REPORT — PowerShell-інструмент для швидкого, повного, глибокого та forensic-аудиту Windows-машини.

Проєкт орієнтований на локальну діагностику Windows-серверів і робочих станцій з формуванням JSON/HTML/CSV/ZIP-звітів.

## Призначення

Скрипт збирає структуровану інформацію про:

- операційну систему;
- PowerShell і .NET;
- hardware: CPU, RAM, диски;
- Storage Deep Audit;
- Storage Critical Findings;
- мережу;
- локальних адміністраторів;
- безпеку: UAC, RDP, антивірус, firewall;
- процеси та служби;
- події Windows Event Log;
- встановлене ПЗ;
- аналіз ОС і стан оновлень Windows: які оновлення потрібно встановити, pending reboot, життєвий цикл версії ОС;
- health score, findings і collection errors.

## Поточний статус

Поточна стабільна версія: **ScriptVersion 0.6.1** (контракт JSON-звіту: **SchemaVersion 0.6.19**).

`ScriptVersion` версіонує реліз інструмента (`src/90-Main.ps1`), `SchemaVersion` — структуру JSON-контракту (`src/20-ReportModel.ps1`); вони змінюються незалежно.

Стабільні етапи:

- **v0.3.0** — Storage Deep Audit skeleton;
- **v0.3.1** — BAT-запускачі режимів аудиту;
- **v0.3.2** — Storage Critical Findings;
- **v0.3.3** — HTML-таблиці Storage Deep / Storage Critical Findings;
- **v0.3.4** — виправлено BAT `--nopause`;
- **v0.3.5** — актуалізація README / документації;
- **v0.4.0** — модульна архітектура BRAVO SYSTEM REPORT: collector-и, export-и, Health Score і модель звіту винесені у `src`-модулі;
- **v0.4.1** — Windows Update collector, privacy-гейтинг публічного IP (`-SkipPublicIP`), подвійний перерахунок Health Score після export-етапів, перевірка можливості оновлення .NET Framework/PowerShell, Catalog-посилання для pending updates;
- **v0.5.0** — аналіз ОС і оновлень Windows: колектор `Updates`, таблиця життєвого циклу всіх випусків Windows, вкладка Updates у HTML-звіті;
- **v0.5.1** — Stabilization P0: єдиний execution contract між root wrapper і `dist` (усунено дублювання дефолтів параметрів), розділення `CollectionErrors`/`ExportErrors`, детермінований exit code contract (0/1/2/3), спрощений export-pipeline (Health Score рахується один раз).

## Швидкий запуск

### PowerShell

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Get-BravoSystemReport.ps1 -Profile Quick -NoPause -NoOpenFolder
```

Повний запуск з CSV і ZIP:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Get-BravoSystemReport.ps1 -Profile Full -CSV -Zip -NoPause -NoOpenFolder
```

Окрема директорія для звітів:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Get-BravoSystemReport.ps1 -Profile Quick -NoPause -NoOpenFolder -OutputPath .\reports\quick-test
```

### BAT-запускачі

```cmd
BRAVO-SystemReport-Quick.bat --nopause
BRAVO-SystemReport-Full.bat --nopause
BRAVO-SystemReport-Deep.bat --nopause
BRAVO-SystemReport-Forensic.bat --nopause
```

Підтримувані варіанти аргументу:

```text
--nopause
-nopause
/nopause
```

Якщо `--nopause` не передано, BAT-запускач після завершення залишає стандартну паузу для ручного запуску подвійним кліком.

## Профілі аудиту

| Профіль | Призначення |
|---|---|
| `Quick` | швидкий аудит основних параметрів Windows-машини |
| `Full` | повний базовий аудит із розширеним збором |
| `Deep` | глибокий аудит, включно зі Storage Deep Audit |
| `Forensic` | максимально детальний режим збору для розслідування проблем |

## Аналіз ОС і оновлень Windows

Секція `Updates` у JSON і вкладка **Updates** у HTML-звіті відповідають на питання «що потрібно встановити».

Що збирається:

- **Життєвий цикл ОС** — продукт, `DisplayVersion` (наприклад `24H2`), full build з `UBR`, канал,
  дата завершення підтримки, кількість днів до неї та статус
  `Supported` / `EndingSoon` / `EndOfSupport` / `Unknown`. Дані беруться зі статичної таблиці життєвого циклу
  всередині скрипта; дата її актуальності виводиться у полі `LifecycleDataUpdatedAt`.

  Канал визначається за `Caption` ОС і має три значення з окремими датами:

  | Канал | Редакції |
  |---|---|
  | `Consumer` | Home, Pro, Core |
  | `Enterprise / Education` | Enterprise, Education, серверні редакції |
  | `LTSC / LTSB` | Enterprise LTSC та LTSB |

  LTSC/LTSB визначається за `EditionID` з реєстру (`EnterpriseS`, `EnterpriseSN`, `IoTEnterpriseS`),
  бо `Caption` в Enterprise SAC і Enterprise LTSC однаковий; за відсутності `EditionID` використовується `Caption`.

  Таблиця покриває всі випуски Windows від Windows 2000 до Windows 11 25H2 і від Windows 2000 Server
  до Windows Server 2025, включно з усіма піврічними релізами Windows 10, LTSB/LTSC-редакціями і
  Windows Server SAC. Клієнтські та серверні ОС з однаковим build (3790, 6002, 7601, 9200, 9600,
  14393, 17763, 26100) розрізняються автоматично.

  Свідомі виключення: IoT LTSC-редакції не виділені окремо; дати ESU не використовуються — показується
  дата завершення звичайної підтримки (наприклад, Windows 7 SP1 — `2020-01-14`, а не `2023-01-10`);
  Windows Server SAC 1809 пропущено через збіг build 17763 із Windows Server 2019.
- **Доступні оновлення** — пошук через COM `Microsoft.Update.Session`
  (`IsInstalled=0 and IsHidden=0`): назва, KB, категорії, `MsrcSeverity`, розмір, чи вже завантажено, дата випуску.
  Зведення: `Total`, `Security`, `Critical`, `Driver`, `Definition`, `Other`, `Downloaded`, `TotalSizeMB`, `MaxAgeDays`.
  Класифікація виконується за стабільними `CategoryID`, тому не залежить від мови інтерфейсу Windows.
  Детально зберігається до 200 оновлень: якщо знайдено більше, `Pending.Total` показує реальну кількість,
  `Pending.Detailed` — скільки збережено, а `Pending.IsTruncated` стає `true` і додається окрема знахідка.
- **Стан Windows Update** — служба `wuauserv` і тип її запуску, політика `AUOptions`, WSUS-сервер,
  час останнього успішного пошуку та встановлення оновлень.
- **Pending reboot** — перевірка CBS, `WindowsUpdate\Auto Update\RebootRequired`,
  `PendingFileRenameOperations` і запланованого перейменування машини, зі списком причин.
- **Встановлені оновлення** — `Get-HotFix` (fallback `Win32_QuickFixEngineering`): загальна кількість,
  дата останнього оновлення, кількість за 30 днів і список останніх записів.

Знахідки, які потрапляють у Health Score:

| Severity | Умова |
|---|---|
| `CRITICAL` | ОС поза підтримкою; є невстановлені security / critical оновлення |
| `WARNING` | підтримка ОС завершується (<= 180 днів); є інші невстановлені оновлення; потрібне перезавантаження; `wuauserv` вимкнено; автооновлення вимкнено політикою; останній пошук > 30 днів тому; останнє оновлення встановлено > 60 днів тому |

Параметри:

| Параметр | Опис |
|---|---|
| `-SkipUpdateSearch` | не виконувати онлайн-пошук оновлень (локальні дані збираються завжди) |
| `-UpdateSearchTimeoutSec` | ліміт часу онлайн-пошуку, за замовчуванням `180` сек |
| `-SkipGeoIP` | визначити Public IPv4, але не відправляти її на geo-lookup сервіс (`ipapi.co`) — без ISP/ASN/локації |
| `-Offline` | вимикає всі зовнішні HTTPS-запити скрипта одразу (Public IPv4, GeoIP, онлайн-пошук оновлень) |

Особливості:

- профіль `Quick` онлайн-пошук не виконує (`Search.Status = Skipped`);
- пошук виконується у фоновому job із таймаутом, тому зависання агента Windows Update не блокує звіт;
- для повного результату потрібні мережа (або доступний WSUS) і права адміністратора; без них секція
  заповнюється локальними даними, а `Search.Status` отримує значення `Failed` або `Timeout`.

## Генеровані файли

За замовчуванням звіти зберігаються у директорію:

```text
.\reports
```

Типові файли:

```text
BravoSystemReport_<COMPUTERNAME>_<yyyyMMdd_HHmmss>.json
BravoSystemReport_<COMPUTERNAME>_<yyyyMMdd_HHmmss>.html
BravoSystemReport_<COMPUTERNAME>_<yyyyMMdd_HHmmss>.csv
BravoSystemReport_<COMPUTERNAME>_<yyyyMMdd_HHmmss>.zip
```

CSV створюється при використанні `-CSV`. ZIP створюється за замовчуванням (`-Zip` увімкнено за замовчуванням) — вимкнути можна через `-NoZip` (рекомендовано) або `-Zip:$false` (обидва способи коректно форвардяться навіть при автоматичному підвищенні прав до адміністратора).

## Storage Deep Audit

Storage Deep Audit активний для профілів `Deep` і `Forensic`.

JSON-секція:

```text
Hardware.Disks.Deep
```

Містить базові дані:

- `LogicalDisks`;
- `Volumes`;
- `Disks`.

HTML-звіт містить секцію **Storage Deep** з таблицею томів:

- том;
- мітка;
- файлова система;
- тип;
- health status;
- operational status;
- size GB;
- free GB;
- free percent;
- risk;
- причина.

## Storage Critical Findings

Storage Critical Findings формує підсумок ризиків для томів.

JSON-секція:

```text
Hardware.Disks.StorageRisk
```

Пороги:

| Рівень | Умова |
|---|---|
| `CRITICAL` | том має менше 5% вільного місця |
| `WARNING` | том має менше 10% вільного місця |
| `WARNING` | системний том має менше 15% вільного місця |

HTML-звіт містить секцію **Storage Critical Findings** з підсумком:

- critical volumes;
- warning volumes;
- system warnings;
- healthy volumes.

Для візуального відображення ризиків використовуються CSS-класи:

```text
risk-critical
risk-warning
risk-ok
risk-unknown
```

## Exit code contract

Скрипт завершується з детермінованим exit code, придатним для перевірки в CI/автоматизації:

| Code | Значення |
|------|----------|
| `0` | Аудит успішно завершено, без помилок збору чи експорту (і, у `-Strict` режимі, без CRITICAL `Health.Status`) |
| `1` | Аудит завершено, але були помилки збору (`CollectionErrors`) і/або запису звітів (`ExportErrors`) |
| `2` | Фатальна неопрацьована помилка виконання (баг/runtime-збій) |
| `3` | Обов'язковий вихідний файл (JSON) не згенеровано |
| `4` | Лише з `-Strict`: аудит завершено без `CollectionErrors`/`ExportErrors`, але `Health.Status` аудитованої машини = `CRITICAL` |

За замовчуванням `Health.Status` (`OK`/`WARNING`/`CRITICAL`) **не впливає** на exit code — це властивість аудитованої машини (наскільки вона здорова), а не ознака збою самого інструмента BRAVO SYSTEM REPORT. Параметр `-Strict` вмикає цю поведінку явно (exit code `4`) — для CI-гейтів, яким потрібен ненульовий exit code саме на "машина в критичному стані", а не лише на "інструмент не зміг щось зібрати/записати". `CollectionErrors` (помилки WMI/CIM/реєстру) і `ExportErrors` (помилки запису JSON/HTML/CSV/ZIP/email) розділені в JSON-звіті — перші впливають на `Health.Score`, другі — ні, обидва впливають на exit code незалежно від `-Strict`.

При автоматичному підвищенні прав (UAC) батьківський процес чекає завершення елевованого дочірнього процесу й повертає його реальний exit code.

## BAT-запускачі

Доступні BAT-файли:

- `BRAVO-SystemReport-Quick.bat` — швидкий аудит;
- `BRAVO-SystemReport-Full.bat` — повний базовий аудит;
- `BRAVO-SystemReport-Deep.bat` — глибокий аудит;
- `BRAVO-SystemReport-Forensic.bat` — максимально детальний аудит;
- `BRAVO-SystemReport-Launcher.bat` — інтерактивне меню вибору режиму.

BAT-запускачі `Quick`, `Full`, `Deep`, `Forensic`:

- передають `-NoPause` у PowerShell-скрипт;
- підтримують `--nopause`, `-nopause`, `/nopause` на рівні BAT;
- повертають exit code основного PowerShell-скрипта;
- не показують `Press any key to continue`, якщо передано `--nopause`.

## GitHub Actions / Local Windows Validation

У репозиторії налаштовано workflow:

```text
.github/workflows/local-windows-validation.yml
```

Workflow запускається на локальному Windows self-hosted runner:

```text
BRAVO-SYSTEM-REPORT-WIN
```

Перевірки:

- `git diff --check`;
- build modular monolith;
- PowerShell parser check для `dist`;
- Quick runtime test;
- JSON validation;
- перевірка `Profile=Quick`;
- перевірка `CollectionErrors=0`;
- перевірка, що у tracked files немає випадково закомічених публічних IPv4 literals.

Окремо є ручний workflow:

```text
.github/workflows/powershell-static-check.yml
```

Він виконує базову перевірку структури репозиторію.

## Реліз

Реліз публікується автоматично workflow-ом `.github/workflows/release.yml` при push-і тега `v*`:

```powershell
git checkout main
git pull
git tag v0.5.0
git push origin v0.5.0
```

Що робить workflow:

1. звіряє версію в `src\90-Main.ps1`, `CHANGELOG.md` і в самому тезі — розбіжність зупиняє реліз;
2. збирає `dist` через `Build-BRAVO-SystemReport.ps1` і робить контрольний прогін профілю `Quick`;
3. пакує реліз через `tools\New-ReleasePackage.ps1`;
4. розпаковує готовий ZIP і перевіряє його: наявність runtime і `MANIFEST.txt`, збіг SHA512, parser check
   і версію запакованого скрипта;
5. створює GitHub Release із нотатками із секції відповідної версії `CHANGELOG.md` і вкладає
   `BRAVO_SYSTEM_REPORT_v<version>.zip` та `.zip.sha256`.

Ручний запуск (`workflow_dispatch`) виконує все те саме, але **без публікації релізу** — пакет
доступний як workflow artifact. Це зручно для перевірки пакування перед тегом.

Локально пакет збирається тим самим скриптом:

```powershell
.\Build-BRAVO-SystemReport.ps1 -CreateSha512
.\tools\New-ReleasePackage.ps1
```

## Вимоги

- Windows PowerShell 5.1;
- запуск від адміністратора для повного збору даних;
- Windows 10 / Windows 11 / Windows Server;
- локальний доступ до WMI/CIM;
- для частини security/network/storage-даних потрібні підвищені права.

## Структура проєкту

```text
BRAVO_SYSTEM_REPORT
├── .github/workflows/
│   ├── local-windows-validation.yml
│   ├── powershell-static-check.yml
│   └── release.yml
├── dist/
│   ├── Get-BravoSystemReport.ps1
│   └── Get-BravoSystemReport.ps1.sha512
├── docs/
│   ├── AI_RULES.md
│   ├── ARCHITECTURE.md
│   ├── IMPLEMENTATION_PLAN.md
│   ├── PROJECT_RULES.md
│   ├── ROADMAP.md
│   └── SECURITY.md
├── examples/
├── patch/
├── review/
├── tests/
│   ├── Core.Tests.ps1
│   ├── Manifest.Tests.ps1
│   └── EndToEnd.Tests.ps1
├── src/
│   ├── 00-Header.ps1
│   ├── 05-Params.ps1
│   ├── 10-Core.ps1
│   ├── 20-ReportModel.ps1
│   ├── 30-Collectors-OS.ps1
│   ├── 31-Collectors-Hardware.ps1
│   ├── 32-Collectors-Storage.ps1
│   ├── 33-Collectors-Network.ps1
│   ├── 34-Collectors-Security.ps1
│   ├── 35-Collectors-Users.ps1
│   ├── 36-Collectors-ProcessesServices.ps1
│   ├── 37-Collectors-Events.ps1
│   ├── 38-Collectors-Software.ps1
│   ├── 39-Collectors-Updates.ps1
│   ├── 39b-Collectors-Runtime.ps1
│   ├── 40-Health.ps1
│   ├── 50-Export-Json.ps1
│   ├── 51-Export-Html.ps1
│   ├── 52-Export-Csv.ps1
│   ├── 53-Export-Zip.ps1
│   ├── 54-Export-Email.ps1
│   ├── 90-Main.ps1
│   └── BRAVO.build.json
├── tools/
│   ├── New-ReleasePackage.ps1
│   └── Publish-ToGitHub.ps1
├── Build-BRAVO-SystemReport.ps1
├── BRAVO-SystemReport-Quick.bat
├── BRAVO-SystemReport-Full.bat
├── BRAVO-SystemReport-Deep.bat
├── BRAVO-SystemReport-Forensic.bat
├── BRAVO-SystemReport-Launcher.bat
├── Get-BravoSystemReport.ps1
├── README.md
├── CHANGELOG.md
└── LICENSE.md
```

## Документація

Основні документи:

- `docs/ARCHITECTURE.md` — цільова архітектура та модель модулів;
- `docs/ROADMAP.md` — актуальний backlog і етапи розвитку;
- `docs/IMPLEMENTATION_PLAN.md` — практичний план впровадження наступних доробок;
- `docs/SECURITY.md` — правила безпечної роботи зі звітами;
- `docs/PROJECT_RULES.md` — правила мови, стилю, git workflow і console contract;
- `docs/AI_RULES.md` — правила роботи з AI-асистентами в цьому проєкті.

## Відомі технічні борги

Після аналізу репозиторію зафіксовано такі ключові напрями доробки:

- release package має включати `dist\Get-BravoSystemReport.ps1` і SHA512, бо root wrapper запускає саме `dist`;
- потрібно реалізувати `-Sanitize` для безпечної передачі звітів третім сторонам;
- потрібно уніфікувати network schema для `IPv4`, `PrimaryIPv4` і `PrimaryInterface`;
- потрібно розширити Deep/Forensic профілі: TPM, Secure Boot, BitLocker, RDP/NLA, WinRM, SMBv1, TLS baseline, EventLog provider summary;
- потрібно додати Markdown/TXT summary і розширити CI-перевірки.

Детальний план впровадження описано у файлі:

```text
docs/IMPLEMENTATION_PLAN.md
```

## Безпека

Скрипт не змінює системні налаштування Windows. Він виконує аудит і формує локальні звіти.

Звіти можуть містити службову інформацію про машину, мережу, локальних користувачів, служби, диски та події. Перед передачею звітів третім особам, якщо не використовується `-Sanitize`, потрібно перевіряти вміст JSON/HTML/CSV.

### Sanitize (безпечна передача звітів)

Параметр `-Sanitize` маскує чутливі дані у JSON/HTML/CSV одним проходом одразу після розрахунку Health Score (маскування не впливає на Score/Status) і до будь-якого export'а — усі формати отримують уже замасковані дані.

| Параметр | Опис |
|---|---|
| `-Sanitize` | вмикає маскування чутливих даних |
| `-SanitizeLevel Basic\|Strict` | обсяг маскування, за замовчуванням `Basic` |

`-SanitizeLevel Basic` маскує: computer name, user name, domain/workgroup, DNS suffix, public IPv4, MAC-адреси, серійні номери (BIOS/RAM/PhysicalDisks/Storage Deep Audit), локальних адміністраторів, install path встановленого ПЗ.

`-SanitizeLevel Strict` додає до Basic: приватні IPv4 — масив адаптерів, `PrimaryIPv4`, `PrimaryInterface`, gateway, DNS-сервери, listening ports.

Кожне унікальне значення в межах одного звіту маскується в один і той самий токен виду `REDACTED-<КАТЕГОРІЯ>-<N>` (наприклад, `REDACTED-COMPUTERNAME-1`) — читабельність структури зберігається, реальні дані не розкриваються.

Відомі межі: "service account names" з чекліста поки не маскуються — колектор служб не збирає LogOnAs/StartName, немає що маскувати. Ім'я файлу звіту (`BravoSystemReport_<COMPUTERNAME>_...`) і далі містить реальну назву машини — маскується лише вміст файлів, не назва.

## Правила проєкту

- Усі commit messages українською мовою.
- Документація українською мовою.
- Консольні повідомлення без emoji.
- HTML-звіт може використовувати emoji як візуальні маркери.
- Після кожного етапу виконуються parser/runtime checks.
- Зміни проходять через patch-гілки та PR.

## Обов'язковий формат локальних команд

```powershell
Clear-Host
Set-Location "E:\GitHub\BRAVO_SYSTEM_REPORT"
$ErrorActionPreference = "Stop"
```

## Плани розвитку

Найближчі етапи:

- стабілізувати release package;
- CI validation для sanitize (regex-скан JSON/HTML на IP/MAC/serial/user/domain literals після `-Sanitize`);
- розширити hardware/storage/network/security/event log аудит;
- додати Markdown/TXT summary (маскування `-Sanitize` застосується автоматично, коли з'явиться);
- розширити Local Windows Validation для Full/Forensic, BAT і release package тестів (Quick і Deep вже покриті).

Актуальний деталізований план ведеться у:

```text
docs/ROADMAP.md
docs/IMPLEMENTATION_PLAN.md
```
