﻿﻿﻿﻿﻿#Requires -RunAsAdministrator
# Windows 11 Optimization Script v3.1
# Targets 24H2 (Build 26100) and 25H2 (Build 26200) - September 2026
# AMD and NVIDIA GPU compatible
# Preserves: Print Spooler, Windows Search, Windows Scan, WIA, WSL, VMware
$ErrorActionPreference = 'SilentlyContinue'
$LogFile = (Join-Path $env:TEMP ('Win11Optimize_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log'))

# ANSI color definitions
$e = [char]27
$cBlue    = $e + '[38;5;62m'
$cLtBlue  = $e + '[38;5;69m'
$cCyan    = $e + '[38;5;45m'
$cOrange  = $e + '[38;5;208m'
$cYellow  = $e + '[38;5;220m'
$cRed     = $e + '[38;5;196m'
$cGrey    = $e + '[38;5;245m'
$cWhite   = $e + '[97m'
$cGreen   = $e + '[38;5;46m'
$cDkGrey  = $e + '[38;5;238m'
$cDkBlue  = $e + '[38;5;18m'
$cBold    = $e + '[1m'
$cReset   = $e + '[0m'

# ── Category Descriptions ────────────────────────────────────────────────────
$catDesc = @{
    '1' = 'Removes all Microsoft AI and Copilot components including app packages, ' +
          'Recall snapshots, Click to Do, Input Insights, and AI image generation in ' +
          'Paint/Photos/Snipping Tool. Disables Bing integration in Windows Search and ' +
          'Copilot sidebar in Edge. Stops AI Fabric background services. ' +
          'Tradeoffs: AI-powered features in built-in apps will stop working. ' +
          'Bing web results will no longer appear in Windows Search. These changes ' +
          'do not affect third-party apps or browsers.'

    '2' = 'Stops and disables background services that consume CPU and RAM without benefiting ' +
          'most users: Xbox Live services, telemetry diagnostics, Windows Error Reporting, ' +
          'Edge update services, and legacy services like Fax and Remote Registry. Protected ' +
          'services (Print Spooler, Windows Search, WSL, VMware) are never touched. ' +
          'Tradeoffs: Edge will no longer auto-update -- you must update it manually or ' +
          'it may fall behind on security patches. Windows Error Reporting crash data will ' +
          'no longer be sent to Microsoft, which means no automatic fix suggestions. Xbox ' +
          'Game Pass cloud features will not function.'

    '3' = 'Comprehensive privacy lockdown: zeroes telemetry to minimum, kills ad tracking and ' +
          'tailored experiences, blocks background microphone/camera/screen capture access for ' +
          'Store apps, disables cloud backup sync and Find My Device, kills Edge background ' +
          'processes and startup boost, disables Remote Assistance, WiFi auto-connect, and ' +
          'removes lock screen ads, Spotlight, and Start menu suggestions. ' +
          'Tradeoffs: Store/UWP apps that need mic or camera will require you to manually ' +
          'grant permission when first used. Find My Device will not be able to locate your ' +
          'PC if lost or stolen. Remote Assistance sessions (someone helping you remotely) ' +
          'will be blocked. Cloud settings sync across devices will stop.'

    '4' = 'Uninstalls 25+ preinstalled apps including Bing apps, Clipchamp, Teams, and Outlook. ' +
          'Removes all Xbox overlay and identity packages that hook into games. Fully removes ' +
          'OneDrive: kills the process, runs the uninstaller, cleans leftover folders, removes ' +
          'it from Explorer, and sets policy to prevent reinstallation. Disables Widgets. ' +
          'Tradeoffs: OneDrive removal is effectively permanent and files stored ONLY in ' +
          'OneDrive cloud (not synced locally) will become inaccessible from this PC -- back ' +
          'them up first. Xbox overlay removal breaks Game Pass features, achievement tracking, ' +
          'and the Xbox social system. Removed apps can be reinstalled from the Microsoft Store ' +
          'if needed, but OneDrive requires re-downloading the installer from Microsoft.'

    '5' = 'Aggressive performance tuning: fast boot, SysMain/Superfetch disabled, Reserved ' +
          'Storage reclaimed (~7GB), background UWP apps killed, CPU scheduler tuned for ' +
          'foreground priority, power throttling disabled, Game DVR/Bar disabled, ' +
          'Hardware-Accelerated GPU Scheduling (HAGS) enabled, Multi-Plane Overlay stutter ' +
          'fix applied, fullscreen optimizations bypassed, NVMe I/O tuned, Nagle algorithm ' +
          'disabled, network throttling removed, Ultimate Performance power plan with sleep ' +
          'fully disabled, Delivery Optimization off, and Windows Update set to notify-only ' +
          'with no automatic reboots. ' +
          'Tradeoffs: HAGS may cause instability on older GPU drivers -- update your graphics ' +
          'drivers first. Ultimate Performance increases power draw and heat output. The PC ' +
          'will never sleep or hibernate automatically. Windows Update will NOT install patches ' +
          'automatically -- you are responsible for manually checking and installing security ' +
          'updates. Delivery Optimization disabled means updates download only from Microsoft ' +
          'servers, which may be slower on limited connections.'

    '6' = 'Hardens your attack surface: removes the obsolete SMBv1 protocol, disables NetBIOS ' +
          'and LLMNR name resolution (common LAN attack vectors), kills WPAD proxy ' +
          'auto-discovery, prevents WDigest from caching plaintext credentials in memory, ' +
          'restricts anonymous network enumeration, enables PowerShell script block logging, ' +
          'and blocks inbound Remote Desktop connections. ' +
          'Tradeoffs: SMBv1 removal may break connectivity to very old NAS devices or printers ' +
          'that only support SMBv1 (anything made after ~2015 supports SMBv2/v3). Remote ' +
          'Desktop inbound will be blocked -- if you need to RDP into this machine, skip ' +
          'this category.'
}

# ── Helper Functions ─────────────────────────────────────────────────────────
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $entry = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' [' + $Level + '] ' + $Message
    Add-Content -Path $LogFile -Value $entry
    switch ($Level) {
        'SUCCESS' { Write-Host ($cGreen  + '  [OK] ' + $cReset + $Message) }
        'WARN'    { Write-Host ($cYellow + '  [!!] ' + $cReset + $cGrey + $Message + $cReset) }
        'ERROR'   { Write-Host ($cRed    + '  [XX] ' + $cReset + $Message) }
        default   { Write-Host ($cCyan   + '  [--] ' + $cReset + $cGrey + $Message + $cReset) }
    }
}
function Set-RegistryValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        Write-Log ('Registry set: ' + $Path + '\' + $Name + ' = ' + $Value) 'SUCCESS'
    }
    catch {
        Write-Log ('Failed to set: ' + $Path + '\' + $Name + ' - ' + $_) 'ERROR'
    }
}
function Disable-ServiceSafe {
    param([string]$ServiceName, [string]$DisplayName)
    $protected = @(
        'Spooler', 'WSearch', 'WiaRpc', 'StiSvc', 'PrintWorkflowUserSvc',
        'LxssManager', 'WslService',
        'VMAuthdService', 'VMnetDHCP', 'VMUSBArbService', 'VMwareHostd'
    )
    if ($protected -contains $ServiceName) {
        Write-Log ('PROTECTED - skipped: ' + $DisplayName + ' - ' + $ServiceName) 'WARN'
        return
    }
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($svc) {
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log ('Disabled service: ' + $DisplayName + ' - ' + $ServiceName) 'SUCCESS'
    }
    else {
        Write-Log ('Service not found: ' + $ServiceName) 'WARN'
    }
}
function Remove-AppxSafe {
    param([string]$Pattern)
    $protectedPatterns = @('*Print3D*', '*Print*Scan*', '*WindowsScan*')
    foreach ($pp in $protectedPatterns) {
        if ($Pattern -like $pp) {
            Write-Log ('PROTECTED - skipped removal: ' + $Pattern) 'WARN'
            return
        }
    }
    $pkgs = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $Pattern }
    foreach ($pkg in $pkgs) {
        try {
            $pkg | Remove-AppxPackage -AllUsers -ErrorAction Stop
            Get-AppxProvisionedPackage -Online |
                Where-Object { $_.DisplayName -like $Pattern } |
                Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            Write-Log ('Removed: ' + $pkg.Name) 'SUCCESS'
        }
        catch {
            Write-Log ('Could not remove: ' + $pkg.Name + ' - ' + $_) 'WARN'
        }
    }
    if (-not $pkgs) { Write-Log ('Package not found: ' + $Pattern) 'WARN' }
}
function Show-CategoryInfo {
    param([string]$Key, [string]$Title)
    Write-Host ''
    Write-Host ($cDkGrey + '  ──────────────────────────────────────────────────────' + $cReset)
    Write-Host ($cOrange + '  ' + $cBold + $Title + $cReset)
    Write-Host ($cDkGrey + '  ──────────────────────────────────────────────────────' + $cReset)
    Write-Host ''
    # Word-wrap description to ~70 chars
    $desc = $catDesc[$Key]
    $words = $desc -split ' '
    $line = '  '
    foreach ($w in $words) {
        if (($line + ' ' + $w).Length -gt 72) {
            Write-Host ($cGrey + $line + $cReset)
            $line = '  ' + $w
        }
        else {
            if ($line -eq '  ') { $line = '  ' + $w } else { $line = $line + ' ' + $w }
        }
    }
    if ($line.Length -gt 2) { Write-Host ($cGrey + $line + $cReset) }
    Write-Host ''
}

# ── Banner ───────────────────────────────────────────────────────────────────
function Show-Banner {
    Clear-Host
    Write-Host ''
    Write-Host ($cDkBlue + '  ░▒▓' + $cBlue + '█████████████████████████████████████████████████████' + $cDkBlue + '▓▒░' + $cReset)
    Write-Host ($cDkBlue + '  ░▒▓' + $cBlue + '█' + $cReset + '                                                   ' + $cBlue + '█' + $cDkBlue + '▓▒░' + $cReset)
    Write-Host ($cDkBlue + '  ░▒▓' + $cBlue + '█' + $cReset + '   ' + $cLtBlue + '▄███▄' + $cReset + ' ' + $cOrange + '▄███▄' + $cReset + '                                    ' + $cBlue + '█' + $cDkBlue + '▓▒░' + $cReset)
    Write-Host ($cDkBlue + '  ░▒▓' + $cBlue + '█' + $cReset + '   ' + $cLtBlue + '█████' + $cReset + ' ' + $cOrange + '█████' + $cReset + '   ' + $cWhite + $cBold + 'W I N O P T' + $cReset + '                  ' + $cBlue + '█' + $cDkBlue + '▓▒░' + $cReset)
    Write-Host ($cDkBlue + '  ░▒▓' + $cBlue + '█' + $cReset + '   ' + $cLtBlue + '▀███▀' + $cReset + ' ' + $cOrange + '▀███▀' + $cReset + '   ' + $cGrey + 'Windows 11 Optimizer' + $cReset + '           ' + $cBlue + '█' + $cDkBlue + '▓▒░' + $cReset)
    Write-Host ($cDkBlue + '  ░▒▓' + $cBlue + '█' + $cReset + '   ' + $cYellow + '▄███▄' + $cReset + ' ' + $cRed + '▄███▄' + $cReset + '                                    ' + $cBlue + '█' + $cDkBlue + '▓▒░' + $cReset)
    Write-Host ($cDkBlue + '  ░▒▓' + $cBlue + '█' + $cReset + '   ' + $cYellow + '█████' + $cReset + ' ' + $cRed + '█████' + $cReset + '   ' + $cOrange + 'v3.1' + $cReset + $cDkGrey + ' | ' + $cGrey + '24H2/25H2' + $cDkGrey + ' | ' + $cGrey + 'Sept 2026' + $cReset + '  ' + $cBlue + '█' + $cDkBlue + '▓▒░' + $cReset)
    Write-Host ($cDkBlue + '  ░▒▓' + $cBlue + '█' + $cReset + '   ' + $cYellow + '▀███▀' + $cReset + ' ' + $cRed + '▀███▀' + $cReset + '   ' + $cDkGrey + 'AMD + NVIDIA Compatible' + $cReset + '         ' + $cBlue + '█' + $cDkBlue + '▓▒░' + $cReset)
    Write-Host ($cDkBlue + '  ░▒▓' + $cBlue + '█' + $cReset + '                                                   ' + $cBlue + '█' + $cDkBlue + '▓▒░' + $cReset)
    Write-Host ($cDkBlue + '  ░▒▓' + $cBlue + '█████████████████████████████████████████████████████' + $cDkBlue + '▓▒░' + $cReset)
    Write-Host ''
}

# ============================================================================
# Category 1: AI / Copilot Removal
# ============================================================================
function Invoke-RemoveAICopilot {
    Write-Host ''
    Write-Host ($cOrange + '  ■ ' + $cWhite + $cBold + 'Executing: Remove AI / Copilot' + $cReset)
    Remove-AppxSafe '*Microsoft.Copilot*'
    Remove-AppxSafe '*Microsoft.Windows.Ai*'
    Remove-AppxSafe '*MicrosoftWindows.Client.AIX*'
    Remove-AppxSafe '*Microsoft.Windows.AI.Copilot.Provider*'
    Remove-AppxSafe '*MicrosoftWindows.Client.Photon*'
    Remove-AppxSafe '*Microsoft.549981C3F5F10*'
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Copilot' 'RemoveCopilotApp' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'TurnOffSavingSnapshots' 1
    Write-Log 'Attempting DISM removal of Recall...' 'INFO'
    dism /online /Disable-Feature /FeatureName:'Recall' /NoRestart 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Log 'Recall removed via DISM' 'SUCCESS' }
    else { Write-Log 'Recall not available as optional feature - registry controls applied' 'WARN' }
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableClickToDo' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\input\Settings' 'InsightsEnabled' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableInputInsights' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableImageCreator' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableCocreator' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableGenerativeFill' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableGenerativeErase' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'HubsSidebarEnabled' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'CopilotCDPPageContext' 0
    Disable-ServiceSafe 'AIFabricService'       'AI Fabric Service'
    Disable-ServiceSafe 'AIF'                   'AI Fabric'
    Write-Log 'AI/Copilot removal complete' 'SUCCESS'
}

# ============================================================================
# Category 2: Disable Unnecessary Services
# ============================================================================
function Invoke-DisableServices {
    Write-Host ''
    Write-Host ($cOrange + '  ■ ' + $cWhite + $cBold + 'Executing: Disable Unnecessary Services' + $cReset)
    Disable-ServiceSafe 'DiagTrack'            'Connected User Experiences and Telemetry'
    Disable-ServiceSafe 'dmwappushservice'      'WAP Push Message Routing'
    Disable-ServiceSafe 'diagnosticshub.standardcollector.service' 'Diagnostics Hub'
    Disable-ServiceSafe 'XblAuthManager'        'Xbox Live Auth Manager'
    Disable-ServiceSafe 'XblGameSave'           'Xbox Live Game Save'
    Disable-ServiceSafe 'XboxNetApiSvc'         'Xbox Live Networking'
    Disable-ServiceSafe 'XboxGipSvc'            'Xbox Accessory Management'
    Disable-ServiceSafe 'WerSvc'               'Windows Error Reporting'
    Disable-ServiceSafe 'edgeupdate'           'Microsoft Edge Update Service'
    Disable-ServiceSafe 'edgeupdatem'          'Microsoft Edge Update Service (Manual)'
    Disable-ServiceSafe 'MicrosoftEdgeElevationService' 'Microsoft Edge Elevation Service'
    Disable-ServiceSafe 'Fax'                   'Fax'
    Disable-ServiceSafe 'RemoteRegistry'        'Remote Registry'
    Disable-ServiceSafe 'lfsvc'                 'Geolocation Service'
    Disable-ServiceSafe 'MapsBroker'            'Downloaded Maps Manager'
    Disable-ServiceSafe 'RetailDemo'            'Retail Demo Service'
    Disable-ServiceSafe 'wisvc'                 'Windows Insider Service'
    Disable-ServiceSafe 'WMPNetworkSvc'         'Windows Media Player Sharing'
    Disable-ServiceSafe 'icssvc'                'Mobile Hotspot Service'
    Disable-ServiceSafe 'PhoneSvc'              'Phone Service'
    Disable-ServiceSafe 'WpcMonSvc'             'Parental Controls'
    Write-Log 'Service optimization complete' 'SUCCESS'
}

# ============================================================================
# Category 3: Privacy and Lockdown
# ============================================================================
function Invoke-PrivacyLockdown {
    Write-Host ''
    Write-Host ($cOrange + '  ■ ' + $cWhite + $cBold + 'Executing: Privacy and Lockdown' + $cReset)
    # Telemetry
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
    # Activity and content delivery
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-310093Enabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338393Enabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353694Enabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353696Enabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SystemPaneSuggestionsEnabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SoftLandingEnabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SilentInstalledAppsEnabled' 0
    # Feedback
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules' 'PeriodInNanoSeconds' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
    # ARSO
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'DisableAutomaticRestartSignOn' 1
    # Spotlight and lock screen ads
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'RotatingLockScreenEnabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'RotatingLockScreenOverlayEnabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsSpotlightFeatures' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableThirdPartySuggestions' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338387Enabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_IrisRecommendations' 0
    # Hardware access lockdown
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsAccessMicrophone' 2
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsAccessCamera' 2
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\graphicsCaptureProgrammatic' 'Value' 'Deny' 'String'
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\graphicsCaptureProgrammatic' 'Value' 'Deny' 'String'
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\graphicsCaptureWithoutBorder' 'Value' 'Deny' 'String'
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\graphicsCaptureWithoutBorder' 'Value' 'Deny' 'String'
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsAccessDiagnosticInfo' 2
    # Find My Device
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice' 'AllowFindMyDevice' 0
    # Remote Assistance
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance' 'fAllowToGetHelp' 0
    # WiFi Sense auto-connect
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config' 'AutoConnectAllowedOEM' 0
    # Cloud Backup
    Disable-ServiceSafe 'wbengine'             'Block Level Backup Engine'
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableCloudOptimizedContent' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudExperienceHost\Intent\SettingsSync' 'SettingsSyncEnabled' 0
    # Edge background
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0
    # Telemetry scheduled tasks
    $tasks = @(
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'
        '\Microsoft\Windows\Application Experience\ProgramDataUpdater'
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'
        '\Microsoft\Windows\Autochk\Proxy'
        '\Microsoft\Windows\MicrosoftEdgeUpdate\MicrosoftEdgeUpdateTaskMachineCore'
        '\Microsoft\Windows\MicrosoftEdgeUpdate\MicrosoftEdgeUpdateTaskMachineUA'
    )
    foreach ($task in $tasks) {
        schtasks /Change /TN $task /Disable 2>$null
        if ($LASTEXITCODE -eq 0) { Write-Log ('Disabled task: ' + $task) 'SUCCESS' }
        else { Write-Log ('Task not found or already disabled: ' + $task) 'WARN' }
    }
    Write-Log 'Privacy and lockdown complete' 'SUCCESS'
}

# ============================================================================
# Category 4: Bloatware and OneDrive Removal
# ============================================================================
function Invoke-RemoveBloatware {
    Write-Host ''
    Write-Host ($cOrange + '  ■ ' + $cWhite + $cBold + 'Executing: Bloatware and OneDrive Removal' + $cReset)
    $bloatApps = @(
        '*Microsoft.BingNews*'
        '*Microsoft.BingWeather*'
        '*Microsoft.BingFinance*'
        '*Microsoft.BingSports*'
        '*Microsoft.GetHelp*'
        '*Microsoft.Getstarted*'
        '*Microsoft.MicrosoftOfficeHub*'
        '*Microsoft.MicrosoftSolitaireCollection*'
        '*Microsoft.People*'
        '*Microsoft.PowerAutomateDesktop*'
        '*Microsoft.Todos*'
        '*Microsoft.WindowsFeedbackHub*'
        '*Microsoft.WindowsMaps*'
        '*Microsoft.ZuneMusic*'
        '*Microsoft.ZuneVideo*'
        '*Microsoft.YourPhone*'
        '*Microsoft.WindowsCommunicationsApps*'
        '*Microsoft.MixedReality.Portal*'
        '*Clipchamp.Clipchamp*'
        '*MicrosoftTeams*'
        '*Microsoft.OutlookForWindows*'
        '*Microsoft.ScreenSketch*'
        '*Microsoft.Windows.DevHome*'
    )
    foreach ($app in $bloatApps) { Remove-AppxSafe $app }
    # Xbox appx packages
    $xboxApps = @(
        '*Microsoft.GamingApp*'
        '*Microsoft.XboxGameOverlay*'
        '*Microsoft.XboxGamingOverlay*'
        '*Microsoft.XboxIdentityProvider*'
        '*Microsoft.XboxSpeechToTextOverlay*'
        '*Microsoft.Xbox.TCUI*'
    )
    foreach ($app in $xboxApps) { Remove-AppxSafe $app }
    # Widgets
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0
    Write-Log 'Widgets disabled' 'SUCCESS'
    # OneDrive removal
    Write-Log 'Removing OneDrive...' 'INFO'
    Stop-Process -Name 'OneDrive' -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    $odPaths = @(
        (Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe')
        (Join-Path $env:SystemRoot 'SysWOW64\OneDriveSetup.exe')
    )
    foreach ($odp in $odPaths) {
        if (Test-Path $odp) {
            Start-Process $odp -ArgumentList '/uninstall' -Wait -ErrorAction SilentlyContinue
            Write-Log ('OneDrive uninstaller ran: ' + $odp) 'SUCCESS'
        }
    }
    $odFolders = @(
        (Join-Path $env:USERPROFILE 'OneDrive')
        (Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive')
        (Join-Path $env:ProgramData 'Microsoft OneDrive')
    )
    foreach ($odf in $odFolders) {
        if (Test-Path $odf) {
            Remove-Item $odf -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log ('Removed folder: ' + $odf) 'SUCCESS'
        }
    }
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSyncNGSC' 1
    Set-RegistryValue 'HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' 'System.IsPinnedToNameSpaceTree' 0
    Set-RegistryValue 'HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' 'System.IsPinnedToNameSpaceTree' 0
    $odTasks = @(
        '\Microsoft\Windows\OneDrive\OneDriveStandaloneUpdate'
        '\Microsoft\Windows\OneDrive\OneDriveUpdate'
    )
    foreach ($task in $odTasks) {
        schtasks /Change /TN $task /Disable 2>$null
        if ($LASTEXITCODE -eq 0) { Write-Log ('Disabled task: ' + $task) 'SUCCESS' }
    }
    Write-Log 'Bloatware and OneDrive removal complete' 'SUCCESS'
}

# ============================================================================
# Category 5: Performance and Update Control
# ============================================================================
function Invoke-PerformanceUpdates {
    Write-Host ''
    Write-Host ($cOrange + '  ■ ' + $cWhite + $cBold + 'Executing: Performance and Update Control' + $cReset)
    # Boot
    bcdedit /timeout 3 | Out-Null
    Write-Log 'Boot timeout set to 3 seconds' 'SUCCESS'
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0
    # Memory
    Disable-ServiceSafe 'SysMain'              'SysMain / Superfetch'
    dism /online /Set-ReservedStorageState /State:Disabled 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Log 'Reserved Storage disabled - ~7GB reclaimed' 'SUCCESS' }
    else { Write-Log 'Reserved Storage already disabled or not available' 'WARN' }
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground' 2
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'AllowClipboardHistory' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'AllowCrossDeviceClipboard' 0
    # CPU scheduling
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 38
    # Disable power throttling
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1
    Write-Log 'Power throttling disabled' 'SUCCESS'
    # Gaming - Game DVR / Bar
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
    Set-RegistryValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
    # Fullscreen optimizations bypass
    Set-RegistryValue 'HKCU:\System\GameConfigStore' 'GameDVR_FSEBehaviorMode' 2
    Set-RegistryValue 'HKCU:\System\GameConfigStore' 'GameDVR_DXGIHonorFSEWindowsCompatible' 1
    Set-RegistryValue 'HKCU:\System\GameConfigStore' 'GameDVR_HonorUserFSEBehaviorMode' 1
    # Enable Hardware-Accelerated GPU Scheduling (HAGS) - AMD and NVIDIA
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2
    Write-Log 'Hardware-Accelerated GPU Scheduling enabled (requires reboot)' 'SUCCESS'
    # Disable Multi-Plane Overlay (MPO) - fixes stutter on AMD and NVIDIA
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode' 5
    Write-Log 'Multi-Plane Overlay disabled (stutter fix)' 'SUCCESS'
    # Disk I/O
    fsutil behavior set disablelastaccess 1 2>$null
    Write-Log 'NTFS last access timestamps disabled' 'SUCCESS'
    fsutil behavior set disable8dot3 1 2>$null
    Write-Log '8.3 short filename creation disabled' 'SUCCESS'
    # Network
    $ifPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
    $interfaces = Get-ChildItem $ifPath -ErrorAction SilentlyContinue
    $nagleCount = 0
    foreach ($iface in $interfaces) {
        $ip = (Get-ItemProperty $iface.PSPath -ErrorAction SilentlyContinue).IPAddress
        if ($ip) {
            Set-ItemProperty $iface.PSPath -Name 'TcpAckFrequency' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty $iface.PSPath -Name 'TCPNoDelay' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            $nagleCount++
        }
    }
    Write-Log ('Nagle disabled on ' + $nagleCount + ' network interfaces') 'SUCCESS'
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'NetworkThrottlingIndex' 0xFFFFFFFF
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'GPU Priority' 8
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'Priority' 6
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'Scheduling Category' 'High' 'String'
    # Power plan - Ultimate Performance
    $ultGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
    powercfg /duplicatescheme $ultGuid 2>$null
    $dupOutput = powercfg /list 2>&1
    if ($dupOutput -match $ultGuid) {
        powercfg /setactive $ultGuid 2>$null
        Write-Log 'Power plan set to Ultimate Performance' 'SUCCESS'
    }
    else {
        # Fallback to High Performance if Ultimate not available
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
        if ($LASTEXITCODE -ne 0) {
            powercfg /duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
            powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
        }
        Write-Log 'Ultimate Performance not available - using High Performance' 'WARN'
    }
    # Sleep and display timeouts
    powercfg /change standby-timeout-ac 0 2>$null
    powercfg /change standby-timeout-dc 0 2>$null
    powercfg /change hibernate-timeout-ac 0 2>$null
    powercfg /change hibernate-timeout-dc 0 2>$null
    powercfg /change monitor-timeout-ac 60 2>$null
    powercfg /change monitor-timeout-dc 60 2>$null
    Write-Log 'Sleep disabled, display timeout 60 min' 'SUCCESS'
    # Connected Standby
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'CsEnabled' 0
    Write-Log 'Connected Standby disabled' 'SUCCESS'
    # Storage Sense
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' 'StoragePoliciesNotified' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01' 0
    Write-Log 'Storage Sense disabled' 'SUCCESS'
    # Delivery Optimization
    Disable-ServiceSafe 'DoSvc'                'Delivery Optimization'
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' 'DODownloadMode' 0
    Write-Log 'Delivery Optimization disabled' 'SUCCESS'
    # Windows Update
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'AUOptions' 2
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoUpdate' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoRebootWithLoggedOnUsers' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'AlwaysAutoRebootAtScheduledTime' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'SetComplianceDeadline' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'SetAutoRestartNotificationDisable' 0
    powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 0 2>$null
    powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 0 2>$null
    powercfg /SETACTIVE SCHEME_CURRENT 2>$null
    Write-Log 'Windows Update set to notify only - auto-reboot disabled' 'SUCCESS'
    # Temp cleanup
    $tempPaths = @($env:TEMP, (Join-Path $env:WINDIR 'Temp'), (Join-Path $env:WINDIR 'Prefetch'))
    foreach ($p in $tempPaths) {
        if (Test-Path $p) {
            $count = (Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue).Count
            Remove-Item (Join-Path $p '*') -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log ('Cleaned ' + $count + ' items from ' + $p) 'SUCCESS'
        }
    }
    Write-Log 'Performance and update control complete' 'SUCCESS'
}

# ============================================================================
# Category 6: Security Hardening
# ============================================================================
function Invoke-SecurityHardening {
    Write-Host ''
    Write-Host ($cOrange + '  ■ ' + $cWhite + $cBold + 'Executing: Security Hardening' + $cReset)
    # SMBv1
    Write-Log 'Removing SMBv1 protocol...' 'INFO'
    dism /online /Disable-Feature /FeatureName:'SMB1Protocol' /NoRestart 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Log 'SMBv1 removed via DISM' 'SUCCESS' }
    else { Write-Log 'SMBv1 already removed or not available' 'WARN' }
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' 'SMB1' 0
    # NetBIOS over TCP/IP
    $wmiAdapters = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE' -ErrorAction SilentlyContinue
    $nbCount = 0
    foreach ($adapter in $wmiAdapters) {
        $adapter.SetTcpipNetbios(2) | Out-Null
        $nbCount++
    }
    Write-Log ('NetBIOS over TCP/IP disabled on ' + $nbCount + ' adapters') 'SUCCESS'
    # LLMNR
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' 'EnableMulticast' 0
    Write-Log 'LLMNR disabled' 'SUCCESS'
    # WPAD
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad' 'WpadOverride' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad' 'WpadOverride' 1
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Services\WinHttpAutoProxySvc' 'Start' 4
    Write-Log 'WPAD disabled' 'SUCCESS'
    # WDigest
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' 'UseLogonCredential' 0
    Write-Log 'WDigest plaintext caching disabled' 'SUCCESS'
    # Anonymous enumeration
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RestrictAnonymousSAM' 1
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RestrictAnonymous' 1
    Write-Log 'Anonymous SAM/share enumeration restricted' 'SUCCESS'
    # PowerShell logging
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' 'EnableScriptBlockLogging' 1
    Write-Log 'PowerShell Script Block Logging enabled' 'SUCCESS'
    # Remote Desktop
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections' 1
    Write-Log 'Remote Desktop inbound disabled' 'SUCCESS'
    Write-Log 'Security hardening complete' 'SUCCESS'
}

# ============================================================================
# Main Menu
# ============================================================================
function Show-Menu {
    Show-Banner
    Write-Host ($cWhite + '  Select optimizations (comma-separated, e.g. 1,3,5):' + $cReset)
    Write-Host ''
    Write-Host ($cOrange + '    [' + $cYellow + '1' + $cOrange + ']  ' + $cWhite + 'Remove AI / Copilot' + $cReset)
    Write-Host ($cOrange + '    [' + $cYellow + '2' + $cOrange + ']  ' + $cWhite + 'Disable Unnecessary Services' + $cReset)
    Write-Host ($cOrange + '    [' + $cYellow + '3' + $cOrange + ']  ' + $cWhite + 'Privacy and Lockdown' + $cReset)
    Write-Host ($cOrange + '    [' + $cYellow + '4' + $cOrange + ']  ' + $cWhite + 'Bloatware and OneDrive Removal' + $cReset)
    Write-Host ($cOrange + '    [' + $cYellow + '5' + $cOrange + ']  ' + $cWhite + 'Performance and Update Control' + $cReset)
    Write-Host ($cOrange + '    [' + $cYellow + '6' + $cOrange + ']  ' + $cWhite + 'Security Hardening' + $cReset)
    Write-Host ''
    Write-Host ($cBlue  + '    [' + $cGreen  + 'A' + $cBlue  + ']  ' + $cGreen + $cBold + 'Run ALL' + $cReset)
    Write-Host ($cDkGrey + '    [' + $cRed   + 'Q' + $cDkGrey + ']  ' + $cGrey + 'Quit' + $cReset)
    Write-Host ''
}
function Invoke-Main {
    Show-Menu
    $choice = Read-Host -Prompt '  Enter selection'
    if ($choice -eq 'Q' -or $choice -eq 'q') {
        Write-Host ''
        Write-Host ($cGrey + '  Exiting. No changes made.' + $cReset)
        return
    }
    # Dispatch
    $map = @{
        '1' = { Invoke-RemoveAICopilot }
        '2' = { Invoke-DisableServices }
        '3' = { Invoke-PrivacyLockdown }
        '4' = { Invoke-RemoveBloatware }
        '5' = { Invoke-PerformanceUpdates }
        '6' = { Invoke-SecurityHardening }
    }
    $catNames = @{
        '1' = 'Remove AI / Copilot'
        '2' = 'Disable Unnecessary Services'
        '3' = 'Privacy and Lockdown'
        '4' = 'Bloatware and OneDrive Removal'
        '5' = 'Performance and Update Control'
        '6' = 'Security Hardening'
    }
    if ($choice -eq 'A' -or $choice -eq 'a') {
        $selections = @('1','2','3','4','5','6')
    }
    else {
        $selections = $choice -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $map.ContainsKey($_) }
    }
    if ($selections.Count -eq 0) {
        Write-Host ''
        Write-Host ($cRed + '  Invalid selection.' + $cReset)
        return
    }
    # Show descriptions for selected categories
    foreach ($s in $selections) {
        Show-CategoryInfo $s $catNames[$s]
    }
    # Disclaimer
    Write-Host ''
    Write-Host ($cDkGrey + '  ──────────────────────────────────────────────────────' + $cReset)
    Write-Host ($cYellow + '  CAUTION: ' + $cGrey + 'This script modifies Windows system settings,' + $cReset)
    Write-Host ($cGrey + '  services, and registry values. Changes are applied at your' + $cReset)
    Write-Host ($cGrey + '  own risk. A system restore point is recommended before' + $cReset)
    Write-Host ($cGrey + '  proceeding. Not all changes may suit every configuration.' + $cReset)
    Write-Host ($cDkGrey + '  ──────────────────────────────────────────────────────' + $cReset)
    Write-Host ''
    $proceed = Read-Host -Prompt '  Proceed with the above changes? Y or N'
    if ($proceed -ne 'Y' -and $proceed -ne 'y') {
        Write-Host ''
        Write-Host ($cGrey + '  Cancelled. No changes made.' + $cReset)
        return
    }
    # Optional Restore Point
    Write-Host ''
    $rp = Read-Host -Prompt '  Create a System Restore Point first? Y or N'
    if ($rp -eq 'Y' -or $rp -eq 'y') {
        Write-Host ''
        Write-Host ($cBlue + '  ' + $cBold + 'Creating System Restore Point...' + $cReset)
        try {
            Enable-ComputerRestore -Drive ($env:SystemDrive + '\') -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description 'Pre-WinOpt-v3.1' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
            Write-Log 'Restore point created' 'SUCCESS'
        }
        catch {
            Write-Log ('Could not create restore point - ' + $_) 'WARN'
        }
    }
    else {
        Write-Log 'Restore point skipped by user' 'INFO'
    }
    # Execute
    foreach ($s in $selections) {
        & $map[$s]
    }
    # Summary
    Write-Host ''
    Write-Host ($cDkBlue + '  ░▒▓' + $cBlue + '█████████████████████████████████████████████████████' + $cDkBlue + '▓▒░' + $cReset)
    Write-Host ($cDkBlue + '  ░▒▓' + $cBlue + '█' + $cReset + '                                                   ' + $cBlue + '█' + $cDkBlue + '▓▒░' + $cReset)
    Write-Host ($cDkBlue + '  ░▒▓' + $cBlue + '█' + $cReset + $cGreen + $cBold + '        ✓  O P T I M I Z A T I O N   D O N E        ' + $cReset + $cBlue + '█' + $cDkBlue + '▓▒░' + $cReset)
    Write-Host ($cDkBlue + '  ░▒▓' + $cBlue + '█' + $cReset + '                                                   ' + $cBlue + '█' + $cDkBlue + '▓▒░' + $cReset)
    Write-Host ($cDkBlue + '  ░▒▓' + $cBlue + '█████████████████████████████████████████████████████' + $cDkBlue + '▓▒░' + $cReset)
    Write-Host ''
    Write-Host ($cGrey + '  Log: ' + $cWhite + $LogFile + $cReset)
    Write-Host ($cYellow + '  A restart is recommended to apply all changes.' + $cReset)
    Write-Host ''
    $restart = Read-Host -Prompt '  Restart now? Y or N'
    if ($restart -eq 'Y' -or $restart -eq 'y') {
        Restart-Computer -Force
    }
}
Invoke-Main
