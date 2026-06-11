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
- health score, findings і collection errors.

## Поточний статус

Поточна стабільна версія: **v0.4.0**.

Стабільні етапи:

- **v0.3.0** — Storage Deep Audit skeleton;
- **v0.3.1** — BAT-запускачі режимів аудиту;
- **v0.3.2** — Storage Critical Findings;
- **v0.3.3** — HTML-таблиці Storage Deep / Storage Critical Findings;
- **v0.3.4** — виправлено BAT `--nopause`;
- **v0.3.5** — актуалізація README / документації;
- **v0.4.0** — модульна архітектура BRAVO SYSTEM REPORT: collector-и, export-и, Health Score і модель звіту винесені у `src`-модулі.

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
│   └── powershell-static-check.yml
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
│   ├── 40-Health.ps1
│   ├── 50-Export-Json.ps1
│   ├── 51-Export-Html.ps1
│   ├── 52-Export-Csv.ps1
│   ├── 53-Export-Zip.ps1
│   ├── 54-Export-Email.ps1
│   ├── 90-Main.ps1
│   └── BRAVO.build.json
├── tools/
│   └── New-ReleasePackage.ps1
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

- release package має включати `dist\Get-BravoSystemReport.ps1` і SHA512, бо root wrapper запускає саме `dist`;
- старий моноліт `src\Get-BravoSystemReport.ps1` потрібно прибрати з основного release flow або перенести в legacy;
- Health Score потрібно перераховувати після export-етапів або окремо враховувати export health;
- потрібно реалізувати `-Sanitize` для безпечної передачі звітів третім сторонам;
- потрібно уніфікувати network schema для `IPv4`, `PrimaryIPv4` і `PrimaryInterface`;
- потрібно розширити Deep/Forensic профілі: TPM, Secure Boot, BitLocker, Pending Reboot, RDP/NLA, WinRM, SMBv1, TLS baseline, EventLog provider summary;
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

- стабілізувати release package;
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
