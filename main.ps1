Clear-Host

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script needs to be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click on the script → 'Run with PowerShell as administrator'" -ForegroundColor Yellow
    Write-Host ""
    pause
    exit
}

$desktop = [Environment]::GetFolderPath("Desktop")
$setupPath = "$desktop\Apps"
$downloadPath = "$setupPath\Installers"
$configPath = "$setupPath\Configs"
$benchmarkPath = "$setupPath\Benchmark"

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
    New-Item -ItemType Directory -Path $benchmarkPath -Force | Out-Null
}

function Create-ConfigTutorial {
    $readmePath = "$configPath\README_Config_Files.txt"
    $content = @"
RESET TOOL - CONFIG FILES TUTORIAL
=================================

The config files have been downloaded to:
$configPath

WHERE TO PUT EACH FILE:

1. grijs.ini
2. kleurtjes.ini
   → %localappdata%\FiveM\FiveM.app\plugins\

3. fivem.cfg
   → %appdata%\CitizenFX\
   (Example: C:\Users\<YourUser>\AppData\Roaming\CitizenFX\)

4. gta5_settings.xml
   → %appdata%\CitizenFX\

5. camera_save_structure.xml
   → %appdata%\CitizenFX\

How to use:
- Copy each file to the folder listed above.
- Overwrite the existing file if prompted.
- Restart FiveM before launching your server.

Good luck!
"@

    $content | Out-File -FilePath $readmePath -Encoding UTF8
    Write-Host "Tutorial (README_Config_Files.txt) created!" -ForegroundColor Green
}
function Download-Configs {
    Make-Folders
    $files = @("grijs.ini","kleurtjes.ini","camera_save_structure.xml","fivem.cfg","gta5_settings.xml")
    foreach ($file in $files) {
        Write-Host "Downloading $file..." -ForegroundColor Yellow
        Invoke-WebRequest "$repo/$file" -OutFile "$configPath\$file" -UseBasicParsing
    }
    Create-ConfigTutorial
    Write-Host "Configs opgeslagen in $configPath" -ForegroundColor Green
}

function Run-UserBenchmark {
    $confirm = Read-Host "Do you want to download UserBenchmark Installer from https://www.userbenchmark.com/? (Y/N)"
    if ($confirm -notmatch "^[Yy]$") {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }

    Make-Folders
    Write-Host "Downloading UserBenchmark Installer..." -ForegroundColor Yellow
    $installerPath = "$benchmarkPath\UserBenchmarkInstaller.exe"
    
    Invoke-WebRequest "https://www.userbenchmark.com/resources/download/UserBenchmarkInstaller.exe" -OutFile $installerPath -UseBasicParsing
    
    Write-Host "Running UserBenchmark Installer..." -ForegroundColor Green
    Start-Process $installerPath
}

Write-Host "=================================" -ForegroundColor Cyan
Write-Host "       Reset Tool" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Alles installeren"
Write-Host "2. Zelf kiezen"
Write-Host "3. Alles downloaden naar Apps\Installers"
Write-Host "4. Configs downloaden naar Apps\Configs"
Write-Host "5. Open Chris Titus Tool"
Write-Host "6. Download & Run UserBenchmark Installer"
Write-Host "0. Exit"
Write-Host ""

$choice = Read-Host "Maak een keuze"

switch ($choice) {
    "1" {
        foreach ($app in $apps.Keys) {
            Write-Host "Installeren van $app..." -ForegroundColor Yellow
            winget install --id $apps[$app] --source winget -e --accept-package-agreements --accept-source-agreements --silent
        }

        Write-Host "`nSpotify installeren..." -ForegroundColor Yellow
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
    "2" {
        foreach ($app in $apps.Keys) {
            $answer = Read-Host "Wil je $app installeren? (Y/N)"
            if ($answer -match "^[Yy]$") {
                Write-Host "Installeren van $app..." -ForegroundColor Yellow
                winget install --id $apps[$app] --source winget -e --accept-package-agreements --accept-source-agreements --silent
            }
        }

        $answer = Read-Host "Wil je Spotify installeren? (Y/N)"
        if ($answer -match "^[Yy]$") {
            Write-Host "Spotify installeren..." -ForegroundColor Yellow
            $spotifyTemp = "$env:TEMP\Spotify_Setup.exe"
            Invoke-WebRequest "https://download.scdn.co/SpotifySetup.exe" -OutFile $spotifyTemp -UseBasicParsing
            Start-Process $spotifyTemp -ArgumentList "/Silent" -Wait -NoNewWindow
        }

        $answer = Read-Host "Wil je NVIDIA App installeren? (Y/N)"
        if ($answer -match "^[Yy]$") {
            Write-Host "NVIDIA App..." -ForegroundColor Yellow
            $nvidiaTemp = "$env:TEMP\NVIDIA_App_Setup.exe"
            Invoke-WebRequest $nvidiaUrl -OutFile $nvidiaTemp -UseBasicParsing
            Start-Process $nvidiaTemp -Wait
        }
        Write-Host "`nKlaar!" -ForegroundColor Green
        Clear-Host
    }
    "3" {
        Make-Folders
        foreach ($app in $apps.Values) {
            Write-Host "Downloading $app..." -ForegroundColor Yellow
            winget download --id $app --source winget -e --download-directory $downloadPath
        }
        Invoke-WebRequest "https://download.scdn.co/SpotifySetup.exe" -OutFile "$downloadPath\Spotify_Setup.exe" -UseBasicParsing
        Invoke-WebRequest $nvidiaUrl -OutFile "$downloadPath\NVIDIA_App_Setup.exe" -UseBasicParsing
        
        Remove-Item "$downloadPath\*.yaml" -Force -ErrorAction SilentlyContinue
        Write-Host "`nKlaar!" -ForegroundColor Green
        Clear-Host
    }
    "4" {
        Download-Configs
        Clear-Host
    }
    "5" {
        Write-Host "Opening Chris Titus Tool..." -ForegroundColor Cyan
        try {
            Invoke-RestMethod -Uri "https://christitus.com/win" -UseBasicParsing | Invoke-Expression
        } catch {
            Write-Host "Could not load Chris Titus Tool." -ForegroundColor Red
        }
        Clear-Host
    }
    "6" {
        Run-UserBenchmark
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
