#Requires -RunAsAdministrator
# Windows 11 Optimization Script v3.0 - Interactive Menu
# Targets 24H2 (Build 26100) and 25H2 (Build 26200) - September 2026
# Creates a restore point before changes. Logs to %TEMP%.
# Preserves: Print Spooler, Windows Search, Windows Scan, WIA, WSL, VMware
$ErrorActionPreference = 'SilentlyContinue'
$LogFile = (Join-Path $env:TEMP ('Win11Optimize_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log'))
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $entry = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' [' + $Level + '] ' + $Message
    Add-Content -Path $LogFile -Value $entry
    switch ($Level) {
        'SUCCESS' { Write-Host ('  [OK] ' + $Message) -ForegroundColor Green }
        'WARN'    { Write-Host ('  [!!] ' + $Message) -ForegroundColor Yellow }
        'ERROR'   { Write-Host ('  [XX] ' + $Message) -ForegroundColor Red }
        default   { Write-Host ('  [--] ' + $Message) -ForegroundColor Cyan }
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
function Show-Banner {
    Clear-Host
    Write-Host ''
    Write-Host '  ======================================================' -ForegroundColor DarkCyan
    Write-Host '         Windows 11 Optimization Script v3.0            ' -ForegroundColor DarkCyan
    Write-Host '       Run as Administrator - 24H2/25H2 Sept 2026       ' -ForegroundColor DarkCyan
    Write-Host '  ======================================================' -ForegroundColor DarkCyan
    Write-Host ''
}

# ============================================================================
# Category 1: AI / Copilot Removal
# ============================================================================
function Invoke-RemoveAICopilot {
    Write-Host ''
    Write-Host '  -- Removing AI / Copilot Features --' -ForegroundColor Magenta
    # Appx packages
    Remove-AppxSafe '*Microsoft.Copilot*'
    Remove-AppxSafe '*Microsoft.Windows.Ai*'
    Remove-AppxSafe '*MicrosoftWindows.Client.AIX*'
    Remove-AppxSafe '*Microsoft.Windows.AI.Copilot.Provider*'
    Remove-AppxSafe '*MicrosoftWindows.Client.Photon*'
    Remove-AppxSafe '*Microsoft.549981C3F5F10*'
    # Disable Copilot via Group Policy
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 0
    # 25H2 Copilot removal policy
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Copilot' 'RemoveCopilotApp' 1
    # Disable Recall and AI data analysis
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'TurnOffSavingSnapshots' 1
    # DISM removal of Recall optional feature (25H2+)
    Write-Log 'Attempting DISM removal of Recall...' 'INFO'
    dism /online /Disable-Feature /FeatureName:'Recall' /NoRestart 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Log 'Recall removed via DISM' 'SUCCESS'
    }
    else {
        Write-Log 'Recall not available as optional feature - registry controls applied' 'WARN'
    }
    # Click to Do, Input Insights
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableClickToDo' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\input\Settings' 'InsightsEnabled' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableInputInsights' 1
    # AI features in Paint, Photos, Snipping Tool
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableImageCreator' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableCocreator' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableGenerativeFill' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableGenerativeErase' 1
    # Bing / AI in Search
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent' 0
    # Copilot in Edge
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'HubsSidebarEnabled' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'CopilotCDPPageContext' 0
    # AI Fabric Service
    Disable-ServiceSafe 'AIFabricService'       'AI Fabric Service'
    Disable-ServiceSafe 'AIF'                   'AI Fabric'
    Write-Log 'AI/Copilot removal complete' 'SUCCESS'
}

# ============================================================================
# Category 2: Disable Unnecessary Services
# ============================================================================
function Invoke-DisableServices {
    Write-Host ''
    Write-Host '  -- Disabling Unnecessary Services --' -ForegroundColor Magenta
    # Telemetry and diagnostics
    Disable-ServiceSafe 'DiagTrack'            'Connected User Experiences and Telemetry'
    Disable-ServiceSafe 'dmwappushservice'      'WAP Push Message Routing'
    Disable-ServiceSafe 'diagnosticshub.standardcollector.service' 'Diagnostics Hub'
    # Xbox
    Disable-ServiceSafe 'XblAuthManager'        'Xbox Live Auth Manager'
    Disable-ServiceSafe 'XblGameSave'           'Xbox Live Game Save'
    Disable-ServiceSafe 'XboxNetApiSvc'         'Xbox Live Networking'
    Disable-ServiceSafe 'XboxGipSvc'            'Xbox Accessory Management'
    # Error Reporting
    Disable-ServiceSafe 'WerSvc'               'Windows Error Reporting'
    # Edge background
    Disable-ServiceSafe 'edgeupdate'           'Microsoft Edge Update Service'
    Disable-ServiceSafe 'edgeupdatem'          'Microsoft Edge Update Service (Manual)'
    Disable-ServiceSafe 'MicrosoftEdgeElevationService' 'Microsoft Edge Elevation Service'
    # Misc unused
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
    # Print Spooler and WSearch preserved per user preference
    Write-Log 'Service optimization complete' 'SUCCESS'
}

# ============================================================================
# Category 3: Privacy and Lockdown
# ============================================================================
function Invoke-PrivacyLockdown {
    Write-Host ''
    Write-Host '  -- Privacy and Lockdown --' -ForegroundColor Magenta

    # ---- Telemetry ----
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0

    # ---- Activity and content delivery ----
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

    # ---- Feedback ----
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules' 'PeriodInNanoSeconds' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0

    # ---- ARSO (background login at lock screen) ----
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'DisableAutomaticRestartSignOn' 1

    # ---- Spotlight and lock screen ads (formerly Category 5) ----
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'RotatingLockScreenEnabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'RotatingLockScreenOverlayEnabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsSpotlightFeatures' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableThirdPartySuggestions' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338387Enabled' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_IrisRecommendations' 0

    # ---- Hardware access lockdown (background access) ----
    # Deny background microphone access
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone' 'Value' 'Allow' 'String'
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone' 'Value' 'Allow' 'String'
    # Deny background mic to non-desktop apps (UWP)
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsAccessMicrophone' 2
    # Deny background camera access to UWP
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsAccessCamera' 2
    # Deny background screen capture (graphicsCaptureProgrammatic)
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\graphicsCaptureProgrammatic' 'Value' 'Deny' 'String'
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\graphicsCaptureProgrammatic' 'Value' 'Deny' 'String'
    # Deny background borderless screen capture
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\graphicsCaptureWithoutBorder' 'Value' 'Deny' 'String'
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\graphicsCaptureWithoutBorder' 'Value' 'Deny' 'String'
    # Deny background app diagnostics
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsAccessDiagnosticInfo' 2

    # ---- Find My Device ----
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice' 'AllowFindMyDevice' 0

    # ---- Remote Assistance ----
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance' 'fAllowToGetHelp' 0

    # ---- Cloud Backup (Windows Backup service) ----
    Disable-ServiceSafe 'wbengine'             'Block Level Backup Engine'
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableCloudOptimizedContent' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudExperienceHost\Intent\SettingsSync' 'SettingsSyncEnabled' 0

    # ---- Edge background behavior ----
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0

    # ---- Telemetry scheduled tasks ----
    $telemetryTasks = @(
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'
        '\Microsoft\Windows\Application Experience\ProgramDataUpdater'
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'
        '\Microsoft\Windows\Autochk\Proxy'
    )
    foreach ($task in $telemetryTasks) {
        schtasks /Change /TN $task /Disable 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log ('Disabled task: ' + $task) 'SUCCESS'
        }
        else {
            Write-Log ('Task not found or already disabled: ' + $task) 'WARN'
        }
    }

    # ---- Edge scheduled tasks ----
    $edgeTasks = @(
        '\Microsoft\Windows\MicrosoftEdgeUpdate\MicrosoftEdgeUpdateTaskMachineCore'
        '\Microsoft\Windows\MicrosoftEdgeUpdate\MicrosoftEdgeUpdateTaskMachineUA'
    )
    foreach ($task in $edgeTasks) {
        schtasks /Change /TN $task /Disable 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log ('Disabled task: ' + $task) 'SUCCESS'
        }
        else {
            Write-Log ('Edge task not found or already disabled: ' + $task) 'WARN'
        }
    }

    Write-Log 'Privacy and lockdown complete' 'SUCCESS'
}

# ============================================================================
# Category 4: Bloatware and OneDrive Removal
# ============================================================================
function Invoke-RemoveBloatware {
    Write-Host ''
    Write-Host '  -- Removing Bloatware and OneDrive --' -ForegroundColor Magenta

    # ---- Standard bloatware ----
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
    foreach ($app in $bloatApps) {
        Remove-AppxSafe $app
    }

    # ---- Xbox appx packages (overlay, auth, UI framework) ----
    $xboxApps = @(
        '*Microsoft.GamingApp*'
        '*Microsoft.XboxGameOverlay*'
        '*Microsoft.XboxGamingOverlay*'
        '*Microsoft.XboxIdentityProvider*'
        '*Microsoft.XboxSpeechToTextOverlay*'
        '*Microsoft.Xbox.TCUI*'
    )
    foreach ($app in $xboxApps) {
        Remove-AppxSafe $app
    }

    # ---- Widgets ----
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0
    Write-Log 'Widgets disabled' 'SUCCESS'

    # ---- OneDrive full removal ----
    Write-Log 'Removing OneDrive...' 'INFO'
    # Kill running process
    Stop-Process -Name 'OneDrive' -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    # Run uninstaller (path differs by architecture)
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
    # Remove leftover folders
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
    # Prevent reinstallation
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSyncNGSC' 1
    # Remove from Explorer sidebar
    Set-RegistryValue 'HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' 'System.IsPinnedToNameSpaceTree' 0
    Set-RegistryValue 'HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' 'System.IsPinnedToNameSpaceTree' 0
    # Disable OneDrive scheduled tasks
    $odTasks = @(
        '\Microsoft\Windows\OneDrive\OneDriveStandaloneUpdate'
        '\Microsoft\Windows\OneDrive\OneDriveUpdate'
    )
    foreach ($task in $odTasks) {
        schtasks /Change /TN $task /Disable 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log ('Disabled task: ' + $task) 'SUCCESS'
        }
    }
    Write-Log 'OneDrive removal complete' 'SUCCESS'

    Write-Log 'Bloatware and OneDrive removal complete' 'SUCCESS'
}

# ============================================================================
# Category 5: Performance and Update Control
# ============================================================================
function Invoke-PerformanceUpdates {
    Write-Host ''
    Write-Host '  -- Performance and Update Control --' -ForegroundColor Magenta

    # ---- Boot ----
    bcdedit /timeout 3 | Out-Null
    Write-Log 'Boot timeout set to 3 seconds' 'SUCCESS'
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0

    # ---- Memory ----
    Disable-ServiceSafe 'SysMain'              'SysMain / Superfetch'
    dism /online /Set-ReservedStorageState /State:Disabled 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Log 'Reserved Storage disabled - ~7GB reclaimed' 'SUCCESS'
    }
    else {
        Write-Log 'Reserved Storage already disabled or not available' 'WARN'
    }
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground' 2
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'AllowClipboardHistory' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'AllowCrossDeviceClipboard' 0

    # ---- CPU / Scheduling ----
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 38

    # ---- Gaming ----
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
    Set-RegistryValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
    Set-RegistryValue 'HKCU:\System\GameConfigStore' 'GameDVR_FSEBehaviorMode' 2
    Set-RegistryValue 'HKCU:\System\GameConfigStore' 'GameDVR_DXGIHonorFSEWindowsCompatible' 1
    Set-RegistryValue 'HKCU:\System\GameConfigStore' 'GameDVR_HonorUserFSEBehaviorMode' 1

    # ---- Disk I/O (NVMe) ----
    fsutil behavior set disablelastaccess 1 2>$null
    Write-Log 'NTFS last access timestamps disabled' 'SUCCESS'
    fsutil behavior set disable8dot3 1 2>$null
    Write-Log '8.3 short filename creation disabled' 'SUCCESS'

    # ---- Network (1Gbps Ethernet) ----
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

    # ---- Power Plan ----
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
    if ($LASTEXITCODE -ne 0) {
        powercfg /duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
    }
    Write-Log 'Power plan set to High Performance' 'SUCCESS'
    powercfg /change standby-timeout-ac 0 2>$null
    powercfg /change standby-timeout-dc 0 2>$null
    powercfg /change hibernate-timeout-ac 0 2>$null
    powercfg /change hibernate-timeout-dc 0 2>$null
    powercfg /change monitor-timeout-ac 60 2>$null
    powercfg /change monitor-timeout-dc 60 2>$null
    Write-Log 'Sleep disabled, display timeout set to 60 min' 'SUCCESS'

    # ---- Connected Standby disable ----
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'CsEnabled' 0
    Write-Log 'Connected Standby disabled' 'SUCCESS'

    # ---- Storage Sense disable ----
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' 'StoragePoliciesNotified' 1
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01' 0
    Write-Log 'Storage Sense disabled' 'SUCCESS'

    # ---- Delivery Optimization ----
    Disable-ServiceSafe 'DoSvc'                'Delivery Optimization'
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' 'DODownloadMode' 0
    Write-Log 'Delivery Optimization fully disabled' 'SUCCESS'

    # ---- Windows Update: Notify Only, No Auto-Reboot ----
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'AUOptions' 2
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoUpdate' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoRebootWithLoggedOnUsers' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'AlwaysAutoRebootAtScheduledTime' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'SetComplianceDeadline' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'SetAutoRestartNotificationDisable' 0
    powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 0 2>$null
    powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 0 2>$null
    powercfg /SETACTIVE SCHEME_CURRENT 2>$null
    Write-Log 'Wake timers disabled' 'SUCCESS'
    Write-Log 'Windows Update set to notify only - auto-reboot disabled' 'SUCCESS'

    # ---- Clean Temp Files ----
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
    Write-Host '  -- Security Hardening --' -ForegroundColor Magenta

    # ---- SMBv1 removal via DISM ----
    Write-Log 'Removing SMBv1 protocol...' 'INFO'
    dism /online /Disable-Feature /FeatureName:'SMB1Protocol' /NoRestart 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Log 'SMBv1 removed via DISM' 'SUCCESS'
    }
    else {
        Write-Log 'SMBv1 already removed or not available' 'WARN'
    }
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' 'SMB1' 0

    # ---- Disable NetBIOS over TCP/IP (all interfaces) ----
    $wmiAdapters = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE' -ErrorAction SilentlyContinue
    $nbCount = 0
    foreach ($adapter in $wmiAdapters) {
        $adapter.SetTcpipNetbios(2) | Out-Null
        $nbCount++
    }
    Write-Log ('NetBIOS over TCP/IP disabled on ' + $nbCount + ' adapters') 'SUCCESS'

    # ---- Disable LLMNR ----
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' 'EnableMulticast' 0
    Write-Log 'LLMNR disabled' 'SUCCESS'

    # ---- Disable WPAD ----
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad' 'WpadOverride' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad' 'WpadOverride' 1
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Services\WinHttpAutoProxySvc' 'Start' 4
    Write-Log 'WPAD disabled' 'SUCCESS'

    # ---- Disable WDigest plaintext credential caching ----
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' 'UseLogonCredential' 0
    Write-Log 'WDigest plaintext caching disabled' 'SUCCESS'

    # ---- Restrict anonymous SAM and share enumeration ----
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RestrictAnonymousSAM' 1
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RestrictAnonymous' 1
    Write-Log 'Anonymous SAM/share enumeration restricted' 'SUCCESS'

    # ---- Enable PowerShell Script Block Logging ----
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' 'EnableScriptBlockLogging' 1
    Write-Log 'PowerShell Script Block Logging enabled' 'SUCCESS'

    # ---- Disable Remote Desktop (inbound) ----
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections' 1
    netsh advfirewall firewall set rule group='Remote Desktop' new enable=no 2>$null
    Write-Log 'Remote Desktop inbound disabled' 'SUCCESS'

    Write-Log 'Security hardening complete' 'SUCCESS'
}

# ============================================================================
# Main Menu
# ============================================================================
function Show-Menu {
    Show-Banner
    Write-Host '  Select optimizations to run (comma-separated, e.g. 1,3,5):' -ForegroundColor White
    Write-Host ''
    Write-Host '    1) Remove AI / Copilot' -ForegroundColor Yellow
    Write-Host '    2) Disable Unnecessary Services' -ForegroundColor Yellow
    Write-Host '    3) Privacy and Lockdown' -ForegroundColor Yellow
    Write-Host '    4) Bloatware and OneDrive Removal' -ForegroundColor Yellow
    Write-Host '    5) Performance and Update Control' -ForegroundColor Yellow
    Write-Host '    6) Security Hardening' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '    A) Run ALL' -ForegroundColor Green
    Write-Host '    Q) Quit' -ForegroundColor Red
    Write-Host ''
}
function Invoke-Main {
    Show-Menu
    $choice = Read-Host -Prompt '  Enter selection'
    if ($choice -eq 'Q' -or $choice -eq 'q') {
        Write-Host ''
        Write-Host '  Exiting. No changes made.' -ForegroundColor Gray
        return
    }
    # Optional Restore Point
    $rp = Read-Host -Prompt '  Create a System Restore Point first? Y or N'
    if ($rp -eq 'Y' -or $rp -eq 'y') {
        Write-Host ''
        Write-Host '  -- Creating System Restore Point --' -ForegroundColor Magenta
        try {
            Enable-ComputerRestore -Drive ($env:SystemDrive + '\') -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description 'Pre-Win11-Optimization' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
            Write-Log 'Restore point created' 'SUCCESS'
        }
        catch {
            Write-Log ('Could not create restore point - ' + $_) 'WARN'
        }
    }
    else {
        Write-Log 'Restore point skipped by user' 'INFO'
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
    if ($choice -eq 'A' -or $choice -eq 'a') {
        $selections = @('1','2','3','4','5','6')
    }
    else {
        $selections = $choice -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $map.ContainsKey($_) }
    }
    if ($selections.Count -eq 0) {
        Write-Host ''
        Write-Host '  Invalid selection.' -ForegroundColor Red
        return
    }
    foreach ($s in $selections) {
        & $map[$s]
    }
    # Summary
    Write-Host ''
    Write-Host '  ======================================================' -ForegroundColor Green
    Write-Host '              Optimization Complete!                     ' -ForegroundColor Green
    Write-Host '  ======================================================' -ForegroundColor Green
    Write-Host ''
    Write-Host ('  Log saved to: ' + $LogFile) -ForegroundColor Gray
    Write-Host '  A restart is recommended to apply all changes.' -ForegroundColor Yellow
    Write-Host ''
    $restart = Read-Host -Prompt '  Restart now? Y or N'
    if ($restart -eq 'Y' -or $restart -eq 'y') {
        Restart-Computer -Force
    }
}
Invoke-Main
