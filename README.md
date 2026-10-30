# Windows Toolbox

A native Windows desktop toolbox for installing curated programs and managing useful Windows settings. The application is written in Rust and distributed as a 64-bit MSI.

## Included applications

Windows Toolbox currently includes 108 applications across 20 categories. [View the complete application catalogue](PROGRAMS.md) for names, categories, package identifiers, and installation sources.

## Tab guides

- [Programs](PROGRAMS.md) — searching, selecting, presets, installer sources, automatic Chocolatey setup, and the complete application catalogue.
- [Windows Tweaks](WINDOWS-TWEAKS.md) — appearance, Explorer preferences, Game Mode, mouse acceleration, display refresh rates, Jumbo Frames, and PowerShell execution policy.
- [Config](CONFIG.md) — Windows optional features, feature-state detection, NFS configuration, WSL, Hyper-V, Sandbox, .NET Framework, and Autologon.
- [Legacy Panels](LEGACY-PANELS.md) — every classic Windows panel that can be opened and the built-in Windows command used for it.

## Requirements

- Windows 10 or Windows 11, 64-bit
- [App Installer](https://apps.microsoft.com/detail/9nblggh4nns1), which provides `winget`
- Internet access while installing selected programs

## Install and open

Run `target/wix/Windows-Toolbox-1.0.28-x64.msi`. During setup, the installer displays a checked-by-default **Create a desktop shortcut** checkbox; clear it if you do not want the desktop shortcut. The installer always creates `Windows Toolbox.lnk` in the all-users Start-menu Programs folder. Windows displays a UAC prompt whenever the application launches because its embedded manifest requires Administrator privileges.

The application uses DirectX 12 and can fall back to a software adapter on virtual machines. If graphics initialization still fails, it displays an error and writes a diagnostic file to:

```text
%LOCALAPPDATA%\Windows Toolbox\startup-error.log
```

The running application version is always shown at the bottom right. A clickable **GitHub** icon beside **Check for updates** opens the Windows Toolbox repository in the default browser. On startup, Windows Toolbox checks the latest stable GitHub release in `dylan0760/Windows-Winget`. It reads the semantic version from an asset named `Windows-Toolbox-X.Y.Z-x64.msi`, which supports the repository's `Latest` release tag. If the asset is newer, the **Install update** button downloads the official release MSI inside the app, checks its reported byte size and MSI header, closes Windows Toolbox, and opens Windows Installer. The updater waits for Windows Installer to finish before removing the temporary MSI, and retains a verbose `.log` beside it if installation fails. The footer also provides a manual update check.

## Add or change programs

Edit `src/catalog.rs`. Each normal entry contains the display name, exact WinGet package ID, and category:

```rust
package!("Spotify", "Spotify.Spotify", "Media"),
```

The launcher runs the equivalent of:

```powershell
winget install --id Spotify.Spotify --exact --silent --disable-interactivity --accept-package-agreements --accept-source-agreements
```

Store packages can specify `source: Some("msstore")`; see the WhatsApp entry for an example. Run the tests after modifying the catalogue because they check for duplicate package IDs and invalid preset references.

The **AI assistants** category includes ChatGPT Desktop from Microsoft Store and Claude Desktop from the WinGet community source.

The **Office** category includes Joplin using the `Joplin.Joplin` WinGet package.

The **Game launchers** category includes NVIDIA App using Chocolatey's `nvidia-app` package, and the Gaming setup preset selects it automatically. Before running `choco install nvidia-app`, Windows Toolbox detects whether Chocolatey is available. When it is missing, the application runs Chocolatey's official PowerShell bootstrap command, verifies that `choco` is now available, and then continues. Existing Chocolatey installations are left unchanged.

The **Media** category includes LRCGET. It checks the official `tranxuanthang/lrcget` GitHub releases at install time, skips drafts and prereleases, downloads the latest `*_x64_en-US.msi`, verifies its byte size against GitHub's metadata, installs it silently, and removes the temporary MSI. This entry does not require WinGet.

The **ArtCraft** category contains the 14 `storytold` repositories listed in the supplied `Get-ArtCraftMSIs.ps1` reference script plus SolidCraft from `tangency-labs/solidcraft`. For each selected entry, the launcher checks the 20 most recent GitHub releases, skips drafts and prereleases, downloads the newest matching x64 MSI, verifies its byte size against GitHub's metadata, installs it silently with Windows Installer, and deletes the temporary MSI. SolidCraft specifically selects the versioned `solidcraft-*-windows-x64.msi` asset. These entries do not require WinGet. GitHub API rate limits still apply.

## Build

Install a stable 64-bit Rust toolchain and WiX Toolset 3.x. The repository's build script can use the bundled WiX binaries in `build-tools/wix314`:

```powershell
cargo test --all-targets
cargo build --release
.\scripts\build-msi.ps1 -SkipBuild -WixBin .\build-tools\wix314
```

The MSI embeds `assets/app.ico` in the executable, Programs and Features entry, Start-menu shortcut, and optional desktop shortcut. Generated Rust and WiX intermediates under `target` are disposable; only the finished executable and MSI are retained in the shared project folder.

## License

Windows Toolbox is source available rather than open source. Official unmodified binary releases are free to install and use for personal or internal business purposes, but the source code may not be copied, redistributed, incorporated into another project, or used to create modified forks or derivative versions without prior written permission. See [LICENSE](LICENSE) for the complete terms.

Copies and versions previously distributed under the MIT License retain the permissions already granted to their recipients; the current license cannot retroactively withdraw those rights.
