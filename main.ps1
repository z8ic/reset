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

        Write-Host "`nKlaar! Druk op Enter om te sluiten..." -ForegroundColor Green
        Download-Configs
        Read-Host
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
            Write-Host "Spotify installeren (silent)..." -ForegroundColor Yellow
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
        Write-Host "`nKlaar! Druk op Enter om te sluiten..." -ForegroundColor Green
        Read-Host
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
        Write-Host "`nKlaar! Druk op Enter om te sluiten..." -ForegroundColor Green
        Read-Host
        Clear-Host
    }
    "4" {
        Download-Configs
        Write-Host "`nKlaar! Druk op Enter om te sluiten..." -ForegroundColor Green
        Read-Host
        Clear-Host
    }
    "5" {
        Write-Host "Opening Chris Titus Tool (winutil)..." -ForegroundColor Cyan
        try {
            irm christitus.com/win | iex
        }
        catch {
            Write-Host "Error loading Chris Titus Tool:" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-Host "Check your internet connection or try running the script as Administrator." -ForegroundColor Yellow
        }
        Read-Host "`nDruk op Enter om terug te gaan..."
        Clear-Host
    }
    "0" {
        Write-Host "Tot ziens, boss!" -ForegroundColor Cyan
        Clear-Host
        exit
    }
    Default {
        Write-Host "Ongeldige keuze." -ForegroundColor Red
        Read-Host
        Clear-Host
    }
}

Pause
