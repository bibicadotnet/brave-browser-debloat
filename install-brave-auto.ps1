# Require Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://go.bibica.net/brave | iex`"" -Verb RunAs
    exit
}

Clear-Host
Write-Host " Brave Browser Auto Installer " -BackgroundColor DarkGreen

# 1. Remove old installation
Write-Host "Removing old installation..." -ForegroundColor Cyan
Stop-Process -Name "brave","BraveUpdate" -Force -ErrorAction SilentlyContinue

@("${env:ProgramFiles}\BraveSoftware\Brave-Browser", "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser") | 
    Where-Object { Test-Path $_ } | ForEach-Object { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue }

# 2. Download and install latest version
Write-Host "Checking for latest version..." -ForegroundColor Cyan
$release = Invoke-RestMethod "https://api.github.com/repos/brave/brave-browser/releases/latest"
$downloadUrl = ($release.assets | Where-Object { $_.name -eq "BraveBrowserSetup.exe" }).browser_download_url

Write-Host "Latest version: $($release.tag_name)" -ForegroundColor Yellow

Write-Host "Downloading URL: $downloadUrl..." -ForegroundColor Cyan
(New-Object System.Net.WebClient).DownloadFile($downloadUrl, "$env:TEMP\BraveBrowserSetup.exe")

Write-Host "Installing..." -ForegroundColor Cyan
Start-Process "$env:TEMP\BraveBrowserSetup.exe" -ArgumentList "/silent /install" -Wait

# 3. Remove scheduled tasks and update folders
Get-ScheduledTask -TaskName "BraveSoftware*" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false

@("${env:ProgramFiles}\BraveSoftware\Update", "${env:ProgramFiles(x86)}\BraveSoftware\Update") | 
    Where-Object { Test-Path $_ } | ForEach-Object { 
        Stop-Process -Name "BraveUpdate" -Force -ErrorAction SilentlyContinue
        Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue
    }

# 4. Apply registry optimizations
Write-Host "Applying optimizations..." -ForegroundColor Cyan
(New-Object System.Net.WebClient).DownloadFile("https://raw.githubusercontent.com/bibicadotnet/brave-browser-debloat/refs/heads/main/disable_brave_features.reg", "$env:TEMP\optimize.reg")
Start-Process "regedit.exe" -ArgumentList "/s `"$env:TEMP\optimize.reg`"" -Wait -NoNewWindow

# Cleanup
Remove-Item "$env:TEMP\BraveBrowserSetup.exe", "$env:TEMP\optimize.reg" -Force -ErrorAction SilentlyContinue
Write-Host "Brave Browser installation completed!" -ForegroundColor Green
