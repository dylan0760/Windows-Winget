#Requires -Version 5.1
<#
.SYNOPSIS
Downloads scripts from GitHub, then provides a GUI to select and install them.

.DESCRIPTION
Checks for Admin rights, downloads/extracts a GitHub repository to C:\temp,
then displays a Windows Forms GUI listing scripts from the extracted repo (recursively).
Allows searching, selecting presets, and installing chosen scripts.

.NOTES
- Requires internet connection for download.
- Writes to C:\temp.
- Preset button script lists may need adjustment based on the repo structure.
#>

# --- Initial Setup & Admin Check ---

# Function to check if the script is running as administrator
function Check-Admin {
    try {
        $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    } catch {
        Write-Warning "Error checking admin status: $($_.Exception.Message)"
        return $false # Assume not admin if check fails
    }
}

# Relaunch as Administrator if not already
if (-not (Check-Admin)) {
    Write-Warning "Administrator privileges required. Attempting to relaunch..."
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($myinvocation.mycommand.definition)`""
    try {
        Start-Process powershell -Verb runAs -ArgumentList $arguments
    } catch {
        Write-Error "Failed to relaunch as administrator: $($_.Exception.Message)"
        # Optional: Display a message box for GUI context if needed later
        # Add-Type -AssemblyName System.Windows.Forms
        # [System.Windows.Forms.MessageBox]::Show("Failed to relaunch as administrator. Please run the script manually as an Administrator.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
    exit # Exit the current non-admin instance
}

# --- Load Assemblies ---
# Ensure necessary .NET assemblies are loaded AFTER admin check
Write-Host "Loading required .NET assemblies..."
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName "System.IO.Compression.FileSystem"
} catch {
    Write-Error "Failed to load essential .NET assemblies: $($_.Exception.Message)"
    [System.Windows.Forms.MessageBox]::Show("Failed to load essential .NET assemblies. The script cannot continue.", "Fatal Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit
}

# --- Download and Extract ---
Write-Host "Setting up script environment..."
# Ensure the C:\temp directory exists before downloading the zip
$tempBaseDir = "C:\temp"
if (-not (Test-Path -Path $tempBaseDir -PathType Container)) {
    try {
        Write-Host "Creating directory: $tempBaseDir"
        New-Item -Path $tempBaseDir -ItemType Directory -ErrorAction Stop | Out-Null
    } catch {
        Write-Error "Failed to create directory '$tempBaseDir': $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Failed to create required directory '$tempBaseDir'. Please check permissions.", "Fatal Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        exit
    }
}

# Path where GitHub repo zip will be downloaded and extracted
$tempZipPath = Join-Path $tempBaseDir "WingetRepo.zip" # Renamed for clarity
$localRepoPath = Join-Path $tempBaseDir "WingetRepoExtract" # Renamed for clarity

# URL of the GitHub repo zip (update the branch name if necessary)
$repoUrl = "https://github.com/dylan0760/Windows-Winget/archive/refs/heads/main.zip"

# Download the .zip file from GitHub
Write-Host "Downloading repository from $repoUrl..."
try {
    Invoke-WebRequest -Uri $repoUrl -OutFile $tempZipPath -ErrorAction Stop
    Write-Host "Download complete: $tempZipPath"
} catch {
    Write-Error "Failed to download repository from '$repoUrl': $($_.Exception.Message)"
    [System.Windows.Forms.MessageBox]::Show("Failed to download the script repository. Please check the URL and your internet connection.", "Download Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit
}

# Check if the repository folder exists, delete it before extraction
if (Test-Path -Path $localRepoPath -PathType Container) {
    Write-Host "Removing existing extraction folder: $localRepoPath"
    try {
        Remove-Item -Recurse -Force -Path $localRepoPath -ErrorAction Stop
    } catch {
        Write-Error "Failed to remove existing directory '$localRepoPath': $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Failed to remove the old script repository directory. Please close any programs using files in '$localRepoPath' and try again.", "Extraction Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        exit
    }
}

# Extract the downloaded .zip archive
Write-Host "Extracting repository to $localRepoPath..."
try {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZipPath, $localRepoPath)
    Write-Host "Extraction complete."
} catch {
    Write-Error "Failed to extract archive '$tempZipPath': $($_.Exception.Message)"
    [System.Windows.Forms.MessageBox]::Show("Failed to extract the script repository ZIP file.", "Extraction Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    # Consider cleaning up $localRepoPath if partially extracted
    exit
}

# Optional: Remove the .zip file after extraction
try {
    Write-Host "Removing temporary zip file: $tempZipPath"
    Remove-Item -Path $tempZipPath -Force -ErrorAction SilentlyContinue # Don't stop script if this fails
} catch {
    Write-Warning "Could not remove temporary zip file '$tempZipPath'."
}

# --- Define Script Source from Extracted Repo ---
# !!! IMPORTANT: Adjust this path based on the ACTUAL structure inside the downloaded ZIP !!!
$targetFolderPath = Join-Path $localRepoPath "Windows-Winget-main\Programs\Powershell Versions"
Write-Host "Target script folder set to: $targetFolderPath"

# --- GUI Code Starts Here ---

# Form Setup
$Form = New-Object System.Windows.Forms.Form
$Form.Text = 'GitHub Script Installer GUI'
$Form.Size = New-Object System.Drawing.Size(420, 720)
$Form.StartPosition = 'CenterScreen'
$Form.FormBorderStyle = 'FixedDialog'
$Form.MaximizeBox = $false
$Form.MinimizeBox = $true

# ToolTip Setup
$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.InitialDelay = 400; $toolTip.AutoPopDelay = 5000; $toolTip.ReshowDelay = 500; $toolTip.ShowAlways = $true

# Search Controls
$SearchLabel = New-Object System.Windows.Forms.Label; $SearchLabel.Text = "Search:"; $SearchLabel.Location = New-Object System.Drawing.Point(10, 15); $SearchLabel.AutoSize = $true
$SearchBox = New-Object System.Windows.Forms.TextBox; $SearchBox.Location = New-Object System.Drawing.Point(70, 12); $SearchBox.Width = 240
$SearchButton = New-Object System.Windows.Forms.Button; $SearchButton.Text = "Search"; $SearchButton.Location = New-Object System.Drawing.Point(320, 10); $SearchButton.Size = New-Object System.Drawing.Size(70, 25)
$Form.Controls.AddRange(@($SearchLabel, $SearchBox, $SearchButton))

# Placeholder text for SearchBox
$placeholderText = "Filter scripts (inc. path)..."
$SearchBox.ForeColor = [System.Drawing.Color]::Gray; $SearchBox.Text = $placeholderText
$SearchBox_GotFocus = { if ($SearchBox.Text -eq $placeholderText) { $SearchBox.Text = ""; $SearchBox.ForeColor = [System.Drawing.Color]::Black } }
$SearchBox_LostFocus = { if ([string]::IsNullOrWhiteSpace($SearchBox.Text)) { $SearchBox.ForeColor = [System.Drawing.Color]::Gray; $SearchBox.Text = $placeholderText } }
$SearchBox.Add_GotFocus($SearchBox_GotFocus); $SearchBox.Add_LostFocus($SearchBox_LostFocus)

# Panel for Checkboxes
$Panel = New-Object System.Windows.Forms.Panel
$Panel.AutoScroll = $true; $Panel.Width = 380; $Panel.Height = 380
$Panel.Location = New-Object System.Drawing.Point(10, 50); $Panel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$Form.Controls.Add($Panel)
Write-Host "DEBUG: Initialized Panel. Type: $($Panel.GetType().FullName)" # Keep debug line

# Checkbox Management
$checkboxes = New-Object System.Collections.ArrayList

# Function to get relative path (using the correct $targetFolderPath)
function Get-RelativePath ($basePath, $fullPath) {
    # Use LiteralPath for Test-Path to handle paths with special characters like '['
    if (-not (Test-Path -LiteralPath $basePath -PathType Container)) {
        Write-Warning "Base path '$basePath' does not exist in Get-RelativePath."
        return $fullPath # Fallback
    }
    try {
        $baseUri = [System.Uri]($basePath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar)
        $fullUri = [System.Uri]$fullPath
        $relativeUri = $baseUri.MakeRelativeUri($fullUri)
        return [Uri]::UnescapeDataString($relativeUri.OriginalString)
    } catch {
        Write-Warning "Error getting relative path for Base='$basePath', Full='$fullPath'. Error: $($_.Exception.Message)"
        return $fullPath
    }
}

# Function to update the checkboxes (using the correct $targetFolderPath)
function Update-Checkboxes($filteredScriptFiles) {
    Write-Host "DEBUG: Entering Update-Checkboxes. Type of `$Panel: $($Panel.GetType().FullName)"
    if ($Panel -isnot [System.Windows.Forms.Panel]) { Write-Warning "-> CRITICAL: `$Panel is NOT a Panel object! Type: $($Panel.GetType().FullName)"; return }

    $Panel.Controls.Clear(); $yPos = 10; $checkboxes.Clear()

    # Use LiteralPath for Test-Path
    if (-not (Test-Path -LiteralPath $targetFolderPath -PathType Container)) {
        Write-Warning "Target script folder path '$targetFolderPath' not found in Update-Checkboxes."
        return
    }

    foreach ($file in $filteredScriptFiles) {
        $checkbox = New-Object System.Windows.Forms.CheckBox
        # --- Use $targetFolderPath as the base for relative path ---
        $relativePath = Get-RelativePath -basePath $targetFolderPath -fullPath $file.FullName
        $checkbox.Text = $relativePath
        # ---
        $checkbox.Tag = $file.FullName
        $checkbox.AutoSize = $false

        Write-Host "DEBUG: Loop iteration for '$($file.Name)'. Type of `$Panel: $($Panel.GetType().FullName). Width: $($Panel.Width)"
        if ($Panel -isnot [System.Windows.Forms.Panel]) { Write-Warning "-> CRITICAL: `$Panel lost DURING loop! Type: $($Panel.GetType().FullName)"; break }

        try {
            $checkboxWidth = ([int]$Panel.Width) - 30
            $checkbox.Size = New-Object System.Drawing.Size($checkboxWidth, 25)
        } catch {
            Write-Error "ERROR calculating checkbox size for '$($file.Name)'. `$Panel.Width evaluated to '$($Panel.Width)'. Error: $($_.Exception.Message)"
            $checkbox.Size = New-Object System.Drawing.Size(350, 25) # Fallback
        }

        $checkbox.Location = New-Object System.Drawing.Point(10, $yPos)
        $toolTip.SetToolTip($checkbox, "Full Path: $($file.FullName)")
        $Panel.Controls.Add($checkbox)
        [void]$checkboxes.Add($checkbox)
        $yPos += 30
    }
    $Panel.AutoScrollMinSize = New-Object System.Drawing.Size(0, $yPos)
    Write-Host "DEBUG: Exiting Update-Checkboxes normally."
}

# Script Discovery (using $targetFolderPath from extracted repo)
Write-Host "Discovering scripts in '$targetFolderPath'..."
$scriptFiles = @() # Initialize as empty array
if (Test-Path -LiteralPath $targetFolderPath -PathType Container) {
    try {
        # Use LiteralPath with Get-ChildItem as well
        $scriptFiles = Get-ChildItem -LiteralPath $targetFolderPath -Filter "*.ps1" -File -Recurse -ErrorAction Stop | Sort-Object FullName
        Write-Host "Found $($scriptFiles.Count) script files."
    } catch {
        Write-Error "Error discovering scripts in '$targetFolderPath': $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Error discovering scripts in '$targetFolderPath'. The list may be empty.", "Discovery Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
} else {
    Write-Warning "Target script folder '$targetFolderPath' does not exist after extraction. Cannot list scripts."
     [System.Windows.Forms.MessageBox]::Show("The target script folder '$targetFolderPath' was not found after extraction. Please check the repository structure and the path defined in the script.", "Discovery Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
     # Optionally exit or continue with an empty list
}

# Initial Checkbox Load
Write-Host "DEBUG: Type of `$Panel BEFORE initial Update-Checkboxes call: $($Panel.GetType().FullName)"
Update-Checkboxes $scriptFiles

# Search Functionality (using the correct $targetFolderPath)
$performSearch = {
    Write-Host "DEBUG: Performing search..."
    Write-Host "DEBUG: Type of `$Panel BEFORE calling Update-Checkboxes from search: $($Panel.GetType().FullName)"
    if ($Panel -isnot [System.Windows.Forms.Panel]) { Write-Warning "-> CRITICAL: `$Panel object lost BEFORE calling Update-Checkboxes from search! Type: $($Panel.GetType().FullName)"; return }

    $searchQuery = $SearchBox.Text.ToLowerInvariant().Trim()
    if ([string]::IsNullOrEmpty($searchQuery) -or $SearchBox.ForeColor -eq [System.Drawing.Color]::Gray) {
        Write-Host "DEBUG: Search query empty/placeholder, updating with all scripts."
        Update-Checkboxes $scriptFiles
    } else {
        Write-Host "DEBUG: Filtering scripts for query '$searchQuery'."
        $filteredScriptFiles = $scriptFiles | Where-Object {
            # --- Use $targetFolderPath as the base for relative path ---
            $currentRelativePath = Get-RelativePath -basePath $targetFolderPath -fullPath $_.FullName
            $currentRelativePath.ToLowerInvariant() -like "*$searchQuery*"
            # ---
        }
        Write-Host "DEBUG: Found $($filteredScriptFiles.Count) matching scripts."
        Update-Checkboxes $filteredScriptFiles
    }
    Write-Host "DEBUG: Search finished."
}
$SearchButton.Add_Click($performSearch)
$SearchBox.Add_TextChanged({ $performSearch.Invoke() })


# --- Control Buttons ---
# Flat Style settings
$flatStyle = [System.Windows.Forms.FlatStyle]::Flat
$FlatAppearanceBorderSize = 0

# Install Button
$InstallButton = New-Object System.Windows.Forms.Button; $InstallButton.Text = 'Install Selected'; $InstallButton.Size = New-Object System.Drawing.Size(150, 35); $InstallButton.Location = New-Object System.Drawing.Point(40, 450); $InstallButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold); $InstallButton.BackColor = [System.Drawing.Color]::FromArgb(255, 46, 204, 113); $InstallButton.ForeColor = [System.Drawing.Color]::White; $InstallButton.FlatStyle = $flatStyle; $InstallButton.FlatAppearance.BorderSize = $FlatAppearanceBorderSize
$Form.Controls.Add($InstallButton)

# Check/Uncheck Buttons
$CheckAllButton = New-Object System.Windows.Forms.Button; $CheckAllButton.Text = "Check All"; $CheckAllButton.Size = New-Object System.Drawing.Size(150, 30); $CheckAllButton.Location = New-Object System.Drawing.Point(40, 500); $CheckAllButton.BackColor = [System.Drawing.Color]::FromArgb(255, 52, 152, 219); $CheckAllButton.ForeColor = [System.Drawing.Color]::White; $CheckAllButton.FlatStyle = $flatStyle; $CheckAllButton.FlatAppearance.BorderSize = $FlatAppearanceBorderSize
$UncheckAllButton = New-Object System.Windows.Forms.Button; $UncheckAllButton.Text = "Uncheck All"; $UncheckAllButton.Size = New-Object System.Drawing.Size(150, 30); $UncheckAllButton.Location = New-Object System.Drawing.Point(210, 500); $UncheckAllButton.BackColor = [System.Drawing.Color]::FromArgb(255, 231, 76, 60); $UncheckAllButton.ForeColor = [System.Drawing.Color]::White; $UncheckAllButton.FlatStyle = $flatStyle; $UncheckAllButton.FlatAppearance.BorderSize = $FlatAppearanceBorderSize
$Form.Controls.AddRange(@($CheckAllButton, $UncheckAllButton))

# Preset Buttons
$Windows11BasicButton = New-Object System.Windows.Forms.Button; $Windows11BasicButton.Text = "Select Win 11 Basic"; $Windows11BasicButton.Size = New-Object System.Drawing.Size(150, 30); $Windows11BasicButton.Location = New-Object System.Drawing.Point(40, 545); $Windows11BasicButton.BackColor = [System.Drawing.Color]::FromArgb(255, 243, 156, 18); $Windows11BasicButton.ForeColor = [System.Drawing.Color]::White; $Windows11BasicButton.FlatStyle = $flatStyle; $Windows11BasicButton.FlatAppearance.BorderSize = $FlatAppearanceBorderSize
$GamingFocusedButton = New-Object System.Windows.Forms.Button; $GamingFocusedButton.Text = "Select Gaming Focus"; $GamingFocusedButton.Size = New-Object System.Drawing.Size(150, 30); $GamingFocusedButton.Location = New-Object System.Drawing.Point(210, 545); $GamingFocusedButton.BackColor = [System.Drawing.Color]::FromArgb(255, 155, 89, 182); $GamingFocusedButton.ForeColor = [System.Drawing.Color]::White; $GamingFocusedButton.FlatStyle = $flatStyle; $GamingFocusedButton.FlatAppearance.BorderSize = $FlatAppearanceBorderSize
$Form.Controls.AddRange(@($Windows11BasicButton, $GamingFocusedButton))

# Status Label
$StatusLabel = New-Object System.Windows.Forms.Label; $StatusLabel.Text = "Ready"; $StatusLabel.Location = New-Object System.Drawing.Point(10, 650); $StatusLabel.AutoSize = $false; $StatusLabel.Width = $Form.ClientSize.Width - 20; $StatusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$Form.Controls.Add($StatusLabel)


# --- Button Click Events ---

# Install Button Click
$InstallButton.Add_Click({
    $scriptsToRun = @()
    foreach ($checkbox in $checkboxes) { if ($checkbox.Checked) { $scriptsToRun += $checkbox.Tag } }
    if ($scriptsToRun.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("No scripts selected to install.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null; return }

    # Disable UI
    $Form.Controls | ForEach-Object { if ($_ -is [System.Windows.Forms.Button] -or $_ -is [System.Windows.Forms.TextBox]) { $_.Enabled = $false } }
    $StatusLabel.Text = "Installing..."; $Form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor; $Form.Refresh()

    $hadErrors = $false; $errorMessages = @()
    for ($i = 0; $i -lt $scriptsToRun.Count; $i++) {
        $scriptPath = $scriptsToRun[$i]
        # Use LiteralPath for Test-Path
        $relativeScriptName = Get-RelativePath -basePath $targetFolderPath -fullPath $scriptPath
        $StatusLabel.Text = "Running ($($i+1)/$($scriptsToRun.Count)): $relativeScriptName"; $Form.Refresh()

        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { $errorMessages += "File not found: $relativeScriptName"; $hadErrors = $true; continue }
        try {
            $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`"" -Wait -PassThru #-NoNewWindow
            if ($process.ExitCode -ne 0) { $errorMessages += "Script '$relativeScriptName' finished with errors (Exit Code: $($process.ExitCode))."; $hadErrors = $true }
        } catch { $errorMessages += "Failed to start script '$relativeScriptName'. Error: $($_.Exception.Message)"; $hadErrors = $true }
    }

    # Re-enable UI
    $Form.Controls | ForEach-Object { if ($_ -is [System.Windows.Forms.Button] -or $_ -is [System.Windows.Forms.TextBox]) { $_.Enabled = $true } }
    $Form.Cursor = [System.Windows.Forms.Cursors]::Default

    # Final status
    if ($hadErrors) { $StatusLabel.Text = "Finished with errors."; [System.Windows.Forms.MessageBox]::Show("Installation completed, but errors occurred:`n`n" + ($errorMessages -join "`n"), "Installation Errors", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null }
    else { $StatusLabel.Text = "Installation complete!"; [System.Windows.Forms.MessageBox]::Show("Selected scripts executed successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null }
    $StatusLabel.Text = "Ready"
})

# Check/Uncheck All Buttons Click
$CheckAllButton.Add_Click({ foreach ($checkbox in $checkboxes) { $checkbox.Checked = $true } })
$UncheckAllButton.Add_Click({ foreach ($checkbox in $checkboxes) { $checkbox.Checked = $false } })

# Preset Buttons Click (!!! ADJUST RELATIVE PATHS BASED ON REPO STRUCTURE !!!)
$Windows11BasicButton.Add_Click({
    # Example: These must match the RELATIVE paths shown in the list
    $basicScripts = @("Brave.ps1", "7-Zip.ps1", "Notepad++.ps1") # ADJUST AS NEEDED
    foreach ($checkbox in $checkboxes) { $checkbox.Checked = ($basicScripts -contains $checkbox.Text) }
    $foundCount = ($checkboxes | Where-Object {$_.Checked}).Count
    $StatusLabel.Text = "Selected $foundCount basic scripts."
    # Optional message box removed for brevity, StatusLabel is enough
})

$GamingFocusedButton.Add_Click({
    # Example: These must match the RELATIVE paths shown in the list
    $gamingScripts = @("Steam.ps1", "Discord.ps1", "GPU-Drivers.ps1", "GameOptimizer.ps1") # ADJUST AS NEEDED
    foreach ($checkbox in $checkboxes) { $checkbox.Checked = ($gamingScripts -contains $checkbox.Text) }
    $foundCount = ($checkboxes | Where-Object {$_.Checked}).Count
    $StatusLabel.Text = "Selected $foundCount gaming scripts."
    # Optional message box removed for brevity, StatusLabel is enough
})


# --- Display the Form ---
$Form.Add_Shown({$Form.Activate()})
[System.Windows.Forms.Application]::EnableVisualStyles()
Write-Host "DEBUG: Showing Form..."
[void]$Form.ShowDialog()
Write-Host "DEBUG: Form closed."

# --- Cleanup ---
$Form.Dispose()
Write-Host "DEBUG: Script finished."