use std::process::Command;

#[cfg(windows)]
use std::os::windows::process::CommandExt;

#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x0800_0000;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ConfigFeature {
    DotNetFramework,
    HyperV,
    NetworkFileSystem,
    WindowsSandbox,
    WindowsSubsystemForLinux,
}

impl ConfigFeature {
    pub const ALL: [Self; 5] = [
        Self::DotNetFramework,
        Self::HyperV,
        Self::NetworkFileSystem,
        Self::WindowsSandbox,
        Self::WindowsSubsystemForLinux,
    ];

    pub const fn label(self) -> &'static str {
        match self {
            Self::DotNetFramework => ".NET Framework (versions 2, 3, and 4)",
            Self::HyperV => "Hyper-V",
            Self::NetworkFileSystem => "Network File System (NFS)",
            Self::WindowsSandbox => "Windows Sandbox",
            Self::WindowsSubsystemForLinux => "Windows Subsystem for Linux (WSL)",
        }
    }

    pub const fn description(self) -> &'static str {
        match self {
            Self::DotNetFramework => {
                "Enable the legacy and advanced .NET Framework Windows components."
            }
            Self::HyperV => "Enable Microsoft's Hyper-V virtualization platform.",
            Self::NetworkFileSystem => {
                "Enable the Windows NFS client and apply the WinUtil client defaults."
            }
            Self::WindowsSandbox => {
                "Enable the disposable Windows Sandbox desktop environment."
            }
            Self::WindowsSubsystemForLinux => {
                "Enable WSL and Virtual Machine Platform. This does not install a Linux distribution."
            }
        }
    }

    pub const fn feature_names(self) -> &'static [&'static str] {
        match self {
            Self::DotNetFramework => &["NetFx4-AdvSrvs", "NetFx3"],
            Self::HyperV => &["Microsoft-Hyper-V-All"],
            Self::NetworkFileSystem => &[
                "ServicesForNFS-ClientOnly",
                "ClientForNFS-Infrastructure",
                "NFS-Administration",
            ],
            Self::WindowsSandbox => &["Containers-DisposableClientVM"],
            Self::WindowsSubsystemForLinux => &[
                "VirtualMachinePlatform",
                "Microsoft-Windows-Subsystem-Linux",
            ],
        }
    }
}

pub fn enable_features(features: &[ConfigFeature]) -> Result<String, String> {
    if features.is_empty() {
        return Err("Select at least one Windows feature.".to_owned());
    }

    run_windows_powershell(&feature_install_script(features))
}

pub fn query_feature_states() -> Result<[bool; ConfigFeature::ALL.len()], String> {
    let output = run_windows_powershell(&feature_state_script())?;
    parse_feature_states(&output)
}

pub fn run_autologon() -> Result<String, String> {
    run_windows_powershell(AUTOLOGON_SCRIPT)
}

fn feature_install_script(features: &[ConfigFeature]) -> String {
    let feature_names = features
        .iter()
        .flat_map(|feature| feature.feature_names().iter().copied())
        .map(|feature| format!("'{feature}'"))
        .collect::<Vec<_>>()
        .join(", ");
    let labels = features
        .iter()
        .map(|feature| feature.label())
        .collect::<Vec<_>>()
        .join(", ");
    let nfs_configuration = if features.contains(&ConfigFeature::NetworkFileSystem) {
        NFS_CONFIGURATION_SCRIPT
    } else {
        ""
    };

    format!(
        r#"$ErrorActionPreference = 'Stop'
$restartNeeded = $false
$features = @({feature_names})
foreach ($feature in $features) {{
    Write-Output ('Enabling ' + $feature + '...')
    $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction Stop
    if ([bool]$result.RestartNeeded) {{ $restartNeeded = $true }}
}}
{nfs_configuration}
Write-Output 'Enabled feature set(s): {labels}.'
if ($restartNeeded) {{
    Write-Output 'Windows reports that a restart is required to finish enabling these features.'
}} else {{
    Write-Output 'No restart was requested by Windows.'
}}"#
    )
}

fn all_feature_names() -> Vec<&'static str> {
    let mut names = Vec::new();
    for feature in ConfigFeature::ALL {
        for name in feature.feature_names() {
            if !names.contains(name) {
                names.push(*name);
            }
        }
    }
    names
}

fn feature_state_script() -> String {
    let feature_names = all_feature_names()
        .iter()
        .map(|feature| format!("'{feature}'"))
        .collect::<Vec<_>>()
        .join(", ");
    format!(
        r#"$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$requested = @({feature_names})
$available = @(Get-WindowsOptionalFeature -Online -ErrorAction Stop)
foreach ($name in $requested) {{
    $match = $available | Where-Object {{ $_.FeatureName -eq $name }} | Select-Object -First 1
    $state = if ($null -eq $match) {{ 'Unavailable' }} else {{ [string]$match.State }}
    Write-Output ($name + '|' + $state)
}}"#
    )
}

fn parse_feature_states(output: &str) -> Result<[bool; ConfigFeature::ALL.len()], String> {
    let parsed: Vec<_> = output
        .lines()
        .filter_map(|line| line.trim().split_once('|'))
        .map(|(name, state)| (name.trim(), state.trim()))
        .collect();

    for expected in all_feature_names() {
        if !parsed.iter().any(|(name, _)| *name == expected) {
            return Err(format!(
                "Windows did not return a state for optional feature {expected}."
            ));
        }
    }

    let mut states = [false; ConfigFeature::ALL.len()];
    for (index, feature) in ConfigFeature::ALL.iter().copied().enumerate() {
        states[index] = feature.feature_names().iter().all(|expected| {
            parsed.iter().any(|(name, state)| {
                name == expected && matches!(*state, "Enabled" | "EnablePending")
            })
        });
    }
    Ok(states)
}

const NFS_CONFIGURATION_SCRIPT: &str = r#"$nfsAdmin = Join-Path $env:SystemRoot 'System32\nfsadmin.exe'
if (-not (Test-Path -LiteralPath $nfsAdmin -PathType Leaf)) {
    throw 'NFS was enabled, but nfsadmin.exe is not currently available. Restart Windows and run the NFS action again.'
}
& $nfsAdmin client stop
if ($LASTEXITCODE -ne 0) { throw "nfsadmin client stop failed with exit code $LASTEXITCODE." }
$nfsDefaults = 'HKLM:\SOFTWARE\Microsoft\ClientForNFS\CurrentVersion\Default'
New-Item -Path $nfsDefaults -Force | Out-Null
New-ItemProperty -Path $nfsDefaults -Name 'AnonymousUID' -PropertyType DWord -Value 0 -Force | Out-Null
New-ItemProperty -Path $nfsDefaults -Name 'AnonymousGID' -PropertyType DWord -Value 0 -Force | Out-Null
& $nfsAdmin client start
if ($LASTEXITCODE -ne 0) { throw "nfsadmin client start failed with exit code $LASTEXITCODE." }
& $nfsAdmin client localhost config fileaccess=755 SecFlavors=+sys -krb5 -krb5i
if ($LASTEXITCODE -ne 0) { throw "nfsadmin client configuration failed with exit code $LASTEXITCODE." }
Write-Output 'Applied the WinUtil NFS client defaults.'"#;

const AUTOLOGON_SCRIPT: &str = r#"$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$download = Join-Path ([IO.Path]::GetTempPath()) ('Windows-Toolbox-Autologon-' + [Guid]::NewGuid().ToString('N') + '.exe')
try {
    Invoke-WebRequest -Uri 'https://live.sysinternals.com/Autologon.exe' -UseBasicParsing -OutFile $download
    $signature = Get-AuthenticodeSignature -LiteralPath $download
    $subject = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { '' }
    if ($signature.Status -ne 'Valid' -or $subject -notmatch 'Microsoft') {
        throw ('Microsoft Authenticode validation failed. Status: ' + $signature.Status + '; signer: ' + $subject)
    }
    $process = Start-Process -FilePath $download -ArgumentList '/accepteula' -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw ('Microsoft Sysinternals Autologon exited with code ' + $process.ExitCode + '.')
    }
    Write-Output 'Microsoft Sysinternals Autologon completed.'
} finally {
    Remove-Item -LiteralPath $download -Force -ErrorAction SilentlyContinue
}"#;

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
        .map_err(|error| format!("Could not start Windows PowerShell: {error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_owned();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();
    let detail = match (stdout.is_empty(), stderr.is_empty()) {
        (false, false) => format!("{stdout}\n{stderr}"),
        (false, true) => stdout,
        (true, false) => stderr,
        (true, true) => format!("Windows PowerShell exited with {}", output.status),
    };

    if output.status.success() {
        Ok(detail)
    } else {
        Err(detail)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn feature_mappings_match_the_winutil_reference() {
        assert_eq!(
            ConfigFeature::DotNetFramework.feature_names(),
            &["NetFx4-AdvSrvs", "NetFx3"]
        );
        assert_eq!(
            ConfigFeature::HyperV.feature_names(),
            &["Microsoft-Hyper-V-All"]
        );
        assert_eq!(
            ConfigFeature::NetworkFileSystem.feature_names(),
            &[
                "ServicesForNFS-ClientOnly",
                "ClientForNFS-Infrastructure",
                "NFS-Administration"
            ]
        );
        assert_eq!(
            ConfigFeature::WindowsSandbox.feature_names(),
            &["Containers-DisposableClientVM"]
        );
        assert_eq!(
            ConfigFeature::WindowsSubsystemForLinux.feature_names(),
            &[
                "VirtualMachinePlatform",
                "Microsoft-Windows-Subsystem-Linux"
            ]
        );
    }

    #[test]
    fn nfs_selection_includes_the_reference_client_configuration() {
        let script = feature_install_script(&[ConfigFeature::NetworkFileSystem]);
        assert!(script.contains("AnonymousUID"));
        assert!(script.contains("AnonymousGID"));
        assert!(script.contains("fileaccess=755"));
        assert!(script.contains("SecFlavors=+sys -krb5 -krb5i"));
    }

    #[test]
    fn autologon_uses_microsoft_download_and_signature_validation() {
        assert!(AUTOLOGON_SCRIPT.contains("https://live.sysinternals.com/Autologon.exe"));
        assert!(AUTOLOGON_SCRIPT.contains("Get-AuthenticodeSignature"));
        assert!(AUTOLOGON_SCRIPT.contains("$signature.Status -ne 'Valid'"));
        assert!(AUTOLOGON_SCRIPT.contains("-ArgumentList '/accepteula'"));
    }

    #[test]
    fn enabled_and_enable_pending_components_are_auto_checked() {
        let output = [
            "NetFx4-AdvSrvs|Enabled",
            "NetFx3|EnablePending",
            "Microsoft-Hyper-V-All|Disabled",
            "ServicesForNFS-ClientOnly|Enabled",
            "ClientForNFS-Infrastructure|Enabled",
            "NFS-Administration|Enabled",
            "Containers-DisposableClientVM|Unavailable",
            "VirtualMachinePlatform|Enabled",
            "Microsoft-Windows-Subsystem-Linux|Enabled",
        ]
        .join("\n");
        let states = parse_feature_states(&output).expect("states should parse");
        assert_eq!(states, [true, false, true, false, true]);
    }

    #[test]
    fn partial_feature_groups_are_not_auto_checked() {
        let output = [
            "NetFx4-AdvSrvs|Enabled",
            "NetFx3|Disabled",
            "Microsoft-Hyper-V-All|Enabled",
            "ServicesForNFS-ClientOnly|Enabled",
            "ClientForNFS-Infrastructure|Disabled",
            "NFS-Administration|Enabled",
            "Containers-DisposableClientVM|Enabled",
            "VirtualMachinePlatform|Enabled",
            "Microsoft-Windows-Subsystem-Linux|Disabled",
        ]
        .join("\n");
        let states = parse_feature_states(&output).expect("states should parse");
        assert_eq!(states, [false, true, false, true, false]);
    }
}
