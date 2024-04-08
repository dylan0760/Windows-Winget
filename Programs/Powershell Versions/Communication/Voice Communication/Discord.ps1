# Check if running as administrator
$currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

# If not, relaunch as administrator
if (-not $isAdmin) {
  $arguments = "& '" + $myinvocation.mycommand.definition + "'"
  Start-Process powershell -Verb runAs -ArgumentList $arguments
  exit
}

# Your script code goes here
Write-Host "Running as administrator"

winget install --id=Discord.Discord  -e --accept-package-agreements --accept-source-agreements --silent
Pause