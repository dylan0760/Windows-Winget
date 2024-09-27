## Running the PowerShell Script

To run the PowerShell script directly from the repository, use the command below. This command temporarily changes the execution policy and then downloads and runs the script.

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/dylan0760/Windows-Winget/refs/heads/main/GuI%20Github.ps1").Content
