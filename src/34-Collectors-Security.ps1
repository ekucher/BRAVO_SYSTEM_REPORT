# MODULE: 34-Collectors-Security.ps1
# Збір інформації про UAC, RDP, антивірус, Windows Firewall, Secure Boot, TPM,
# SMBv1 та TLS registry status.

# Чиста функція: інтерпретує пару SCHANNEL registry DWORD (Enabled,
# DisabledByDefault — HKLM:\...\SecurityProviders\SCHANNEL\Protocols\<protocol>\<Client|Server>)
# у людяний статус. Семантика за документацією Microsoft:
# - обидва ключі відсутні -> адміністратор нічого не налаштовував, діє
#   вбудований дефолт ОС (залежить від версії Windows) -> 'NotConfigured';
# - Enabled=0 -> явно вимкнено, незалежно від DisabledByDefault;
# - DisabledByDefault=1 (і Enabled не 0) -> вимкнено за замовчуванням;
# - інакше (Enabled=1 або відсутній, DisabledByDefault=0 або відсутній) ->
#   явно чи неявно увімкнено -> 'Enabled'.
function Get-BravoTlsProtocolStatus {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [Nullable[int]]$Enabled,
        [AllowNull()]
        [Nullable[int]]$DisabledByDefault
    )

    if ($null -eq $Enabled -and $null -eq $DisabledByDefault) { return 'NotConfigured' }
    if ($null -ne $Enabled -and $Enabled -eq 0) { return 'Disabled' }
    if ($null -ne $DisabledByDefault -and $DisabledByDefault -eq 1) { return 'Disabled' }
    return 'Enabled'
}

function Get-BravoSecurityAudit {
    [CmdletBinding()]
    param()

    # --- Безпека ---
    try {
        # Важливо: WARNING/INFO-знахідки нижче генеруються лише якщо ключ реєстру
        # реально вдалось прочитати. Якщо $uac/$rdp -eq $null (немає прав, GPO,
        # Server Core), стан невідомий — це НЕ те саме, що "підтверджено вимкнено",
        # і не повинно ставати хибним WARNING на дефолтному значенні моделі.
        $uac = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction SilentlyContinue
        if ($uac) {
            $script:Report.Security.UAC.Enabled = ($uac.EnableLUA -eq 1)

            if (-not $script:Report.Security.UAC.Enabled) {
                Add-AuditFinding -Severity 'WARNING' -Category 'Security' -Message 'UAC вимкнено.' -Recommendation 'Увімкніть UAC, якщо немає обґрунтованого винятку.'
            }
        } else {
            Add-AuditError -Section 'Security.UAC' -Message 'Не вдалося прочитати ключ реєстру EnableLUA — стан UAC невідомий.'
        }

        $rdp = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -ErrorAction SilentlyContinue
        if ($rdp) {
            $script:Report.Security.RemoteAccess.RDPEnabled = ($rdp.fDenyTSConnections -eq 0)

            if ($script:Report.Security.RemoteAccess.RDPEnabled) {
                Add-AuditFinding -Severity 'INFO' -Category 'RemoteAccess' -Message 'RDP увімкнено.' -Recommendation 'Перевірте NLA, firewall scope і список дозволених користувачів.'
            }
        } else {
            Add-AuditError -Section 'Security.RemoteAccess' -Message 'Не вдалося прочитати ключ реєстру fDenyTSConnections — стан RDP невідомий.'
        }

        try {
            $antivirusInfo = Get-WmiObject -Namespace 'root\SecurityCenter2' -Class 'AntiVirusProduct' -ErrorAction SilentlyContinue
            if ($antivirusInfo) { $script:Report.Security.Antivirus.Product = (($antivirusInfo | Select-Object -ExpandProperty displayName) -join '; ') }
        } catch {
            Add-AuditError -Section 'Security.Antivirus' -Message $_.Exception.Message
        }

        if (Get-Command Get-NetFirewallProfile -ErrorAction SilentlyContinue) {
            try {
                $firewallProfiles = Get-NetFirewallProfile -ErrorAction Stop
                foreach ($profileInfo in $firewallProfiles) {
                    $script:Report.Security.Firewall[$profileInfo.Name] = [ordered]@{
                        Enabled = $profileInfo.Enabled
                        DefaultInboundAction = $profileInfo.DefaultInboundAction.ToString()
                        DefaultOutboundAction = $profileInfo.DefaultOutboundAction.ToString()
                    }

                    if (-not $profileInfo.Enabled) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Firewall' -Message "Firewall-профіль $($profileInfo.Name) вимкнено." -Recommendation 'Перевірте політику Windows Firewall.'
                    }
                }
            } catch {
                Add-AuditError -Section 'Security.Firewall' -Message $_.Exception.Message
            }
        }

        # --- Secure Boot / TPM (Deep Security, v0.5.0) ---
        # Гейтовано Full/Deep/Forensic: не критично для Quick-профілю, і на
        # частині машин (VM без vTPM, Legacy BIOS) обидва запити стабільно
        # "не підтримується" — щоб не подовжувати найшвидший профіль зайвими
        # WMI/cmdlet-викликами без цінності.
        if ($Profile -in @('Full','Deep','Forensic')) {
            try {
                $secureBootEnabled = Confirm-SecureBootUEFI -ErrorAction Stop
                $script:Report.Security.SecureBoot.Supported = $true
                $script:Report.Security.SecureBoot.Enabled = [bool]$secureBootEnabled
                $script:Report.Security.SecureBoot.Status = if ($secureBootEnabled) { 'Enabled' } else { 'Disabled' }

                if (-not $secureBootEnabled) {
                    Add-AuditFinding -Severity 'WARNING' -Category 'Security.SecureBoot' -Message 'Secure Boot підтримується, але вимкнено.' -Recommendation 'Увімкніть Secure Boot у UEFI/BIOS, якщо немає обґрунтованого винятку (dual-boot з несумісною ОС, специфічне обладнання).'
                }
            } catch {
                # Confirm-SecureBootUEFI кидає виняток і на Legacy BIOS (немає
                # UEFI — Secure Boot фізично неможливий), і на частині VM —
                # це штатний стан машини, не помилка збору (Add-AuditError
                # НЕ викликається, щоб не давати хибний exit code 1 на кожній
                # Legacy BIOS/VM-машині).
                $script:Report.Security.SecureBoot.Supported = $false
                $script:Report.Security.SecureBoot.Status = 'NotSupported'
                $script:Report.Security.SecureBoot.Error = $_.Exception.Message
            }

            try {
                $tpmInfo = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' -ClassName 'Win32_Tpm' -ErrorAction Stop | Select-Object -First 1

                if ($tpmInfo) {
                    $script:Report.Security.TPM.Present = $true
                    $script:Report.Security.TPM.Enabled = [bool]$tpmInfo.IsEnabled_InitialValue
                    $script:Report.Security.TPM.Activated = [bool]$tpmInfo.IsActivated_InitialValue
                    $script:Report.Security.TPM.Ready = $script:Report.Security.TPM.Enabled -and $script:Report.Security.TPM.Activated
                    $script:Report.Security.TPM.ManufacturerId = [string]$tpmInfo.ManufacturerId
                    $script:Report.Security.TPM.ManufacturerVersion = [string]$tpmInfo.ManufacturerVersion
                    $script:Report.Security.TPM.SpecVersion = [string]$tpmInfo.SpecVersion
                    $script:Report.Security.TPM.Status = 'Detected'

                    if (-not $script:Report.Security.TPM.Ready) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.TPM' -Message 'TPM присутній, але не увімкнений/не активований повністю.' -Recommendation 'Увімкніть і активуйте TPM у UEFI/BIOS — потрібен для BitLocker, Windows Hello, Credential Guard.'
                    }
                } else {
                    $script:Report.Security.TPM.Present = $false
                    $script:Report.Security.TPM.Status = 'NotPresent'
                }
            } catch {
                # Клас Win32_Tpm/namespace відсутній — типово означає відсутність
                # фізичного/firmware TPM (старе обладнання, VM без vTPM), не
                # помилка збору (та сама логіка, що й для Secure Boot вище).
                $script:Report.Security.TPM.Present = $false
                $script:Report.Security.TPM.Status = 'NotPresent'
                $script:Report.Security.TPM.Error = $_.Exception.Message
            }

            # --- SMBv1 ---
            if (Get-Command Get-SmbServerConfiguration -ErrorAction SilentlyContinue) {
                try {
                    $smbConfig = Get-SmbServerConfiguration -ErrorAction Stop
                    $script:Report.Security.SMBv1.Enabled = [bool]$smbConfig.EnableSMB1Protocol
                    $script:Report.Security.SMBv1.Status = if ($smbConfig.EnableSMB1Protocol) { 'Enabled' } else { 'Disabled' }

                    if ($smbConfig.EnableSMB1Protocol) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.SMBv1' -Message 'SMBv1 увімкнено — застарілий, вразливий протокол (EternalBlue/WannaCry).' -Recommendation 'Вимкніть SMBv1: Set-SmbServerConfiguration -EnableSMB1Protocol $false, якщо немає застарілих пристроїв, що вимагають саме SMBv1.'
                    }
                } catch {
                    Add-AuditError -Section 'Security.SMBv1' -Message $_.Exception.Message
                }
            } else {
                # Get-SmbServerConfiguration відсутній (застарілий Windows без
                # модуля SmbShare) — штатний стан, не помилка збору.
                $script:Report.Security.SMBv1.Status = 'NotAvailable'
            }

            # --- TLS registry status ---
            $tlsProtocolNames = @('TLS 1.0', 'TLS 1.1', 'TLS 1.2', 'TLS 1.3')
            foreach ($tlsProtocolName in $tlsProtocolNames) {
                foreach ($tlsSide in @('Client', 'Server')) {
                    $tlsRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$tlsProtocolName\$tlsSide"
                    $tlsProperties = Get-ItemProperty -Path $tlsRegistryPath -ErrorAction SilentlyContinue

                    $tlsEnabledValue = if ($tlsProperties -and $null -ne $tlsProperties.Enabled) { [int]$tlsProperties.Enabled } else { $null }
                    $tlsDisabledByDefaultValue = if ($tlsProperties -and $null -ne $tlsProperties.DisabledByDefault) { [int]$tlsProperties.DisabledByDefault } else { $null }
                    $tlsStatus = Get-BravoTlsProtocolStatus -Enabled $tlsEnabledValue -DisabledByDefault $tlsDisabledByDefaultValue

                    $script:Report.Security.TLS.Protocols += [PSCustomObject]@{
                        Protocol           = $tlsProtocolName
                        Side               = $tlsSide
                        Enabled            = $tlsEnabledValue
                        DisabledByDefault  = $tlsDisabledByDefaultValue
                        Status             = $tlsStatus
                    }

                    # Застарілі протоколи (1.0/1.1) явно увімкнені реєстром —
                    # адміністратор свідомо переозначив ОС-дефолт у бік менш
                    # безпечного стану. TLS 1.2 явно вимкнений — навпаки,
                    # ризик сумісності (більшість сучасних клієнтів/серверів
                    # вимагають мінімум 1.2). 'NotConfigured' (найпоширеніший
                    # стан на реальних машинах — ОС-дефолт) НЕ породжує
                    # finding: адмін нічого не змінював, немає що звинувачувати.
                    if ($tlsProtocolName -in @('TLS 1.0', 'TLS 1.1') -and $tlsStatus -eq 'Enabled' -and $tlsEnabledValue -eq 1) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.TLS' -Message "$tlsProtocolName ($tlsSide) явно увімкнено через реєстр — застарілий протокол." -Recommendation 'Вимкніть застарілі TLS-версії через SCHANNEL registry, якщо немає застарілих клієнтів/серверів, що вимагають саме цю версію.'
                    } elseif ($tlsProtocolName -eq 'TLS 1.2' -and $tlsStatus -eq 'Disabled') {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.TLS' -Message "TLS 1.2 ($tlsSide) вимкнено через реєстр — ризик сумісності з сучасними клієнтами/серверами." -Recommendation 'Перевірте, чи це свідоме рішення; TLS 1.2 зазвичай мінімально необхідна версія для сучасних з''єднань.'
                    }
                }
            }

            Write-Host "  $IconSecurity Secure Boot: $($script:Report.Security.SecureBoot.Status), TPM: $($script:Report.Security.TPM.Status), SMBv1: $($script:Report.Security.SMBv1.Status)" -ForegroundColor Green
        }

        Write-Host "  $IconSecurity Безпека: RDP=$(if($script:Report.Security.RemoteAccess.RDPEnabled){'ON'}else{'OFF'}), UAC=$(if($script:Report.Security.UAC.Enabled){'ON'}else{'OFF'})" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Security' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка даних безпеки: $($_.Exception.Message)" -ForegroundColor Red
    }
}
