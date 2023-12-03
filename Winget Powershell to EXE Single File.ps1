# Prompt the user to enter the file path of the PS1 file
$source = Read-Host -Prompt "Enter the file path of the PS1 file"

# Check if the file exists and has a .ps1 extension
if (Test-Path $source -PathType Leaf) {
    if ($source -like "*.ps1") {
        # Set the target file name as the source file name with .exe extension
        $target = $source -replace ".ps1", ".exe"

        # Set the destination folder path
        $destination = "\\OPHELIA\Plex Server\My Software\Windows\Windows Winget\Programs\Windows-Winget\Programs\EXE Versions"

        # Invoke the ps2exe command to convert the PS1 file to EXE file
        Invoke-ps2exe $source $target

        # Move the EXE file to the destination folder
        Move-Item $target $destination

        # Display a success message
        Write-Host "The PS1 file has been converted to EXE file and moved to the destination folder"
    }
    else {
        # Display an error message if the file is not a PS1 file
        Write-Host "The file is not a PS1 file"
    }
}
else {
    # Display an error message if the file does not exist
    Write-Host "The file does not exist"
}
