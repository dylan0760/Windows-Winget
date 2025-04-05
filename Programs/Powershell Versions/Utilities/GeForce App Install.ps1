Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
choco install nvidia-app -y
Remove-Item "C:\ProgramData\chocolatey" -Recurse -Force
Remove-Item "C:\Users\$env:USERNAME\AppData\Local\Temp\Chocolatey" -Recurse -Force

