# BRAVO SYSTEM REPORT

**BRAVO SYSTEM REPORT** — PowerShell-проект для збору детального технічного звіту про Windows-машину або сервер.

Початковою основою проекту є скрипт `Get-SystemAudit.ps1`, перенесений у `src/Get-BravoSystemReport.ps1`. Далі проект буде розширюватися до повноцінного адміністративного діагностичного пакета з профілями аудиту, HTML/JSON/CSV/Markdown-звітами, health score, security findings та рекомендаціями.

## Призначення

Проект має збирати структурований звіт про:

- операційну систему, версію, build, uptime, PowerShell, .NET;
- апаратне забезпечення: CPU, RAM, BIOS/UEFI, TPM, Secure Boot, GPU;
- диски, томи, SMART/health, BitLocker, pagefile, VSS;
- мережеві адаптери, IP, DNS, шлюзи, маршрути, listening ports;
- локальних користувачів, адміністраторів, UAC, RDP, WinRM, SMB, TLS;
- процеси, служби, автозапуск, scheduled tasks;
- оновлення Windows, pending reboot, помилки Windows Update;
- журнали подій System/Application/Security/Setup та профільні журнали Windows;
- встановлене програмне забезпечення;
- підсумкові Critical/Warning/Info findings.

## Швидкий запуск

Запуск із кореня репозиторію:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Get-BravoSystemReport.ps1 -Profile Full -Zip -CSV
```

Або напряму:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\Get-BravoSystemReport.ps1 -Profile Full -Zip -CSV
```

Для запуску без паузи в кінці:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Get-BravoSystemReport.ps1 -Profile Full -Zip -CSV -NoPause
```

## Поточний статус

Поточна версія — **0.2.0 Stabilization**. Базовий скрипт уже підготовлено до подальшого розширення:

- додано профілі `Quick`, `Full`, `Deep`, `Forensic`;
- додано `-OutputPath`, `-NoOpenFolder`, `-EventLogDays`;
- виправлено конфлікти змінних `$cpu` / `$disk`;
- додано `Health.Score`, `Health.Status`, `Health.Findings`;
- додано `CollectionErrors` для контрольованої фіксації помилок збору даних;
- уточнено базову сумісність: Windows PowerShell 5.1+;
- виправлено helper `tools/Publish-ToGitHub.ps1` для уникнення проблем із кодуванням.

Наступний етап — **v0.3.0 Deep Inventory**: розширення hardware/storage/network/security-блоків.

## Безпека

Звіти можуть містити чутливу інформацію: імена користувачів, домени, IP-адреси, MAC-адреси, серійні номери, список ПЗ, відкриті порти та локальних адміністраторів.

Рекомендація: тримати репозиторій приватним, а самі сформовані звіти не комітити в Git.

## Структура проекту

```text
BRAVO_SYSTEM_REPORT/
├── src/
│   └── Get-BravoSystemReport.ps1
├── docs/
│   ├── ARCHITECTURE.md
│   ├── ROADMAP.md
│   └── SECURITY.md
├── examples/
│   └── README.md
├── tools/
│   └── Publish-ToGitHub.ps1
├── .github/workflows/
│   └── powershell-static-check.yml
├── .gitignore
├── CHANGELOG.md
├── Get-BravoSystemReport.ps1
└── README.md
```

## Плани розвитку

Детальний план розширення описано у [`docs/ROADMAP.md`](docs/ROADMAP.md).
Архітектурний підхід — у [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
Правила безпеки — у [`docs/SECURITY.md`](docs/SECURITY.md).

## Правила проекту

- Усі відповіді, документація, логи, консольні повідомлення, Git commit messages, PR/merge-описи та описи змін ведуться українською мовою.
- У PowerShell-скриптах не використовуються emoji.
- Консольний вивід має бути простим і production-friendly: секції `=== ... ===`, маркери `[INFO]`, `[OK]`, `[SUCCESS]`, `[ERROR]`.
- Кольори в PowerShell дозволені, але текстовий contract output не повинен залежати від кольорів.
- PowerShell-скрипти з українським текстом зберігаються у UTF-8 з BOM для сумісності з Windows PowerShell 5.1.

## Обов'язковий формат локальних команд

```powershell
Clear-Host
Set-Location "E:\GitHub\BRAVO_SYSTEM_REPORT"
$ErrorActionPreference = "Stop"
```

## Storage Deep Audit

Починаючи з 0.3.0, профілі Deep та Forensic збирають базовий розширений аудит сховища у JSON-секцію Hardware.Disks.Deep:

- LogicalDisks;
- Volumes;
- Disks.

HTML-таблиці та додаткові storage-підсекції додаються окремими PR після стабілізації JSON-структури.
## BAT-запускачі

У корені проекту доступні BAT-файли для запуску BRAVO SYSTEM REPORT без ручного введення PowerShell-команд:

- BRAVO-SystemReport-Quick.bat — швидкий аудит;
- BRAVO-SystemReport-Full.bat — повний базовий аудит;
- BRAVO-SystemReport-Deep.bat — глибокий аудит;
- BRAVO-SystemReport-Forensic.bat — максимально детальний аудит;
- BRAVO-SystemReport-Launcher.bat — інтерактивне меню вибору режиму.

Усі BAT-файли запускають Get-BravoSystemReport.ps1, зберігають звіти у папку eports поруч із проектом і залишають консоль відкритою після завершення.
## Storage Critical Findings

Починаючи з 0.3.2, профілі Deep та Forensic автоматично формують findings для ризиків вільного місця на томах.

Правила:

- CRITICAL — том має менше 5% вільного місця;
- WARNING — том має менше 10% вільного місця;
- WARNING — системний том має менше 15% вільного місця.

Підсумок ризиків записується у JSON-секцію Hardware.Disks.StorageRisk.