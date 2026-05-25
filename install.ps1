#Requires -RunAsAdministrator
<#
.SYNOPSIS
    AdShield Installer — Windows
.DESCRIPTION
    Installs the AdShield system-level ad blocker on Windows.
    Safe to run multiple times (idempotent).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Configuration ─────────────────────────────────────────────
$InstallDir   = "$env:ProgramFiles\adshield"
$InstallBin   = Join-Path $InstallDir 'adshield'
$ConfigDir    = Join-Path $env:USERPROFILE '.adshield'
$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Definition
$TaskName     = 'AdShield Weekly Update'

# ── Helpers ───────────────────────────────────────────────────
function Write-Banner {
    Write-Host ''
    Write-Host '     █████╗ ██████╗ ███████╗██╗  ██╗██╗███████╗██╗     ██████╗ ' -ForegroundColor Cyan
    Write-Host '    ██╔══██╗██╔══██╗██╔════╝██║  ██║██║██╔════╝██║     ██╔══██╗' -ForegroundColor Cyan
    Write-Host '    ███████║██║  ██║███████╗███████║██║█████╗  ██║     ██║  ██║' -ForegroundColor Cyan
    Write-Host '    ██╔══██║██║  ██║╚════██║██╔══██║██║██╔══╝  ██║     ██║  ██║' -ForegroundColor Cyan
    Write-Host '    ██║  ██║██████╔╝███████║██║  ██║██║███████╗███████╗██████╔╝' -ForegroundColor Cyan
    Write-Host '    ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚═════╝' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '    System-level ad blocker for your entire machine.' -ForegroundColor Cyan
    Write-Host ''
}

function Write-Info    { param([string]$Msg) Write-Host "[INFO]  $Msg" -ForegroundColor Blue }
function Write-Success { param([string]$Msg) Write-Host "[  OK]  $Msg" -ForegroundColor Green }
function Write-Warn    { param([string]$Msg) Write-Host "[WARN]  $Msg" -ForegroundColor Yellow }
function Write-Fail    { param([string]$Msg) Write-Host "[FAIL]  $Msg" -ForegroundColor Red; exit 1 }

# ── Main ──────────────────────────────────────────────────────
Write-Banner

# 1. Check for admin privileges
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal   = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Fail 'This installer must be run as Administrator. Right-click PowerShell and select "Run as Administrator".'
}
Write-Success 'Running with administrator privileges.'

# 2. Check for Python 3
Write-Info 'Checking for Python 3...'
$pythonCmd = $null
foreach ($cmd in @('python3', 'python', 'py')) {
    try {
        $ver = & $cmd --version 2>&1
        if ($ver -match 'Python 3') {
            $pythonCmd = $cmd
            break
        }
    } catch {
        continue
    }
}

if (-not $pythonCmd) {
    Write-Fail 'Python 3 is required but not found. Install it from https://www.python.org/downloads/'
}
Write-Success "Found $( & $pythonCmd --version 2>&1)"

# 3. Verify adshield script exists
$sourceScript = Join-Path $ScriptDir 'adshield'
if (-not (Test-Path $sourceScript)) {
    Write-Fail "Cannot find 'adshield' script in $ScriptDir. Make sure it is in the same directory as install.ps1."
}

# 4. Install to Program Files
Write-Info "Installing adshield to $InstallDir..."
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
Copy-Item -Path $sourceScript -Destination $InstallBin -Force

# Copy sources.json alongside the binary
$sourcesFile = Join-Path $ScriptDir 'sources.json'
if (Test-Path $sourcesFile) {
    Copy-Item -Path $sourcesFile -Destination (Join-Path $InstallDir 'sources.json') -Force
}
Write-Success "Installed to $InstallDir"

# 5. Add to PATH (Machine scope, idempotent)
Write-Info 'Updating system PATH...'
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
if ($machinePath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$machinePath;$InstallDir", 'Machine')
    $env:Path = "$env:Path;$InstallDir"
    Write-Success "Added $InstallDir to system PATH."
} else {
    Write-Warn "$InstallDir is already in PATH."
}

# 6. Create config directory
Write-Info "Creating config directory at $ConfigDir..."
if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

# Copy default sources.json to config dir if not present
$configSources = Join-Path $ConfigDir 'sources.json'
if ((Test-Path $sourcesFile) -and (-not (Test-Path $configSources))) {
    Copy-Item -Path $sourcesFile -Destination $configSources -Force
    Write-Success 'Copied default sources.json to config directory.'
} elseif (Test-Path $configSources) {
    Write-Warn 'sources.json already exists in config — keeping your version.'
}
Write-Success "Config directory ready: $ConfigDir"

# 7. Activate ad blocking
Write-Info 'Activating AdShield...'
try {
    & $pythonCmd $InstallBin activate
    Write-Success 'AdShield is now active!'
} catch {
    Write-Warn "Activation failed. You can retry with:  adshield activate"
}

# 8. Set up weekly Task Scheduler job
Write-Info 'Setting up weekly auto-update task...'
try {
    # Remove existing task if present (idempotent)
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    $action  = New-ScheduledTaskAction -Execute $pythonCmd -Argument "$InstallBin update"
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At '04:00'
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Description 'Updates AdShield blocklists weekly.' `
        -RunLevel Highest | Out-Null

    Write-Success "Registered scheduled task: '$TaskName' (Sundays at 04:00)"
} catch {
    Write-Warn "Could not create scheduled task: $_"
}

# ── Done ──────────────────────────────────────────────────────
Write-Host ''
Write-Host '  AdShield installation complete!' -ForegroundColor Green
Write-Host ''
Write-Info 'Useful commands:'
Write-Host '    adshield status       Show current status'
Write-Host '    adshield update       Update blocklists now'
Write-Host '    adshield whitelist    Manage whitelisted domains'
Write-Host '    adshield deactivate   Temporarily disable blocking'
Write-Host ''
Write-Info "To uninstall, run the uninstaller or remove $InstallDir manually."
Write-Host ''
