<#
.SYNOPSIS
    Adds AWS SSM port forwarding profiles to Windows Terminal
.DESCRIPTION
    Creates permanent profiles in Windows Terminal for connecting to EC2 instances via SSM port forwarding
    Dynamically retrieves EC2 instance IDs based on Name tags
.NOTES
    Version:        2.0
    Author:         AWS Automation Tool
    Requires:       Windows Terminal, AWS CLI, Session Manager Plugin
#>

# Configuration
$region         = "us-east-1"
$awsProfile     = "APD-Editorial-Prod"
$remotePort     = 1521
$batchSubFolder = "Apd-Editorial-PROD-1521"    # <-- Change this to any subfolder name

# Define instance mappings with EC2 Name Tags (no hardcoded instance IDs)
$instanceMappings = @(
    @{EC2NameTag = "pawora7011l"; LocalPort = 5170; Name = "nagsp"},
    @{EC2NameTag = "pawora7012l"; LocalPort = 5176; Name = "radp"}
)

# ============================================================
# Function: Get Instance ID by EC2 Name Tag
# ============================================================
function Get-InstanceIdByNameTag {
    param(
        [string]$NameTag,
        [string]$Region,
        [string]$Profile
    )

    try {
        $instanceId = aws ec2 describe-instances `
            --filters "Name=tag:Name,Values=$NameTag" `
                      "Name=instance-state-name,Values=running" `
            --query "Reservations[0].Instances[0].InstanceId" `
            --output text `
            --region $Region `
            --profile $Profile 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "  AWS CLI error for $NameTag : $instanceId" -ForegroundColor Red
            return $null
        }

        if ([string]::IsNullOrWhiteSpace($instanceId) -or $instanceId -eq "None") {
            Write-Host "  No running instance found with Name tag: $NameTag" -ForegroundColor Yellow
            return $null
        }

        return $instanceId.Trim()
    }
    catch {
        Write-Host "  Exception retrieving instance ID for $NameTag : $_" -ForegroundColor Red
        return $null
    }
}

# ============================================================
# Validate AWS CLI is available
# ============================================================
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  AWS SSM Windows Terminal Profile Setup   " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

try {
    $awsVersion = aws --version 2>&1
    Write-Host "AWS CLI: $awsVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: AWS CLI not found. Please install AWS CLI." -ForegroundColor Red
    exit 1
}

# ============================================================
# Dynamically Retrieve Instance IDs
# ============================================================
Write-Host "`nRetrieving EC2 Instance IDs from AWS..." -ForegroundColor Yellow
Write-Host "Region : $region" -ForegroundColor Cyan
Write-Host "Profile: $awsProfile" -ForegroundColor Cyan
Write-Host "--------------------------------------------" -ForegroundColor Gray

$resolvedMappings = @()
$failedMappings   = @()

foreach ($mapping in $instanceMappings) {
    Write-Host "Looking up: $($mapping.EC2NameTag) ($($mapping.Name))..." -NoNewline

    $instanceId = Get-InstanceIdByNameTag `
        -NameTag  $mapping.EC2NameTag `
        -Region   $region `
        -Profile  $awsProfile

    if ($instanceId) {
        Write-Host " Found: $instanceId" -ForegroundColor Green

        # Add resolved mapping with instance ID
        $resolvedMappings += @{
            EC2NameTag = $mapping.EC2NameTag
            InstanceId = $instanceId
            LocalPort  = $mapping.LocalPort
            Name       = $mapping.Name
        }
    } else {
        Write-Host " FAILED - Skipping" -ForegroundColor Red
        $failedMappings += $mapping.Name
    }
}

Write-Host "--------------------------------------------" -ForegroundColor Gray
Write-Host "Resolved : $($resolvedMappings.Count) of $($instanceMappings.Count) instances" -ForegroundColor Cyan

if ($failedMappings.Count -gt 0) {
    Write-Host "Failed   : $($failedMappings -join ', ')" -ForegroundColor Yellow
}

if ($resolvedMappings.Count -eq 0) {
    Write-Host "`nERROR: No instances could be resolved. Exiting." -ForegroundColor Red
    exit 1
}

# ============================================================
# Find Windows Terminal settings.json path
# ============================================================
$settingsPath  = $null
$possiblePaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $settingsPath = $path
        break
    }
}

if (-not $settingsPath) {
    Write-Host "Could not find Windows Terminal settings.json file." -ForegroundColor Red
    Write-Host "Make sure Windows Terminal is installed and has been run at least once." -ForegroundColor Yellow
    exit 1
}

# Backup settings.json
$backupPath = "$settingsPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -Path $settingsPath -Destination $backupPath
Write-Host "`nBacked up settings to: $backupPath" -ForegroundColor Green

# ============================================================
# Read and parse settings.json
# ============================================================
try {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

    # Check if schema version supports profile creation via folders
    $supportsGroups = $false
    if ($settings.PSObject.Properties.Name -contains "version" -and $settings.version -ge 1) {
        $supportsGroups = $true
    }

    # Keep track of generated profiles for display
    $generatedProfiles = @()

    # Create a group for SSM connections if supported
    if ($supportsGroups) {
        $ssmGroup = $settings.profiles.list | Where-Object { $_.name -eq "AWS SSM Connections" }
        if (-not $ssmGroup) {
            $groupGuid = [guid]::NewGuid().ToString()
            $ssmGroup  = @{
                guid = "{$groupGuid}"
                name = "AWS SSM Connections"
            }
            $settings.profiles.list += $ssmGroup
        }
    }

    # ============================================================
    # Batch scripts directory using $batchSubFolder variable
    # ============================================================
    $batchDir = "C:\scripts\AWS-Scripts\$batchSubFolder"
    if (-not (Test-Path $batchDir)) {
        New-Item -ItemType Directory -Path $batchDir -Force | Out-Null
        Write-Host "Created scripts directory: $batchDir" -ForegroundColor Green
    } else {
        Write-Host "Scripts directory exists  : $batchDir" -ForegroundColor Cyan
    }

    # ============================================================
    # Create batch script and profile for each resolved instance
    # ============================================================
    foreach ($mapping in $resolvedMappings) {

        $profileName   = "SSM: $($mapping.Name) (Port $($mapping.LocalPort)) - $remotePort"
        $profileGuid   = [guid]::NewGuid().ToString()
        $batchFileName = "ssm-$($mapping.Name)-$($mapping.LocalPort)-$remotePort.bat"
        $batchFilePath = Join-Path $batchDir $batchFileName

        # Batch file with dynamic instance ID retrieval at runtime
        $batchContent = @"
@echo off
echo ============================================================
echo AWS SSM Port Forwarding: $($mapping.Name)
echo ============================================================
echo EC2 Name Tag : $($mapping.EC2NameTag)
echo Local Port   : $($mapping.LocalPort)
echo Remote Port  : $remotePort
echo AWS Profile  : $awsProfile
echo Region       : $region
echo ============================================================

REM Dynamically retrieve instance ID at runtime
echo Retrieving instance ID for: $($mapping.EC2NameTag)...

FOR /F "tokens=*" %%i IN ('aws ec2 describe-instances ^
  --filters "Name=tag:Name,Values=$($mapping.EC2NameTag)" ^
            "Name=instance-state-name,Values=running" ^
  --query "Reservations[0].Instances[0].InstanceId" ^
  --output text ^
  --region $region ^
  --profile $awsProfile') DO SET INSTANCE_ID=%%i

REM Validate instance ID
IF "%INSTANCE_ID%"=="" (
    echo ERROR: No running instance found for tag: $($mapping.EC2NameTag)
    pause
    exit /b 1
)

IF "%INSTANCE_ID%"=="None" (
    echo ERROR: No running instance found for tag: $($mapping.EC2NameTag)
    pause
    exit /b 1
)

echo Instance ID  : %INSTANCE_ID%
echo ============================================================
echo Connect via  : localhost:$($mapping.LocalPort)
echo ============================================================
echo Starting SSM session...

aws ssm start-session ^
  --target %INSTANCE_ID% ^
  --document-name AWS-StartPortForwardingSession ^
  --parameters portNumber=$remotePort,localPortNumber=$($mapping.LocalPort) ^
  --region $region ^
  --profile $awsProfile

IF %ERRORLEVEL% NEQ 0 (
    echo ERROR: SSM session failed with error code %ERRORLEVEL%
)

pause
"@

        # Write the batch file
        $batchContent | Out-File -FilePath $batchFilePath -Encoding ascii -Force

        # Create the Windows Terminal profile
        $newProfile = @{
            guid        = "{$profileGuid}"
            name        = $profileName
            commandline = "cmd.exe /k `"$batchFilePath`""
            tabTitle    = "$($mapping.Name)"
        }

        # Add to the list of profiles
        $settings.profiles.list += $newProfile
        $generatedProfiles       += $profileName
    }

    # Save updated settings
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath

    # ============================================================
    # Summary
    # ============================================================
    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host "Successfully added profiles to Windows Terminal:" -ForegroundColor Green
    foreach ($profileItem in $generatedProfiles) {
        Write-Host "  - $profileItem" -ForegroundColor Cyan
    }

    if ($failedMappings.Count -gt 0) {
        Write-Host "`nSkipped (instance not found):" -ForegroundColor Yellow
        foreach ($failed in $failedMappings) {
            Write-Host "  - $failed" -ForegroundColor Yellow
        }
    }

    Write-Host "`nSSM script files created in : $batchDir" -ForegroundColor Green
    Write-Host "Settings backed up to        : $backupPath" -ForegroundColor Green
    Write-Host "`nPlease restart Windows Terminal to see the new profiles." -ForegroundColor Yellow
    Write-Host "Access them from the dropdown menu (Ctrl+Shift+Space)" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Cyan
}
catch {
    Write-Host "Error modifying Windows Terminal settings: $_" -ForegroundColor Red
    Write-Host "Restoring backup from: $backupPath" -ForegroundColor Yellow
    Copy-Item -Path $backupPath -Destination $settingsPath -Force
}