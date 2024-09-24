# Ensure necessary .NET assemblies for creating forms are loaded
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Check if the script is running as Administrator
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

# Path to the folder containing PowerShell scripts
$scriptFolderPath = "\\OPHELIA\Plex Server\My Software\Windows\Windows Winget\Programs\Windows-Winget\Programs\Powershell Versions"

# Corrected the path format -- ensure you update to the correct folder in your environment
if (-not (Test-Path $scriptFolderPath)) {
    Write-Error "The path '$scriptFolderPath' does not exist. Please verify the path is correct."
    exit
}

# Get all .ps1 files in the folder
$scriptFiles = Get-ChildItem -Path $scriptFolderPath -Recurse -Filter "*.ps1"

# Define the form
$Form = New-Object System.Windows.Forms.Form
$Form.Text = 'Select programs to install'
$Form.Width = 400
$Form.Height = 600

# ---- CORE FIX ----
# Initialize controls here before adding event handlers or adding to form
$SortComboBox = New-Object System.Windows.Forms.ComboBox
$SearchBox = New-Object System.Windows.Forms.TextBox
$SearchButton = New-Object System.Windows.Forms.Button
$Panel = New-Object System.Windows.Forms.Panel
$InstallButton = New-Object System.Windows.Forms.Button # Ensure it's initialized

# TextBox for placeholder logic in search
$SearchBox.Location = New-Object System.Drawing.Point(10, 10)
$SearchBox.Size = New-Object System.Drawing.Size(270, 25)
$placeholderText = "Search programs..."
$SearchBox.Text = $placeholderText
$SearchBox.ForeColor = [System.Drawing.Color]::Gray

# Search Button
$SearchButton.Text = "Search"
$SearchButton.Location = New-Object System.Drawing.Point(290, 10)
$SearchButton.Size = New-Object System.Drawing.Size(75, 25)

# Panel for checkboxes
$Panel.AutoScroll = $true
$Panel.Width = 360
$Panel.Height = 470  # Increase the height to show more items
$Panel.Location = New-Object System.Drawing.Point(10, 50)

# ComboBox for selecting sorting method
$SortComboBox.Location = New-Object System.Drawing.Point(10, 530)
$SortComboBox.Size = New-Object System.Drawing.Size(270, 25)
$SortComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$SortComboBox.Items.Add("Name (A-Z)")
$SortComboBox.Items.Add("Date Modified (Newest First)")
$SortComboBox.Items.Add("Date Modified (Oldest First)")
$SortComboBox.SelectedIndex = 0

# Create an Install Button
$InstallButton.Text = 'Install'
$InstallButton.Size = New-Object System.Drawing.Size(75, 25)
$InstallButton.Location = New-Object System.Drawing.Point(140, 570)  # Correct Placement

# Add SearchBox Event Handlers (placeholders, etc.)
$SearchBox.Add_GotFocus({
    if ($SearchBox.Text -eq $placeholderText) {
        $SearchBox.Text = ""
        $SearchBox.ForeColor = [System.Drawing.Color]::Black
    }
})
$SearchBox.Add_LostFocus({
    if ([string]::IsNullOrEmpty($SearchBox.Text)) {
        $SearchBox.Text = $placeholderText
        $SearchBox.ForeColor = [System.Drawing.Color]::Gray
    }
})

# Search functionality, triggered by dynamic text changes or search button click.
$performSearch = {
    $searchQuery = $SearchBox.Text.ToLowerInvariant().Trim()
    if ([string]::IsNullOrEmpty($searchQuery) -or $searchQuery -eq $placeholderText.ToLowerInvariant()) {
        Update-Checkboxes $scriptFiles
    } else {
        $filteredScriptFiles = $scriptFiles | Where-Object { $_.Name -like "*$searchQuery*" }
        Update-Checkboxes $filteredScriptFiles
    }
}

$SearchButton.Add_Click($performSearch)

# Define function that populates the panel with checkboxes and applies sorting
function Update-Checkboxes ($filteredScriptFiles) {
    # Apply user-selected sorting option
    $sortOption = $SortComboBox.SelectedItem
    if ($sortOption -eq "Name (A-Z)") {
        $sortedFiles = $filteredScriptFiles | Sort-Object Name
    } elseif ($sortOption -eq "Date Modified (Newest First)") {
        $sortedFiles = $filteredScriptFiles | Sort-Object LastWriteTime -Descending
    } else {
        $sortedFiles = $filteredScriptFiles | Sort-Object LastWriteTime
    }

    # Remove existing checkboxes before populating new ones
    $Panel.Controls.Clear()

    # Create checkboxes for each file
    $yPos = 10
    foreach ($file in $sortedFiles) {
        $checkbox = New-Object System.Windows.Forms.CheckBox
        $checkbox.Text = $file.Name
        $checkbox.Tag = $file
        $checkbox.Location = New-Object System.Drawing.Point(10, $yPos)
        $checkbox.Size = New-Object System.Drawing.Size(340, 25)
        $Panel.Controls.Add($checkbox)
        $yPos += 30
    }
    $Panel.AutoScrollMinSize = New-Object System.Drawing.Size(0, $yPos)
}

# Populate initial list of checkboxes
Update-Checkboxes $scriptFiles

# Handle Sorting ComboBox selection change
$SortComboBox.add_SelectedIndexChanged({
    $performSearch.Invoke()  # Reapply search and sorting when the sort order is changed
})

# Install button handler
$InstallButton.Add_Click({
    foreach ($control in $Panel.Controls) {
        if ($control.GetType().Name -eq 'CheckBox' -and $control.Checked) {
            $scriptFile = $control.Tag.FullName
            Write-Host "Running script: $scriptFile"
            Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptFile`"" -Wait
        }
    }
})

# Add controls to the form
$Form.Controls.Add($SearchBox)
$Form.Controls.Add($SearchButton)
$Form.Controls.Add($Panel)
$Form.Controls.Add($SortComboBox)
$Form.Controls.Add($InstallButton)

# Display form
$Form.ShowDialog()