## v0.3.13 — винесення collector-а процесів і служб у модуль

- Винесено збір інформації про процеси та служби у `src\36-Collectors-ProcessesServices.ps1`.
- Додано функцію `Get-BravoProcessesServicesAudit`.
- Перенесено збір процесів через `Get-Process` з `src\90-Main.ps1`.
- Збережено логіку `TopMemory` для профілів `Full`, `Deep` та `Forensic`.
- Перенесено збір служб через `Get-Service`.
- Збережено логіку пошуку автоматичних служб, які не запущені, через `Win32_Service`.
- Збережено finding для автоматичних служб, які мають бути запущені, але зупинені.
- Оновлено `src\90-Main.ps1`: inline-блоки процесів і служб замінено на виклик `Get-BravoProcessesServicesAudit`.
- Перевірено build, parser check для `dist`, Quick runtime, Deep runtime, JSON/HTML export, Processes, TopMemory, Services, AutomaticStopped та `CollectionErrors=0`.
## v0.3.12 — винесення Users collector-а у модуль

- Винесено збір інформації про локальних адміністраторів у `src\35-Collectors-Users.ps1`.
- Перенесено helper `Get-LocalAdministratorsSafe` з `src\90-Main.ps1` у Users collector.
- Додано функцію `Get-BravoUsersAudit`.
- Оновлено `src\90-Main.ps1`: inline-блок користувачів замінено на виклик `Get-BravoUsersAudit`.
- Збережено логіку отримання локальних адміністраторів через `Get-LocalGroupMember` з fallback на `net localgroup`.
- Перевірено build, parser check для `dist`, Quick runtime, Deep runtime, JSON/HTML export, LocalAdmins та `CollectionErrors=0`.
## v0.3.11 — винесення Security collector-а у модуль

- Винесено збір інформації про безпеку у `src\34-Collectors-Security.ps1`.
- Додано функцію `Get-BravoSecurityAudit`.
- Перенесено збір UAC, RDP, антивірусу та Windows Firewall з `src\90-Main.ps1`.
- Збережено логіку findings для вимкненого UAC, увімкненого RDP та вимкнених Firewall-профілів.
- Оновлено `src\90-Main.ps1`: inline-блок безпеки замінено на виклик `Get-BravoSecurityAudit`.
- Перевірено build, parser check для `dist`, Quick runtime, Deep runtime, JSON/HTML export, UAC, RDP, Antivirus, Firewall profiles та `CollectionErrors=0`.
## v0.3.10 — винесення Network collector-а у модуль

- Винесено збір мережевої інформації у `src\33-Collectors-Network.ps1`.
- Додано функцію `Get-BravoNetworkAudit`.
- Перенесено збір hostname, domain, IPv4, gateway, DNS, adapters та TCP-з'єднань з `src\90-Main.ps1`.
- Збережено логіку визначення primary IPv4 через `Get-BravoPrimaryNetworkInterface`.
- Збережено логіку впорядкування IPv4 через `Move-BravoIPv4ToFront`.
- Збережено логіку визначення public IPv4 без виводу значення public IP у консоль.
- Оновлено `src\90-Main.ps1`: inline-блок мережі замінено на виклик `Get-BravoNetworkAudit`.
- Перевірено build, parser check для `dist`, Quick runtime, Deep runtime, JSON/HTML export, primary IPv4, public IPv4 status, listening ports та `CollectionErrors=0`.
## v0.3.9 — винесення Storage collector-а у модуль

- Винесено storage helper-и у `src\32-Collectors-Storage.ps1`.
- Додано функцію `Get-BravoStorageAudit`.
- Перенесено базовий збір дисків з `src\90-Main.ps1` у Storage collector.
- Збережено логіку `Win32_LogicalDisk`, `Win32_DiskDrive`, `Storage Deep Audit` та `StorageRisk`.
- Оновлено `src\90-Main.ps1`: inline-блок дисків замінено на виклик `Get-BravoStorageAudit`.
- Перевірено build, parser check для `dist`, Quick runtime, Deep runtime, JSON/HTML export, Storage Deep, StorageRisk та `CollectionErrors=0`.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро, основний IPv4 та Public IPv4

- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- Додано runtime-визначення публічної IPv4-адреси.
- Додано `Network.PublicIPv4`, `Network.PublicIPv4Provider`, `Network.PublicIPv4CheckedAt` та `Network.PublicIPv4Status`.
- У консольному виводі реальна Public IPv4 не друкується, щоб випадково не вставити її в чат або Git.
- Додано правила `.gitignore` для generated reports із потенційно чутливими даними.
- Перевірено, що публічні IPv4 literal не потрапляють у tracked-зміни.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро та визначення основного IPv4

- Винесено параметри запуску у `src\05-Params.ps1`.
- Винесено базові helper-функції у `src\10-Core.ps1`.
- Оновлено `src\90-Main.ps1`: залишено основний execution flow.
- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- У консольному виводі IP основна IPv4-адреса показується першою.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1` та Quick runtime.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро, основний IPv4 та Public IPv4

- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- Додано runtime-визначення публічної IPv4-адреси.
- Додано `Network.PublicIPv4`, `Network.PublicIPv4Provider`, `Network.PublicIPv4CheckedAt` та `Network.PublicIPv4Status`.
- У консольному виводі реальна Public IPv4 не друкується, щоб випадково не вставити її в чат або Git.
- Додано правила `.gitignore` для generated reports із потенційно чутливими даними.
- Перевірено, що публічні IPv4 literal не потрапляють у tracked-зміни.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.5 - 2026-06-10

### Змінено
- Актуалізовано README.md після змін v0.3.2-v0.3.4.
- Додано опис Storage Deep HTML.
- Додано опис Storage Critical Findings HTML.
- Додано опис BAT `--nopause`.
- Додано опис GitHub Actions Local Windows Validation.
- Виправлено markdown-форматування CSS-класів `risk-critical`, `risk-warning`, `risk-ok`, `risk-unknown` у CHANGELOG.md.

### Перевірено
- README.md відповідає поточному стану v0.3.4.
- CHANGELOG.md не містить пошкоджених `isk-*` записів.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро, основний IPv4 та Public IPv4

- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- Додано runtime-визначення публічної IPv4-адреси.
- Додано `Network.PublicIPv4`, `Network.PublicIPv4Provider`, `Network.PublicIPv4CheckedAt` та `Network.PublicIPv4Status`.
- У консольному виводі реальна Public IPv4 не друкується, щоб випадково не вставити її в чат або Git.
- Додано правила `.gitignore` для generated reports із потенційно чутливими даними.
- Перевірено, що публічні IPv4 literal не потрапляють у tracked-зміни.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро та визначення основного IPv4

- Винесено параметри запуску у `src\05-Params.ps1`.
- Винесено базові helper-функції у `src\10-Core.ps1`.
- Оновлено `src\90-Main.ps1`: залишено основний execution flow.
- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- У консольному виводі IP основна IPv4-адреса показується першою.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1` та Quick runtime.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро, основний IPv4 та Public IPv4

- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- Додано runtime-визначення публічної IPv4-адреси.
- Додано `Network.PublicIPv4`, `Network.PublicIPv4Provider`, `Network.PublicIPv4CheckedAt` та `Network.PublicIPv4Status`.
- У консольному виводі реальна Public IPv4 не друкується, щоб випадково не вставити її в чат або Git.
- Додано правила `.gitignore` для generated reports із потенційно чутливими даними.
- Перевірено, що публічні IPv4 literal не потрапляють у tracked-зміни.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.4 - 2026-06-10

### Змінено
- Оновлено BAT-запускачі Quick, Full, Deep, Forensic.
- Додано обробку аргументів --nopause, -nopause, /nopause на рівні BAT-обгорток.
- BAT-запускачі більше не виконують pause, якщо передано --nopause.
- BAT-запускачі повертають exit code основного PowerShell-скрипта.

### Перевірено
- BRAVO-SystemReport-Quick.bat --nopause завершується без Press any key to continue.
- Quick runtime створює JSON і HTML.
- ExitCode=0.
- PowerShell parser check проходить.
- git diff --check проходить без whitespace error.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро, основний IPv4 та Public IPv4

- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- Додано runtime-визначення публічної IPv4-адреси.
- Додано `Network.PublicIPv4`, `Network.PublicIPv4Provider`, `Network.PublicIPv4CheckedAt` та `Network.PublicIPv4Status`.
- У консольному виводі реальна Public IPv4 не друкується, щоб випадково не вставити її в чат або Git.
- Додано правила `.gitignore` для generated reports із потенційно чутливими даними.
- Перевірено, що публічні IPv4 literal не потрапляють у tracked-зміни.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро та визначення основного IPv4

- Винесено параметри запуску у `src\05-Params.ps1`.
- Винесено базові helper-функції у `src\10-Core.ps1`.
- Оновлено `src\90-Main.ps1`: залишено основний execution flow.
- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- У консольному виводі IP основна IPv4-адреса показується першою.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1` та Quick runtime.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро, основний IPv4 та Public IPv4

- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- Додано runtime-визначення публічної IPv4-адреси.
- Додано `Network.PublicIPv4`, `Network.PublicIPv4Provider`, `Network.PublicIPv4CheckedAt` та `Network.PublicIPv4Status`.
- У консольному виводі реальна Public IPv4 не друкується, щоб випадково не вставити її в чат або Git.
- Додано правила `.gitignore` для generated reports із потенційно чутливими даними.
- Перевірено, що публічні IPv4 literal не потрапляють у tracked-зміни.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.3 - 2026-06-10

### Додано
- Додано HTML-секцію Storage Critical Findings з підсумком критичних, попереджувальних, системних і здорових томів.
- Додано HTML-секцію Storage Deep з таблицею томів, файлових систем, health/operational status, розміру, вільного місця, free percent і risk.
- Додано CSS-класи для відображення storage-ризиків:
`risk-critical`,
`risk-warning`,
`risk-ok`,
`risk-unknown`.
- Додано HTML-екранування значень storage-таблиць перед вставкою у звіт.

### Перевірено
- PowerShell parser check проходить.
- Quick runtime test створює JSON і HTML.
- HTML містить маркери Storage Critical Findings, Storage Deep, storage-table,
`risk-critical`,
`risk-warning`,
`risk-ok`.
- JSON validation проходить з Profile=Quick і CollectionErrors=0.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро, основний IPv4 та Public IPv4

- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- Додано runtime-визначення публічної IPv4-адреси.
- Додано `Network.PublicIPv4`, `Network.PublicIPv4Provider`, `Network.PublicIPv4CheckedAt` та `Network.PublicIPv4Status`.
- У консольному виводі реальна Public IPv4 не друкується, щоб випадково не вставити її в чат або Git.
- Додано правила `.gitignore` для generated reports із потенційно чутливими даними.
- Перевірено, що публічні IPv4 literal не потрапляють у tracked-зміни.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро та визначення основного IPv4

- Винесено параметри запуску у `src\05-Params.ps1`.
- Винесено базові helper-функції у `src\10-Core.ps1`.
- Оновлено `src\90-Main.ps1`: залишено основний execution flow.
- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- У консольному виводі IP основна IPv4-адреса показується першою.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1` та Quick runtime.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро, основний IPv4 та Public IPv4

- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- Додано runtime-визначення публічної IPv4-адреси.
- Додано `Network.PublicIPv4`, `Network.PublicIPv4Provider`, `Network.PublicIPv4CheckedAt` та `Network.PublicIPv4Status`.
- У консольному виводі реальна Public IPv4 не друкується, щоб випадково не вставити її в чат або Git.
- Додано правила `.gitignore` для generated reports із потенційно чутливими даними.
- Перевірено, що публічні IPv4 literal не потрапляють у tracked-зміни.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## 0.3.2 - Unreleased

### Додано
- Додано Storage Critical Findings для профілів Deep та Forensic.
- Додано JSON-секцію Hardware.Disks.StorageRisk.
- Додано автоматичні findings для томів з критично малим вільним місцем.

### Правила оцінки
- CRITICAL: том має менше 5% вільного місця.
- WARNING: том має менше 10% вільного місця.
- WARNING: системний том має менше 15% вільного місця.

## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро, основний IPv4 та Public IPv4

- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- Додано runtime-визначення публічної IPv4-адреси.
- Додано `Network.PublicIPv4`, `Network.PublicIPv4Provider`, `Network.PublicIPv4CheckedAt` та `Network.PublicIPv4Status`.
- У консольному виводі реальна Public IPv4 не друкується, щоб випадково не вставити її в чат або Git.
- Додано правила `.gitignore` для generated reports із потенційно чутливими даними.
- Перевірено, що публічні IPv4 literal не потрапляють у tracked-зміни.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро та визначення основного IPv4

- Винесено параметри запуску у `src\05-Params.ps1`.
- Винесено базові helper-функції у `src\10-Core.ps1`.
- Оновлено `src\90-Main.ps1`: залишено основний execution flow.
- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- У консольному виводі IP основна IPv4-адреса показується першою.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1` та Quick runtime.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро, основний IPv4 та Public IPv4

- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- Додано runtime-визначення публічної IPv4-адреси.
- Додано `Network.PublicIPv4`, `Network.PublicIPv4Provider`, `Network.PublicIPv4CheckedAt` та `Network.PublicIPv4Status`.
- У консольному виводі реальна Public IPv4 не друкується, щоб випадково не вставити її в чат або Git.
- Додано правила `.gitignore` для generated reports із потенційно чутливими даними.
- Перевірено, що публічні IPv4 literal не потрапляють у tracked-зміни.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## 0.3.0 - Unreleased

### Додано
- Додано перший безпечний skeleton Storage Deep Audit для профілів Deep та Forensic.
- Додано JSON-секцію Hardware.Disks.Deep з базовими даними LogicalDisks, Volumes та Disks.

### Змінено
- Оновлено ScriptVersion та SchemaVersion до 0.3.0.

# Журнал змін

## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро, основний IPv4 та Public IPv4

- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- Додано runtime-визначення публічної IPv4-адреси.
- Додано `Network.PublicIPv4`, `Network.PublicIPv4Provider`, `Network.PublicIPv4CheckedAt` та `Network.PublicIPv4Status`.
- У консольному виводі реальна Public IPv4 не друкується, щоб випадково не вставити її в чат або Git.
- Додано правила `.gitignore` для generated reports із потенційно чутливими даними.
- Перевірено, що публічні IPv4 literal не потрапляють у tracked-зміни.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро та визначення основного IPv4

- Винесено параметри запуску у `src\05-Params.ps1`.
- Винесено базові helper-функції у `src\10-Core.ps1`.
- Оновлено `src\90-Main.ps1`: залишено основний execution flow.
- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- У консольному виводі IP основна IPv4-адреса показується першою.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1` та Quick runtime.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро, основний IPv4 та Public IPv4

- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- Додано runtime-визначення публічної IPv4-адреси.
- Додано `Network.PublicIPv4`, `Network.PublicIPv4Provider`, `Network.PublicIPv4CheckedAt` та `Network.PublicIPv4Status`.
- У консольному виводі реальна Public IPv4 не друкується, щоб випадково не вставити її в чат або Git.
- Додано правила `.gitignore` для generated reports із потенційно чутливими даними.
- Перевірено, що публічні IPv4 literal не потрапляють у tracked-зміни.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## 0.2.0 — 2026-06-10

### Додано

- Додано профілі аудиту `Quick`, `Full`, `Deep`, `Forensic`.
- Додано параметри `-OutputPath`, `-NoOpenFolder`, `-EventLogDays`.
- Додано `Health.Score`, `Health.Status`, `Health.Findings`.
- Додано `CollectionErrors` для фіксації помилок збору даних.
- Додано детальніші блоки RAM-модулів, фізичних дисків, мережевих адаптерів, listening TCP-портів, зупинених автоматичних служб.

### Виправлено

- Виправлено конфлікт змінних іконок `$cpu` / `$disk` з об'єктами CPU/дисків.
- Виправлено обчислення часу виконання скрипта.
- Прибрано порожні `catch {}` у ключових секціях.
- Виправлено helper `tools/Publish-ToGitHub.ps1`, щоб уникнути проблем із кодуванням у Windows PowerShell.

## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро, основний IPv4 та Public IPv4

- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- Додано runtime-визначення публічної IPv4-адреси.
- Додано `Network.PublicIPv4`, `Network.PublicIPv4Provider`, `Network.PublicIPv4CheckedAt` та `Network.PublicIPv4Status`.
- У консольному виводі реальна Public IPv4 не друкується, щоб випадково не вставити її в чат або Git.
- Додано правила `.gitignore` для generated reports із потенційно чутливими даними.
- Перевірено, що публічні IPv4 literal не потрапляють у tracked-зміни.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро та визначення основного IPv4

- Винесено параметри запуску у `src\05-Params.ps1`.
- Винесено базові helper-функції у `src\10-Core.ps1`.
- Оновлено `src\90-Main.ps1`: залишено основний execution flow.
- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- У консольному виводі IP основна IPv4-адреса показується першою.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1` та Quick runtime.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## v0.3.6 — модульне ядро, основний IPv4 та Public IPv4

- Додано визначення основного мережевого інтерфейсу через default route `0.0.0.0/0`.
- Додано `Network.PrimaryIPv4` та `Network.PrimaryInterface` у JSON-звіт.
- Додано runtime-визначення публічної IPv4-адреси.
- Додано `Network.PublicIPv4`, `Network.PublicIPv4Provider`, `Network.PublicIPv4CheckedAt` та `Network.PublicIPv4Status`.
- У консольному виводі реальна Public IPv4 не друкується, щоб випадково не вставити її в чат або Git.
- Додано правила `.gitignore` для generated reports із потенційно чутливими даними.
- Перевірено, що публічні IPv4 literal не потрапляють у tracked-зміни.
## v0.3.7 — винесення ReportModel у модуль

- Винесено створення базової моделі звіту у `src\20-ReportModel.ps1`.
- Додано функцію `New-BravoReportModel`.
- Оновлено `src\90-Main.ps1`: ініціалізація `$script:Report` виконується через `New-BravoReportModel`.
- Перевірено збірку моноліту `dist\Get-BravoSystemReport.ps1`.
- Перевірено Quick runtime, JSON/HTML export, `SchemaVersion`, `ScriptVersion`, `Profile`, `PrimaryIPv4` та `PublicIPv4Status`.
- Значення Public IPv4 не виводиться в консоль.
## 0.1.0 — 2026-06-10

### Додано

- Ініціалізовано проект **BRAVO SYSTEM REPORT**.
- Додано стартовий скрипт `src/Get-BravoSystemReport.ps1` на основі наданого `Get-SystemAudit.ps1`.
- Додано README, roadmap, архітектурні нотатки, правила безпеки та `.gitignore`.
- Додано базовий GitHub Actions workflow для перевірки PowerShell-скриптів через PSScriptAnalyzer.

### Заплановано

- Рефакторинг скрипта на функції.
- Додавання профілів аудиту `Quick`, `Full`, `Deep`, `Forensic`.
- Додавання `Health Score`, `Findings`, `CollectionErrors`.
- Розширення HTML-звіту.

### Правила проекту

- Зафіксовано українську мову для відповідей, commit messages, PR/merge-описів, документації, логів і консольних повідомлень.
- Прибрано emoji з PowerShell-скриптів.
- Уніфіковано консольний вивід: секції `=== ... ===`, маркери `[INFO]`, `[OK]`, `[SUCCESS]`, `[ERROR]`.
- Додано `.editorconfig` для фіксації кодування PowerShell-скриптів у UTF-8 з BOM.
