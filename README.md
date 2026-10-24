# Windows Toolbox

A native Windows desktop toolbox for installing curated programs and managing useful Windows settings. The application is written in Rust and distributed as a 64-bit MSI.

## Included applications

Windows Toolbox currently includes 107 applications across 20 categories. [View the complete application catalogue](PROGRAMS.md) for names, categories, package identifiers, and installation sources.

## Requirements

- Windows 10 or Windows 11, 64-bit
- [App Installer](https://apps.microsoft.com/detail/9nblggh4nns1), which provides `winget`
- Internet access while installing selected programs

## Install and open

Run `target/wix/Windows-Toolbox-1.0.22-x64.msi`, then open **Windows Toolbox** from the Windows Start menu. Windows displays a UAC prompt whenever the application launches because its embedded manifest requires Administrator privileges.

The application uses DirectX 12 and can fall back to a software adapter on virtual machines. If graphics initialization still fails, it displays an error and writes a diagnostic file to:

```text
%LOCALAPPDATA%\Windows Toolbox\startup-error.log
```

The running application version is always shown at the bottom right. On startup, Windows Toolbox checks the latest stable GitHub release in `dylan0760/Windows-Winget`. It reads the semantic version from an asset named `Windows-Toolbox-X.Y.Z-x64.msi`, which supports the repository's `Latest` release tag. If the asset is newer, an update banner offers a direct download from that repository's GitHub Releases URL. The footer also provides a manual update check.

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

The **ArtCraft** category contains the 14 `storytold` repositories listed in the supplied `Get-ArtCraftMSIs.ps1` reference script. For each selected entry, the launcher checks the 20 most recent GitHub releases, skips drafts and prereleases, downloads the newest release asset matching `*x64*.msi`, verifies its byte size against GitHub's metadata, installs it silently with Windows Installer, and deletes the temporary MSI. These entries do not require WinGet. GitHub API rate limits still apply.

## Windows Tweaks

The **Windows Tweaks** tab can switch between dark and light mode, show or hide File Explorer file extensions and hidden files, toggle Windows Game Mode and mouse acceleration, select the highest supported refresh rate at each monitor's current resolution, configure a selected network adapter's Jumbo Packet value, and inspect or change the 64-bit Windows PowerShell execution policy. The four new preference toggles read their current states when the tab opens. Jumbo Frames use the supplied script's 9014-byte setting and include a 1514-byte recovery option. The PowerShell section requires explicit confirmation before setting `LocalMachine` to `Unrestricted`, with `Restricted` as the locked-down toggle and `RemoteSigned` as a middle-ground option. After a change, Windows Toolbox verifies the stored `LocalMachine` value and reports any higher-priority `MachinePolicy`, `UserPolicy`, `Process`, or `CurrentUser` scope that keeps a different policy effective. Group Policy scopes are reported but are never bypassed. Run the application as Administrator for machine-wide changes.

## Config

The **Config** tab reproduces the requested WinUtil feature mappings locally without downloading or executing WinUtil. It can enable .NET Framework (`NetFx4-AdvSrvs`, `NetFx3`), Hyper-V, the NFS client and WinUtil NFS defaults, Windows Sandbox, and the two WSL platform components. When the tab opens, Windows Toolbox reads the optional-feature states and automatically checks groups whose complete component set is enabled or pending enablement; partially enabled and unavailable groups remain unchecked. A manual refresh button reads the states again. Windows edition requirements still apply, and a restart may be required. The Autologin action downloads Microsoft Sysinternals Autologon from `live.sysinternals.com`, requires a valid Microsoft Authenticode signature, launches its configuration dialog, and deletes the temporary executable afterward.

## Legacy Windows Panels

The **Legacy Panels** tab directly opens Control Panel, Network Connections, Power Options, Region, Sound, Devices and Printers, System Properties, and User Accounts. These actions use Windows' built-in system executables and do not require the supplied PowerShell launcher scripts.

## Build

Install a stable 64-bit Rust toolchain and WiX Toolset 3.x. The repository's build script can use the bundled WiX binaries in `build-tools/wix314`:

```powershell
cargo test --all-targets
cargo build --release
.\scripts\build-msi.ps1 -SkipBuild -WixBin .\build-tools\wix314
```

The MSI embeds `assets/app.ico` in the executable, Programs and Features entry, and Start-menu shortcut. Generated Rust and WiX intermediates under `target` are disposable; only the finished executable and MSI are retained in the shared project folder.
