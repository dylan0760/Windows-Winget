#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod catalog;
mod config;
mod tweaks;
mod updates;

use catalog::{GithubReleaseInstaller, Package, BASIC_PRESET, GAMING_PRESET, PACKAGES};
use config::ConfigFeature;
use eframe::egui;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::mpsc::{self, Receiver};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tweaks::{LegacyPanel, NetworkAdapter, WindowsToggle, WindowsToggleStates};
use updates::UpdateInfo;

#[cfg(windows)]
use std::os::windows::process::CommandExt;

#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x0800_0000;

const CHOCOLATEY_INSTALL_SCRIPT: &str = r#"Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"#;

enum InstallEvent {
    Started {
        number: usize,
        name: &'static str,
    },
    Finished {
        name: &'static str,
        success: bool,
        detail: String,
    },
    Fatal(String),
    Done,
}

#[derive(Clone, Copy, Default, Eq, PartialEq)]
enum AppTab {
    #[default]
    Programs,
    WindowsTweaks,
    Config,
    LegacyPanels,
}

enum TweakEvent {
    Completed(Result<String, String>),
    Adapters(Result<Vec<NetworkAdapter>, String>),
    ToggleStates(Result<WindowsToggleStates, String>),
    ConfigFeatureStates(Result<[bool; ConfigFeature::ALL.len()], String>),
    ToggleCompleted {
        setting: WindowsToggle,
        previous: bool,
        result: Result<String, String>,
    },
}

enum UpdateEvent {
    Checked(Result<Option<UpdateInfo>, String>),
}

struct LauncherApp {
    active_tab: AppTab,
    selected: Vec<bool>,
    query: String,
    receiver: Option<Receiver<InstallEvent>>,
    installing: bool,
    total: usize,
    completed: usize,
    status: String,
    results: Vec<(String, bool, String)>,
    tweak_receiver: Option<Receiver<TweakEvent>>,
    tweak_busy: bool,
    tweak_status: String,
    tweak_succeeded: Option<bool>,
    adapters: Vec<NetworkAdapter>,
    selected_adapter: usize,
    jumbo_confirmed: bool,
    unrestricted_confirmed: bool,
    windows_toggle_states: Option<WindowsToggleStates>,
    toggle_states_loaded: bool,
    config_features: [bool; ConfigFeature::ALL.len()],
    config_states_loaded: bool,
    legacy_status: String,
    legacy_succeeded: Option<bool>,
    update_receiver: Option<Receiver<UpdateEvent>>,
    update_check_started: bool,
    update_checking: bool,
    available_update: Option<UpdateInfo>,
    update_status: String,
    update_succeeded: Option<bool>,
}

impl Default for LauncherApp {
    fn default() -> Self {
        Self {
            active_tab: AppTab::Programs,
            selected: vec![false; PACKAGES.len()],
            query: String::new(),
            receiver: None,
            installing: false,
            total: 0,
            completed: 0,
            status: "Ready".to_owned(),
            results: Vec::new(),
            tweak_receiver: None,
            tweak_busy: false,
            tweak_status: "Ready.".to_owned(),
            tweak_succeeded: None,
            adapters: Vec::new(),
            selected_adapter: 0,
            jumbo_confirmed: false,
            unrestricted_confirmed: false,
            windows_toggle_states: None,
            toggle_states_loaded: false,
            config_features: [false; ConfigFeature::ALL.len()],
            config_states_loaded: false,
            legacy_status: "Ready to open a legacy Windows panel.".to_owned(),
            legacy_succeeded: None,
            update_receiver: None,
            update_check_started: false,
            update_checking: false,
            available_update: None,
            update_status: "Update check pending.".to_owned(),
            update_succeeded: None,
        }
    }
}

impl LauncherApp {
    fn matching(&self, package: &Package) -> bool {
        let query = self.query.trim().to_ascii_lowercase();
        query.is_empty()
            || package.name.to_ascii_lowercase().contains(&query)
            || package.id.to_ascii_lowercase().contains(&query)
            || package.category.to_ascii_lowercase().contains(&query)
    }

    fn start_update_check(&mut self) {
        if self.update_checking {
            return;
        }
        let (sender, receiver) = mpsc::channel();
        self.update_receiver = Some(receiver);
        self.update_check_started = true;
        self.update_checking = true;
        self.available_update = None;
        self.update_status = "Checking GitHub for updates...".to_owned();
        self.update_succeeded = None;
        std::thread::spawn(move || {
            let _ = sender.send(UpdateEvent::Checked(updates::check_for_update()));
        });
    }

    fn poll_update_check(&mut self) {
        let Some(receiver) = self.update_receiver.take() else {
            return;
        };
        match receiver.try_recv() {
            Ok(UpdateEvent::Checked(result)) => {
                self.update_checking = false;
                match result {
                    Ok(Some(update)) => {
                        self.update_status = format!("Version {} is available.", update.version);
                        self.available_update = Some(update);
                        self.update_succeeded = Some(true);
                    }
                    Ok(None) => {
                        self.update_status = "Windows Toolbox is up to date.".to_owned();
                        self.available_update = None;
                        self.update_succeeded = Some(true);
                    }
                    Err(message) => {
                        self.update_status = format!("Update check failed: {message}");
                        self.available_update = None;
                        self.update_succeeded = Some(false);
                    }
                }
            }
            Err(mpsc::TryRecvError::Empty) => {
                self.update_receiver = Some(receiver);
            }
            Err(mpsc::TryRecvError::Disconnected) => {
                self.update_checking = false;
                self.update_status = "The update checker stopped unexpectedly.".to_owned();
                self.update_succeeded = Some(false);
            }
        }
    }

    fn selected_count(&self) -> usize {
        self.selected.iter().filter(|value| **value).count()
    }

    fn set_visible(&mut self, value: bool) {
        for (index, package) in PACKAGES.iter().enumerate() {
            if self.matching(package) {
                self.selected[index] = value;
            }
        }
    }

    fn apply_preset(&mut self, ids: &[&str], name: &str) {
        self.selected.fill(false);
        for (index, package) in PACKAGES.iter().enumerate() {
            self.selected[index] = ids.contains(&package.id);
        }
        self.status = format!("{name} preset applied ({} selected)", self.selected_count());
    }

    fn start_install(&mut self) {
        let packages: Vec<Package> = PACKAGES
            .iter()
            .zip(&self.selected)
            .filter_map(|(package, selected)| selected.then_some(*package))
            .collect();

        if packages.is_empty() {
            self.status = "Select at least one package.".to_owned();
            return;
        }

        let (sender, receiver) = mpsc::channel();
        self.receiver = Some(receiver);
        self.installing = true;
        self.total = packages.len();
        self.completed = 0;
        self.results.clear();
        self.status = format!("Preparing to install {} package(s)...", self.total);

        std::thread::spawn(move || {
            if packages
                .iter()
                .any(|package| package.github_release.is_none() && package.chocolatey_id.is_none())
            {
                if let Err(message) = winget_available() {
                    let _ = sender.send(InstallEvent::Fatal(message));
                    return;
                }
            }
            for (index, package) in packages.into_iter().enumerate() {
                let _ = sender.send(InstallEvent::Started {
                    number: index + 1,
                    name: package.name,
                });

                let result = install(package);
                let (success, detail) = match result {
                    Ok(detail) => (true, detail),
                    Err(detail) => (false, detail),
                };
                let _ = sender.send(InstallEvent::Finished {
                    name: package.name,
                    success,
                    detail,
                });
            }
            let _ = sender.send(InstallEvent::Done);
        });
    }

    fn poll_installer(&mut self) {
        let Some(receiver) = self.receiver.take() else {
            return;
        };

        let mut finished = false;
        for event in receiver.try_iter() {
            match event {
                InstallEvent::Started { number, name } => {
                    self.status = format!("Installing {number}/{}: {name}", self.total);
                }
                InstallEvent::Finished {
                    name,
                    success,
                    detail,
                } => {
                    self.completed += 1;
                    self.results.push((name.to_owned(), success, detail));
                }
                InstallEvent::Fatal(message) => {
                    self.status = message.clone();
                    self.results.push(("WinGet".to_owned(), false, message));
                    self.installing = false;
                    finished = true;
                }
                InstallEvent::Done => {
                    let failures = self.results.iter().filter(|(_, ok, _)| !ok).count();
                    self.status = if failures == 0 {
                        format!(
                            "Completed: {} package(s) installed successfully.",
                            self.total
                        )
                    } else {
                        format!("Completed with {failures} failure(s). See results below.")
                    };
                    self.installing = false;
                    finished = true;
                }
            }
        }

        if !finished {
            self.receiver = Some(receiver);
        }
    }

    fn start_tweak<F>(&mut self, message: &str, action: F)
    where
        F: FnOnce() -> Result<String, String> + Send + 'static,
    {
        let (sender, receiver) = mpsc::channel();
        self.tweak_receiver = Some(receiver);
        self.tweak_busy = true;
        self.tweak_succeeded = None;
        self.tweak_status = message.to_owned();
        std::thread::spawn(move || {
            let _ = sender.send(TweakEvent::Completed(action()));
        });
    }

    fn refresh_adapters(&mut self) {
        let (sender, receiver) = mpsc::channel();
        self.tweak_receiver = Some(receiver);
        self.tweak_busy = true;
        self.tweak_succeeded = None;
        self.tweak_status = "Reading network adapters...".to_owned();
        std::thread::spawn(move || {
            let _ = sender.send(TweakEvent::Adapters(tweaks::query_network_adapters()));
        });
    }

    fn refresh_windows_toggle_states(&mut self) {
        let (sender, receiver) = mpsc::channel();
        self.tweak_receiver = Some(receiver);
        self.tweak_busy = true;
        self.tweak_succeeded = None;
        self.toggle_states_loaded = true;
        self.tweak_status = "Reading current Windows preference states...".to_owned();
        std::thread::spawn(move || {
            let _ = sender.send(TweakEvent::ToggleStates(
                tweaks::query_windows_toggle_states(),
            ));
        });
    }

    fn refresh_config_feature_states(&mut self) {
        let (sender, receiver) = mpsc::channel();
        self.tweak_receiver = Some(receiver);
        self.tweak_busy = true;
        self.tweak_succeeded = None;
        self.config_states_loaded = true;
        self.tweak_status = "Reading current Windows optional-feature states...".to_owned();
        std::thread::spawn(move || {
            let _ = sender.send(TweakEvent::ConfigFeatureStates(
                config::query_feature_states(),
            ));
        });
    }

    fn start_windows_toggle(&mut self, setting: WindowsToggle, enabled: bool, previous: bool) {
        let (sender, receiver) = mpsc::channel();
        self.tweak_receiver = Some(receiver);
        self.tweak_busy = true;
        self.tweak_succeeded = None;
        self.tweak_status = format!(
            "Setting {} {}...",
            windows_toggle_name(setting),
            if enabled { "on" } else { "off" }
        );
        std::thread::spawn(move || {
            let result = tweaks::set_windows_toggle(setting, enabled);
            let _ = sender.send(TweakEvent::ToggleCompleted {
                setting,
                previous,
                result,
            });
        });
    }

    fn poll_tweaks(&mut self) {
        let Some(receiver) = self.tweak_receiver.take() else {
            return;
        };
        match receiver.try_recv() {
            Ok(TweakEvent::Completed(result)) => {
                self.tweak_busy = false;
                match result {
                    Ok(message) => {
                        self.tweak_succeeded = Some(true);
                        self.tweak_status = message;
                    }
                    Err(message) => {
                        self.tweak_succeeded = Some(false);
                        self.tweak_status = message;
                    }
                }
            }
            Ok(TweakEvent::Adapters(result)) => {
                self.tweak_busy = false;
                match result {
                    Ok(adapters) => {
                        self.adapters = adapters;
                        self.selected_adapter = self
                            .selected_adapter
                            .min(self.adapters.len().saturating_sub(1));
                        self.tweak_succeeded = Some(true);
                        self.tweak_status =
                            format!("Found {} network adapter(s).", self.adapters.len());
                    }
                    Err(message) => {
                        self.adapters.clear();
                        self.selected_adapter = 0;
                        self.tweak_succeeded = Some(false);
                        self.tweak_status = message;
                    }
                }
            }
            Ok(TweakEvent::ToggleStates(result)) => {
                self.tweak_busy = false;
                match result {
                    Ok(states) => {
                        self.windows_toggle_states = Some(states);
                        self.tweak_succeeded = Some(true);
                        self.tweak_status = "Loaded current Windows preference states.".to_owned();
                    }
                    Err(message) => {
                        self.windows_toggle_states = None;
                        self.tweak_succeeded = Some(false);
                        self.tweak_status = message;
                    }
                }
            }
            Ok(TweakEvent::ConfigFeatureStates(result)) => {
                self.tweak_busy = false;
                match result {
                    Ok(states) => {
                        self.config_features = states;
                        let enabled = states.iter().filter(|state| **state).count();
                        self.tweak_succeeded = Some(true);
                        self.tweak_status = format!(
                            "Loaded feature states: {enabled} of {} feature groups enabled.",
                            states.len()
                        );
                    }
                    Err(message) => {
                        self.tweak_succeeded = Some(false);
                        self.tweak_status = message;
                    }
                }
            }
            Ok(TweakEvent::ToggleCompleted {
                setting,
                previous,
                result,
            }) => {
                self.tweak_busy = false;
                match result {
                    Ok(message) => {
                        self.tweak_succeeded = Some(true);
                        self.tweak_status = message;
                    }
                    Err(message) => {
                        if let Some(states) = self.windows_toggle_states.as_mut() {
                            states.set(setting, previous);
                        }
                        self.tweak_succeeded = Some(false);
                        self.tweak_status = message;
                    }
                }
            }
            Err(mpsc::TryRecvError::Empty) => {
                self.tweak_receiver = Some(receiver);
            }
            Err(mpsc::TryRecvError::Disconnected) => {
                self.tweak_busy = false;
                self.tweak_succeeded = Some(false);
                self.tweak_status = "The tweak worker stopped unexpectedly.".to_owned();
            }
        }
    }
}

fn windows_toggle_name(setting: WindowsToggle) -> &'static str {
    match setting {
        WindowsToggle::FileExtensions => "File Explorer file extensions",
        WindowsToggle::HiddenFiles => "File Explorer hidden files",
        WindowsToggle::GameMode => "Windows Game Mode",
        WindowsToggle::MouseAcceleration => "mouse acceleration",
    }
}

impl LauncherApp {
    fn show_windows_toggle(
        &mut self,
        ui: &mut egui::Ui,
        setting: WindowsToggle,
        label: &str,
        description: &str,
    ) {
        let Some(current) = self.windows_toggle_states.map(|states| states.get(setting)) else {
            ui.horizontal(|ui| {
                ui.label(egui::RichText::new(label).strong());
                ui.weak("State unavailable");
            });
            ui.weak(description);
            return;
        };

        let mut requested = current;
        let mut changed = false;
        ui.horizontal(|ui| {
            ui.label(egui::RichText::new(label).strong());
            changed = ui
                .add_enabled(
                    !self.tweak_busy,
                    egui::Checkbox::new(&mut requested, "Enabled"),
                )
                .changed();
        });
        ui.weak(description);

        if changed {
            if let Some(states) = self.windows_toggle_states.as_mut() {
                states.set(setting, requested);
            }
            self.start_windows_toggle(setting, requested, current);
        }
    }

    fn show_tweaks(&mut self, ui: &mut egui::Ui) {
        egui::ScrollArea::vertical().show(ui, |ui| {
            ui.heading("Appearance");
            ui.label("Change the Windows system and application colour preference for this user.");
            ui.horizontal(|ui| {
                if ui
                    .add_enabled(!self.tweak_busy, egui::Button::new("Use dark mode"))
                    .clicked()
                {
                    self.start_tweak("Enabling dark mode...", || tweaks::set_dark_mode(true));
                }
                if ui
                    .add_enabled(!self.tweak_busy, egui::Button::new("Use light mode"))
                    .clicked()
                {
                    self.start_tweak("Enabling light mode...", || tweaks::set_dark_mode(false));
                }
            });

            ui.add_space(14.0);
            ui.separator();
            ui.add_space(8.0);
            ui.heading("Explorer and gaming preferences");
            ui.label("Toggle common Windows preferences and view their current states.");
            if ui
                .add_enabled(
                    !self.tweak_busy,
                    egui::Button::new("Refresh preference states"),
                )
                .clicked()
            {
                self.refresh_windows_toggle_states();
            }
            ui.add_space(6.0);
            self.show_windows_toggle(
                ui,
                WindowsToggle::FileExtensions,
                "Show File Explorer file extensions",
                "Show extensions such as .exe, .png, and .txt. Existing Explorer windows may need to be refreshed.",
            );
            ui.add_space(6.0);
            self.show_windows_toggle(
                ui,
                WindowsToggle::HiddenFiles,
                "Show hidden files in File Explorer",
                "Reveal or hide items carrying the Windows hidden-file attribute.",
            );
            ui.add_space(6.0);
            self.show_windows_toggle(
                ui,
                WindowsToggle::GameMode,
                "Windows Game Mode",
                "Allow Windows to prioritize system resources for games.",
            );
            ui.add_space(6.0);
            self.show_windows_toggle(
                ui,
                WindowsToggle::MouseAcceleration,
                "Mouse acceleration",
                "Let pointer movement vary with the speed of physical mouse movement.",
            );

            ui.add_space(14.0);
            ui.separator();
            ui.add_space(8.0);
            ui.heading("Display refresh rate");
            ui.label(
                "Select the highest refresh rate Windows reports as supported at each display's current resolution and colour depth.",
            );
            if ui
                .add_enabled(
                    !self.tweak_busy,
                    egui::Button::new("Use highest supported refresh rate"),
                )
                .clicked()
            {
                self.start_tweak("Checking supported display modes...", || {
                    tweaks::set_highest_refresh_rates()
                });
            }

            ui.add_space(14.0);
            ui.separator();
            ui.add_space(8.0);
            ui.heading("Jumbo Frames");
            ui.label(
                "Configure the selected adapter's *JumboPacket advanced property, matching the supplied script.",
            );
            ui.colored_label(
                egui::Color32::from_rgb(210, 145, 35),
                "Only use 9014 bytes when the adapter, switch, router, and destination all support it. The adapter may briefly disconnect.",
            );

            if ui
                .add_enabled(!self.tweak_busy, egui::Button::new("Refresh adapter list"))
                .clicked()
            {
                self.refresh_adapters();
            }

            if self.adapters.is_empty() {
                ui.weak("No adapters loaded.");
            }

            let selected_text = self
                .adapters
                .get(self.selected_adapter)
                .map(|adapter| adapter.name.as_str())
                .unwrap_or("Select an adapter");
            egui::ComboBox::from_id_salt("jumbo_adapter")
                .selected_text(selected_text)
                .show_ui(ui, |ui| {
                    for (index, adapter) in self.adapters.iter().enumerate() {
                        ui.selectable_value(
                            &mut self.selected_adapter,
                            index,
                            format!("{} — {}", adapter.name, adapter.status),
                        );
                    }
                });

            let selected = self.adapters.get(self.selected_adapter).cloned();
            if let Some(adapter) = selected {
                ui.label(format!("Adapter: {}", adapter.description));
                ui.label(format!(
                    "Status: {}   Link speed: {}   Jumbo value: {}",
                    adapter.status, adapter.link_speed, adapter.jumbo_value
                ));
                ui.checkbox(
                    &mut self.jumbo_confirmed,
                    "I understand Jumbo Frames can interrupt networking when the network is not configured end-to-end.",
                );

                ui.horizontal(|ui| {
                    let can_enable = !self.tweak_busy && self.jumbo_confirmed;
                    if ui
                        .add_enabled(can_enable, egui::Button::new("Enable 9014-byte Jumbo Frames"))
                        .clicked()
                    {
                        let name = adapter.name.clone();
                        self.start_tweak("Enabling Jumbo Frames...", move || {
                            tweaks::set_jumbo_packet(&name, true)
                        });
                    }
                    if ui
                        .add_enabled(
                            !self.tweak_busy,
                            egui::Button::new("Restore standard 1514-byte frame"),
                        )
                        .clicked()
                    {
                        let name = adapter.name.clone();
                        self.start_tweak("Restoring the standard frame size...", move || {
                            tweaks::set_jumbo_packet(&name, false)
                        });
                    }
                });
                ui.weak(
                    "Changing this adapter property normally requires running the application as Administrator.",
                );
            }

            ui.add_space(14.0);
            ui.separator();
            ui.add_space(8.0);
            ui.heading("PowerShell execution policy");
            ui.label(
                "View or change the 64-bit Windows PowerShell LocalMachine execution policy.",
            );
            ui.colored_label(
                egui::Color32::from_rgb(210, 145, 35),
                "Unrestricted permits unsigned local scripts and only warns for scripts marked as downloaded. It is not recommended for normal use.",
            );
            if ui
                .add_enabled(!self.tweak_busy, egui::Button::new("Check current policies"))
                .clicked()
            {
                self.start_tweak("Reading PowerShell execution policies...", || {
                    tweaks::query_execution_policies()
                });
            }
            ui.checkbox(
                &mut self.unrestricted_confirmed,
                "I understand that Unrestricted weakens PowerShell script-origin protections for all users.",
            );
            ui.horizontal(|ui| {
                if ui
                    .add_enabled(
                        !self.tweak_busy && self.unrestricted_confirmed,
                        egui::Button::new("Set LocalMachine to Unrestricted"),
                    )
                    .clicked()
                {
                    self.start_tweak("Setting PowerShell policy to Unrestricted...", || {
                        tweaks::set_local_machine_execution_policy("Unrestricted")
                    });
                }
                if ui
                    .add_enabled(
                        !self.tweak_busy,
                        egui::Button::new("Set LocalMachine to Restricted"),
                    )
                    .clicked()
                {
                    self.start_tweak("Setting PowerShell policy to Restricted...", || {
                        tweaks::set_local_machine_execution_policy("Restricted")
                    });
                }
                if ui
                    .add_enabled(
                        !self.tweak_busy,
                        egui::Button::new("Set LocalMachine to RemoteSigned"),
                    )
                    .clicked()
                {
                    self.start_tweak("Setting PowerShell policy to RemoteSigned...", || {
                        tweaks::set_local_machine_execution_policy("RemoteSigned")
                    });
                }
            });
            ui.weak(
                "LocalMachine requires Administrator rights. Higher-priority MachinePolicy, UserPolicy, Process, or CurrentUser settings remain effective and will be reported.",
            );
        });
    }

    fn show_config(&mut self, ui: &mut egui::Ui) {
        egui::ScrollArea::vertical().show(ui, |ui| {
            ui.heading("Features");
            ui.label(
                "Select Windows optional features, then enable them using the same feature mappings as WinUtil.",
            );
            ui.colored_label(
                egui::Color32::from_rgb(210, 145, 35),
                "Availability depends on your Windows edition. Hyper-V, Sandbox, WSL, and NFS may require a restart.",
            );
            ui.add_space(8.0);

            if ui
                .add_enabled(
                    !self.tweak_busy,
                    egui::Button::new("Refresh feature states"),
                )
                .clicked()
            {
                self.refresh_config_feature_states();
            }
            ui.weak(
                "Enabled and enable-pending groups are checked automatically. A group with only some components enabled remains unchecked.",
            );
            ui.add_space(8.0);

            ui.add_enabled_ui(!self.tweak_busy, |ui| {
                for (index, feature) in ConfigFeature::ALL.iter().copied().enumerate() {
                    ui.checkbox(&mut self.config_features[index], feature.label());
                    ui.indent(format!("config_feature_{index}"), |ui| {
                        ui.weak(feature.description());
                        ui.monospace(feature.feature_names().join(", "));
                    });
                    ui.add_space(7.0);
                }
            });

            let selected: Vec<_> = ConfigFeature::ALL
                .iter()
                .copied()
                .zip(self.config_features)
                .filter_map(|(feature, selected)| selected.then_some(feature))
                .collect();
            ui.horizontal(|ui| {
                let enable = egui::Button::new(
                    egui::RichText::new(format!("Enable selected ({})", selected.len()))
                        .strong()
                        .color(egui::Color32::WHITE),
                )
                .fill(egui::Color32::from_rgb(42, 93, 210));
                if ui
                    .add_enabled(!self.tweak_busy && !selected.is_empty(), enable)
                    .clicked()
                {
                    self.start_tweak("Enabling selected Windows features...", move || {
                        config::enable_features(&selected)
                    });
                }
                if ui
                    .add_enabled(!self.tweak_busy, egui::Button::new("Clear selection"))
                    .clicked()
                {
                    self.config_features.fill(false);
                }
            });

            ui.add_space(16.0);
            ui.separator();
            ui.add_space(8.0);
            ui.heading("Autologin");
            ui.label(
                "Download and run Microsoft Sysinternals Autologon, matching WinUtil's Autologin action.",
            );
            ui.colored_label(
                egui::Color32::from_rgb(210, 145, 35),
                "Autologin reduces physical sign-in security. Review the account carefully in Microsoft's dialog.",
            );
            if ui
                .add_enabled(
                    !self.tweak_busy,
                    egui::Button::new("Run Microsoft Autologon"),
                )
                .clicked()
            {
                self.start_tweak("Downloading and validating Microsoft Autologon...", || {
                    config::run_autologon()
                });
            }
            ui.weak(
                "The download must have a valid Microsoft Authenticode signature. The temporary executable is deleted after the dialog closes.",
            );
        });
    }

    fn show_legacy_panels(&mut self, ui: &mut egui::Ui) {
        const PANELS: &[(LegacyPanel, &str, &str)] = &[
            (
                LegacyPanel::ControlPanel,
                "Control Panel",
                "Open the classic Control Panel home page.",
            ),
            (
                LegacyPanel::NetworkConnections,
                "Network Connections",
                "Manage classic network adapters and their properties.",
            ),
            (
                LegacyPanel::PowerOptions,
                "Power Options",
                "Choose and configure classic Windows power plans.",
            ),
            (
                LegacyPanel::Region,
                "Region",
                "Change regional formats and administrative settings.",
            ),
            (
                LegacyPanel::Sound,
                "Sound",
                "Manage playback, recording, sounds, and communications.",
            ),
            (
                LegacyPanel::DevicesAndPrinters,
                "Devices and Printers",
                "Open the classic devices and printers shell view.",
            ),
            (
                LegacyPanel::SystemProperties,
                "System Properties",
                "Open computer name, hardware, and advanced system settings.",
            ),
            (
                LegacyPanel::UserAccounts,
                "User Accounts",
                "Manage local user accounts with the classic dialog.",
            ),
        ];

        ui.heading("Legacy Windows Panels");
        ui.label(
            "Open classic Windows management panels directly. No PowerShell scripts are required.",
        );
        ui.add_space(10.0);

        egui::Grid::new("legacy_panels_grid")
            .num_columns(2)
            .spacing([18.0, 14.0])
            .show(ui, |ui| {
                for (index, (panel, name, description)) in PANELS.iter().enumerate() {
                    ui.vertical(|ui| {
                        if ui
                            .add_sized([230.0, 34.0], egui::Button::new(*name))
                            .clicked()
                        {
                            match tweaks::open_legacy_panel(*panel) {
                                Ok(message) => {
                                    self.legacy_succeeded = Some(true);
                                    self.legacy_status = message;
                                }
                                Err(message) => {
                                    self.legacy_succeeded = Some(false);
                                    self.legacy_status = message;
                                }
                            }
                        }
                        ui.weak(*description);
                    });
                    if index % 2 == 1 {
                        ui.end_row();
                    }
                }
            });
    }
}

impl eframe::App for LauncherApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.poll_installer();
        self.poll_tweaks();
        self.poll_update_check();
        if !self.update_check_started {
            self.start_update_check();
        }
        if self.active_tab == AppTab::WindowsTweaks
            && !self.toggle_states_loaded
            && !self.tweak_busy
        {
            self.refresh_windows_toggle_states();
        }
        if self.active_tab == AppTab::Config && !self.config_states_loaded && !self.tweak_busy {
            self.refresh_config_feature_states();
        }
        if self.installing || self.tweak_busy || self.update_checking {
            ctx.request_repaint_after(Duration::from_millis(100));
        }

        egui::TopBottomPanel::top("header").show(ctx, |ui| {
            ui.add_space(12.0);
            ui.heading("Windows Toolbox");
            ui.horizontal(|ui| {
                ui.selectable_value(&mut self.active_tab, AppTab::Programs, "Programs");
                ui.selectable_value(
                    &mut self.active_tab,
                    AppTab::WindowsTweaks,
                    "Windows Tweaks",
                );
                ui.selectable_value(&mut self.active_tab, AppTab::Config, "Config");
                ui.selectable_value(&mut self.active_tab, AppTab::LegacyPanels, "Legacy Panels");
            });
            ui.label(match self.active_tab {
                AppTab::Programs => {
                    "Choose applications and install them directly with Windows Package Manager."
                }
                AppTab::WindowsTweaks => {
                    "Apply useful Windows appearance, display, and network-adapter settings."
                }
                AppTab::Config => {
                    "Enable Windows optional features and run trusted configuration utilities."
                }
                AppTab::LegacyPanels => {
                    "Open classic Windows Control Panel destinations and management dialogs."
                }
            });
            if let Some(update) = self.available_update.clone() {
                ui.add_space(5.0);
                ui.separator();
                ui.horizontal_wrapped(|ui| {
                    ui.colored_label(
                        egui::Color32::from_rgb(35, 155, 85),
                        format!(
                            "Windows Toolbox {} is available (running {}).",
                            update.version,
                            updates::CURRENT_VERSION
                        ),
                    );
                    if ui.button("Download update").clicked() {
                        match updates::open_update_download(&update) {
                            Ok(message) => {
                                self.update_status = message;
                                self.update_succeeded = Some(true);
                            }
                            Err(message) => {
                                self.update_status = message;
                                self.update_succeeded = Some(false);
                            }
                        }
                    }
                });
            }
            ui.add_space(8.0);
        });

        egui::TopBottomPanel::bottom("status").show(ctx, |ui| {
            ui.add_space(5.0);
            match self.active_tab {
                AppTab::Programs => {
                    if self.installing {
                        let progress = self.completed as f32 / self.total.max(1) as f32;
                        ui.add(egui::ProgressBar::new(progress).show_percentage());
                    }
                    ui.horizontal_wrapped(|ui| {
                        ui.label(&self.status);
                        if !self.results.is_empty() {
                            let succeeded = self.results.iter().filter(|(_, ok, _)| *ok).count();
                            let failed = self.results.len() - succeeded;
                            ui.separator();
                            ui.label(format!("Succeeded: {succeeded}  Failed: {failed}"));
                        }
                    });
                }
                AppTab::WindowsTweaks | AppTab::Config => {
                    ui.horizontal_wrapped(|ui| {
                        if self.tweak_busy {
                            ui.spinner();
                        }
                        let color = match self.tweak_succeeded {
                            Some(true) => egui::Color32::from_rgb(35, 155, 85),
                            Some(false) => egui::Color32::from_rgb(210, 65, 60),
                            None => ui.visuals().text_color(),
                        };
                        ui.label(egui::RichText::new(&self.tweak_status).color(color));
                    });
                }
                AppTab::LegacyPanels => {
                    let color = match self.legacy_succeeded {
                        Some(true) => egui::Color32::from_rgb(35, 155, 85),
                        Some(false) => egui::Color32::from_rgb(210, 65, 60),
                        None => ui.visuals().text_color(),
                    };
                    ui.label(egui::RichText::new(&self.legacy_status).color(color));
                }
            }
            ui.add_space(3.0);
            ui.horizontal(|ui| {
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    ui.monospace(format!("Version {}", updates::CURRENT_VERSION));
                    if ui
                        .add_enabled(
                            !self.update_checking,
                            egui::Button::new("Check for updates"),
                        )
                        .clicked()
                    {
                        self.start_update_check();
                    }
                    if self.update_checking {
                        ui.spinner();
                    }
                    let color = match self.update_succeeded {
                        Some(false) => egui::Color32::from_rgb(210, 65, 60),
                        _ => ui.visuals().weak_text_color(),
                    };
                    ui.label(egui::RichText::new(&self.update_status).color(color));
                });
            });
            ui.add_space(5.0);
        });

        egui::CentralPanel::default().show(ctx, |ui| {
            if self.active_tab == AppTab::Programs {
                ui.add_enabled_ui(!self.installing, |ui| {
                    ui.horizontal(|ui| {
                        ui.add_sized(
                            [ui.available_width() - 110.0, 30.0],
                            egui::TextEdit::singleline(&mut self.query)
                                .hint_text("Search by name, category, or package ID"),
                        );
                        ui.label(format!("{} selected", self.selected_count()));
                    });

                    ui.add_space(7.0);
                    ui.horizontal_wrapped(|ui| {
                        if ui.button("Select visible").clicked() {
                            self.set_visible(true);
                        }
                        if ui.button("Deselect visible").clicked() {
                            self.set_visible(false);
                        }
                        ui.separator();
                        if ui.button("Windows 11 basic").clicked() {
                            self.apply_preset(BASIC_PRESET, "Windows 11 basic");
                        }
                        if ui.button("Gaming setup").clicked() {
                            self.apply_preset(GAMING_PRESET, "Gaming setup");
                        }
                        ui.separator();
                        let install = egui::Button::new(
                            egui::RichText::new("Install selected")
                                .strong()
                                .color(egui::Color32::WHITE),
                        )
                        .fill(egui::Color32::from_rgb(42, 93, 210));
                        if ui.add(install).clicked() {
                            self.start_install();
                        }
                    });
                });

                ui.separator();
                egui::ScrollArea::vertical().show(ui, |ui| {
                    let mut current_category = "";
                    for (index, package) in PACKAGES.iter().enumerate() {
                        if !self.matching(package) {
                            continue;
                        }
                        if current_category != package.category {
                            current_category = package.category;
                            ui.add_space(6.0);
                            ui.label(egui::RichText::new(current_category).strong().size(14.0));
                        }
                        ui.add_enabled_ui(!self.installing, |ui| {
                            ui.horizontal(|ui| {
                                ui.checkbox(&mut self.selected[index], package.name);
                                ui.with_layout(
                                    egui::Layout::right_to_left(egui::Align::Center),
                                    |ui| {
                                        ui.weak(package.id);
                                    },
                                );
                            });
                        });
                    }

                    if !self.results.is_empty() {
                        ui.add_space(12.0);
                        ui.separator();
                        ui.heading("Installation results");
                        for (name, success, detail) in &self.results {
                            let (symbol, color) = if *success {
                                ("OK", egui::Color32::from_rgb(35, 155, 85))
                            } else {
                                ("FAILED", egui::Color32::from_rgb(210, 65, 60))
                            };
                            ui.collapsing(
                                egui::RichText::new(format!("{symbol}  {name}")).color(color),
                                |ui| {
                                    ui.monospace(detail);
                                },
                            );
                        }
                    }
                });
            } else if self.active_tab == AppTab::WindowsTweaks {
                self.show_tweaks(ui);
            } else if self.active_tab == AppTab::Config {
                self.show_config(ui);
            } else {
                self.show_legacy_panels(ui);
            }
        });
    }
}

fn winget_available() -> Result<(), String> {
    let mut command = Command::new("winget");
    command.arg("--version");
    #[cfg(windows)]
    command.creation_flags(CREATE_NO_WINDOW);

    let output = command.output().map_err(|error| {
        if error.kind() == std::io::ErrorKind::NotFound {
            "WinGet was not found. Install or update 'App Installer' from Microsoft Store, then try again."
                .to_owned()
        } else {
            format!("Could not start WinGet: {error}")
        }
    })?;

    output
        .status
        .success()
        .then_some(())
        .ok_or_else(|| "WinGet is installed but did not start successfully.".to_owned())
}

fn chocolatey_available() -> Result<(), String> {
    let mut command = Command::new(chocolatey_executable());
    command.arg("--version");
    #[cfg(windows)]
    command.creation_flags(CREATE_NO_WINDOW);

    let output = command.output().map_err(|error| {
        if error.kind() == std::io::ErrorKind::NotFound {
            "Chocolatey was not found. Install Chocolatey, restart Windows Toolbox, then try again."
                .to_owned()
        } else {
            format!("Could not start Chocolatey: {error}")
        }
    })?;

    output
        .status
        .success()
        .then_some(())
        .ok_or_else(|| "Chocolatey is installed but did not start successfully.".to_owned())
}

fn ensure_chocolatey() -> Result<bool, String> {
    if chocolatey_available().is_ok() {
        return Ok(false);
    }

    let powershell =
        trusted_windows_executable(&["System32", "WindowsPowerShell", "v1.0", "powershell.exe"])?;
    let mut command = Command::new(powershell);
    command.args([
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        CHOCOLATEY_INSTALL_SCRIPT,
    ]);
    #[cfg(windows)]
    command.creation_flags(CREATE_NO_WINDOW);

    let output = command
        .output()
        .map_err(|error| format!("Could not start the Chocolatey installer: {error}"))?;
    if !output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout).trim().to_owned();
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();
        let detail = match (stdout.is_empty(), stderr.is_empty()) {
            (false, false) => format!("{stdout}\n{stderr}"),
            (false, true) => stdout,
            (true, false) => stderr,
            (true, true) => format!("PowerShell exited with {}", output.status),
        };
        return Err(format!("Chocolatey installation failed:\n{detail}"));
    }

    chocolatey_available().map_err(|message| {
        format!("Chocolatey setup completed, but its command could not be verified: {message}")
    })?;
    Ok(true)
}

fn chocolatey_executable() -> PathBuf {
    if let Some(install_root) = std::env::var_os("ChocolateyInstall") {
        let executable = PathBuf::from(install_root).join("bin").join("choco.exe");
        if executable.is_file() {
            return executable;
        }
    }

    if let Some(program_data) = std::env::var_os("ProgramData") {
        let executable = PathBuf::from(program_data)
            .join("chocolatey")
            .join("bin")
            .join("choco.exe");
        if executable.is_file() {
            return executable;
        }
    }

    PathBuf::from("choco")
}

fn install(package: Package) -> Result<String, String> {
    if let Some(release) = package.github_release {
        return install_latest_github_msi(package.name, release);
    }
    if let Some(chocolatey_id) = package.chocolatey_id {
        let installed_now = ensure_chocolatey()?;
        let detail = install_chocolatey(package.name, chocolatey_id)?;
        return Ok(if installed_now {
            format!("Chocolatey was installed automatically.\n{detail}")
        } else {
            detail
        });
    }

    install_winget(package)
}

fn install_chocolatey(name: &str, package_id: &str) -> Result<String, String> {
    let mut command = Command::new(chocolatey_executable());
    command.args([
        "install",
        package_id,
        "--yes",
        "--no-progress",
        "--limit-output",
    ]);
    #[cfg(windows)]
    command.creation_flags(CREATE_NO_WINDOW);

    let output = command
        .output()
        .map_err(|error| format!("Could not start Chocolatey for {name}: {error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_owned();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();
    let detail = match (stdout.is_empty(), stderr.is_empty()) {
        (false, false) => format!("{stdout}\n{stderr}"),
        (false, true) => stdout,
        (true, false) => stderr,
        (true, true) => format!("Chocolatey exited with {}", output.status),
    };
    let exit_code = output.status.code();

    if output.status.success() || matches!(exit_code, Some(1641 | 3010)) {
        let mut message = detail;
        if matches!(exit_code, Some(1641 | 3010)) {
            message.push_str("\nChocolatey reports that a restart is required.");
        }
        Ok(message)
    } else {
        Err(detail)
    }
}

fn install_winget(package: Package) -> Result<String, String> {
    let mut command = Command::new("winget");
    command.args([
        "install",
        "--id",
        package.id,
        "--exact",
        "--silent",
        "--disable-interactivity",
        "--accept-package-agreements",
        "--accept-source-agreements",
    ]);
    if let Some(source) = package.source {
        command.args(["--source", source]);
    }
    #[cfg(windows)]
    command.creation_flags(CREATE_NO_WINDOW);

    let output = command.output().map_err(|error| {
        if error.kind() == std::io::ErrorKind::NotFound {
            "WinGet was not found. Install or update 'App Installer' from Microsoft Store, then try again.".to_owned()
        } else {
            format!("Could not start WinGet: {error}")
        }
    })?;

    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_owned();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();
    let detail = match (stdout.is_empty(), stderr.is_empty()) {
        (false, false) => format!("{stdout}\n{stderr}"),
        (false, true) => stdout,
        (true, false) => stderr,
        (true, true) => format!("WinGet exited with {}", output.status),
    };

    if output.status.success() {
        Ok(detail)
    } else {
        Err(detail)
    }
}

fn trusted_windows_executable(relative_path: &[&str]) -> Result<PathBuf, String> {
    let system_root = std::env::var_os("SystemRoot")
        .ok_or_else(|| "Windows did not provide the SystemRoot directory.".to_owned())?;
    let mut executable = PathBuf::from(system_root);
    for component in relative_path {
        executable.push(component);
    }

    if executable.is_file() {
        Ok(executable)
    } else {
        Err(format!(
            "Required Windows executable was not found: {}",
            executable.display()
        ))
    }
}

fn remove_temporary_file(path: &Path) {
    if path.is_file() {
        let _ = std::fs::remove_file(path);
    }
}

fn install_latest_github_msi(
    name: &str,
    release_source: GithubReleaseInstaller,
) -> Result<String, String> {
    let powershell =
        trusted_windows_executable(&["System32", "WindowsPowerShell", "v1.0", "powershell.exe"])?;
    let msiexec = trusted_windows_executable(&["System32", "msiexec.exe"])?;
    let unique = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos();
    let base_name = format!(
        "Windows-Toolbox-GitHub-{}-{}-{unique}",
        release_source.repo,
        std::process::id()
    );
    let msi_path = std::env::temp_dir().join(format!("{base_name}.msi"));
    let partial_path = std::env::temp_dir().join(format!("{base_name}.msi.partial"));

    // Values are passed through the environment so repository names and paths are never
    // interpolated into executable PowerShell code.
    const DOWNLOAD_LATEST_MSI: &str = r#"
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$headers = @{
    'User-Agent' = 'Windows-Toolbox'
    'Accept' = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}
$uri = 'https://api.github.com/repos/' + $env:GITHUB_OWNER + '/' + $env:GITHUB_REPO + '/releases?per_page=20'
$releases = Invoke-RestMethod -Uri $uri -Headers $headers -UseBasicParsing
$selectedRelease = $null
$selectedAsset = $null
foreach ($release in $releases) {
    if ($release.draft -or $release.prerelease) { continue }
    $assets = @($release.assets | Where-Object { $_.name -like $env:GITHUB_ASSET_PATTERN } | Sort-Object { $_.name.Length })
    if ($assets.Count -gt 0) {
        $selectedRelease = $release
        $selectedAsset = $assets[0]
        break
    }
}
if ($null -eq $selectedAsset) {
    throw ('No stable MSI matching ' + $env:GITHUB_ASSET_PATTERN + ' was found in the 20 most recent releases.')
}
Invoke-WebRequest -Uri $selectedAsset.browser_download_url -Headers $headers -UseBasicParsing -OutFile $env:GITHUB_PARTIAL
$download = Get-Item -LiteralPath $env:GITHUB_PARTIAL
if ($download.Length -ne [int64]$selectedAsset.size) {
    throw 'The downloaded MSI size does not match the GitHub release asset.'
}
Move-Item -LiteralPath $env:GITHUB_PARTIAL -Destination $env:GITHUB_OUTPUT -Force
Write-Output ('Release: ' + $selectedRelease.tag_name)
Write-Output ('Asset: ' + $selectedAsset.name)
"#;

    let mut download = Command::new(powershell);
    download
        .args([
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            DOWNLOAD_LATEST_MSI,
        ])
        .env("GITHUB_OWNER", release_source.owner)
        .env("GITHUB_REPO", release_source.repo)
        .env("GITHUB_ASSET_PATTERN", release_source.asset_pattern)
        .env("GITHUB_PARTIAL", &partial_path)
        .env("GITHUB_OUTPUT", &msi_path);
    #[cfg(windows)]
    download.creation_flags(CREATE_NO_WINDOW);

    let output = download
        .output()
        .map_err(|error| format!("Could not start the GitHub release download: {error}"))?;
    let download_stdout = String::from_utf8_lossy(&output.stdout).trim().to_owned();
    let download_stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();
    if !output.status.success() || !msi_path.is_file() {
        remove_temporary_file(&partial_path);
        remove_temporary_file(&msi_path);
        let detail = if download_stderr.is_empty() {
            download_stdout
        } else {
            download_stderr
        };
        return Err(if detail.is_empty() {
            format!("Could not download the latest stable MSI for {name}.")
        } else {
            format!("Could not download the latest stable MSI for {name}:\n{detail}")
        });
    }

    let mut installer = Command::new(msiexec);
    installer
        .args(["/i"])
        .arg(&msi_path)
        .args(["/qn", "/norestart"]);
    #[cfg(windows)]
    installer.creation_flags(CREATE_NO_WINDOW);
    let install_result = installer.output();
    remove_temporary_file(&partial_path);
    remove_temporary_file(&msi_path);

    let install_output = install_result.map_err(|error| {
        format!("Downloaded {name}, but could not start Windows Installer: {error}")
    })?;
    let exit_code = install_output.status.code();
    if install_output.status.success() || exit_code == Some(3010) {
        let mut detail = if download_stdout.is_empty() {
            format!("Installed the latest stable MSI for {name}.")
        } else {
            format!("{download_stdout}\nInstalled silently with Windows Installer.")
        };
        if exit_code == Some(3010) {
            detail.push_str("\nWindows Installer reports that a restart is required.");
        }
        Ok(detail)
    } else {
        let stdout = String::from_utf8_lossy(&install_output.stdout)
            .trim()
            .to_owned();
        let stderr = String::from_utf8_lossy(&install_output.stderr)
            .trim()
            .to_owned();
        let message = match (stdout.is_empty(), stderr.is_empty()) {
            (false, false) => format!("{stdout}\n{stderr}"),
            (false, true) => stdout,
            (true, false) => stderr,
            (true, true) => format!("Windows Installer exited with {}.", install_output.status),
        };
        Err(format!("Failed to install {name}:\n{message}"))
    }
}

fn vm_compatible_wgpu_options() -> eframe::egui_wgpu::WgpuConfiguration {
    use eframe::wgpu::{Backend, DeviceType, PowerPreference};

    let setup = eframe::egui_wgpu::WgpuSetupCreateNew {
        power_preference: PowerPreference::LowPower,
        native_adapter_selector: Some(std::sync::Arc::new(|adapters, surface| {
            adapters
                .iter()
                .filter(|adapter| {
                    surface.is_none_or(|surface| adapter.is_surface_supported(surface))
                })
                .min_by_key(|adapter| {
                    let info = adapter.get_info();
                    let device_rank = match info.device_type {
                        DeviceType::DiscreteGpu => 0,
                        DeviceType::IntegratedGpu => 1,
                        DeviceType::Cpu => 2,
                        DeviceType::VirtualGpu => 3,
                        DeviceType::Other => 4,
                    };
                    let backend_rank = match info.backend {
                        Backend::Dx12 => 0,
                        Backend::Vulkan => 1,
                        Backend::Gl => 2,
                        _ => 3,
                    };
                    (device_rank, backend_rank)
                })
                .cloned()
                .ok_or_else(|| {
                    "No DirectX-compatible hardware or software rendering adapter was found."
                        .to_owned()
                })
        })),
        ..Default::default()
    };

    eframe::egui_wgpu::WgpuConfiguration {
        wgpu_setup: setup.into(),
        ..Default::default()
    }
}

fn report_startup_error(error: &str) {
    let log_directory = std::env::var_os("LOCALAPPDATA")
        .map(std::path::PathBuf::from)
        .unwrap_or_else(std::env::temp_dir)
        .join("Windows Toolbox");
    let log_path = log_directory.join("startup-error.log");
    let message = format!(
        "Windows Toolbox could not start.\n\n{error}\n\nDiagnostic log: {}",
        log_path.display()
    );

    let _ = std::fs::create_dir_all(&log_directory);
    let _ = std::fs::write(&log_path, &message);
    eprintln!("{message}");

    #[cfg(windows)]
    {
        let text: Vec<u16> = message.encode_utf16().chain(std::iter::once(0)).collect();
        let caption: Vec<u16> = "Windows Toolbox"
            .encode_utf16()
            .chain(std::iter::once(0))
            .collect();
        unsafe {
            MessageBoxW(
                std::ptr::null_mut(),
                text.as_ptr(),
                caption.as_ptr(),
                0x0000_0010,
            );
        }
    }
}

#[cfg(windows)]
#[link(name = "user32")]
unsafe extern "system" {
    fn MessageBoxW(
        window: *mut std::ffi::c_void,
        text: *const u16,
        caption: *const u16,
        kind: u32,
    ) -> i32;
}

fn main() {
    std::panic::set_hook(Box::new(|panic| {
        report_startup_error(&format!("Unexpected application error: {panic}"));
    }));

    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([900.0, 760.0])
            .with_min_inner_size([680.0, 520.0]),
        renderer: eframe::Renderer::Wgpu,
        wgpu_options: vm_compatible_wgpu_options(),
        ..Default::default()
    };
    if let Err(error) = eframe::run_native(
        "Windows Toolbox",
        options,
        Box::new(|_creation_context| Ok(Box::<LauncherApp>::default())),
    ) {
        report_startup_error(&error.to_string());
    }
}

#[cfg(test)]
mod tests {
    use super::CHOCOLATEY_INSTALL_SCRIPT;

    #[test]
    fn chocolatey_bootstrap_uses_the_official_https_installer() {
        assert!(CHOCOLATEY_INSTALL_SCRIPT.contains("Set-ExecutionPolicy Bypass -Scope Process"));
        assert!(CHOCOLATEY_INSTALL_SCRIPT.contains("SecurityProtocol -bor 3072"));
        assert!(CHOCOLATEY_INSTALL_SCRIPT.contains("https://community.chocolatey.org/install.ps1"));
        assert!(!CHOCOLATEY_INSTALL_SCRIPT.contains("http://"));
    }
}
