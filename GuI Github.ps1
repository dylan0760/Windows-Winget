# Function to check for Administrator privileges
function Check-Admin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Relaunch as Administrator if not already, bypassing execution policy
if (-not (Check-Admin)) {
    Write-Warning "Administrator privileges are required. Attempting to relaunch with elevated permissions..."
    try {
        $scriptPath = $MyInvocation.MyCommand.Path
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        Start-Process powershell -Verb RunAs -ArgumentList $arguments
    } catch {
        Write-Error "Failed to relaunch as administrator: $($_.Exception.Message)"
        Read-Host "Press Enter to exit..."
    }
    exit
}

# Add required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName "System.IO.Compression.FileSystem"

# Enable visual styles for modern control rendering
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- Download and Extract Repository Section ---

if (-not (Test-Path -Path "C:\temp")) {
    New-Item -Path "C:\temp" -ItemType Directory
}

$tempZipPath = "C:\temp\Winget.zip"
$localRepoPath = "C:\temp\Winget"
$repoUrl = "https://github.com/dylan0760/Windows-Winget/archive/refs/heads/main.zip"

Write-Host "Downloading repository from $repoUrl..."
try {
    Invoke-WebRequest -Uri $repoUrl -OutFile $tempZipPath -UseBasicParsing
    Write-Host "Download complete: $tempZipPath"
} catch {
    Write-Error "Failed to download repository from '$repoUrl': $($_.Exception.Message)"
    [System.Windows.Forms.MessageBox]::Show("Failed to download the script repository. Please check the URL and your internet connection.", "Download Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit
}

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
} catch { 
    Write-Warning "Could not remove temporary zip file '$tempZipPath'." 
}

$targetFolderPath = "$localRepoPath\Windows-Winget-main\Programs\Powershell Versions"
Write-Host "Target script folder set to: $targetFolderPath"

# --- Modern Theme Configuration ---

$script:DarkMode = $false

# Refined color palettes
$ThemeColors = @{
    Light = @{
        FormBackground    = [System.Drawing.Color]::FromArgb(255, 243, 243, 243)
        HeaderBackground  = [System.Drawing.Color]::FromArgb(255, 24, 24, 36)
        HeaderText        = [System.Drawing.Color]::White
        TextColor         = [System.Drawing.Color]::FromArgb(255, 30, 30, 30)
        SubtleText        = [System.Drawing.Color]::FromArgb(255, 120, 120, 130)
        PanelBackground   = [System.Drawing.Color]::White
        PanelBorder       = [System.Drawing.Color]::FromArgb(255, 218, 218, 225)
        ButtonPrimary     = [System.Drawing.Color]::FromArgb(255, 56, 96, 214)
        ButtonPrimaryHover= [System.Drawing.Color]::FromArgb(255, 45, 80, 190)
        ButtonText        = [System.Drawing.Color]::White
        CheckboxBack      = [System.Drawing.Color]::White
        CheckboxText      = [System.Drawing.Color]::FromArgb(255, 40, 40, 50)
        CheckboxHover     = [System.Drawing.Color]::FromArgb(255, 237, 240, 252)
        SearchBackground  = [System.Drawing.Color]::White
        SearchBorder      = [System.Drawing.Color]::FromArgb(255, 200, 200, 210)
        SearchText        = [System.Drawing.Color]::FromArgb(255, 30, 30, 30)
        SearchPlaceholder = [System.Drawing.Color]::FromArgb(255, 160, 160, 170)
        Separator         = [System.Drawing.Color]::FromArgb(255, 228, 228, 235)
        StatusBarBack     = [System.Drawing.Color]::FromArgb(255, 248, 248, 250)
        AccentGreen       = [System.Drawing.Color]::FromArgb(255, 34, 180, 85)
        AccentRed         = [System.Drawing.Color]::FromArgb(255, 220, 60, 50)
        AccentOrange      = [System.Drawing.Color]::FromArgb(255, 235, 140, 15)
        AccentPurple      = [System.Drawing.Color]::FromArgb(255, 130, 75, 200)
        AccentBlue        = [System.Drawing.Color]::FromArgb(255, 50, 130, 210)
        ShadowColor       = [System.Drawing.Color]::FromArgb(20, 0, 0, 0)
    }
    Dark = @{
        FormBackground    = [System.Drawing.Color]::FromArgb(255, 28, 28, 35)
        HeaderBackground  = [System.Drawing.Color]::FromArgb(255, 18, 18, 25)
        HeaderText        = [System.Drawing.Color]::White
        TextColor         = [System.Drawing.Color]::FromArgb(255, 225, 225, 230)
        SubtleText        = [System.Drawing.Color]::FromArgb(255, 140, 140, 155)
        PanelBackground   = [System.Drawing.Color]::FromArgb(255, 38, 38, 48)
        PanelBorder       = [System.Drawing.Color]::FromArgb(255, 55, 55, 68)
        ButtonPrimary     = [System.Drawing.Color]::FromArgb(255, 70, 110, 220)
        ButtonPrimaryHover= [System.Drawing.Color]::FromArgb(255, 85, 125, 235)
        ButtonText        = [System.Drawing.Color]::White
        CheckboxBack      = [System.Drawing.Color]::FromArgb(255, 45, 45, 58)
        CheckboxText      = [System.Drawing.Color]::FromArgb(255, 210, 210, 220)
        CheckboxHover     = [System.Drawing.Color]::FromArgb(255, 55, 55, 72)
        SearchBackground  = [System.Drawing.Color]::FromArgb(255, 42, 42, 55)
        SearchBorder      = [System.Drawing.Color]::FromArgb(255, 65, 65, 80)
        SearchText        = [System.Drawing.Color]::FromArgb(255, 210, 210, 220)
        SearchPlaceholder = [System.Drawing.Color]::FromArgb(255, 120, 120, 140)
        Separator         = [System.Drawing.Color]::FromArgb(255, 55, 55, 68)
        StatusBarBack     = [System.Drawing.Color]::FromArgb(255, 22, 22, 30)
        AccentGreen       = [System.Drawing.Color]::FromArgb(255, 40, 190, 95)
        AccentRed         = [System.Drawing.Color]::FromArgb(255, 230, 70, 60)
        AccentOrange      = [System.Drawing.Color]::FromArgb(255, 240, 150, 25)
        AccentPurple      = [System.Drawing.Color]::FromArgb(255, 145, 90, 215)
        AccentBlue        = [System.Drawing.Color]::FromArgb(255, 60, 140, 220)
        ShadowColor       = [System.Drawing.Color]::FromArgb(40, 0, 0, 0)
    }
}

# Helper: Get current theme
function Get-Theme {
    if ($script:DarkMode) { return $ThemeColors.Dark } else { return $ThemeColors.Light }
}

# Helper: create a rounded rectangle path
function New-RoundedRectPath {
    param (
        [System.Drawing.Rectangle]$Rect,
        [int]$Radius
    )
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $Radius * 2
    $path.AddArc($Rect.X, $Rect.Y, $d, $d, 180, 90)
    $path.AddArc($Rect.Right - $d, $Rect.Y, $d, $d, 270, 90)
    $path.AddArc($Rect.Right - $d, $Rect.Bottom - $d, $d, $d, 0, 90)
    $path.AddArc($Rect.X, $Rect.Bottom - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
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

# --- Fonts ---
$FontFamily      = "Segoe UI"
$HeaderFont       = New-Object System.Drawing.Font($FontFamily, 15, [System.Drawing.FontStyle]::Bold)
$SubHeaderFont    = New-Object System.Drawing.Font($FontFamily, 9, [System.Drawing.FontStyle]::Regular)
$ButtonFont       = New-Object System.Drawing.Font($FontFamily, 9, [System.Drawing.FontStyle]::Bold)
$CheckboxFont     = New-Object System.Drawing.Font($FontFamily, 9.5, [System.Drawing.FontStyle]::Regular)
$SearchFont       = New-Object System.Drawing.Font($FontFamily, 10, [System.Drawing.FontStyle]::Regular)
$StatusFont       = New-Object System.Drawing.Font($FontFamily, 8.5, [System.Drawing.FontStyle]::Regular)
$SectionLabelFont = New-Object System.Drawing.Font($FontFamily, 8, [System.Drawing.FontStyle]::Bold)
$CountFont        = New-Object System.Drawing.Font($FontFamily, 9, [System.Drawing.FontStyle]::Bold)

# --- Create Main Form ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Windows-Winget Script Installer"
$Form.Size = New-Object System.Drawing.Size(880, 760)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$Form.MaximizeBox = $false
$Form.Font = New-Object System.Drawing.Font($FontFamily, 9)

# Remove default border by using double buffering for flicker-free rendering
$Form.GetType().GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]"Instance,NonPublic").SetValue($Form, $true, $null)

# --- Header Panel (branded top bar) ---
$HeaderPanel = New-Object System.Windows.Forms.Panel
$HeaderPanel.Dock = [System.Windows.Forms.DockStyle]::Top
$HeaderPanel.Height = 70
$HeaderPanel.BackColor = [System.Drawing.Color]::FromArgb(255, 24, 24, 36)
$Form.Controls.Add($HeaderPanel)

$TitleLabel = New-Object System.Windows.Forms.Label
$TitleLabel.Text = "Windows-Winget Installer"
$TitleLabel.Font = $HeaderFont
$TitleLabel.ForeColor = [System.Drawing.Color]::White
$TitleLabel.AutoSize = $true
$TitleLabel.Location = New-Object System.Drawing.Point(24, 14)
$HeaderPanel.Controls.Add($TitleLabel)

$SubtitleLabel = New-Object System.Windows.Forms.Label
$SubtitleLabel.Text = "Select programs to install via Winget package manager"
$SubtitleLabel.Font = $SubHeaderFont
$SubtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 160, 165, 185)
$SubtitleLabel.AutoSize = $true
$SubtitleLabel.Location = New-Object System.Drawing.Point(26, 44)
$HeaderPanel.Controls.Add($SubtitleLabel)

# --- Content area starts below header ---
$contentTop = 85

# --- Search Box ---
$SearchBox = New-Object System.Windows.Forms.TextBox
$SearchBox.Location = New-Object System.Drawing.Point(24, $contentTop)
$SearchBox.Size = New-Object System.Drawing.Size(812, 30)
$SearchBox.Font = $SearchFont
$SearchBox.Text = "Search programs..."
$SearchBox.ForeColor = [System.Drawing.Color]::FromArgb(255, 160, 160, 170)
$SearchBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$Form.Controls.Add($SearchBox)

# Ctrl+A support
$SearchBox.Add_KeyDown({
    param($sender, $e)
    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::A) {
        $SearchBox.SelectAll()
        $e.SuppressKeyPress = $true
    }
})

$SearchBox.Add_Enter({
    if ($this.Text -eq "Search programs...") {
        $this.Text = ""
        $theme = Get-Theme
        $this.ForeColor = $theme.SearchText
    }
})

$SearchBox.Add_Leave({
    if ($this.Text -eq "") {
        $this.Text = "Search programs..."
        $theme = Get-Theme
        $this.ForeColor = $theme.SearchPlaceholder
    }
})

$SearchBox.Add_TextChanged({
    if ($this.Text -ne "Search programs...") {
        Update-Checkboxes $scriptFiles
    }
})

# --- Selected Count Label ---
$CountLabel = New-Object System.Windows.Forms.Label
$CountLabel.Text = "0 selected"
$CountLabel.Font = $CountFont
$CountLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 120, 120, 130)
$CountLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$CountLabel.Location = New-Object System.Drawing.Point(700, ($contentTop + 35))
$CountLabel.Size = New-Object System.Drawing.Size(136, 20)
$Form.Controls.Add($CountLabel)

function Update-SelectedCount {
    $count = @($Panel.Controls | Where-Object { ($_ -is [System.Windows.Forms.CheckBox]) -and $_.Checked }).Count
    $CountLabel.Text = "$count selected"
    $theme = Get-Theme
    if ($count -gt 0) {
        $CountLabel.ForeColor = $theme.ButtonPrimary
    } else {
        $CountLabel.ForeColor = $theme.SubtleText
    }
}

# --- Scrollable Checkbox Panel ---
$panelTop = $contentTop + 40
$Panel = New-Object System.Windows.Forms.Panel
$Panel.Location = New-Object System.Drawing.Point(24, $panelTop)
$Panel.Size = New-Object System.Drawing.Size(812, 390)
$Panel.AutoScroll = $true
$Panel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$Form.Controls.Add($Panel)

# Double-buffer the panel
$Panel.GetType().GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]"Instance,NonPublic").SetValue($Panel, $true, $null)

# Global checkbox array
$script:checkboxes = @()

# Function to update checkboxes
function Update-Checkboxes {
    param ([System.IO.FileInfo[]]$files)
    
    $Panel.SuspendLayout()
    $Panel.Controls.Clear()
    $script:checkboxes = @()
    $y = 8
    
    if ($SearchBox.Text -and $SearchBox.Text -ne "Search programs...") {
        $searchTerm = $SearchBox.Text.ToLower()
        $filteredFiles = $files | Where-Object { 
            (Get-RelativePath -basePath $targetFolderPath -fullPath $_.FullName).ToLower().Contains($searchTerm) 
        }
    } else {
        $filteredFiles = $files
    }
    
    $theme = Get-Theme
    
    foreach ($file in $filteredFiles) {
        $relativePath = Get-RelativePath -basePath $targetFolderPath -fullPath $file.FullName
        $checkbox = New-Object System.Windows.Forms.CheckBox
        $checkbox.Text = $relativePath
        $checkbox.Location = New-Object System.Drawing.Point(8, $y)
        $checkbox.Font = $CheckboxFont
        $checkbox.BackColor = $theme.CheckboxBack
        $checkbox.ForeColor = $theme.CheckboxText
        $checkbox.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        
        try {
            $panelWidth = [int]$Panel.Width
            $checkboxWidth = $panelWidth - 40
            $checkbox.Size = New-Object System.Drawing.Size($checkboxWidth, 28)
        } catch {
            $checkbox.Size = New-Object System.Drawing.Size(760, 28)
        }
        
        $checkbox.Padding = New-Object System.Windows.Forms.Padding(6, 0, 0, 0)
        $checkbox.Checked = $false
        
        # Hover effect
        $checkbox.Add_MouseEnter({
            $t = Get-Theme
            $this.BackColor = $t.CheckboxHover
        })
        $checkbox.Add_MouseLeave({
            $t = Get-Theme
            $this.BackColor = $t.CheckboxBack
        })
        # Update count on check/uncheck
        $checkbox.Add_CheckedChanged({ Update-SelectedCount })
        
        $Panel.Controls.Add($checkbox)
        $script:checkboxes += $checkbox
        $y += 30
    }
    
    $Panel.ResumeLayout()
    Update-SelectedCount
}

# --- Button Area ---
$buttonAreaTop = $panelTop + 400

# Section label: Selection
$SelectionLabel = New-Object System.Windows.Forms.Label
$SelectionLabel.Text = "SELECTION"
$SelectionLabel.Font = $SectionLabelFont
$SelectionLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 140, 140, 155)
$SelectionLabel.Location = New-Object System.Drawing.Point(24, $buttonAreaTop)
$SelectionLabel.AutoSize = $true
$Form.Controls.Add($SelectionLabel)

$btnRow1 = $buttonAreaTop + 20
$btnWidth = 150
$btnHeight = 36
$btnGap = 12

# Helper to style a button
function Style-Button {
    param (
        [System.Windows.Forms.Button]$Btn,
        [System.Drawing.Color]$BgColor,
        [System.Drawing.Color]$HoverColor
    )
    $Btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $Btn.FlatAppearance.BorderSize = 0
    $Btn.BackColor = $BgColor
    $Btn.ForeColor = [System.Drawing.Color]::White
    $Btn.Font = $ButtonFont
    $Btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $Btn.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
    
    # Store hover color in Tag
    $Btn.Tag = $HoverColor
    $Btn.Add_MouseEnter({
        if ($this.Tag -is [System.Drawing.Color]) {
            $this.BackColor = $this.Tag
        }
    })
    $Btn.Add_MouseLeave({
        # Restore original color - use the control's name to look up the base color
        # We'll store base color differently
    })
}

# --- Check All Button ---
$CheckAllButton = New-Object System.Windows.Forms.Button
$CheckAllButton.Text = "  Select All"
$CheckAllButton.Location = New-Object System.Drawing.Point(24, $btnRow1)
$CheckAllButton.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$CheckAllButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$CheckAllButton.FlatAppearance.BorderSize = 0
$CheckAllButton.Font = $ButtonFont
$CheckAllButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$Form.Controls.Add($CheckAllButton)

# --- Uncheck All Button ---
$x2 = 24 + $btnWidth + $btnGap
$UncheckAllButton = New-Object System.Windows.Forms.Button
$UncheckAllButton.Text = "  Deselect All"
$UncheckAllButton.Location = New-Object System.Drawing.Point($x2, $btnRow1)
$UncheckAllButton.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$UncheckAllButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$UncheckAllButton.FlatAppearance.BorderSize = 0
$UncheckAllButton.Font = $ButtonFont
$UncheckAllButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$Form.Controls.Add($UncheckAllButton)

# Section label: Presets
$PresetsLabel = New-Object System.Windows.Forms.Label
$PresetsLabel.Text = "PRESETS"
$PresetsLabel.Font = $SectionLabelFont
$PresetsLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 140, 140, 155)
$PresetsLabel.Location = New-Object System.Drawing.Point(24, ($btnRow1 + $btnHeight + 12))
$PresetsLabel.AutoSize = $true
$Form.Controls.Add($PresetsLabel)

$btnRow2 = $btnRow1 + $btnHeight + 30

# --- Win 11 Basic Button ---
$Windows11BasicButton = New-Object System.Windows.Forms.Button
$Windows11BasicButton.Text = "  Win 11 Basic"
$Windows11BasicButton.Location = New-Object System.Drawing.Point(24, $btnRow2)
$Windows11BasicButton.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$Windows11BasicButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$Windows11BasicButton.FlatAppearance.BorderSize = 0
$Windows11BasicButton.Font = $ButtonFont
$Windows11BasicButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$Form.Controls.Add($Windows11BasicButton)

# --- Gaming Focused Button ---
$GamingFocusedButton = New-Object System.Windows.Forms.Button
$GamingFocusedButton.Text = "  Gaming Setup"
$GamingFocusedButton.Location = New-Object System.Drawing.Point($x2, $btnRow2)
$GamingFocusedButton.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$GamingFocusedButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$GamingFocusedButton.FlatAppearance.BorderSize = 0
$GamingFocusedButton.Font = $ButtonFont
$GamingFocusedButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$Form.Controls.Add($GamingFocusedButton)

# --- Theme Toggle Button ---
$x3 = $x2 + $btnWidth + $btnGap
$ToggleThemeButton = New-Object System.Windows.Forms.Button
$ToggleThemeButton.Text = "  Dark Mode"
$ToggleThemeButton.Location = New-Object System.Drawing.Point($x3, $btnRow2)
$ToggleThemeButton.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$ToggleThemeButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$ToggleThemeButton.FlatAppearance.BorderSize = 0
$ToggleThemeButton.Font = $ButtonFont
$ToggleThemeButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$Form.Controls.Add($ToggleThemeButton)

# --- Install Button (prominent, right-aligned) ---
$InstallButton = New-Object System.Windows.Forms.Button
$InstallButton.Text = "INSTALL SELECTED"
$installBtnWidth = 200
$InstallButton.Location = New-Object System.Drawing.Point((836 - $installBtnWidth), $btnRow2)
$InstallButton.Size = New-Object System.Drawing.Size($installBtnWidth, $btnHeight)
$InstallButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$InstallButton.FlatAppearance.BorderSize = 0
$InstallButton.Font = New-Object System.Drawing.Font($FontFamily, 10, [System.Drawing.FontStyle]::Bold)
$InstallButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$Form.Controls.Add($InstallButton)

# --- Status Bar ---
$statusTop = $btnRow2 + $btnHeight + 18
$StatusPanel = New-Object System.Windows.Forms.Panel
$StatusPanel.Location = New-Object System.Drawing.Point(0, $statusTop)
$StatusPanel.Size = New-Object System.Drawing.Size(880, 32)
$Form.Controls.Add($StatusPanel)

$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Text = "Ready"
$StatusLabel.Font = $StatusFont
$StatusLabel.Location = New-Object System.Drawing.Point(28, 7)
$StatusLabel.AutoSize = $true
$StatusPanel.Controls.Add($StatusLabel)

# --- Apply Theme Function ---
function Apply-Theme {
    param ([bool]$IsDarkMode)
    
    $theme = if ($IsDarkMode) { $ThemeColors.Dark } else { $ThemeColors.Light }
    
    # Form
    $Form.BackColor = $theme.FormBackground
    $Form.ForeColor = $theme.TextColor
    
    # Header
    $HeaderPanel.BackColor = $theme.HeaderBackground
    $TitleLabel.ForeColor = $theme.HeaderText
    
    # Panel
    $Panel.BackColor = $theme.PanelBackground
    
    # Search
    $SearchBox.BackColor = $theme.SearchBackground
    $SearchBox.ForeColor = if ($SearchBox.Text -eq "Search programs...") { $theme.SearchPlaceholder } else { $theme.SearchText }
    
    # Count label
    Update-SelectedCount
    
    # Checkboxes
    $Panel.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] } | ForEach-Object {
        $_.BackColor = $theme.CheckboxBack
        $_.ForeColor = $theme.CheckboxText
    }
    
    # Section labels
    $SelectionLabel.ForeColor = $theme.SubtleText
    $PresetsLabel.ForeColor = $theme.SubtleText
    
    # Buttons with their accent colors
    $CheckAllButton.BackColor = $theme.AccentGreen
    $CheckAllButton.ForeColor = $theme.ButtonText
    
    $UncheckAllButton.BackColor = $theme.AccentRed
    $UncheckAllButton.ForeColor = $theme.ButtonText
    
    $Windows11BasicButton.BackColor = $theme.AccentOrange
    $Windows11BasicButton.ForeColor = $theme.ButtonText
    
    $GamingFocusedButton.BackColor = $theme.AccentPurple
    $GamingFocusedButton.ForeColor = $theme.ButtonText
    
    $ToggleThemeButton.BackColor = $theme.AccentBlue
    $ToggleThemeButton.ForeColor = $theme.ButtonText
    $ToggleThemeButton.Text = if ($IsDarkMode) { "  Light Mode" } else { "  Dark Mode" }
    
    $InstallButton.BackColor = $theme.ButtonPrimary
    $InstallButton.ForeColor = $theme.ButtonText
    
    # Status bar
    $StatusPanel.BackColor = $theme.StatusBarBack
    $StatusLabel.ForeColor = $theme.SubtleText
    $StatusLabel.BackColor = $theme.StatusBarBack
}

# --- Button Hover Effects ---
# We store [BaseColor, HoverColor] in each button's Tag for hover management

function Add-ButtonHover {
    param (
        [System.Windows.Forms.Button]$Btn,
        [scriptblock]$GetBaseColor,
        [int]$LightenAmount = 20
    )
    $Btn.Add_MouseEnter({
        $c = $this.BackColor
        $r = [Math]::Min(255, $c.R + 20)
        $g = [Math]::Min(255, $c.G + 20)
        $b = [Math]::Min(255, $c.B + 20)
        $this.BackColor = [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
    })
    $Btn.Add_MouseLeave({
        # Re-apply theme to reset color
        Apply-Theme -IsDarkMode $script:DarkMode
    })
}

Add-ButtonHover $CheckAllButton
Add-ButtonHover $UncheckAllButton
Add-ButtonHover $Windows11BasicButton
Add-ButtonHover $GamingFocusedButton
Add-ButtonHover $ToggleThemeButton
Add-ButtonHover $InstallButton

# --- Multithreaded Script Execution ---
function Run-Scripts {
    $Form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $Form.Controls | ForEach-Object { if ($_ -is [System.Windows.Forms.Button] -or $_ -is [System.Windows.Forms.TextBox]) { $_.Enabled = $false } }
    
    $scriptsToRun = @($Panel.Controls | Where-Object { ($_ -is [System.Windows.Forms.CheckBox]) -and $_.Checked } | ForEach-Object { 
        $checkboxText = $_.Text
        $scriptFiles | Where-Object { (Get-RelativePath -basePath $targetFolderPath -fullPath $_.FullName) -eq $checkboxText } | Select-Object -ExpandProperty FullName 
    })
    
    if ($scriptsToRun.Count -eq 0) {
        $StatusLabel.Text = "No scripts selected."
        $Form.Controls | ForEach-Object { if ($_ -is [System.Windows.Forms.Button] -or $_ -is [System.Windows.Forms.TextBox]) { $_.Enabled = $true } }
        $Form.Cursor = [System.Windows.Forms.Cursors]::Default
        return
    }
    
    $StatusLabel.Text = "Preparing to run $($scriptsToRun.Count) script(s)..."
    $Form.Refresh()
    
    $errorMessages = @()
    $hadErrors = $false
    
    # Progress bar - placed in the status area
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(24, ($statusTop + 32))
    $progressBar.Size = New-Object System.Drawing.Size(812, 6)
    $progressBar.Minimum = 0
    $progressBar.Maximum = $scriptsToRun.Count
    $progressBar.Value = 0
    $progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
    $Form.Controls.Add($progressBar)
    $Form.Refresh()
    
    # Create runspace pool for multi-threading
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, 5)
    $runspacePool.Open()
    
    $runspaces = @()
    $scriptResults = @{}
    
    for ($i = 0; $i -lt $scriptsToRun.Count; $i++) {
        $scriptPath = $scriptsToRun[$i]
        $relativeScriptName = Get-RelativePath -basePath $targetFolderPath -fullPath $scriptPath
        
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
        
        $powershell.RunspacePool = $runspacePool
        
        $runspaces += [PSCustomObject]@{
            Index = $i
            PowerShell = $powershell
            Result = $powershell.BeginInvoke()
        }
    }
    
    # Wait for completion
    $completedCount = 0
    while ($runspaces.Where({ -not $_.Result.IsCompleted }).Count -gt 0) {
        $newlyCompleted = $runspaces.Where({ $_.Result.IsCompleted -and -not $scriptResults.ContainsKey($_.Index) })
        
        foreach ($runspace in $newlyCompleted) {
            $result = $runspace.PowerShell.EndInvoke($runspace.Result)
            $scriptResults[$runspace.Index] = $result
            
            $completedCount++
            
            $Form.Invoke([Action]{
                $progressBar.Value = $completedCount
                $StatusLabel.Text = "Installing ($completedCount/$($scriptsToRun.Count)): $($result.Name)"
                
                if (-not $result.Success -and -not [string]::IsNullOrEmpty($result.ErrorMessage)) {
                    $errorMessages += $result.ErrorMessage
                    $hadErrors = $true
                }
                
                $Form.Refresh()
            })
        }
        
        Start-Sleep -Milliseconds 200
    }
    
    # Cleanup
    foreach ($runspace in $runspaces) {
        $runspace.PowerShell.Dispose()
    }
    $runspacePool.Close()
    $runspacePool.Dispose()
    
    # Final UI update
    $Form.Invoke([Action]{
        $Form.Controls.Remove($progressBar)
        
        if ($hadErrors) {
            $StatusLabel.Text = "Completed with errors."
            [System.Windows.Forms.MessageBox]::Show("Installation completed, but errors occurred:`n`n" + ($errorMessages -join "`n"), "Errors", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        } else {
            $StatusLabel.Text = "All scripts completed successfully."
            [System.Windows.Forms.MessageBox]::Show("Selected scripts executed successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        }
        
        $Form.Controls | ForEach-Object { if ($_ -is [System.Windows.Forms.Button] -or $_ -is [System.Windows.Forms.TextBox]) { $_.Enabled = $true } }
        $Form.Cursor = [System.Windows.Forms.Cursors]::Default
        $Form.Refresh()
    })
}

# --- Button Event Handlers ---
$InstallButton.Add_Click({ Run-Scripts })

$CheckAllButton.Add_Click({
    $Panel.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] } | ForEach-Object { $_.Checked = $true }
})

$UncheckAllButton.Add_Click({
    $Panel.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] } | ForEach-Object { $_.Checked = $false }
})

$ToggleThemeButton.Add_Click({
    $script:DarkMode = -not $script:DarkMode
    Apply-Theme -IsDarkMode $script:DarkMode
})

$Windows11BasicButton.Add_Click({
    $Panel.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] } | ForEach-Object { $_.Checked = $false }
    
    $basicScripts = @(
        "Brave.ps1",
        "7-Zip.ps1",
        "Notepad++.ps1",
        "VLC.ps1"
    )
    
    $selectedCount = 0
    foreach ($checkbox in $Panel.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] }) {
        $filename = Split-Path -Leaf $checkbox.Text
        if ($basicScripts -contains $filename -or 
            $basicScripts -contains ($filename -replace '\.ps1$', '') -or 
            $basicScripts -contains "$($filename).ps1") {
            $checkbox.Checked = $true
            $selectedCount++
        }
    }
    
    $StatusLabel.Text = "Win 11 Basic preset applied ($selectedCount scripts)"
    [System.Windows.Forms.MessageBox]::Show("Selected $selectedCount basic script(s)!", "Basic Preset Applied", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$GamingFocusedButton.Add_Click({
    $Panel.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] } | ForEach-Object { $_.Checked = $false }
    
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
        $filename = Split-Path -Leaf $checkbox.Text
        if ($gamingScripts -contains $filename -or 
            $gamingScripts -contains ($filename -replace '\.ps1$', '') -or 
            $gamingScripts -contains "$($filename).ps1") {
            $checkbox.Checked = $true
            $selectedCount++
        }
    }
    
    $StatusLabel.Text = "Gaming preset applied ($selectedCount scripts)"
    [System.Windows.Forms.MessageBox]::Show("Selected $selectedCount gaming-focused script(s)!", "Gaming Preset Applied", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# --- Script Discovery ---
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

# Initialize with light theme
Apply-Theme -IsDarkMode $script:DarkMode

# Show the form
$Form.Add_Shown({$Form.Activate()})
[void]$Form.ShowDialog()