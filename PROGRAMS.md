# Included applications

Windows Toolbox 1.0.22 includes the following 107 applications. Unless another source is shown, applications are installed using the listed WinGet package identifier.

[Return to the main README](README.md) · [Windows Tweaks](WINDOWS-TWEAKS.md) · [Config](CONFIG.md) · [Legacy Panels](LEGACY-PANELS.md)

## What the Programs tab does

The Programs tab is a curated multi-application installer. It shows each application as a checkbox, grouped by category, with the package identifier on the right. Installations run sequentially so each application receives an individual success or failure result.

### Search and selection

- Search matches application name, category, or package identifier.
- **Select visible** checks every application matching the current search.
- **Deselect visible** clears every application matching the current search.
- The selected count updates above the catalogue.
- Application selection is locked while an installation batch is running.
- **Install selected** starts the batch. Expand an item under **Installation results** to read the installer's output.

### Presets

Choosing a preset replaces the current selection with that preset's applications.

**Windows 11 basic** selects:

- Brave
- 7-Zip
- Notepad++
- VLC media player

**Gaming setup** selects:

- Brave
- Discord
- TeamSpeak 6 Client Beta
- Steam
- EA app
- 7-Zip
- Notepad++
- Ubisoft Connect
- Epic Games Launcher
- GOG Galaxy
- OBS Studio
- NVIDIA App

### Installer sources

- **WinGet:** Most applications use an exact package ID with silent, non-interactive installation and automatic package/source agreement acceptance. Windows Toolbox checks that WinGet is available before starting a batch that requires it.
- **Microsoft Store:** ChatGPT Desktop and WhatsApp use WinGet with the `msstore` source.
- **GitHub releases:** LRCGET and ArtCraft applications use the newest stable matching x64 MSI. Drafts and prereleases are skipped, the downloaded byte count is checked against GitHub's asset metadata, Windows Installer runs silently, and the temporary MSI is removed.
- **Chocolatey:** NVIDIA App uses `nvidia-app`. Windows Toolbox checks for `choco`; if missing, it runs Chocolatey's official HTTPS PowerShell bootstrap, verifies that Chocolatey is available, and then runs `choco install nvidia-app --yes --no-progress --limit-output`.

The application itself runs with Administrator rights. Internet access is required for package metadata and downloads. A package can still fail because of network access, vendor installer behaviour, an unavailable source, platform compatibility, or a pending restart.

## Application catalogue

## AI assistants

- ChatGPT Desktop — Microsoft Store (`9NT1R1C2HH7J`)
- Claude Desktop — `Anthropic.Claude`

## ArtCraft

These applications use the latest stable x64 MSI from their GitHub releases.

- PhotoCraft — `storytold/photocraft`
- VectorCraft — `storytold/vectorcraft`
- FilmCraft — `storytold/filmcraft`
- LightCraft — `storytold/lightcraft`
- PDFCraft — `storytold/pdfcraft`
- EffectCraft — `storytold/effectcraft`
- DesignCraft — `storytold/designcraft`
- WordCraft — `storytold/wordcraft`
- DeckCraft — `storytold/deckcraft`
- GridCraft — `storytold/gridcraft`
- CADCraft — `storytold/cadcraft`
- SoundCraft — `storytold/soundcraft`
- Craft Launcher — `storytold/craft-launcher`
- FigCraft — `storytold/figcraft`

## Benchmarking

- Cinebench R23 — `Maxon.CinebenchR23`
- CrystalDiskMark — `CrystalDewWorld.CrystalDiskMark`
- Geekbench 5 — `PrimateLabs.Geekbench.5`

## Browsers

- Brave — `Brave.Brave`
- Google Chrome — `Google.Chrome`
- Microsoft Edge — `Microsoft.Edge`
- Mozilla Firefox — `Mozilla.Firefox`
- Tor Browser — `TorProject.TorBrowser`
- Zen Browser — `Zen-Team.Zen-Browser`

## Cloud collaboration

- Git — `Git.Git`
- GitHub Desktop — `GitHub.GitHubDesktop`

## Cloud storage

- Dropbox — `Dropbox.Dropbox`
- Google Drive — `Google.Drive`

## Communication

- Telegram Desktop — `Telegram.TelegramDesktop`
- Discord — `Discord.Discord`
- SimpleX Chat — `SimpleX.SimpleX-Chat`
- TeamSpeak 3 Client — `TeamSpeakSystems.TeamSpeakClient`
- TeamSpeak 6 Client Beta — `TeamSpeakSystems.TeamSpeakClient.Beta.6`
- WhatsApp — Microsoft Store (`9NKSQGP7F2NH`)

## Computer info

- CrystalDiskInfo — `CrystalDewWorld.CrystalDiskInfo`
- GlassWire — `GlassWire.GlassWire`

## Development

- Visual Studio Code — `Microsoft.VisualStudioCode`

## Distributed computing

- Folding@home — `FoldingAtHome.FoldingAtHome`

## DNS

- No-IP DUC — `NoIP.DUC`

## File sharing

- Syncthing — `Syncthing.Syncthing`
- Prowlarr — `TeamProwlarr.Prowlarr`
- qBittorrent — `qBittorrent.qBittorrent`
- Radarr — `TeamRadarr.Radarr`
- Sonarr — `TeamSonarr.Sonarr`

## Game launchers

- Battle.net — `Blizzard.BattleNet`
- EA app — `ElectronicArts.EADesktop`
- Epic Games Launcher — `EpicGames.EpicGamesLauncher`
- GOG Galaxy — `GOG.Galaxy`
- NVIDIA App — Chocolatey (`nvidia-app`); Chocolatey is installed automatically when required
- NVIDIA GeForce NOW — `Nvidia.GeForceNow`
- Steam — `Valve.Steam`
- Ubisoft Connect — `Ubisoft.Connect`

## Media

- Plex — `Plex.Plex`
- Plex Media Server — `Plex.PlexMediaServer`
- Plexamp — `Plex.Plexamp`
- LRCGET — latest stable x64 MSI from `tranxuanthang/lrcget` GitHub releases
- Spotify — `Spotify.Spotify`
- VLC media player — `VideoLAN.VLC`

## Office

- Adobe Acrobat Reader — `Adobe.Acrobat.Reader.64-bit`
- LibreOffice — `TheDocumentFoundation.LibreOffice`
- Joplin — `Joplin.Joplin`
- Microsoft Teams — `Microsoft.Teams`
- Mozilla Thunderbird — `Mozilla.Thunderbird`
- Notepad++ — `Notepad++.Notepad++`

## Peripherals

- CORSAIR iCUE 4 — `Corsair.iCUE.4`
- Logitech Gaming Software — `Logitech.LGS`

## Recording and streaming

- OBS Studio — `OBSProject.OBSStudio`
- Parsec — `Parsec.Parsec`

## Security

- Cryptomator — `Cryptomator.Cryptomator`
- VeraCrypt — `IDRIX.VeraCrypt`
- KeePass — `DominikReichl.KeePass`
- KeePassXC — `KeePassXCTeam.KeePassXC`
- KeeWeb — `KeeWeb.KeeWeb`
- Gpg4win — `GnuPG.Gpg4win`
- IVPN — `IVPN.IVPN`
- Mullvad VPN — `MullvadVPN.MullvadVPN`
- NordVPN — `NordVPN.NordVPN`
- OpenVPN — `OpenVPNTechnologies.OpenVPN`
- Private Internet Access — `PrivateInternetAccess.PrivateInternetAccess`
- Proton VPN — `Proton.ProtonVPN`
- Surfshark — `Surfshark.Surfshark`
- Twingate — `Twingate.Client`
- WireGuard — `WireGuard.WireGuard`
- Yubico Authenticator — `Yubico.Authenticator`
- YubiKey Manager — `Yubico.YubikeyManager`

## Utilities

- 7-Zip — `7zip.7zip`
- AutoHotkey — `AutoHotkey.AutoHotkey`
- Bulk Rename Utility — `TGRMNSoftware.BulkRenameUtility`
- CPUID HWMonitor — `CPUID.HWMonitor`
- DB Browser for SQLite — `DBBrowserForSQLite.DBBrowserForSQLite`
- File Converter — `AdrienAllard.FileConverter`
- HandBrake — `HandBrake.HandBrake`
- MakeMKV — `GuinpinSoft.MakeMKV`
- Autoruns — `Microsoft.Sysinternals.Autoruns`
- Process Explorer — `Microsoft.Sysinternals.ProcessExplorer`
- Process Monitor — `Microsoft.Sysinternals.ProcessMonitor`
- Mp3tag — `Mp3tag.Mp3tag`
- MusicBrainz Picard — `MusicBrainz.Picard`
- NTLite — `Nlitesoft.NTLite`
- RustDesk — `RustDesk.RustDesk`
- ShareX — `ShareX.ShareX`
- WinDirStat — `WinDirStat.WinDirStat`
- WizTree — `AntibodySoftware.WizTree`
- UniGetUI — `MartiCliment.UniGetUI`

## Virtualization

- Docker Desktop — `Docker.DockerDesktop`
- VMware Horizon Client — `VMware.HorizonClient`
