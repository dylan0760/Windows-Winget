[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$SkipValidation,
    [string]$Cargo = "cargo",
    [string]$WixBin
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$releaseDirectory = Join-Path $projectRoot "target\release"
$wixOutputDirectory = Join-Path $projectRoot "target\wix"
$wixSource = Join-Path $projectRoot "wix\main.wxs"
$objectFile = Join-Path $wixOutputDirectory "main.wixobj"
$msiFile = Join-Path $wixOutputDirectory "Windows-Toolbox-1.0.26-x64.msi"

if (-not $SkipBuild) {
    & $Cargo build --release --manifest-path (Join-Path $projectRoot "Cargo.toml")
    if ($LASTEXITCODE -ne 0) { throw "Rust release build failed." }
}

$executable = Join-Path $releaseDirectory "windows-toolbox.exe"
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "Expected executable not found: $executable"
}

if ($WixBin) {
    $candle = Join-Path $WixBin "candle.exe"
    $light = Join-Path $WixBin "light.exe"
} else {
    $candleCommand = Get-Command candle.exe -ErrorAction SilentlyContinue
    $lightCommand = Get-Command light.exe -ErrorAction SilentlyContinue
    if ($candleCommand -and $lightCommand) {
        $candle = $candleCommand.Source
        $light = $lightCommand.Source
    } else {
        $knownWix = @(
            "${env:ProgramFiles(x86)}\WiX Toolset v3.14\bin",
            "${env:ProgramFiles(x86)}\WiX Toolset v3.11\bin"
        ) | Where-Object { Test-Path -LiteralPath (Join-Path $_ "candle.exe") } | Select-Object -First 1
        if (-not $knownWix) {
            throw "WiX Toolset 3.14 was not found. Pass -WixBin with its bin directory."
        }
        $candle = Join-Path $knownWix "candle.exe"
        $light = Join-Path $knownWix "light.exe"
    }
}

New-Item -ItemType Directory -Path $wixOutputDirectory -Force | Out-Null

$wixUiExtensionSource = Join-Path (Split-Path -Parent $light) "WixUIExtension.dll"
if (-not (Test-Path -LiteralPath $wixUiExtensionSource -PathType Leaf)) {
    throw "WiX UI extension not found: $wixUiExtensionSource"
}
$wixUiExtension = Join-Path ([IO.Path]::GetTempPath()) "WindowsToolbox-WixUIExtension-$PID.dll"
Copy-Item -LiteralPath $wixUiExtensionSource -Destination $wixUiExtension -Force

$lightArguments = @("-nologo", "-ext", $wixUiExtension, "-out", $msiFile, $objectFile)
if ($SkipValidation) {
    # Some sandbox environments disable the Windows Installer service used by ICE.
    $lightArguments = @("-nologo", "-sval", "-ext", $wixUiExtension, "-out", $msiFile, $objectFile)
}
try {
    & $candle -nologo -arch x64 "-dSourceDir=$releaseDirectory" "-dProjectRoot=$projectRoot" -out $objectFile $wixSource
    if ($LASTEXITCODE -ne 0) { throw "WiX compiler failed." }

    & $light @lightArguments
    if ($LASTEXITCODE -ne 0) { throw "WiX linker failed." }
} finally {
    Remove-Item -LiteralPath $wixUiExtension -Force -ErrorAction SilentlyContinue
}

Write-Output $msiFile
