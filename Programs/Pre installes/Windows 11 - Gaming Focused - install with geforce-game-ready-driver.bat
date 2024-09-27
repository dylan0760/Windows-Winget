@echo off

rem Set the execution policy to Unrestricted
powershell.exe -Command "Set-ExecutionPolicy Unrestricted"

rem Install the Discord app
powershell.exe -Command "winget install -e --id Discord.Discord --accept-package-agreements --accept-source-agreements"

rem Install the Steam app
powershell.exe -Command "winget install -e --id Valve.Steam --accept-package-agreements --accept-source-agreements"

rem Install the EA Desktop app
powershell.exe -Command "winget install -e --id ElectronicArts.EADesktop --accept-package-agreements --accept-source-agreements"

rem Install the 7-Zip app
powershell.exe -Command "winget install -e --id 7zip.7zip --accept-package-agreements --accept-source-agreements"

rem Install the Notepad++ app
powershell.exe -Command "winget install -e --id Notepad++.Notepad++ --accept-package-agreements --accept-source-agreements"

rem Install the Ubisoft Connect app
powershell.exe -Command "winget install -e --id Ubisoft.Connect --accept-package-agreements --accept-source-agreements"

rem Install the Epic Games Launcher app
powershell.exe -Command "winget install -e --id EpicGames.EpicGamesLauncher --accept-package-agreements --accept-source-agreements"

rem Install the Nvidia GeForce Experience app
powershell.exe -Command "winget install -e --id Nvidia.GeForceExperience --accept-package-agreements --accept-source-agreements"
