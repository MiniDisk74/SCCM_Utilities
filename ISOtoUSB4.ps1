<#
.LINK
    https://www.extremelycashpoor.com
.SYNOPSIS
    Creates a Bootable FAT32 USB (32GB or smaller) and copies a Mounted ISO. (Modified to run as an SCCM package via a Task Sequence in Windows)
.DESCRIPTION
    Creates a Bootable FAT32 USB (32GB or smaller) and copies a Mounted ISO. Supports only 1 USB drive. Make sure the one you want to modify is the only usb drive connected.
.NOTES
    NAME:	IsoToUsb4.ps1
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
[System.String]$LogFile = "C:\windows\temp\isotousb3.log"
[System.String]$ISOFile = "$scriptpath\boot.iso"
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
Write-Log -LogFile $LogFile -Message "the command were running is: SelectedDisk = Get-Disk | Where-Object { _.Size/1GB -lt 33 -and _.BusType -eq 'USB' } | Select-Object -First 1"
$SelectedDisk = Get-Disk | Where-Object { $_.Size/1GB -lt 33 -and $_.BusType -eq 'USB' } | Select-Object -First 1
Write-Log -LogFile $LogFile -Message "the new drive is $SelectedDisk"
if ($SelectedDisk)
{
	# Proceed with disk operations
	$SelectedDisk | Clear-Disk -RemoveData -RemoveOEM -Confirm:$false -PassThru |
	New-Partition -UseMaximumSize -IsActive -AssignDriveLetter |
	Format-Volume -FileSystem FAT32 -NewFileSystemLabel $USBLabel
	Write-Host "The USB drive has been formatted and is ready to use."
	Write-Log -LogFile $LogFile -Message "Disk Selected: $selectedDisk"
	#=================================================
	Write-Log -LogFile $LogFile -Message "Getting Volumes and drives ..."
	#=================================================
	$Volumes = (Get-Volume).Where({ $_.DriveLetter }).DriveLetter
	$DriveLetter = Get-Partition -DiskNumber $SelectedDisk.Number | Get-Volume | Select-Object -ExpandProperty DriveLetter
	Write-Log -LogFile $LogFile -Message "$Volumes = (Get-Volume).Where({ $_.DriveLetter }).DriveLetter"
	Write-Log -LogFile $LogFile -Message "Volumes: $Volumes"
	Write-Log -LogFile $LogFile -Message "Driveletter of the USB drive is $DriveLetter"
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
	$ISO = (Compare-Object -ReferenceObject $Volumes -DifferenceObject (Get-Volume).Where({ $_.DriveLetter }).DriveLetter).InputObject
	Write-Log -LogFile $LogFile -Message "Mounted Iso is located at $ISO"
	#=================================================
	Write-Log -LogFile $LogFile -Message "Making the USB Drive Botoable ..."
	#=================================================
	$loc1 = Get-Location
	Write-Log -LogFile $LogFile -Message "Current Location is: $loc1"
	Set-Location -Path "$($ISO):\boot"
	$loc2 = Get-Location
	Write-Log -LogFile $LogFile -Message "Changed Location to: $loc2"
	Write-Log -LogFile $LogFile -Message "the new drive is $($DriveLetter):"
	Write-Log -LogFile $LogFile -Message "lets set the bootsect.exe on the usb drive"
	Start-Process -FilePath "C:\windows\system32\bootsect.exe" -ArgumentList "/nt60", "$($DriveLetter):" -NoNewWindow -Wait
	#=================================================
	Write-Log -LogFile $LogFile -Message "Copying Files ..."
	#=================================================
	Copy-Item -Path "$($ISO):\*" -Destination "$($DriveLetter):" -Recurse -Verbose *>> c:\copyitemsResults.log
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



