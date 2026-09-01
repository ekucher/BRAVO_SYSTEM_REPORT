# MODULE: 39a-Data-WindowsLifecycle.ps1
# Централізований data-модуль: статична таблиця життєвого циклу Windows.
# Винесено з src/39-Collectors-Updates.ps1 (P0.7), щоб оновлення дат
# не вимагало правок логіки колектора Get-BravoOsSupportInfo.

# Дата актуальності статичної таблиці життєвого циклу Windows.
# Оновлюйте разом із таблицею у Get-BravoWindowsLifecycleTable.
# Звірено з офіційними lifecycle-сторінками Microsoft Learn (learn.microsoft.com/lifecycle).
$script:BravoLifecycleTableUpdatedAt = '2026-09-01'

function Get-BravoWindowsLifecycleTable {
    [CmdletBinding()]
    param()

    # Статична таблиця життєвого циклу Windows.
    # Дані потребують періодичного оновлення разом із $BravoLifecycleTableUpdatedAt.
    #
    # SupportEndConsumer   — Home / Pro / Core-редакції.
    # SupportEndEnterprise — Enterprise / Education / серверні редакції.
    # SupportEndLtsc       — LTSC / LTSB-редакції (порожнє, якщо такої редакції немає).
    #
    # Свідомі виключення:
    # - IoT LTSC-редакції з довшими термінами не виділені окремо;
    # - дати ESU не використовуються (наприклад, Windows 7 SP1 і Server 2008 R2 SP1 показують 2020-01-14,
    #   а не 2023-01-10; Windows 10 22H2 показує 2025-10-14, а не дату завершення ESU);
    # - Windows Server SAC 1809 пропущено, бо build 17763 збігається з Windows Server 2019 (LTSC);
    # - дати наведені як публічно оголошена дата (офіційна raw "Retirement Date" на learn.microsoft.com/lifecycle
    #   вказана як HH:59:59 наступного календарного дня в PT — тут узгоджено з публічним анонсом, на 1 день раніше).
    return @(
        # --- Клієнтські випуски ---
        [PSCustomObject]@{ Build = 26200; IsServer = $false; Product = 'Windows 11'                    ; DisplayVersion = '25H2'                ; SupportEndConsumer = '2027-10-12'; SupportEndEnterprise = '2028-10-10'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 26100; IsServer = $false; Product = 'Windows 11'                    ; DisplayVersion = '24H2'                ; SupportEndConsumer = '2026-10-13'; SupportEndEnterprise = '2027-10-12'; SupportEndLtsc = '2029-10-09' }
        [PSCustomObject]@{ Build = 22631; IsServer = $false; Product = 'Windows 11'                    ; DisplayVersion = '23H2'                ; SupportEndConsumer = '2025-11-11'; SupportEndEnterprise = '2026-11-10'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 22621; IsServer = $false; Product = 'Windows 11'                    ; DisplayVersion = '22H2'                ; SupportEndConsumer = '2024-10-08'; SupportEndEnterprise = '2025-10-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 22000; IsServer = $false; Product = 'Windows 11'                    ; DisplayVersion = '21H2'                ; SupportEndConsumer = '2023-10-10'; SupportEndEnterprise = '2024-10-08'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 19045; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '22H2'                ; SupportEndConsumer = '2025-10-14'; SupportEndEnterprise = '2025-10-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 19044; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '21H2'                ; SupportEndConsumer = '2023-06-13'; SupportEndEnterprise = '2024-06-11'; SupportEndLtsc = '2027-01-12' }
        [PSCustomObject]@{ Build = 19043; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '21H1'                ; SupportEndConsumer = '2022-12-13'; SupportEndEnterprise = '2022-12-13'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 19042; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '20H2'                ; SupportEndConsumer = '2022-05-10'; SupportEndEnterprise = '2023-05-09'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 19041; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '2004'                ; SupportEndConsumer = '2021-12-14'; SupportEndEnterprise = '2021-12-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 18363; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1909'                ; SupportEndConsumer = '2021-05-11'; SupportEndEnterprise = '2022-05-10'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 18362; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1903'                ; SupportEndConsumer = '2020-12-08'; SupportEndEnterprise = '2020-12-08'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 17763; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1809'                ; SupportEndConsumer = '2020-11-10'; SupportEndEnterprise = '2021-05-11'; SupportEndLtsc = '2029-01-09' }
        [PSCustomObject]@{ Build = 17134; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1803'                ; SupportEndConsumer = '2019-11-12'; SupportEndEnterprise = '2021-05-11'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 16299; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1709'                ; SupportEndConsumer = '2019-04-09'; SupportEndEnterprise = '2020-10-13'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 15063; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1703'                ; SupportEndConsumer = '2018-10-09'; SupportEndEnterprise = '2019-10-08'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 14393; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1607'                ; SupportEndConsumer = '2018-04-10'; SupportEndEnterprise = '2019-04-09'; SupportEndLtsc = '2026-10-13' }
        [PSCustomObject]@{ Build = 10586; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1511'                ; SupportEndConsumer = '2017-10-10'; SupportEndEnterprise = '2017-10-10'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 10240; IsServer = $false; Product = 'Windows 10'                    ; DisplayVersion = '1507'                ; SupportEndConsumer = '2017-05-09'; SupportEndEnterprise = '2017-05-09'; SupportEndLtsc = '2025-10-14' }
        [PSCustomObject]@{ Build = 9600 ; IsServer = $false; Product = 'Windows 8.1'                   ; DisplayVersion = '8.1'                 ; SupportEndConsumer = '2023-01-10'; SupportEndEnterprise = '2023-01-10'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 9200 ; IsServer = $false; Product = 'Windows 8'                     ; DisplayVersion = 'RTM'                 ; SupportEndConsumer = '2016-01-12'; SupportEndEnterprise = '2016-01-12'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 7601 ; IsServer = $false; Product = 'Windows 7'                     ; DisplayVersion = 'SP1'                 ; SupportEndConsumer = '2020-01-14'; SupportEndEnterprise = '2020-01-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 7600 ; IsServer = $false; Product = 'Windows 7'                     ; DisplayVersion = 'RTM'                 ; SupportEndConsumer = '2013-04-09'; SupportEndEnterprise = '2013-04-09'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 6002 ; IsServer = $false; Product = 'Windows Vista'                 ; DisplayVersion = 'SP2'                 ; SupportEndConsumer = '2017-04-11'; SupportEndEnterprise = '2017-04-11'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 6001 ; IsServer = $false; Product = 'Windows Vista'                 ; DisplayVersion = 'SP1'                 ; SupportEndConsumer = '2011-07-12'; SupportEndEnterprise = '2011-07-12'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 6000 ; IsServer = $false; Product = 'Windows Vista'                 ; DisplayVersion = 'RTM'                 ; SupportEndConsumer = '2010-04-13'; SupportEndEnterprise = '2010-04-13'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 3790 ; IsServer = $false; Product = 'Windows XP Professional x64'   ; DisplayVersion = 'SP2'                 ; SupportEndConsumer = '2014-04-08'; SupportEndEnterprise = '2014-04-08'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 2600 ; IsServer = $false; Product = 'Windows XP'                    ; DisplayVersion = 'SP3'                 ; SupportEndConsumer = '2014-04-08'; SupportEndEnterprise = '2014-04-08'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 2195 ; IsServer = $false; Product = 'Windows 2000 Professional'     ; DisplayVersion = 'SP4'                 ; SupportEndConsumer = '2010-07-13'; SupportEndEnterprise = '2010-07-13'; SupportEndLtsc = '' }

        # --- Серверні випуски ---
        [PSCustomObject]@{ Build = 26100; IsServer = $true ; Product = 'Windows Server 2025'           ; DisplayVersion = '24H2'                ; SupportEndConsumer = '2034-11-14'; SupportEndEnterprise = '2034-11-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 25398; IsServer = $true ; Product = 'Windows Server 23H2'          ; DisplayVersion = '23H2'                ; SupportEndConsumer = '2025-10-24'; SupportEndEnterprise = '2025-10-24'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 20348; IsServer = $true ; Product = 'Windows Server 2022'           ; DisplayVersion = '21H2'                ; SupportEndConsumer = '2031-10-14'; SupportEndEnterprise = '2031-10-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 19042; IsServer = $true ; Product = 'Windows Server SAC'            ; DisplayVersion = '20H2'                ; SupportEndConsumer = '2022-08-09'; SupportEndEnterprise = '2022-08-09'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 19041; IsServer = $true ; Product = 'Windows Server SAC'            ; DisplayVersion = '2004'                ; SupportEndConsumer = '2021-12-14'; SupportEndEnterprise = '2021-12-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 18363; IsServer = $true ; Product = 'Windows Server SAC'            ; DisplayVersion = '1909'                ; SupportEndConsumer = '2021-05-11'; SupportEndEnterprise = '2021-05-11'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 18362; IsServer = $true ; Product = 'Windows Server SAC'            ; DisplayVersion = '1903'                ; SupportEndConsumer = '2020-12-08'; SupportEndEnterprise = '2020-12-08'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 17763; IsServer = $true ; Product = 'Windows Server 2019'           ; DisplayVersion = '1809'                ; SupportEndConsumer = '2029-01-09'; SupportEndEnterprise = '2029-01-09'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 17134; IsServer = $true ; Product = 'Windows Server SAC'            ; DisplayVersion = '1803'                ; SupportEndConsumer = '2019-11-12'; SupportEndEnterprise = '2019-11-12'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 16299; IsServer = $true ; Product = 'Windows Server SAC'            ; DisplayVersion = '1709'                ; SupportEndConsumer = '2019-04-09'; SupportEndEnterprise = '2019-04-09'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 14393; IsServer = $true ; Product = 'Windows Server 2016'           ; DisplayVersion = '1607'                ; SupportEndConsumer = '2027-01-12'; SupportEndEnterprise = '2027-01-12'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 9600 ; IsServer = $true ; Product = 'Windows Server 2012 R2'        ; DisplayVersion = 'R2'                  ; SupportEndConsumer = '2023-10-10'; SupportEndEnterprise = '2023-10-10'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 9200 ; IsServer = $true ; Product = 'Windows Server 2012'           ; DisplayVersion = 'RTM'                 ; SupportEndConsumer = '2023-10-10'; SupportEndEnterprise = '2023-10-10'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 7601 ; IsServer = $true ; Product = 'Windows Server 2008 R2'        ; DisplayVersion = 'R2 SP1'              ; SupportEndConsumer = '2020-01-14'; SupportEndEnterprise = '2020-01-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 7600 ; IsServer = $true ; Product = 'Windows Server 2008 R2'        ; DisplayVersion = 'R2 RTM'              ; SupportEndConsumer = '2013-04-09'; SupportEndEnterprise = '2013-04-09'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 6002 ; IsServer = $true ; Product = 'Windows Server 2008'           ; DisplayVersion = 'SP2'                 ; SupportEndConsumer = '2020-01-14'; SupportEndEnterprise = '2020-01-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 6001 ; IsServer = $true ; Product = 'Windows Server 2008'           ; DisplayVersion = 'RTM'                 ; SupportEndConsumer = '2011-07-12'; SupportEndEnterprise = '2011-07-12'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 3790 ; IsServer = $true ; Product = 'Windows Server 2003 / 2003 R2' ; DisplayVersion = 'SP2'                 ; SupportEndConsumer = '2015-07-14'; SupportEndEnterprise = '2015-07-14'; SupportEndLtsc = '' }
        [PSCustomObject]@{ Build = 2195 ; IsServer = $true ; Product = 'Windows 2000 Server'           ; DisplayVersion = 'SP4'                 ; SupportEndConsumer = '2010-07-13'; SupportEndEnterprise = '2010-07-13'; SupportEndLtsc = '' }
    )
}
