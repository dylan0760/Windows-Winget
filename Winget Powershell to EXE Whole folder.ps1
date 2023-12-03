# Get all the PS1 files in the source directory
$sourceDir = "\\OPHELIA\Plex Server\My Software\Windows\Windows Winget\Programs\Windows-Winget\Programs\Powershell Versions"
$ps1Files = Get-ChildItem -Path $sourceDir -Filter *.ps1

# Set the target directory for the EXE files
$targetDir = "\\OPHELIA\Plex Server\My Software\Windows\Windows Winget\Programs\Windows-Winget\Programs\EXE Versions"

# Loop through each PS1 file and invoke ps2exe to convert it to EXE
foreach ($ps1File in $ps1Files) {
    # Get the base name of the PS1 file
    $baseName = $ps1File.BaseName

    # Set the source and target paths for ps2exe
    $sourcePath = Join-Path -Path $sourceDir -ChildPath $ps1File.Name
    $targetPath = Join-Path -Path $targetDir -ChildPath "$baseName.exe"

    # Invoke ps2exe to convert the PS1 file to EXE
    Invoke-ps2exe -InputFile $sourcePath -OutputFile $targetPath
}
