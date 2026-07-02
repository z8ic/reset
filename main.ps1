Clear-Host

$desktop = [Environment]::GetFolderPath("Desktop")
$setupPath = "$desktop\Apps"
$downloadPath = "$setupPath\Installers"
$configPath = "$setupPath\Configs"

$repo = "https://raw.githubusercontent.com/z8ic/reset/main"
$nvidiaUrl = "https://us.download.nvidia.com/nvapp/client/11.0.7.247/NVIDIA_app_v11.0.7.247.exe"

$apps = @{
    "Discord"           = "Discord.Discord"
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
    Invoke-WebRequest "$repo/grijs.ini" -OutFile "$configPath\grijs.ini"
    Invoke-WebRequest "$repo/kleurtjes.ini" -OutFile "$configPath\kleurtjes.ini"
    Invoke-WebRequest "$repo/camera_save_structure.xml" -OutFile "$configPath\camera_save_structure.xml"
    Invoke-WebRequest "$repo/fivem.cfg" -OutFile "$configPath\fivem.cfg"
    Invoke-WebRequest "$repo/gta5_settings.xml" -OutFile "$configPath\gta5_settings.xml"
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
Write-Host ""

$choice = Read-Host "Maak een keuze"

switch ($choice) {
    "1" {
        foreach ($app in $apps.Keys) {
            Write-Host "Installeren van $app..." -ForegroundColor Yellow
            winget install --id $apps[$app] -e --accept-package-agreements --accept-source-agreements
        }
        Write-Host "Spotify installeren..." -ForegroundColor Yellow
        $spotifyTemp = "$env:TEMP\Spotify_Setup.exe"
        Invoke-WebRequest "https://download.scdn.co/SpotifySetup.exe" -OutFile $spotifyTemp
        Start-Process $spotifyTemp -Wait

        Write-Host "NVIDIA App installeren..." -ForegroundColor Yellow
        $nvidiaTemp = "$env:TEMP\NVIDIA_App_Setup.exe"
        Invoke-WebRequest $nvidiaUrl -OutFile $nvidiaTemp
        Start-Process $nvidiaTemp -Wait

        Write-Host "Klaar!" -ForegroundColor Green
        Download-Configs
    }
    "2" {
        foreach ($app in $apps.Keys) {
            $answer = Read-Host "Wil je $app installeren? (Y/N)"
            if ($answer -match "^[Yy]$") {
                winget install --id $apps[$app] -e --accept-package-agreements --accept-source-agreements
            }
        }
        $answer = Read-Host "Wil je Spotify installeren? (Y/N)"
        if ($answer -match "^[Yy]$") {
            $spotifyTemp = "$env:TEMP\Spotify_Setup.exe"
            Invoke-WebRequest "https://download.scdn.co/SpotifySetup.exe" -OutFile $spotifyTemp
            Start-Process $spotifyTemp -Wait
        }
        $answer = Read-Host "Wil je NVIDIA App installeren? (Y/N)"
        if ($answer -match "^[Yy]$") {
            $nvidiaTemp = "$env:TEMP\NVIDIA_App_Setup.exe"
            Invoke-WebRequest $nvidiaUrl -OutFile $nvidiaTemp
            Start-Process $nvidiaTemp -Wait
        }
        Write-Host "Klaar!" -ForegroundColor Green
    }
    "3" {
        Make-Folders
        foreach ($app in $apps.Values) {
            Write-Host "Downloaden van $app..." -ForegroundColor Yellow
            winget download --id $app -e --download-directory $downloadPath
        }
        Invoke-WebRequest "https://download.scdn.co/SpotifySetup.exe" -OutFile "$downloadPath\Spotify_Setup.exe"
        Invoke-WebRequest $nvidiaUrl -OutFile "$downloadPath\NVIDIA_App_Setup.exe"
        Write-Host "Installers opgeslagen in $downloadPath" -ForegroundColor Green
    }
    "4" {
        Download-Configs
    }
    Default {
        Write-Host "Ongeldige keuze." -ForegroundColor Red
    }
}

Pause
