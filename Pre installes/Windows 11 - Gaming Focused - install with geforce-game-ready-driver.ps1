function Check-Update-Winget {
    # Check if Winget is installed
    $wingetExists = $true
    try {
        $wingetVersionFull = winget --version
    } catch [System.Management.Automation.CommandNotFoundException], [System.Management.Automation.ApplicationFailedException] {
        Write-Warning "Winget was not found"
        $wingetExists = $false
    } catch {
        Write-Warning "Winget was not found due to unknown reasons"
        $wingetExists = $false
    }

    if ($wingetExists) {
        # Check if Preview Version
        if ($wingetVersionFull.Contains("-preview")) {
            $wingetVersion = $wingetVersionFull.Trim("-preview")
            $wingetPreview = $true
        } else {
            $wingetVersion = $wingetVersionFull
            $wingetPreview = $false
        }
        
        $wingetCurrentVersion = [System.Version]::Parse($wingetVersion.Trim('v'))
        
        # Grabs the latest release of Winget from the Github API for version check process.
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/Winget-cli/releases/latest" -Method Get -ErrorAction Stop
        $wingetLatestVersion = [System.Version]::Parse(($response.tag_name).Trim('v')) #Stores version number of latest release.
        $wingetOutdated = $wingetCurrentVersion -lt $wingetLatestVersion
        
        if (!$wingetOutdated) {
            Write-Host "Winget is up to date (Version: $wingetVersionFull)" -ForegroundColor Green
        } else {
            Write-Host "Winget is outdated (Current Version: $wingetVersionFull, Latest Version: $wingetLatestVersion)" -ForegroundColor Yellow
            # Code to update Winget

            Write-Host "Downloading Winget Prerequisites`n"
            Get-WinUtilWingetPrerequisites
            Write-Host "Downloading Winget and License File`r"
            Get-WinUtilWingetLatest
            Write-Host "Installing Winget w/ Prerequisites`r"
            Add-AppxProvisionedPackage -Online -PackagePath $ENV:TEMP\Microsoft.DesktopAppInstaller.msixbundle -DependencyPackagePath $ENV:TEMP\Microsoft.VCLibs.x64.Desktop.appx, $ENV:TEMP\Microsoft.UI.Xaml.x64.appx -LicensePath $ENV:TEMP\License1.xml
            Write-Host "Manually adding Winget Sources, from Winget CDN."
            Add-AppxPackage -Path https://cdn.winget.microsoft.com/cache/source.msix
            Write-Host "Winget Installed" -ForegroundColor Green

            # Enabling NuGet and Module...
            Write-Host "Enabling NuGet and Module..."
            Install-PackageProvider -Name NuGet -Force
            Install-Module -Name Microsoft.WinGet.Client -Force

            # Refreshing Environment Variables
            Write-Output "Refreshing Environment Variables...`n"
            $ENV:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        }
    } else {
        Write-Host "Winget is not installed. Proceeding with installation."

        # Code to install Winget if it's not installed

        Write-Host "Downloading Winget Prerequisites`n"
        Get-WinUtilWingetPrerequisites
        Write-Host "Downloading Winget and License File`r"
        Get-WinUtilWingetLatest
        Write-Host "Installing Winget w/ Prerequisites`r"
        Add-AppxProvisionedPackage -Online -PackagePath $ENV:TEMP\Microsoft.DesktopAppInstaller.msixbundle -DependencyPackagePath $ENV:TEMP\Microsoft.VCLibs.x64.Desktop.appx, $ENV:TEMP\Microsoft.UI.Xaml.x64.appx -LicensePath $ENV:TEMP\License1.xml
        Write-Host "Manually adding Winget Sources, from Winget CDN."
        Add-AppxPackage -Path https://cdn.winget.microsoft.com/cache/source.msix
        Write-Host "Winget Installed" -ForegroundColor Green

        # Enabling NuGet and Module...
        Write-Host "Enabling NuGet and Module..."
        Install-PackageProvider -Name NuGet -Force
        Install-Module -Name Microsoft.WinGet.Client -Force

        # Refreshing Environment Variables
        Write-Output "Refreshing Environment Variables...`n"
        $ENV:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
		Invoke-Expression (New-Object System.Net.WebClient).DownloadString("https://raw.githubusercontent.com/dylan0760/Windows-Winget/main/Pre%20installes/Windows%2011%20-%20Gaming%20Focused%20-%20install%20with%20geforce-game-ready-driver%20Programs.ps1")
    }
}

