# Bypass execution policy to permit script execution
# Download the script and execute it
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/dylan0760/Windows-Winget/main/Programs/GuI%20Github.ps1" -OutFile "$env:TEMP\GuI_Github.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\GuI_Github.ps1"