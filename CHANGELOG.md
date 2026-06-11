## Unreleased — документація та план впровадження

- Оновлено `README.md` відповідно до фактичної структури проєкту після переходу на модульну архітектуру.
- Додано посилання на `docs/IMPLEMENTATION_PLAN.md`.
- Актуалізовано опис GitHub Actions / Local Windows Validation.
- Актуалізовано структуру проєкту з урахуванням `dist/`, `docs/`, модулів `src/` і workflow-файлів.
- Додано секцію відомого технічного боргу.
- Оновлено `docs/ROADMAP.md`: додано milestones `v0.4.1` ... `v0.7.0`, release stabilization, sanitize, runtime quality, deep inventory, reports і CI gates.
- Додано `docs/IMPLEMENTATION_PLAN.md` з практичним планом впровадження доробок після аналізу репозиторію.

## v0.4.0 — модульна архітектура BRAVO SYSTEM REPORT

- Оновлено `ScriptVersion` до `0.4.0`.
- Інтегровано повну модульну архітектуру BRAVO SYSTEM REPORT.
- Додано модульну збірку монолітного runtime-скрипта через `Build-BRAVO-SystemReport.ps1`.
- Винесено модель звіту у `src\20-ReportModel.ps1`.
- Винесено collector-и у модулі: OS, Hardware, Storage, Network, Security, Users, Processes/Services, EventLogs, Software.
- Винесено розрахунок Health Score у `src\40-Health.ps1`.
- Винесено export-и у модулі: JSON, HTML, CSV, ZIP, Email.
- Оновлено `dist\Get-BravoSystemReport.ps1` і SHA512.
- Оновлено README для стабільної версії `v0.4.0`.
- Перевірено build, parser check для `src` і `dist`, Quick JSONOnly, Deep CSV ZIP, ZIP-вміст, `CollectionErrors=0`, tracked public IPv4 literal scan та self-hosted Windows CI.

## v0.3.21 — винесення Email export у модуль

- Винесено Email export у `src\54-Export-Email.ps1`.
- Додано функцію `Send-BravoEmailReport`.
- Передано `EmailTo`, `EmailFrom` і `SmtpServer` як явні параметри export-функції.
- Збережено формування SMTP-сервера за замовчуванням через `USERDNSDOMAIN`.
- Збережено формування тіла листа з основними параметрами звіту.
- Збережено вкладення з `Report.GeneratedFiles`, окрім ZIP-архіву.
- Оновлено `src\90-Main.ps1`: inline-блок `# Email` замінено на виклик `Send-BravoEmailReport`.
- Перевірено build, parser check для `dist`, Quick no Email, Deep CSV ZIP no Email, `Export.Email errors=0`, `CollectionErrors=0` та `git diff --check`.
## v0.3.20 — винесення ZIP export у модуль

- Винесено ZIP export у `src\53-Export-Zip.ps1`.
- Додано функцію `Export-BravoZipReport`.
- Передано `OutputDir`, `BaseFileName` і `Zip` як явні параметри export-функції.
- Збережено створення ZIP через `System.IO.Compression.FileSystem`.
- Збережено додавання згенерованих файлів із `Report.GeneratedFiles` у ZIP-архів.
- Збережено запис ZIP-файлу у `Report.GeneratedFiles`.
- Оновлено `src\90-Main.ps1`: inline-блок `# ZIP` замінено на виклик `Export-BravoZipReport`.
- Перевірено build, parser check для `dist`, Quick без ZIP, Quick ZIP, Deep CSV ZIP, вміст ZIP-архіву, відсутність ZIP без параметра `-Zip`, `CollectionErrors=0` та `git diff --check`.
## v0.3.19 — винесення CSV export у модуль

- Винесено CSV export у `src\52-Export-Csv.ps1`.
- Додано функцію `Export-BravoCsvReport`.
- Передано `OutputDir`, `BaseFileName` і `CSV` як явні параметри export-функції.
- Збережено формування CSV-даних: `ComputerName`, `Profile`, `HealthScore`, `HealthStatus`, `IPv4`, `Installed_Software`, `CollectionErrors` та інші ключові параметри.
- Збережено запис CSV-файлу у `Report.GeneratedFiles`.
- Оновлено `src\90-Main.ps1`: inline-блок `# CSV` замінено на виклик `Export-BravoCsvReport`.
- Перевірено build, parser check для `dist`, Quick без CSV, Quick CSV, Deep CSV, створення JSON/HTML/CSV, відсутність CSV без параметра `-CSV`, `CollectionErrors=0` та `git diff --check`.
## v0.3.18 — винесення HTML export у модуль

- Винесено HTML export у `src\51-Export-Html.ps1`.
- Додано функцію `Export-BravoHtmlReport`.
- Передано `OutputDir`, `BaseFileName`, `JSONOnly`, `EventLogDays`, `Profile` і `ScriptVersion` як явні параметри export-функції.
- Збережено формування HTML-звіту, `Storage Critical Findings`, `Storage Deep`, `Findings`, `CollectionErrors`, стилі та footer.
- Збережено поведінку `JSONOnly`: HTML-звіт не створюється.
- Оновлено `src\90-Main.ps1`: великий inline-блок `# HTML` замінено на виклик `Export-BravoHtmlReport`.
- Перевірено build, parser check для `dist`, Quick `JSONOnly`, Quick HTML, Deep HTML, створення JSON/HTML, відсутність HTML у `JSONOnly`, `CollectionErrors=0` та `git diff --check`.
## v0.3.17 — винесення JSON export у модуль

- Винесено експорт JSON-звіту у `src\50-Export-Json.ps1`.
- Додано функцію `Export-BravoJsonReport`.
- Передано `OutputDir` і `BaseFileName` як явні параметри export-функції.
- Збережено генерацію JSON через `ConvertTo-Json` з глибиною `12`.
- Збережено запис згенерованого JSON-файлу у `Report.GeneratedFiles`.
- Оновлено `src\90-Main.ps1`: inline-блок `# JSON` замінено на виклик `Export-BravoJsonReport`.
- Перевірено build, parser check для `dist`, Quick `JSONOnly` runtime, Deep runtime, JSON/HTML export, відсутність HTML у `JSONOnly`, `CollectionErrors=0` та `git diff --check`.
## v0.3.16 — винесення розрахунку оцінки стану у модуль

- Винесено розрахунок підсумкової оцінки стану машини у `src\40-Health.ps1`.
- Додано функцію `Update-BravoHealthScore`.
- Перенесено розрахунок кількості критичних знахідок, попереджень і помилок збору з `src\90-Main.ps1`.
- Збережено формулу оцінки стану в межах `0..100`.
- Збережено визначення статусу `OK`, `WARNING` або `CRITICAL`.
- Оновлено `src\90-Main.ps1`: inline-блок оцінки стану замінено на виклик `Update-BravoHealthScore`.
- Перевірено build, parser check для `dist`, Quick runtime, Deep runtime, JSON/HTML export, Health.Score, Health.Status та `CollectionErrors=0`.
## v0.3.15 — винесення Software collector-а у модуль

- Винесено збір інформації про встановлене програмне забезпечення у `src\38-Collectors-Software.ps1`.
- Додано функцію `Get-BravoSoftwareAudit`.
- Перенесено збір програм з registry uninstall-гілок `HKLM` та `WOW6432Node`.
- Збережено додатковий збір `HKCU` uninstall-гілки для профілів `Deep` та `Forensic`.
- Збережено різний формат виводу: назви програм для `Quick`, деталізовані об'єкти для інших профілів.
- Оновлено `src\90-Main.ps1`: inline-блок програмного забезпечення замінено на виклик `Get-BravoSoftwareAudit`.
- Перевірено build, parser check для `dist`, Quick runtime, Deep runtime, JSON/HTML export, Software.Installed та `CollectionErrors=0`.
## v0.3.14 — винесення EventLogs collector-а у модуль

- Винесено збір журналів подій Windows у `src\37-Collectors-Events.ps1`.
- Додано функцію `Get-BravoEventLogsAudit`.
- Перенесено збір System Errors/Warnings за 24 години та за період профілю з `src\90-Main.ps1`.
- Збережено використання параметра `EventLogDays`.
- Збережено finding для системних помилок у журналі System.
- Оновлено `src\90-Main.ps1`: inline-блок журналів подій замінено на виклик `Get-BravoEventLogsAudit`.
- Перевірено build, parser check для `dist`, Quick runtime, Deep runtime, JSON/HTML export, SystemErrors24h, SystemWarnings24h, SystemErrors, SystemWarnings та `CollectionErrors=0`.
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
- Перевірено build, parser check для `dist`, Quick runtime, Deep runtime, JSON/HTML export, PrimaryIPv4, PublicIPv4Status, відсутність public IPv4 у консолі та `CollectionErrors=0`.
