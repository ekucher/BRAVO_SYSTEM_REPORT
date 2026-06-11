## Unreleased — інтерактивний HTML dashboard backend

- Підготовлено backend-структуру для майбутнього інтерактивного HTML-звіту Dashboard & Tabs.
- Оновлено `SchemaVersion` до `0.4.1`.
- Додано top-level поля `Status` і `StatusReason` у модель звіту.
- Додано секцію `Dashboard` з `Header`, `Metrics` і `Tabs`.
- Додано dashboard-метрики `CPU`, `RAM`, `Disk`, `OS`.
- Виправлено RAM-метрики: додано `TotalVisibleMemoryGB`, `FreeGB`, `UsedGB`, `UsedPercent`, `Source`.
- Розширено network-модель для HTML-вкладки: `DefaultGateways`, `DNSServers`, `DNSSuffixSearchOrder`, nested `Network.IP.PrimaryIPv4`, `PrimaryInterface`, `PublicIPv4*`.
- Синхронізовано `Health.Status` з `Report.Status` і `Dashboard.Header.Status`.
- Локально перевірено smoke test профілю `Forensic` з `CSV` і `ZIP`: `SchemaVersion=0.4.1`, `Dashboard` заповнено, `CollectionErrors=0`.

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
