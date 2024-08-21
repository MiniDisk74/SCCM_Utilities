# Define source and destination paths
$sourcePath = "X:\Windows\Temp\SMSTSLog\"
$destinationPath = "\\server\sharename"

# Define credentials (you'll be prompted to enter them)
$credential = Get-Credential

# Create a temporary mapped network drive using the credentials
$driveLetter = "Z:"
New-PSDrive -Name "TempDrive" -PSProvider FileSystem -Root $destinationPath -Credential $credential -Persist -ErrorAction Stop

# Define the full destination path using the mapped drive
$fullDestinationPath = Join-Path -Path $driveLetter -ChildPath "\"

# Check if the destination path exists
if (Test-Path -Path $fullDestinationPath) {
    # Get all files from the source directory
    $files = Get-ChildItem -Path $sourcePath

    # Copy each file to the destination share
    foreach ($file in $files) {
        $destinationFile = Join-Path -Path $fullDestinationPath -ChildPath $file.Name
        Copy-Item -Path $file.FullName -Destination $destinationFile -Force
    }

    Write-Output "Files successfully copied to $destinationPath."
} else {
    Write-Error "The destination share $destinationPath is not accessible."
}

# Remove the mapped network drive
Remove-PSDrive -Name "TempDrive"
