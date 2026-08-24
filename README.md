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

Поточна стабільна версія: **v0.5.0**.

Стабільні етапи:

- **v0.3.0** — Storage Deep Audit skeleton;
- **v0.3.1** — BAT-запускачі режимів аудиту;
- **v0.3.2** — Storage Critical Findings;
- **v0.3.3** — HTML-таблиці Storage Deep / Storage Critical Findings;
- **v0.3.4** — виправлено BAT `--nopause`;
- **v0.3.5** — актуалізація README / документації;
- **v0.4.0** — модульна архітектура BRAVO SYSTEM REPORT: collector-и, export-и, Health Score і модель звіту винесені у `src`-модулі.
- **v0.5.0** — аналіз ОС і оновлень Windows: колектор `Updates`, таблиця життєвого циклу всіх випусків Windows, вкладка Updates у HTML-звіті.

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

CSV і ZIP створюються при використанні відповідних параметрів `-CSV` і `-Zip`.

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
│   ├── ARCHITECTURE.md
│   ├── IMPLEMENTATION_PLAN.md
│   ├── PROJECT_RULES.md
│   ├── ROADMAP.md
│   └── SECURITY.md
├── examples/
├── patch/
├── review/
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
- `docs/PROJECT_RULES.md` — правила мови, стилю, git workflow і console contract.

## Відомі технічні борги

Після аналізу репозиторію зафіксовано такі ключові напрями доробки:

- старий моноліт `src\Get-BravoSystemReport.ps1` лишається в репозиторії як legacy: з release flow його прибрано, але файл ще потребує перенесення або видалення;
- Health Score потрібно перераховувати після export-етапів або окремо враховувати export health;
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

Звіти можуть містити службову інформацію про машину, мережу, локальних користувачів, служби, диски та події. Перед передачею звітів третім особам потрібно перевіряти вміст JSON/HTML/CSV.

Для майбутньої безпечної передачі звітів заплановано параметр `-Sanitize`.

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

- прибрати legacy-конфлікт `src\Get-BravoSystemReport.ps1`;
- додати `-Sanitize`, `-SkipPublicIP` і `-Offline`;
- розширити hardware/storage/network/security/event log аудит;
- додати Markdown/TXT summary;
- розширити Local Windows Validation для Full/Deep/Forensic, BAT і release package тестів.

Актуальний деталізований план ведеться у:

```text
docs/ROADMAP.md
docs/IMPLEMENTATION_PLAN.md
```
