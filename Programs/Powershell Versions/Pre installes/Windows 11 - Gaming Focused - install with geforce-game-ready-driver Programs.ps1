# Installing additional software using Winget
Write-Host "Installing Brave Browser..."
winget install --id=Brave.Brave -e --accept-package-agreements --accept-source-agreements --silent

Write-Host "Installing Discord..."
winget install --id Discord.Discord -e --accept-package-agreements --accept-source-agreements --silent

Write-Host "Installing Steam..."
winget install --id Valve.Steam -e --accept-package-agreements --accept-source-agreements --silent

Write-Host "Installing EA Desktop..."
winget install --id ElectronicArts.EADesktop -e --accept-package-agreements --accept-source-agreements --silent

Write-Host "Installing 7zip..."
winget install --id 7zip.7zip -e --accept-package-agreements --accept-source-agreements --silent

Write-Host "Installing Notepad++..."
winget install --id Notepad++.Notepad++ -e --accept-package-agreements --accept-source-agreements --silent

Write-Host "Installing Ubisoft Connect..."
winget install --id Ubisoft.Connect -e --accept-package-agreements --accept-source-agreements --silent

Write-Host "Installing Epic Games Launcher..."
winget install --id EpicGames.EpicGamesLauncher -e --accept-package-agreements --accept-source-agreements --silent

Write-Host "Installing GOG Galaxy..."
winget install --id GOG.Galaxy -e --accept-package-agreements --accept-source-agreements --silent

Write-Host "Installing Nvidia GeForce Experience..."
winget install --id Nvidia.GeForceExperience -e --accept-package-agreements --accept-source-agreements --silent
pause