# MODULE: 35-Collectors-Users.ps1
# Збір інформації про локальних користувачів та адміністраторів.

function Get-LocalAdministratorsSafe {
    $members = @()

    try {
        $adminGroupSid = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
        $adminGroupName = $adminGroupSid.Translate([Security.Principal.NTAccount]).Value.Split('\\')[-1]
    } catch {
        $adminGroupName = 'Administrators'
    }

    if (Get-Command Get-LocalGroupMember -ErrorAction SilentlyContinue) {
        try {
            $members = Get-LocalGroupMember -Group $adminGroupName -ErrorAction Stop |
                Select-Object -ExpandProperty Name
            return @($members)
        } catch {
            Add-AuditError -Section 'Users.LocalAdmins.GetLocalGroupMember' -Message $_.Exception.Message
        }
    }

    try {
        $raw = net localgroup "$adminGroupName" 2>$null
        if ($raw) {
            # Завершальний рядок "The command completed successfully." (net.exe)
            # локалізується разом з MUI-пакетом Windows — раніше тут матчився
            # текст лише для en/uk, на інших локалях (ru/de/pl/...) фальшивий
            # службовий рядок потрапляв у список адмінів. net localgroup
            # структурно ЗАВЖДИ завершує вивід рівно одним таким рядком
            # одразу після переліку членів, тому замість тексту-матчингу
            # просто відкидаємо останній непорожній рядок після роздільника
            # "----" — це локале-незалежно.
            $capture = $false
            $capturedLines = New-Object System.Collections.Generic.List[string]
            foreach ($line in $raw) {
                $text = ($line | Out-String).Trim()
                if (-not $text) { continue }
                if ($text -match '^-{3,}$') { $capture = $true; continue }
                if ($capture) { $capturedLines.Add($text) }
            }
            if ($capturedLines.Count -gt 0) {
                # Останній рядок — завжди статус-повідомлення net.exe, не ім'я.
                $capturedLines.RemoveAt($capturedLines.Count - 1)
            }
            $members = @($capturedLines)
        }
    } catch {
        Add-AuditError -Section 'Users.LocalAdmins.NetLocalGroup' -Message $_.Exception.Message
    }

    return @($members)
}

function Get-BravoUsersAudit {
    [CmdletBinding()]
    param()

    # --- Користувачі ---
    try {
        $script:Report.Users.LocalAdmins = @(Get-LocalAdministratorsSafe | Where-Object { $_ } | Select-Object -Unique)
    } catch {
        Add-AuditError -Section 'Users' -Message $_.Exception.Message
    }
}
