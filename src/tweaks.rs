use std::process::Command;

#[cfg(windows)]
use std::os::windows::process::CommandExt;

#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x0800_0000;

#[derive(Clone, Debug)]
pub struct NetworkAdapter {
    pub name: String,
    pub description: String,
    pub status: String,
    pub link_speed: String,
    pub jumbo_value: String,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum WindowsToggle {
    FileExtensions,
    HiddenFiles,
    GameMode,
    MouseAcceleration,
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct WindowsToggleStates {
    pub file_extensions: bool,
    pub hidden_files: bool,
    pub game_mode: bool,
    pub mouse_acceleration: bool,
}

impl WindowsToggleStates {
    pub fn get(self, setting: WindowsToggle) -> bool {
        match setting {
            WindowsToggle::FileExtensions => self.file_extensions,
            WindowsToggle::HiddenFiles => self.hidden_files,
            WindowsToggle::GameMode => self.game_mode,
            WindowsToggle::MouseAcceleration => self.mouse_acceleration,
        }
    }

    pub fn set(&mut self, setting: WindowsToggle, enabled: bool) {
        match setting {
            WindowsToggle::FileExtensions => self.file_extensions = enabled,
            WindowsToggle::HiddenFiles => self.hidden_files = enabled,
            WindowsToggle::GameMode => self.game_mode = enabled,
            WindowsToggle::MouseAcceleration => self.mouse_acceleration = enabled,
        }
    }
}

const EXPLORER_ADVANCED_KEY: &str =
    r"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";
const GAME_BAR_KEY: &str = r"HKCU\Software\Microsoft\GameBar";

pub fn query_windows_toggle_states() -> Result<WindowsToggleStates, String> {
    #[cfg(windows)]
    {
        let hide_file_extensions =
            query_registry_dword(EXPLORER_ADVANCED_KEY, "HideFileExt")?.unwrap_or(1);
        let hidden_files = query_registry_dword(EXPLORER_ADVANCED_KEY, "Hidden")?.unwrap_or(0);
        let allow_auto_game_mode =
            query_registry_dword(GAME_BAR_KEY, "AllowAutoGameMode")?.unwrap_or(1);
        let auto_game_mode =
            query_registry_dword(GAME_BAR_KEY, "AutoGameModeEnabled")?.unwrap_or(1);

        Ok(WindowsToggleStates {
            file_extensions: hide_file_extensions == 0,
            hidden_files: hidden_files == 1,
            game_mode: allow_auto_game_mode == 1 && auto_game_mode == 1,
            mouse_acceleration: query_mouse_acceleration()?,
        })
    }

    #[cfg(not(windows))]
    {
        Err("Windows preference toggles are only supported on Windows.".to_owned())
    }
}

pub fn set_windows_toggle(setting: WindowsToggle, enabled: bool) -> Result<String, String> {
    match setting {
        WindowsToggle::FileExtensions => {
            set_registry_dword(
                EXPLORER_ADVANCED_KEY,
                "HideFileExt",
                if enabled { 0 } else { 1 },
            )?;
            broadcast_explorer_change();
            Ok(format!(
                "File Explorer file extensions are now {}.",
                if enabled { "shown" } else { "hidden" }
            ))
        }
        WindowsToggle::HiddenFiles => {
            set_registry_dword(EXPLORER_ADVANCED_KEY, "Hidden", if enabled { 1 } else { 0 })?;
            broadcast_explorer_change();
            Ok(format!(
                "Hidden files are now {} in File Explorer.",
                if enabled { "shown" } else { "hidden" }
            ))
        }
        WindowsToggle::GameMode => {
            let value = if enabled { 1 } else { 0 };
            set_registry_dword(GAME_BAR_KEY, "AllowAutoGameMode", value)?;
            set_registry_dword(GAME_BAR_KEY, "AutoGameModeEnabled", value)?;
            Ok(format!(
                "Windows Game Mode is now {}.",
                if enabled { "on" } else { "off" }
            ))
        }
        WindowsToggle::MouseAcceleration => {
            set_mouse_acceleration(enabled)?;
            Ok(format!(
                "Mouse acceleration is now {}.",
                if enabled { "on" } else { "off" }
            ))
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum LegacyPanel {
    ControlPanel,
    NetworkConnections,
    PowerOptions,
    Region,
    Sound,
    DevicesAndPrinters,
    SystemProperties,
    UserAccounts,
}

impl LegacyPanel {
    fn command(self) -> (&'static str, &'static [&'static str]) {
        match self {
            Self::ControlPanel => ("control.exe", &[]),
            Self::NetworkConnections => ("control.exe", &["ncpa.cpl"]),
            Self::PowerOptions => ("control.exe", &["powercfg.cpl"]),
            Self::Region => ("control.exe", &["intl.cpl"]),
            Self::Sound => ("control.exe", &["mmsys.cpl"]),
            Self::DevicesAndPrinters => (
                "explorer.exe",
                &["shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}"],
            ),
            Self::SystemProperties => ("control.exe", &["sysdm.cpl"]),
            Self::UserAccounts => ("control.exe", &["userpasswords2"]),
        }
    }

    fn label(self) -> &'static str {
        match self {
            Self::ControlPanel => "Control Panel",
            Self::NetworkConnections => "Network Connections",
            Self::PowerOptions => "Power Options",
            Self::Region => "Region",
            Self::Sound => "Sound",
            Self::DevicesAndPrinters => "Devices and Printers",
            Self::SystemProperties => "System Properties",
            Self::UserAccounts => "User Accounts",
        }
    }
}

pub fn open_legacy_panel(panel: LegacyPanel) -> Result<String, String> {
    #[cfg(windows)]
    {
        let (program, arguments) = panel.command();
        let windows_root = std::env::var_os("SystemRoot")
            .map(std::path::PathBuf::from)
            .ok_or_else(|| "Windows did not provide the SystemRoot directory.".to_owned())?;
        let executable = if program.eq_ignore_ascii_case("explorer.exe") {
            windows_root.join(program)
        } else {
            windows_root.join("System32").join(program)
        };

        if !executable.is_file() {
            return Err(format!(
                "Windows system executable was not found: {}",
                executable.display()
            ));
        }

        Command::new(&executable)
            .args(arguments)
            .spawn()
            .map_err(|error| format!("Could not open {}: {error}", panel.label()))?;
        Ok(format!("Opened {}.", panel.label()))
    }

    #[cfg(not(windows))]
    {
        let _ = panel;
        Err("Legacy Windows panels can only be opened on Windows.".to_owned())
    }
}

#[cfg(windows)]
fn query_registry_dword(key: &str, name: &str) -> Result<Option<u32>, String> {
    let mut command = Command::new("reg.exe");
    command.args(["query", key, "/v", name]);
    command.creation_flags(CREATE_NO_WINDOW);
    let output = command
        .output()
        .map_err(|error| format!("Could not read Windows preference {name}: {error}"))?;
    if !output.status.success() {
        return Ok(None);
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let value = stdout
        .lines()
        .find(|line| line.split_whitespace().next() == Some(name))
        .and_then(|line| line.split_whitespace().last())
        .ok_or_else(|| format!("Windows returned an unreadable value for {name}."))?;
    let parsed = value
        .strip_prefix("0x")
        .map(|hex| u32::from_str_radix(hex, 16))
        .unwrap_or_else(|| value.parse::<u32>())
        .map_err(|error| format!("Could not parse Windows preference {name}: {error}"))?;
    Ok(Some(parsed))
}

fn set_registry_dword(key: &str, name: &str, value: u32) -> Result<(), String> {
    let value = value.to_string();
    run_command(
        "reg.exe",
        &[
            "add",
            key,
            "/v",
            name,
            "/t",
            "REG_DWORD",
            "/d",
            &value,
            "/f",
        ],
    )?;
    Ok(())
}

#[cfg(windows)]
fn query_mouse_acceleration() -> Result<bool, String> {
    use windows_sys::Win32::UI::WindowsAndMessaging::{SystemParametersInfoW, SPI_GETMOUSE};

    let mut values = [0_i32; 3];
    let succeeded = unsafe {
        SystemParametersInfoW(
            SPI_GETMOUSE,
            0,
            values.as_mut_ptr().cast::<std::ffi::c_void>(),
            0,
        )
    };
    if succeeded == 0 {
        Err(format!(
            "Windows could not read the mouse acceleration setting: {}",
            std::io::Error::last_os_error()
        ))
    } else {
        Ok(values[2] != 0)
    }
}

#[cfg(windows)]
fn set_mouse_acceleration(enabled: bool) -> Result<(), String> {
    use windows_sys::Win32::UI::WindowsAndMessaging::{
        SystemParametersInfoW, SPIF_SENDCHANGE, SPIF_UPDATEINIFILE, SPI_SETMOUSE,
    };

    let mut values = if enabled {
        [6_i32, 10_i32, 1_i32]
    } else {
        [0_i32, 0_i32, 0_i32]
    };
    let succeeded = unsafe {
        SystemParametersInfoW(
            SPI_SETMOUSE,
            0,
            values.as_mut_ptr().cast::<std::ffi::c_void>(),
            SPIF_UPDATEINIFILE | SPIF_SENDCHANGE,
        )
    };
    if succeeded == 0 {
        Err(format!(
            "Windows could not change mouse acceleration: {}",
            std::io::Error::last_os_error()
        ))
    } else {
        Ok(())
    }
}

#[cfg(not(windows))]
fn set_mouse_acceleration(_enabled: bool) -> Result<(), String> {
    Err("Mouse acceleration changes are only supported on Windows.".to_owned())
}

fn broadcast_explorer_change() {
    broadcast_setting_change(r"Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced");
    #[cfg(windows)]
    {
        use windows_sys::Win32::UI::Shell::{SHChangeNotify, SHCNE_ASSOCCHANGED, SHCNF_IDLIST};
        unsafe {
            SHChangeNotify(
                SHCNE_ASSOCCHANGED as i32,
                SHCNF_IDLIST,
                std::ptr::null(),
                std::ptr::null(),
            );
        }
    }
}

pub fn set_dark_mode(dark: bool) -> Result<String, String> {
    let value = if dark { "0" } else { "1" };
    for name in ["AppsUseLightTheme", "SystemUsesLightTheme"] {
        run_command(
            "reg.exe",
            &[
                "add",
                r"HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
                "/v",
                name,
                "/t",
                "REG_DWORD",
                "/d",
                value,
                "/f",
            ],
        )?;
    }

    broadcast_theme_change();
    Ok(if dark {
        "Dark mode enabled for Windows and applications.".to_owned()
    } else {
        "Light mode enabled for Windows and applications.".to_owned()
    })
}

#[cfg(windows)]
fn broadcast_theme_change() {
    broadcast_setting_change("ImmersiveColorSet");
}

#[cfg(windows)]
fn broadcast_setting_change(setting: &str) {
    use windows_sys::Win32::UI::WindowsAndMessaging::{
        SendMessageTimeoutW, HWND_BROADCAST, SMTO_ABORTIFHUNG, WM_SETTINGCHANGE,
    };

    let parameter: Vec<u16> = setting.encode_utf16().chain(std::iter::once(0)).collect();
    unsafe {
        SendMessageTimeoutW(
            HWND_BROADCAST,
            WM_SETTINGCHANGE,
            0,
            parameter.as_ptr() as isize,
            SMTO_ABORTIFHUNG,
            1_000,
            std::ptr::null_mut(),
        );
    }
}

#[cfg(not(windows))]
fn broadcast_theme_change() {}

#[cfg(not(windows))]
fn broadcast_setting_change(_setting: &str) {}

#[cfg(windows)]
pub fn set_highest_refresh_rates() -> Result<String, String> {
    use windows_sys::Win32::Graphics::Gdi::{
        ChangeDisplaySettingsExW, EnumDisplayDevicesW, EnumDisplaySettingsW, CDS_UPDATEREGISTRY,
        DEVMODEW, DISPLAY_DEVICEW, DISPLAY_DEVICE_ACTIVE, DISPLAY_DEVICE_MIRRORING_DRIVER,
        DISP_CHANGE_SUCCESSFUL, DM_DISPLAYFREQUENCY, ENUM_CURRENT_SETTINGS,
    };

    let mut adapter_index = 0;
    let mut active_displays = 0;
    let mut changes = Vec::new();
    let mut failures = Vec::new();

    loop {
        let mut device = DISPLAY_DEVICEW {
            cb: std::mem::size_of::<DISPLAY_DEVICEW>() as u32,
            ..Default::default()
        };
        let found = unsafe { EnumDisplayDevicesW(std::ptr::null(), adapter_index, &mut device, 0) };
        if found == 0 {
            break;
        }
        adapter_index += 1;

        if device.StateFlags & DISPLAY_DEVICE_ACTIVE == 0
            || device.StateFlags & DISPLAY_DEVICE_MIRRORING_DRIVER != 0
        {
            continue;
        }
        active_displays += 1;

        let name = wide_array_to_string(&device.DeviceName);
        let description = wide_array_to_string(&device.DeviceString);
        let mut current = DEVMODEW {
            dmSize: std::mem::size_of::<DEVMODEW>() as u16,
            ..Default::default()
        };
        let current_found = unsafe {
            EnumDisplaySettingsW(
                device.DeviceName.as_ptr(),
                ENUM_CURRENT_SETTINGS,
                &mut current,
            )
        };
        if current_found == 0 {
            failures.push(format!(
                "{description}: could not read the current display mode"
            ));
            continue;
        }

        let mut best = current;
        let mut mode_index = 0;
        loop {
            let mut candidate = DEVMODEW {
                dmSize: std::mem::size_of::<DEVMODEW>() as u16,
                ..Default::default()
            };
            let mode_found = unsafe {
                EnumDisplaySettingsW(device.DeviceName.as_ptr(), mode_index, &mut candidate)
            };
            if mode_found == 0 {
                break;
            }
            mode_index += 1;

            if candidate.dmPelsWidth == current.dmPelsWidth
                && candidate.dmPelsHeight == current.dmPelsHeight
                && candidate.dmBitsPerPel == current.dmBitsPerPel
                && candidate.dmDisplayFrequency > best.dmDisplayFrequency
                && candidate.dmDisplayFrequency > 1
            {
                best = candidate;
            }
        }

        if best.dmDisplayFrequency <= current.dmDisplayFrequency {
            changes.push(format!(
                "{description} ({name}): already using {} Hz at {}x{}",
                current.dmDisplayFrequency, current.dmPelsWidth, current.dmPelsHeight
            ));
            continue;
        }

        best.dmFields = DM_DISPLAYFREQUENCY;
        let result = unsafe {
            ChangeDisplaySettingsExW(
                device.DeviceName.as_ptr(),
                &best,
                std::ptr::null_mut(),
                CDS_UPDATEREGISTRY,
                std::ptr::null(),
            )
        };
        if result == DISP_CHANGE_SUCCESSFUL {
            changes.push(format!(
                "{description} ({name}): {} Hz -> {} Hz at {}x{}",
                current.dmDisplayFrequency,
                best.dmDisplayFrequency,
                current.dmPelsWidth,
                current.dmPelsHeight
            ));
        } else {
            failures.push(format!(
                "{description} ({name}): Windows rejected {} Hz (code {result})",
                best.dmDisplayFrequency
            ));
        }
    }

    if active_displays == 0 {
        return Err("Windows did not report an active display adapter.".to_owned());
    }
    if changes.is_empty() && !failures.is_empty() {
        return Err(failures.join("\n"));
    }

    let mut message = changes.join("\n");
    if !failures.is_empty() {
        message.push_str("\n\nSome displays could not be changed:\n");
        message.push_str(&failures.join("\n"));
    }
    Ok(message)
}

#[cfg(not(windows))]
pub fn set_highest_refresh_rates() -> Result<String, String> {
    Err("Display refresh-rate changes are only supported on Windows.".to_owned())
}

pub fn query_network_adapters() -> Result<Vec<NetworkAdapter>, String> {
    let script = r#"$separator=[char]31; Get-NetAdapter | Sort-Object Name | ForEach-Object { $property=Get-NetAdapterAdvancedProperty -Name $_.Name -RegistryKeyword '*JumboPacket' -ErrorAction SilentlyContinue; $jumbo=if ($property) { [string]$property.RegistryValue } else { 'Unsupported' }; [Console]::Out.WriteLine($_.Name+$separator+$_.InterfaceDescription+$separator+$_.Status+$separator+$_.LinkSpeed+$separator+$jumbo) }"#;
    let output = run_command(
        "powershell.exe",
        &[
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            script,
        ],
    )?;

    let adapters = output
        .lines()
        .filter_map(|line| {
            let fields: Vec<&str> = line.split('\u{1f}').collect();
            (fields.len() == 5).then(|| NetworkAdapter {
                name: fields[0].trim().to_owned(),
                description: fields[1].trim().to_owned(),
                status: fields[2].trim().to_owned(),
                link_speed: fields[3].trim().to_owned(),
                jumbo_value: fields[4].trim().to_owned(),
            })
        })
        .collect::<Vec<_>>();

    if adapters.is_empty() {
        Err("No network adapters were returned by Get-NetAdapter.".to_owned())
    } else {
        Ok(adapters)
    }
}

pub fn set_jumbo_packet(adapter_name: &str, enabled: bool) -> Result<String, String> {
    let escaped_name = adapter_name.replace('\'', "''");
    let value = if enabled { 9014 } else { 1514 };
    let script = format!(
        "$ErrorActionPreference='Stop'; Set-NetAdapterAdvancedProperty -Name '{escaped_name}' -RegistryKeyword '*JumboPacket' -RegistryValue {value}; Write-Output 'Updated {escaped_name} to {value} bytes.'"
    );
    run_command(
        "powershell.exe",
        &[
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            &script,
        ],
    )
    .map_err(|error| {
        format!(
            "{error}\n\nThis change requires Administrator rights and adapter support for *JumboPacket."
        )
    })
}

pub fn query_execution_policies() -> Result<String, String> {
    let script = "Get-ExecutionPolicy -List | Format-Table -AutoSize | Out-String -Width 120";
    run_command(
        &windows_powershell_path(),
        &[
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            script,
        ],
    )
}

pub fn set_local_machine_execution_policy(policy: &str) -> Result<String, String> {
    let policy = match policy {
        "Unrestricted" => "Unrestricted",
        "Restricted" => "Restricted",
        "RemoteSigned" => "RemoteSigned",
        _ => return Err("Unsupported PowerShell execution policy requested.".to_owned()),
    };
    let script = local_machine_execution_policy_script(policy);
    run_command(
        &windows_powershell_path(),
        &[
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            &script,
        ],
    )
    .map_err(|error| {
        format!(
            "{error}\n\nWindows Toolbox could not verify the requested LocalMachine value. Use 'Check current policies' to identify higher-priority scopes. MachinePolicy and UserPolicy must be changed through the applicable Group Policy; Windows Toolbox will not bypass them."
        )
    })
}

fn local_machine_execution_policy_script(policy: &str) -> String {
    format!(
        r#"$ErrorActionPreference='Stop'
$setError = $null
try {{
    Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy {policy} -Force -ErrorAction Stop
}} catch {{
    $setError = $_.Exception.Message
}}
$policies = @(Get-ExecutionPolicy -List)
$localMachine = [string](Get-ExecutionPolicy -Scope LocalMachine)
$effective = [string](Get-ExecutionPolicy)
$table = $policies | Format-Table -AutoSize | Out-String -Width 120
if ($localMachine -ne '{policy}') {{
    $reason = if ($setError) {{ $setError }} else {{ 'Windows did not store the requested value.' }}
    throw ($reason + "`n`nLocalMachine remains " + $localMachine + ".`n" + $table)
}}
Write-Output 'LocalMachine execution policy was set to {policy}.'
if ($effective -ne '{policy}') {{
    $overriding = $policies |
        Where-Object {{ $_.Scope -in @('MachinePolicy', 'UserPolicy', 'Process', 'CurrentUser') -and $_.ExecutionPolicy -ne 'Undefined' }} |
        Select-Object -First 1
    if ($null -ne $overriding) {{
        Write-Output ('Effective policy remains ' + $effective + ' because ' + $overriding.Scope + ' is set to ' + $overriding.ExecutionPolicy + '.')
    }} else {{
        Write-Output ('Effective policy remains ' + $effective + ' because of a higher-priority Windows policy.')
    }}
}} else {{
    Write-Output 'The effective execution policy now matches LocalMachine.'
}}
Write-Output $table"#
    )
}

fn windows_powershell_path() -> String {
    std::env::var_os("SystemRoot")
        .map(std::path::PathBuf::from)
        .map(|root| {
            root.join("System32")
                .join("WindowsPowerShell")
                .join("v1.0")
                .join("powershell.exe")
        })
        .filter(|path| path.is_file())
        .map(|path| path.to_string_lossy().into_owned())
        .unwrap_or_else(|| "powershell.exe".to_owned())
}

fn run_command(program: &str, arguments: &[&str]) -> Result<String, String> {
    let mut command = Command::new(program);
    command.args(arguments);
    #[cfg(windows)]
    command.creation_flags(CREATE_NO_WINDOW);

    let output = command
        .output()
        .map_err(|error| format!("Could not start {program}: {error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_owned();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();

    if output.status.success() {
        Ok(if stdout.is_empty() {
            format!("{program} completed successfully.")
        } else {
            stdout
        })
    } else {
        let detail = match (stdout.is_empty(), stderr.is_empty()) {
            (false, false) => format!("{stdout}\n{stderr}"),
            (false, true) => stdout,
            (true, false) => stderr,
            (true, true) => format!("{program} exited with {}", output.status),
        };
        Err(detail)
    }
}

#[cfg(windows)]
fn wide_array_to_string(value: &[u16]) -> String {
    let length = value
        .iter()
        .position(|character| *character == 0)
        .unwrap_or(value.len());
    String::from_utf16_lossy(&value[..length])
}

#[cfg(test)]
mod tests {
    use super::{LegacyPanel, WindowsToggle, WindowsToggleStates};

    #[test]
    fn adapter_names_are_escaped_for_powershell_literals() {
        let name = "Dylan's Ethernet";
        assert_eq!(name.replace('\'', "''"), "Dylan''s Ethernet");
    }

    #[test]
    fn unsupported_execution_policy_is_rejected() {
        assert!(super::set_local_machine_execution_policy("Bypass").is_err());
    }

    #[test]
    fn execution_policy_change_verifies_the_stored_value_and_reports_overrides() {
        let script = super::local_machine_execution_policy_script("Restricted");
        assert!(script.contains("Get-ExecutionPolicy -Scope LocalMachine"));
        assert!(script.contains("$localMachine -ne 'Restricted'"));
        assert!(script.contains("MachinePolicy"));
        assert!(script.contains("UserPolicy"));
        assert!(script.contains("Process"));
        assert!(script.contains("CurrentUser"));
        assert!(script.contains("Effective policy remains"));
    }

    #[test]
    fn windows_toggle_state_accessors_cover_every_setting() {
        let mut states = WindowsToggleStates::default();
        for setting in [
            WindowsToggle::FileExtensions,
            WindowsToggle::HiddenFiles,
            WindowsToggle::GameMode,
            WindowsToggle::MouseAcceleration,
        ] {
            assert!(!states.get(setting));
            states.set(setting, true);
            assert!(states.get(setting));
        }
    }

    #[test]
    fn legacy_panel_commands_match_the_supplied_scripts() {
        assert_eq!(
            LegacyPanel::ControlPanel.command(),
            ("control.exe", &[][..])
        );
        assert_eq!(
            LegacyPanel::NetworkConnections.command(),
            ("control.exe", &["ncpa.cpl"][..])
        );
        assert_eq!(
            LegacyPanel::PowerOptions.command(),
            ("control.exe", &["powercfg.cpl"][..])
        );
        assert_eq!(
            LegacyPanel::Region.command(),
            ("control.exe", &["intl.cpl"][..])
        );
        assert_eq!(
            LegacyPanel::Sound.command(),
            ("control.exe", &["mmsys.cpl"][..])
        );
        assert_eq!(
            LegacyPanel::DevicesAndPrinters.command(),
            (
                "explorer.exe",
                &["shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}"][..]
            )
        );
        assert_eq!(
            LegacyPanel::SystemProperties.command(),
            ("control.exe", &["sysdm.cpl"][..])
        );
        assert_eq!(
            LegacyPanel::UserAccounts.command(),
            ("control.exe", &["userpasswords2"][..])
        );
    }
}
