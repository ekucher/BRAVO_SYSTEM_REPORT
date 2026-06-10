# Roadmap BRAVO SYSTEM REPORT

## Етап 1. Стабілізація базового скрипта

- [ ] Перейменувати службові змінні іконок: `$cpu`, `$disk`, `$ram` → `$IconCpu`, `$IconDisk`, `$IconRam`.
- [ ] Додати `$StartTime` на початку виконання.
- [ ] Додати `$Report.Meta`, `$Report.Summary`, `$Report.Health`, `$Report.CollectionErrors`.
- [ ] Замінити порожні `catch {}` на `Add-AuditError`.
- [ ] Додати параметр `-OutputPath`.
- [ ] Додати параметр `-NoOpenFolder`.
- [ ] Винести генерацію JSON/HTML/CSV/ZIP у функції.
- [ ] Уточнити сумісність: Windows PowerShell 5.1+ як основний режим, Legacy fallback окремо.

## Етап 2. Профілі аудиту

- [ ] `-Profile Quick` — базовий аудит.
- [ ] `-Profile Full` — повний адміністративний звіт.
- [ ] `-Profile Deep` — розширений аудит журналів, мережі, служб, security baseline.
- [ ] `-Profile Forensic` — глибокий збір діагностичних артефактів без збору секретів.

## Етап 3. Hardware Inventory

- [ ] ComputerSystem: vendor, model, domain/workgroup, chassis type.
- [ ] BIOS/UEFI: version, release date, serial number.
- [ ] Secure Boot.
- [ ] TPM.
- [ ] CPU: socket, cores, logical processors, max clock.
- [ ] RAM modules: slot, vendor, serial, speed, size.
- [ ] Motherboard.
- [ ] GPU.
- [ ] Monitors.

## Етап 4. Storage Audit

- [ ] Physical disks: model, serial, size, media type, health.
- [ ] Volumes: drive letter, filesystem, total/free/used.
- [ ] BitLocker status.
- [ ] Pagefile.
- [ ] Shadow Copies.
- [ ] Storage Spaces.
- [ ] Findings для низького вільного місця.

## Етап 5. Network Audit

- [ ] Network adapters: name, MAC, speed, status, driver.
- [ ] IP/DNS/Gateway/DHCP/static.
- [ ] Routing table.
- [ ] ARP table.
- [ ] Listening ports with process name.
- [ ] Established connections.
- [ ] Firewall profiles.
- [ ] WinHTTP proxy.
- [ ] SMB shares.

## Етап 6. Security Baseline

- [ ] Defender/AV status.
- [ ] Firewall status.
- [ ] UAC full policy.
- [ ] RDP: enabled, NLA, port, allowed users.
- [ ] WinRM listeners and auth.
- [ ] SMBv1.
- [ ] TLS 1.0/1.1/1.2/1.3 registry status.
- [ ] Local users and local admins via SID `S-1-5-32-544`.
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

- [ ] JSON — повні структуровані дані.
- [ ] HTML — красивий інтерактивний звіт.
- [ ] CSV — коротка інвентаризація.
- [ ] TXT — короткий summary.
- [ ] Markdown — для Redmine/GitHub.
- [ ] ZIP — повний пакет.
- [ ] `-Sanitize` — маскування чутливих даних.

## Етап 9. Health Score

- [ ] Score 0–100.
- [ ] Severity: Critical, Warning, Info, Passed.
- [ ] Рекомендації для кожного finding.
- [ ] Підсумкова оцінка: OK / WARNING / CRITICAL.
