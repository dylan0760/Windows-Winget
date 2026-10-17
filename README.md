# Windows WinGet Installer

A native Windows desktop application for installing a curated set of programs with WinGet. The launcher is written in Rust and distributed as a 64-bit MSI; PowerShell and execution-policy changes are not required.

## Requirements

- Windows 10 or Windows 11, 64-bit
- [App Installer](https://apps.microsoft.com/detail/9nblggh4nns1), which provides `winget`
- Internet access while installing selected programs

## Install and open

Run `target/wix/Windows-WinGet-Installer-1.0.13-x64.msi`, then open **Windows WinGet Installer** from the Windows Start menu. Windows displays a UAC prompt whenever the application launches because its embedded manifest requires Administrator privileges.

The application uses DirectX 12 and can fall back to a software adapter on virtual machines. If graphics initialization still fails, it displays an error and writes a diagnostic file to:

```text
%LOCALAPPDATA%\Windows WinGet Installer\startup-error.log
```

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

The **ArtCraft** category contains the 14 `storytold` repositories listed in the supplied `Get-ArtCraftMSIs.ps1` reference script. For each selected entry, the launcher checks the 20 most recent GitHub releases, skips drafts and prereleases, downloads the newest release asset matching `*x64*.msi`, verifies its byte size against GitHub's metadata, installs it silently with Windows Installer, and deletes the temporary MSI. These entries do not require WinGet. GitHub API rate limits still apply.

## Windows Tweaks

The **Windows Tweaks** tab can switch between dark and light mode, show or hide File Explorer file extensions and hidden files, toggle Windows Game Mode and mouse acceleration, select the highest supported refresh rate at each monitor's current resolution, configure a selected network adapter's Jumbo Packet value, and inspect or change the 64-bit Windows PowerShell execution policy. The four new preference toggles read their current states when the tab opens. Jumbo Frames use the supplied script's 9014-byte setting and include a 1514-byte recovery option. The PowerShell section requires explicit confirmation before setting `LocalMachine` to `Unrestricted`, with `Restricted` as the locked-down toggle and `RemoteSigned` as a middle-ground option. Run the application as Administrator for machine-wide changes.

## Windows Activation link

The **Windows Activation** tab opens the configured Gitea repository in the default browser. It does not download or execute remote PowerShell content.

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
