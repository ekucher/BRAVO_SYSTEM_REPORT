# MODULE: 34-Collectors-Security.ps1
# Збір інформації про UAC (+full policy), RDP (+NLA/port/firewall scope/
# allowed users), антивірус, Windows Firewall, Secure Boot, TPM, SMBv1, TLS
# registry status, деталі Windows Defender, WinRM (listeners/auth), SMB
# signing, password policy (net accounts), audit policy (auditpol),
# autoruns (Run/RunOnce ключі реєстру + папки автозавантаження) та
# scheduled tasks (Get-ScheduledTask).

# Чиста функція: ConsentPromptBehaviorAdmin DWORD (HKLM:\...\Policies\System)
# -> людяний опис. Значення за документацією Microsoft (UAC group policy
# settings); невідомий код повертається як "Unknown ($code)", не помилка.
function Get-BravoUacAdminPromptText {
    [CmdletBinding()]
    param([AllowNull()][Nullable[int]]$Code)

    switch ($Code) {
        0 { return 'Elevate without prompting' }
        1 { return 'Prompt for credentials on the secure desktop' }
        2 { return 'Prompt for consent on the secure desktop' }
        3 { return 'Prompt for credentials' }
        4 { return 'Prompt for consent' }
        5 { return 'Prompt for consent for non-Windows binaries' }
        $null { return 'Unknown (not set)' }
        default { return "Unknown ($Code)" }
    }
}

# Чиста функція: ConsentPromptBehaviorUser DWORD -> людяний опис.
function Get-BravoUacUserPromptText {
    [CmdletBinding()]
    param([AllowNull()][Nullable[int]]$Code)

    switch ($Code) {
        0 { return 'Automatically deny elevation requests' }
        1 { return 'Prompt for credentials on the secure desktop' }
        3 { return 'Prompt for credentials' }
        $null { return 'Unknown (not set)' }
        default { return "Unknown ($Code)" }
    }
}

# Чиста функція: витягує Name/Value пари з об'єкта, поверненого
# Get-ItemProperty, відкидаючи службові PS*-метавластивості (PSPath/
# PSParentPath/PSChildName/PSDrive/PSProvider), які завжди присутні на
# результаті Get-ItemProperty поряд з реальними значеннями реєстрового
# ключа. Винесено окремо від I/O, щоб покрити unit-тестами без реального
# реєстру.
function ConvertFrom-BravoRegistryKeyProperties {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $PropertiesObject
    )

    $result = @()
    if (-not $PropertiesObject) { return $result }

    foreach ($propName in $PropertiesObject.PSObject.Properties.Name) {
        if ($propName -match '^PS(Path|ParentPath|ChildName|Drive|Provider)$') { continue }
        $result += [PSCustomObject]@{
            Name  = $propName
            Value = [string]$PropertiesObject.$propName
        }
    }

    return $result
}

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

# Чиста функція: парсить вивід `net accounts` за ПОЗИЦІЄЮ рядка, а не за
# текстом мітки. `net.exe` локалізує самі мітки (на не-EN збірках Windows),
# але порядок рядків — фіксований у самому net.exe, не залежить від мовного
# пакета (перевірено на UA-локалізованій машині: значення виводяться у тому
# самому порядку, що документує Microsoft для будь-якої локалі). Той самий
# принцип, що й для RemoteDesktop-UserMode-In-TCP (незалежне від локалізації
# ім'я замість локалізованого DisplayGroup) раніше в цій сесії.
function ConvertFrom-BravoNetAccountsOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines
    )

    $dataLines = @($Lines | Where-Object { $_ -match ':' })

    function Get-BravoNetAccountsValueAt {
        param([int]$Index)
        if ($dataLines.Count -le $Index) { return $null }
        $line = $dataLines[$Index]
        $colonIndex = $line.LastIndexOf(':')
        if ($colonIndex -lt 0) { return $null }
        $value = $line.Substring($colonIndex + 1).Trim()
        if ([string]::IsNullOrWhiteSpace($value)) { return $null }
        return $value
    }

    # Фіксований порядок рядків net accounts (індекс 0 — "Force user logoff...",
    # навмисно не використовується цим колектором):
    return [ordered]@{
        MinPasswordAgeDays               = Get-BravoNetAccountsValueAt 1
        MaxPasswordAgeDays               = Get-BravoNetAccountsValueAt 2
        MinPasswordLength                = Get-BravoNetAccountsValueAt 3
        PasswordHistoryLength            = Get-BravoNetAccountsValueAt 4
        LockoutThreshold                 = Get-BravoNetAccountsValueAt 5
        LockoutDurationMinutes           = Get-BravoNetAccountsValueAt 6
        LockoutObservationWindowMinutes  = Get-BravoNetAccountsValueAt 7
    }
}

# Чиста функція (Release Blocker Fixes v0.6.1): чи потрібен WARNING на
# вимкнений Real-Time Protection. Passive/SxS Passive — свідомий, штатний
# стан Defender, коли активний сторонній антивірус, не сигнал проблеми.
# Винесено окремо для Pester-покриття без запуску Get-BravoSecurityAudit.
function Test-BravoDefenderRealTimeProtectionWarning {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [Nullable[bool]]$RealTimeProtectionEnabled,

        [AllowNull()]
        [string]$AMRunningMode
    )

    return (-not $RealTimeProtectionEnabled) -and ($AMRunningMode -notin @('Passive', 'SxS Passive'))
}

# Чиста-за-даними обгортка над Confirm-SecureBootUEFI (Release Blocker
# Fixes v0.6.1) — винесена окремо, щоб розрізняти access-denied (сесія без
# elevation — не доказ апаратної відсутності Secure Boot) від справжнього
# NotSupported (Legacy BIOS/VM без UEFI), і щоб цю логіку можна було
# перевірити Pester Mock без запуску всього Get-BravoSecurityAudit.
function Get-BravoSecureBootStatus {
    [CmdletBinding()]
    param()

    try {
        $secureBootEnabled = Confirm-SecureBootUEFI -ErrorAction Stop
        return [PSCustomObject]@{
            Supported = $true
            Enabled   = [bool]$secureBootEnabled
            Status    = if ($secureBootEnabled) { 'Enabled' } else { 'Disabled' }
            Error     = ''
        }
    } catch [System.UnauthorizedAccessException] {
        # Access denied — Confirm-SecureBootUEFI вимагає підвищеної
        # (elevated) сесії; це НЕ доказ апаратної відсутності Secure Boot,
        # а лише брак прав у поточному контексті виконання (раніше
        # змішувалось з реальним "NotSupported" — Legacy BIOS/VM).
        return [PSCustomObject]@{
            Supported = $null
            Enabled   = $null
            Status    = 'Unavailable'
            Error     = $_.Exception.Message
        }
    } catch {
        # Будь-який інший виняток (типово System.PlatformNotSupportedException
        # на Legacy BIOS — немає UEFI, Secure Boot фізично неможливий, або
        # аналогічний стан на частині VM) — штатний стан машини.
        return [PSCustomObject]@{
            Supported = $false
            Enabled   = $null
            Status    = 'NotSupported'
            Error     = $_.Exception.Message
        }
    }
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

            # UAC full policy: значення нижче — типово $null, якщо адміністратор
            # ніколи не змінював дефолт групової політики (Windows тоді діє за
            # вбудованим дефолтом ConsentPromptBehaviorAdmin=5/User=3) — це
            # штатний стан, не помилка, публікуємо як є без Add-AuditFinding на
            # "не налаштовано".
            $adminPromptCode = if ($null -ne $uac.ConsentPromptBehaviorAdmin) { [int]$uac.ConsentPromptBehaviorAdmin } else { $null }
            $userPromptCode = if ($null -ne $uac.ConsentPromptBehaviorUser) { [int]$uac.ConsentPromptBehaviorUser } else { $null }
            $script:Report.Security.UAC.ConsentPromptBehaviorAdminCode = $adminPromptCode
            $script:Report.Security.UAC.ConsentPromptBehaviorAdminText = Get-BravoUacAdminPromptText -Code $adminPromptCode
            $script:Report.Security.UAC.ConsentPromptBehaviorUserCode = $userPromptCode
            $script:Report.Security.UAC.ConsentPromptBehaviorUserText = Get-BravoUacUserPromptText -Code $userPromptCode
            $script:Report.Security.UAC.PromptOnSecureDesktop = if ($null -ne $uac.PromptOnSecureDesktop) { [bool]$uac.PromptOnSecureDesktop } else { $null }
            $script:Report.Security.UAC.FilterAdministratorToken = if ($null -ne $uac.FilterAdministratorToken) { [bool]$uac.FilterAdministratorToken } else { $null }

            # Найризикованіша конфігурація UAC для адміністратора — "Elevate
            # without prompting" (код 0): підвищення привілеїв відбувається без
            # жодного запиту, повністю нівелює захист UAC для admin-облікових
            # записів. Значення 1-5 (усі варіанти "Prompt for...") — прийнятні.
            if ($script:Report.Security.UAC.Enabled -and $adminPromptCode -eq 0) {
                Add-AuditFinding -Severity 'WARNING' -Category 'Security.UAC' -Message 'UAC налаштовано на "Elevate without prompting" для адміністраторів (ConsentPromptBehaviorAdmin=0) — підвищення привілеїв без запиту.' -Recommendation 'Змініть ConsentPromptBehaviorAdmin на значення 1-5 (запит підтвердження/облікових даних), якщо немає обґрунтованого винятку.'
            }
        } else {
            Add-AuditError -Section 'Security.UAC' -Message 'Не вдалося прочитати ключ реєстру EnableLUA — стан UAC невідомий.'
        }

        $rdp = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -ErrorAction SilentlyContinue
        if ($rdp) {
            $script:Report.Security.RemoteAccess.RDPEnabled = ($rdp.fDenyTSConnections -eq 0)

            if ($script:Report.Security.RemoteAccess.RDPEnabled) {
                Add-AuditFinding -Severity 'INFO' -Category 'RemoteAccess' -Message 'RDP увімкнено.' -Recommendation 'Деталі NLA/firewall scope/дозволених користувачів — див. Security.RemoteAccess у звіті (Full/Deep/Forensic профілі); окремі WARNING породжуються автоматично, якщо NLA не вимагається або firewall-scope занадто широкий.'
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
            $secureBootResult = Get-BravoSecureBootStatus
            $script:Report.Security.SecureBoot.Supported = $secureBootResult.Supported
            $script:Report.Security.SecureBoot.Enabled = $secureBootResult.Enabled
            $script:Report.Security.SecureBoot.Status = $secureBootResult.Status
            $script:Report.Security.SecureBoot.Error = $secureBootResult.Error

            if ($secureBootResult.Status -eq 'Disabled') {
                # INFO, не WARNING: Secure Boot вимкнений — поширений
                # свідомий вибір (dual-boot, старіше/специфічне обладнання,
                # dev-машини) — не впливає на Health Score/Status, лише
                # фіксується в звіті як факт стану.
                Add-AuditFinding -Severity 'INFO' -Category 'Security.SecureBoot' -Message 'Secure Boot підтримується, але вимкнено.' -Recommendation 'Увімкніть Secure Boot у UEFI/BIOS, якщо немає обґрунтованого винятку (dual-boot з несумісною ОС, специфічне обладнання).'
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

            # --- Defender details ---
            if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
                try {
                    $defenderStatus = Get-MpComputerStatus -ErrorAction Stop

                    $script:Report.Security.Defender.Available = $true
                    $script:Report.Security.Defender.AMServiceEnabled = [bool]$defenderStatus.AMServiceEnabled
                    $script:Report.Security.Defender.AntivirusEnabled = [bool]$defenderStatus.AntivirusEnabled
                    $script:Report.Security.Defender.RealTimeProtectionEnabled = [bool]$defenderStatus.RealTimeProtectionEnabled
                    $script:Report.Security.Defender.BehaviorMonitorEnabled = [bool]$defenderStatus.BehaviorMonitorEnabled
                    $script:Report.Security.Defender.AntivirusSignatureVersion = [string]$defenderStatus.AntivirusSignatureVersion
                    $script:Report.Security.Defender.AMEngineVersion = [string]$defenderStatus.AMEngineVersion
                    $script:Report.Security.Defender.AMProductVersion = [string]$defenderStatus.AMProductVersion
                    # AMRunningMode (Release Blocker Fixes v0.6.1) — 'Normal',
                    # 'Passive' або 'SxS Passive', коли сторонній антивірус
                    # присутній і Defender свідомо працює у пасивному режимі
                    # (RealTimeProtectionEnabled=$false у цьому режимі —
                    # штатний стан, не сигнал проблеми, див. WARNING нижче).
                    $script:Report.Security.Defender.AMRunningMode = [string]$defenderStatus.AMRunningMode
                    $script:Report.Security.Defender.Status = 'Detected'

                    if ($defenderStatus.AntivirusSignatureLastUpdated) {
                        $script:Report.Security.Defender.AntivirusSignatureLastUpdated = $defenderStatus.AntivirusSignatureLastUpdated.ToString('yyyy-MM-dd HH:mm:ss')
                        $script:Report.Security.Defender.AntivirusSignatureAgeDays = [Math]::Round(((Get-Date) - $defenderStatus.AntivirusSignatureLastUpdated).TotalDays)
                    }

                    # RealTimeProtectionEnabled=$false на машині зі стороннім
                    # антивірусом (напр. цей же script:Report.Security.Antivirus.Product
                    # показує інший продукт) — очікуваний, не тривожний стан:
                    # Defender свідомо переходить у passive mode. AMRunningMode
                    # ('Passive'/'SxS Passive') — прямий, авторитетний сигнал
                    # саме цього стану від самого Defender (Release Blocker
                    # Fixes v0.6.1: раніше WARNING спрацьовував безумовно,
                    # даючи хибну тривогу на кожній машині зі стороннім AV).
                    # Не звіряємо з Antivirus.Product (окрема SecurityCenter2-
                    # знахідка) — AMRunningMode надійніший прямий індикатор.
                    if (Test-BravoDefenderRealTimeProtectionWarning -RealTimeProtectionEnabled $script:Report.Security.Defender.RealTimeProtectionEnabled -AMRunningMode $script:Report.Security.Defender.AMRunningMode) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.Defender' -Message 'Windows Defender Real-Time Protection вимкнено.' -Recommendation 'Перевірте, чи це свідоме рішення (напр. активний сторонній антивірус) — якщо ні, увімкніть Real-Time Protection.'
                    }

                    if ($null -ne $script:Report.Security.Defender.AntivirusSignatureAgeDays -and $script:Report.Security.Defender.AntivirusSignatureAgeDays -gt 7) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.Defender' -Message "Сигнатури Windows Defender застарілі: $($script:Report.Security.Defender.AntivirusSignatureAgeDays) днів з останнього оновлення." -Recommendation 'Запустіть оновлення сигнатур антивіруса (Update-MpSignature) та перевірте підключення до Windows Update.'
                    }
                } catch {
                    # Get-MpComputerStatus може падати, коли служба Defender
                    # вимкнена GPO/сторонім антивірусом — штатний стан машини,
                    # не помилка збору.
                    $script:Report.Security.Defender.Available = $false
                    $script:Report.Security.Defender.Status = 'Unavailable'
                    $script:Report.Security.Defender.Error = $_.Exception.Message
                }
            } else {
                $script:Report.Security.Defender.Available = $false
                $script:Report.Security.Defender.Status = 'NotAvailable'
            }

            # --- RDP details: NLA, port, firewall scope, allowed users ---
            if ($script:Report.Security.RemoteAccess.RDPEnabled) {
                try {
                    $rdpTcpConfig = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -ErrorAction SilentlyContinue
                    if ($rdpTcpConfig) {
                        $script:Report.Security.RemoteAccess.NLAEnabled = ($rdpTcpConfig.UserAuthentication -eq 1)
                        $script:Report.Security.RemoteAccess.Port = $rdpTcpConfig.PortNumber

                        if (-not $script:Report.Security.RemoteAccess.NLAEnabled) {
                            Add-AuditFinding -Severity 'WARNING' -Category 'RemoteAccess' -Message 'RDP увімкнено, але Network Level Authentication (NLA) не вимагається.' -Recommendation 'Увімкніть вимогу NLA для RDP (UserAuthentication=1), якщо немає застарілих клієнтів, що не підтримують NLA.'
                        }
                    }
                } catch {
                    Add-AuditError -Section 'Security.RemoteAccess.NLA' -Message $_.Exception.Message
                }

                # RemoteDesktop-UserMode-In-TCP — вбудоване, НЕ локалізоване ім'я
                # правила (на відміну від DisplayGroup/DisplayName, які на
                # неанглійських збірках Windows перекладені й ненадійні для
                # програмного пошуку).
                if (Get-Command Get-NetFirewallRule -ErrorAction SilentlyContinue) {
                    try {
                        $rdpFirewallRule = Get-NetFirewallRule -Name 'RemoteDesktop-UserMode-In-TCP' -ErrorAction Stop
                        $script:Report.Security.RemoteAccess.FirewallProfiles = $rdpFirewallRule.Profile.ToString()

                        if ($rdpFirewallRule.Enabled) {
                            $rdpAddressFilter = Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $rdpFirewallRule -ErrorAction Stop
                            $script:Report.Security.RemoteAccess.FirewallScope = ($rdpAddressFilter.RemoteAddress -join ', ')

                            if ($script:Report.Security.RemoteAccess.FirewallScope -eq 'Any' -and $rdpFirewallRule.Profile.ToString() -match 'Public') {
                                Add-AuditFinding -Severity 'WARNING' -Category 'RemoteAccess' -Message 'RDP firewall-правило дозволяє підключення з будь-якої адреси (RemoteAddress=Any) у Public-профілі.' -Recommendation 'Обмежте RemoteAddress конкретними підмережами/VPN-діапазоном, особливо для Public-профілю фаєрвола.'
                            }
                        }
                    } catch {
                        # Вбудоване правило відсутнє/перейменоване (нетипова
                        # конфігурація) — не помилка збору, просто немає даних.
                    }
                }

                if (Get-Command Get-LocalGroupMember -ErrorAction SilentlyContinue) {
                    try {
                        # SID S-1-5-32-555 (well-known, locale-independent) —
                        # той самий канонічний резолвер, що й для Administrators
                        # (Resolve-BravoWellKnownGroupName, src/35-Collectors-Users.ps1).
                        # Група "Remote Desktop Users" локалізується разом з MUI
                        # (напр. "Пользователи удалённого рабочего стола" на
                        # ru-RU) — жорсткий англ. літерал раніше повністю не
                        # знаходив групу на не-EN збірках Windows, тож
                        # AllowedUsers завжди лишався порожнім (Release Blocker
                        # Fixes v0.6.1).
                        $rdpGroupName = Resolve-BravoWellKnownGroupName -Sid 'S-1-5-32-555' -FallbackName 'Remote Desktop Users'
                        $rdpGroupMembers = Get-LocalGroupMember -Group $rdpGroupName -ErrorAction Stop
                        $script:Report.Security.RemoteAccess.AllowedUsers = @($rdpGroupMembers | ForEach-Object { $_.Name })
                    } catch {
                        # Група "Remote Desktop Users" може справді не існувати
                        # на цій машині — не помилка збору.
                    }
                }
            }

            # --- WinRM: listeners, auth ---
            $winrmService = Get-Service -Name 'WinRM' -ErrorAction SilentlyContinue
            if ($winrmService) {
                $script:Report.Security.WinRM.ServiceStatus = $winrmService.Status.ToString()

                if ($winrmService.Status -eq 'Running') {
                    try {
                        $winrmListeners = Get-ChildItem 'WSMan:\localhost\Listener' -ErrorAction Stop
                        foreach ($listener in $winrmListeners) {
                            $listenerProps = Get-ChildItem $listener.PSPath -ErrorAction Stop
                            $script:Report.Security.WinRM.Listeners += [PSCustomObject]@{
                                Transport = ($listenerProps | Where-Object { $_.Name -eq 'Transport' }).Value
                                Port      = ($listenerProps | Where-Object { $_.Name -eq 'Port' }).Value
                                Enabled   = ($listenerProps | Where-Object { $_.Name -eq 'Enabled' }).Value
                            }
                        }

                        $winrmAuth = Get-ChildItem 'WSMan:\localhost\Service\Auth' -ErrorAction Stop
                        foreach ($authSetting in @('Basic', 'Kerberos', 'Negotiate', 'Certificate', 'CredSSP')) {
                            $matchedAuthSetting = $winrmAuth | Where-Object { $_.Name -eq $authSetting }
                            if ($matchedAuthSetting) {
                                $script:Report.Security.WinRM.Auth[$authSetting] = [System.Convert]::ToBoolean($matchedAuthSetting.Value)
                            }
                        }

                        $script:Report.Security.WinRM.Status = 'Detected'

                        if ($script:Report.Security.WinRM.Auth.Basic -eq $true) {
                            Add-AuditFinding -Severity 'WARNING' -Category 'Security.WinRM' -Message 'WinRM Basic authentication увімкнено.' -Recommendation 'Вимкніть Basic auth для WinRM, якщо немає обґрунтованої потреби — креденшели передаються без надійного захисту поза HTTPS-транспортом.'
                        }

                        if ($script:Report.Security.WinRM.Auth.CredSSP -eq $true) {
                            Add-AuditFinding -Severity 'WARNING' -Category 'Security.WinRM' -Message 'WinRM CredSSP authentication увімкнено.' -Recommendation 'CredSSP дозволяє делегування креденшелів (ризик relay/pass-the-hash) — вимкніть, якщо не потрібен саме подвійний hop.'
                        }
                    } catch {
                        Add-AuditError -Section 'Security.WinRM' -Message $_.Exception.Message
                    }
                } else {
                    $script:Report.Security.WinRM.Status = 'ServiceNotRunning'
                }
            } else {
                $script:Report.Security.WinRM.Status = 'NotAvailable'
            }

            # --- SMB signing / insecure guest access ---
            if (Get-Command Get-SmbServerConfiguration -ErrorAction SilentlyContinue) {
                try {
                    $smbServerConfig = Get-SmbServerConfiguration -ErrorAction Stop
                    $smbClientConfig = Get-SmbClientConfiguration -ErrorAction Stop

                    $script:Report.Security.SMB.ServerSigningRequired = [bool]$smbServerConfig.RequireSecuritySignature
                    $script:Report.Security.SMB.ServerSigningEnabled = [bool]$smbServerConfig.EnableSecuritySignature
                    $script:Report.Security.SMB.ClientSigningRequired = [bool]$smbClientConfig.RequireSecuritySignature
                    $script:Report.Security.SMB.InsecureGuestLogonsEnabled = [bool]$smbClientConfig.EnableInsecureGuestLogons
                    $script:Report.Security.SMB.Status = 'Detected'

                    if (-not $script:Report.Security.SMB.ServerSigningRequired) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.SMB' -Message 'SMB server signing не є обов''язковим (RequireSecuritySignature=False).' -Recommendation 'Увімкніть обов''язковий SMB signing на сервері — знижує ризик SMB relay-атак (напр. NTLM relay).'
                    }

                    if ($script:Report.Security.SMB.InsecureGuestLogonsEnabled) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.SMB' -Message 'SMB client дозволяє insecure guest logons.' -Recommendation 'Вимкніть EnableInsecureGuestLogons — небезпечний fallback на неавтентифікований guest-доступ до SMB-серверів.'
                    }
                } catch {
                    Add-AuditError -Section 'Security.SMB' -Message $_.Exception.Message
                }
            } else {
                $script:Report.Security.SMB.Status = 'NotAvailable'
            }

            # --- Password policy (net accounts) ---
            try {
                $netAccountsOutput = & net accounts 2>&1

                if ($LASTEXITCODE -eq 0) {
                    $parsedPolicy = ConvertFrom-BravoNetAccountsOutput -Lines $netAccountsOutput

                    $script:Report.Security.PasswordPolicy.MinPasswordAgeDays = $parsedPolicy.MinPasswordAgeDays
                    $script:Report.Security.PasswordPolicy.MaxPasswordAgeDays = $parsedPolicy.MaxPasswordAgeDays
                    $script:Report.Security.PasswordPolicy.MinPasswordLength = $parsedPolicy.MinPasswordLength
                    $script:Report.Security.PasswordPolicy.PasswordHistoryLength = $parsedPolicy.PasswordHistoryLength
                    $script:Report.Security.PasswordPolicy.LockoutThreshold = $parsedPolicy.LockoutThreshold
                    $script:Report.Security.PasswordPolicy.LockoutDurationMinutes = $parsedPolicy.LockoutDurationMinutes
                    $script:Report.Security.PasswordPolicy.LockoutObservationWindowMinutes = $parsedPolicy.LockoutObservationWindowMinutes
                    $script:Report.Security.PasswordPolicy.Status = 'Detected'

                    # Findings рахуються лише з ЧИСЛОВИХ значень (locale-безпечно
                    # — цифри не локалізуються так, як текстові мітки/значення
                    # "Never"/"None"/"Unlimited"). Нечислове значення (не
                    # вдалось [int]::TryParse) залишає поле "не оцінене" —
                    # свідомо без спроби вгадати сенс локалізованого слова.
                    $minLength = 0
                    if ([int]::TryParse($script:Report.Security.PasswordPolicy.MinPasswordLength, [ref]$minLength) -and $minLength -lt 8) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.PasswordPolicy' -Message "Мінімальна довжина пароля замала: $minLength символів." -Recommendation 'Встановіть мінімальну довжину пароля не менше 8 символів (net accounts /minpwlen:8 або групова політика).'
                    }

                    $lockoutThreshold = 0
                    if ([int]::TryParse($script:Report.Security.PasswordPolicy.LockoutThreshold, [ref]$lockoutThreshold) -and $lockoutThreshold -eq 0) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.PasswordPolicy' -Message 'Політика блокування облікового запису вимкнена (Lockout threshold=0) — необмежена кількість спроб входу.' -Recommendation 'Встановіть lockout threshold (напр. 5-10 невдалих спроб) для захисту від brute-force атак.'
                    }

                    $historyLength = 0
                    if ([int]::TryParse($script:Report.Security.PasswordPolicy.PasswordHistoryLength, [ref]$historyLength) -and $historyLength -eq 0) {
                        Add-AuditFinding -Severity 'WARNING' -Category 'Security.PasswordPolicy' -Message 'Історія паролів вимкнена (0) — користувачі можуть одразу повторно використовувати старий пароль.' -Recommendation 'Встановіть довжину історії паролів (напр. 5-24) для заборони повторного використання.'
                    }
                } else {
                    $script:Report.Security.PasswordPolicy.Status = 'Unavailable'
                }
            } catch {
                # `net accounts` недоступний (напр. обмежене середовище без
                # net.exe) — не типова ситуація на Windows, але не помилка
                # інструмента, якщо трапиться.
                $script:Report.Security.PasswordPolicy.Status = 'Unavailable'
                $script:Report.Security.PasswordPolicy.Error = $_.Exception.Message
            }

            # --- Audit policy (auditpol) ---
            # Свідомо БЕЗ findings на основі тексту "Inclusion Setting": ці
            # значення (напр. "No Auditing"/"Success and Failure") — локалізовані
            # рядки auditpol.exe, на відміну від числових полів password policy
            # вище. Судити "недостатньо аудиту" за збігом англійського тексту
            # було б ненадійно на не-EN системах — просто публікуємо сирі дані.
            if (Get-Command auditpol -ErrorAction SilentlyContinue) {
                try {
                    $auditPolicyCsv = & auditpol /get /category:* /r 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        $auditPolicyEntries = $auditPolicyCsv | ConvertFrom-Csv -ErrorAction Stop

                        foreach ($entry in $auditPolicyEntries) {
                            $script:Report.Security.AuditPolicy.Subcategories += [PSCustomObject]@{
                                Category          = $entry.'Policy Target'
                                Subcategory       = $entry.Subcategory
                                SubcategoryGuid   = $entry.'Subcategory GUID'
                                InclusionSetting  = $entry.'Inclusion Setting'
                            }
                        }

                        $script:Report.Security.AuditPolicy.TotalCount = $script:Report.Security.AuditPolicy.Subcategories.Count
                        $script:Report.Security.AuditPolicy.Status = 'Detected'
                    } else {
                        $script:Report.Security.AuditPolicy.Status = 'Unavailable'
                    }
                } catch {
                    Add-AuditError -Section 'Security.AuditPolicy' -Message $_.Exception.Message
                }
            } else {
                $script:Report.Security.AuditPolicy.Status = 'NotAvailable'
            }

            # --- Autoruns: реєстрові Run/RunOnce (HKLM/HKCU + Wow6432Node на
            # 64-bit) + папки автозавантаження (User/AllUsers Startup).
            # Гейтовано окремо Deep/Forensic (не Full) — набагато більший
            # обсяг даних, ніж решта Security-блоку вище.
            if ($Profile -in @('Deep','Forensic')) {
                try {
                    $autorunRegistryTargets = @(
                        [PSCustomObject]@{ Hive = 'HKLM'; Source = 'Run';     Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' }
                        [PSCustomObject]@{ Hive = 'HKLM'; Source = 'RunOnce'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' }
                        [PSCustomObject]@{ Hive = 'HKLM'; Source = 'Run (Wow6432Node)';     Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' }
                        [PSCustomObject]@{ Hive = 'HKLM'; Source = 'RunOnce (Wow6432Node)'; Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce' }
                        [PSCustomObject]@{ Hive = 'HKCU'; Source = 'Run';     Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' }
                        [PSCustomObject]@{ Hive = 'HKCU'; Source = 'RunOnce'; Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' }
                    )

                    foreach ($target in $autorunRegistryTargets) {
                        if (-not (Test-Path -LiteralPath $target.Path)) { continue }
                        try {
                            $keyProperties = Get-ItemProperty -LiteralPath $target.Path -ErrorAction Stop
                            $entries = ConvertFrom-BravoRegistryKeyProperties -PropertiesObject $keyProperties
                            foreach ($entry in $entries) {
                                $script:Report.Security.Autoruns += [PSCustomObject]@{
                                    Name    = $entry.Name
                                    Command = $entry.Value
                                    Source  = $target.Source
                                    Hive    = $target.Hive
                                }
                            }
                        } catch {
                            Add-AuditError -Section "Security.Autoruns.$($target.Source)" -Message $_.Exception.Message
                        }
                    }

                    # Папки автозавантаження — окремий механізм autorun, не
                    # реєстровий; WOW6432Node-варіанту тут немає (шлях на
                    # файловій системі однаковий для 32/64-bit процесів).
                    $startupFolders = @(
                        [PSCustomObject]@{ Hive = 'HKCU'; Source = 'StartupFolder (User)';     Path = [Environment]::GetFolderPath('Startup') }
                        [PSCustomObject]@{ Hive = 'HKLM'; Source = 'StartupFolder (AllUsers)'; Path = [Environment]::GetFolderPath('CommonStartup') }
                    )

                    foreach ($folder in $startupFolders) {
                        if (-not $folder.Path -or -not (Test-Path -LiteralPath $folder.Path)) { continue }
                        try {
                            $files = Get-ChildItem -LiteralPath $folder.Path -File -ErrorAction Stop
                            foreach ($file in $files) {
                                # desktop.ini — штатний системний файл папки, не autorun-запис.
                                if ($file.Name -eq 'desktop.ini') { continue }
                                $script:Report.Security.Autoruns += [PSCustomObject]@{
                                    Name    = $file.BaseName
                                    Command = $file.FullName
                                    Source  = $folder.Source
                                    Hive    = $folder.Hive
                                }
                            }
                        } catch {
                            Add-AuditError -Section "Security.Autoruns.$($folder.Source)" -Message $_.Exception.Message
                        }
                    }
                } catch {
                    Add-AuditError -Section 'Security.Autoruns' -Message $_.Exception.Message
                }
            }
            # Відсутність autorun-записів (чисте автозавантаження) — штатний
            # стан, не помилка збору; $script:Report.Security.Autoruns
            # лишається порожнім масивом.

            # --- Scheduled tasks: гейтовано окремо Deep/Forensic (той самий
            # принцип, що й Autoruns вище — суттєво більший обсяг даних, ніж
            # решта Security-блоку). Вбудовані задачі Windows (TaskPath
            # \Microsoft\Windows\*) — типово 200-300+ на кожній машині; замість
            # приховування (втрата даних) або показу всіх без розбору (шум),
            # позначаємо прапорцем IsMicrosoftDefault=true — той самий
            # принцип "дані видимі, findings обережні", що вже застосований
            # для ARP/Storage ReservedVolumes.
            if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
                try {
                    $scheduledTasks = Get-ScheduledTask -ErrorAction Stop
                    foreach ($task in $scheduledTasks) {
                        $firstAction = $task.Actions | Select-Object -First 1
                        $script:Report.Security.ScheduledTasks += [PSCustomObject]@{
                            Name               = $task.TaskName
                            Path               = $task.TaskPath
                            State              = [string]$task.State
                            Author             = $task.Author
                            Execute            = if ($firstAction) { [string]$firstAction.Execute } else { '' }
                            Arguments          = if ($firstAction) { [string]$firstAction.Arguments } else { '' }
                            IsMicrosoftDefault = [bool]($task.TaskPath -like '\Microsoft\Windows\*')
                        }
                    }
                } catch {
                    Add-AuditError -Section 'Security.ScheduledTasks' -Message $_.Exception.Message
                }
            }
            # Get-ScheduledTask відсутній (модуль ScheduledTasks не
            # встановлено, напр. деякі Server Core збірки) — штатний стан,
            # $script:Report.Security.ScheduledTasks лишається порожнім
            # масивом.

            Write-Host "  $IconSecurity Secure Boot: $($script:Report.Security.SecureBoot.Status), TPM: $($script:Report.Security.TPM.Status), SMBv1: $($script:Report.Security.SMBv1.Status), Defender: $($script:Report.Security.Defender.Status), WinRM: $($script:Report.Security.WinRM.Status), Password policy: $($script:Report.Security.PasswordPolicy.Status), Audit policy: $($script:Report.Security.AuditPolicy.Status) ($($script:Report.Security.AuditPolicy.TotalCount))" -ForegroundColor Green
        }

        Write-Host "  $IconSecurity Безпека: RDP=$(if($script:Report.Security.RemoteAccess.RDPEnabled){'ON'}else{'OFF'}), UAC=$(if($script:Report.Security.UAC.Enabled){'ON'}else{'OFF'})" -ForegroundColor Green
    } catch {
        Add-AuditError -Section 'Security' -Message $_.Exception.Message
        Write-Host "  $IconError Помилка даних безпеки: $($_.Exception.Message)" -ForegroundColor Red
    }
}
