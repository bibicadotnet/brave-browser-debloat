# Brave Browser Auto Installer
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'

# Require Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if ([string]::IsNullOrEmpty($PSCommandPath)) {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://go.bibica.net/brave | iex`"" -Verb RunAs
    } else {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    }
    exit
}

try {
    # Cleanup old installation
    Write-Host "Cleaning up old installation..." -ForegroundColor Cyan
    $paths = @("${env:ProgramFiles}\BraveSoftware\Brave-Browser", "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser")
    foreach ($path in $paths) {
        if (Test-Path $path) {
            Stop-Process -Name "brave","BraveUpdate" -Force -ErrorAction SilentlyContinue
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cleaned: $path" -ForegroundColor Green
        }
    }

    # Download and install
    $folder = "$env:USERPROFILE\Downloads\BraveInstall"
    $installer = "$folder\BraveBrowserSetup.exe"
    New-Item -ItemType Directory -Path $folder -Force | Out-Null

    Write-Host "Checking for latest Brave Browser version..." -ForegroundColor Cyan
    $release = Invoke-RestMethod "https://api.github.com/repos/brave/brave-browser/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -eq "BraveBrowserSetup.exe" }
    $latestVersion = $release.tag_name
    Write-Host "Downloading Brave Browser $($latestVersion)..." -ForegroundColor Cyan
    (New-Object System.Net.WebClient).DownloadFile($asset.browser_download_url, $installer)

    Write-Host "Installing Brave Browser..." -ForegroundColor Cyan
    Start-Process -FilePath $installer -ArgumentList "/silent /install" -Wait

    # Apply registry settings
    Write-Host "Applying registry settings..." -ForegroundColor Cyan
    $restoreReg = "$folder\restore.reg"
    $optimizeReg = "$folder\optimize.reg"
    
    Invoke-WebRequest "https://raw.githubusercontent.com/bibicadotnet/brave-browser-debloat/refs/heads/main/restore_brave_features.reg" -OutFile $restoreReg -UseBasicParsing
    Invoke-WebRequest "https://raw.githubusercontent.com/bibicadotnet/brave-browser-debloat/refs/heads/main/disable_brave_features.reg" -OutFile $optimizeReg -UseBasicParsing
    
    Start-Process "regedit.exe" -ArgumentList "/s `"$restoreReg`"" -Wait -NoNewWindow
    Start-Process "regedit.exe" -ArgumentList "/s `"$optimizeReg`"" -Wait -NoNewWindow

    # Disable updates
    Write-Host "Disabling auto updates..." -ForegroundColor Cyan
    
    # Remove update tasks
    @("BraveSoftwareUpdateTaskMachineCore*", "BraveSoftwareUpdateTaskMachineUA*") | ForEach {
        Get-ScheduledTask -TaskName $_ -ErrorAction SilentlyContinue | ForEach {
            $_ | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
            $_ | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            Write-Host "Removed task: $($_.TaskName)" -ForegroundColor Green
        }
    }
    
    # Disable update exe
    @("${env:ProgramFiles}\BraveSoftware\Update\BraveUpdate.exe", "${env:ProgramFiles(x86)}\BraveSoftware\Update\BraveUpdate.exe") | ForEach {
        if (Test-Path $_) {
            $file = Get-Item $_
            Get-Process -Name $file.BaseName -ErrorAction SilentlyContinue | Stop-Process -Force
            Rename-Item $_ "$_.disabled" -Force
            New-Item $_ -ItemType File -Force | Out-Null
            (Get-Item $_).Attributes = "ReadOnly, Hidden, System"
            Write-Host "Disabled: $($file.Name)" -ForegroundColor Green
        }
    }

    # Cleanup
    Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "`nBrave Browser installation completed!" -ForegroundColor Green

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Read-Host "Press Enter to exit"
}