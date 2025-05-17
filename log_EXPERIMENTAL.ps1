# Script version:   2025-05-17 11:10
# Script author:    Barg0

# ---------------------------[ Parameters ]---------------------------

[bool]$log = $true                  # Set to $false to disable logging in shell
[bool]$enableLogFile = $true        # Set to $false to disable file output
[int]$platformType = 1              # 0 = Undefined | 1 = Microsoft Intune | 2 = N-able
[int]$scriptType = 0                # 0 = Script | 1 = Application | 2 = Compliance (valid only for Intune)

# Script-specific parameters (if $platformType = 1 and $scriptType = 0)
[int]$intuneScriptSubType = 1       # 1 = Platform Script | 2 = Remediation Script 
[int]$intuneRemediationType = 0     # 1 = Detection | 2 = Remediation (if $intuneScriptSubType = 2)

# Script-specific parameters (if scriptType = 0 or 2)
[string]$scriptName = "DefaultScriptName"

# Application-specific parameters (if scriptType = 1)
[string]$applicationName = "DefaultApplication"
[int]$applicationScriptSubType = 0  # 1 = Detection | 2 = Install | 3 = Uninstall

# Parameters for other Scripts
# [bool]$withVersionCheck = $false
# [string]$regDisplayName = ""
# [string]$regDisplayVersion = ""
# [string]$wingetAppID = ""

# ---------------------------[ Script Start Timestamp ]---------------------------



# ---------------------------[ Log Folder ]---------------------------

# Determine platform folder
$platformFolder = switch ($platformType) {
    1 { "IntuneLogs" }
    2 { "NableLogs" }
    default { "UndefinedLogs" }
}

# Determine script type folder, validating compatibility
$scriptFolder = switch ($scriptType) {
    0 { "Scripts" }
    1 { "Applications" }
    2 { if ($platformType -eq 1) { "Compliance" } else { "Undefined" } }
    default { "Undefined" }
}

# Adjust log folder and filename based on script and subtypes
if ($scriptType -eq 1) { # Application scripts
    $logFileDirectory = Join-Path "$env:ProgramData" $platformFolder $scriptFolder $applicationName
    $logFileName = switch ($applicationScriptSubType) {
        1 { "detection.log" }
        2 { "install.log" }
        3 { "uninstall.log" }
        default { "application.log" }
    }
    $logFile = Join-Path $logFileDirectory $logFileName
}
elseif ($scriptType -eq 2 -and $platformType -eq 1) { # Compliance scripts
    $logFileDirectory = Join-Path "$env:ProgramData" $platformFolder $scriptFolder
    $logFile = Join-Path $logFileDirectory "$scriptName.log"
}
elseif ($platformType -eq 1 -and $scriptType -eq 0) { # Intune Scripts
    switch ($intuneScriptSubType) {
        1 { # Platform script
            $logFileDirectory = Join-Path "$env:ProgramData" $platformFolder $scriptFolder
            $logFile = Join-Path $logFileDirectory "$scriptName.log"
        }
        2 { # Remediation script
            $logFileDirectory = Join-Path "$env:ProgramData" $platformFolder $scriptFolder $scriptName
            $logFile = switch ($intuneRemediationType) {
                1 { Join-Path $logFileDirectory "detection.log" }
                2 { Join-Path $logFileDirectory "remediation.log" }
                default { Join-Path $logFileDirectory "undefined.log" }
            }
        }
        default { # fallback to script naming
            $logFileDirectory = Join-Path "$env:ProgramData" $platformFolder $scriptFolder $scriptName
            $logFile = Join-Path $logFileDirectory "$scriptName.log"
        }
    }
} else {
    $logFileDirectory = Join-Path "$env:ProgramData" $platformFolder $scriptFolder $scriptName
    $logFile = Join-Path $logFileDirectory "$scriptName.log"
}

# Ensure the log directory exists
if ($enableLogFile -and -not (Test-Path $logFileDirectory)) {
    New-Item -ItemType Directory -Path $logFileDirectory -Force | Out-Null
}

# ---------------------------[ Logging Function ]---------------------------

# Function to write structured logs to file and console
function Write-Log {
    param ([string]$Message, [string]$Tag = "Info")

    if (-not $log) { return } # Exit if logging is disabled

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $tagList = @("Start", "Check", "Info", "Success", "Error", "Debug", "End")
    $rawTag = $Tag.Trim()

    if ($tagList -contains $rawTag) {
        $rawTag = $rawTag.PadRight(7)
    } else {
        $rawTag = "Error  "  # Fallback if an unrecognized tag is used
    }

    # Set tag colors
    $color = switch ($rawTag.Trim()) {
        "Start"   { "Cyan" }
        "Check"   { "Blue" }
        "Info"    { "Yellow" }
        "Success" { "Green" }
        "Error"   { "Red" }
        "Debug"   { "DarkYellow"}
        "End"     { "Cyan" }
        default   { "White" }
    }

    $logMessage = "$timestamp [  $rawTag ] $Message"

    # Write to file if enabled
    if ($enableLogFile) {
        "$logMessage" | Out-File -FilePath $logFile -Append
    }

    # Write to console with color formatting
    Write-Host "$timestamp " -NoNewline
    Write-Host "[  " -NoNewline -ForegroundColor White
    Write-Host "$rawTag" -NoNewline -ForegroundColor $color
    Write-Host " ] " -NoNewline -ForegroundColor White
    Write-Host "$Message"
}

# ---------------------------[ Script Labels ]---------------------------

[string]$platformTypeLabel = switch ($platformType) {
    1 { "Microsoft Intune" }
    2 { "N-able" }
    default { "Undefined" }
}

[string]$scriptTypeLabel = "Undefined"

if ($scriptType -eq 1) {
    $scriptTypeLabel = switch ($applicationScriptSubType) {
        1 { "Application Detection" }
        2 { "Application Install" }
        3 { "Application Uninstall" }
        default { "Application" }
    }
}
elseif ($scriptType -eq 2) {
    # Compliance scripts are only valid for Intune
    if ($platformType -eq 1) {
        $scriptTypeLabel = "Compliance"
    } else {
        $scriptTypeLabel = "Undefined"
    }
}
elseif ($scriptType -eq 0) {
    if ($platformType -eq 1) {
        if ($intuneScriptSubType -eq 1) {
            $scriptTypeLabel = "Platform"
        }
        elseif ($intuneScriptSubType -eq 2) {
            $scriptTypeLabel = switch ($intuneRemediationType) {
                1 { "Detection" }
                2 { "Remediation" }
                default { "Remediation Undefined" }
            }
        } else {
            $scriptTypeLabel = "Undefined"
        }
    } else {
        $scriptTypeLabel = "Undefined"
    }
}

# ---------------------------[ Start Function ]---------------------------

# Function to summarize script context
function Start-Script {
    Write-Log "======== $scriptTypeLabel Script Started ========" -Tag "Start"

    if ($scriptType -eq 1) {
        Write-Log "ComputerName: $env:COMPUTERNAME | User: $env:USERNAME | Application: $applicationName" -Tag "Info"
    } else {
        Write-Log "ComputerName: $env:COMPUTERNAME | User: $env:USERNAME | Script: $scriptName" -Tag "Info"
    }

    Write-Log "Platform: $platformTypeLabel"
    Write-Log "Log file path: $logFile" -Tag "Debug"

}

# ---------------------------[ Exit Function ]---------------------------

function Complete-Script {
    param([int]$ExitCode)
    $scriptEndTime = Get-Date
    $duration = $scriptEndTime - $scriptStartTime
    Write-Log "Script execution time: $($duration.ToString("hh\:mm\:ss\.ff"))" -Tag "Info"
    Write-Log "Exit Code: $ExitCode" -Tag "Info"
    Write-Log "======== $scriptTypeLabel Script Completed ========" -Tag "End"
    exit $ExitCode
}
# Complete-Script -ExitCode 0

# ---------------------------[ Script Start ]---------------------------

# Capture start time to log script duration
$scriptStartTime = Get-Date
Start-Script

# ---------------------------[ Stuff ]---------------------------

Write-Log "This is a test Check ouput" -Tag "Check"
Write-Log "This is a test Success ouput" -Tag "Success"
Write-Log "This is a test Error ouput" -Tag "Error"
Write-Log "This is a test Debug ouput" -Tag "Debug"

Complete-Script -ExitCode 0