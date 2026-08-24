## Unreleased — менше шуму в findings: trigger-start служби, деталі помилок System log

- `36-Collectors-ProcessesServices.ps1`: додано whitelist відомих trigger-start/опціональних служб (`edgeupdate`, `edgeupdatem`, `gupdate`, `gupdatem`, `MapsBroker`, `sppsvc`, `WbioSrvc`, `RemoteRegistry`) — вони більше не рахуються у WARNING-знахідці "Автоматичних служб не запущено" (лишаються видимими в `Services.AutomaticStopped` для прозорості, просто не впливають на severity/score).
- `37-Collectors-Events.ps1`: додано `EventLogs.TopErrorSources` — топ-10 джерел помилок System log (Source, Count, останнє повідомлення) за період, замість самого лише лічильника. Знахідка тепер містить топ-3 джерела прямо в тексті.
- `20-ReportModel.ps1`: `SchemaVersion` `0.5.0` → `0.5.1` (нове поле `EventLogs.TopErrorSources`).
- `51-Export-Html.ps1`: додано таблицю "Топ джерел помилок System log" у вкладку Services. Заразом виправлено супутній баг — таблиця "Automatic stopped services" мапилась на неіснуючі властивості `StartType`/`Status` (мали бути `StartMode`/`State`) і завжди показувала порожні колонки.

## Unreleased — ScriptVersion 0.4.1

- `ScriptVersion` (`src/90-Main.ps1`) піднято `0.4.0` → `0.4.1` — версія релізу інструмента, що друкується в банері консолі та в JSON (`ScriptVersion`), відображає накопичені зміни цього PR (Windows Update collector, privacy public IP, health score, CD-ROM fix тощо). Відрізняється від `SchemaVersion` (`0.5.0`), яка версіонує лише структуру JSON-контракту.

## Unreleased — виправлено false positive CRITICAL для CD-ROM томів

- Виправлено `32-Collectors-Storage.ps1`: томи з `DriveType='CD-ROM'` більше не потрапляють у CRITICAL/WARNING знахідки Storage Risk через "0% вільно" (оптичні носії read-only, поняття вільного місця до них не застосовне). Такі томи тепер класифікуються як `HealthyVolumes`.
- Знайдено під час валідації PR на Windows Server 2016: CD-ROM том з ISO показував `Health.Score` штучно нижчим через хибну CRITICAL-знахідку.

## Unreleased — код-рев'ю: privacy, health score, dist rebuild

- **[Blocker]** Перезібрано `dist/Get-BravoSystemReport.ps1` — Windows Update collector нарешті потрапив у виконуваний артефакт.
- Додано прапорець `-SkipPublicIP` та гейтинг профілем (`Full`/`Deep`/`Forensic`) для запитів публічного IP/ISP/geo до сторонніх сервісів — для профілю `Quick` та за наявності прапорця дані більше не відправляються.
- `Update-BravoHealthScore` тепер перераховується вдруге після export-етапів (JSON/HTML/CSV), а JSON перезаписується з фінальною оцінкою — виправлено розсинхронізацію `Health.Score` при помилках експорту.
- Прибрано порожні `catch {}` у `10-Core.ps1` — додано коментарі, що пояснюють свідомо ігноровані сценарії (відповідно до `docs/AI_RULES.md`).
- Виправлено `33-Collectors-Network.ps1`: усунено звернення до `$Report` без `script:`-префіксу, прибрано недосяжний (мертвий) `else`-код для не-`IDictionary` типу, прибрано дублювання CIM-запиту при формуванні fallback-списку IPv4.
- Додано severity-класи `Moderate`/`Low` у HTML-мапінг ризику Windows Update (раніше потрапляли в `risk-unknown`).
- Видалено застарілий сміттєвий файл `tools/Publish-ToGitHub.ps1.broken`.
- `SchemaVersion` піднято `0.4.1` → `0.5.0` (контракт звіту змінено: додана секція `WindowsUpdate`, нове поле `PublicIPv4Status='Skipped'`).

## Unreleased — Windows Update audit

- Додано модуль `39-Collectors-Updates.ps1` зі збором даних Windows Update.
- Додано секцію `WindowsUpdate` у модель звіту (`SchemaVersion` піднято до `0.5.0`, див. запис вище).
- Додано збір встановлених оновлень через `Get-HotFix` з датою останнього встановлення.
- Додано перевірку pending reboot через ключі реєстру Windows Update та CBS.
- Додано пошук відсутніх оновлень через Windows Update Agent COM API (лише профілі `Deep`/`Forensic`).
- Додано findings: CRITICAL для невстановлених критичних оновлень; WARNING для застарілості >60 днів, pending reboot, вимкненої служби wuauserv та черги оновлень.
- Додано картку `Windows Update` та таблицю `Pending Windows Updates` з пошуком у вкладку OS HTML-звіту.
- Додано `src/39-Collectors-Updates.ps1` у `BRAVO.build.json`.

## Unreleased — Forensic ZIP default та Storage Deep Inventory v2

- Змінено профіль запуску за замовчуванням з `Full` на `Forensic`.
- Увімкнено створення ZIP-архіву за замовчуванням.
- Додано можливість вимкнути ZIP через `-Zip:$false`.
- Розширено `StorageDeep` полями `Partitions` і `PageFiles`.
- Додано збір partition-даних через `Get-Partition`.
- Додано збір pagefile-даних через `Win32_PageFileUsage`.
- Збережено існуючу логіку `StorageRisk` без змін.
- Перевірено default runtime test: `Forensic + ZIP`, `CollectionErrors=0`, `Partitions=10`, `PageFiles=1`.
## Unreleased — інтерактивний HTML dashboard polish

- Додано пошук по великих HTML-таблицях без зовнішніх CDN.
- Додано helper `New-BravoTableToolbarHtml` для генерації toolbar біля таблиць.
- Додано `.table-toolbar`, `.table-search`, `.table-counter` і `.row-hidden` CSS-класи.
- Додано JS-функції `initializeTableFilters`, `filterTable` і `updateTableCounter`.
- Додано лічильник видимих/загальних рядків для фільтрованих таблиць.
- Додано пошук для Storage Critical Findings, Storage Deep, Network Adapters, Automatic stopped services, Installed software, Findings і Collection errors.
- Збережено print/PDF fallback: toolbar приховується, а всі рядки таблиць показуються при друку.

## Unreleased — інтерактивний HTML dashboard JS tabs

- Додано автономний inline JavaScript без зовнішніх CDN.
- Додано функцію `openTab(event, tabId)` для перемикання вкладок.
- Додано приховування неактивних `.tab-panel` через `display: none`.
- Додано показ активної `.tab-panel.active` через `display: block`.
- Додано керування класом `.active` для `.tab-button`.
- Додано `aria-selected` для активної/неактивних кнопок вкладок.
- Додано ініціалізацію першої вкладки `tab-general` після завантаження HTML.
- Додано підтримку відкриття вкладки з URL hash, наприклад `#tab-network`.
- Збережено print/PDF fallback: у режимі друку всі `.tab-panel` показуються.

## Unreleased — інтерактивний HTML dashboard UI

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
