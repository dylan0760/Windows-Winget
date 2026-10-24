use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

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
    pub asset_size: u64,
    pub download_url: String,
    pub release_url: String,
}

pub fn check_for_update() -> Result<Option<UpdateInfo>, String> {
    let output = run_windows_powershell(CHECK_UPDATE_SCRIPT)?;
    parse_update_response(&output, CURRENT_VERSION)
}

pub fn install_update(update: &UpdateInfo) -> Result<String, String> {
    validate_update(update)?;

    #[cfg(windows)]
    {
        let powershell = trusted_windows_executable(&[
            "System32",
            "WindowsPowerShell",
            "v1.0",
            "powershell.exe",
        ])?;
        let msiexec = trusted_windows_executable(&["System32", "msiexec.exe"])?;
        let unique = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos();
        let base_name = format!("Windows-Toolbox-Update-{}-{unique}", std::process::id());
        let msi_path = std::env::temp_dir().join(format!("{base_name}.msi"));
        let partial_path = std::env::temp_dir().join(format!("{base_name}.msi.partial"));

        remove_temporary_file(&partial_path);
        remove_temporary_file(&msi_path);
        download_update(&powershell, update, &partial_path, &msi_path)?;
        if let Err(error) = verify_msi_header(&msi_path) {
            remove_temporary_file(&partial_path);
            remove_temporary_file(&msi_path);
            return Err(error);
        }

        let mut helper = Command::new(&powershell);
        helper
            .args([
                "-NoLogo",
                "-NoProfile",
                "-NonInteractive",
                "-ExecutionPolicy",
                "Bypass",
                "-Command",
                LAUNCH_UPDATE_SCRIPT,
            ])
            .env("WINDOWS_TOOLBOX_PID", std::process::id().to_string())
            .env("WINDOWS_TOOLBOX_UPDATE_MSI", &msi_path)
            .env("WINDOWS_TOOLBOX_MSIEXEC", &msiexec)
            .creation_flags(CREATE_NO_WINDOW);
        if let Err(error) = helper.spawn() {
            remove_temporary_file(&msi_path);
            return Err(format!("Could not launch the downloaded update: {error}"));
        }

        Ok(format!(
            "Windows Toolbox {} was downloaded and verified. The app will close and Windows Installer will open.",
            update.version
        ))
    }

    #[cfg(not(windows))]
    {
        let _ = update;
        Err("In-app updates are only supported on Windows.".to_owned())
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
        asset_size: value("ASSET_SIZE\t")
            .ok_or_else(|| "GitHub did not return the MSI asset size.".to_owned())?
            .parse()
            .map_err(|_| "GitHub returned an invalid MSI asset size.".to_owned())?,
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
    if update.asset_size == 0 {
        return Err("GitHub returned an empty Windows Toolbox MSI asset.".to_owned());
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
Write-Output ('ASSET_SIZE' + "`t" + [string]$candidate.Asset.size)
Write-Output ('DOWNLOAD_URL' + "`t" + $candidate.Asset.browser_download_url)
Write-Output ('RELEASE_URL' + "`t" + $release.html_url)"#;

const DOWNLOAD_UPDATE_SCRIPT: &str = r#"$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$headers = @{
    'User-Agent' = 'Windows-Toolbox'
    'Accept' = 'application/octet-stream'
}
Invoke-WebRequest -Uri $env:WINDOWS_TOOLBOX_UPDATE_URL -Headers $headers -UseBasicParsing -OutFile $env:WINDOWS_TOOLBOX_UPDATE_PARTIAL
$download = Get-Item -LiteralPath $env:WINDOWS_TOOLBOX_UPDATE_PARTIAL
if ($download.Length -ne [int64]$env:WINDOWS_TOOLBOX_UPDATE_SIZE) {
    throw 'The downloaded MSI size does not match the GitHub release asset.'
}
Move-Item -LiteralPath $env:WINDOWS_TOOLBOX_UPDATE_PARTIAL -Destination $env:WINDOWS_TOOLBOX_UPDATE_OUTPUT -Force"#;

const LAUNCH_UPDATE_SCRIPT: &str = r#"$ErrorActionPreference = 'Stop'
$installerExitCode = 1603
$installerLog = $env:WINDOWS_TOOLBOX_UPDATE_MSI + '.log'
try {
    Wait-Process -Id ([int]$env:WINDOWS_TOOLBOX_PID) -ErrorAction SilentlyContinue
    $quotedMsi = '"' + $env:WINDOWS_TOOLBOX_UPDATE_MSI + '"'
    $quotedLog = '"' + $installerLog + '"'
    $installer = Start-Process -FilePath $env:WINDOWS_TOOLBOX_MSIEXEC -ArgumentList @('/i', $quotedMsi, '/L*V', $quotedLog) -Wait -PassThru
    $installerExitCode = $installer.ExitCode
} finally {
    Remove-Item -LiteralPath $env:WINDOWS_TOOLBOX_UPDATE_MSI -Force -ErrorAction SilentlyContinue
}
if ($installerExitCode -in @(0, 1641, 3010)) {
    Remove-Item -LiteralPath $installerLog -Force -ErrorAction SilentlyContinue
}
exit $installerExitCode"#;

fn download_update(
    powershell: &Path,
    update: &UpdateInfo,
    partial_path: &Path,
    msi_path: &Path,
) -> Result<(), String> {
    let mut command = Command::new(powershell);
    command
        .args([
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            DOWNLOAD_UPDATE_SCRIPT,
        ])
        .env("WINDOWS_TOOLBOX_UPDATE_URL", &update.download_url)
        .env("WINDOWS_TOOLBOX_UPDATE_SIZE", update.asset_size.to_string())
        .env("WINDOWS_TOOLBOX_UPDATE_PARTIAL", partial_path)
        .env("WINDOWS_TOOLBOX_UPDATE_OUTPUT", msi_path);
    #[cfg(windows)]
    command.creation_flags(CREATE_NO_WINDOW);

    let output = command
        .output()
        .map_err(|error| format!("Could not start the in-app update download: {error}"))?;
    if output.status.success() && msi_path.is_file() {
        return Ok(());
    }

    remove_temporary_file(partial_path);
    remove_temporary_file(msi_path);
    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_owned();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();
    let detail = if !stderr.is_empty() {
        stderr
    } else if !stdout.is_empty() {
        stdout
    } else {
        format!("PowerShell exited with {}", output.status)
    };
    Err(format!("Could not download the update MSI:\n{detail}"))
}

fn verify_msi_header(path: &Path) -> Result<(), String> {
    const COMPOUND_FILE_HEADER: [u8; 8] = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];
    let mut file = std::fs::File::open(path)
        .map_err(|error| format!("Could not open the downloaded update MSI: {error}"))?;
    let mut header = [0_u8; 8];
    file.read_exact(&mut header)
        .map_err(|error| format!("Could not validate the downloaded update MSI: {error}"))?;
    if header == COMPOUND_FILE_HEADER {
        Ok(())
    } else {
        Err("The downloaded update does not have a valid MSI file header.".to_owned())
    }
}

fn remove_temporary_file(path: &Path) {
    if path.is_file() {
        let _ = std::fs::remove_file(path);
    }
}

fn trusted_windows_executable(relative_path: &[&str]) -> Result<PathBuf, String> {
    let system_root = std::env::var_os("SystemRoot")
        .ok_or_else(|| "Windows did not provide the SystemRoot directory.".to_owned())?;
    let mut executable = PathBuf::from(system_root);
    for component in relative_path {
        executable.push(component);
    }
    executable
        .is_file()
        .then_some(executable)
        .ok_or_else(|| "A required Windows update executable could not be found.".to_owned())
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
            "VERSION\t{version}\nASSET_NAME\tWindows-Toolbox-{version}-x64.msi\nASSET_SIZE\t2932736\nDOWNLOAD_URL\thttps://github.com/{repository}/releases/download/Latest/Windows-Toolbox-{version}-x64.msi\nRELEASE_URL\thttps://github.com/{repository}/releases/tag/Latest"
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
        assert!(CHECK_UPDATE_SCRIPT.contains("$candidate.Asset.size"));
    }

    #[test]
    fn in_app_update_download_is_validated_and_launched_with_windows_installer() {
        assert!(DOWNLOAD_UPDATE_SCRIPT.contains("WINDOWS_TOOLBOX_UPDATE_SIZE"));
        assert!(LAUNCH_UPDATE_SCRIPT.contains("WINDOWS_TOOLBOX_MSIEXEC"));
        assert!(LAUNCH_UPDATE_SCRIPT.contains("Wait-Process"));
        assert!(LAUNCH_UPDATE_SCRIPT.contains("Start-Process"));
        assert!(LAUNCH_UPDATE_SCRIPT.contains("-Wait -PassThru"));
        assert!(LAUNCH_UPDATE_SCRIPT.contains("/L*V"));
        assert!(LAUNCH_UPDATE_SCRIPT.contains("Remove-Item"));
    }
}
