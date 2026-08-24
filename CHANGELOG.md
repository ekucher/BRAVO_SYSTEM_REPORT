## v0.5.0 — аналіз ОС і оновлень Windows

### реліз-пакет

- Виправлено склад реліз-пакета: замість застарілого моноліту `src\Get-BravoSystemReport.ps1` пакується робочий runtime `dist\Get-BravoSystemReport.ps1`.
- Контрольна сума runtime генерується з файлу, який реально потрапляє в пакет, а всі текстові файли нормалізуються до CRLF.
- Fallback визначення версії переведено з застарілого моноліту на `src\90-Main.ps1`.
- `tools\New-ReleasePackage.ps1` зроблено кросплатформним і додано читабельний перелік вмісту пакета.
- Нормалізовано переноси рядків у `dist\Get-BravoSystemReport.ps1` до CRLF.

- Додано модуль `src\39-Collectors-Updates.ps1` з колектором `Get-BravoUpdatesAudit`.
- Додано секцію `Updates` у модель звіту та підвищено `SchemaVersion` до `0.5.0`.
- Додано аналіз життєвого циклу ОС: продукт, DisplayVersion, full build з UBR, канал, дата завершення підтримки і статус `Supported` / `EndingSoon` / `EndOfSupport`.
- Додано пошук доступних оновлень через COM `Microsoft.Update.Session` з таймаутом і виконанням у фоновому job.
- Додано зведення по оновленнях: total, security, critical, driver, definition, other, downloaded, розмір і вік найстарішого оновлення.
- Додано збір стану Windows Update: служба `wuauserv`, політика `AUOptions`, WSUS, час останнього пошуку та встановлення.
- Додано визначення pending reboot з переліком причин.
- Додано збір встановлених оновлень через `Get-HotFix` з fallback на `Win32_QuickFixEngineering`.
- Додано знахідки Health Score для ОС поза підтримкою, невстановлених оновлень безпеки, pending reboot і зупиненого циклу оновлень.
- Додано метричну картку `Updates` і вкладку `Updates` у HTML-звіт із таблицями доступних і встановлених оновлень.
- Додано поля оновлень у CSV-експорт.
- Додано параметри `-SkipUpdateSearch` і `-UpdateSearchTimeoutSec`; профіль `Quick` онлайн-пошук не виконує.
- Додано дати завершення підтримки для Windows 11 25H2 (build 26200) у таблицю життєвого циклу.
- Додано у local Windows validation кроки `Full runtime test` і `Validate updates section` для перевірки онлайн-пошуку оновлень.
- Виправлено помилку `TryParse` з `[ref]` на неініціалізованих змінних, через яку успішний пошук оновлень позначався як `Failed`, а `MaxAgeDays` не обчислювався.
- Захищено `Search.Status = OK` від перезапису помилкою пост-обробки.
- Додано третій канал підтримки `LTSC / LTSB` з окремими датами замість змішування з Enterprise.
- Розширено таблицю життєвого циклу до повного покриття: від Windows 2000 і Windows 2000 Server до Windows 11 25H2 і Windows Server 2025, включно з Windows 10 1511/1703/1709/1803/1903 і Windows Server SAC.
- Посилено CI-перевірку секції `Updates`: неконсистентність `Search.Status`/`Pending.Total` і ненульові `CollectionErrors` тепер валять збірку.
- Класифікацію оновлень переведено на стабільні `CategoryID` замість локалізованих назв категорій; англомовні назви лишились як fallback.
- Додано `Pending.Detailed` і `Pending.IsTruncated`: якщо знайдено більше оновлень, ніж зберігається детально, це видно у звіті та у знахідці.
- LTSC/LTSB тепер визначається за `EditionID` (`EnterpriseS`, `EnterpriseSN`, `IoTEnterpriseS`), а не лише за `Caption`; `EditionID` виводиться у звіті.
- Додано перевірку політики `NoAutoUpdate=1`, яка має пріоритет над застарілим значенням `AUOptions`.
- Статус життєвого циклу `Unknown` більше не дає зелену метрику Updates.
- `-UpdateSearchTimeoutSec` зі значенням `0` або від'ємним більше не вимикає таймаут, а повертається до 180 сек.
- Контрольна сума `dist` рахується на CRLF-варіанті файлу, як його бачить Windows після checkout.
- Додано Windows Server 23H2 (build 25398) у таблицю життєвого циклу.
- Pro Education і Pro for Workstations тепер обслуговуються за споживчим циклом, а не за Enterprise.
- Метрика Updates стає CRITICAL і за наявності critical-оновлень, а не лише security.

### Forensic ZIP default та Storage Deep Inventory v2

- Змінено профіль запуску за замовчуванням з `Full` на `Forensic`.
- Увімкнено створення ZIP-архіву за замовчуванням.
- Додано можливість вимкнути ZIP через `-Zip:$false`.
- Розширено `StorageDeep` полями `Partitions` і `PageFiles`.
- Додано збір partition-даних через `Get-Partition`.
- Додано збір pagefile-даних через `Win32_PageFileUsage`.
- Збережено існуючу логіку `StorageRisk` без змін.
- Перевірено default runtime test: `Forensic + ZIP`, `CollectionErrors=0`, `Partitions=10`, `PageFiles=1`.
### інтерактивний HTML dashboard polish

- Додано пошук по великих HTML-таблицях без зовнішніх CDN.
- Додано helper `New-BravoTableToolbarHtml` для генерації toolbar біля таблиць.
- Додано `.table-toolbar`, `.table-search`, `.table-counter` і `.row-hidden` CSS-класи.
- Додано JS-функції `initializeTableFilters`, `filterTable` і `updateTableCounter`.
- Додано лічильник видимих/загальних рядків для фільтрованих таблиць.
- Додано пошук для Storage Critical Findings, Storage Deep, Network Adapters, Automatic stopped services, Installed software, Findings і Collection errors.
- Збережено print/PDF fallback: toolbar приховується, а всі рядки таблиць показуються при друку.

### інтерактивний HTML dashboard JS tabs

- Додано автономний inline JavaScript без зовнішніх CDN.
- Додано функцію `openTab(event, tabId)` для перемикання вкладок.
- Додано приховування неактивних `.tab-panel` через `display: none`.
- Додано показ активної `.tab-panel.active` через `display: block`.
- Додано керування класом `.active` для `.tab-button`.
- Додано `aria-selected` для активної/неактивних кнопок вкладок.
- Додано ініціалізацію першої вкладки `tab-general` після завантаження HTML.
- Додано підтримку відкриття вкладки з URL hash, наприклад `#tab-network`.
- Збережено print/PDF fallback: у режимі друку всі `.tab-panel` показуються.

### інтерактивний HTML dashboard UI

- Оновлено `src\51-Export-Html.ps1` під HTML dashboard layout.
- Додано автономний CSS-каркас без зовнішніх CDN.
- Додано `dashboard-header` з computer name, uptime, primary IPv4, health/status і status reason.
- Додано `tab-nav` з anchor-кнопками для майбутньої JS-логіки вкладок.
- Додано секції `tab-panel`: General, OS, Hardware, Network, Security, Services, Software, Findings.
- Додано метричні картки `metric-card` для CPU, RAM, Disk і OS.
- Додано універсальні таблиці `.data-table` та scroll-контейнери `.table-scroll` для великих списків.
- Додано адаптивну верстку для вузьких екранів.
- Додано print CSS, який приховує навігацію та прибирає обмеження scroll-контейнерів для друку/PDF.
- JS-перемикання вкладок реалізовано окремим Sprint 3.

### інтерактивний HTML dashboard backend

- Підготовлено backend-структуру для майбутнього інтерактивного HTML-звіту Dashboard & Tabs.
- Оновлено `SchemaVersion` до `0.4.1`.
- Додано top-level поля `Status` і `StatusReason` у модель звіту.
- Додано секцію `Dashboard` з `Header`, `Metrics` і `Tabs`.
- Додано dashboard-метрики `CPU`, `RAM`, `Disk`, `OS`.
- Виправлено RAM-метрики: додано `TotalVisibleMemoryGB`, `FreeGB`, `UsedGB`, `UsedPercent`, `Source`.
- Розширено network-модель для HTML-вкладки: `DefaultGateways`, `DNSServers`, `DNSSuffixSearchOrder`, nested `Network.IP.PrimaryIPv4`, `PrimaryInterface`, `PublicIPv4*`.
- Синхронізовано `Health.Status` з `Report.Status` і `Dashboard.Header.Status`.
- Локально перевірено smoke test профілю `Forensic` з `CSV` і `ZIP`: `SchemaVersion=0.4.1`, `Dashboard` заповнено, `CollectionErrors=0`.

### документація та план впровадження

- Оновлено `README.md` відповідно до фактичної структури проєкту після переходу на модульну архітектуру.
- Додано посилання на `docs/IMPLEMENTATION_PLAN.md`.
- Актуалізовано опис GitHub Actions / Local Windows Validation.
- Актуалізовано структуру проєкту з урахуванням `dist/`, `docs/`, модулів `src/` і workflow-файлів.
- Додано секцію відомого технічного боргу.
- Оновлено `docs/ROADMAP.md`: додано milestones `v0.4.1` ... `v0.7.0`, release stabilization, sanitize, runtime quality, deep inventory, reports і CI gates.
