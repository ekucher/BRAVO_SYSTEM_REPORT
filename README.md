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

Поточна стабільна версія: **v0.3.4**.

Стабільні етапи:

- **v0.3.0** — Storage Deep Audit skeleton;
- **v0.3.1** — BAT-запускачі режимів аудиту;
- **v0.3.2** — Storage Critical Findings;
- **v0.3.3** — HTML-таблиці Storage Deep / Storage Critical Findings;
- **v0.3.4** — виправлено BAT `--nopause`;
- **v0.3.5** — актуалізація README / документації.

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
- PowerShell parser check;
- Quick runtime test;
- Quick BAT test;
- JSON validation;
- перевірка `Profile=Quick`;
- перевірка `CollectionErrors=0`.

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
│   └── local-windows-validation.yml
├── examples/
├── patch/
├── review/
├── src/
│   └── Get-BravoSystemReport.ps1
├── tools/
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

## Безпека

Скрипт не змінює системні налаштування Windows. Він виконує аудит і формує локальні звіти.

Звіти можуть містити службову інформацію про машину, мережу, локальних користувачів, служби, диски та події. Перед передачею звітів третім особам потрібно перевіряти вміст JSON/HTML/CSV.

## Правила проєкту

- Усі commit messages українською мовою.
- Документація українською мовою.
- Консольні повідомлення без emoji.
- HTML-звіт може використовувати emoji як візуальні маркери.
- Після кожного етапу виконуються parser/runtime checks.
- Зміни проходять через PR і Local Windows Validation.

## Обов'язковий формат локальних команд

```powershell
Clear-Host
Set-Location "E:\GitHub\BRAVO_SYSTEM_REPORT"
$ErrorActionPreference = "Stop"
```

## Плани розвитку

Можливі наступні етапи:

- покращення README examples;
- додавання HTML-фільтрів або компактних секцій;
- розширення Storage Deep Audit;
- network/security deep audit;
- release artifacts;
- автоматизована публікація release notes.