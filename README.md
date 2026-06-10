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
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Get-BravoSystemReport.ps1 -Zip -CSV
```

Або напряму:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\Get-BravoSystemReport.ps1 -Zip -CSV
```

Для запуску без паузи в кінці:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Get-BravoSystemReport.ps1 -Zip -CSV -NoPause
```

## Поточний статус

Поточна версія — стартовий імпорт існуючого скрипта. Перед великим розширенням потрібно виконати стабілізацію:

- прибрати конфлікти змінних `$cpu` / `$disk`;
- додати `$StartTime` для коректного часу виконання;
- замінити порожні `catch {}` на контрольований збір помилок;
- додати `CollectionErrors` у JSON/HTML;
- уточнити мінімальну підтримувану версію PowerShell;
- винести генерацію HTML/JSON/CSV у функції;
- додати профілі `Quick`, `Full`, `Deep`, `Forensic`.

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

