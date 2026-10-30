#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct GithubReleaseInstaller {
    pub owner: &'static str,
    pub repo: &'static str,
    pub asset_pattern: &'static str,
}

#[derive(Clone, Copy, Debug)]
pub struct Package {
    pub name: &'static str,
    pub id: &'static str,
    pub category: &'static str,
    pub source: Option<&'static str>,
    pub github_release: Option<GithubReleaseInstaller>,
    pub chocolatey_id: Option<&'static str>,
}

macro_rules! package {
    ($name:literal, $id:literal, $category:literal) => {
        Package {
            name: $name,
            id: $id,
            category: $category,
            source: None,
            github_release: None,
            chocolatey_id: None,
        }
    };
}

macro_rules! github_msi_package {
    ($name:literal, $id:expr, $category:literal, $owner:literal, $repo:literal, $asset_pattern:literal) => {
        Package {
            name: $name,
            id: $id,
            category: $category,
            source: None,
            github_release: Some(GithubReleaseInstaller {
                owner: $owner,
                repo: $repo,
                asset_pattern: $asset_pattern,
            }),
            chocolatey_id: None,
        }
    };
}

macro_rules! chocolatey_package {
    ($name:literal, $id:literal, $category:literal) => {
        Package {
            name: $name,
            id: concat!("choco:", $id),
            category: $category,
            source: None,
            github_release: None,
            chocolatey_id: Some($id),
        }
    };
}

macro_rules! artcraft_package {
    ($name:literal, $repo:literal) => {
        github_msi_package!(
            $name,
            concat!("storytold/", $repo),
            "ArtCraft",
            "storytold",
            $repo,
            "*x64*.msi"
        )
    };
}

pub const PACKAGES: &[Package] = &[
    Package {
        name: "ChatGPT Desktop",
        id: "9NT1R1C2HH7J",
        category: "AI assistants",
        source: Some("msstore"),
        github_release: None,
        chocolatey_id: None,
    },
    package!("Claude Desktop", "Anthropic.Claude", "AI assistants"),
    artcraft_package!("PhotoCraft", "photocraft"),
    artcraft_package!("VectorCraft", "vectorcraft"),
    artcraft_package!("FilmCraft", "filmcraft"),
    artcraft_package!("LightCraft", "lightcraft"),
    artcraft_package!("PDFCraft", "pdfcraft"),
    artcraft_package!("EffectCraft", "effectcraft"),
    artcraft_package!("DesignCraft", "designcraft"),
    artcraft_package!("WordCraft", "wordcraft"),
    artcraft_package!("DeckCraft", "deckcraft"),
    artcraft_package!("GridCraft", "gridcraft"),
    artcraft_package!("CADCraft", "cadcraft"),
    artcraft_package!("SoundCraft", "soundcraft"),
    github_msi_package!(
        "SolidCraft",
        "tangency-labs/solidcraft",
        "ArtCraft",
        "tangency-labs",
        "solidcraft",
        "solidcraft-*-windows-x64.msi"
    ),
    artcraft_package!("Craft Launcher", "craft-launcher"),
    artcraft_package!("FigCraft", "figcraft"),
    package!("Cinebench R23", "Maxon.CinebenchR23", "Benchmarking"),
    package!(
        "CrystalDiskMark",
        "CrystalDewWorld.CrystalDiskMark",
        "Benchmarking"
    ),
    package!("Geekbench 5", "PrimateLabs.Geekbench.5", "Benchmarking"),
    package!("Brave", "Brave.Brave", "Browsers"),
    package!("Google Chrome", "Google.Chrome", "Browsers"),
    package!("Microsoft Edge", "Microsoft.Edge", "Browsers"),
    package!("Mozilla Firefox", "Mozilla.Firefox", "Browsers"),
    package!("Tor Browser", "TorProject.TorBrowser", "Browsers"),
    package!("Zen Browser", "Zen-Team.Zen-Browser", "Browsers"),
    package!("Git", "Git.Git", "Cloud collaboration"),
    package!(
        "GitHub Desktop",
        "GitHub.GitHubDesktop",
        "Cloud collaboration"
    ),
    package!("Dropbox", "Dropbox.Dropbox", "Cloud storage"),
    package!("Google Drive", "Google.Drive", "Cloud storage"),
    package!(
        "Telegram Desktop",
        "Telegram.TelegramDesktop",
        "Communication"
    ),
    package!("Discord", "Discord.Discord", "Communication"),
    package!("SimpleX Chat", "SimpleX.SimpleX-Chat", "Communication"),
    package!(
        "TeamSpeak 3 Client",
        "TeamSpeakSystems.TeamSpeakClient",
        "Communication"
    ),
    package!(
        "TeamSpeak 6 Client Beta",
        "TeamSpeakSystems.TeamSpeakClient.Beta.6",
        "Communication"
    ),
    Package {
        name: "WhatsApp",
        id: "9NKSQGP7F2NH",
        category: "Communication",
        source: Some("msstore"),
        github_release: None,
        chocolatey_id: None,
    },
    package!(
        "CrystalDiskInfo",
        "CrystalDewWorld.CrystalDiskInfo",
        "Computer info"
    ),
    package!("GlassWire", "GlassWire.GlassWire", "Computer info"),
    package!(
        "Visual Studio Code",
        "Microsoft.VisualStudioCode",
        "Development"
    ),
    package!(
        "Folding@home",
        "FoldingAtHome.FoldingAtHome",
        "Distributed computing"
    ),
    package!("No-IP DUC", "NoIP.DUC", "DNS"),
    package!("Syncthing", "Syncthing.Syncthing", "File sharing"),
    package!("Prowlarr", "TeamProwlarr.Prowlarr", "File sharing"),
    package!("qBittorrent", "qBittorrent.qBittorrent", "File sharing"),
    package!("Radarr", "TeamRadarr.Radarr", "File sharing"),
    package!("Sonarr", "TeamSonarr.Sonarr", "File sharing"),
    package!("Battle.net", "Blizzard.BattleNet", "Game launchers"),
    package!("EA app", "ElectronicArts.EADesktop", "Game launchers"),
    package!(
        "Epic Games Launcher",
        "EpicGames.EpicGamesLauncher",
        "Game launchers"
    ),
    package!("GOG Galaxy", "GOG.Galaxy", "Game launchers"),
    chocolatey_package!("NVIDIA App", "nvidia-app", "Game launchers"),
    package!("NVIDIA GeForce NOW", "Nvidia.GeForceNow", "Game launchers"),
    package!("Steam", "Valve.Steam", "Game launchers"),
    package!("Ubisoft Connect", "Ubisoft.Connect", "Game launchers"),
    package!("Plex", "Plex.Plex", "Media"),
    package!("Plex Media Server", "Plex.PlexMediaServer", "Media"),
    package!("Plexamp", "Plex.Plexamp", "Media"),
    github_msi_package!(
        "LRCGET",
        "tranxuanthang/lrcget",
        "Media",
        "tranxuanthang",
        "lrcget",
        "*_x64_en-US.msi"
    ),
    package!("Spotify", "Spotify.Spotify", "Media"),
    package!("VLC media player", "VideoLAN.VLC", "Media"),
    package!(
        "Adobe Acrobat Reader",
        "Adobe.Acrobat.Reader.64-bit",
        "Office"
    ),
    package!("LibreOffice", "TheDocumentFoundation.LibreOffice", "Office"),
    package!("Joplin", "Joplin.Joplin", "Office"),
    package!("Microsoft Teams", "Microsoft.Teams", "Office"),
    package!("Mozilla Thunderbird", "Mozilla.Thunderbird", "Office"),
    package!("Notepad++", "Notepad++.Notepad++", "Office"),
    package!("CORSAIR iCUE 4", "Corsair.iCUE.4", "Peripherals"),
    package!("Logitech Gaming Software", "Logitech.LGS", "Peripherals"),
    package!(
        "OBS Studio",
        "OBSProject.OBSStudio",
        "Recording and streaming"
    ),
    package!("Parsec", "Parsec.Parsec", "Recording and streaming"),
    package!("Cryptomator", "Cryptomator.Cryptomator", "Security"),
    package!("VeraCrypt", "IDRIX.VeraCrypt", "Security"),
    package!("KeePass", "DominikReichl.KeePass", "Security"),
    package!("KeePassXC", "KeePassXCTeam.KeePassXC", "Security"),
    package!("KeeWeb", "KeeWeb.KeeWeb", "Security"),
    package!("Gpg4win", "GnuPG.Gpg4win", "Security"),
    package!("IVPN", "IVPN.IVPN", "Security"),
    package!("Mullvad VPN", "MullvadVPN.MullvadVPN", "Security"),
    package!("NordVPN", "NordVPN.NordVPN", "Security"),
    package!("OpenVPN", "OpenVPNTechnologies.OpenVPN", "Security"),
    package!(
        "Private Internet Access",
        "PrivateInternetAccess.PrivateInternetAccess",
        "Security"
    ),
    package!("Proton VPN", "Proton.ProtonVPN", "Security"),
    package!("Surfshark", "Surfshark.Surfshark", "Security"),
    package!("Twingate", "Twingate.Client", "Security"),
    package!("WireGuard", "WireGuard.WireGuard", "Security"),
    package!("Yubico Authenticator", "Yubico.Authenticator", "Security"),
    package!("YubiKey Manager", "Yubico.YubikeyManager", "Security"),
    package!("7-Zip", "7zip.7zip", "Utilities"),
    package!("AutoHotkey", "AutoHotkey.AutoHotkey", "Utilities"),
    package!(
        "Bulk Rename Utility",
        "TGRMNSoftware.BulkRenameUtility",
        "Utilities"
    ),
    package!("CPUID HWMonitor", "CPUID.HWMonitor", "Utilities"),
    package!(
        "DB Browser for SQLite",
        "DBBrowserForSQLite.DBBrowserForSQLite",
        "Utilities"
    ),
    package!("File Converter", "AdrienAllard.FileConverter", "Utilities"),
    package!("HandBrake", "HandBrake.HandBrake", "Utilities"),
    package!("MakeMKV", "GuinpinSoft.MakeMKV", "Utilities"),
    package!("Autoruns", "Microsoft.Sysinternals.Autoruns", "Utilities"),
    package!(
        "Process Explorer",
        "Microsoft.Sysinternals.ProcessExplorer",
        "Utilities"
    ),
    package!(
        "Process Monitor",
        "Microsoft.Sysinternals.ProcessMonitor",
        "Utilities"
    ),
    package!("Mp3tag", "Mp3tag.Mp3tag", "Utilities"),
    package!("MusicBrainz Picard", "MusicBrainz.Picard", "Utilities"),
    package!("NTLite", "Nlitesoft.NTLite", "Utilities"),
    package!("RustDesk", "RustDesk.RustDesk", "Utilities"),
    package!("ShareX", "ShareX.ShareX", "Utilities"),
    package!("WinDirStat", "WinDirStat.WinDirStat", "Utilities"),
    package!("WizTree", "AntibodySoftware.WizTree", "Utilities"),
    package!("Docker Desktop", "Docker.DockerDesktop", "Virtualization"),
    package!(
        "VMware Horizon Client",
        "VMware.HorizonClient",
        "Virtualization"
    ),
    package!("UniGetUI", "MartiCliment.UniGetUI", "Utilities"),
];

pub const BASIC_PRESET: &[&str] = &[
    "Brave.Brave",
    "7zip.7zip",
    "Notepad++.Notepad++",
    "VideoLAN.VLC",
];

pub const GAMING_PRESET: &[&str] = &[
    "Brave.Brave",
    "Discord.Discord",
    "TeamSpeakSystems.TeamSpeakClient.Beta.6",
    "Valve.Steam",
    "ElectronicArts.EADesktop",
    "7zip.7zip",
    "Notepad++.Notepad++",
    "Ubisoft.Connect",
    "EpicGames.EpicGamesLauncher",
    "GOG.Galaxy",
    "OBSProject.OBSStudio",
    "choco:nvidia-app",
];

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    #[test]
    fn package_ids_are_unique_and_nonempty() {
        let mut ids = HashSet::new();
        for package in PACKAGES {
            assert!(!package.name.is_empty());
            assert!(!package.id.is_empty());
            assert!(
                ids.insert(package.id.to_ascii_lowercase()),
                "duplicate {}",
                package.id
            );
        }
    }

    #[test]
    fn presets_reference_catalog_entries() {
        for id in BASIC_PRESET.iter().chain(GAMING_PRESET) {
            assert!(
                PACKAGES.iter().any(|package| package.id == *id),
                "missing {id}"
            );
        }
    }

    #[test]
    fn ai_desktop_packages_use_expected_winget_sources() {
        let chatgpt = PACKAGES
            .iter()
            .find(|package| package.name == "ChatGPT Desktop")
            .expect("ChatGPT Desktop is missing");
        assert_eq!(chatgpt.id, "9NT1R1C2HH7J");
        assert_eq!(chatgpt.source, Some("msstore"));

        let claude = PACKAGES
            .iter()
            .find(|package| package.name == "Claude Desktop")
            .expect("Claude Desktop is missing");
        assert_eq!(claude.id, "Anthropic.Claude");
        assert_eq!(claude.source, None);
    }

    #[test]
    fn joplin_uses_the_expected_winget_package() {
        let joplin = PACKAGES
            .iter()
            .find(|package| package.name == "Joplin")
            .expect("Joplin is missing");
        assert_eq!(joplin.id, "Joplin.Joplin");
        assert_eq!(joplin.source, None);
    }

    #[test]
    fn nvidia_app_uses_chocolatey_and_is_in_the_gaming_preset() {
        let nvidia = PACKAGES
            .iter()
            .find(|package| package.name == "NVIDIA App")
            .expect("NVIDIA App is missing");

        assert_eq!(nvidia.id, "choco:nvidia-app");
        assert_eq!(nvidia.category, "Game launchers");
        assert_eq!(nvidia.source, None);
        assert_eq!(nvidia.github_release, None);
        assert_eq!(nvidia.chocolatey_id, Some("nvidia-app"));
        assert!(GAMING_PRESET.contains(&nvidia.id));

        assert!(!PACKAGES
            .iter()
            .any(|package| package.id == "Chocolatey.Chocolatey"));
    }

    #[test]
    fn artcraft_catalog_matches_the_supplied_script() {
        let repos: Vec<_> = PACKAGES
            .iter()
            .filter_map(|package| {
                package
                    .github_release
                    .filter(|release| release.owner == "storytold")
                    .map(|release| release.repo)
            })
            .collect();

        assert_eq!(
            repos,
            [
                "photocraft",
                "vectorcraft",
                "filmcraft",
                "lightcraft",
                "pdfcraft",
                "effectcraft",
                "designcraft",
                "wordcraft",
                "deckcraft",
                "gridcraft",
                "cadcraft",
                "soundcraft",
                "craft-launcher",
                "figcraft",
            ]
        );
        assert!(PACKAGES
            .iter()
            .filter(|package| {
                package
                    .github_release
                    .is_some_and(|release| release.owner == "storytold")
            })
            .all(|package| package.category == "ArtCraft" && package.source.is_none()));
    }

    #[test]
    fn solidcraft_uses_the_latest_stable_windows_x64_msi() {
        let solidcraft = PACKAGES
            .iter()
            .find(|package| package.name == "SolidCraft")
            .expect("SolidCraft is missing");

        assert_eq!(solidcraft.id, "tangency-labs/solidcraft");
        assert_eq!(solidcraft.category, "ArtCraft");
        assert_eq!(solidcraft.source, None);
        assert_eq!(
            solidcraft.github_release,
            Some(GithubReleaseInstaller {
                owner: "tangency-labs",
                repo: "solidcraft",
                asset_pattern: "solidcraft-*-windows-x64.msi",
            })
        );
    }

    #[test]
    fn lrcget_uses_the_latest_stable_github_msi() {
        let lrcget = PACKAGES
            .iter()
            .find(|package| package.name == "LRCGET")
            .expect("LRCGET is missing");

        assert_eq!(lrcget.id, "tranxuanthang/lrcget");
        assert_eq!(lrcget.category, "Media");
        assert_eq!(lrcget.source, None);
        assert_eq!(
            lrcget.github_release,
            Some(GithubReleaseInstaller {
                owner: "tranxuanthang",
                repo: "lrcget",
                asset_pattern: "*_x64_en-US.msi",
            })
        );
    }
}
