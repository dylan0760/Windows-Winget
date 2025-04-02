

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
    # Ensure the path to the script itself is quoted correctly, especially if it contains spaces
    $scriptPath = $myinvocation.mycommand.definition
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    try {
        Start-Process powershell -Verb runAs -ArgumentList $arguments
    } catch {
        Write-Error "Failed to relaunch as administrator: $($_.Exception.Message)"
        # Attempt to show a message box if Forms assembly can be loaded quickly
        try { Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop } catch {}
        if ([System.Windows.Forms.Application]) {
            [System.Windows.Forms.MessageBox]::Show("Failed to relaunch as administrator. Please run the script manually as an Administrator.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
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
    # Ensure Forms is loaded before trying to use MessageBox
    try { Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop } catch {}
    if ([System.Windows.Forms.Application]) {
        [System.Windows.Forms.MessageBox]::Show("Failed to load essential .NET assemblies. The script cannot continue.", "Fatal Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
    exit
}

# --- Download and Extract ---
Write-Host "Setting up script environment..."
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

$tempZipPath = Join-Path $tempBaseDir "WingetRepo.zip"
$localRepoPath = Join-Path $tempBaseDir "WingetRepoExtract"
$repoUrl = "https://github.com/dylan0760/Windows-Winget/archive/refs/heads/main.zip"

Write-Host "Downloading repository from $repoUrl..."
try {
    Invoke-WebRequest -Uri $repoUrl -OutFile $tempZipPath -UseBasicParsing -ErrorAction Stop # Added UseBasicParsing for potential compatibility
    Write-Host "Download complete: $tempZipPath"
} catch {
    Write-Error "Failed to download repository from '$repoUrl': $($_.Exception.Message)"
    [System.Windows.Forms.MessageBox]::Show("Failed to download the script repository. Please check the URL and your internet connection.", "Download Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit
}

if (Test-Path -Path $localRepoPath -PathType Container) {
    Write-Host "Removing existing extraction folder: $localRepoPath"
    try { Remove-Item -Recurse -Force -Path $localRepoPath -ErrorAction Stop } catch {
        Write-Error "Failed to remove existing directory '$localRepoPath': $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Failed to remove the old script repository directory. Please close any programs using files in '$localRepoPath' and try again.", "Extraction Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        exit
    }
}

Write-Host "Extracting repository to $localRepoPath..."
try {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZipPath, $localRepoPath)
    Write-Host "Extraction complete."
} catch {
    Write-Error "Failed to extract archive '$tempZipPath': $($_.Exception.Message)"
    [System.Windows.Forms.MessageBox]::Show("Failed to extract the script repository ZIP file.", "Extraction Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit
}

try {
    Write-Host "Removing temporary zip file: $tempZipPath"
    Remove-Item -Path $tempZipPath -Force -ErrorAction SilentlyContinue
} catch { Write-Warning "Could not remove temporary zip file '$tempZipPath'." }

# --- Define Script Source from Extracted Repo ---
# !!! IMPORTANT: Verify this path matches the structure inside the downloaded ZIP !!!
$targetFolderPath = Join-Path $localRepoPath "Windows-Winget-main\Programs\Powershell Versions"
Write-Host "Target script folder set to: $targetFolderPath"

# --- GUI Code Starts Here ---

# Form Setup
$Form = New-Object System.Windows.Forms.Form
$Form.Text = 'GitHub Script Installer GUI'; $Form.Size = New-Object System.Drawing.Size(420, 720); $Form.StartPosition = 'CenterScreen'; $Form.FormBorderStyle = 'FixedDialog'; $Form.MaximizeBox = $false; $Form.MinimizeBox = $true

# ToolTip Setup
$toolTip = New-Object System.Windows.Forms.ToolTip; $toolTip.InitialDelay = 400; $toolTip.AutoPopDelay = 5000; $toolTip.ReshowDelay = 500; $toolTip.ShowAlways = $true

# Search Controls
$SearchLabel = New-Object System.Windows.Forms.Label; $SearchLabel.Text = "Search:"; $SearchLabel.Location = New-Object System.Drawing.Point(10, 15); $SearchLabel.AutoSize = $true
$SearchBox = New-Object System.Windows.Forms.TextBox; $SearchBox.Location = New-Object System.Drawing.Point(70, 12); $SearchBox.Width = 240
$SearchButton = New-Object System.Windows.Forms.Button; $SearchButton.Text = "Search"; $SearchButton.Location = New-Object System.Drawing.Point(320, 10); $SearchButton.Size = New-Object System.Drawing.Size(70, 25)
$Form.Controls.AddRange(@($SearchLabel, $SearchBox, $SearchButton))

# Placeholder text
$placeholderText = "Filter scripts (inc. path)..."; $SearchBox.ForeColor = [System.Drawing.Color]::Gray; $SearchBox.Text = $placeholderText
$SearchBox_GotFocus = { if ($SearchBox.Text -eq $placeholderText) { $SearchBox.Text = ""; $SearchBox.ForeColor = [System.Drawing.Color]::Black } }; $SearchBox.Add_GotFocus($SearchBox_GotFocus)
$SearchBox_LostFocus = { if ([string]::IsNullOrWhiteSpace($SearchBox.Text)) { $SearchBox.ForeColor = [System.Drawing.Color]::Gray; $SearchBox.Text = $placeholderText } }; $SearchBox.Add_LostFocus($SearchBox_LostFocus)

# Panel for Checkboxes
$Panel = New-Object System.Windows.Forms.Panel; $Panel.AutoScroll = $true; $Panel.Width = 380; $Panel.Height = 380; $Panel.Location = New-Object System.Drawing.Point(10, 50); $Panel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$Form.Controls.Add($Panel)
Write-Host "DEBUG: Initialized Panel. Type: $($Panel.GetType().FullName)" # Debug line

# Checkbox Management
$checkboxes = New-Object System.Collections.ArrayList

# Function to get relative path
function Get-RelativePath ($basePath, $fullPath) {
    if (-not (Test-Path -LiteralPath $basePath -PathType Container)) { Write-Warning "Base path '$basePath' does not exist in Get-RelativePath."; return $fullPath }
    try {
        $baseUri = [System.Uri]($basePath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar)
        $fullUri = [System.Uri]$fullPath; $relativeUri = $baseUri.MakeRelativeUri($fullUri)
        # Use Replace for web-style separators just in case Uri uses them, ensure Windows style for consistency
        return [Uri]::UnescapeDataString($relativeUri.OriginalString).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    } catch { Write-Warning "Error getting relative path for Base='$basePath', Full='$fullPath'. Error: $($_.Exception.Message)"; return $fullPath }
}

# Function to update the checkboxes
function Update-Checkboxes($filteredScriptFiles) {
    Write-Host "DEBUG: Entering Update-Checkboxes. Type of `$Panel: $($Panel.GetType().FullName)"
    if ($Panel -isnot [System.Windows.Forms.Panel]) { Write-Warning "-> CRITICAL: `$Panel is NOT a Panel object! Type: $($Panel.GetType().FullName)"; return }

    $Panel.Controls.Clear(); $yPos = 10; $checkboxes.Clear()
    if (-not (Test-Path -LiteralPath $targetFolderPath -PathType Container)) { Write-Warning "Target script folder path '$targetFolderPath' not found in Update-Checkboxes."; return }

    foreach ($file in $filteredScriptFiles) {
        $checkbox = New-Object System.Windows.Forms.CheckBox
        $relativePath = Get-RelativePath -basePath $targetFolderPath -fullPath $file.FullName
        $checkbox.Text = $relativePath; $checkbox.Tag = $file.FullName; $checkbox.AutoSize = $false

        # Write-Host "DEBUG: Loop iteration for '$($file.Name)'. Type of `$Panel: $($Panel.GetType().FullName). Width: $($Panel.Width)" # Optional Debug
        if ($Panel -isnot [System.Windows.Forms.Panel]) { Write-Warning "-> CRITICAL: `$Panel lost DURING loop! Type: $($Panel.GetType().FullName)"; break }

        try {
            $checkboxWidth = ([int]$Panel.Width) - 30; $checkbox.Size = New-Object System.Drawing.Size($checkboxWidth, 25)
        } catch { Write-Error "ERROR calculating checkbox size for '$($file.Name)'. `$Panel.Width evaluated to '$($Panel.Width)'. Error: $($_.Exception.Message)"; $checkbox.Size = New-Object System.Drawing.Size(350, 25) }

        $checkbox.Location = New-Object System.Drawing.Point(10, $yPos); $toolTip.SetToolTip($checkbox, "Full Path: $($file.FullName)")
        $Panel.Controls.Add($checkbox); [void]$checkboxes.Add($checkbox); $yPos += 30
    }
    $Panel.AutoScrollMinSize = New-Object System.Drawing.Size(0, $yPos); Write-Host "DEBUG: Exiting Update-Checkboxes normally."
}

# Script Discovery
Write-Host "Discovering scripts in '$targetFolderPath'..."
$scriptFiles = @()
if (Test-Path -LiteralPath $targetFolderPath -PathType Container) {
    try { $scriptFiles = Get-ChildItem -LiteralPath $targetFolderPath -Filter "*.ps1" -File -Recurse -ErrorAction Stop | Sort-Object FullName; Write-Host "Found $($scriptFiles.Count) script files." }
    catch { Write-Error "Error discovering scripts in '$targetFolderPath': $($_.Exception.Message)"; [System.Windows.Forms.MessageBox]::Show("Error discovering scripts in '$targetFolderPath'. The list may be empty.", "Discovery Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null }
} else { Write-Warning "Target script folder '$targetFolderPath' does not exist."; [System.Windows.Forms.MessageBox]::Show("The target script folder '$targetFolderPath' was not found after extraction. Please check the repository structure and the path defined in the script.", "Discovery Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null }

# Initial Checkbox Load
Write-Host "DEBUG: Type of `$Panel BEFORE initial Update-Checkboxes call: $($Panel.GetType().FullName)"
Update-Checkboxes $scriptFiles

# Search Functionality
$performSearch = {
    # Write-Host "DEBUG: Performing search..." # Optional Debug
    # Write-Host "DEBUG: Type of `$Panel BEFORE calling Update-Checkboxes from search: $($Panel.GetType().FullName)" # Optional Debug
    if ($Panel -isnot [System.Windows.Forms.Panel]) { Write-Warning "-> CRITICAL: `$Panel object lost BEFORE calling Update-Checkboxes from search! Type: $($Panel.GetType().FullName)"; return }

    $searchQuery = $SearchBox.Text.ToLowerInvariant().Trim()
    if ([string]::IsNullOrEmpty($searchQuery) -or $SearchBox.ForeColor -eq [System.Drawing.Color]::Gray) { Update-Checkboxes $scriptFiles }
    else {
        $filteredScriptFiles = $scriptFiles | Where-Object { (Get-RelativePath -basePath $targetFolderPath -fullPath $_.FullName).ToLowerInvariant() -like "*$searchQuery*" }
        Update-Checkboxes $filteredScriptFiles
    }
    # Write-Host "DEBUG: Search finished." # Optional Debug
}
$SearchButton.Add_Click($performSearch)
$SearchBox.Add_TextChanged({ $performSearch.Invoke() })

# --- Control Buttons ---
$flatStyle = [System.Windows.Forms.FlatStyle]::Flat; $FlatAppearanceBorderSize = 0
$InstallButton = New-Object System.Windows.Forms.Button; $InstallButton.Text = 'Install Selected'; $InstallButton.Size = New-Object System.Drawing.Size(150, 35); $InstallButton.Location = New-Object System.Drawing.Point(40, 450); $InstallButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold); $InstallButton.BackColor = [System.Drawing.Color]::FromArgb(255, 46, 204, 113); $InstallButton.ForeColor = [System.Drawing.Color]::White; $InstallButton.FlatStyle = $flatStyle; $InstallButton.FlatAppearance.BorderSize = $FlatAppearanceBorderSize
$CheckAllButton = New-Object System.Windows.Forms.Button; $CheckAllButton.Text = "Check All"; $CheckAllButton.Size = New-Object System.Drawing.Size(150, 30); $CheckAllButton.Location = New-Object System.Drawing.Point(40, 500); $CheckAllButton.BackColor = [System.Drawing.Color]::FromArgb(255, 52, 152, 219); $CheckAllButton.ForeColor = [System.Drawing.Color]::White; $CheckAllButton.FlatStyle = $flatStyle; $CheckAllButton.FlatAppearance.BorderSize = $FlatAppearanceBorderSize
$UncheckAllButton = New-Object System.Windows.Forms.Button; $UncheckAllButton.Text = "Uncheck All"; $UncheckAllButton.Size = New-Object System.Drawing.Size(150, 30); $UncheckAllButton.Location = New-Object System.Drawing.Point(210, 500); $UncheckAllButton.BackColor = [System.Drawing.Color]::FromArgb(255, 231, 76, 60); $UncheckAllButton.ForeColor = [System.Drawing.Color]::White; $UncheckAllButton.FlatStyle = $flatStyle; $UncheckAllButton.FlatAppearance.BorderSize = $FlatAppearanceBorderSize
$Windows11BasicButton = New-Object System.Windows.Forms.Button; $Windows11BasicButton.Text = "Select Win 11 Basic"; $Windows11BasicButton.Size = New-Object System.Drawing.Size(150, 30); $Windows11BasicButton.Location = New-Object System.Drawing.Point(40, 545); $Windows11BasicButton.BackColor = [System.Drawing.Color]::FromArgb(255, 243, 156, 18); $Windows11BasicButton.ForeColor = [System.Drawing.Color]::White; $Windows11BasicButton.FlatStyle = $flatStyle; $Windows11BasicButton.FlatAppearance.BorderSize = $FlatAppearanceBorderSize
$GamingFocusedButton = New-Object System.Windows.Forms.Button; $GamingFocusedButton.Text = "Select Gaming Focus"; $GamingFocusedButton.Size = New-Object System.Drawing.Size(150, 30); $GamingFocusedButton.Location = New-Object System.Drawing.Point(210, 545); $GamingFocusedButton.BackColor = [System.Drawing.Color]::FromArgb(255, 155, 89, 182); $GamingFocusedButton.ForeColor = [System.Drawing.Color]::White; $GamingFocusedButton.FlatStyle = $flatStyle; $GamingFocusedButton.FlatAppearance.BorderSize = $FlatAppearanceBorderSize
$StatusLabel = New-Object System.Windows.Forms.Label; $StatusLabel.Text = "Ready"; $StatusLabel.Location = New-Object System.Drawing.Point(10, 650); $StatusLabel.AutoSize = $false; $StatusLabel.Width = $Form.ClientSize.Width - 20; $StatusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$Form.Controls.AddRange(@($InstallButton, $CheckAllButton, $UncheckAllButton, $Windows11BasicButton, $GamingFocusedButton, $StatusLabel))

# --- Button Click Events ---

# Install Button Click
$InstallButton.Add_Click({
    $scriptsToRun = @(); foreach ($checkbox in $checkboxes) { if ($checkbox.Checked) { $scriptsToRun += $checkbox.Tag } }
    if ($scriptsToRun.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("No scripts selected.", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null; return }

    $Form.Controls | ForEach-Object { if ($_ -is [System.Windows.Forms.Button] -or $_ -is [System.Windows.Forms.TextBox]) { $_.Enabled = $false } }
    $StatusLabel.Text = "Installing..."; $Form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor; $Form.Refresh()
    $hadErrors = $false; $errorMessages = @()

    for ($i = 0; $i -lt $scriptsToRun.Count; $i++) {
        $scriptPath = $scriptsToRun[$i]; $relativeScriptName = Get-RelativePath -basePath $targetFolderPath -fullPath $scriptPath
        $StatusLabel.Text = "Running ($($i+1)/$($scriptsToRun.Count)): $relativeScriptName"; $Form.Refresh()
        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { $errorMessages += "NF: $relativeScriptName"; $hadErrors = $true; continue }
        try {
            $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`"" -Wait -PassThru #-NoNewWindow
            if ($process.ExitCode -ne 0) { $errorMessages += "Err($($process.ExitCode)): $relativeScriptName"; $hadErrors = $true }
        } catch { $errorMessages += "FAIL: $relativeScriptName Error: $($_.Exception.Message)"; $hadErrors = $true }
    }

    $Form.Controls | ForEach-Object { if ($_ -is [System.Windows.Forms.Button] -or $_ -is [System.Windows.Forms.TextBox]) { $_.Enabled = $true } }
    $Form.Cursor = [System.Windows.Forms.Cursors]::Default

    if ($hadErrors) { $StatusLabel.Text = "Finished with errors."; [System.Windows.Forms.MessageBox]::Show("Installation completed, but errors occurred:`n`n" + ($errorMessages -join "`n"), "Errors", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null }
    else { $StatusLabel.Text = "Installation complete!"; [System.Windows.Forms.MessageBox]::Show("Selected scripts executed successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null }
    $StatusLabel.Text = "Ready"
})

# Check/Uncheck All Buttons Click
$CheckAllButton.Add_Click({ foreach ($checkbox in $checkboxes) { $checkbox.Checked = $true } })
$UncheckAllButton.Add_Click({ foreach ($checkbox in $checkboxes) { $checkbox.Checked = $false } })

# --- PRESET BUTTONS WITH UPDATED PATHS ---

# "Windows 11 Basic Install" Button Click Event
$Windows11BasicButton.Add_Click({
    # --- ADJUST THESE RELATIVE PATHS to match your actual structure ---
    # Example: If Brave is in Browsers subdir, 7-Zip in Utilities, Notepad++ at root level
    $basicScripts = @(
        "Browsers\Brave.ps1",    # Example: Assumes Brave.ps1 is in Browsers subfolder
        "Utilities\7-Zip.ps1",   # Example: Assumes 7-Zip.ps1 is in Utilities subfolder
        "Office Tools\Notepad++.ps1"          # Example: Assumes Notepad++.ps1 is directly in $targetFolderPath
    )
    # --- END ADJUSTMENT ---

    Write-Host "Selecting Win 11 Basic Scripts. Looking for: $($basicScripts -join ', ')"

    # Iterate through checkboxes and set based on the list
    $foundCount = 0
    foreach ($checkbox in $checkboxes) {
        # Compare checkbox text (relative path) against the list
        if ($basicScripts -contains $checkbox.Text) {
            $checkbox.Checked = $true
            $foundCount++
        } else {
            $checkbox.Checked = $false # Ensure others are unchecked
        }
    }

    $StatusLabel.Text = "Selected $foundCount Win 11 Basic script(s)."
    [System.Windows.Forms.MessageBox]::Show("Applied 'Win 11 Basic' preset. Found $foundCount matching script(s).", "Preset Applied", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
})

# "Gaming Focused Install" Button Click Event
$GamingFocusedButton.Add_Click({
    # --- ADJUST THESE RELATIVE PATHS to match your actual structure ---
    # Example: Assuming subfolders like Browsers, Comms, Launchers, Utilities, Drivers
    $gamingScripts = @(
        "Browsers\Brave.ps1",            # Example Path
        "Communication\Voice Communication\Discord.ps1",             # Example Path
        "Game Distributors\Steam.ps1",           # Example Path
        "Game Distributors\EA Desktop.ps1",      # Example Path (Note space in name)
        "Utilities\7-Zip.ps1",           # Example Path
        "Notepad++.ps1",                 # Example Path (Root)
        "Game Distributors\Ubisoft Connect.ps1", # Example Path (Note space in name)
        "Game Distributors\Epic Games Launcher.ps1", # Example Path (Note space in name)
        "Game Distributors\GOG Galaxy.ps1",      # Example Path (Note space in name)
        "Utilities\Nvidia GeForce Experience.ps1" # Example Path (Note space in name)
    )
    # --- END ADJUSTMENT ---

    Write-Host "Selecting Gaming Focus Scripts. Looking for: $($gamingScripts -join ', ')"

    # Iterate through checkboxes and set based on the list
    $foundCount = 0
    foreach ($checkbox in $checkboxes) {
        # Compare checkbox text (relative path) against the list
         if ($gamingScripts -contains $checkbox.Text) {
            $checkbox.Checked = $true
            $foundCount++
        } else {
            $checkbox.Checked = $false # Ensure others are unchecked
        }
    }

    $StatusLabel.Text = "Selected $foundCount Gaming Focus script(s)."
    [System.Windows.Forms.MessageBox]::Show("Applied 'Gaming Focus' preset. Found $foundCount matching script(s).", "Preset Applied", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
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