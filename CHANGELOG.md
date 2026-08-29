## Unreleased — третій раунд глибокого код-ревю: release-скрипт не запускався, self-zip race

Два незалежні паралельні ревю: (1) накопичена логіка `src/90-Main.ps1` (редагувався в кожному з 4 попередніх коміти поспіль — найбільший ризик прихованих регресій), (2) периферійні файли, які ще не рев'ювались (bat-лаунчери, `tools/*.ps1`, актуальність документації). Кожна знахідка перевірена особисто перед фіксом.

- **[Release-скрипт взагалі не запускався]** `tools/New-ReleasePackage.ps1` посилався на видалений `src/Get-BravoSystemReport.ps1` (визначення версії + hard-required перевірка на самому старті) і не включав `dist/Get-BravoSystemReport.ps1`/`.sha512` у release ZIP — навіть без падіння скрипт зібрав би нефункціональний пакет (root wrapper викликає `dist\...`, якого там нема). Версія тепер читається з `src/90-Main.ps1`; скрипт вимагає наявності свіжого `dist` і звіряє sha512 перед пакуванням; `dist/Get-BravoSystemReport.ps1` + `.sha512` додані в package. Функціонально перевірено — реліз-пакет успішно збирається.
- **[Self-zip race]** `90-Main.ps1`: якщо export-етапи вище (JSON/HTML/CSV/ZIP) додали нову помилку, гейт перерахунку перезбирає ZIP — але до фіксу шлях до вже створеного першим проходом архіву лишався в `GeneratedFiles`, і `Export-BravoZipReport` намагався запакувати сам себе (щойно відкритий ексклюзивно на запис файл) → `IOException`, ще одна непідхоплена помилка вже після того, як Health Score/JSON/HTML зафіксовані як фінальні. Тепер `*.zip` явно виключається з `GeneratedFiles` перед повторним викликом (той самий патерн, що вже використовувався для Email-вкладень).
- `examples/README.md`: синхронізовано з поточною поведінкою (`-Zip` за замовчуванням, `-NoZip` для вимкнення; уточнено, що `-JSONOnly` не вимикає ZIP сам по собі).
- `docs/ROADMAP.md`, `docs/IMPLEMENTATION_PLAN.md`: відмічено вирішені пункти release-package tech debt.

**Перевірено і підтверджено відсутність проблем**: elevation-forwarding усіх параметрів з `05-Params.ps1`, порядок `if ($NoZip) { $Zip = $false }` відносно всіх використань `$Zip` нижче, синхронність `dist/` з `src/` (побайтова звірка + sha512), коректність `BRAVO.build.json` (немає forward-залежностей між модулями), усі 5 `.bat`-лаунчерів, `tools/Publish-ToGitHub.ps1` (немає ризикованих force-дій).

Усі 23 Pester-тести проходять. `dist` перебудовано, sha512 звірено.

## Unreleased — другий раунд глибокого код-ревю: CI завжди падав, Email зі старими даними

Два незалежні паралельні ревю: (1) саме останні 2 коміти попереднього ревю на предмет нових регресій, (2) раніше нерев'юєні модулі (Network/Users/ProcessesServices/Software collectors, Csv/Zip/Email export, Core, ReportModel, tests/, CI). Кожна знахідка перевірена особисто перед фіксом.

- **[CI завжди падав]** `.github/workflows/local-windows-validation.yml`: крок "Validate latest JSON" звертався до неіснуючого `$report.Network.PrimaryIPv4`/`PublicIPv4Status` (реальний шлях — `Network.IP.PrimaryIPv4`/`PublicIPv4Status`, поле переїхало ще при переході на `SchemaVersion 0.5.0`). Кожен PR на `main` мав падати на цьому кроці — pre-existing баг, не з цієї сесії, але критичний для довіри до CI.
- **[Email зі старими даними]** `90-Main.ps1`: `Send-BravoEmailReport` тепер викликається останнім, ПІСЛЯ гейту повторного перерахунку Health Score. Раніше лист відправлявся до гейту — якщо саме ZIP-етап спричиняв нову помилку, лист ішов зі старим (вищим) Health Score в тілі й застарілими JSON/HTML-вкладеннями, хоча файли на диску вже мали виправлене значення. Це саме той розсинхрон, який попередній фікс мав усунути, просто перенесений з диска в надіслану пошту.
- **[Регресія все ще не закрита повністю]** `90-Main.ps1`: `-Zip:$false` (старий, задокументований в історії CHANGELOG спосіб вимкнути ZIP) досі губився при elevation-relaunch навіть після додавання `-NoZip` в попередньому коміті — форвардилось лише за прапорцем `-NoZip`, не за ефективним значенням `$Zip`. Тепер перевіряється `if (-not $Zip)`, що коректно охоплює обидва способи вимкнення.
- **[Локале-залежність]** `37-Collectors-Events.ps1`: фільтр "порожній результат Get-EventLog" тепер звіряє `FullyQualifiedErrorId` (`GetEventLogNoEntriesFound`, стабільний) замість тексту `Exception.Message` ("No matches found", локалізується разом з MUI-пакетом Windows — на uk-UA/ru-UA системах текст інший, і штатний порожній результат помилково потрапляв би в `CollectionErrors`).
- **[Конфлікт з тестом]** `31-Collectors-Hardware.ps1`: прибрано `Add-AuditError` для `LoadPercentage=$null` (додано в попередньому раунді) — це очікуваний, не помилковий стан на щойно піднятих VM/CI-раннерах, і штрафував Health Score та ламав інваріант `CollectionErrors=0` в `EndToEnd.Tests.ps1` на кожному такому прогоні. 0% залишається значенням-заглушкою для "невідомо", як і до фіксу.
- `README.md`: задокументовано `-NoZip` і те, що `-Zip` увімкнений за замовчуванням.

**Свідомо не виправлено**: дублювання `$zipPath` у `GeneratedFiles` між першим і другим викликом `Export-BravoZipReport` (самокоригується через `Select-Object -Unique`, крихко, але не бажає окремого фіксу зараз); прогалини Pester-покриття нових гілок (`-NoZip`-forwarding при елевації, UAC null-case, worst-volume розрахунок) — потребують рефакторингу для unit-тестування (90-Main.ps1 не dot-source-безпечний), окрема задача.

Усі 23 Pester-тести проходять. `dist` перебудовано, sha512 звірено. Функціонально перевірено: `-Zip:$false` (прямий виклик), sha512-звірка, повний Quick-прогін з CollectionErrors=0.

## Unreleased — глибоке код-ревю: виправлено 9 підтверджених багів і 3 правдоподібні

Знайдено двома незалежними глибокими ревю (collector-и та export/core/main), кожна знахідка перевірена особисто читанням коду перед фіксом.

- **[Регресія функціональності]** `05-Params.ps1`/`90-Main.ps1`: додано `-NoZip`. `-Zip:$false` губився при elevation-relaunch — `powershell.exe -File` не підтримує синтаксис `-Switch:$false` з командного рядка (емпірично перевірено: `ParameterArgumentTransformationError`), тому елевований процес завжди створював ZIP, ігноруючи явну відмову користувача. `-NoZip` форвардиться за тим самим патерном, що й `-NoPause`/`-NoEmoji`/`-NoOpenFolder`.
- **[Хибний security-finding]** `34-Collectors-Security.ps1`: WARNING "UAC вимкнено" і INFO "RDP увімкнено" тепер генеруються лише якщо відповідний реєстровий ключ реально вдалось прочитати. Раніше недоступність ключа (Server Core, GPO) мовчки трактувалась як "вимкнено" через дефолтне значення моделі — хибна CRITICAL-подібна знахідка в security-аудиті.
- **[Неузгоджені пороги]** `40-Health.ps1`: статус Disk-плитки на dashboard тепер рахується по найгіршому тому (`Hardware.Disks.Volumes`, пороги 10/20%, ті самі що й у findings), а не по агрегованому вільному місцю по всіх дисках разом. Підтверджено реальним прогоном: диск з 4.57% вільного ховався за агрегатом 17.66% і показував dashboard "WARNING" замість "CRITICAL".
- **[Втрачені помилки]** `90-Main.ps1`: гейт повторного перерахунку Health Score/re-export JSON+HTML тепер стоїть після ZIP і Email (раніше — лише після CSV), тож помилки саме ZIP/Email-етапів більше не ігноруються; ZIP після re-export перезбирається, щоб не пакувати застарілі JSON/HTML.
- **[Втрачені помилки]** `37-Collectors-Events.ps1`: помилки `Get-EventLog` (крім штатного "No matches found") тепер логуються в `CollectionErrors` — раніше `-ErrorAction SilentlyContinue` ковтав їх мовчки, і провал збору виглядав як "0 помилок/попереджень".
- **[Мертвий код]** `51-Export-Html.ps1`: прибрано fallback-гілку, що зверталась до неіснуючого поля `Network.PublicIPv4` (правильний шлях — `Network.IP.PublicIPv4`) — ніколи не виконувалась.
- **[HTML-екранування]** `51-Export-Html.ps1`: `$OutputDir` у футері тепер проходить через `ConvertTo-BravoHtmlText`, як і всі інші динамічні значення у файлі.
- **[Сумісність]** `50-Export-Json.ps1`: JSON пишеться через `[System.IO.File]::WriteAllText` з `UTF8Encoding($false)` замість `Out-File -Encoding utf8` — прибрано BOM, який ламав суворі JSON-парсери (RFC 8259) у зовнішніх CI/monitoring pipeline.
- **[Захист]** `51-Export-Html.ps1`: `CatalogUrl` у href тепер проходить allow-list схеми (`^https://`) перед вставкою — захист від потенційного `javascript:`-URI, якщо патерн буде скопійований для менш контрольованого поля.
- **[Хибне значення]** `31-Collectors-Hardware.ps1`: якщо `Win32_Processor.LoadPercentage` повертає `$null` (буває на VM), тепер логується `Add-AuditError` замість мовчазного показу CPU 0%.
- **[Застаріла константа]** `39b-Collectors-Runtime.ps1`: еталон "найновіша відома версія PowerShell 7" піднято `7.4` → `7.6`.

**Свідомо не виправлено** (LOW/PLAUSIBLE, ризик змін не виправдовує вигоду): `Add-AuditFinding`/`Add-AuditError` досі `+=` в циклі по всій кодовій базі (O(n²), але викликається лише десятки разів за прогін — реальний вплив незначний, конвертація в `List` торкнулась би 15+ місць виклику); окрема Deep-профільна система порогів Storage Risk Summary (5/10/15%) лишається відмінною від basic-аудиту (10/20%) — повна уніфікація вже в `docs/ROADMAP.md` як окремий tech-debt пункт, це більший архітектурний рефакторинг, не точковий фікс.

Усі 23 Pester-тести проходять. `dist/Get-BravoSystemReport.ps1` + `.sha512` перебудовані.

## Unreleased — ревю проєкту: OS-aware .NET-сумісність, прибирання legacy, CI-гварди, Pester-тести

- **[Bugfix]** `39b-Collectors-Runtime.ps1`: `Get-BravoRuntimeAudit` більше не радить сліпо ставити .NET Framework 4.8.1 — тепер визначає максимальну сумісну версію за `OS.Build` (Windows 11 22H2+/Server 2022 23H2+, build ≥ 22621 → 4.8.1; старіші ОС, включно з Windows Server 2019, → 4.8). Раніше на Windows Server 2019 рекомендація "встановіть 4.8.1" блокувалась інсталятором з повідомленням "не підтримується цією операційною системою" — підтверджено реальним прогоном на Server 2019 (build 17763), тепер коректно показує `4.8`.
- Видалено застарілий монолітний `src/Get-BravoSystemReport.ps1` (не редагувався з моменту переходу на модульну архітектуру; вводив в оману щодо "основного" скрипта, зокрема в `powershell-static-check.yml`).
- Видалено `BRAVO_SYSTEM_REPORT.git.bundle` (орфанний бекап-артефакт у корені репо, ніде не використовувався).
- `.github/workflows/powershell-static-check.yml`: перевірка структури репозиторію оновлена під реальну модульну архітектуру (замість застарілого моноліту — `src/90-Main.ps1`, `src/BRAVO.build.json`, `dist/Get-BravoSystemReport.ps1`).
- `.github/workflows/local-windows-validation.yml`: додано звірку `dist/Get-BravoSystemReport.ps1.sha512` з реальним хешем після build; додано гвард, що вимагає підняття `SchemaVersion` і запису в `CHANGELOG.md` разом зі зміною `src/20-ReportModel.ps1`; додано крок `Invoke-Pester tests/`; додано `Deep`-прогін з `-CSV -Zip`, що перевіряє реальне виконання Windows Update COM-пошуку (`WindowsUpdate.SearchStatus -ne 'Skipped'`).
- Додано `tests/` — базовий Pester 5.x набір: `Core.Tests.ps1` (чисті IPv4-хелпери з `10-Core.ps1`), `Manifest.Tests.ps1` (консистентність `BRAVO.build.json` ↔ фактичні файли `src/*.ps1` — ловить клас багів "забув зареєструвати новий модуль"), `EndToEnd.Tests.ps1` (наскрізний прогін `dist` у профілі Quick, локально запускається через `Invoke-Pester tests/`).
- `README.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/IMPLEMENTATION_PLAN.md`: синхронізовано з фактичним станом коду (версії `ScriptVersion 0.4.1`/`SchemaVersion 0.5.2`, дерево структури проєкту, виконані пункти backlog позначені `[x]`, прибрано згадки видаленого моноліту).
- `docs/AI_RULES.md`: усунуто протиріччя між п.6 (обов'язковий бамп `SchemaVersion` при зміні контракту) і п.9 (заборона змінювати `SchemaVersion` без явного запиту) — уточнено, що п.9 стосується довільних бампів, не пов'язаних із поточним запитом.
- `patch/v0.2.0-stabilization.*` свідомо залишено без змін — історичний артефакт міграції, не заважає поточній роботі.

## Unreleased — перевірка оновлень .NET Framework/PowerShell, Catalog-посилання для pending updates

- Додано модуль `39b-Collectors-Runtime.ps1` (`Get-BravoRuntimeAudit`): офлайн-перевірка можливості оновлення .NET Framework 4.x (порівняння release-key з еталоном 4.8.1) та Windows PowerShell/PowerShell 7 (Core) (порівняння з еталоном 7.4, виявлення встановлення через `HKLM:\SOFTWARE\Microsoft\PowerShellCore\InstalledVersions`). Генерує WARNING/INFO-знахідки через `Add-AuditFinding` — раніше версія .NET лише відображалась, ніяк не впливаючи на Health Score.
- `20-ReportModel.ps1`: нові поля `DotNet.ReleaseKey`, `DotNet.LatestKnownVersion`, `DotNet.UpdateAvailable`, `PowerShell.Core7Installed`, `PowerShell.Core7Version`, `PowerShell.Core7LatestKnown`, `PowerShell.Core7UpdateAvailable`.
- `39-Collectors-Updates.ps1`: до кожного запису `WindowsUpdate.PendingUpdates` додано `CatalogUrl` — пряме посилання на Microsoft Update Catalog для відповідного KB.
- `51-Export-Html.ps1`: картка "Runtime" показує статус оновлень .NET/PowerShell 7; таблиця "Pending Windows Updates" отримала клікабельну колонку "Посилання" на Catalog.
- `90-Main.ps1`: inline-блок визначення версії .NET Framework замінено викликом `Get-BravoRuntimeAudit`.
- `SchemaVersion` піднято `0.5.1` → `0.5.2` (нові поля `DotNet.*`, `PowerShell.Core7*`, `WindowsUpdate.PendingUpdates[].CatalogUrl`).

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
