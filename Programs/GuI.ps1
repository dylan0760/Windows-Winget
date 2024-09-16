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

# Path to the directory containing the PowerShell scripts
$scriptFolderPath = "\\OPHELIA\Plex Server\My Software\Windows\Windows Winget\Programs\Windows-Winget\Programs\Powershell Versions"

# Get all .ps1 files in the folder and its subdirectories
$scriptFiles = Get-ChildItem -Path $scriptFolderPath -Recurse -Filter "*.ps1"

# Define the GUI form
$Form = New-Object system.Windows.Forms.Form
$Form.Text = 'Select programs to install'
$Form.Width = 400
$Form.Height = 600

# Create a TextBox for searching with dynamic placeholder behavior
$SearchBox = New-Object System.Windows.Forms.TextBox
$SearchBox.Location = New-Object System.Drawing.Point(10, 10)
$SearchBox.Size = New-Object System.Drawing.Size(270, 25)

# Placeholder text simulation
$placeholderText = "Search programs..."

# Attach GotFocus event handler to clear placeholder text when the user focuses on the text box
$SearchBox.Add_GotFocus({
    if ($SearchBox.Text -eq $placeholderText) {
        $SearchBox.Text = ""
        $SearchBox.ForeColor = [System.Drawing.Color]::Black
    }
})

# Attach LostFocus event handler to restore placeholder text when the textbox is empty and loses focus
$SearchBox.Add_LostFocus({
    if ([string]::IsNullOrEmpty($SearchBox.Text)) {
        $SearchBox.Text = $placeholderText
        $SearchBox.ForeColor = [System.Drawing.Color]::Gray
    }
})

# Initialize the textbox with placeholder text and a light color to differentiate it
$SearchBox.Text = $placeholderText
$SearchBox.ForeColor = [System.Drawing.Color]::Gray

# Create a Search button (still allowing manual search)
$SearchButton = New-Object System.Windows.Forms.Button
$SearchButton.Text = "Search"
$SearchButton.Location = New-Object System.Drawing.Point(290, 10)
$SearchButton.Size = New-Object System.Drawing.Size(75, 25)

# Create a panel to hold the dynamic checkboxes
$Panel = New-Object System.Windows.Forms.Panel
$Panel.AutoScroll = $true
$Panel.Width = 360
$Panel.Height = 470  # Increased the height to allow more results to be displayed
$Panel.Location = New-Object System.Drawing.Point(10, 50)

# Use an ArrayList to hold all checkbox objects (instead of an array)
$checkboxes = New-Object System.Collections.ArrayList

# Function to dynamically display checkboxes based on the current script files list
function Update-Checkboxes($filteredScriptFiles) {
    # Clear old checkboxes from the panel
    $Panel.Controls.Clear()

    # Reset Y position for the new checkboxes
    $yPos = 10
    $checkboxes.Clear()  # Clear existing checkbox list

    # Dynamically create checkboxes for each file in the filtered list
    foreach ($file in $filteredScriptFiles) {
        $checkbox = New-Object System.Windows.Forms.CheckBox
        $checkbox.Text = $file.Name
        $checkbox.Tag = $file.FullName # Store full path in checkbox's Tag property
        $checkbox.Size = New-Object System.Drawing.Size(340, 25)
        $checkbox.Location = New-Object System.Drawing.Point(10, $yPos)

        # Add checkbox to the panel
        $Panel.Controls.Add($checkbox)

        # Add checkbox to the ArrayList for later reference
        [void]$checkboxes.Add($checkbox)

        $yPos += 30  # Move checkboxes vertically
    }

    # Ensure that the height of the panel can appropriately scroll if checkboxes exceed panel space
    $Panel.AutoScrollMinSize = New-Object System.Drawing.Size(0, $yPos)
}

# Initial population of checkboxes (show all .ps1 files by default)
Update-Checkboxes $scriptFiles

# Search functionality logic, reused for both button and dynamic search
$performSearch = {
    # Get the current search query from the TextBox
    $searchQuery = $SearchBox.Text.ToLowerInvariant().Trim()

    # If the search box is empty, reset to show all scripts
    if ([string]::IsNullOrEmpty($searchQuery) -or $searchQuery -eq $placeholderText.ToLowerInvariant()) {
        Update-Checkboxes $scriptFiles  # Show all scripts if no search term
    } else {
        # Otherwise, filter the script files based on the search query
        $filteredScriptFiles = $scriptFiles | Where-Object { $_.Name.ToLowerInvariant() -like "*$searchQuery*" }
        Update-Checkboxes $filteredScriptFiles
    }
}

# Search Button clicked: triggers the same search functionality
$SearchButton.Add_Click($performSearch)

# Trigger search dynamically every time the text box changes (i.e., as you type)
$SearchBox.Add_TextChanged({
    $performSearch.Invoke()  # Call the search method as text changes
})

# Install functionality: run checked scripts
$InstallButton = New-Object System.Windows.Forms.Button
$InstallButton.Location = New-Object System.Drawing.Point(140, 530)
$InstallButton.Text = 'Install'

$InstallButton.Add_Click({
    # Loop through ArrayList and run the checked scripts
    foreach ($checkbox in $checkboxes) {
        if ($checkbox.Checked) {
            $scriptFile = $checkbox.Tag
            Write-Host "Installing from script: $scriptFile"
            # Use Start-Process to run the selected PowerShell script
            Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptFile`"" -Wait
        }
    }

    # Removed $Form.Close() to keep the window open after installation
    # $Form.Close()  # Commenting this line to avoid closing the form after installation
})

# Add elements to the form
$Form.Controls.Add($SearchBox)
$Form.Controls.Add($SearchButton)
$Form.Controls.Add($Panel)
$Form.Controls.Add($InstallButton)

# Show the form
$Form.ShowDialog()

Pause