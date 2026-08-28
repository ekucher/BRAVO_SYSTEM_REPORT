# План впровадження доробок BRAVO SYSTEM REPORT

## Мета документа

Цей документ фіксує практичний план доробок після глибокого аналізу репозиторію.

План орієнтований на поетапне доведення BRAVO SYSTEM REPORT до стабільного release-ready стану:

- релізний пакет має запускатися без ручних доробок;
- документація має відповідати фактичній архітектурі;
- звіти мають бути безпечними для передачі третім сторонам;
- Deep і Forensic профілі мають давати справді глибоку діагностику;
- CI має ловити регресії до merge/release.

## Поточна база

Уже реалізовано:

- модульна архітектура `src/*.ps1`;
- build у `dist/Get-BravoSystemReport.ps1`;
- SHA512 для runtime;
- root wrapper `Get-BravoSystemReport.ps1`;
- BAT-запускачі Quick/Full/Deep/Forensic/Launcher;
- JSON/HTML/CSV/ZIP export;
- Email export;
- Health Score;
- Storage Deep Audit skeleton;
- Storage Critical Findings;
- Local Windows Validation workflow.

## Ключові ризики

### 1. Release package може бути неповним

Root wrapper запускає `dist/Get-BravoSystemReport.ps1`, тому release package повинен містити `dist`.

Поточний release script має бути перевірений і виправлений так, щоб у release ZIP точно потрапляли:

```text
dist/Get-BravoSystemReport.ps1
dist/Get-BravoSystemReport.ps1.sha512
```

### 2. Старий моноліт у `src/Get-BravoSystemReport.ps1` — ВИРІШЕНО

Файл видалено. Актуальний runtime — виключно `dist/Get-BravoSystemReport.ps1`, зібраний з `src/*.ps1` через `Build-BRAVO-SystemReport.ps1`; `powershell-static-check.yml` більше не перевіряє наявність старого моноліту.

### 3. Health Score не враховує export errors — ВИРІШЕНО

`Update-BravoHealthScore` (`src/40-Health.ps1`) викликається вдруге в `src/90-Main.ps1` після export-етапів (JSON/HTML/CSV); JSON і HTML перегенеровуються з фінальною оцінкою, але лише якщо export-етапи додали нові `CollectionErrors` (щоб не дублювати дорогий HTML-рендер без потреби).

### 4. Немає безпечного режиму передачі звітів

Звіти можуть містити:

- computer name;
- user name;
- domain/workgroup;
- DNS suffix;
- IP addresses;
- MAC addresses;
- serial numbers;
- local administrators;
- service account names;
- installed software paths;
- фрагменти event logs.

Потрібен `-Sanitize`.

## Етап 1. Release Stabilization

### Ціль

Зробити так, щоб release ZIP був самодостатнім і запускався після розпакування.

### Задачі

- [ ] Оновити `tools/New-ReleasePackage.ps1`.
- [ ] Додати у package include list:
  - [ ] `dist/Get-BravoSystemReport.ps1`;
  - [ ] `dist/Get-BravoSystemReport.ps1.sha512`.
- [ ] Перевірити, що package не включає сформовані звіти з `reports/`.
- [ ] Перевірити, що package не включає sensitive artifacts.
- [ ] Додати локальний тест release package:
  - [ ] build runtime;
  - [ ] create release ZIP;
  - [ ] unpack to temp;
  - [ ] run `BRAVO-SystemReport-Quick.bat --nopause`;
  - [ ] validate JSON;
  - [ ] validate HTML;
  - [ ] validate exit code.
- [ ] Описати процес у `docs/RELEASE.md`.

### Acceptance criteria

- Release ZIP містить `dist/Get-BravoSystemReport.ps1`.
- Root wrapper запускається з розпакованого ZIP.
- BAT Quick запускається з розпакованого ZIP.
- Створюються JSON і HTML.
- `CollectionErrors=0` у Quick smoke test.
- Немає sensitive generated reports у package.

## Етап 2. Legacy Cleanup

### Ціль

Прибрати плутанину між старим монолітом і новим модульним runtime.

### Задачі

- [x] Перевірити, чи використовується `src/Get-BravoSystemReport.ps1` — не редагувався з переходу на модульну архітектуру, реального використання не було.
- [x] Видалено після review (`git rm`), `legacy/`-перенесення визнано зайвим — уся історія доступна в git log.
- [x] Оновити README (дерево структури, борги, плани розвитку).
- [x] Оновити CHANGELOG.

### Acceptance criteria

- [x] У документації є один основний runtime flow: root wrapper → `dist/Get-BravoSystemReport.ps1`.
- [x] У release package немає старого моноліту.
- [x] Немає розбіжності між README, CHANGELOG, ROADMAP і фактичним запуском.

## Етап 3. Runtime Quality

### Ціль

Зробити runtime behavior передбачуваним і зручним для автоматизації.

### Задачі

- [ ] Додати повторний `Update-BravoHealthScore` після export-етапів.
- [ ] Або створити окрему секцію:

```text
Health.Collection
Health.Export
Health.Overall
```

- [ ] Додати `-Strict`.
- [ ] Додати контроль exit code:
  - [ ] `0` — успішно;
  - [ ] `1` — runtime failure;
  - [ ] `2` — collection errors у strict mode;
  - [ ] `3` — export errors;
  - [ ] `4` — validation failed.
- [ ] Уніфікувати network schema.
- [ ] Уніфікувати storage thresholds.
- [ ] HTML-encode всі динамічні значення.

### Acceptance criteria

- Export errors впливають на фінальний статус.
- CI може перевіряти exit code.
- JSON schema не дублює одні й ті самі network values у різних місцях без потреби.
- HTML не вставляє сирі значення без encoding.

## Етап 4. Safe Sharing / Sanitize

### Ціль

Дозволити безпечну передачу звітів третім сторонам.

### Нові параметри

```powershell
-Sanitize
-SanitizeLevel Basic|Strict
-SkipPublicIP
-Offline
```

### Basic sanitize

Маскувати:

- public IPv4;
- MAC addresses;
- serial numbers;
- local administrators;
- user name;
- computer name;
- domain/workgroup.

### Strict sanitize

Додатково маскувати:

- private IPv4;
- DNS suffix;
- service account names;
- install locations;
- event log messages, якщо вони містять імена/шляхи/IP.

### Acceptance criteria

- `-Sanitize` не ламає JSON structure.
- HTML/CSV/ZIP також містять sanitized values.
- У CI є regex scan на IP/MAC/serial/user/domain literals.
- `-Offline` не виконує зовнішні HTTPS-запити.
- `-SkipPublicIP` пропускає public IP detection без помилки.

## Етап 5. Hardware Deep Inventory

### Ціль

Розширити hardware audit до рівня повної інвентаризації.

### Задачі

- [ ] Secure Boot.
- [ ] TPM.
- [ ] Motherboard.
- [ ] GPU.
- [ ] Monitors.
- [ ] Chassis type.
- [ ] CPU socket.

### Джерела даних

- `Confirm-SecureBootUEFI`, якщо доступно;
- `Get-Tpm`, якщо доступно;
- `Win32_BaseBoard`;
- `Win32_VideoController`;
- `WmiMonitorID`, якщо доступно;
- `Win32_SystemEnclosure`;
- `Win32_Processor`.

### Acceptance criteria

- Quick не стає важким.
- Deep/Forensic збирають розширені hardware дані.
- Якщо cmdlet/class недоступні, додається collection warning/error без падіння всього скрипта.

## Етап 6. Storage Deep Inventory

### Ціль

Додати діагностику storage, корисну для серверів, VM і робочих станцій.

### Задачі

- [ ] BitLocker status.
- [ ] Pagefile.
- [ ] Shadow Copies / VSS.
- [ ] Storage Spaces.
- [ ] SMART/NVMe health, якщо доступно штатними засобами.
- [ ] Єдині thresholds для всіх storage findings.

### Acceptance criteria

- Storage findings не дублюються.
- Для системного тому є окрема логіка warning threshold.
- У HTML є зрозуміла storage summary.
- У JSON є структуровані storage-секції.

## Етап 7. Network Deep Audit

### Ціль

Зробити network audit придатним для діагностики підключень, портів і мережевих проблем.

### Задачі

- [ ] Adapter speed/status/driver.
- [ ] Routing table.
- [ ] ARP/Neighbor table.
- [ ] Listening ports з ProcessName.
- [ ] Established connections з ProcessName.
- [ ] WinHTTP proxy.
- [ ] SMB shares.
- [ ] DNS suffix/search list.

### Acceptance criteria

- Listening ports показують не тільки PID, а й ProcessName.
- Established connections доступні у Deep/Forensic.
- Public IP detection можна вимкнути.
- Network schema узгоджена між JSON/HTML/CSV.

## Етап 8. Security Baseline

### Ціль

Дати практичну security-картину Windows-машини без збору секретів.

### Задачі

- [ ] UAC full policy.
- [ ] RDP NLA.
- [ ] RDP port.
- [ ] RDP allowed users.
- [ ] WinRM listeners.
- [ ] WinRM auth flags.
- [ ] SMBv1.
- [ ] SMB signing.
- [ ] Insecure guest access.
- [ ] TLS registry baseline.
- [ ] Defender details.
- [ ] Password policy.
- [ ] Audit policy.
- [ ] Autoruns.
- [ ] Scheduled tasks.

### Acceptance criteria

- Findings мають рекомендації.
- Не збираються паролі, токени, cookies, private keys або browser credentials.
- Security data доступні в JSON і коротко відображаються в HTML.

## Етап 9. Updates and Event Diagnostics

### Ціль

Додати діагностику оновлень, pending reboot і ключових event log provider-ів.

### Задачі

- [ ] Installed hotfixes.
- [ ] Pending reboot detection.
- [ ] Windows Update errors.
- [ ] System provider summary.
- [ ] Application provider summary.
- [ ] Setup log summary.
- [ ] Security summary без дампу чутливих подій.
- [ ] Disk/Ntfs/storport diagnostics.
- [ ] WHEA diagnostics.
- [ ] Kernel-Power diagnostics.
- [ ] BugCheck diagnostics.

### Acceptance criteria

- Event log збір не робить Forensic профіль надмірно повільним.
- Є grouping by ProviderName/EventId/Level.
- Є LastSeen/Count.
- Є top recurring errors.

## Етап 10. Reports and Support UX

### Ціль

Зробити звіт зручним для підтримки, Redmine/GitHub і ручного аналізу.

### Задачі

- [ ] TXT summary.
- [ ] Markdown summary.
- [ ] HTML collapsible sections.
- [ ] HTML filters by severity/category.
- [ ] Copy-friendly support summary.
- [ ] JSON schema documentation.
- [ ] Окрема секція `Recommendations`.

### Acceptance criteria

- Markdown можна вставити в Redmine/GitHub без ручного форматування.
- TXT summary можна швидко надіслати у чат підтримки.
- HTML залишається читабельним на великих звітах.

## Етап 11. CI / Quality Gates

### Ціль

Автоматично ловити регресії до merge/release.

### Задачі

- [ ] Parser check для всіх `src/*.ps1`.
- [ ] Quick BAT test.
- [ ] Full runtime test.
- [ ] Deep runtime test з `-CSV -Zip`.
- [ ] Forensic smoke test з `-JSONOnly`.
- [ ] Release package build test.
- [ ] Release package unpack-and-run test.
- [ ] ZIP content validation.
- [ ] HTML generated validation.
- [ ] JSONOnly no HTML validation.
- [ ] Sanitize validation.

### Acceptance criteria

- PR не проходить, якщо build/runtime/JSON validation падає.
- Release package перевіряється до merge.
- CI не друкує public IP value у logs.
- Sensitive generated reports не потрапляють у tracked files.

## Рекомендований порядок реалізації

1. **Release package fix**.
2. **Legacy cleanup**.
3. **CI release package test**.
4. **Health/export status fix**.
5. **Network schema cleanup**.
6. **Storage thresholds cleanup**.
7. **HTML encoding**.
8. **`-Sanitize`, `-SkipPublicIP`, `-Offline`**.
9. **TPM/Secure Boot/BitLocker/Pending Reboot**.
10. **RDP/WinRM/SMB/TLS baseline**.
11. **EventLog provider summary**.
12. **Markdown/TXT summary**.
13. **Full/Deep/Forensic CI coverage**.

## Definition of Done для кожної задачі

Кожна задача вважається завершеною, якщо:

- код або документація оновлені;
- README/ROADMAP/CHANGELOG оновлені, якщо зміна впливає на користувача;
- build проходить;
- parser check проходить;
- runtime smoke test проходить;
- `CollectionErrors` перевірено;
- немає випадково закомічених звітів;
- commit message українською мовою;
- підготовлено короткий review результату.
