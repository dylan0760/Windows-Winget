# Config tab

The Config tab enables supported Windows optional features and provides a guarded launcher for Microsoft Sysinternals Autologon. Feature operations use built-in Windows PowerShell commands and do not download or execute WinUtil.

[Return to the main README](README.md) · [Programs](PROGRAMS.md) · [Windows Tweaks](WINDOWS-TWEAKS.md) · [Legacy Panels](LEGACY-PANELS.md)

## Feature-state detection

Windows Toolbox queries `Get-WindowsOptionalFeature -Online` when the Config tab is first opened. **Refresh feature states** repeats the query.

- A feature group is checked automatically only when every component in that group is `Enabled` or `EnablePending`.
- A partially enabled group remains unchecked.
- A group containing an unavailable component remains unchecked.
- The checkboxes are both current-state indicators and the selection for the next enable operation.

**Enable selected** calls `Enable-WindowsOptionalFeature -Online -All -NoRestart` for every component in each selected group. Windows Toolbox reports whether Windows requested a restart. **Clear selection** clears the checkboxes in the interface; it does not disable Windows features.

Windows edition, hardware virtualisation, organisational policy, and component availability still determine whether an action can succeed. This tab enables features but does not provide a disable operation.

## Available feature groups

### .NET Framework (versions 2, 3, and 4)

Enables:

- `NetFx4-AdvSrvs`
- `NetFx3`

This provides the advanced .NET Framework 4 component and the legacy .NET Framework 2.0/3.0/3.5 compatibility component used by older Windows applications.

### Hyper-V

Enables:

- `Microsoft-Hyper-V-All`

This turns on Microsoft's Hyper-V platform and its dependent components where supported. Compatible Windows editions, hardware virtualisation, and usually a restart are required.

### Network File System (NFS)

Enables:

- `ServicesForNFS-ClientOnly`
- `ClientForNFS-Infrastructure`
- `NFS-Administration`

After the features are enabled, Windows Toolbox applies the requested client defaults:

- Stops the NFS client service before configuration and starts it afterwards.
- Sets `AnonymousUID` and `AnonymousGID` to `0` in the Microsoft Client for NFS defaults registry key.
- Sets `fileaccess=755`.
- Enables the `sys` security flavour and removes `krb5` and `krb5i` from the configured client security flavours.

If `nfsadmin.exe` is not available immediately after enabling the components, restart Windows and run the NFS action again. Review the UID/GID and security-flavour choices against the requirements of the NFS server before using them in a production environment.

### Windows Sandbox

Enables:

- `Containers-DisposableClientVM`

Windows Sandbox provides an isolated, disposable Windows desktop on supported editions. Hardware virtualisation and a restart may be required.

### Windows Subsystem for Linux (WSL)

Enables:

- `VirtualMachinePlatform`
- `Microsoft-Windows-Subsystem-Linux`

This prepares Windows for WSL and WSL 2. It does not install a Linux distribution, select a default WSL version, or configure a distribution.

## Autologin

**Run Microsoft Autologon** performs the following guarded workflow:

1. Downloads `Autologon.exe` from `https://live.sysinternals.com/` to a uniquely named temporary file using TLS 1.2.
2. Checks the Authenticode signature.
3. Requires a valid signature from a certificate whose subject contains Microsoft.
4. Starts the Microsoft Sysinternals dialog with `/accepteula` and waits for it to close.
5. Deletes the temporary executable whether the dialog succeeds or fails.

Windows Toolbox does not collect the account name or password; those are entered into Microsoft's Autologon interface. Enabling Autologon reduces physical sign-in security because Windows signs in automatically, so review the selected account and device exposure carefully.

## Permissions and restart behaviour

- Enabling optional Windows features requires Administrator rights.
- Windows Toolbox passes `-NoRestart`, so it does not restart the computer automatically.
- The result reports when Windows says a restart is needed.
- Feature availability varies by Windows edition and version.
