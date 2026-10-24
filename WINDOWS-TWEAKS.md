# Windows Tweaks tab

The Windows Tweaks tab changes local Windows preferences and machine settings without downloading a third-party tweaking script. It displays the result of each action in the status area at the bottom of Windows Toolbox.

[Return to the main README](README.md) · [Programs](PROGRAMS.md) · [Config](CONFIG.md) · [Legacy Panels](LEGACY-PANELS.md)

## Appearance

### Use dark mode

Sets both `AppsUseLightTheme` and `SystemUsesLightTheme` to `0` under the current user's Windows personalization registry key. This requests dark colours for supported Windows surfaces and applications, then broadcasts a Windows setting-change notification.

### Use light mode

Sets the same two values to `1` and broadcasts the setting change. Applications that do not follow the Windows theme may ignore either option.

These appearance changes are per-user rather than machine-wide.

## Explorer and gaming preferences

Windows Toolbox reads these four states automatically when the tab is opened. **Refresh preference states** reads them again. File Explorer windows or applications may need to be refreshed before a visual change appears.

### Show File Explorer file extensions

- Enabled: sets `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\HideFileExt` to `0`.
- Disabled: sets it to `1`.
- Windows Toolbox broadcasts an Explorer change notification after updating the value.

### Show hidden files in File Explorer

- Enabled: sets the Explorer `Hidden` value to `1`.
- Disabled: sets it to `0`.
- This affects items carrying the Windows hidden-file attribute; it does not remove the attribute or change protected operating-system-file settings.

### Windows Game Mode

- Enabled: sets `AllowAutoGameMode` and `AutoGameModeEnabled` to `1` under `HKCU\Software\Microsoft\GameBar`.
- Disabled: sets both values to `0`.
- Game Mode lets Windows prioritise resources for supported games, but performance changes depend on the system and workload.

### Mouse acceleration

- Enabled: applies Windows mouse parameters `6, 10, 1`.
- Disabled: applies `0, 0, 0`.
- The change is made through the Windows `SystemParametersInfo` API, persisted to the user profile, and broadcast to applications.

## Display refresh rate

**Use highest supported refresh rate** checks every active, non-mirroring display reported by Windows. For each display it:

1. Reads the current resolution, colour depth, and refresh rate.
2. Enumerates the supported display modes.
3. Selects the highest refresh rate with the same resolution and colour depth.
4. Applies only the refresh-rate change and stores it in Windows display settings.
5. Reports the old and new rates, an already-optimal result, or a Windows rejection code.

This action does not intentionally change resolution or colour depth. Windows and the graphics driver remain responsible for validating the selected mode.

## Jumbo Frames

**Refresh adapter list** runs `Get-NetAdapter` and shows each adapter's name, description, status, link speed, and current `*JumboPacket` advanced-property value. Adapters without that driver property are shown as unsupported.

### Enable 9014-byte Jumbo Frames

- Requires selecting the acknowledgement checkbox first.
- Sets the selected adapter's `*JumboPacket` registry value to `9014` with `Set-NetAdapterAdvancedProperty`.
- The adapter may disconnect briefly.
- The adapter, switch, router, and destination must support the same frame size end-to-end. Otherwise, traffic may fail or fragment.

### Restore standard 1514-byte frame

Sets the selected adapter's `*JumboPacket` value to `1514`. This recovery action does not require the acknowledgement checkbox.

Changing advanced adapter properties normally requires Administrator rights and vendor-driver support.

## PowerShell execution policy

This section targets the 64-bit Windows PowerShell `LocalMachine` scope.

### Check current policies

Runs `Get-ExecutionPolicy -List` and displays every scope, including `MachinePolicy`, `UserPolicy`, `Process`, `CurrentUser`, and `LocalMachine`.

### Set LocalMachine to Unrestricted

Allows unsigned local scripts and warns for scripts marked as downloaded. Because this weakens script-origin protections for every user, Windows Toolbox requires an explicit acknowledgement before enabling the button.

### Set LocalMachine to Restricted

Prevents Windows PowerShell script files from running at the `LocalMachine` scope. Interactive commands can still be entered.

### Set LocalMachine to RemoteSigned

Allows unsigned local scripts while requiring downloaded scripts to be signed unless they are explicitly unblocked.

After any change, Windows Toolbox reads the stored `LocalMachine` value and the effective policy. If a higher-priority scope keeps a different effective policy, the application identifies the overriding scope where possible. Domain or local Group Policy is reported but never bypassed.

## Permissions and recovery

- Windows Toolbox requests Administrator rights when launched, which is required for machine-wide execution-policy and adapter changes.
- Per-user appearance and Explorer preferences are written only to the current user's settings.
- If an operation fails, the previous toggle state is restored in the interface and the Windows error is shown in the status area.
