Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
Install-Script -Name winget-install -Force
winget-install.ps1



# This script will download and install the latest version of App Installer from GitHub

# Define the download URL and the output file path
$download_url = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
$output_file = "C:\Temp\WinGet.msixbundle"

# Make new folder
New-Item -Path C:\ -Name Temp -ItemType Directory


# Save the original value of the progress preference variable
$originalProgressPreference = $ProgressPreference

# Set the progress preference variable to SilentlyContinue
$ProgressPreference = 'SilentlyContinue'


# Download the App Installer file
Invoke-WebRequest -Uri $download_url -OutFile $output_file

# Restore the original value of the progress preference variable
$ProgressPreference = $originalProgressPreference

# Install the App Installer file
Add-AppxPackage $output_file

# Delete the App Installer file
Remove-Item $output_file
