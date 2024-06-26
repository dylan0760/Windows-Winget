# Pause for 60 seconds
Start-Sleep -Seconds 60

# Next part of the script
Write-Host "This is the part of the script that runs after a 60-second pause."

# Installing additional software using Winget
Write-Host "Installing Brave Browser..."
winget install --id=Brave.Brave -e --accept-package-agreements --accept-source-agreements --silent

Write-Host "Installing 7zip..."
winget install --id 7zip.7zip -e --accept-package-agreements --accept-source-agreements --silent

Write-Host "Installing Notepad++..."
winget install --id Notepad++.Notepad++ -e --accept-package-agreements --accept-source-agreements --silent
