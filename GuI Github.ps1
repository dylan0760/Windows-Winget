# Ensure necessary .NET assemblies for creating forms are loaded
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function to check if the script is running as administrator
function Check-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# Relaunch as Administrator if not already
if (-not (Check-Admin)) {
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    exit
}

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
Invoke-WebRequest -Uri $repoUrl -OutFile $tempZipPath

# Check if the repository folder exists, delete it before extraction
if (Test-Path -Path $localRepoPath) {
    Remove-Item -Recurse -Force -Path $localRepoPath
}

# Extract the downloaded .zip archive
Add-Type -AssemblyName "System.IO.Compression.FileSystem"
[System.IO.Compression.ZipFile]::ExtractToDirectory($tempZipPath, $localRepoPath)

# Optional: Remove the .zip file after extraction
Remove-Item -Path $tempZipPath

# Define the target folder where the PowerShell scripts are located
$targetFolderPath = "$localRepoPath\Windows-Winget-main\Programs\Powershell Versions"

# Sample data: Get script files from the extracted folder
$scriptFiles = Get-ChildItem -Path "$targetFolderPath\*.ps1" -Recurse

# Create the form
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Winget Script Installer"
$Form.Width = 400
$Form.Height = 750 # Increased the form height for better visibility
$Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen   # Center Form

# Create a SearchBox
$SearchBox = New-Object System.Windows.Forms.TextBox
$SearchBox.Location = New-Object System.Drawing.Point(10, 10)
$SearchBox.Width = 300
$SearchBox.Height = 25
$Form.Controls.Add($SearchBox)

# Implement Ctrl+A shortcut to select all text in SearchBox
$SearchBox.Add_KeyDown({
    param ($sender, $e)
    
    # Check if Ctrl is pressed and the key is "A"
    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::A) {
        $SearchBox.SelectAll()  # Select all text in the SearchBox
        $e.SuppressKeyPress = $true  # Prevent the "A" from being typed
    }
})


# Create a SearchButton
$SearchButton = New-Object System.Windows.Forms.Button
$SearchButton.Text = "Search"
$SearchButton.Location = New-Object System.Drawing.Point(320, 10)
$SearchButton.Width = 60
$SearchButton.Height = 25
$Form.Controls.Add($SearchButton)

# Placeholder text
$placeholderText = "Search scripts..."
$SearchBox.Text = $placeholderText

# Create a panel for dynamic checkboxes
$Panel = New-Object System.Windows.Forms.Panel
$Panel.AutoScroll = $true
$Panel.Width = 360
$Panel.Height = 380
$Panel.Location = New-Object System.Drawing.Point(10, 70)
$Form.Controls.Add($Panel)

# Create an ArrayList for tracking dynamically created checkboxes
$checkboxes = New-Object System.Collections.ArrayList

# Function to update the checkboxes
function Update-Checkboxes($filteredScriptFiles) {
    $Panel.Controls.Clear()
    $yPos = 10
    $checkboxes.Clear()

    foreach ($file in $filteredScriptFiles) {
        $checkbox = New-Object System.Windows.Forms.CheckBox
        $checkbox.Text = $file.Name
        $checkbox.Tag = $file.FullName
        $checkbox.Size = New-Object System.Drawing.Size(340, 25)
        $checkbox.Location = New-Object System.Drawing.Point(10, $yPos)

        # Add the checkbox to the panel
        $Panel.Controls.Add($checkbox)
        [void]$checkboxes.Add($checkbox)
        $yPos += 30
    }
    # Ensure the panel scrolls if needed
    $Panel.AutoScrollMinSize = New-Object System.Drawing.Size(0, $yPos)
}

# Initially load checkboxes
Update-Checkboxes $scriptFiles

# Search functionality logic
$performSearch = {
    $searchQuery = $SearchBox.Text.ToLowerInvariant().Trim() 
    if ([string]::IsNullOrEmpty($searchQuery) -or $searchQuery -eq $placeholderText.ToLowerInvariant()) {
        Update-Checkboxes $scriptFiles  # Show all if no query
    } else {
        $filteredScriptFiles = $scriptFiles | Where-Object { $_.Name.ToLowerInvariant() -like "*$searchQuery*" }
        Update-Checkboxes $filteredScriptFiles
    }
}

# Event handler for search button click
$SearchButton.Add_Click($performSearch)

# Trigger search as user types
$SearchBox.Add_TextChanged({
    $performSearch.Invoke()
})

# Create "Check All" button
$CheckAllButton = New-Object System.Windows.Forms.Button
$CheckAllButton.Text = "Check All"
$CheckAllButton.Location = New-Object System.Drawing.Point(40, 530)  # Moved above the progress bar
$CheckAllButton.BackColor = [System.Drawing.Color]::Blue  # Set the background color to Blue
$CheckAllButton.ForeColor = [System.Drawing.Color]::White  # Set the text (foreground) color to White
$Form.Controls.Add($CheckAllButton)

# Add click event for "Check All" button
$CheckAllButton.Add_Click({
    foreach ($checkbox in $checkboxes) {
        $checkbox.Checked = $true
    }
})


# Create "Uncheck All" button
$UncheckAllButton = New-Object System.Windows.Forms.Button
$UncheckAllButton.Text = "Uncheck All"
$UncheckAllButton.Location = New-Object System.Drawing.Point(40, 560)  # Moved above the progress bar
$UncheckAllButton.BackColor = [System.Drawing.Color]::Red  # Set the background color to Red
$UncheckAllButton.ForeColor = [System.Drawing.Color]::White  # Set the text color to White
$Form.Controls.Add($UncheckAllButton)

# Uncheck All button click event
$UncheckAllButton.Add_Click({
    foreach ($checkbox in $checkboxes) {
        $checkbox.Checked = $false
    }
})

# Create Install button
$InstallButton = New-Object System.Windows.Forms.Button
$InstallButton.Location = New-Object System.Drawing.Point(40, 500)  # Moved down a little due to reduced panel height
$InstallButton.Text = 'Install'
$InstallButton.BackColor = [System.Drawing.Color]::Green  # Set the background color to Green
$InstallButton.ForeColor = [System.Drawing.Color]::White  # Set the text (foreground) color to White
$Form.Controls.Add($InstallButton)

# Add InstallButton click event to launch selected scripts
$InstallButton.Add_Click({
    # Iterate through all the checkboxes
    foreach ($checkbox in $checkboxes) {
        # Check if the checkbox is checked
        if ($checkbox.Checked) {
            # Get the script file path from the Tag property
            $scriptPath = $checkbox.Tag
            
            # Check if the file exists before attempting to invoke it
            if (Test-Path $scriptPath) {
                # You can use Start-Process to run each script
                Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -Wait
            } else {
                [System.Windows.Forms.MessageBox]::Show("File not found: $scriptPath", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
    }

    # Optional: Show a message when all scripts have been executed
    [System.Windows.Forms.MessageBox]::Show("Installed selected scripts!", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# "Windows 11 Basic Install" button logic
$Windows11BasicButton = New-Object System.Windows.Forms.Button
$Windows11BasicButton.Text = "Windows 11 Basic Install"
$Windows11BasicButton.Location = New-Object System.Drawing.Point(40, 590)  # Button location
$Windows11BasicButton.Size = New-Object System.Drawing.Size(180, 30)  # Adjusted width to 180 to fit the new text
$Windows11BasicButton.BackColor = [System.Drawing.Color]::Pink  # Optional: Light Gray background
$Windows11BasicButton.ForeColor = [System.Drawing.Color]::Black  # Optional: Black text color
$Form.Controls.Add($Windows11BasicButton)

$Windows11BasicButton.Add_Click({
    foreach ($checkbox in $checkboxes) {
        if ($checkbox.Text -eq "Brave.ps1" -or $checkbox.Text -eq "7-Zip.ps1" -or $checkbox.Text -eq "Notepad++.ps1") {
            $checkbox.Checked = $true
        }
    }
    [System.Windows.Forms.MessageBox]::Show("Selected Brave, 7-Zip, and Notepad++ scripts", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# Create the "Windows 11 - Gaming Focused Install" button
$GamingFocusedButton = New-Object System.Windows.Forms.Button
$GamingFocusedButton.Text = "Windows 11 - Gaming Focused Install"
$GamingFocusedButton.Location = New-Object System.Drawing.Point(40, 630)
$GamingFocusedButton.Size = New-Object System.Drawing.Size(210, 30)  # Wider to match the text
$GamingFocusedButton.BackColor = [System.Drawing.Color]::Purple  # Optional: Light Gray background
$GamingFocusedButton.ForeColor = [System.Drawing.Color]::Black  # Optional: Black text color
$Form.Controls.Add($GamingFocusedButton)

# Click event to check scripts related to gaming installation
$GamingFocusedButton.Add_Click({
    foreach ($checkbox in $checkboxes) {
        if ($checkbox.Text -in @(
            "Brave.ps1",
            "Discord.ps1",
            "Steam.ps1",
            "EA Desktop.ps1",
            "7-Zip.ps1",
            "Notepad++.ps1",
            "Ubisoft Connect.ps1",
            "Epic Games Launcher.ps1",
            "GOG Galaxy.ps1",
            "Nvidia GeForce Experience.ps1"
        )) {
            $checkbox.Checked = $true
        }
    }
    [System.Windows.Forms.MessageBox]::Show("Selected Gaming Focused scripts!", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# Run the form
[void]$Form.ShowDialog()