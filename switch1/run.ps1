$VolumeName = "bashbunny"
$computerSystem = Get-CimInstance CIM_ComputerSystem
$backupDrive = $null

$art = "
  / _ \_________________________/`/\+-/\'\'\
\_\(_)/_/ Intune Auto Upploader -+-    -+-+-
 _//o\\_                        \'\/+-\/`/`/
  /   \   By Nick22985           \/-+--\/`/
"

Write-Host $art
function waitUserInput($defaultValue = "Default Value", $timeout = 5, $defaultText = "Please enter a value:") {

    [Console]::Write($defaultText)

    $response = $null
    $timestamp = [Environment]::TickCount

    while(([Environment]::TickCount - $timestamp) -lt ($timeout * 1000)) {
        if([Console]::KeyAvailable) {
            $response = [Console]::ReadLine()
            break
        }
    }

    if($response -eq $null) {
        $response = $defaultValue
    }
    Write-Host
    return $response
}

get-wmiobject win32_logicaldisk | % {
    if ($_.VolumeName -eq $VolumeName) {
        $backupDrive = $_.DeviceID
    }
}
$BaseScriptLocation = $backupDrive + "/payloads/"

$envVars = Import-Csv -Path "$BaseScriptLocation/.env" -Delimiter ","
$localEnvVars = @{}
foreach ($envVar in $envVars) {
    if ($envVar.Value -ne $null -and $envVar.Value -ne "" -and $envVar.Name -ne $null -and $envVar.Name -ne "") {
        $localEnvVars[$envVar.Name] = $envVar.Value
    }
}

# Define the repository owner and name
$owner = "nick22985"
$repo = "IntunePS1BashBunny"

# Define the current version of the script
$currentVersion = $localEnvVars.currentVersion
# Get the latest release from GitHub
$gitRelease = (Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/releases/latest")
Read-Host $gitRelease.author.login
$release = $gitRelease.tag_name
$author = $gitRelease.author.login
# Compare the latest release with the current version
if ($release -gt $currentVersion) {
    # Update available
	$default = "Update available. Would you like to update to version $release by $author ? (y/n): "
    $doUpdate = waitUserInput -defaultValue "n" -timeout 5 -defaultText
        if($doUpdate -eq "y") {
        # Download the new files
        Invoke-WebRequest -Uri "https://github.com/$owner/$repo/archive/refs/tags/$release.zip" -OutFile "$BaseScriptLocation/update.zip"
        # Unzip the downloaded file
        Expand-Archive -Path "$BaseScriptLocation/update.zip" -DestinationPath "$BaseScriptLocation/update"

        #Move new update to switch positions
        Move-Item -Path "$BaseScriptLocation\update\$repo-$release\switch2\*" -Destination $BaseScriptLocation\switch2 -Force
        Move-Item -Path "$BaseScriptLocation\update\$repo-$release\switch1\*" -Destination $BaseScriptLocation\switch1 -Force

        # Delete update file
        Remove-Item -Recurse -Force $BaseScriptLocation\update
        Remove-Item -Recurse -Force $BaseScriptLocation\update.zip

        # Set .env currentVersion
        $localEnvVars.currentVersion = $release
        $localEnvVars.GetEnumerator() | Select-Object @{n="Name";e={$_.Key}},@{n="Value";e={$_.Value}} | Export-Csv -Path "$BaseScriptLocation/.env" -NoTypeInformation -Delimiter "," -Encoding UTF8

        Write-Host "Restarting Script with version $release"
        # Run the update script
        & "$BaseScriptLocation/switch1/run.ps1"
        Exit
    } else {
        Write-host "Opted to not update to new version. Running script"
    }
} else {
    # No update available
    Write-Host "No update available."
}

# Validate if variablels exists in env.
if($localEnvVars.domain -eq $null) {
    $domain = Read-Host -Prompt "Missing domain in .env file. Would you like to fix this by setting a domain in .env.(y/n)"
    if($domain -eq "y") {
        $domain = Read-Host -Prompt "Enter domain with @ in front. Example: @domain.com"
        $localEnvVars.domain = $domain
        $localEnvVars.GetEnumerator() | Select-Object @{n="Name";e={$_.Key}},@{n="Value";e={$_.Value}} | Export-Csv -Path "$BaseScriptLocation/.env" -NoTypeInformation -Delimiter "," -Encoding UTF8
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
        $localEnvVars.GetEnumerator() | Select-Object @{n="Name";e={$_.Key}},@{n="Value";e={$_.Value}} | Export-Csv -Path "$BaseScriptLocation/.env" -NoTypeInformation -Delimiter "," -Encoding UTF8
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
        $localEnvVars.GetEnumerator() | Select-Object @{n="Name";e={$_.Key}},@{n="Value";e={$_.Value}} | Export-Csv -Path "$BaseScriptLocation/.env" -NoTypeInformation -Delimiter "," -Encoding UTF8
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

Get-WindowsAutopilotInfo.ps1 -Online -GroupTag $localEnvVars.GroupTag -AddToGroup $localEnvVars.Group -Assigneduser $email -OutputFile $backupPath\AutopilotHWID-$UserAccount-$datetime.csv