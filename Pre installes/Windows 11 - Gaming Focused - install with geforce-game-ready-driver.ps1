function Check-Update-Winget {
    $logFilePath = "$ENV:TEMP\wingetLog.txt"
    try {
        # Clear log file
        Clear-Content -Path $logFilePath -ErrorAction SilentlyContinue
    } catch {}

    function Log-Message {
        param ($message)
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $logFilePath -Value "[$timestamp] $message"
    }

    # Start logging
    Log-Message "Starting Winget update check."

    $wingetExists = $true
    try {
        $wingetVersionFull = winget --version
        Log-Message "Winget version found: $wingetVersionFull"
    } catch [System.Management.Automation.CommandNotFoundException], [System.Management.Automation.ApplicationFailedException] {
        Log-Message "Winget was not found."
        $wingetExists = $false
    } catch {
        Log-Message "Winget was not found due to unknown reasons."
        $wingetExists = $false
    }

    if ($wingetExists) {
        # Check if Preview Version
        if ($wingetVersionFull -contains "-preview") {
            $wingetVersion = $wingetVersionFull.Trim("preview")
            $wingetPreview = $true
            Log-Message "Winget is a preview version: $wingetVersion"
        } else {
            $wingetVersion = $wingetVersionFull
            $wingetPreview = $false
            Log-Message "Winget is a release version: $wingetVersion"
        }

        $wingetCurrentVersion = [System.Version]::Parse($wingetVersion.Trim('v'))
        Log-Message "Parsed current Winget version: $wingetCurrentVersion"

        # Grabs the latest release of Winget from the Github API for version check process.
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/Winget-cli/releases/latest" -Method Get -ErrorAction Stop
        $wingetLatestVersion = [System.Version]::Parse(($response.tag_name).Trim('v')) # Stores version number of latest release.
        $wingetOutdated = $wingetCurrentVersion -lt $wingetLatestVersion

        if (!$wingetOutdated) {
            Log-Message "Winget is up to date (Version: $wingetVersionFull)"
        } else {
            Log-Message "Winget is outdated (Current Version: $wingetVersionFull, Latest Version: $wingetLatestVersion)"
            # Code to update Winget
            Log-Message "Downloading Winget Prerequisites."
            Get-WinUtilWingetPrerequisites
            Log-Message "Downloading Winget and License File."
            Get-WinUtilWingetLatest

            Log-Message "Installing Winget with Prerequisites."
            Add-AppxProvisionedPackage -Online -PackagePath $ENV:TEMP\Microsoft.DesktopAppInstaller.msixbundle -DependencyPackagePath $ENV:TEMP\Microsoft.VCLibs.x64.Desktop.appx, $ENV:TEMP\Microsoft.UI.Xaml.x64.appx -LicensePath $ENV:TEMP\License1.xml

            Log-Message "Manually adding Winget Sources from Winget CDN."
            Add-AppxPackage -Path https://cdn.winget.microsoft.com/cache/source.msix
            Log-Message "Winget Installed."

            # Enabling NuGet and Module...
            Log-Message "Enabling NuGet and Module."
            Install-PackageProvider -Name NuGet -Force
            Install-Module -Name Microsoft.WinGet.Client -Force

            # Refreshing Environment Variables
            Log-Message "Refreshing Environment Variables."
            $ENV:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        }
    } else {
        Log-Message "Winget is not installed. Proceeding with installation."

        # Code to install Winget if it's not installed

        Log-Message "Downloading Winget Prerequisites."
        Get-WinUtilWingetPrerequisites
        Log-Message "Downloading Winget and License File."
        Get-WinUtilWingetLatest

        Log-Message "Installing Winget with Prerequisites."
        Add-AppxProvisionedPackage -Online -PackagePath $ENV:TEMP\Microsoft.DesktopAppInstaller.msixbundle -DependencyPackagePath $ENV:TEMP\Microsoft.VCLibs.x64.Desktop.appx, $ENV:TEMP\Microsoft.UI.Xaml.x64.appx -LicensePath $ENV:TEMP\License1.xml

        Log-Message "Manually adding Winget Sources from Winget CDN."
        Add-AppxPackage -Path https://cdn.winget.microsoft.com/cache/source.msix
        Log-Message "Winget Installed."

        # Enabling NuGet and Module...
        Log-Message "Enabling NuGet and Module."
        Install-PackageProvider -Name NuGet -Force
        Install-Module -Name Microsoft.WinGet.Client -Force

        # Refreshing Environment Variables
        Log-Message "Refreshing Environment Variables."
        $ENV:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }

    Log-Message "Installing packages."

    $packages = @(
        "Brave.Brave",
        "Discord.Discord",
        "Valve.Steam",
        "ElectronicArts.EADesktop",
        "7zip.7zip",
        "Notepad++.Notepad++",
        "Ubisoft.Connect",
        "EpicGames.EpicGamesLauncher",
        "GOG.Galaxy",
        "Nvidia.GeForceExperience"
    )

    foreach ($package in $packages) {
        try {
            Log-Message "Installing $package."
            winget install --id=$package -e --accept-package-agreements --accept-source-agreements --silent
        } catch {
            Log-Message "Failed to install $package: $_"
        }
    }

    Log-Message "Finished installing packages."
}

# Run the function
Check-Update-Winget