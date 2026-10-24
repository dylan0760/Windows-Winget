use std::process::Command;

#[cfg(windows)]
use std::os::windows::process::CommandExt;

#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x0800_0000;

pub const CURRENT_VERSION: &str = env!("CARGO_PKG_VERSION");
const DOWNLOAD_PREFIX: &str = "https://github.com/dylan0760/Windows-Winget/releases/download/";
const RELEASE_PREFIX: &str = "https://github.com/dylan0760/Windows-Winget/releases/";

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct UpdateInfo {
    pub version: String,
    pub asset_name: String,
    pub download_url: String,
    pub release_url: String,
}

pub fn check_for_update() -> Result<Option<UpdateInfo>, String> {
    let output = run_windows_powershell(CHECK_UPDATE_SCRIPT)?;
    parse_update_response(&output, CURRENT_VERSION)
}

pub fn open_update_download(update: &UpdateInfo) -> Result<String, String> {
    validate_update(update)?;

    #[cfg(windows)]
    {
        use windows_sys::Win32::UI::Shell::ShellExecuteW;

        let operation: Vec<u16> = "open".encode_utf16().chain(std::iter::once(0)).collect();
        let target: Vec<u16> = update
            .download_url
            .encode_utf16()
            .chain(std::iter::once(0))
            .collect();
        let result = unsafe {
            ShellExecuteW(
                std::ptr::null_mut(),
                operation.as_ptr(),
                target.as_ptr(),
                std::ptr::null(),
                std::ptr::null(),
                1,
            )
        } as isize;
        if result <= 32 {
            return Err(format!(
                "Windows could not open the update download (ShellExecute code {result})."
            ));
        }
        Ok(format!(
            "Opened the Windows Toolbox {} MSI download in the default browser.",
            update.version
        ))
    }

    #[cfg(not(windows))]
    {
        let _ = update;
        Err("Update downloads are only supported on Windows.".to_owned())
    }
}

fn parse_update_response(
    output: &str,
    current_version: &str,
) -> Result<Option<UpdateInfo>, String> {
    if output
        .lines()
        .any(|line| line.trim() == "NO_COMPATIBLE_ASSET")
    {
        return Ok(None);
    }

    let value = |prefix: &str| {
        output.lines().find_map(|line| {
            line.trim()
                .strip_prefix(prefix)
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(str::to_owned)
        })
    };
    let update = UpdateInfo {
        version: value("VERSION\t")
            .ok_or_else(|| "GitHub did not return a readable release version.".to_owned())?,
        asset_name: value("ASSET_NAME\t")
            .ok_or_else(|| "GitHub did not return a readable MSI asset name.".to_owned())?,
        download_url: value("DOWNLOAD_URL\t")
            .ok_or_else(|| "GitHub did not return a readable MSI download URL.".to_owned())?,
        release_url: value("RELEASE_URL\t")
            .ok_or_else(|| "GitHub did not return a readable release URL.".to_owned())?,
    };
    validate_update(&update)?;

    let current = parse_version(current_version)
        .ok_or_else(|| format!("The running version is invalid: {current_version}"))?;
    let latest = parse_version(&update.version)
        .ok_or_else(|| format!("GitHub returned an invalid version: {}", update.version))?;
    Ok((latest > current).then_some(update))
}

fn validate_update(update: &UpdateInfo) -> Result<(), String> {
    let expected_name = format!("Windows-Toolbox-{}-x64.msi", update.version);
    if update.asset_name != expected_name {
        return Err("GitHub returned an unexpected Windows Toolbox asset name.".to_owned());
    }
    if !update.download_url.starts_with(DOWNLOAD_PREFIX)
        || !update.download_url.ends_with(&format!("/{expected_name}"))
    {
        return Err("GitHub returned an update URL outside the official repository.".to_owned());
    }
    if !update.release_url.starts_with(RELEASE_PREFIX) {
        return Err("GitHub returned a release page outside the official repository.".to_owned());
    }
    Ok(())
}

fn parse_version(version: &str) -> Option<[u64; 3]> {
    let version = version.strip_prefix('v').unwrap_or(version);
    let mut parts = version.split('.');
    let parsed = [
        parts.next()?.parse().ok()?,
        parts.next()?.parse().ok()?,
        parts.next()?.parse().ok()?,
    ];
    parts.next().is_none().then_some(parsed)
}

const CHECK_UPDATE_SCRIPT: &str = r#"$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$headers = @{
    'User-Agent' = 'Windows-Toolbox'
    'Accept' = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}
$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/dylan0760/Windows-Winget/releases/latest' -Headers $headers -UseBasicParsing
if ($release.draft -or $release.prerelease) {
    Write-Output 'NO_COMPATIBLE_ASSET'
    exit 0
}
$candidates = @(
    foreach ($asset in @($release.assets)) {
        if ($asset.name -match '^Windows-Toolbox-(?<Version>\d+\.\d+\.\d+)-x64\.msi$') {
            [pscustomobject]@{
                Version = [version]$Matches.Version
                Asset = $asset
            }
        }
    }
)
$candidate = $candidates | Sort-Object Version -Descending | Select-Object -First 1
if ($null -eq $candidate) {
    Write-Output 'NO_COMPATIBLE_ASSET'
    exit 0
}
Write-Output ('VERSION' + "`t" + $candidate.Version.ToString())
Write-Output ('ASSET_NAME' + "`t" + $candidate.Asset.name)
Write-Output ('DOWNLOAD_URL' + "`t" + $candidate.Asset.browser_download_url)
Write-Output ('RELEASE_URL' + "`t" + $release.html_url)"#;

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

fn run_windows_powershell(script: &str) -> Result<String, String> {
    let program = windows_powershell_path();
    let mut command = Command::new(&program);
    command.args([
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-Command",
        script,
    ]);
    #[cfg(windows)]
    command.creation_flags(CREATE_NO_WINDOW);

    let output = command
        .output()
        .map_err(|error| format!("Could not start the GitHub update check: {error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_owned();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();
    if output.status.success() {
        Ok(stdout)
    } else if stderr.is_empty() {
        Err(if stdout.is_empty() {
            format!("The GitHub update check exited with {}.", output.status)
        } else {
            stdout
        })
    } else {
        Err(stderr)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn response(version: &str, repository: &str) -> String {
        format!(
            "VERSION\t{version}\nASSET_NAME\tWindows-Toolbox-{version}-x64.msi\nDOWNLOAD_URL\thttps://github.com/{repository}/releases/download/Latest/Windows-Toolbox-{version}-x64.msi\nRELEASE_URL\thttps://github.com/{repository}/releases/tag/Latest"
        )
    }

    #[test]
    fn newer_release_asset_is_offered() {
        let update = parse_update_response(&response("1.2.0", "dylan0760/Windows-Winget"), "1.1.9")
            .expect("response should parse")
            .expect("newer update should be offered");
        assert_eq!(update.version, "1.2.0");
    }

    #[test]
    fn same_or_older_release_is_not_offered() {
        assert!(
            parse_update_response(&response("1.0.17", "dylan0760/Windows-Winget"), "1.0.17")
                .expect("response should parse")
                .is_none()
        );
        assert!(
            parse_update_response(&response("1.0.16", "dylan0760/Windows-Winget"), "1.0.17")
                .expect("response should parse")
                .is_none()
        );
    }

    #[test]
    fn update_urls_outside_the_official_repository_are_rejected() {
        assert!(
            parse_update_response(&response("9.0.0", "example/Windows-Winget"), "1.0.0").is_err()
        );
    }

    #[test]
    fn latest_tag_can_use_versioned_msi_asset() {
        assert!(CHECK_UPDATE_SCRIPT.contains("releases/latest"));
        assert!(CHECK_UPDATE_SCRIPT.contains("Windows-Toolbox-"));
        assert!(CHECK_UPDATE_SCRIPT.contains("$Matches.Version"));
    }
}
