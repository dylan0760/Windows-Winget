# Legacy Panels tab

The Legacy Panels tab opens classic Windows management interfaces directly with built-in Windows executables. It does not download tools or run PowerShell scripts. A status message reports whether Windows successfully started the requested panel.

[Return to the main README](README.md) · [Programs](PROGRAMS.md) · [Windows Tweaks](WINDOWS-TWEAKS.md) · [Config](CONFIG.md)

## Available panels

| Panel | What it opens | Windows command |
| --- | --- | --- |
| Control Panel | The classic Control Panel home page and category view. | `control.exe` |
| Network Connections | Classic network-adapter management for enabling, disabling, renaming, and opening adapter properties. | `control.exe ncpa.cpl` |
| Power Options | Classic power-plan selection and advanced power-plan configuration. | `control.exe powercfg.cpl` |
| Region | Regional formats, location, language-related administrative settings, and system locale options provided by the classic dialog. | `control.exe intl.cpl` |
| Sound | Playback, recording, Windows sounds, and communications-device settings. | `control.exe mmsys.cpl` |
| Devices and Printers | The classic shell view for installed devices and printers. | `explorer.exe shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}` |
| System Properties | Computer name, hardware, system protection, remote access, performance, user profiles, startup, and environment-variable entry points exposed by the classic dialog. | `control.exe sysdm.cpl` |
| User Accounts | The classic local user-account management dialog, including account membership and sign-in options available on the current Windows edition. | `control.exe userpasswords2` |

## How panels are launched

- Windows Toolbox resolves `control.exe` from `%SystemRoot%\System32`.
- Devices and Printers resolves `explorer.exe` from `%SystemRoot%`.
- The target executable must exist before Windows Toolbox attempts to start it.
- Each panel opens as a normal Windows process and remains independent of Windows Toolbox after launch.
- Available controls can differ between Windows 10, Windows 11, Windows editions, and domain-managed computers.

Administrator rights may expose additional controls, but the panel itself decides which settings the current account can change.
