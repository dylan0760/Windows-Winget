Prerequisites
To run this script, ensure the following prerequisites are met:

Git Installation :
You will need Git installed to clone the repository. You can download Git from the official site:
[Download Git](https://git-scm.com/downloads)


PowerShell Permissions :
Make sure that PowerShell is configured to allow the execution of scripts. You need to set the execution policy to run unsigned (unmanaged) scripts. You can do this with the following command in an elevated PowerShell window:

powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser

Running the Script :
After meeting the above prerequisites, you can run the script by opening a command prompt (CMD) and entering the following command:

shell
powershell -ExecutionPolicy Bypass -File "GuI Github.ps1.ps1"
