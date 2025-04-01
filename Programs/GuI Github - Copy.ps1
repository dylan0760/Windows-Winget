#Requires -Version 5.1
<#
.SYNOPSIS
A Windows Forms GUI to select and install PowerShell scripts from a folder and its subdirectories.

.DESCRIPTION
Provides a user interface with checkboxes for available scripts found recursively,
search functionality based on relative paths, check/uncheck all options, preset selections,
and an install button to execute the chosen scripts. Includes debugging output.

.NOTES
Place your installable .ps1 scripts in the folder defined by $scriptFolderPath, including within subfolders.
Adjust preset button script lists to use relative paths (e.g., "Utilities\Script.ps1").
Observe DEBUG messages in the console if errors occur.
#>

# --- Configuration ---
# Path to your scripts folder (will search recursively)
$scriptFolderPath = Join-Path $PSScriptRoot "Scripts" # Adjust as needed
# --- End Configuration ---

# Load Windows Forms assembly
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Form Setup ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = 'Recursive Script Installer GUI (Debug)' # Updated title
$Form.Size = New-Object System.Drawing.Size(420, 720)
$Form.StartPosition = 'CenterScreen'
$Form.FormBorderStyle = 'FixedDialog'
$Form.MaximizeBox = $false
$Form.MinimizeBox = $true

# --- ToolTip Setup ---
$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.InitialDelay = 400
$toolTip.AutoPopDelay = 5000
$toolTip.ReshowDelay = 500
$toolTip.ShowAlways = $true

# --- Search Controls ---
$SearchLabel = New-Object System.Windows.Forms.Label
$SearchLabel.Text = "Search:"
$SearchLabel.Location = New-Object System.Drawing.Point(10, 15)
$SearchLabel.AutoSize = $true
$Form.Controls.Add($SearchLabel)

$SearchBox = New-Object System.Windows.Forms.TextBox
$SearchBox.Location = New-Object System.Drawing.Point(70, 12)
$SearchBox.Width = 240
$Form.Controls.Add($SearchBox)

$SearchButton = New-Object System.Windows.Forms.Button
$SearchButton.Text = "Search"
$SearchButton.Location = New-Object System.Drawing.Point(320, 10)
$SearchButton.Width = 70
$SearchButton.Height = 25
$Form.Controls.Add($SearchButton)

# Placeholder text for SearchBox
$placeholderText = "Filter scripts (inc. path)..."
$SearchBox.ForeColor = [System.Drawing.Color]::Gray
$SearchBox.Text = $placeholderText
$SearchBox_GotFocus = {
    if ($SearchBox.Text -eq $placeholderText) {
        $SearchBox.Text = ""
        $SearchBox.ForeColor = [System.Drawing.Color]::Black
    }
}
$SearchBox_LostFocus = {
    if ([string]::IsNullOrWhiteSpace($SearchBox.Text)) {
        $SearchBox.ForeColor = [System.Drawing.Color]::Gray
        $SearchBox.Text = $placeholderText
    }
}
$SearchBox.Add_GotFocus($SearchBox_GotFocus)
$SearchBox.Add_LostFocus($SearchBox_LostFocus)


# --- Panel for Checkboxes ---
$Panel = New-Object System.Windows.Forms.Panel
$Panel.AutoScroll = $true
$Panel.Width = 380
$Panel.Height = 380
$Panel.Location = New-Object System.Drawing.Point(10, 50)
$Panel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$Form.Controls.Add($Panel)
Write-Host "DEBUG: Initialized `$Panel. Type: $($Panel.GetType().FullName)" # DEBUG

# --- Checkbox Management ---
$checkboxes = New-Object System.Collections.ArrayList

# Function to get relative path
function Get-RelativePath ($basePath, $fullPath) {
    try {
        # Ensure consistent directory separators and remove potential trailing slash from base path
        $baseUri = [System.Uri]($basePath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar)
        $fullUri = [System.Uri]$fullPath
        $relativeUri = $baseUri.MakeRelativeUri($fullUri)
        return [Uri]::UnescapeDataString($relativeUri.OriginalString)
    } catch {
        Write-Warning "Error getting relative path for Base='$basePath', Full='$fullPath'. Error: $($_.Exception.Message)"
        return $fullPath # Fallback to full path on error
    }
}


# Function to update the checkboxes in the panel
function Update-Checkboxes($filteredScriptFiles) {
    # === DEBUG: Check $Panel type at function start ===
    Write-Host "DEBUG: Entering Update-Checkboxes. Type of `$Panel: $($Panel.GetType().FullName)"
    if ($Panel -isnot [System.Windows.Forms.Panel]) {
         Write-Warning "-> CRITICAL: `$Panel is NOT a Panel object inside Update-Checkboxes! Current Type: $($Panel.GetType().FullName)"
         # Optional: Add a MessageBox here or throw to stop execution
         # [System.Windows.Forms.MessageBox]::Show("Critical Error: Panel object lost!", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
         return # Exit function to prevent further errors
    }
    # === END DEBUG ===

    $Panel.Controls.Clear()
    $yPos = 10
    $checkboxes.Clear()

    # Ensure the base path exists for relative path calculation
    if (-not (Test-Path -LiteralPath $scriptFolderPath -PathType Container)) {
        Write-Warning "Script folder path '$scriptFolderPath' not found in Update-Checkboxes."
        return
    }

    foreach ($file in $filteredScriptFiles) {
        $checkbox = New-Object System.Windows.Forms.CheckBox
        $relativePath = Get-RelativePath -basePath $scriptFolderPath -fullPath $file.FullName
        $checkbox.Text = $relativePath
        $checkbox.Tag = $file.FullName # Store the full path
        $checkbox.AutoSize = $false

        # === DEBUG: Check $Panel just before calculation ===
        Write-Host "DEBUG: Loop iteration for '$($file.Name)'. Type of `$Panel: $($Panel.GetType().FullName). Width: $($Panel.Width)"
        if ($Panel -isnot [System.Windows.Forms.Panel]) {
             Write-Warning "-> CRITICAL: `$Panel lost DURING loop! Type: $($Panel.GetType().FullName)"
             # Decide how to handle this - maybe break the loop?
             break
        }
        # === END DEBUG ===

        # Calculate size (with cast as safeguard)
        try {
            $checkboxWidth = ([int]$Panel.Width) - 30
            $checkbox.Size = New-Object System.Drawing.Size($checkboxWidth, 25)
        } catch {
            Write-Error "ERROR calculating checkbox size for '$($file.Name)'. `$Panel.Width evaluated to '$($Panel.Width)'. Error: $($_.Exception.Message)"
            # Fallback size or skip? Using a default for now.
             $checkbox.Size = New-Object System.Drawing.Size(350, 25) # Fallback size
        }

        $checkbox.Location = New-Object System.Drawing.Point(10, $yPos)
        $toolTip.SetToolTip($checkbox, "Full Path: $($file.FullName)")
        $Panel.Controls.Add($checkbox)
        [void]$checkboxes.Add($checkbox)
        $yPos += 30
    }
    $Panel.AutoScrollMinSize = New-Object System.Drawing.Size(0, $yPos)
    Write-Host "DEBUG: Exiting Update-Checkboxes normally." # DEBUG
}

# --- Script Discovery ---
try {
    if (-not (Test-Path -LiteralPath $scriptFolderPath -PathType Container)) {
        [System.Windows.Forms.MessageBox]::Show("Script folder not found: '$scriptFolderPath'. Please create it or adjust the path in the script.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        exit
    }
    Write-Host "DEBUG: Getting script files recursively from '$scriptFolderPath'" # DEBUG
    $scriptFiles = Get-ChildItem -Path $scriptFolderPath -Filter "*.ps1" -File -Recurse | Sort-Object FullName
    Write-Host "DEBUG: Found $($scriptFiles.Count) script files." # DEBUG
} catch {
    [System.Windows.Forms.MessageBox]::Show("Error accessing script folder '$scriptFolderPath': $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit
}

# === DEBUG: Check $Panel type before initial call ===
Write-Host "DEBUG: Type of `$Panel BEFORE initial Update-Checkboxes call: $($Panel.GetType().FullName)"
# Initially load all checkboxes
Update-Checkboxes $scriptFiles
# === END DEBUG ===


# --- Search Functionality ---
$performSearch = {
    Write-Host "DEBUG: Performing search..." # DEBUG
    # === DEBUG: Check $Panel type right before filtering/updating ===
    Write-Host "DEBUG: Type of `$Panel BEFORE calling Update-Checkboxes from search: $($Panel.GetType().FullName)"
    if ($Panel -isnot [System.Windows.Forms.Panel]) {
         Write-Warning "-> CRITICAL: `$Panel object lost BEFORE calling Update-Checkboxes from search! Type: $($Panel.GetType().FullName)"
         # Optionally show a message box or handle error
         return
    }
    # === END DEBUG ===

    $searchQuery = $SearchBox.Text.ToLowerInvariant().Trim()
    if ([string]::IsNullOrEmpty($searchQuery) -or $SearchBox.ForeColor -eq [System.Drawing.Color]::Gray) {
        Write-Host "DEBUG: Search query empty/placeholder, updating with all scripts." # DEBUG
        Update-Checkboxes $scriptFiles
    } else {
        Write-Host "DEBUG: Filtering scripts for query '$searchQuery'." # DEBUG
        $filteredScriptFiles = $scriptFiles | Where-Object {
            $currentRelativePath = Get-RelativePath -basePath $scriptFolderPath -fullPath $_.FullName
            $currentRelativePath.ToLowerInvariant() -like "*$searchQuery*"
        }
        Write-Host "DEBUG: Found $($filteredScriptFiles.Count) matching scripts." # DEBUG
        Update-Checkboxes $filteredScriptFiles
    }
    Write-Host "DEBUG: Search finished." # DEBUG
}

# Event handler for search button click
$SearchButton.Add_Click($performSearch)

# Trigger search as user types in the search box
$SearchBox.Add_TextChanged({ $performSearch.Invoke() })

# --- Control Buttons ---
# (Install, Check All, Uncheck All, Preset buttons - code unchanged from previous version)

# Create "Install" button
$InstallButton = New-Object System.Windows.Forms.Button
$InstallButton.Location = New-Object System.Drawing.Point(40, 450)
$InstallButton.Size = New-Object System.Drawing.Size(150, 35)
$InstallButton.Text = 'Install Selected'
$InstallButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$InstallButton.BackColor = [System.Drawing.Color]::FromArgb(255, 46, 204, 113)
$InstallButton.ForeColor = [System.Drawing.Color]::White
$InstallButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$InstallButton.FlatAppearance.BorderSize = 0
$Form.Controls.Add($InstallButton)

# Create "Check All" button
$CheckAllButton = New-Object System.Windows.Forms.Button
$CheckAllButton.Text = "Check All"
$CheckAllButton.Location = New-Object System.Drawing.Point(40, 500)
$CheckAllButton.Size = New-Object System.Drawing.Size(150, 30)
$CheckAllButton.BackColor = [System.Drawing.Color]::FromArgb(255, 52, 152, 219)
$CheckAllButton.ForeColor = [System.Drawing.Color]::White
$CheckAllButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$CheckAllButton.FlatAppearance.BorderSize = 0
$Form.Controls.Add($CheckAllButton)

# Create "Uncheck All" button
$UncheckAllButton = New-Object System.Windows.Forms.Button
$UncheckAllButton.Text = "Uncheck All"
$UncheckAllButton.Location = New-Object System.Drawing.Point(210, 500)
$UncheckAllButton.Size = New-Object System.Drawing.Size(150, 30)
$UncheckAllButton.BackColor = [System.Drawing.Color]::FromArgb(255, 231, 76, 60)
$UncheckAllButton.ForeColor = [System.Drawing.Color]::White
$UncheckAllButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$UncheckAllButton.FlatAppearance.BorderSize = 0
$Form.Controls.Add($UncheckAllButton)

# Create "Windows 11 Basic Install" button
$Windows11BasicButton = New-Object System.Windows.Forms.Button
$Windows11BasicButton.Text = "Select Win 11 Basic"
$Windows11BasicButton.Location = New-Object System.Drawing.Point(40, 545)
$Windows11BasicButton.Size = New-Object System.Drawing.Size(150, 30)
$Windows11BasicButton.BackColor = [System.Drawing.Color]::FromArgb(255, 243, 156, 18)
$Windows11BasicButton.ForeColor = [System.Drawing.Color]::White
$Windows11BasicButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$Windows11BasicButton.FlatAppearance.BorderSize = 0
$Form.Controls.Add($Windows11BasicButton)

# Create "Gaming Focused Install" button
$GamingFocusedButton = New-Object System.Windows.Forms.Button
$GamingFocusedButton.Text = "Select Gaming Focus"
$GamingFocusedButton.Location = New-Object System.Drawing.Point(210, 545)
$GamingFocusedButton.Size = New-Object System.Drawing.Size(150, 30)
$GamingFocusedButton.BackColor = [System.Drawing.Color]::FromArgb(255, 155, 89, 182)
$GamingFocusedButton.ForeColor = [System.Drawing.Color]::White
$GamingFocusedButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$GamingFocusedButton.FlatAppearance.BorderSize = 0
$Form.Controls.Add($GamingFocusedButton)

# Status Label
$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Text = "Ready"
$StatusLabel.Location = New-Object System.Drawing.Point(10, 650)
$StatusLabel.AutoSize = $false
$StatusLabel.Width = $Form.ClientSize.Width - 20
$StatusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$Form.Controls.Add($StatusLabel)

# --- Button Click Events ---

# "Install" Button Click Event
$InstallButton.Add_Click({
    $scriptsToRun = @()
    foreach ($checkbox in $checkboxes) {
        if ($checkbox.Checked) {
            $scriptsToRun += $checkbox.Tag # Use full path from Tag
        }
    }

    if ($scriptsToRun.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No scripts selected to install.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        return
    }

    # Disable UI
    $InstallButton.Enabled = $false; $CheckAllButton.Enabled = $false; $UncheckAllButton.Enabled = $false
    $Windows11BasicButton.Enabled = $false; $GamingFocusedButton.Enabled = $false
    $SearchButton.Enabled = $false; $SearchBox.Enabled = $false
    $StatusLabel.Text = "Installing..."; $Form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor; $Form.Refresh()

    $hadErrors = $false
    $errorMessages = @()

    for ($i = 0; $i -lt $scriptsToRun.Count; $i++) {
        $scriptPath = $scriptsToRun[$i]
        $relativeScriptName = Get-RelativePath -basePath $scriptFolderPath -fullPath $scriptPath
        $StatusLabel.Text = "Running ($($i+1)/$($scriptsToRun.Count)): $relativeScriptName"; $Form.Refresh()

        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
            $errorMessages += "File not found: $relativeScriptName"; $hadErrors = $true; continue
        }

        try {
            $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`"" -Wait -PassThru #-NoNewWindow

            if ($process.ExitCode -ne 0) {
                $errorMessages += "Script '$relativeScriptName' finished with errors (Exit Code: $($process.ExitCode))."; $hadErrors = $true
            }
        } catch {
            $errorMessages += "Failed to start script '$relativeScriptName'. Error: $($_.Exception.Message)"; $hadErrors = $true
        }
    }

    # Re-enable UI
    $InstallButton.Enabled = $true; $CheckAllButton.Enabled = $true; $UncheckAllButton.Enabled = $true
    $Windows11BasicButton.Enabled = $true; $GamingFocusedButton.Enabled = $true
    $SearchButton.Enabled = $true; $SearchBox.Enabled = $true
    $Form.Cursor = [System.Windows.Forms.Cursors]::Default

    # Final status
    if ($hadErrors) {
        $StatusLabel.Text = "Finished with errors."
        [System.Windows.Forms.MessageBox]::Show("Installation completed, but errors occurred:`n`n" + ($errorMessages -join "`n"), "Installation Errors", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    } else {
        $StatusLabel.Text = "Installation complete!"
        [System.Windows.Forms.MessageBox]::Show("Selected scripts executed successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    }
    $StatusLabel.Text = "Ready"
})

# "Check All" Button Click Event
$CheckAllButton.Add_Click({ foreach ($checkbox in $checkboxes) { $checkbox.Checked = $true } })

# "Uncheck All" Button Click Event
$UncheckAllButton.Add_Click({ foreach ($checkbox in $checkboxes) { $checkbox.Checked = $false } })

# "Windows 11 Basic Install" Button Click Event
$Windows11BasicButton.Add_Click({
    # --- IMPORTANT: Use relative paths exactly as displayed in the list ---
    $basicScripts = @("Apps/Brave.ps1", "Utils/7-Zip.ps1", "Notepad++.ps1") # ADJUST THESE
    # ---

    foreach ($checkbox in $checkboxes) { $checkbox.Checked = $false }
    $foundCount = 0
    $foundScriptsList = [System.Collections.Generic.List[string]]::new()
    foreach ($checkbox in $checkboxes) {
        if ($basicScripts -contains $checkbox.Text) {
            $checkbox.Checked = $true
            $foundScriptsList.Add($checkbox.Text)
            $foundCount++
        }
    }
    $StatusLabel.Text = "Selected $foundCount basic scripts."
    [System.Windows.Forms.MessageBox]::Show("Selected scripts for 'Win 11 Basic': $($foundScriptsList -join ', ')", "Preset Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
})

# "Gaming Focused Install" Button Click Event
$GamingFocusedButton.Add_Click({
    # --- IMPORTANT: Use relative paths exactly as displayed in the list ---
    $gamingScripts = @("Games/Steam.ps1", "Apps/Discord.ps1", "Drivers/GPU-Drivers.ps1", "Optimizers/GameOptimizer.ps1") # ADJUST THESE
    # ---

    foreach ($checkbox in $checkboxes) { $checkbox.Checked = $false }
    $foundCount = 0
    $foundScriptsList = [System.Collections.Generic.List[string]]::new()
    foreach ($checkbox in $checkboxes) {
         if ($gamingScripts -contains $checkbox.Text) {
            $checkbox.Checked = $true
            $foundScriptsList.Add($checkbox.Text)
            $foundCount++
        }
    }
     $StatusLabel.Text = "Selected $foundCount gaming scripts."
    [System.Windows.Forms.MessageBox]::Show("Selected scripts for 'Gaming Focus': $($foundScriptsList -join ', ')", "Preset Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
})


# --- Display the Form ---
$Form.Add_Shown({$Form.Activate()})
[System.Windows.Forms.Application]::EnableVisualStyles()
Write-Host "DEBUG: Showing Form..." # DEBUG
[void]$Form.ShowDialog()
Write-Host "DEBUG: Form closed." # DEBUG

# --- Cleanup (Optional) ---
$Form.Dispose()
Write-Host "DEBUG: Script finished." # DEBUG