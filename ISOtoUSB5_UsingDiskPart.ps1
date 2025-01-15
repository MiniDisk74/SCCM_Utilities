<#
.LINK
    https://www.extremelycashpoor.com
.SYNOPSIS
    Creates a Bootable FAT32 USB (32GB or smaller) and copies a Mounted ISO. (Modified to run as an SCCM package via a Task Sequence in WinPE)
.DESCRIPTION
    Creates a Bootable FAT32 USB (32GB or smaller) and copies a Mounted ISO. Supports only 1 USB drive. Make sure the one you want to modify is the only usb drive connected.
.NOTES
    NAME:	Copy-IsoToUsb_WinPE.ps1
    AUTHOR:	MiniDisk
    BLOG:	https://www.extremelycashpoor.com
    VERSION:	1.0
    
  
#>

function Write-Log
{
	param (
		[string]$LogFile,
		[string]$Message
	)
	
	# Check if the log file exists, if not, create it
	if (-not (Test-Path -Path $LogFile))
	{
		New-Item -ItemType File -Path $LogFile -Force
	}
	
	# Get the current date and time
	$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	
	# Write the message to the log file with a timestamp
	$logEntry = "$timestamp - $Message"
	Add-Content -Path $LogFile -Value $logEntry
}


[System.String]$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
[System.String]$LogFile = "c:\windows\temp\isotousb_LogFile.log"
[System.String]$ISOFile = "$scriptpath\SCCM_OSD_x64_AMER.iso"
[System.String]$USBLabel = "SCCMBoot"
#=================================================
Write-Log -LogFile $LogFile -Message "Validating Elevated Permissions ..."
#=================================================
$Elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Log -LogFile $LogFile -Message "checking elevation"
if (-not $Elevated)
{
	Write-Log -LogFile $LogFile -Message "elevation failed"
}
Write-Log -LogFile $LogFile -Message "script path is: $scriptpath"
Write-Log -LogFile $LogFile -Message "Log file is: $LogFile"
Write-Log -LogFile $LogFile -Message "ISO File is: $ISOFile"
Write-Log -LogFile $LogFile -Message "USB Label is: $USBLabel"
#=================================================
Write-Log -LogFile $LogFile -Message "Selecting USB Drive ..."
#=================================================
# Get the first USB drive that matches the criteria
# Create a temporary file to store the diskpart script for listing disks
$diskpartScriptPath = [System.IO.Path]::GetTempFileName()

# Write the diskpart commands to the temporary file
@"
list disk
"@ | Set-Content -Path $diskpartScriptPath

# Run diskpart and capture the output
$diskOutput = diskpart /s $diskpartScriptPath | Out-String

# Clean up the temporary file
Remove-Item $diskpartScriptPath

# Use a regular expression to extract disk information
$diskMatches = [regex]::Matches($diskOutput, "Disk\s+(\d+)\s+Online\s+(\d+)\s+GB")

$targetDisk = $null
foreach ($match in $diskMatches) {
    $diskNumber = $match.Groups[1].Value
    $diskSizeGB = [int]$match.Groups[2].Value
    if ($diskSizeGB -lt 32) {
        $targetDisk = $diskNumber
        break
    }
}

if ($targetDisk) {
    Write-Log -LogFile $LogFile -Message "Target disk identified: Disk $targetDisk"
    sleep 2

    # Create a temporary file to store the diskpart script for cleaning and partitioning
    $diskpartScriptPath = [System.IO.Path]::GetTempFileName()

    # Write the diskpart commands to the temporary file for cleaning and formatting the disk
    @"
select disk $targetDisk
clean
create partition primary
format fs=fat32 quick
"@ | Set-Content -Path $diskpartScriptPath

    # Run diskpart with the script and capture the output
    $diskpartOutput = diskpart /s $diskpartScriptPath | Out-String

    # Clean up the temporary file
    Remove-Item $diskpartScriptPath

    # Output the diskpart process result
    Write-Log -LogFile $LogFile -Message "the new drive is $diskpartOutput"
} else {
    Write-Log -LogFile $LogFile -Message "No disk found with size less than 32GB."
    sleep 300
    exit
}


if ($diskpartOutput)
{
	# Create a temporary script for diskpart to list volumes
    $diskpartScript = @"
    list volume
"@ 

    # Save the script to a temporary file
    $scriptPath = "$env:TEMP\diskpart_script.txt"
    $diskpartScript | Set-Content -Path $scriptPath

    # Run diskpart with the script file and capture the output
    $diskpartOutput = & "diskpart.exe" /s $scriptPath

    # Regular expression to match removable volumes with size and check if less than 32GB
    $regex = 'Volume\s+(\d+)\s+([A-Z])\s+\S+\s+Removable\s+(\d+)\s+GB'

    # Split the output into individual lines for better processing
    $lines = $diskpartOutput -split "`n"

    # Iterate through each line and find matches
    foreach ($line in $lines) {
        if ($line -match $regex) {
            # Extract volume size and drive letter from regex match
            $matches = [regex]::Match($line, $regex)
            $volumeSize = [int]$matches.Groups[3].Value
            $DriveLetter = $matches.Groups[2].Value
        
            # Ensure it's a removable volume and its size is less than 32GB
            if ($volumeSize -lt 32) {
                Write-Log -LogFile $LogFile -Message "Driveletter of the USB drive is $DriveLetter"
                $USBDriveLetter = $DriveLetter
            }
        }
    }

    # Clean up the temporary script file
    Remove-Item -Path $scriptPath

    
	#=================================================
	Write-Log -LogFile $LogFile -Message "Mounting the ISO ..."
	#=================================================
	Mount-DiskImage -ImagePath $ISOFile
	#=================================================
	Write-Log -LogFile $LogFile -Message "Waiting 5 Seconds ..."
	#=================================================
	Start-Sleep -s 5
	#=================================================
	Write-Log -LogFile $LogFile -Message "Detemrining the Drive Letter of the Mounted ISO ..."
	#=================================================
    # Create a temporary script for diskpart to list volumes
    $diskpartScript = @"
    list volume
"@

    # Save the script to a temporary file
    $scriptPath = "$env:TEMP\diskpart_script.txt"
    $diskpartScript | Set-Content -Path $scriptPath

    # Run diskpart with the script file and capture the output
    $diskpartOutput = & "diskpart.exe" /s $scriptPath

    # Regular expression to match DVD-ROM volumes with size and check if less than 999MB
    $regex = 'Volume\s+(\d+)\s+([A-Z])\s+\S+\s+\S+\s+DVD-ROM\s+(\d+)\s+MB'

    # Split the output into individual lines for better processing
    $lines = $diskpartOutput -split "`n"

    # Iterate through each line and find matches
    foreach ($line in $lines) {
        if ($line -match $regex) {
            # Extract volume size and drive letter from regex match
            $matches = [regex]::Match($line, $regex)
            $volumeSize = [int]$matches.Groups[3].Value
            $driveLetter = $matches.Groups[2].Value
        
            # Ensure it's a DVD-ROM volume and its size is less than 999MB
            if ($volumeSize -lt 999) {
                Write-Log -LogFile $LogFile -Message "Found DVD-ROM volume with drive letter $driveLetter and size $volumeSize MB"
                $ISO = $driveLetter
                Write-Log -LogFile $LogFile -Message "Mounted Iso is located at $ISO"
            }
        }
    }

    # Clean up the temporary script file
    Remove-Item -Path $scriptPath
    
    
	
	#=================================================
	Write-Log -LogFile $LogFile -Message "Making the USB Drive Botoable ..."
	#=================================================
	$loc1 = Get-Location
	Write-Log -LogFile $LogFile -Message "Current Location is: $loc1"
	Set-Location -Path "$($ISO):\boot"
	$loc2 = Get-Location
	Write-Log -LogFile $LogFile -Message "Changed Location to: $loc2"
	Write-Log -LogFile $LogFile -Message "the new drive is $($USBDriveLetter):"
	sleep 60
    Write-Log -LogFile $LogFile -Message "lets set the bootsect.exe on the usb drive"
	Start-Process -FilePath "c:\windows\system32\bootsect.exe" -ArgumentList "/nt60", "$($USBDriveLetter):" -NoNewWindow -Wait
	#=================================================
	Write-Log -LogFile $LogFile -Message "Copying Files ..."
	#=================================================
	Copy-Item -Path "$($ISO):\*" -Destination "$($USBDriveLetter):" -Recurse -Verbose *>> c:\copyitemsResults.log
	#=================================================
	Write-Log -LogFile $LogFile -Message "Dismounting Disk Image ..."
	#=================================================
	Dismount-DiskImage -ImagePath $ISOFile
	#=================================================
	Write-Log -LogFile $LogFile -Message "Complete"
	#=================================================
	sleep -Seconds 10
}
else
{
	Write-Log -LogFile $LogFile -Message "No USB Drive was Found or Selected"
}
