# Roadmap BRAVO SYSTEM REPORT

## Етап 1. Стабілізація базового скрипта

- [x] Перейменувати службові змінні іконок: `$cpu`, `$disk`, `$ram` → `$IconCpu`, `$IconDisk`, `$IconRam`.
- [x] Додати `$StartTime` на початку виконання.
- [x] Додати `$Report.Meta`, `$Report.Health`, `$Report.CollectionErrors`.
- [x] Замінити порожні `catch {}` на `Add-AuditError` у ключових секціях.
- [x] Додати параметр `-OutputPath`.
- [x] Додати параметр `-NoOpenFolder`.
- [ ] Винести генерацію JSON/HTML/CSV/ZIP у функції.
- [x] Уточнити сумісність: Windows PowerShell 5.1+ як основний режим, Legacy fallback окремо.

## Етап 2. Профілі аудиту

- [x] `-Profile Quick` — базовий аудит.
- [x] `-Profile Full` — повний адміністративний звіт.
- [x] `-Profile Deep` — розширений аудит журналів, мережі, служб, security baseline.
- [x] `-Profile Forensic` — глибокий збір діагностичних артефактів без збору секретів.

## Етап 3. Hardware Inventory

- [ ] ComputerSystem: vendor, model, domain/workgroup, chassis type.
- [x] BIOS/UEFI: version, release date, serial number.
- [ ] Secure Boot.
- [ ] TPM.
- [~] CPU: базово cores, logical processors, max clock; socket — наступний етап.
- [x] RAM modules: slot, vendor, serial, speed, size.
- [ ] Motherboard.
- [ ] GPU.
- [ ] Monitors.

## Етап 4. Storage Audit

- [~] Physical disks: model, serial, size, media type; health — наступний етап.
- [x] Volumes: drive letter, filesystem, total/free/used.
- [ ] BitLocker status.
- [ ] Pagefile.
- [ ] Shadow Copies.
- [ ] Storage Spaces.
- [x] Findings для низького вільного місця.

## Етап 5. Network Audit

- [ ] Network adapters: name, MAC, speed, status, driver.
- [x] IP/DNS/Gateway/DHCP/static.
- [ ] Routing table.
- [ ] ARP table.
- [~] Listening ports з OwningProcess; мапінг ProcessName — наступний етап.
- [ ] Established connections.
- [x] Firewall profiles.
- [ ] WinHTTP proxy.
- [ ] SMB shares.

## Етап 6. Security Baseline

- [~] Antivirus через SecurityCenter2; Defender details — наступний етап.
- [x] Firewall status.
- [ ] UAC full policy.
- [ ] RDP: enabled, NLA, port, allowed users.
- [ ] WinRM listeners and auth.
- [ ] SMBv1.
- [ ] TLS 1.0/1.1/1.2/1.3 registry status.
- [~] Local admins через SID `S-1-5-32-544`; повні local users — наступний етап.
- [ ] Password policy.
- [ ] Audit policy.
- [ ] Autoruns and scheduled tasks.

## Етап 7. Updates and Event Logs

- [ ] Installed hotfixes.
- [ ] Pending reboot detection.
- [ ] Windows Update errors.
- [ ] Event logs: System, Application, Setup, Security.
- [ ] Provider summary.
- [ ] Critical/Error/Warning grouping.
- [ ] Disk/Ntfs/storport/WHEA/Kernel-Power/BugCheck diagnostics.

## Етап 8. Звіти

- [x] JSON — повні структуровані дані.
- [~] HTML — базовий звіт; інтерактивність — наступний етап.
- [x] CSV — коротка інвентаризація.
- [ ] TXT — короткий summary.
- [ ] Markdown — для Redmine/GitHub.
- [x] ZIP — повний пакет.
- [ ] `-Sanitize` — маскування чутливих даних.

## Етап 9. Health Score

- [x] Score 0–100.
- [~] Severity: Critical, Warning, Info; Passed — наступний етап.
- [x] Рекомендації для кожного finding.
- [x] Підсумкова оцінка: OK / WARNING / CRITICAL.


## Найближчий наступний milestone: v0.3.0 Deep Inventory

- [ ] Додати `-Sanitize`.
- [ ] Додати Secure Boot, TPM, BitLocker, Pending Reboot.
- [ ] Додати RDP NLA/port, WinRM listeners, SMBv1.
- [ ] Додати мапінг listening ports до ProcessName.
- [ ] Додати Application/System provider summary.
- [ ] Винести експорт JSON/HTML/CSV/ZIP у окремі функції.
