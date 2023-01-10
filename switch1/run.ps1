﻿$VolumeName = "bashbunny"
$computerSystem = Get-CimInstance CIM_ComputerSystem
$backupDrive = $null
get-wmiobject win32_logicaldisk | % {
    if ($_.VolumeName -eq $VolumeName) {
        $backupDrive = $_.DeviceID
    }
}


# Define the repository owner and name
$owner = "nick22985"
$repo = "IntunePS1BashBunny"

# Define the current version of the script
$currentVersion = "0"

# Get the latest release from GitHub
$release = (Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/releases/latest").tag_name
Write-Host $release
Write-Host $backupDrive
# Compare the latest release with the current version
if ($release -gt $currentVersion) {
    # Download the new files
    Invoke-WebRequest -Uri "https://github.com/$owner/$repo/archive/refs/tags/$release.zip" -OutFile "update.zip"
    # Unzip the downloaded file
    Expand-Archive -Path "update.zip" -DestinationPath "update"

    # Copy env file to update
    Copy-Item -Path "../.env" -Destination "update/$repo-$release/.env" -Force

    # Define the location of the old script
    $oldScriptLocation = $backupDrive + "/payloads/"

    # Move the new files to the location of the old script, overwriting existing files
    Move-Item -Path "update\*" -Destination $oldScriptLocation -Force

    # Delete the old files
    Remove-Item -Recurse -Force $oldScriptLocation\update

    # Run the update script
    & "$oldScriptLocation\update.ps1"

} else {
    # No update available
    Write-Host "No update available."
}



$envVars = Import-Csv -Path "../.env" -Delimiter ","
$localEnvVars = @{}
foreach ($envVar in $envVars) {
    if ($envVar.Value -ne $null -and $envVar.Value -ne "" -and $envVar.Name -ne $null -and $envVar.Name -ne "") {
        $localEnvVars[$envVar.Name] = $envVar.Value
    }
}

# Validate if variablels exists in env.
if($localEnvVars.domain -eq $null) {
    $domain = Read-Host -Prompt "Missing domain in .env file. Would you like to fix this by setting a domain in .env.(y/n)"
    if($domain -eq "y") {
        $domain = Read-Host -Prompt "Enter domain with @ in front. Example: @domain.com"
        $localEnvVars.domain = $domain
        $localEnvVars.GetEnumerator() | Select-Object @{n="Name";e={$_.Key}},@{n="Value";e={$_.Value}} | Export-Csv -Path ".env" -NoTypeInformation -Delimiter "," -Encoding UTF8
    } else {
        Write-Host "No domain terminating...."
        Exit
    }
}

if($localEnvVars.GroupTag -eq $null) {
    $GroupTag = Read-Host -Prompt "Missing GroupTag in .env file. Would you like to fix this by setting a GroupTag in .env.(y/n)"
    if($GroupTag -eq "y") {
        $GroupTag = Read-Host -Prompt "Enter GroupTag"
        $localEnvVars.GroupTag = $GroupTag
        $localEnvVars.GetEnumerator() | Select-Object @{n="Name";e={$_.Key}},@{n="Value";e={$_.Value}} | Export-Csv -Path ".env" -NoTypeInformation -Delimiter "," -Encoding UTF8
    } else {
        Write-Host "No GroupTag terminating...."
        Exit
    }
}

if($localEnvVars.Group -eq $null) {
    $Group = Read-Host -Prompt "Missing Group in .env file. Would you like to fix this by setting a Group in .env.(y/n)"
    if($Group -eq "y") {
        $Group = Read-Host -Prompt "Enter Group"
        $localEnvVars.Group = $Group
        $localEnvVars.GetEnumerator() | Select-Object @{n="Name";e={$_.Key}},@{n="Value";e={$_.Value}} | Export-Csv -Path ".env" -NoTypeInformation -Delimiter "," -Encoding UTF8
    } else {
        Write-Host "No Group terminating...."
        Exit
    }
}


$UserAccount = Read-host -Prompt "User Account"


#See if a loot folder exist in usb. If not create one
$TARGETDIR = $backupDrive + "\loot"
if(!(Test-Path -Path $TARGETDIR )){
    New-Item -ItemType directory -Path $TARGETDIR
}

#See if a info folder exist in loot folder. If not create one
$TARGETDIR = $backupDrive + "\loot\HWID"
if(!(Test-Path -Path $TARGETDIR )){
    New-Item -ItemType directory -Path $TARGETDIR
}

#Create a path that will be used to make the file
$datetime = get-date -f yyyy-MM-dd_HH-mm-ss
$backupPath = $backupDrive + "\loot\HWID\"

#Create output from info script
$TARGETDIR = $MyInvocation.MyCommand.Path
$TARGETDIR = $TARGETDIR -replace ".......$"
cd $TARGETDIR

$email = $UserAccount + $localEnvVars.domain

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force
Install-Script -Name Get-WindowsAutopilotInfo -Force -Confirm:$False
$env:Path += ";C:\Program Files\WindowsPowerShell\Scripts"

Get-WindowsAutopilotInfo.ps1 -Online -GroupTag $localEnvVars.GroupTag -AddToGroup $localEnvVars.Group -Assigneduser $UserAccount -OutputFile $backupPath\AutopilotHWID-$UserAccount-$datetime.csv