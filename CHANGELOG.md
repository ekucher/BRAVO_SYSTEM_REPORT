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
