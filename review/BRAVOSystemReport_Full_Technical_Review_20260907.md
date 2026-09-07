# Повне технічне ревю BRAVO SYSTEM REPORT

**Репозиторій:** `ekucher/BRAVO_SYSTEM_REPORT`

**Об'єкт ревю:** `main`, `developer`, `release/v0.6.1-stable`, активний PR #85, архітектура, runtime, build/dist, CI/CD, release governance, security та privacy (`-Sanitize`), тестування, документація

**Дата ревю:** 2026-09-07

---

## 1. Загальний висновок

**BRAVO SYSTEM REPORT уже переріс категорію «PowerShell-скрипт для аудиту».** За фактом це інструмент із:

- модульною архітектурою `src/*.ps1 → dist`;
- єдиною моделлю звіту і сімома форматами виводу (JSON/HTML/PDF/TXT/MD/CSV/ZIP + Email);
- execution contract між wrapper, `dist` і elevation;
- детермінованим exit-code contract;
- режимом safe-sharing `-Sanitize` з fail-closed поведінкою;
- Health Score, findings, `CollectionErrors`/`ExportErrors`;
- CI на реальному Windows PowerShell 5.1 з runtime-тестами;
- release governance `developer → release/* → main → tag`;
- 24 файлами Pester-тестів.

`main` зараз містить stable **0.5.0**, `developer` — **0.6.1** (SchemaVersion 0.6.20), а `release/v0.6.1-stable` — release candidate, який через PR #85 очікує promotion у `main`.

`developer` перебуває на 65 комітів попереду `main` і є фактичною інтеграційною лінією 0.6.x. `main` при цьому правильно залишається production-гілкою.

### Інтегральна оцінка

| Область | Оцінка |
|---|---:|
| Архітектура | **7.4/10** |
| Коректність збору даних | **6.6/10** |
| Security engineering (сам інструмент) | **7.2/10** |
| Privacy / `-Sanitize` | **5.5/10** |
| CI/CD | **7.8/10** |
| Release governance | **6.4/10** |
| Автоматичне тестування | **7.9/10** |
| Real-machine validation | **6.0/10** |
| Maintainability | **6.3/10** |
| Документація — обсяг | **9.0/10** |
| Документація — консистентність | **6.2/10** |
| Production readiness `main` (0.5.0) | **7/10** |
| Production readiness `release/v0.6.1-stable` (PR #85 як є) | **не готовий до promotion** |

**Загалом: приблизно 7/10.**

Для PowerShell-проєкту, якому три місяці і який веде одна людина з AI-асистентами, це вже дуже зріла кодова база. Головна проблема тепер не «погана якість коду», а **розрив між задекларованими гарантіями (safe sharing, «no blockers», required checks) і тим, що механічно перевіряється**.

### Обмеження ревю

Ревю виконано читанням коду release-гілки (head PR #85, `3db337e`), `main`, `developer`, історії git, PR/CI на GitHub. PowerShell-runtime у середовищі ревю немає, тому кожна знахідка позначена як **підтверджена кодом** або **правдоподібна** (потребує прогону на Windows). Пріоритети: **P1** — неправильний результат аудиту, порушення задекларованої гарантії або реальна exposure; **P2** — дефект з workaround або суттєвий борг; **P3** — гігієна.

Процес: код читали кілька незалежних рецензентів за окремими лінзами (архітектура, колектори, privacy, security, export-шар); знахідки з лінз архітектури, колекторів і privacy (64) пройшли окрему adversarial-перевірку іншим рецензентом із калібруванням пріоритету (жодну не спростовано, чотири знижено з P1 до P2 або з P2 до P3); знахідки з лінз security та export-шару (28) перевірені вибірково автором ревю — у документ увійшли лише ті, що підтверджені кодом. Оцінки в таблиці — судження автора ревю на основі підтверджених знахідок.

---

## 2. Поточний стан репозиторію

Репозиторій публічний, основна гілка — `main`, Issues увімкнені, але жодного Issue за весь час не створено. PR ревʼюється ботом Codex, додатково працює GitGuardian.

### `main`

Production:

```text
BRAVO SYSTEM REPORT 0.5.0
SchemaVersion = 0.5.0
GitHub Release v0.5.0 (2026-08-24)
```

### `developer`

Інтеграційна лінія:

```text
ScriptVersion = 0.6.1
SchemaVersion = 0.6.20
65 комітів попереду main
~40 PR (#45–#86) за 6 робочих днів (29.08–03.09)
```

### `release/v0.6.1-stable`

Release candidate:

```text
developer
  + Release Sync & Governance Fixes (e01e1ca)
  + PR #87 Release Blocker Fixes (b4ca2c3..d0fe19a)
  = 3db337e  ← head PR #85
```

Важлива деталь топології:

```text
release..developer = 0 комітів
developer..release = 9 комітів
```

Тобто `developer` **не отримав назад** жодного з release-blocker fixes. Після merge PR #85 у `main` гілка `developer` стане одночасно і «попереду» (нічого), і «позаду» (9 комітів) — класична ситуація, коли наступна feature-гілка від `developer` регресує вже виправлені дефекти.

### Активний PR #85

```text
release/v0.6.1-stable → main
state = open
mergeable_state = clean
checks: Local Windows Validation ✓, Static hosted ✓, GitGuardian ✓
review threads: 25 (Codex), resolved: 0
```

### Гілка поза процесом

```text
fix/v061-storage-ci-integrity
1 коміт (5cc7948), 03.09 21:11 — ПІСЛЯ фінального SHA PR #85
не має PR
CHANGELOG у ній називає зміни "acceptance-review fix"
```

Це означає, що автор уже знає про дефекти в release candidate, але сам PR #85 про це не знає.

### Branch protection

```text
main:      protected = false
developer: protected = false
```

Процес (`docs/PROJECT_RULES.md`) описує required checks і «merge лише після зелених checks», але механічно це нічим не забезпечено. Той самий документ чесно фіксує це як рекомендацію власнику.

---

## 3. Архітектура

Фактична схема виконання:

```text
   BRAVO-SystemReport-*.bat / Launcher.bat
                 │
                 ▼
   Get-BravoSystemReport.ps1   (root wrapper, transparent passthrough)
                 │  & dist\... @PSBoundParameters
                 ▼
   dist\Get-BravoSystemReport.ps1   (монолітний build з src\*.ps1)
                 │
        05-Params ─ 10-Core ─ 20-ReportModel
                 │
        elevation self-relaunch (runas) ──► той самий dist з -SkipElevation
                 │
        30..39b  Get-Bravo<Area>Audit  ──► $script:Report.<Section>
                 │
        40-Health   Update-BravoHealthScore (один раз)
                 │
        45-Sanitize (опційно, fail-closed)
                 │
        50..56   JSON → HTML → PDF → TXT → MD → CSV → ZIP → Email
                 │
        exit code 0/1/2/3/4/5
```

Що в цій схемі правильно:

- **Один `$script:Report`** — усі формати (JSON/HTML/CSV/TXT/MD) читають одну модель; жоден export не рахує нічого сам.
- **Одне джерело дефолтів** — `src/05-Params.ps1`; root wrapper форвардить лише `$PSBoundParameters`. Це результат стабілізації P0, де wrapper і dist мали два незалежні `param()`-блоки, що розійшлися.
- **`CollectionErrors` ≠ `ExportErrors`** — помилка збору впливає на Health Score (властивість машини), помилка запису — лише на exit code (властивість інструмента).
- **Детермінований exit code contract** і `-Strict` як окремий режим для CI-гейтів.
- **Fail-closed `-Sanitize`** — якщо маскування впало посередині, жоден файл не пишеться (exit 5).
- **Read-only audit** як інваріант: у `src/` немає записів у реєстр, служби чи файли поза `OutputPath`; жодного `$global:`.

---

## 4. Найбільший архітектурний борг: модель звіту — це одночасно контракт, runtime-state і об'єкт маскування

`$script:Report` виконує три ролі:

```text
1. data contract      — те, що серіалізується в JSON і документується в SCHEMA.md
2. runtime state      — GeneratedFiles, ExportErrors, OutputPath мутуються ПІСЛЯ sanitize
3. sanitize target    — 45-Sanitize маскує конкретні шляхи в цій моделі
```

Це вже не теоретична проблема. Саме поєднання ролей 2 і 3 дало production-class дефект у release candidate:

```text
45-Sanitize маскує Report.OutputPath
        ↓
Export-BravoHtmlReport / Txt / Md / Csv додають у Report.GeneratedFiles
   сирі абсолютні шляхи (C:\Users\jdoe\...\BravoSystemReport_...html)
        ↓
будь-який ExportError (SMTP, PDF, ZIP, CSV)
        ↓
Sync-BravoJsonIfExportErrorsChanged перезаписує JSON
        ↓
sanitized JSON містить реальний шлях з іменем користувача
        ↓
цей JSON іде в ZIP і у вкладення Email
```

`src/50-Export-Json.ps1` серіалізує весь `$script:Report` (`ConvertTo-Json -Depth 12`), `GeneratedFiles` заповнюється сирим `$OutputDir` у `51/52/55/56/53-Export-*.ps1`, а `src/90-Main.ps1` тричі викликає повторний запис JSON, коли `ExportErrors` зросли. Сценарій «`-EmailTo` + недоступний SMTP» — це буквально CI-крок «Exit code contract test». **Підтверджено кодом, P1.**

Другий наслідок тієї самої архітектури — sanitizer як **ручний deny-list**: кожне нове поле треба не забути додати. Історія v0.6.1 (Motherboard → StartName → DNS suffix per adapter → InstalledBy → WSUS → LastMessage → GeneratedFiles → WinHttpProxy) показує, що список завжди відстає від колекторів на один крок.

### Що робити

Не переписувати модель. Розділити ролі:

```text
$script:Report          — тільки data contract (те, що описує SCHEMA.md)
$script:Ctx             — RuntimeContext: Profile, Caps, OutputDir, GeneratedFiles,
                          flags (Offline/SkipGeoIP/...), ScriptStartTime
Field policy manifest   — 'Meta.UserName' = USER; 'Updates.*.InstalledBy' = USER;
                          'EventLogs.*.LastMessage' = FREETEXT; ...
                          → generic deep-walk masker + тест «кожен string-leaf має policy»
```

і зробити export-етапи читачами **замороженого snapshot** моделі: після `-Sanitize` жодна мутація в `$script:Report` не допускається.

### Пріоритет

**P1 для витоку `GeneratedFiles`, P2 для рефакторингу.** Big-bang rewrite тут небезпечніший за сам борг: усі 24 тестові файли спираються на поточну модель.

---

## 5. Runtime-файли стають занадто великими

Розмір коду вже помітний:

```text
src/51-Export-Html.ps1          820 рядків   95 KB   (рядки до 6 872 символів)
src/34-Collectors-Security.ps1  749 рядків   55 KB   (Get-BravoSecurityAudit ≈ 557 рядків, 17 try-блоків)
src/32-Collectors-Storage.ps1   692 рядки    40 KB
src/39-Collectors-Updates.ps1   685 рядків   36 KB
src/90-Main.ps1                 545 рядків   29 KB
src/45-Sanitize.ps1             340 рядків   20 KB
tests/ExecutionContract.Tests   870 рядків   54 KB
CHANGELOG.md                    719 рядків  143 KB
docs/ROADMAP.md                 305 рядків   50 KB
dist/Get-BravoSystemReport.ps1  6 429 рядків (main: 3 394)
```

Це вже зона, де:

```text
collector module != small cohesive module
```

а радше:

```text
collector module = новий monolith, тільки переміщений з кореня
```

### Не раджу

Не треба дробити все на десятки мікромодулів або переходити на `.psm1` заради форми.

### Треба виділити саме policy boundaries

```text
34-Collectors-Security.ps1
 ├─ Baseline        UAC / RDP / Firewall / Antivirus
 ├─ Platform        SecureBoot / TPM / SMBv1 / TLS
 ├─ Services        Defender / WinRM / SMB signing
 ├─ Policy          Password / Audit policy
 └─ Persistence     Autoruns / ScheduledTasks   (Deep/Forensic)

51-Export-Html.ps1
 ├─ Layout          CSS / JS / shell
 ├─ Tabs            один файл-фрагмент на вкладку
 └─ Helpers         ConvertTo-BravoHtmlText / New-Bravo*Html (визначені ОДИН раз, не всередині функції)
```

У `51-Export-Html.ps1` 11 helper-функцій зараз оголошуються всередині `Export-BravoHtmlReport` при кожному виклику, а 45 KB із 95 KB — це 40 template-рядків. Це не ламає runtime, але робить diff нечитабельним і review неможливим.

---

## 6. Execution contract і параметри

Це один із найкращих результатів стабілізаційного циклу.

Раніше root wrapper і `dist` мали два незалежні `param()`-блоки, які розійшлися (різний default `Profile`, загублений `-Zip:$false`). Тепер:

```text
src/05-Params.ps1        — єдине джерело дефолтів
Get-BravoSystemReport.ps1 — форвардить лише $PSBoundParameters
tests/ParameterSurface   — AST-звірка множин параметрів wrapper ↔ 05-Params
```

Так само правильно вирішено обмеження `powershell.exe -File`, який не приймає `-Zip:$false`: окремий default-false switch `-NoZip` за тим самим патерном, що й `-NoPause`/`-NoEmoji`.

### Залишкова слабкість: elevation relaunch

Self-relaunch під адміністратором серіалізує параметри у **рядок команди**:

```powershell
$arguments += "-OutputPath `"$OutputPath`""
$arguments += "-EmailTo `"$EmailTo`""
$arguments += "-SmtpServer `"$SmtpServer`""
$psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`" $($arguments -join ' ')"
```

Без escaping лапок і без обробки trailing backslash. За правилами розбору командного рядка Windows `\"` — це екранована лапка, тому шлях із кінцевим `\` **не закриває свій аргумент**, і все, що йде далі, потрапляє у значення `-OutputPath`:

```text
користувач:   .\Get-BravoSystemReport.ps1 -OutputPath D:\audit\ -Sanitize      (tab-completion додає \)
без прав адміністратора → relaunch:
              -OutputPath "D:\audit\" -JSONOnly ... -Sanitize -SanitizeLevel Basic -UpdateSearchTimeoutSec 180 -EmailFrom "..."
елевований процес бачить:
              OutputPath = 'D:\audit" -JSONOnly ... -Sanitize -SanitizeLevel Basic ... -EmailFrom '
              -Sanitize   = НЕ передано
        ↓
New-Item на шлях із лапкою падає → ExportError 'OutputPath' → fallback у каталог скрипта
        ↓
НЕзамаскований звіт записано поруч зі скриптом, exit code 1
```

`-EmailFrom` завжди додається (дефолт `systemaudit@<COMPUTERNAME>.local` не порожній), тож наступна лапка є завжди. Жоден тест не проганяє relaunch (усі E2E-тести передають `-SkipElevation`, CI працює під адміністратором). `.bat`-лаунчери безпечні (їхній `%REPORTS%` без кінцевого `\`), але ручний запуск із tab-completion — головний сценарій оператора. PR #85 згадує «trailing backslash/quoting» як P2/P3 backlog; наслідок для `-Sanitize` там не проаналізовано. **P1** (підтверджено кодом; поведінка розбору аргументів Windows задокументована).

Поверхня параметрів існує у **трьох** ручних копіях: `05-Params`, wrapper, серіалізатор elevation. Тест `ParameterSurface` захищає лише перші дві; новий параметр, забутий у серіалізаторі, мовчки губиться при relaunch.

Правильна модель — не будувати рядок вручну, а форвардити параметри файлом (temp JSON) або через `-EncodedCommand`, додати серіалізатор до того самого AST-тесту і один E2E-тест relaunch-у зі шляхом, що закінчується на `\`.

---

## 7. Build, `dist` і цілісність артефакту

`Build-BRAVO-SystemReport.ps1` конкатенує 26 модулів за `src/BRAVO.build.json` (маніфест звірено: повний, без зайвих і відсутніх файлів), проганяє parser check і пише `dist/*.sha512`.

Заголовок збірки містить:

```text
GeneratedAt: 2026-09-03 19:50:56
```

Це робить build **недетермінованим** — два прогони на одному `src` дають різні байти і різний SHA512. Саме через це:

- перша версія CI-кроку «dist reproducibility» (`git diff --exit-code -- dist/`) падала на кожному прогоні (run #95/#96 03.09) і була замінена на порівняння з нормалізацією рядка `GeneratedAt`;
- CI звіряє `.sha512` лише зі **щойно перезібраним** runtime, а не із закоміченим: крок «Verify SHA512» іде після «Build», який перезаписує обидва файли. Закомічений `.sha512` — той, яким користувач звіряє завантажений `dist`, — не валідується взагалі. Це виправлено лише в гілці `fix/v061-storage-ci-integrity` (крок «Verify committed dist SHA512» ДО build).

Правильна модель:

```text
build без timestamp (або timestamp = commit date, плюс commit SHA)
        ↓
dist байт-у-байт відтворюваний
        ↓
CI: committed dist == fresh build   (звичайний git diff, без нормалізації)
CI: committed .sha512 == sha512(committed dist)
```

`tools/New-ReleasePackage.ps1` при пакуванні нормалізує всі текстові файли до CRLF через Latin1 round-trip і рахує SHA512 уже з файлу в пакеті — це правильно, бо саме цей файл отримує користувач.

---

## 8. Коректність збору даних

Це область, де проєкт зробив найбільше правильних кроків і де залишилось найбільше конкретних дефектів.

### Що зроблено добре

- locale-independence там, де вже виправлено: SID `S-1-5-32-544/555` замість назв груп, числовий `Level` замість `LevelDisplayName`, `CategoryID` замість назв категорій оновлень, `FullyQualifiedErrorId` замість тексту помилок, позиційний розбір `net accounts`;
- один набір thresholds для storage (5/10/15 %) і CPU/RAM (75/90, 85/95) із чистими функціями і тестами;
- dashboard-плитка диска рахується за найгіршим томом, а не за агрегатом;
- «доступ заборонено» ≠ «не підтримується» для Secure Boot;
- Windows Update COM-пошук ізольовано у background job з таймаутом, cleanup і обліком truncation.

### Дефекти, підтверджені кодом

**Multi-homed hosts: Routing.DefaultGateways / DNSServers / DNSSuffixSearchOrder псуються.** `src/33-Collectors-Network.ps1` акумулює списки так:

```powershell
$script:Report.Network.Routing.DefaultGateways =
    @($script:Report.Network.Routing.DefaultGateways + $adapterConfig.DefaultIPGateway) |
    Where-Object { $_ } | Select-Object -Unique
```

Результат pipeline з одним елементом PowerShell присвоює як **рядок**, а не масив. На другому адаптері `'10.0.0.1' + @('10.0.1.1')` — це вже конкатенація рядків: `10.0.0.110.0.1.1`. Те саме для DNS-серверів і DNS-суфіксів, якщо перший адаптер мав рівно одне значення. Сервер із LAN + backup-мережею, Hyper-V host, будь-яка машина з двома шлюзами — типові жертви. **P1.**

**MBR WinRE (0x27) у Deep/Forensic → false CRITICAL і exit 4 у `-Strict`.** Після PR #87 reserved-класифікація спирається на `Get-Partition.Type`, який для MBR-дисків не мапить WinRE у `Recovery`; штатно заповнений на 90 %+ розділ відновлення потрапляє в аналіз вільного місця. Виправлено лише в гілці поза PR. **P1** для legacy-BIOS парку.

**Security-журнал у summary завжди 0/0/0.** `src/37-Collectors-Events.ps1` запитує `Get-WinEvent -FilterHashtable @{ LogName='Security'; Level = 1,2,3 }`. Audit-події Security мають `Level = 0` (`LogAlways`, розрізняються Keywords `Audit Success/Failure`), тому запит повертає `NoMatchingEventsFound`, а звіт показує `Status='Detected'` з нулями. Рядок «Security» у таблиці Event Logs — декоративний. **P2.**

**Defender passive mode: виправлення v0.6.1 не спрацьовує.** `Test-BravoDefenderRealTimeProtectionWarning` порівнює `AMRunningMode` з `'Passive'`/`'SxS Passive'`, а `Get-MpComputerStatus` повертає `'Passive Mode'`/`'SxS Passive Mode'`. WARNING «Real-Time Protection вимкнено» продовжує спрацьовувати на машинах зі стороннім антивірусом. **P2, правдоподібно** (значення з документації Microsoft; підтвердити прогоном).

**Томи з `Size = 0` → CRITICAL.** У базовому проході `FreePercent = 0`, якщо `Size` не більше нуля; для Quick/Full це одразу CRITICAL-finding. Заблокований BitLocker-том, RAW-том, том без файлової системи з літерою — усі мають `Size = $null` у `Win32_LogicalDisk` (фільтр `DriveType=3` їх не відсікає). **P2.**

**HTML Storage Deep суперечить Findings.** `src/51-Export-Html.ps1` класифікує **будь-який** том без літери як `RESERVED`, тоді як risk summary після v0.6.1 дивиться на `PartitionType`. Folder-mounted data-том у таблиці — «не є ризиком», у findings — CRITICAL. **P2.**

**CPU — лише перший сокет.** `Get-AuditObject -ClassName 'Win32_Processor' -First`: на двосокетних серверах ядра, потоки і навантаження занижені вдвічі. **P2.**

**Lockout threshold і password history WARNING недосяжні.** `net accounts` друкує `Never`/`None` для 0; код свідомо рахує findings лише з числових значень, тож саме «вимкнено» ніколи не стає знахідкою. **P2** (false negative у найпоширенішому небезпечному стані).

**Kernel-Power 41 рахується тричі.** Одна подія неочікуваного вимкнення дає CRITICAL за System summary, WARNING за HardwareDiagnostics і WARNING за SystemErrors — Health Score стає CRITICAL, а у `-Strict` — exit 4. **P2** (калібрування).

**Deep/Forensic втрачають усі free-space findings, якщо `Get-Volume` впав.** У Deep/Forensic базовий прохід свідомо не емітить findings (делегує risk summary), а risk summary без даних `Get-Volume` нічого не рахує — fallback-у на базовий прохід немає. **P2.**

**Мертва секція `WindowsUpdate`.** Top-level `Report.WindowsUpdate` оголошена в моделі з дефолтами, жоден модуль її не пише і не читає, але вона потрапляє в кожен JSON і в `SCHEMA.md` як «легасі». **P3.**

**Дрібніше, але підтверджене кодом (P3):**

- `Software.Installed` мовчки викидає все, що містить `Update` у назві (`-notlike '*Update*'`): «Microsoft Update Health Tools», агенти «... Update Service» тощо; `SCHEMA.md` при цьому обіцяє «повний список, без штучного обрізання»;
- на Windows Server немає `root\SecurityCenter2` → `Antivirus.Product = ''` без `Status`/`Error`, невідрізнимо від «антивірус не встановлено»;
- TLS 1.0/1.1, увімкнені через `Enabled = 0xFFFFFFFF` (патерн IIS Crypto), не флагуються — WARNING вимагає рівно `1`;
- TXT/MD summary друкує `Uptime: 3d 75.5h` — `UptimeHours` це **загальні** години (`Round(TotalHours,1)`), а не залишок після днів;
- `AuditPolicy.Subcategories[].Category` заповнюється з колонки `Policy Target` (завжди `System`), а не з категорії аудиту;
- `Processes/Connections`: результат `Select-Object -First 200` з одним елементом стає скаляром, а не масивом, у JSON.

### Правдоподібні (потребують прогону)

- offline/read-only диски → CRITICAL: false positive на кластерах і SAN з `OfflineShared` (P2);
- `auditpol` з локалізованими заголовками CSV → `$null`-поля при `Status='Detected'` (P2);
- TPM під `-NoElevate`: `UnauthorizedAccessException` → `NotPresent` замість `Unavailable` (P2);
- RDP WARNING «відкрито для будь-якої адреси» не спрацьовує, коли профіль вбудованого правила — `Any` (P2);
- Windows 10 22H2 → `EndOfSupport` CRITICAL з текстом «оновлень безпеки більше немає» — хибно для машин з ESU (P3);
- PowerShell 7 детектується лише через MSI-ключ реєстру; MSIX/Store/zip-інсталяції — «не встановлено» (P3);
- будь-яке pending security-оновлення → CRITICAL незалежно від віку; `MaxAgeDays` рахується, але не впливає на severity (P3, калібрування);
- непривілейований запуск реєструє очікувані відмови як `CollectionErrors` → exit 1 на кожному `-NoElevate`-прогоні (P2/P3, семантика).

---

## 9. Privacy і `-Sanitize`: гарантія, яка ще не виконується повністю

`-Sanitize` — це обіцянка: `docs/SECURITY.md` каже «для передачі третім сторонам використовувати `-Sanitize`». Тому кожне поле, яке проходить повз маскер, — не косметика, а порушення контракту.

### Що маскується (Basic)

```text
ComputerName (+ Dashboard, Network.General.Hostname)
Meta.UserName, Meta.UserDomainName
ComputerSystem.Domain, Network.General.Domain
DNS suffix (Routing + per-adapter)
PublicIPv4
MAC-адреси
серійні номери: BIOS, RAM, PhysicalDisks, Storage Deep, Monitors, Motherboard
LocalAdmins, RDP AllowedUsers
Services.AutomaticStopped[].StartName (крім LocalSystem / NT AUTHORITY\*)
Software.Installed[].InstallLocation
Autoruns[].Command, ScheduledTasks[].Author
SMB share paths
Report.OutputPath
```

Strict додає приватні IPv4/gateway/DNS/listening ports/adapter IPs і `REDACTED-GEOIP` для ISP/Org/ASN/Country/Region/City/Timezone.

### Що НЕ маскується (підтверджено в коді release-гілки)

```text
Report.GeneratedFiles[]                      сирі шляхи C:\Users\<user>\... після будь-якого ExportError
Network.WinHttpProxy.RawOutput               proxy hostname + bypass list із внутрішнім доменом (JSON + HTML)
Updates.Installed.Recent[].InstalledBy       CORP\jdoe        JSON + HTML "Installed by"
Updates.WindowsUpdate.WSUSServer             http://wsus.corp.local:8530   JSON + HTML
EventLogs.TopErrorSources[].LastMessage      сирий текст подій (акаунти, хости, IP)
EventLogs.LogSummaries[].TopProviders[].LastMessage
EventLogs.HardwareDiagnostics[].LastMessage
HTML footer                                  $OutputDir (сирий параметр, не Report.OutputPath)
Health.Findings[].Message, CollectionErrors[].Message
                                             будуються з сирих значень ДО маскування
Basic: PublicIPv4ISP/Organization/ASN/City   маскуються лише у Strict, хоча IP уже замаскований
консольний вивід                             реальні LAN IP, ISP, шлях — у transcript/CI-логах
```

Три з цих пунктів бот Codex позначив як P1 **на фінальному SHA** PR #85 через десять хвилин після merge PR #87. PR body при цьому стверджує «No confirmed P0/P1 release blockers remain» і відносить event messages до «P2/P3 backlog».

Додатково (P2, підтверджено кодом): навіть у Strict лишаються `Security.RemoteAccess.FirewallScope` (дозволені підмережі RDP) і, правдоподібно, `ScheduledTasks[].Name/Path` з SID-ами користувачів у назвах per-user задач; а **жоден формат не позначає, що звіт санітизований і на якому рівні** — `Meta` не має `Sanitized`/`SanitizeLevel`, рівень лише друкується в консоль. Отримувач не може відрізнити замаскований звіт від сирого інакше, ніж помітивши токени `REDACTED-*`, а sentinel-тест не має чого перевіряти.

Для інструмента, чиї звіти явно призначені для передачі назовні, це P1: у `Security`-журналі текст події регулярно містить `Account Name`, `Workstation Name`, `Source Network Address`; `GeneratedFiles` — ім'я Windows-користувача оператора; `WinHttpProxy` — внутрішній домен.

### Структурна причина

Див. розділ 4: sanitizer — ручний deny-list без coverage-інваріанта. Тест `Sanitize.Tests.ps1` перевіряє точкові поля, а `ExecutionContract.Tests.ps1` свідомо **не** робить повнотекстовий скан на `$env:USERNAME`, бо `OutputPath` «легітимно не маскується» — коментар із версії до v0.6.1, який тепер описує саме той витік, що існує.

Правильна модель для safe-sharing:

```text
policy manifest: кожен string-leaf моделі має клас (USER / HOST / DOMAIN / IP / SERIAL / PATH / FREETEXT / SAFE)
   +
generic masker за manifest-ом, FREETEXT у Strict — pattern-masking (DOMAIN\user, hostname, IPv4)
   +
leakage sentinel test: після -Sanitize JSON/HTML/TXT/MD/CSV не містять
   $env:COMPUTERNAME, $env:USERNAME, $env:USERDOMAIN, реального DNS suffix,
   жодного рядка з Security-журналу, жодного шляху C:\Users\<name>
   +
документація з точним переліком: що маскується, що видаляється, що лишається
```

### Мережева поведінка за замовчуванням

Default профіль — `Forensic`. У Full/Deep/Forensic інструмент звертається до `api.ipify.org` / `checkip.amazonaws.com` / `ifconfig.me` і далі відправляє отриману публічну адресу на `ipapi.co`, якщо не задано `-SkipGeoIP` або `-Offline`. Жоден із чотирьох `.bat`-лаунчерів цих прапорців не передає. Тобто подвійний клік по `BRAVO-SystemReport-Forensic.bat` на сервері замовника без жодного попередження робить два зовнішні запити, один із яких — до стороннього GeoIP-сервісу.

Це задокументовано і має вимикачі, але для аудиторського інструмента opt-in (`-GeoIP`) був би безпечнішим дефолтом, ніж opt-out. **P2.**

---

## 10. Security engineering

### Що добре

- інструмент **read-only**: жодного запису в реєстр/служби/файли поза `OutputPath` (принцип у `AI_RULES.md` п.8 — підтверджено grep-ом по `src/`);
- жодних паролів/токенів/cookies не збирається;
- HTML проходить через `ConvertTo-BravoHtmlText`, прогрес-бари — через `Get-BravoSafePercentText` з InvariantCulture, `CatalogUrl` — через allow-list `^https://`;
- JSON пишеться без BOM (`UTF8Encoding($false)`), що сумісно з RFC 8259 парсерами;
- CI сканує tracked files на випадкові публічні IPv4-літерали, GitGuardian — на секрети;
- COM-обʼєкти Windows Update звільняються через `Marshal.ReleaseComObject`.

### Self-hosted runner у публічному репозиторії

Це найсерйозніша security-проблема delivery chain.

```text
runs-on: [self-hosted, Windows, X64, bravo-system-report]
on: pull_request: branches: [main, developer, release/**]
```

GitHub прямо рекомендує **не використовувати self-hosted runners для публічних репозиторіїв**: PR із fork виконує код PR на runner-і. Тут runner:

- працює як **Administrator** (це друкується в public-логах разом із `ComputerName`, `UserName`, `UserDomain`, а крок «Validate latest JSON» друкує ще й LAN-адресу `PrimaryIPv4`);
- виконує `Build-BRAVO-SystemReport.ps1` і запускає зібраний `dist` з PR у профілях Quick/Full/Deep — тобто довільний PowerShell-код із PR під адміністратором;
- у workflow немає guard-умови `if: github.event.pull_request.head.repo.full_name == github.repository`.

Дефолтна політика GitHub «approval for first-time contributors» знижує, але не усуває ризик, і не є частиною репозиторію.

Мінімальний фікс (один рядок на job):

```yaml
if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository
```

Правильна модель:

```text
hosted windows-latest (PowerShell 5.1)  ← усі PR, у т.ч. з fork
self-hosted runner                       ← лише push у developer/release/**, workflow_dispatch, tags
runner на ізольованій VM без персональних даних, зі snapshot
```

**Пріоритет: P1** (реальна exposure, а не теоретична).

### Supply chain

- `Install-Module Pester -MinimumVersion 5.0.0` і `powershell-yaml` без pinned версії і без hash — build залежить від того, що PSGallery віддає сьогодні;
- `actions/checkout@v4`, `actions/upload-artifact@v4` — tag, не SHA; у логах уже є попередження про Node 20 deprecation;
- `release.yml` має `permissions: contents: write` і публікує через REST з `GITHUB_TOKEN` — коректно обмежено tag-push і dispatch.

Пріоритет **P3**, не блокер.

### Email

`Send-MailMessage` — cmdlet, який Microsoft офіційно позначив obsolete (без гарантій TLS). Для внутрішнього SMTP relay достатньо, для зовнішнього — ні. Default `-EmailFrom` = `systemaudit@<COMPUTERNAME>.local` — реальне ім'я машини в заголовку листа навіть при `-Sanitize`. Задокументувати обмеження і не розширювати.

---

## 11. CI

CI зроблений під проєкт, а не скопійований із шаблону. Це помітно.

### Що перевіряє `local-windows-validation.yml`

```text
git diff --check
build modular monolith
SHA512 (fresh build)
dist reproducibility (fresh vs HEAD, нормалізований GeneratedAt)
contract change guard (20-ReportModel → SchemaVersion + CHANGELOG)
parser check dist
Pester (24 файли)
Quick runtime + JSON validation (CollectionErrors=0)
Full runtime + Updates validation (реальний онлайн-пошук оновлень)
Public IPv4 literal scan
Deep runtime (CSV + Zip)
Exit code contract (forced SMTP failure → exit 1)
```

Особливо правильно:

- `shell: powershell`, а не `pwsh` — тест на реальному Windows PowerShell 5.1;
- `WorkflowEncoding.Tests.ps1` як regression-guard проти non-ASCII у `run:` кроках (self-hosted runner читає temp-скрипт в ANSI) — проєкт зловив цей клас багу і закрив його тестом;
- CI реально ловив дефекти: run #95/#96 (перша реалізація reproducibility-check), падіння CollectionErrors на VM без `LoadPercentage`, `Network.PrimaryIPv4` замість `Network.IP.*` у самому CI.

### Сліпі зони

1. **Порядок кроків**: build перезаписує `dist` і `.sha512`, після чого «Verify SHA512» звіряє два щойно згенеровані файли. Закомічений `.sha512` не перевіряється (виправлено лише в гілці поза PR).
2. **Contract guard обходиться**: колектор може почати писати нове поле в наявну секцію без зміни `20-ReportModel.ps1` — guard дивиться лише на diff цього файлу. `docs/SCHEMA.md` чесно пише, що «правило ширше», але CI цього не бачить.
3. **Hosted job = pwsh 7 на ubuntu**: parser check проходить у PowerShell 7, який приймає `??`, `?.`, ternary — синтаксис, заборонений `AI_RULES.md` для 5.1. Hosted job не може зловити саме той клас помилок, заради якого існує правило.
4. **Один runner** = single point of failure для всіх PR: run #91 завис на Pester-кроці 13 хвилин без діагностики; job без `timeout-minutes`, без `concurrency`, без path-фільтрів.
5. **Public IPv4 scan** з regex на 4 октети зловить `Version = 10.0.19045.4046`-подібні рядки (PR body сам згадує false positives).

### Цільова матриця

```text
hosted-static      ubuntu-latest, pwsh        парсер, маніфест, docs invariants, version/CHANGELOG    ~1 хв, кожен PR
hosted-unit        windows-latest, powershell  T0–T2 Pester (чисті функції, mocks), 5.1-парність      ~3 хв, кожен PR (у т.ч. fork)
selfhosted-runtime BRAVO-SYSTEM-REPORT-WIN     T3–T4: Quick/Full/Deep, updates, exit codes, package    push developer/release/**, dispatch
release            self-hosted                 tag v*                                                   як зараз
```

`hosted-unit` на `windows-latest` дає Windows PowerShell 5.1 без self-hosted машини — і саме там мають жити всі 14 файлів чистих unit-тестів.

---

## 12. Release artifact і release governance

Задекларована модель:

```text
feature/fix/docs/test
        ↓
    developer
        ↓
  release/vX.Y.Z-stable
        ↓
   незалежне ревю
        ↓
      main
        ↓
   tag vX.Y.Z → GitHub Release
```

Що реалізовано механічно:

- `release.yml` при push тега `v*` звіряє `$ScriptVersion` у `src/90-Main.ps1`, перший заголовок `## vX.Y.Z` у `CHANGELOG.md` і назву тега — розбіжність зупиняє реліз;
- пакет розпаковується і перевіряється **саме як пакет** (файли, SHA512 runtime, parser, версія) — це правильна гарантія «published ZIP works», а не лише «repository passes tests»;
- ручний `workflow_dispatch` = dry run без публікації; `publish_release=true` створює тег через GitHub API.

Що НЕ забезпечено механічно:

- branch protection відсутня (див. розділ 2);
- «незалежне ревю release SHA» — це той самий автор + бот; 25 тредів бота на PR #85 жоден не resolved;
- зворотний sync `release → developer` не описаний і не виконаний;
- release notes = усе від `## v0.6.1` до наступного `## ` заголовка, тобто зараз **≈610 рядків** CHANGELOG (усі `###` за місяць розробки) стануть текстом одного релізу.

---

## 13. Тестова система: сильна, але вже потребує архітектури

24 файли Pester 5, ≈229 `It`-блоків, 223 проходять на runner-і. Для PowerShell-проєкту такого віку це дуже добре: є regression-тести на кожен клас минулих багів (locale, wrapper contract, exit codes, sanitize, manifest, workflow encoding, release package).

### Tier-модель (фактична)

```text
T0 Static      SourceParserCheck, Manifest, ParameterSurface, WorkflowEncoding, DocsSchema
T1 Unit        Core, FindingsGrouped, StorageThresholds, HardwareThresholds, UacPromptText,
               TlsProtocolStatus, WmiMonitorCharArray, NetAccountsParsing, RegistryKeyProperties,
               EventLogSummary, RdpGroupResolution, ProcessNameLookup
T2 Component   RuntimeCollectors (10 mocks), SecurityPureFunctions (4), Sanitize (31 It, 1 mock)
T3 Integration ExecutionContract (≈20 наскрізних запусків wrapper: Quick/Full/Deep/Forensic),
               EndToEnd, EdgePdfExport
T4 Acceptance  ReleasePackage (розпакування + Quick.bat), Deep runtime у CI
```

### Проблеми

- **ExecutionContract.Tests.ps1 — 870 рядків, 17 Describe, ≈20 запусків runtime.** Кожен Describe запускає wrapper заново замість спільної fixture. Full/Deep-прогін — хвилини і реальний WMI/Event Log. Звідси 14 хвилин на job і тиск «не запускати повний набір локально».
- **Тихі `-Skip`**: за відсутності `dist`, Edge, `powershell-yaml`, admin-прав тести пропускаються без сигналу. `WorkflowEncoding` уже один раз skip-ався на кожному прогоні непомітно, поки це не знайшли.
- **Sanitize leakage sentinel не покриває саме ті поля, що витекли**: `GeneratedFiles`, `WinHttpProxy`, `InstalledBy`, `WSUSServer`, `LastMessage`, footer. Тест перевіряє точкові поля, а не негативний скан усього виводу.
- **Core helpers не тестуються напряму**: `Add-AuditError`/`Add-AuditFinding`/`Get-AuditObject` живуть у `90-Main.ps1`, який не можна dot-source-нути без запуску аудиту, тому `RuntimeCollectors.Tests` і `StorageThresholds.Tests` оголошують власні stub-версії цих функцій.
- **Немає unit-тестів для ризикової чистої логіки**: класифікація партицій (зʼявляється лише в гілці поза PR — 117 рядків тестів), вибір exit code, серіалізація аргументів elevation, lifecycle lookup за build/edition, акумуляція routing-списків (розділ 8).
- Повний набір запускається лише на self-hosted runner; hosted CI — 2 файли з 24.

### Рекомендація

```text
FAST GATE (hosted windows-latest, 5.1)   T0–T2, < 3 хв, кожен PR
FULL (self-hosted)                        T3–T4, спільна fixture: ОДИН Full -Offline прогін
                                          → JSON у BeforeAll контейнера → усі Describe читають його
ACCEPTANCE                                Deep/Forensic, реальні updates, release package
```

плюс `-Tag Unit|Integration|Acceptance` на Describe і `Invoke-Pester -Tag` у workflow. Кількість тестів не зменшувати.

---

## 14. Real-machine validation: один runner — не acceptance-матриця

Фактичне acceptance-середовище — одна машина `BRAVO-SYSTEM-REPORT-WIN` (одна ОС, одна локаль, admin, з інтернетом, один адаптер). Саме тому найцінніші дефекти v0.6.1 знайшов не CI, а читання коду:

```text
LevelDisplayName локалізований       → нульові лічильники подій на не-англійській Windows
'Remote Desktop Users' літерал        → порожній AllowedUsers на локалізованій системі
auditpol CSV headers                  → null-поля при Status='Detected'
Confirm-SecureBootUEFI без прав       → 'NotSupported' замість 'Unavailable'
MBR WinRE (0x27)                      → false CRITICAL на legacy-BIOS
два адаптери зі шлюзами               → склеєні рядки замість списку (розділ 8)
Security log Level=0                  → завжди 0/0/0
```

Жоден із цих сценаріїв runner не відтворює: він англомовний, UEFI, elevated, з одним шлюзом.

Мінімальна reference-матриця для acceptance:

```text
Windows Server 2019/2022 EN, UEFI, admin        (є — runner)
Windows 10/11 uk-UA або ru-RU                   (локалізація)
legacy BIOS / MBR VM                            (storage classification)
multi-homed VM (2 адаптери, 2 шлюзи)            (routing)
non-admin run (-NoElevate)                      (permission semantics)
WSUS-managed / offline VM                       (Updates + -Offline)
```

Не обовʼязково як runners: acceptance package → оператор запускає → JSON-звіт кожної машини прикріплюється до release PR як evidence. Інструмент уже генерує саме такий JSON.

---

## 15. Активний PR #85 — зараз НЕ merge

Це головний практичний висновок ревю.

```text
state = open
mergeable_state = clean
checks = green
```

`mergeable_state = clean` означає лише «немає конфліктів і checks зелені». Воно не означає «готовий».

Факти:

1. **25 review threads, 0 resolved.** Частина закрита кодом (PR #87), але жоден не dispositioned у самому PR.
2. **Чотири P1 бота на фінальному SHA не закриті**: `InstalledBy`, `WSUSServer`, HTML footer, event `LastMessage`. Це витік у режимі, який проєкт рекламує як безпечний для третіх сторін.
3. **Це ревю додає ще три P1**: `GeneratedFiles` у повторно записаному JSON (розділ 4), `WinHttpProxy.RawOutput`, і зіпсовані routing-списки на multi-homed хостах (розділ 8).
4. **Один P2 закритий як «NOT APPLICABLE» помилково**: scheduled tasks збираються у `Full`, бо блок стоїть поза `if ($Profile -in @('Deep','Forensic'))` (рядок 646 закривається на 704, блок tasks починається на 709 у тому самому зовнішньому `Full/Deep/Forensic`-гейті з рядка 279).
5. **Автор уже має гілку з «acceptance-review fixes»** (`fix/v061-storage-ci-integrity`) для трьох дефектів RC: false CRITICAL на MBR WinRE (+ exit 4 у `-Strict`), незвірений закомічений `.sha512`, footer. Вона створена після фінального SHA і не має PR — тобто RC відомо-дефектний, а PR цього не відображає.
6. PR body: «No confirmed P0/P1 release blockers remain» — на момент написання правда лише щодо тредів, які встигли переглянути до 17:33.

### Merge gate

```text
[BLOCK] PR у release: fix/v061-storage-ci-integrity (MBR WinRE, committed sha512, footer, OutputEncoding)
[BLOCK] Sanitize: GeneratedFiles, WinHttpProxy.RawOutput, InstalledBy, WSUSServer, EventLogs.*LastMessage —
        маскувати або вирізати під -Sanitize; export-етапи не мутують модель після маскування
[BLOCK] Routing.DefaultGateways/DNSServers/DNSSuffixSearchOrder — акумуляція масивів без scalar-unwrap + unit-тест
[BLOCK] elevation relaunch: -Sanitize (і решта switch-ів) не губляться при -OutputPath із кінцевим \ + E2E-тест relaunch-у
[BLOCK] Meta.Sanitized / Meta.SanitizeLevel у моделі — щоб отримувач і sentinel-тест бачили, що звіт замасковано
[BLOCK] Sanitize leakage sentinel: негативний скан JSON/HTML/TXT/MD на реальні hostname/user/domain/
        DNS suffix/Security-текст/C:\Users\<name>, у т.ч. у сценарії з ExportError
[BLOCK] SECURITY.md/README: точний перелік того, що -Sanitize маскує і НЕ маскує
[BLOCK] усі 25 тредів dispositioned (fixed / wontfix з причиною / follow-up Issue)
[BLOCK] scheduled tasks: або гейт Deep/Forensic, або виправити коментар і docs (одне з двох)
[BLOCK] повний CI + Pester на новому SHA; локальний Full/Deep/Forensic -Sanitize -SanitizeLevel Strict
[SHOULD] branch protection на main і developer ДО merge
[SHOULD] Security-log summary (Level 0), Defender 'Passive Mode', Size=0-томи, HTML RESERVED
[SHOULD] TPM access-denied → 'Unavailable'; auditpol позиційний розбір
[SHOULD] CHANGELOG: окремі ## v0.5.1 / v0.6.0 / v0.6.1 замість одного розділу на 610 рядків
[NICE]   Launcher.bat без BOM; .gitignore для txt/md/pdf; CPU — усі сокети
```

### Шлях до mergeable RC

```text
1. PR A: fix/v061-storage-ci-integrity → release/v0.6.1-stable
2. PR B: sanitize gaps + snapshot після маскування + sentinel + routing fix + docs → release
3. CI зелений на новому SHA; disposition тредів у #85; оновити PR body
4. merge #85 → main; tag v0.6.1 через release.yml (dry run спочатку)
5. ТОГО Ж ДНЯ: merge main → developer (developer не має 9+ комітів release-гілки)
6. release/v0.6.1-stable видалити або заморозити; наступний цикл — v0.6.2/v0.7.0 у developer
```

### Ризик merge «як є» сьогодні

Stable-реліз, який (а) в advertised safe-режимі віддає доменні акаунти, тексти Security-журналу, внутрішній proxy і шлях профілю оператора, (б) при запуску без прав адміністратора зі шляхом із кінцевим `\` мовчки скидає `-Sanitize`, (в) на legacy-BIOS парку ставить CRITICAL здоровим машинам і повертає exit 4 у `-Strict`, (г) на серверах із двома шлюзами показує склеєні адреси замість маршрутизації, (д) публікується з release notes на 610 рядків.

---

## 16. Інші unresolved findings (P2)

### TPM під `-NoElevate`

Загальний `catch` для `root\cimv2\Security\MicrosoftTpm` записує `Present=false`, `Status='NotPresent'` і на `UnauthorizedAccessException`. Той самий клас, що вже виправлено для Secure Boot (`Unavailable`). **P2.**

### `auditpol /r` на локалізованій Windows

`ConvertFrom-Csv` створює властивості з локалізованими назвами колонок; звернення до `'Policy Target'`, `'Subcategory GUID'`, `'Inclusion Setting'` дають `$null` при `Status='Detected'` і `TotalCount > 0`. Розбирати позиційно або мапити за фактичними заголовками. Додатково: поле `Category` заповнюється з колонки `Policy Target` (завжди `System`), а не з категорії аудиту. **P2.**

### Scheduled tasks у `Full`

Див. розділ 15. **P2** (сотні записів, час і розмір звіту всупереч контракту профілю). Політика профілів узагалі розкидана по 16 `if ($Profile -in ...)` у 9 файлах без єдиної матриці — саме тому такий дефект не має де бути спійманим.

### Профільно-залежна форма JSON

`Hardware.Disks.Deep` і `Hardware.Disks.StorageRisk` існують лише в Deep/Forensic; споживач JSON для Quick/Full отримує інший набір ключів при тому самому `SchemaVersion`. Або оголосити секції в моделі з порожніми дефолтами, або зафіксувати в `SCHEMA.md` як умовні. **P2.**

### `Core7LatestKnown`: два джерела істини

```text
src/20-ReportModel.ps1:          Core7LatestKnown = '7.4'
src/39b-Collectors-Runtime.ps1:  $latestKnownCore7 = '7.6.5'
```

Модель показує один default, колектор перезаписує іншим. Одна константа в одному місці, з датою актуалізації, як уже зроблено для lifecycle-таблиці. **P3.**

### Hard-coded reference data

Lifecycle-таблиця Windows, `7.6.5`, матриця .NET 4.8.1 (у якій, правдоподібно, бракує 19044/22000) — усе оновлюється вручну. Потрібен один release-checklist пункт «звірити reference data» з датою в JSON-звіті (для lifecycle це вже є: `LifecycleDataUpdatedAt`). **P3.**

---

## 17. Гілка `fix/v061-storage-ci-integrity` — тріаж обовʼязковий

```text
5cc7948  fix: harden storage partition classification and dist integrity
9 files, +396/−13, 03.09 21:11
```

Зміст:

- CI: перевірка закоміченого `.sha512` ДО build; `[Console]::OutputEncoding = UTF8` перед `git show` (OEM-кодова сторінка руйнувала кирилицю в порівнянні);
- Storage: `Resolve-BravoPartitionType` (GPT GUID → MBR 0x27 → IsSystem → Type → Unknown), fallback-кореляція том↔партиція за `AccessPaths`/літерою, INFO-знахідка `Storage.UnknownVolume`;
- HTML footer через `Report.OutputPath`;
- +117 рядків `StorageThresholds.Tests`, +9 `ExecutionContract.Tests`, CHANGELOG, ARCHITECTURE (exit codes 0–5).

Оцінка: це саме той наступний інкремент RC, якого бракує PR #85. Зміни локальні, покриті тестами, без нових параметрів. Її потрібно провести через PR у `release/v0.6.1-stable` **до** merge #85, а не після. Гілка без PR через кілька тижнів стане «археологічним квестом» — той самий ризик, який у проєкті вже був із PR #44 (там disposition «superseded by #45» зафіксовано коментарем — це правильна практика, її треба повторити).

---

## 18. Документація: обсяг чудовий, drift уже почався

Обсяг документації для проєкту такого розміру видатний: `AI_RULES.md`, `ARCHITECTURE.md`, `IMPLEMENTATION_PLAN.md`, `PROJECT_RULES.md`, `RELEASE.md`, `ROADMAP.md`, `SCHEMA.md`, `SECURITY.md`, README на 500 рядків, CHANGELOG на 143 KB.

Але конкретні твердження вже суперечать коду release-гілки.

### `docs/ARCHITECTURE.md`

```text
"Маскування чутливих даних через -Sanitize — заплановане, ще не реалізоване"
```

`-Sanitize` існує з v0.4.3 і є частиною release-blocker fixes v0.6.1.

```text
"детермінований exit code (0/1/2/3)"
```

Фактичний контракт — `0/1/2/3/4/5`. Перелік секцій `$script:Report` у документі не містить `Meta`, `Dashboard`, `Updates`, `Virtualization`, `GeneratedFiles`, `Status`. Документ каже, що helper-и живуть у `10-Core.ps1`; фактично `Add-AuditError`/`Add-AuditFinding`/`Get-AuditObject` — у `90-Main.ps1`, а BIOS збирається inline в оркестраторі без власного `Get-BravoBiosAudit`.

### `README.md`

```text
"Поточна стабільна версія: ScriptVersion 0.6.1"
```

Stable `main` — 0.5.0; `docs/ROADMAP.md` у тому самому дереві каже «Current stable (main): 0.5.0; Release candidate 0.6.1». Причина зрозуміла: hosted CI вимагає, щоб README згадував поточний `ScriptVersion`, і формулювання «стабільна» випереджає реальність.

Дерево «Структура проєкту»: `tests/` показує 3 файли (є 24), у `src/` немає `39a`, `45`, `55`, `56`, у `docs/` немає `RELEASE.md` і `SCHEMA.md`, вступ досі каже «JSON/HTML/CSV/ZIP» (є TXT/MD/PDF).

### `docs/ROADMAP.md`

```text
"service account names — не реалізовано: колектор служб не збирає StartName"
"Відоме обмеження: ім'я файлу звіту містить реальне ім'я машини"
```

Обидва пункти закриті у v0.6.1 (`StartName` збирається і маскується; ім'я файлу маскується). Сам ROADMAP містить mutable-блок «Поточний статус», який застаріває з кожним merge.

### `docs/SCHEMA.md`

```text
"GeneratedFiles — шляхи всіх фактично створених файлів (JSON/HTML/CSV/ZIP/PDF) — джерело для ZIP-пакування"
```

У кожному **успішному** прогоні `GeneratedFiles` у JSON — порожній масив: JSON пишеться першим, а його шлях додається вже після серіалізації. Поле заповнюється лише тоді, коли стався ExportError і JSON перезаписано (див. розділ 4). Тобто семантика поля залежить від того, чи була помилка. `Installed[]` описаний як «повний список без обрізання», хоча колектор відкидає все з `Update` у назві.

### `docs/SECURITY.md`

```text
"Для цього проекту рекомендовано приватний репозиторій"
```

Репозиторій публічний. Процесу disclosure (Security Advisory / приватний контакт) немає. Документ також обіцяє маскування «для передачі третім сторонам», не згадуючи жодної з прогалин sanitizer-а з розділу 9.

### `CHANGELOG.md`

```text
рядок   1: ## v0.6.1 — 2026-09-03
рядок 612: ## v0.5.0 — ...
рядок 655: ## Unreleased — Forensic ZIP default та Storage Deep Inventory v2
```

Заголовок «Unreleased» нижче за випущену версію — stale. Усе між v0.5.0 і v0.6.1 (Stabilization P0, Deep Inventory, v0.6.0 Reports, v0.6.1 UI, CI gates, п'ять раундів код-ревю) живе як `###` під одним `## v0.6.1`.

### Правила проти практики

`docs/PROJECT_RULES.md` і `docs/AI_RULES.md` обидва вимагають commit messages українською. Фактично:

```text
main..release:       34 з 74 заголовків комітів без кирилиці
developer з v0.5.0:  25 з 65
```

`AI_RULES.md` п.9 забороняє додавати нові параметри, вкладки HTML і файли експорту без явного запиту — за один цикл додано `-TXT`, `-MD`, `-ExportPdf`, `-Strict`, `-Offline`, `-SkipGeoIP`, `-Sanitize`, `-SanitizeLevel`. Правило або треба переформулювати як «лише за узгодженим завданням», або визнати, що воно не діє.

---

## 19. Документація повинна перевірятись CI

CI уже перевіряє `ScriptVersion`/`SchemaVersion` у README і ROADMAP. Цього замало — саме ця перевірка і породила формулювання «стабільна версія 0.6.1» у README.

Достатньо 10–20 lightweight invariants:

```text
docs/ARCHITECTURE.md   не містить "ще не реалізоване" поряд із "-Sanitize"
docs/ARCHITECTURE.md   перелік exit codes == перелік у src/90-Main.ps1
docs/SECURITY.md       не містить "рекомендовано приватний репозиторій"
docs/SECURITY.md       містить розділ про disclosure
docs/SECURITY.md       містить перелік "НЕ маскується"
README.md              кожен параметр із src/05-Params.ps1 згаданий у README
README.md              дерево структури містить кожен файл src/*.ps1, tests/*.ps1 і docs/*.md
README.md              "стабільна версія" == ScriptVersion на main (тег), не на гілці
docs/SCHEMA.md         кожен top-level ключ New-BravoReportModel описаний
docs/ROADMAP.md        не містить "не реалізовано" для функцій, що є в src
CHANGELOG.md           жоден "## Unreleased" не стоїть нижче "## vX.Y.Z"
CHANGELOG.md           перший "## vX.Y.Z" == ScriptVersion (уже є в release.yml — перенести в PR-gate)
docs/RELEASE.md        назви кроків == назви кроків release.yml
*.bat                  без UTF-8 BOM
src/*.ps1              з UTF-8 BOM (є .editorconfig, немає перевірки)
src/45-Sanitize.ps1    кожен string-leaf моделі має policy (див. розділ 4)
git log (PR)           commit subject містить кирилицю — або прибрати правило
```

---

## 20. Version provenance

`ScriptVersion = 0.6.1` однаковий на `developer` і на `release/v0.6.1-stable`. `dist` має лише `GeneratedAt`, без commit SHA. Тобто скопійований на production `developer`-checkout **невідрізнимий** від release candidate ані за версією, ані за заголовком runtime, ані за JSON-звітом.

Рекомендація:

```text
dist header:   SourceCommit: <sha>   SourceBranch: <ref>   Channel: dev|rc|stable
JSON Meta:     SourceCommit, Channel
console:       "0.6.1 (dev, 32a691a)" vs "0.6.1 (rc, 3db337e)"
```

і stamp через build при release, а не вручну.

---

## 21. Гігієна репозиторію та правила форматування

### Кодування

`.editorconfig` вимагає CRLF для всіх файлів і UTF-8 BOM для `.ps1`; `.gitattributes` при цьому примусово ставить LF для `*.md`, `*.yml`, `*.json` і взагалі не згадує `.bat`. Фактичний стан release-гілки:

```text
src/30-Collectors-OS.ps1            без BOM        (порушує .editorconfig і AI_RULES п.5)
BRAVO-SystemReport-Launcher.bat     З BOM          (EF BB BF перед @echo off)
BRAVO-SystemReport-*.bat (усі 5)    LF у git
CHANGELOG.md, docs/RELEASE.md,
docs/PROJECT_RULES.md               з BOM          (.editorconfig: .md без BOM)
.gitignore, src/BRAVO.build.json,
local-windows-validation.yml        з BOM
```

BOM у `.bat` — не косметика: `cmd.exe` не пропускає BOM, перший рядок читається як `п»ї@echo off` і дає `'п»ї@echo' is not recognized...`, а `echo off` не застосовується. `tests/ReleasePackage.Tests.ps1` перевіряє лише наявність усіх пʼяти `.bat` у пакеті і виконує тільки `Quick.bat`; Launcher (єдиний файл із BOM) ніколи не запускається жодним тестом.

### Спадок

```text
patch/APPLY-v0.2.0-stabilization.ps1
patch/files/src/Get-BravoSystemReport.ps1     50 KB старий моноліт
patch/v0.2.0-stabilization.patch
review/v0.2.0-*.md
tools/Publish-ToGitHub.ps1                    git add . ; commit ; gh repo create --push
```

Це артефакти червня 2026; вони потрапляють у README-дерево, у grep, у parser-перевірки і вводять в оману. `Publish-ToGitHub.ps1` при випадковому запуску робить `git add .` на все дерево, включно зі згенерованими звітами, якщо `.gitignore` їх не ловить.

### `.gitignore`

Ігнорує `BravoSystemReport_*.{json,html,csv,zip,sha512}`, але не `.txt`, `.md`, `.pdf` — три нові формати v0.6.x. Sanitize-звіт, TXT summary чи PDF можуть потрапити у `git add .`.

### Гілки

На origin накопичились merged/abandoned гілки: `bravo/*` (4), `claude/*`, `fix/v061-release-blockers`. Автовидалення merged branches + явний список винятків (`main`, `developer`, активна `release/*`).

### Ліцензія

`LICENSE.md` — «All rights reserved, no part may be copied», репозиторій при цьому публічний із дозволеним fork. Або приватний репозиторій, або ліцензія, яка відповідає публічності.

---

## 22. GitHub Issues не використовуються

Відомого боргу вже багато, і він живе у PR body (#85 має список із 10 P2/P3), у `ROADMAP.md` (50 KB), у CHANGELOG-абзацах «свідомо не виправлено», у коментарях коду. Це працює, поки одна людина памʼятає контекст, але вже зараз:

- 4 P1-треди бота на фінальному SHA PR #85 не мають жодного трекінгу;
- `fix/v061-storage-ci-integrity` існує лише як гілка;
- дублікати боргу між README «Відомі технічні борги», ROADMAP «Технічний борг» і PR body.

Мінімальна модель:

```text
Issue
  type: bug | tech-debt | privacy
  severity: P1/P2/P3
  component: collector/export/ci/docs
  found by: codex review / acceptance / self-review / external review
  acceptance criteria
```

ROADMAP тоді лише агрегує посилання.

---

## 23. Що НЕ рекомендується зараз

Не варто:

- переписувати на PowerShell 7 — цільовий парк це Windows PowerShell 5.1, і проєкт уже ловив семантичні різниці 5.1/7;
- дробити `src/` на десятки мікромодулів або переходити на `.psm1`-модулі заради форми — проблема не в кількості файлів, а в policy boundaries усередині `51-Export-Html` і `34-Security`;
- замінювати власний Pester-набір на інший фреймворк;
- вимикати self-hosted runner «бо небезпечно» без заміни — він єдине місце, де тестується реальний WMI/CIM/Event Log/Windows Update;
- робити big-bang рефакторинг `$script:Report` у класи — модель працює, і всі 24 тестові файли на неї спираються;
- відкладати merge PR #85 «до ідеального стану» — потрібен короткий, чітко обмежений список блокерів (розділ 15), а не ще один місяць у release-гілці.

Поточна проблема — не мова і не стек, а **розрив між задекларованими гарантіями (safe sharing, «no blockers», required checks) і тим, що механічно перевіряється**.

---

## 24. Пріоритетний backlog після ревю

| Priority | Задача | Чому |
|---|---|---|
| **P1** | PR #85: не merge без закриття sanitize-витоків (`GeneratedFiles`, `WinHttpProxy`, `InstalledBy`, `WSUSServer`, `LastMessage`, footer) | Порушення advertised safe-sharing |
| **P1** | Export-етапи не мутують модель після `-Sanitize`; runtime-state винести з `$script:Report` | Корінь витоку `GeneratedFiles` |
| **P1** | Routing-списки на multi-homed hosts (scalar-unwrap при акумуляції) + unit-тест | Неправильний результат аудиту |
| **P1** | Провести `fix/v061-storage-ci-integrity` через PR у release | MBR WinRE false CRITICAL, committed sha512, footer |
| **P1** | Self-hosted runner: guard `head.repo == repository` або hosted `windows-latest` для PR | Виконання коду fork-PR під адміністратором |
| **P1** | Elevation relaunch: серіалізація параметрів без ручного рядка (файл/EncodedCommand) + E2E-тест relaunch-у | `-OutputPath D:\audit\` мовчки губить `-Sanitize` і пише сирий звіт |
| **P1** | `SECURITY.md`: публічний репозиторій, disclosure, точний перелік «не маскується» | Документ обіцяє більше, ніж є |
| **P2** | Sanitize leakage sentinel (негативний скан усіх форматів, у т.ч. з ExportError) | Той самий клас багу пʼять разів за цикл |
| **P2** | Policy manifest для sanitizer + тест «кожен string-leaf має policy» | Deny-list завжди відстає |
| **P2** | Security-log summary (Level 0/Keywords), Defender `'Passive Mode'`, Size=0-томи, HTML RESERVED, CPU всі сокети, lockout `Never`, Kernel-Power подвійний облік | Коректність findings |
| **P2** | Scheduled tasks гейт + єдина матриця capabilities профілів | Контракт профілю |
| **P2** | Branch protection `main`/`developer`; sync `release → developer` після merge | Процес без механічного забезпечення |
| **P2** | CI: committed `.sha512` до build; contract guard на рівні моделі, а не файлу; hosted `windows-latest` (5.1) для T0–T2 | Сліпі зони |
| **P2** | Тести: спільна fixture для E2E, `-Tag`, видимі skip-и, тести для helper-ів (винести з `90-Main`) | 14 хв на job, тихі пропуски |
| **P2** | Docs invariants у CI; актуалізувати ARCHITECTURE/README/ROADMAP; CHANGELOG за версіями | Drift уже є |
| **P2** | Розділити `34-Security` і `51-Export-Html` по policy boundaries; helper-и HTML — один раз | Файли на 55–95 KB |
| **P2** | `Meta.Sanitized`/`Meta.SanitizeLevel` у моделі; `GeneratedFiles` — або завжди заповнений, або поза контрактом | Отримувач не бачить, чи звіт замаскований; семантика поля залежить від помилки |
| **P2** | GeoIP opt-in замість opt-out (або `-SkipGeoIP` у `.bat`) | Зовнішній запит за замовчуванням |
| **P2** | Deep/Forensic: fallback на базові free-space findings, якщо `Get-Volume` впав | Мовчазна втрата всіх storage-findings |
| **P3** | Launcher.bat без BOM; `30-Collectors-OS.ps1` з BOM; `.gitignore` txt/md/pdf; `.editorconfig` ↔ `.gitattributes` | Гігієна |
| **P3** | Детермінований build (без wall-clock timestamp) + `SourceCommit`/`Channel` у dist і JSON | Provenance |
| **P3** | Pinned Pester/powershell-yaml, SHA-pinned actions | Supply chain |
| **P3** | `patch/`, `review/v0.2.0-*`, `Publish-ToGitHub.ps1` → архів або видалення; merged branches | Спадок |
| **P3** | Issues для боргу; disposition для кожного треду бота | Трекінг |
| **P3** | Мертва секція `WindowsUpdate`; `Core7LatestKnown` один раз; reference data у release-checklist | Контракт |
| **P3** | TXT/MD uptime (`3d 75.5h`), фільтр `*Update*` у Software, `Antivirus.Status` на Server, TLS `0xFFFFFFFF`, Edge без timeout | Дрібні дефекти виводу і findings |

---

## 25. Рекомендована архітектура наступного етапу

Не потрібен BRAVO SYSTEM REPORT 2.0.

Логічний розвиток 0.7.x:

```text
                 Get-BravoSystemReport.ps1 / *.bat
                              │
                              ▼
                     ┌────────────────────┐
                     │   RuntimeContext   │  Profile, Caps (матриця), OutputDir,
                     │                    │  Offline/SkipGeoIP/..., GeneratedFiles
                     └─────────┬──────────┘
                               │
            ┌──────────────────┼──────────────────┐
            ▼                  ▼                  ▼
       Collectors          Health            Sanitize (policy manifest)
     Get-Bravo*Audit    Update-Bravo...      generic masker + coverage test
            │                  │                  │
            └──────────────────┼──────────────────┘
                               ▼
                    $script:Report (frozen snapshot)
                               │
              ┌────────┬───────┼───────┬────────┐
              ▼        ▼       ▼       ▼        ▼
            JSON     HTML    TXT/MD   CSV    ZIP/Email
         (читають, не пишуть; шляхи — у RuntimeContext)
```

Ключова зміна:

```text
модель = контракт + runtime-state + sanitize target
```

поступово стає:

```text
модель = тільки контракт; runtime-state — окремо; sanitize — за policy manifest
```

Плюс:

- `Get-BravoProfileCapabilities -Profile` замість 16 розкиданих `if ($Profile -in ...)`;
- core helper-и в `10-Core.ps1`, dot-source-able для тестів;
- один Full-прогін як спільна fixture для інтеграційних тестів;
- hosted `windows-latest` job на 5.1 для T0–T2.

---

## 26. Що в проєкті вже добре і не треба ламати

- **Windows PowerShell 5.1 як target** і CI саме на 5.1;
- **один `$script:Report`** для всіх форматів;
- **одне джерело дефолтів** параметрів і transparent wrapper;
- **`CollectionErrors` ≠ `ExportErrors`** і Health Score як властивість машини, а не інструмента;
- **exit code contract** 0–5 і `-Strict`;
- **fail-closed `-Sanitize`**, детерміновані маскери з однаковими токенами між секціями, безпечне ім'я файлу;
- **read-only audit** як інваріант;
- **locale-independence** там, де вже виправлено (SID, `Level`, `CategoryID`, `FullyQualifiedErrorId`, позиційний `net accounts`);
- **thresholds як єдине джерело** для колекторів, dashboard і HTML;
- **Windows Update COM у background job** з таймаутом і cleanup;
- **release package перевіряється як пакет** (розпакування, SHA512, parser, версія, запуск `Quick.bat`);
- **manifest ↔ src** і **parameter surface** як regression-guards;
- **чесний ROADMAP/CHANGELOG** із записами «свідомо не виправлено» і «не підтверджено».

---

## 27. Підсумковий verdict

BRAVO SYSTEM REPORT зараз знаходиться приблизно тут:

```text
Скрипт
   │
   ├── уже пройдено
   ▼
Інструмент з профілями і звітами
   │
   ├── уже пройдено
   ▼
Інструмент з контрактами (execution, exit code, schema, sanitize)
   │
   ├── ВИ ТУТ
   ▼
Інструмент, чиї контракти перевіряються механічно
```

Основні класи ризику для аудиторського інструмента — коректність findings, безпека передачі звітів, цілісність артефакту, відтворюваність релізу — уже покриті набагато краще, ніж у типовому PowerShell automation repository.

Але наступна межа росту вже чітко видна:

> **Проєкт декларує більше гарантій, ніж перевіряє.**

Тому для 0.6.1/0.7.x варто поставити фокус не на нові колектори, а на три напрямки:

```text
1. Закрити safe-sharing контракт: -Sanitize маскує все або чесно каже, що ні.
2. Зробити гарантії механічними: branch protection, sentinel-тести, docs invariants, committed-dist check.
3. Розділити модель і runtime-state, щоб наступний export не породив наступний витік.
```

Якщо ці три речі довести до кінця, BRAVO SYSTEM REPORT цілком можна довести приблизно до **8.5/10 production-grade audit tool** без переписування на іншу мову чи радикальної зміни стеку.
