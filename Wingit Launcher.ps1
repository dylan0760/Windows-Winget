if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Define the command to run elevated
    $Cmd = 'Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/dylan0760/Windows-Winget/refs/heads/main/GuI%20Github.ps1").Content'

    # Relaunch PowerShell elevated, telling it to execute the command
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command & { $Cmd }"
    Write-Host "Attempting to relaunch with Administrator privileges..." -ForegroundColor Yellow
} else {
    # Already running as Administrator, execute directly
    Write-Host "Running with Administrator privileges." -ForegroundColor Green
    Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/dylan0760/Windows-Winget/refs/heads/main/GuI%20Github.ps1").Content
}