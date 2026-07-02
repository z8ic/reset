# =============================================
# Auto Elevate to Administrator
# =============================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting Administrator rights..." -ForegroundColor Yellow
    Write-Host "(A UAC window should appear - click Yes)" -ForegroundColor Gray
    pause
    
    $scriptPath = $MyInvocation.MyCommand.Path
    if ($scriptPath) {
        try {
            Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
            exit
        }
        catch {
            Write-Host "Failed to elevate to Administrator." -ForegroundColor Red
            Write-Host "Please right-click the script and select 'Run as administrator'" -ForegroundColor Yellow
            pause
            exit
        }
    }
}

Clear-Host

$desktop = [Environment]::GetFolderPath("Desktop")
$setupPath = "$desktop\Apps"
$downloadPath = "$setupPath\Installers"
$configPath = "$setupPath\Configs"

$repo = "https://raw.githubusercontent.com/z8ic/reset/main"
$nvidiaUrl = "https://us.download.nvidia.com/nvapp/client/11.0.7.247/NVIDIA_app_v11.0.7.247.exe"

$apps = @{
    "Discord"           = "Discord.Discord"
    "Epic Games"        = "EpicGames.EpicGamesLauncher"
    "Steam"             = "Valve.Steam"
    "Brave"             = "Brave.Brave"
    "Rockstar Launcher" = "RockstarGames.Launcher"
    "FiveM"             = "Cfx.re.FiveM"
    "ReShade"           = "Reshade.Setup"
}

function Make-Folders {
    New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
    New-Item -ItemType Directory -Path $configPath -Force | Out-Null
}

function Download-Configs {
    Make-Folders
    $files = @("grijs.ini","kleurtjes.ini","camera_save_structure.xml","fivem.cfg","gta5_settings.xml")
    foreach ($file in $files) {
        Write-Host "Downloading $file..." -ForegroundColor Yellow
        Invoke-WebRequest "$repo/$file" -OutFile "$configPath\$file" -UseBasicParsing
    }
    Write-Host "Configs opgeslagen in $configPath" -ForegroundColor Green
}

Write-Host "=================================" -ForegroundColor Cyan
Write-Host "       Reset Tool" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Alles installeren"
Write-Host "2. Zelf kiezen"
Write-Host "3. Alles downloaden naar Apps\Installers"
Write-Host "4. Configs downloaden naar Apps\Configs"
Write-Host "5. Open Chris Titus Tool (winutil)"
Write-Host "6. Run Trusted Benchmark (Cinebench)"
Write-Host "0. Exit"
Write-Host ""

$choice = Read-Host "Maak een keuze"

switch ($choice) {
    "1" {
        foreach ($app in $apps.Keys) {
            Write-Host "Installeren van $app..." -ForegroundColor Yellow
            winget install --id $apps[$app] --source winget -e --accept-package-agreements --accept-source-agreements --silent
        }

        Write-Host "`nSpotify installeren (silent)..." -ForegroundColor Yellow
        $spotifyTemp = "$env:TEMP\Spotify_Setup.exe"
        Invoke-WebRequest "https://download.scdn.co/SpotifySetup.exe" -OutFile $spotifyTemp -UseBasicParsing
        Start-Process $spotifyTemp -ArgumentList "/Silent" -Wait -NoNewWindow

        Write-Host "NVIDIA App..." -ForegroundColor Yellow
        $nvidiaTemp = "$env:TEMP\NVIDIA_App_Setup.exe"
        Invoke-WebRequest $nvidiaUrl -OutFile $nvidiaTemp -UseBasicParsing
        Start-Process $nvidiaTemp -Wait

        Write-Host "`nKlaar!" -ForegroundColor Green
        Download-Configs
        Clear-Host
    }
    "2" { ... }   # (I shortened it here to save space - keep your existing "2" block)
    "3" { ... }
    "4" { ... }
    "5" { ... }
    "6" {
        Write-Host "Launching Cinebench R24 (Trusted Benchmark)..." -ForegroundColor Cyan
        try {
            Start-Process "https://www.maxon.net/en/downloads/cinebench-2024"
            Write-Host "Cinebench page opened. Download and run the latest version." -ForegroundColor Green
        }
        catch {
            Write-Host "Could not open benchmark link." -ForegroundColor Red
        }
        Clear-Host
    }
    "0" {
        Write-Host "Tot ziens, boss!" -ForegroundColor Cyan
        Clear-Host
        exit
    }
    Default {
        Write-Host "Ongeldige keuze." -ForegroundColor Red
        Clear-Host
    }
}

Pause
