# Function to check for Administrator privileges
function Check-Admin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Relaunch as Administrator if not already, bypassing execution policy
if (-not (Check-Admin)) {
    Write-Warning "Administrator privileges are required. Attempting to relaunch with elevated permissions..."
    try {
        # Get the path to the current script file
        $scriptPath = $MyInvocation.MyCommand.Path
        # Construct the arguments for the new PowerShell process
        # -NoProfile: Speeds up startup slightly
        # -ExecutionPolicy Bypass: Ignores the execution policy for this session
        # -File: Specifies the script file to run
        # Note the use of triple quotes (`"`") or backticks (`"`) to handle paths with spaces
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

        # Start a new PowerShell process elevated (RunAs)
        Start-Process powershell -Verb RunAs -ArgumentList $arguments

        # Optional: Add error handling if Start-Process fails
    } catch {
        Write-Error "Failed to relaunch as administrator: $($_.Exception.Message)"
        # You could add a pause here or a message box if needed
        Read-Host "Press Enter to exit..."
    }
    # Exit the current, non-elevated script instance
    exit
}





# Add required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName "System.IO.Compression.FileSystem"



# --- Download and Extract Repository Section ---

# Ensure the C:\temp directory exists before downloading the zip
if (-not (Test-Path -Path "C:\temp")) {
    New-Item -Path "C:\temp" -ItemType Directory
}

# Path where GitHub repo zip will be downloaded and extracted
$tempZipPath = "C:\temp\Winget.zip"
$localRepoPath = "C:\temp\Winget"

# URL of the GitHub repo zip (update the branch name if necessary)
$repoUrl = "https://github.com/dylan0760/Windows-Winget/archive/refs/heads/main.zip"

# Download the .zip file from GitHub
Write-Host "Downloading repository from $repoUrl..."
try {
    Invoke-WebRequest -Uri $repoUrl -OutFile $tempZipPath -UseBasicParsing
    Write-Host "Download complete: $tempZipPath"
} catch {
    Write-Error "Failed to download repository from '$repoUrl': $($_.Exception.Message)"
    [System.Windows.Forms.MessageBox]::Show("Failed to download the script repository. Please check the URL and your internet connection.", "Download Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit
}

# Check if the repository folder exists, delete it before extraction
if (Test-Path -Path $localRepoPath) {
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
    exit
}

# Remove the .zip file after extraction
try {
    Write-Host "Removing temporary zip file: $tempZipPath"
    Remove-Item -Path $tempZipPath -Force -ErrorAction SilentlyContinue
} catch { 
    Write-Warning "Could not remove temporary zip file '$tempZipPath'." 
}

# Define the target folder where the PowerShell scripts are located
$targetFolderPath = "$localRepoPath\Windows-Winget-main\Programs\Powershell Versions"
Write-Host "Target script folder set to: $targetFolderPath"

# --- Theme Variables and Functions ---

$DarkMode = $false
$ThemeColors = @{
    Light = @{
        FormBackground = [System.Drawing.Color]::WhiteSmoke
        TextColor = [System.Drawing.Color]::Black
        PanelBackground = [System.Drawing.Color]::White
        ButtonBackground = [System.Drawing.Color]::FromArgb(255, 65, 105, 225)
        ButtonText = [System.Drawing.Color]::White
        CheckboxBackground = [System.Drawing.Color]::White
        CheckboxText = [System.Drawing.Color]::Black
        SearchBackground = [System.Drawing.Color]::White
        SearchText = [System.Drawing.Color]::Black
        SearchPlaceholder = [System.Drawing.Color]::Gray
    }
    Dark = @{
        FormBackground = [System.Drawing.Color]::FromArgb(255, 43, 43, 43)
        TextColor = [System.Drawing.Color]::LightGray
        PanelBackground = [System.Drawing.Color]::FromArgb(255, 55, 55, 55)
        ButtonBackground = [System.Drawing.Color]::FromArgb(255, 75, 110, 175)
        ButtonText = [System.Drawing.Color]::White
        CheckboxBackground = [System.Drawing.Color]::FromArgb(255, 65, 65, 65)
        CheckboxText = [System.Drawing.Color]::LightGray
        SearchBackground = [System.Drawing.Color]::FromArgb(255, 65, 65, 65)
        SearchText = [System.Drawing.Color]::LightGray
        SearchPlaceholder = [System.Drawing.Color]::Silver
    }
}

function Apply-Theme {
    param ([bool]$IsDarkMode)
    
    $theme = if ($IsDarkMode) { $ThemeColors.Dark } else { $ThemeColors.Light }
    
    # Apply to form
    $Form.BackColor = $theme.FormBackground
    $Form.ForeColor = $theme.TextColor
    
    # Apply to panel
    $Panel.BackColor = $theme.PanelBackground
    
    # Apply to all buttons
    $Form.Controls | Where-Object { $_ -is [System.Windows.Forms.Button] } | ForEach-Object {
        $_.BackColor = $theme.ButtonBackground
        $_.ForeColor = $theme.ButtonText
    }
    
    # Special buttons keep their colors
    $CheckAllButton.BackColor = [System.Drawing.Color]::FromArgb(255, 46, 204, 113)
    $UncheckAllButton.BackColor = [System.Drawing.Color]::FromArgb(255, 231, 76, 60)
    $Windows11BasicButton.BackColor = [System.Drawing.Color]::FromArgb(255, 243, 156, 18)
    $GamingFocusedButton.BackColor = [System.Drawing.Color]::FromArgb(255, 155, 89, 182)
    
    # Apply to all checkboxes
    $Panel.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] } | ForEach-Object {
        $_.BackColor = $theme.CheckboxBackground
        $_.ForeColor = $theme.CheckboxText
    }
    
    # Apply to search box
    $SearchBox.BackColor = $theme.SearchBackground
    $SearchBox.ForeColor = if ($SearchBox.Text -eq "Search...") { $theme.SearchPlaceholder } else { $theme.SearchText }
    
    # Apply to status label
    $StatusLabel.ForeColor = $theme.TextColor
}

# Helper function to get relative path
function Get-RelativePath {
    param (
        [Parameter(Mandatory=$true)][string]$basePath,
        [Parameter(Mandatory=$true)][string]$fullPath
    )
    if (-not $fullPath.StartsWith($basePath, [StringComparison]::OrdinalIgnoreCase)) { return $fullPath }
    $relativePath = $fullPath.Substring($basePath.Length)
    if ($relativePath.StartsWith('\')) { $relativePath = $relativePath.Substring(1) }
    return $relativePath
}

# --- GUI Code Starts Here ---

# Create UI
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Windows-Winget Script Installer"
$Form.Size = New-Object System.Drawing.Size(800, 700)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$Form.MaximizeBox = $false

# Panel for scrolling checkboxes
$Panel = New-Object System.Windows.Forms.Panel
$Panel.Location = New-Object System.Drawing.Point(20, 80)
$Panel.Size = New-Object System.Drawing.Size(750, 400)
$Panel.AutoScroll = $true
$Panel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$Form.Controls.Add($Panel)

# Global checkbox array
$script:checkboxes = @()

# Function to update checkboxes based on search filter and script files
function Update-Checkboxes {
    param ([System.IO.FileInfo[]]$files)
    
    $Panel.Controls.Clear()
    $script:checkboxes = @()
    $y = 10
    
    # Filter the files based on search text if provided
    if ($SearchBox.Text -and $SearchBox.Text -ne "Search...") {
        $searchTerm = $SearchBox.Text.ToLower()
        $filteredFiles = $files | Where-Object { 
            (Get-RelativePath -basePath $targetFolderPath -fullPath $_.FullName).ToLower().Contains($searchTerm) 
        }
    } else {
        $filteredFiles = $files
    }
    
    foreach ($file in $filteredFiles) {
        $relativePath = Get-RelativePath -basePath $targetFolderPath -fullPath $file.FullName
        $checkbox = New-Object System.Windows.Forms.CheckBox
        $checkbox.Text = $relativePath
        $checkbox.Location = New-Object System.Drawing.Point(10, $y)
        
        # Fix the checkbox size calculation by ensuring we have an integer
        try {
            # First get the panel width as an integer
            $panelWidth = [int]$Panel.Width
            # Then calculate the checkbox width with a safe approach
            $checkboxWidth = $panelWidth - 40
            # Apply the size
            $checkbox.Size = New-Object System.Drawing.Size($checkboxWidth, 22)
        } catch {
            Write-Host "Error setting checkbox size: $($_.Exception.Message)"
            # Fallback to a safe default size
            $checkbox.Size = New-Object System.Drawing.Size(700, 22)
        }
        
        $checkbox.Checked = $false
        $Panel.Controls.Add($checkbox)
        $script:checkboxes += $checkbox
        $y += 25
    }
}

# Search box
$SearchBox = New-Object System.Windows.Forms.TextBox
$SearchBox.Location = New-Object System.Drawing.Point(20, 50)
$SearchBox.Size = New-Object System.Drawing.Size(750, 22)
$SearchBox.Text = "Search..."
$SearchBox.ForeColor = [System.Drawing.Color]::Gray
$Form.Controls.Add($SearchBox)

# Search events
$SearchBox.Add_Enter({
    if ($this.Text -eq "Search...") {
        $this.Text = ""
        $theme = if ($DarkMode) { $ThemeColors.Dark } else { $ThemeColors.Light }
        $this.ForeColor = $theme.SearchText
    }
})

$SearchBox.Add_Leave({
    if ($this.Text -eq "") {
        $this.Text = "Search..."
        $this.ForeColor = [System.Drawing.Color]::Gray
    }
})

$SearchBox.Add_TextChanged({
    if ($this.Text -ne "Search...") {
        Update-Checkboxes $scriptFiles
    }
})

# Title label
$TitleLabel = New-Object System.Windows.Forms.Label
$TitleLabel.Text = "Windows-Winget Script Installer"
$TitleLabel.Location = New-Object System.Drawing.Point(20, 20)
$TitleLabel.Size = New-Object System.Drawing.Size(300, 20)
$TitleLabel.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($TitleLabel)

# Status Label
$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Text = "Ready"
$StatusLabel.Location = New-Object System.Drawing.Point(20, 590)
$StatusLabel.Size = New-Object System.Drawing.Size(750, 20)
$StatusLabel.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Regular)
$Form.Controls.Add($StatusLabel)

# Define button styles
$flatStyle = [System.Windows.Forms.FlatStyle]::Flat
$FlatAppearanceBorderSize = 0

# Buttons
$InstallButton = New-Object System.Windows.Forms.Button
$InstallButton.Text = "Install Selected"
$InstallButton.Size = New-Object System.Drawing.Size(150, 30)
$InstallButton.Location = New-Object System.Drawing.Point(620, 500)
$InstallButton.BackColor = [System.Drawing.Color]::FromArgb(255, 65, 105, 225)
$InstallButton.ForeColor = [System.Drawing.Color]::White
$InstallButton.FlatStyle = $flatStyle
$InstallButton.FlatAppearance.BorderSize = $FlatAppearanceBorderSize
$Form.Controls.Add($InstallButton)

$CheckAllButton = New-Object System.Windows.Forms.Button
$CheckAllButton.Text = "Check All"
$CheckAllButton.Size = New-Object System.Drawing.Size(150, 30)
$CheckAllButton.Location = New-Object System.Drawing.Point(40, 500)
$CheckAllButton.BackColor = [System.Drawing.Color]::FromArgb(255, 46, 204, 113)
$CheckAllButton.ForeColor = [System.Drawing.Color]::White
$CheckAllButton.FlatStyle = $flatStyle
$CheckAllButton.FlatAppearance.BorderSize = $FlatAppearanceBorderSize
$Form.Controls.Add($CheckAllButton)

$UncheckAllButton = New-Object System.Windows.Forms.Button
$UncheckAllButton.Text = "Uncheck All"
$UncheckAllButton.Size = New-Object System.Drawing.Size(150, 30)
$UncheckAllButton.Location = New-Object System.Drawing.Point(210, 500)
$UncheckAllButton.BackColor = [System.Drawing.Color]::FromArgb(255, 231, 76, 60)
$UncheckAllButton.ForeColor = [System.Drawing.Color]::White
$UncheckAllButton.FlatStyle = $flatStyle
$UncheckAllButton.FlatAppearance.BorderSize = $FlatAppearanceBorderSize
$Form.Controls.Add($UncheckAllButton)

$Windows11BasicButton = New-Object System.Windows.Forms.Button
$Windows11BasicButton.Text = "Select Win 11 Basic"
$Windows11BasicButton.Size = New-Object System.Drawing.Size(150, 30)
$Windows11BasicButton.Location = New-Object System.Drawing.Point(40, 545)
$Windows11BasicButton.BackColor = [System.Drawing.Color]::FromArgb(255, 243, 156, 18)
$Windows11BasicButton.ForeColor = [System.Drawing.Color]::White
$Windows11BasicButton.FlatStyle = $flatStyle
$Windows11BasicButton.FlatAppearance.BorderSize = $FlatAppearanceBorderSize
$Form.Controls.Add($Windows11BasicButton)

# Create the "Windows 11 - Gaming Focused Install" button
$GamingFocusedButton = New-Object System.Windows.Forms.Button
$GamingFocusedButton.Text = "Gaming Focused"
$GamingFocusedButton.Location = New-Object System.Drawing.Point(210, 545)
$GamingFocusedButton.Size = New-Object System.Drawing.Size(150, 30)
$GamingFocusedButton.BackColor = [System.Drawing.Color]::FromArgb(255, 155, 89, 182)  # Purple color
$GamingFocusedButton.ForeColor = [System.Drawing.Color]::White
$GamingFocusedButton.FlatStyle = $flatStyle
$GamingFocusedButton.FlatAppearance.BorderSize = $FlatAppearanceBorderSize
$Form.Controls.Add($GamingFocusedButton)

$ToggleThemeButton = New-Object System.Windows.Forms.Button
$ToggleThemeButton.Text = "Toggle Dark Mode"
$ToggleThemeButton.Size = New-Object System.Drawing.Size(150, 30)
$ToggleThemeButton.Location = New-Object System.Drawing.Point(380, 545)
$ToggleThemeButton.BackColor = [System.Drawing.Color]::FromArgb(255, 52, 152, 219)
$ToggleThemeButton.ForeColor = [System.Drawing.Color]::White
$ToggleThemeButton.FlatStyle = $flatStyle
$ToggleThemeButton.FlatAppearance.BorderSize = $FlatAppearanceBorderSize
$ToggleThemeButton.Add_Click({
    $script:DarkMode = -not $script:DarkMode
    Apply-Theme -IsDarkMode $script:DarkMode
})
$Form.Controls.Add($ToggleThemeButton)

# Multithreaded script running function
function Run-Scripts {
    $Form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $Form.Controls | ForEach-Object { if ($_ -is [System.Windows.Forms.Button] -or $_ -is [System.Windows.Forms.TextBox]) { $_.Enabled = $false } }
    
    $scriptsToRun = @($Panel.Controls | Where-Object { ($_ -is [System.Windows.Forms.CheckBox]) -and $_.Checked } | ForEach-Object { 
        $checkboxText = $_.Text
        $scriptFiles | Where-Object { (Get-RelativePath -basePath $targetFolderPath -fullPath $_.FullName) -eq $checkboxText } | Select-Object -ExpandProperty FullName 
    })
    
    if ($scriptsToRun.Count -eq 0) {
        $StatusLabel.Text = "No scripts selected"
        $Form.Controls | ForEach-Object { if ($_ -is [System.Windows.Forms.Button] -or $_ -is [System.Windows.Forms.TextBox]) { $_.Enabled = $true } }
        $Form.Cursor = [System.Windows.Forms.Cursors]::Default
        return
    }
    
    $StatusLabel.Text = "Preparing to run $($scriptsToRun.Count) scripts..."
    $Form.Refresh()
    
    $errorMessages = @()
    $hadErrors = $false
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 620)
    $progressBar.Size = New-Object System.Drawing.Size($Form.ClientSize.Width - 40, 20)
    $progressBar.Minimum = 0
    $progressBar.Maximum = $scriptsToRun.Count
    $progressBar.Value = 0
    $Form.Controls.Add($progressBar)
    $Form.Refresh()
    
    # Create runspace pool for multi-threading
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, 5)  # Min 1, Max 5 threads
    $runspacePool.Open()
    
    $runspaces = @()
    $scriptResults = @{}
    
    for ($i = 0; $i -lt $scriptsToRun.Count; $i++) {
        $scriptPath = $scriptsToRun[$i]
        $relativeScriptName = Get-RelativePath -basePath $targetFolderPath -fullPath $scriptPath
        
        # Create PowerShell instance and add script
        $powershell = [powershell]::Create().AddScript({
            param ($scriptPath, $index, $scriptName)
            
            $result = @{
                Index = $index
                Name = $scriptName
                Success = $false
                ErrorMessage = ""
            }
            
            if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
                $result.ErrorMessage = "NF: $scriptName"
                return $result
            }
            
            try {
                $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`"" -Wait -PassThru
                if ($process.ExitCode -ne 0) {
                    $result.ErrorMessage = "Err($($process.ExitCode)): $scriptName"
                } else {
                    $result.Success = $true
                }
            } catch {
                $result.ErrorMessage = "FAIL: $scriptName Error: $($_.Exception.Message)"
            }
            
            return $result
        }).AddArgument($scriptPath).AddArgument($i).AddArgument($relativeScriptName)
        
        # Configure runspace
        $powershell.RunspacePool = $runspacePool
        
        # Start script asynchronously
        $runspaces += [PSCustomObject]@{
            Index = $i
            PowerShell = $powershell
            Result = $powershell.BeginInvoke()
        }
    }
    
    # Wait for all runspaces to complete and update progress
    $completedCount = 0
    while ($runspaces.Where({ -not $_.Result.IsCompleted }).Count -gt 0) {
        $newlyCompleted = $runspaces.Where({ $_.Result.IsCompleted -and -not $scriptResults.ContainsKey($_.Index) })
        
        foreach ($runspace in $newlyCompleted) {
            $result = $runspace.PowerShell.EndInvoke($runspace.Result)
            $scriptResults[$runspace.Index] = $result
            
            $completedCount++
            
            # Update UI from UI thread
            $Form.Invoke([Action]{
                $progressBar.Value = $completedCount
                $StatusLabel.Text = "Running ($completedCount/$($scriptsToRun.Count)): $($result.Name)"
                
                if (-not $result.Success -and -not [string]::IsNullOrEmpty($result.ErrorMessage)) {
                    $errorMessages += $result.ErrorMessage
                    $hadErrors = $true
                }
                
                $Form.Refresh()
            })
        }
        
        Start-Sleep -Milliseconds 200
    }
    
    # Clean up runspaces
    foreach ($runspace in $runspaces) {
        $runspace.PowerShell.Dispose()
    }
    $runspacePool.Close()
    $runspacePool.Dispose()
    
    # Final UI update
    $Form.Invoke([Action]{
        $Form.Controls.Remove($progressBar)
        
        if ($hadErrors) {
            $StatusLabel.Text = "Completed with errors"
            [System.Windows.Forms.MessageBox]::Show("Installation completed, but errors occurred:`n`n" + ($errorMessages -join "`n"), "Errors", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        } else {
            $StatusLabel.Text = "All scripts completed successfully"
            [System.Windows.Forms.MessageBox]::Show("Selected scripts executed successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        }
        
        $Form.Controls | ForEach-Object { if ($_ -is [System.Windows.Forms.Button] -or $_ -is [System.Windows.Forms.TextBox]) { $_.Enabled = $true } }
        $Form.Cursor = [System.Windows.Forms.Cursors]::Default
        $Form.Refresh()
    })
}

# Button event handlers
$InstallButton.Add_Click({ Run-Scripts })

$CheckAllButton.Add_Click({
    $Panel.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] } | ForEach-Object { $_.Checked = $true }
})

$UncheckAllButton.Add_Click({
    $Panel.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] } | ForEach-Object { $_.Checked = $false }
})

$Windows11BasicButton.Add_Click({
    # First, uncheck all
    $Panel.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] } | ForEach-Object { $_.Checked = $false }
    
    # Basic Win11 scripts to select - modify these patterns as needed for your specific scripts
    $basicScripts = @(
        "Brave.ps1",
        "7-Zip.ps1",
        "Notepad++.ps1",
        "VLC.ps1"
    )
    
    $selectedCount = 0
    foreach ($checkbox in $Panel.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] }) {
        # Extract just the filename from the path for easier matching
        $filename = Split-Path -Leaf $checkbox.Text
        
        # Check if the filename is in our list or if it matches with or without .ps1 extension
        if ($basicScripts -contains $filename -or 
            $basicScripts -contains ($filename -replace '\.ps1$', '') -or 
            $basicScripts -contains "$($filename).ps1") {
            $checkbox.Checked = $true
            $selectedCount++
        }
    }
    
    # Update status and show message
    $StatusLabel.Text = "Selected $selectedCount basic script(s)"
    [System.Windows.Forms.MessageBox]::Show("Selected $selectedCount basic script(s)!", "Basic Preset Applied", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# Click event to check scripts related to gaming installation
$GamingFocusedButton.Add_Click({
    # First, uncheck all
    $Panel.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] } | ForEach-Object { $_.Checked = $false }
    
    # Gaming-focused scripts to select
    $gamingScripts = @(
        "Brave.ps1",
        "Discord.ps1",
        "Steam.ps1", 
        "EA Desktop.ps1",
        "7-Zip.ps1",
        "Notepad++.ps1",
        "Ubisoft Connect.ps1",
        "Epic Games Launcher.ps1",
        "GOG Galaxy.ps1",
        "NVIDIA App Install.ps1"
    )
    
    $selectedCount = 0
    foreach ($checkbox in $Panel.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] }) {
        # Extract just the filename from the path for easier matching
        $filename = Split-Path -Leaf $checkbox.Text
        
        # Check if the filename is in our list or if it matches with or without .ps1 extension
        if ($gamingScripts -contains $filename -or 
            $gamingScripts -contains ($filename -replace '\.ps1$', '') -or 
            $gamingScripts -contains "$($filename).ps1") {
            $checkbox.Checked = $true
            $selectedCount++
        }
    }
    
    # Update status and show message
    $StatusLabel.Text = "Selected $selectedCount gaming-focused script(s)"
    [System.Windows.Forms.MessageBox]::Show("Selected $selectedCount gaming-focused script(s)!", "Gaming Preset Applied", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# Script Discovery
Write-Host "Discovering scripts in '$targetFolderPath'..."
$scriptFiles = @()
if (Test-Path -LiteralPath $targetFolderPath -PathType Container) {
    try { 
        $scriptFiles = Get-ChildItem -LiteralPath $targetFolderPath -Filter "*.ps1" -File -Recurse -ErrorAction Stop | Sort-Object FullName
        Write-Host "Found $($scriptFiles.Count) script files." 
    }
    catch { 
        Write-Error "Error discovering scripts in '$targetFolderPath': $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Error discovering scripts in '$targetFolderPath'. The list may be empty.", "Discovery Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null 
    }
} else { 
    Write-Warning "Target script folder '$targetFolderPath' does not exist."
    [System.Windows.Forms.MessageBox]::Show("The target script folder '$targetFolderPath' was not found. Please check the repository structure and the path defined in the script.", "Discovery Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null 
}

# Initial Checkbox Load
Update-Checkboxes $scriptFiles

# Initialize with light theme by default
Apply-Theme -IsDarkMode $DarkMode

# Show the form
$Form.Add_Shown({$Form.Activate()})
[void]$Form.ShowDialog()