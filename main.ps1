Clear-Host

#Requires -RunAsAdministrator
# Reset Tool v2.0 - Volledig Automatisch
# Alles wordt automatisch op de juiste plek gezet: configs + mods (.rpf / sound packs) + apps

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Dit script moet als Administrator worden uitgevoerd!" -ForegroundColor Red
    Write-Host "Rechtsklik -> 'Als administrator uitvoeren'" -ForegroundColor Yellow
    Write-Host ""
    pause
    exit
}

# ================= CONFIG =================
$Version = "2.5 - VS Code + Clean README"
$desktop = [Environment]::GetFolderPath("Desktop")
$setupPath = "$desktop\Apps"
$downloadPath = "$setupPath\Installers"
$configPath = "$setupPath\Configs"
$benchmarkPath = "$setupPath\Benchmark"
$modsLocalPath = "$setupPath\Mods"
$modsStagingPath = "$env:TEMP\ResetMods"

$repo = "https://raw.githubusercontent.com/z8ic/reset/main"
$repoApiMods = "https://api.github.com/repos/z8ic/reset/contents/mods"
$repoApiSounds = "https://api.github.com/repos/z8ic/reset/contents/sounds"

# NVIDIA App - geupdate naar laatste versie (11.0.8.299 - aug 2026). Script probeert altijd winget eerst, daarna direct URL.
$nvidiaUrl = "https://us.download.nvidia.com/nvapp/client/11.0.8.299/NVIDIA_app_v11.0.8.299.exe"

# Joker's Packs - Google Drive IDs (automatisch)
$jokersSoundPackId = "15EgtE-bz1lIsp5GvzBL-DkIVMzhoEBsQ"
$jokersModsId = "1NP12LePk7HfBd3cINCHsaYG66FgUkh6a"
$jokersSoundPackUrl = "https://drive.google.com/drive/folders/$jokersSoundPackId"
$jokersModsUrl = "https://drive.google.com/drive/folders/$jokersModsId"
$customBloodModFileId = "1YrZNY63l3STl_lmRGaoFbNlFjHGM-1U6"
$customBloodModUrl = "https://drive.google.com/file/d/$customBloodModFileId/view?usp=sharing"
$customMinimapFileId = "1HTD6ujiV_fJ49bNcybLw-9Bqjfdj50Ag"
$customMinimapUrl = "https://drive.google.com/file/d/$customMinimapFileId/view?usp=sharing"

# Updated winget IDs - 2026 verified - inclusief WinRAR, VLC, VS Code etc
$apps = @{
    "Discord"             = "Discord.Discord"
    "Epic Games"          = "EpicGames.EpicGamesLauncher"
    "Steam"               = "Valve.Steam"
    "Brave"               = "Brave.Brave"
    "Rockstar Launcher"   = "RockstarGames.Launcher"
    "FiveM"               = "Cfx.re.FiveM"
    "ReShade"             = "ReShade.Setup"
    "Spotify"             = "Spotify.Spotify"
    "WinRAR"              = "RARLab.WinRAR"
    "VLC"                 = "VideoLAN.VLC"
    "Visual Studio Code"  = "Microsoft.VisualStudioCode"
}

$logFile = "$setupPath\reset_log.txt"

# ================= HELPER FUNCTIES =================
function Write-Log {
    param([string]$msg, [string]$color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $msg" -ForegroundColor $color
    try { "[$timestamp] $msg" | Out-File -Append -FilePath $logFile -Encoding UTF8 } catch {}
}

function Write-Header {
    Clear-Host
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host "       Reset Tool v$Version" -ForegroundColor Cyan
    Write-Host "   Volledig Automatisch | z8ic" -ForegroundColor DarkCyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-Winget {
    try {
        $null = Get-Command winget -ErrorAction Stop
        return $true
    } catch {
        Write-Log "winget niet gevonden! Installeer App Installer via Microsoft Store." "Red"
        return $false
    }
}

function Update-WingetSource {
    if (-not (Test-Winget)) { return }
    Write-Log "Winget sources updaten..." "Gray"
    try { winget source update --disable-interactivity | Out-Null } catch {}
}

function Download-FileWithRetry {
    param(
        [string]$Url,
        [string]$OutFile,
        [int]$Retries = 3
    )
    for ($i=1; $i -le $Retries; $i++) {
        try {
            # Gebruik TLS 1.2
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
            if (Test-Path $OutFile) { return $true }
        } catch {
            Write-Log "Download poging $i mislukt voor $Url : $($_.Exception.Message)" "Yellow"
            Start-Sleep -Seconds 2
        }
    }
    return $false
}

function Backup-File {
    param([string]$Path)
    if (Test-Path $Path) {
        $backupDir = Split-Path $Path -Parent
        $fileName = Split-Path $Path -Leaf
        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = Join-Path $backupDir "$fileName.bak_$stamp"
        try {
            Copy-Item -Path $Path -Destination $backupPath -Force
            Write-Log "Backup gemaakt: $backupPath" "DarkGray"
        } catch {
            Write-Log "Backup mislukt voor $Path" "Yellow"
        }
    }
}

function Get-FiveMPath {
    $candidates = @(
        "$env:LOCALAPPDATA\FiveM\FiveM.exe",
        "$env:LOCALAPPDATA\FiveM\FiveM.app\FiveM.exe",
        "$env:APPDATA\CitizenFX\FiveM.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            return Split-Path $c -Parent
        }
    }
    # Zoek via localappdata\FiveM
    $p = "$env:LOCALAPPDATA\FiveM"
    if (Test-Path $p) { return $p }
    return $null
}

function Get-GTAPath {
    $pathsToTest = @()

    # Registry - Rockstar
    try {
        $reg = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Rockstar Games\Grand Theft Auto V" -ErrorAction SilentlyContinue
        if ($reg -and $reg.InstallFolder -and (Test-Path "$($reg.InstallFolder)\GTA5.exe")) { return $reg.InstallFolder }
        if ($reg -and $reg.InstallFolder) { $pathsToTest += $reg.InstallFolder }
    } catch {}
    try {
        $reg2 = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Rockstar Games\GTAV" -ErrorAction SilentlyContinue
        if ($reg2 -and $reg2.InstallFolder -and (Test-Path "$($reg2.InstallFolder)\GTA5.exe")) { return $reg2.InstallFolder }
        if ($reg2 -and $reg2.InstallFolder) { $pathsToTest += $reg2.InstallFolder }
    } catch {}
    try {
        $reg3 = Get-ItemProperty "HKLM:\SOFTWARE\Rockstar Games\Grand Theft Auto V" -ErrorAction SilentlyContinue
        if ($reg3 -and $reg3.InstallFolder -and (Test-Path "$($reg3.InstallFolder)\GTA5.exe")) { return $reg3.InstallFolder }
    } catch {}

    # Steam default locaties
    $pathsToTest += @(
        "${env:ProgramFiles(x86)}\Steam\steamapps\common\Grand Theft Auto V",
        "$env:ProgramFiles\Steam\steamapps\common\Grand Theft Auto V",
        "C:\Program Files (x86)\Steam\steamapps\common\Grand Theft Auto V"
    )
    # Epic
    $pathsToTest += @(
        "$env:ProgramFiles\Epic Games\GTAV",
        "$env:ProgramFiles\Epic Games\Grand Theft Auto V",
        "C:\Program Files\Epic Games\GTAV"
    )

    foreach ($p in $pathsToTest) {
        if ($p -and (Test-Path "$p\GTA5.exe")) { return $p }
    }

    # Steam libraryfolders.vdf parsen
    $steamVdf = "${env:ProgramFiles(x86)}\Steam\steamapps\libraryfolders.vdf"
    if (-not (Test-Path $steamVdf)) { $steamVdf = "$env:ProgramFiles\Steam\steamapps\libraryfolders.vdf" }
    if (Test-Path $steamVdf) {
        try {
            $content = Get-Content $steamVdf | Out-String
            $matches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
            foreach ($m in $matches) {
                $lib = $m.Groups[1].Value -replace '\\\\','\'
                $candidate = Join-Path $lib "steamapps\common\Grand Theft Auto V"
                if (Test-Path "$candidate\GTA5.exe") { return $candidate }
            }
        } catch {}
    }

    return $null
}

function Make-Folders {
    New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
    New-Item -ItemType Directory -Path $configPath -Force | Out-Null
    New-Item -ItemType Directory -Path $benchmarkPath -Force | Out-Null
    New-Item -ItemType Directory -Path $modsLocalPath -Force | Out-Null
    New-Item -ItemType Directory -Path $modsStagingPath -Force | Out-Null
    # Log folder
    New-Item -ItemType Directory -Path $setupPath -Force | Out-Null
}

function Install-AppWinget {
    param(
        [string]$Name,
        [string]$WingetId
    )
    Write-Log "Installeren van $Name ($WingetId)..." "Yellow"
    if (-not (Test-Winget)) {
        Write-Log "winget niet beschikbaar, sla $Name over" "Red"
        return $false
    }
    try {
        # Check of al geinstalleerd
        $list = winget list --id $WingetId -e --disable-interactivity 2>&1 | Out-String
        if ($list -match [regex]::Escape($WingetId)) {
            Write-Log "$Name is al geinstalleerd, probeer te updaten..." "Gray"
            winget upgrade --id $WingetId -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
            Write-Log "$Name geupdate (of al up-to-date)" "Green"
            return $true
        }
    } catch {}

    $args = "install --id $WingetId -e --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity"
    try {
        $proc = Start-Process -FilePath "winget" -ArgumentList $args -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 1641 -or $proc.ExitCode -eq 3010) {
            Write-Log "$Name succesvol geinstalleerd!" "Green"
            return $true
        } else {
            Write-Log "$Name installatie exit code: $($proc.ExitCode) - probeer opnieuw" "Yellow"
            # retry once met --force?
            Start-Sleep 2
            $proc2 = Start-Process -FilePath "winget" -ArgumentList $args -Wait -PassThru -NoNewWindow
            if ($proc2.ExitCode -eq 0) { Write-Log "$Name gelukt bij 2e poging" "Green"; return $true }
            Write-Log "$Name mislukt" "Red"
            return $false
        }
    } catch {
        Write-Log "Fout bij $Name : $($_.Exception.Message)" "Red"
        return $false
    }
}

function Install-SpotifyAuto {
    Write-Log "Spotify installeren..." "Yellow"
    $success = Install-AppWinget -Name "Spotify" -WingetId "Spotify.Spotify"
    if ($success) { return }
    # Fallback direct download
    Write-Log "Fallback: Spotify direct download..." "Gray"
    $spotifyTemp = "$env:TEMP\Spotify_Setup.exe"
    if (Download-FileWithRetry -Url "https://download.scdn.co/SpotifySetup.exe" -OutFile $spotifyTemp) {
        try { Start-Process $spotifyTemp -Wait -NoNewWindow; Write-Log "Spotify direct geinstalleerd" "Green" } catch { Write-Log "Spotify fallback mislukt" "Red" }
    }
}

function Install-NvidiaAppAuto {
    Write-Log "NVIDIA App installeren..." "Yellow"
    # Probeer eerst winget (er zijn nu community packages: Nvidia.App? maar fallback naar direct)
    # We proberen bekende IDs
    $nvidiaIds = @("Nvidia.App", "Nvidia.NvidiaApp", "Nvidia.GeForceExperience")
    $installed = $false
    foreach ($id in $nvidiaIds) {
        try {
            $test = winget search --id $id -e --disable-interactivity 2>&1 | Out-String
            if ($test -match $id) {
                if (Install-AppWinget -Name "NVIDIA App" -WingetId $id) { $installed = $true; break }
            }
        } catch {}
    }
    if ($installed) { return }

    Write-Log "NVIDIA App via direct download (laatste versie 11.0.8.299)..." "Gray"
    $nvidiaTemp = "$env:TEMP\NVIDIA_App_Setup.exe"
    if (Download-FileWithRetry -Url $nvidiaUrl -OutFile $nvidiaTemp) {
        Write-Log "NVIDIA installer gedownload, starten..." "Yellow"
        try { Start-Process $nvidiaTemp -Wait; Write-Log "NVIDIA App geinstalleerd" "Green" } catch { Write-Log "NVIDIA install mislukt: $($_.Exception.Message)" "Red" }
    } else {
        Write-Log "NVIDIA download mislukt! Check URL: $nvidiaUrl" "Red"
    }
}

function Install-VCRedistDirectX {
    Write-Log "=== Game Prerequisites installeren (VCRedist + DirectX) ===" "Cyan"
    # VCRedist via winget - 2015+ (dekt 2015-2022) x64 + x86 = meeste games
    $vcPackages = @(
        "Microsoft.VCRedist.2015+.x64",
        "Microsoft.VCRedist.2015+.x86"
    )
    foreach ($pkg in $vcPackages) {
        Write-Log "Installeren $pkg..." "Yellow"
        Install-AppWinget -Name $pkg -WingetId $pkg | Out-Null
    }
    # Fallback: Direct download AIO van abbodi1406 (als winget faalt)
    # DirectX End-User Runtime
    Write-Log "DirectX installeren..." "Yellow"
    $dxTemp = "$env:TEMP\dxwebsetup.exe"
    $dxUrl = "https://download.microsoft.com/download/1/7/1/1576D19E-A53B-4D84-812D-395A3BC0A74B/dxwebsetup.exe"
    if (Download-FileWithRetry -Url $dxUrl -OutFile $dxTemp) {
        try { Start-Process $dxTemp -ArgumentList "/Q" -Wait -NoNewWindow; Write-Log "DirectX geinstalleerd" "Green" } catch { Write-Log "DirectX mislukt: $($_.Exception.Message)" "Yellow" }
    } else {
        # probeer winget als fallback
        try { Install-AppWinget -Name "DirectX" -WingetId "Microsoft.DirectX" | Out-Null } catch {}
    }
    # .NET 8 runtimes (nodig voor veel FiveM mods/tools)
    Write-Log ".NET Runtimes check..." "Gray"
    try { winget install --id Microsoft.DotNet.DesktopRuntime.8 --silent --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null } catch {}
    Write-Log "Game Prereqs klaar!" "Green"
}

function Invoke-WindowsUpdateAuto {
    Write-Log "=== Windows Update check (belangrijk na reset!) ===" "Cyan"
    try {
        # Probeer PSWindowsUpdate module
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Log "PSWindowsUpdate module installeren..." "Gray"
            try { Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
            try { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue } catch {}
            try { Install-Module PSWindowsUpdate -Force -SkipPublisherCheck -Confirm:$false -ErrorAction SilentlyContinue | Out-Null } catch { Write-Log "PSWindowsUpdate install mislukt, gebruik fallback COM" "Yellow" }
        }
        Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
        if (Get-Command Get-WindowsUpdate -ErrorAction SilentlyContinue) {
            Write-Log "Zoeken naar Windows Updates (kan 5-10 min duren na reset)..." "Yellow"
            try {
                $updates = Get-WindowsUpdate -Severity Important, Critical -ErrorAction SilentlyContinue
                if ($updates) {
                    Write-Log "$($updates.Count) updates gevonden, installeren..." "Yellow"
                    Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot -ErrorAction SilentlyContinue | Out-Null
                    Write-Log "Windows Updates geinstalleerd (reboot mogelijk nodig)" "Green"
                } else {
                    Write-Log "Geen belangrijke updates gevonden of al up-to-date" "Green"
                }
            } catch { Write-Log "Windows Update via PSWindowsUpdate mislukt: $($_.Exception.Message)" "Yellow" }
        } else {
            # Fallback: gebruik COM object
            Write-Log "Fallback COM Windows Update..." "Gray"
            try {
                $Session = New-Object -ComObject Microsoft.Update.Session
                $Searcher = $Session.CreateUpdateSearcher()
                $result = $Searcher.Search("IsInstalled=0 and Type='Software'")
                Write-Log "$($result.Updates.Count) updates gevonden via COM" "Yellow"
                if ($result.Updates.Count -gt 0) {
                    Write-Log "Start download & install via COM (kan lang duren)..." "Yellow"
                    $Downloader = $Session.CreateUpdateDownloader()
                    $Downloader.Updates = $result.Updates
                    $Downloader.Download() | Out-Null
                    $Installer = $Session.CreateUpdateInstaller()
                    $Installer.Updates = $result.Updates
                    $InstallResult = $Installer.Install()
                    Write-Log "COM update resultaat: $($InstallResult.ResultCode)" "Green"
                }
            } catch { Write-Log "COM Update mislukt: $($_.Exception.Message)" "Yellow" }
        }
    } catch { Write-Log "Windows Update check overgeslagen: $($_.Exception.Message)" "Yellow" }
    Write-Log "Windows Update check klaar - reboot handmatig als gevraagd!" "Cyan"
}

function Invoke-CTTDebloatAuto {
    param([switch]$Silent)
    Write-Log "=== Debloat & Tweaks (Chris Titus Tool + eigen tweaks) ===" "Cyan"
    # Eigen snelle debloat - verwijder bekende bloatware (alleen safe lijst)
    $bloat = @(
        "Microsoft.3DBuilder","Microsoft.Appconnector","Microsoft.BingFinance","Microsoft.BingNews","Microsoft.BingSports",
        "Microsoft.BingTranslator","Microsoft.BingWeather","Microsoft.FreshPaint","Microsoft.GamingServices","Microsoft.Microsoft3DViewer",
        "Microsoft.MicrosoftOfficeHub","Microsoft.MicrosoftPowerBIForWindows","Microsoft.MicrosoftSolitaireCollection","Microsoft.MicrosoftStickyNotes",
        "Microsoft.MinecraftUWP","Microsoft.NetworkSpeedTest","Microsoft.Office.OneNote","Microsoft.OneConnect","Microsoft.People",
        "Microsoft.Print3D","Microsoft.SkypeApp","Microsoft.Wallet","Microsoft.WindowsAlarms","Microsoft.WindowsCamera",
        "Microsoft.WindowsFeedbackHub","Microsoft.WindowsMaps","Microsoft.WindowsPhone","Microsoft.WindowsSoundRecorder","Microsoft.Xbox.TCUI",
        "Microsoft.XboxApp","Microsoft.XboxGameOverlay","Microsoft.XboxGamingOverlay","Microsoft.XboxIdentityProvider","Microsoft.ZuneMusic","Microsoft.ZuneVideo"
    )
    foreach ($app in $bloat) {
        try {
            Get-AppxPackage -Name $app -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online | Where-Object DisplayName -EQ $app | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
        } catch {}
    }
    Write-Log "Bloatware verwijderd (Xbox etc. behalve essentiële)" "Green"

    # Registry tweaks - perf + privacy (veilig na reset)
    try {
        # Disable telemetry
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name AllowTelemetry -Value 0 -ErrorAction SilentlyContinue
        # Disable Bing in search
        New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Force | Out-Null
        Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name DisableSearchBoxSuggestions -Value 1 -ErrorAction SilentlyContinue
        # Sneller context menu (Win11)
        # ...
        Write-Log "Privacy/Performance tweaks toegepast" "Green"
    } catch { Write-Log "Registry tweaks gedeeltelijk mislukt" "Yellow" }

    if (-not $Silent) {
        $ans = Read-Host "Wil je nu ook het volledige Chris Titus Tool openen voor extra tweaks? (Y/N)"
        if ($ans -match "^[Yy]$") {
            Write-Log "Chris Titus Tool openen..." "Cyan"
            try { Invoke-RestMethod -Uri "https://christitus.com/win" -UseBasicParsing | Invoke-Expression } catch { Write-Log "CTT kon niet laden" "Red" }
        }
    } else {
        Write-Log "Silent modus: sla CTT GUI over, alleen eigen debloat gedaan" "Gray"
    }
}

# ================= CONFIGS AUTO INSTALL =================
function Install-ConfigsAuto {
    Write-Log "=== Configs Automatisch Plaatsen ===" "Cyan"
    Make-Folders

    $fiveMPlugins = "$env:LOCALAPPDATA\FiveM\FiveM.app\plugins"
    $fiveMAppData = "$env:LOCALAPPDATA\FiveM\FiveM.app\data"
    $citizenFX = "$env:APPDATA\CitizenFX"

    # Maak doel mappen aan
    foreach ($p in @($fiveMPlugins, $citizenFX, $fiveMAppData)) {
        if (-not (Test-Path $p)) {
            try { New-Item -ItemType Directory -Path $p -Force | Out-Null; Write-Log "Map aangemaakt: $p" "Gray" } catch {}
        }
    }

    # Definieer waar elk bestand heen moet (AUTOMATISCH) - Joker presets
    $configMap = @{
        "Joker 1.ini"                 = @($fiveMPlugins, $configPath)
        "Joker 2.ini"                 = @($fiveMPlugins, $configPath)
        "Joker 3.ini"                 = @($fiveMPlugins, $configPath)
        "fivem.cfg"                   = @($citizenFX, $configPath)
        "gta5_settings.xml"           = @($citizenFX, $configPath)
        "camera_save_structure.xml"   = @($citizenFX, $configPath)
    }
    # Voor backward compat: als Joker files niet op GitHub staan, pak uit Downloads
    $downloadsPath = "$env:USERPROFILE\Downloads"

    $allSuccess = $true
    foreach ($file in $configMap.Keys) {
        Write-Log "Verwerken $file..." "Yellow"
        $destinations = $configMap[$file]
        $tempFile = "$env:TEMP\$file"

        # Download - probeer GitHub, fallback naar Downloads voor Joker ini's
        $url = "$repo/$file"
        # Encode spaties voor URL
        $urlEncoded = $url -replace " ","%20"
        $downloaded = Download-FileWithRetry -Url $urlEncoded -OutFile $tempFile
        if (-not $downloaded) {
            # Fallback voor Joker files: check Downloads folder
            if ($file -match "Joker") {
                $fallbacks = @(
                    (Join-Path $downloadsPath $file),
                    (Join-Path $downloadsPath ($file -replace " ","_")),
                    (Join-Path $downloadsPath ($file -replace " ","")),
                    (Join-Path $downloadsPath "Joker 1.ini"),
                    (Join-Path $downloadsPath "Joker1.ini"),
                    (Join-Path $downloadsPath "Joker_1.ini")
                )
                # Voor Joker 2 en 3 ook varianten
                if ($file -eq "Joker 2.ini") { $fallbacks += @((Join-Path $downloadsPath "Joker 2.ini"), (Join-Path $downloadsPath "Joker2.ini"), (Join-Path $downloadsPath "Joker_2.ini")) }
                if ($file -eq "Joker 3.ini") { $fallbacks += @((Join-Path $downloadsPath "Joker 3.ini"), (Join-Path $downloadsPath "Joker3.ini"), (Join-Path $downloadsPath "Joker_3.ini")) }
                $found = $null
                foreach ($fb in $fallbacks) { if (Test-Path $fb) { $found = $fb; break } }
                # Ook wildcard zoeken: Joker*.ini in Downloads
                if (-not $found) {
                    $wild = Get-ChildItem -Path $downloadsPath -Filter "Joker*.ini" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match [regex]::Escape($file) -or $_.Name -match "Joker" } | Select-Object -First 1
                    if ($wild) { $found = $wild.FullName }
                }
                if ($found -and (Test-Path $found)) {
                    Write-Log "GitHub mislukt, fallback naar Downloads: $found" "Yellow"
                    try { Copy-Item -Path $found -Destination $tempFile -Force; $downloaded = $true } catch { $downloaded = $false }
                }
                if (-not $downloaded) {
                    Write-Log "Download mislukt voor $file en niet gevonden in Downloads ($downloadsPath) - plaats handmatig Joker 1/2/3.ini in Downloads of push naar GitHub" "Red"
                    $allSuccess = $false
                    continue
                }
            } else {
                Write-Log "Download mislukt voor $file" "Red"
                $allSuccess = $false
                continue
            }
        }

        # Kopieer naar ALLE bestemmingen automatisch
        foreach ($dest in $destinations) {
            $destFile = Join-Path $dest $file
            try {
                if (Test-Path $destFile) { Backup-File -Path $destFile }
                Copy-Item -Path $tempFile -Destination $destFile -Force
                Write-Log "  -> Geplaatst in $destFile" "Green"
            } catch {
                Write-Log "  -> Mislukt voor $destFile : $($_.Exception.Message)" "Red"
                $allSuccess = $false
            }
        }
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }

    # Maak tutorial nog steeds voor referentie, maar nu is alles al automatisch gedaan
    $readmePath = "$configPath\README_AUTO.txt"
    $content = @"
RESET TOOL v2 - AUTOMATISCH GEPLAATST
=====================================
Datum: $(Get-Date)

Alles is AUTOMATISCH geplaatst! Je hoeft NIETS handmatig te kopieren.

Waar staat wat:

1. Joker 1.ini + Joker 2.ini + Joker 3.ini
   -> $fiveMPlugins
   (ReShade presets Joker - automatisch geplaatst, uit Downloads of GitHub)

2. fivem.cfg + gta5_settings.xml + camera_save_structure.xml
   -> $citizenFX
   (FiveM CitizenFX configs - automatisch geplaatst)

Backup: oude bestanden zijn gebackupt als *.bak_*

Je kunt FiveM nu direct starten!
"@
    $content | Out-File -FilePath $readmePath -Encoding UTF8
    Write-Log "README_AUTO.txt gemaakt in $configPath" "Green"

    if ($allSuccess) {
        Write-Log "Alle configs succesvol AUTOMATISCH geplaatst!" "Green"
    } else {
        Write-Log "Configs geplaatst met enkele fouten, check log: $logFile" "Yellow"
    }
    return $allSuccess
}

function Download-ConfigsLegacy {
    # Oude functie behouden voor optie "alleen downloaden" - nu met Joker 1/2/3
    Make-Folders
    $files = @("Joker 1.ini","Joker 2.ini","Joker 3.ini","camera_save_structure.xml","fivem.cfg","gta5_settings.xml")
    foreach ($file in $files) {
        Write-Log "Downloading $file (legacy)..." "Yellow"
        $urlEnc = "$repo/$file" -replace " ","%20"
        try { Invoke-WebRequest $urlEnc -OutFile "$configPath\$file" -UseBasicParsing } catch { Write-Log "Mislukt $file, probeer Downloads fallback" "Yellow"; $fb = "$env:USERPROFILE\Downloads\$file"; if (Test-Path $fb) { Copy-Item $fb "$configPath\$file" -Force } }
    }
    Write-Log "Configs opgeslagen in $configPath (handmatig kopieren nog nodig)" "Yellow"
}

# ================= MODS AUTO INSTALL (.rpf & sound packs) =================
function Get-GithubFolderFiles {
    param([string]$ApiUrl)
    try {
        $headers = @{ "User-Agent" = "ResetTool" }
        $response = Invoke-RestMethod -Uri $ApiUrl -Headers $headers -UseBasicParsing -ErrorAction Stop
        return $response
    } catch {
        Write-Log "Kon GitHub folder niet lezen: $ApiUrl - $($_.Exception.Message)" "Yellow"
        return $null
    }
}

function Ensure-Gdown {
    $hasGdown = Get-Command gdown -ErrorAction SilentlyContinue
    if ($hasGdown) { return $true }
    Write-Log "gdown niet gevonden, proberen te installeren..." "Yellow"
    $hasPython = Get-Command python -ErrorAction SilentlyContinue
    if (-not $hasPython) { $hasPython = Get-Command python3 -ErrorAction SilentlyContinue }
    if (-not $hasPython) {
        Write-Log "Python niet gevonden, installeren via winget..." "Yellow"
        Install-AppWinget -Name "Python 3.12" -WingetId "Python.Python.3.12"
        try { $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") } catch {}
        $hasPython = Get-Command python -ErrorAction SilentlyContinue
        if (-not $hasPython) { $hasPython = Get-Command python3 -ErrorAction SilentlyContinue }
    }
    $pipCommands = @(
        "python -m pip install --quiet --upgrade gdown",
        "pip install --quiet gdown",
        "pip3 install --quiet gdown",
        "python3 -m pip install --quiet --upgrade gdown",
        "python -m pip install --user --quiet gdown"
    )
    foreach ($cmd in $pipCommands) {
        try {
            Write-Log "Probeer: $cmd" "Gray"
            Invoke-Expression $cmd 2>&1 | Out-Null
            $hasGdown = Get-Command gdown -ErrorAction SilentlyContinue
            if ($hasGdown) { Write-Log "gdown succesvol geinstalleerd!" "Green"; return $true }
            # ook check via python -m gdown
            try { python -m gdown --help 2>&1 | Out-Null; if ($LASTEXITCODE -eq 0) { Write-Log "gdown beschikbaar via python -m gdown" "Green"; return $true } } catch {}
        } catch {}
    }
    Write-Log "gdown installatie mislukt, fallback naar handmatige instructie" "Red"
    return $false
}

function Install-JokersPacksAuto {
    param(
        [string]$SoundPackId = $jokersSoundPackId,
        [string]$ModsId = $jokersModsId
    )
    Write-Log "=== Joker's Packs Downloaden (Google Drive) ===" "Magenta"
    Make-Folders
    $gtaPath = Get-GTAPath
    $fiveMPath = Get-FiveMPath
    $gtaModsPath = if ($gtaPath) { Join-Path $gtaPath "mods" } else { $null }
    $gtaAudioMods = if ($gtaPath) { Join-Path $gtaModsPath "x64\audio\sfx" } else { $null }
    $fiveMMods = if ($fiveMPath) { Join-Path $fiveMPath "mods" } else { $null }
    foreach ($p in @($gtaModsPath, $gtaAudioMods, $fiveMMods)) { if ($p -and -not (Test-Path $p)) { try { New-Item -ItemType Directory -Path $p -Force | Out-Null } catch {} } }

    $destSound = Join-Path $modsStagingPath "JokersSoundpack"
    $destMods = Join-Path $modsStagingPath "JokersNVE"
    New-Item -ItemType Directory -Path $destSound -Force | Out-Null
    New-Item -ItemType Directory -Path $destMods -Force | Out-Null
    New-Item -ItemType Directory -Path $modsLocalPath -Force | Out-Null

    # Check gdown
    $hasGdownDirect = Get-Command gdown -ErrorAction SilentlyContinue
    $hasGdownModule = $false
    try { python -m gdown --help 2>&1 | Out-Null; if ($LASTEXITCODE -eq 0) { $hasGdownModule = $true } } catch {}
    $hasGdown = $hasGdownDirect -or $hasGdownModule
    if (-not $hasGdown) { $hasGdown = Ensure-Gdown; $hasGdownDirect = Get-Command gdown -ErrorAction SilentlyContinue }

    if ($hasGdown) {
        $gdownCmd = if ($hasGdownDirect) { "gdown" } else { "python -m gdown" }
        Write-Log "Soundpack downloaden: $jokersSoundPackUrl (3 files ~248MB: ONESHOT_AMBIENCE, RESIDENT, WEAPONS_PLAYER)" "Yellow"
        try {
            $cmd1 = "$gdownCmd --folder `"$jokersSoundPackUrl`" --output `"$destSound`" --remaining-ok"
            Write-Log "Uitvoeren: $cmd1" "Gray"
            Invoke-Expression $cmd1 2>&1 | Out-Null
            Write-Log "Soundpack download klaar" "Green"
        } catch { Write-Log "Soundpack download fout: $($_.Exception.Message)" "Red" }

        Write-Log "NVE Mods downloaden: $jokersModsUrl (9 files, zonder roblox tree.rpf, inclusief EUROPE ROADS 2.88GB - kan even duren!)" "Yellow"
        try {
            $cmd2 = "$gdownCmd --folder `"$jokersModsUrl`" --output `"$destMods`" --remaining-ok"
            Write-Log "Uitvoeren: $cmd2" "Gray"
            Invoke-Expression $cmd2 2>&1 | Out-Null
            Write-Log "NVE download klaar" "Green"
        } catch { Write-Log "NVE download fout: $($_.Exception.Message)" "Red" }

        # Verwijder roblox tree.rpf (excluded)
        Get-ChildItem -Path $destMods -Filter "*roblox*tree*.rpf" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            try { Remove-Item $_.FullName -Force; Write-Log "Excluded verwijderd: $($_.Name)" "Yellow" } catch {}
        }
        Get-ChildItem -Path $destMods -Filter "*roblox*" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Name -match "roblox") { try { Remove-Item $_.FullName -Force; Write-Log "Excluded: $($_.Name)" "Yellow" } catch {} }
        }

        $allRpf = Get-ChildItem -Path $destSound, $destMods -Include "*.rpf" -File -Recurse -ErrorAction SilentlyContinue
        if (-not $allRpf -or $allRpf.Count -eq 0) {
            Write-Log "Geen .rpf gevonden na gdown! Check of Google Drive quota niet overschreden is." "Yellow"
            Write-Log "Handmatig: open links in browser en download" "Gray"
            return $false
        }
        Write-Log "$($allRpf.Count) .rpf bestanden gevonden na Drive download, nu automatisch plaatsen..." "Cyan"
        foreach ($rpf in $allRpf) {
            $fileName = $rpf.Name
            $isSound = $fileName -match "ONESHOT|RESIDENT|WEAPONS_PLAYER|sound|audio|sfx" -or $rpf.DirectoryName -match "Soundpack"
            $isNVE = $fileName -match "NVE|EUROPE ROADS|Street_Lights|Window_Raindrops|Engine_Smoke|Northern_Lights|Weapons_Overhaul|Cool White"
            $destinations = @()
            if ($isSound) {
                if ($gtaAudioMods) { $destinations += $gtaAudioMods }
                if ($gtaPath) { $destinations += "$gtaPath\x64\audio\sfx" }
                if ($fiveMMods) { $destinations += $fiveMMods }
            } elseif ($isNVE) {
                if ($gtaModsPath) { $destinations += $gtaModsPath }
                if ($fiveMMods) { $destinations += $fiveMMods }
                if ($fileName -match "EUROPE ROADS") {
                    $dlc = Join-Path $gtaModsPath "update\x64\dlcpacks"
                    if (-not (Test-Path $dlc)) { New-Item -ItemType Directory -Path $dlc -Force | Out-Null }
                    $destinations += $dlc
                }
            } else {
                if ($gtaModsPath) { $destinations += $gtaModsPath }
            }
            $destinations += $modsLocalPath
            foreach ($dest in $destinations | Select-Object -Unique) {
                if (-not $dest) { continue }
                $destFile = Join-Path $dest $fileName
                try {
                    if (Test-Path $destFile) { Backup-File -Path $destFile }
                    Copy-Item -Path $rpf.FullName -Destination $destFile -Force
                    Write-Log "  -> $fileName -> $dest" "Green"
                } catch { Write-Log "  -> Mislukt $dest : $($_.Exception.Message)" "Red" }
            }
        }
        Write-Log "Joker's Packs klaar! Soundpack (3 files) + NVE mods (9 files zonder roblox) geplaatst." "Green"
        return $true
    } else {
        Write-Log "gdown niet beschikbaar. Handmatige stappen:" "Red"
        Write-Log "1. Soundpack: $jokersSoundPackUrl -> download alle 3 .rpf en plaats in $destSound  (ONESHOT_AMBIENCE.rpf 66MB, RESIDENT.rpf 173MB, WEAPONS_PLAYER.rpf 7.9MB)" "Yellow"
        Write-Log "2. NVE Mods: $jokersModsUrl -> download alles BEHALVE 'roblox tree.rpf' naar $destMods (a_NVE 294MB, b_NVE_Window_Raindrops 49MB, c_NVE_More_Engine_Smoke 12MB, Cool White Street Lights 41MB, EUROPE ROADS 2.88GB!, p_NVE_Northern_Lights 16MB, r_NVE_Weapons_Overhaul 136MB, z_NVE_New_Street_Lights 27MB, z_NVE_Street_Lights 18MB)" "Yellow"
        Write-Log "Daarna run opnieuw optie 5, of sleep handmatig naar $modsLocalPath" "Gray"
        # Probeer ook fallback: open browser
        try { Start-Process $jokersSoundPackUrl } catch {}
        try { Start-Process $jokersModsUrl } catch {}
        return $false
    }
}

function Install-CustomBloodMod {
    Write-Log "=== Custom BLOOD_MOD.RPF (Drive) downloaden ===" "Magenta"
    Make-Folders
    $gtaPath = Get-GTAPath
    $fiveMPath = Get-FiveMPath
    $gtaModsPath = if ($gtaPath) { Join-Path $gtaPath "mods" } else { $null }
    $fiveMMods = if ($fiveMPath) { Join-Path $fiveMPath "mods" } else { $null }
    foreach ($p in @($gtaModsPath, $fiveMMods)) { if ($p -and -not (Test-Path $p)) { try { New-Item -ItemType Directory -Path $p -Force | Out-Null } catch {} } }

    $destFile = Join-Path $modsStagingPath "BLOOD_MOD.RPF"
    $destFileLower = Join-Path $modsStagingPath "blood_mod.rpf"
    New-Item -ItemType Directory -Path $modsStagingPath -Force | Out-Null
    New-Item -ItemType Directory -Path $modsLocalPath -Force | Out-Null

    $hasGdown = Ensure-Gdown
    $hasGdownDirect = Get-Command gdown -ErrorAction SilentlyContinue
    $success = $false

    if ($hasGdown) {
        $gdownCmd = if ($hasGdownDirect) { "gdown" } else { "python -m gdown" }
        Write-Log "Downloaden BLOOD_MOD.RPF van $customBloodModUrl ..." "Yellow"
        try {
            # gdown file download - probeer beide manieren
            $cmd = "$gdownCmd --id $customBloodModFileId --output `"$destFile`""
            Write-Log "Uitvoeren: $cmd" "Gray"
            Invoke-Expression $cmd 2>&1 | Out-Null
            if (Test-Path $destFile) { $success = $true }
            elseif (Test-Path $destFileLower) { $destFile = $destFileLower; $success = $true }
            else {
                # fallback probeer direct url
                $cmd2 = "$gdownCmd `"$customBloodModUrl`" --output `"$destFile`""
                Invoke-Expression $cmd2 2>&1 | Out-Null
                if (Test-Path $destFile -or Test-Path $destFileLower) { $success = $true }
            }
        } catch { Write-Log "BLOOD_MOD download fout: $($_.Exception.Message)" "Red" }
    }

    if ($success -and (Test-Path $destFile -or Test-Path $destFileLower)) {
        if (-not (Test-Path $destFile) -and (Test-Path $destFileLower)) { $destFile = $destFileLower }
        Write-Log "BLOOD_MOD.RPF gedownload ($([math]::Round((Get-Item $destFile).Length/1MB,1)) MB)" "Green"
        $destinations = @()
        if ($gtaModsPath) { $destinations += $gtaModsPath }
        if ($fiveMMods) { $destinations += $fiveMMods }
        $destinations += $modsLocalPath
        foreach ($dest in $destinations | Select-Object -Unique) {
            if (-not $dest) { continue }
            if (-not (Test-Path $dest)) { try { New-Item -ItemType Directory -Path $dest -Force | Out-Null } catch {} }
            $destName = "BLOOD_MOD.RPF"
            # behoud caps maar maak ook lower variant voor compat
            $destFileFinal = Join-Path $dest $destName
            try {
                if (Test-Path $destFileFinal) { Backup-File -Path $destFileFinal }
                Copy-Item -Path $destFile -Destination $destFileFinal -Force
                Write-Log "  -> BLOOD_MOD.RPF -> $dest" "Green"
                # ook lower variant voor mods die lower verwachten
                $lowerDest = Join-Path $dest "blood_mod.rpf"
                if ($destName -ne "blood_mod.rpf") { Copy-Item -Path $destFile -Destination $lowerDest -Force -ErrorAction SilentlyContinue }
            } catch { Write-Log "  -> Mislukt $dest : $($_.Exception.Message)" "Red" }
        }
        return $true
    } else {
        Write-Log "BLOOD_MOD.RPF download mislukt! Check of link gedeeld is (Iedereen met link -> Viewer) en probeer handmatig: $customBloodModUrl" "Red"
        try { Start-Process $customBloodModUrl } catch {}
        return $false
    }
}

function Install-CustomMinimap {
    Write-Log "=== Custom minimap.rpf (Drive) downloaden ===" "Magenta"
    Make-Folders
    $gtaPath = Get-GTAPath
    $fiveMPath = Get-FiveMPath
    $gtaModsPath = if ($gtaPath) { Join-Path $gtaPath "mods" } else { $null }
    $fiveMMods = if ($fiveMPath) { Join-Path $fiveMPath "mods" } else { $null }
    foreach ($p in @($gtaModsPath, $fiveMMods)) { if ($p -and -not (Test-Path $p)) { try { New-Item -ItemType Directory -Path $p -Force | Out-Null } catch {} } }

    $destFile = Join-Path $modsStagingPath "minimap.rpf"
    New-Item -ItemType Directory -Path $modsStagingPath -Force | Out-Null
    New-Item -ItemType Directory -Path $modsLocalPath -Force | Out-Null

    $hasGdown = Ensure-Gdown
    $hasGdownDirect = Get-Command gdown -ErrorAction SilentlyContinue
    $success = $false

    if ($hasGdown) {
        $gdownCmd = if ($hasGdownDirect) { "gdown" } else { "python -m gdown" }
        Write-Log "Downloaden minimap.rpf van $customMinimapUrl ..." "Yellow"
        try {
            $cmd = "$gdownCmd --id $customMinimapFileId --output `"$destFile`""
            Write-Log "Uitvoeren: $cmd" "Gray"
            Invoke-Expression $cmd 2>&1 | Out-Null
            if (Test-Path $destFile) { $success = $true }
            else {
                $cmd2 = "$gdownCmd `"$customMinimapUrl`" --output `"$destFile`""
                Invoke-Expression $cmd2 2>&1 | Out-Null
                if (Test-Path $destFile) { $success = $true }
            }
        } catch { Write-Log "minimap download fout: $($_.Exception.Message)" "Red" }
    }

    if ($success -and (Test-Path $destFile)) {
        Write-Log "minimap.rpf gedownload ($([math]::Round((Get-Item $destFile).Length/1MB,1)) MB)" "Green"
        $destinations = @()
        if ($gtaModsPath) { $destinations += $gtaModsPath }
        if ($fiveMMods) { $destinations += $fiveMMods }
        # minimap ook naar citizen/common/data voor FiveM minimap
        if ($fiveMPath) { $destinations += "$fiveMPath\citizen\common\data" }
        $destinations += $modsLocalPath
        foreach ($dest in $destinations | Select-Object -Unique) {
            if (-not $dest) { continue }
            if (-not (Test-Path $dest)) { try { New-Item -ItemType Directory -Path $dest -Force | Out-Null } catch {} }
            $destFileFinal = Join-Path $dest "minimap.rpf"
            try {
                if (Test-Path $destFileFinal) { Backup-File -Path $destFileFinal }
                Copy-Item -Path $destFile -Destination $destFileFinal -Force
                Write-Log "  -> minimap.rpf -> $dest" "Green"
            } catch { Write-Log "  -> Mislukt $dest : $($_.Exception.Message)" "Red" }
        }
        return $true
    } else {
        Write-Log "minimap.rpf download mislukt! Check link: $customMinimapUrl" "Red"
        try { Start-Process $customMinimapUrl } catch {}
        return $false
    }
}

function Install-ModsAuto {
    Write-Log "=== Mods & Sound Packs (.rpf) Automatisch Installeren ===" "Cyan"
    Make-Folders

    $gtaPath = Get-GTAPath
    $fiveMPath = Get-FiveMPath

    if (-not $gtaPath) {
        Write-Log "GTA V installatie NIET gevonden!" "Red"
        Write-Log "Tip: installeer GTA V eerst of plaats handmatig .rpf in $modsLocalPath" "Yellow"
        $gtaPath = $null
    } else {
        Write-Log "GTA V gevonden: $gtaPath" "Green"
    }
    if ($fiveMPath) {
        Write-Log "FiveM gevonden: $fiveMPath" "Green"
    } else {
        Write-Log "FiveM (nog) niet gevonden - mods gaan alleen naar GTA" "Yellow"
    }

    # Zorg dat mods folders bestaan
    $gtaModsPath = if ($gtaPath) { Join-Path $gtaPath "mods" } else { $null }
    $gtaAudioMods = if ($gtaPath) { Join-Path $gtaModsPath "x64\audio\sfx" } else { $null }
    $fiveMMods = if ($fiveMPath) { Join-Path $fiveMPath "mods" } else { $null }

    foreach ($p in @($gtaModsPath, $gtaAudioMods, $fiveMMods, $modsLocalPath)) {
        if ($p -and -not (Test-Path $p)) {
            try { New-Item -ItemType Directory -Path $p -Force | Out-Null; Write-Log "Map gemaakt: $p" "Gray" } catch {}
        }
    }

    # 1. Download mods vanaf GitHub repo/mods en repo/sounds (als die bestaan)
    $githubFiles = @()
    $modsApi = Get-GithubFolderFiles -ApiUrl $repoApiMods
    $soundsApi = Get-GithubFolderFiles -ApiUrl $repoApiSounds

    foreach ($apiResult in @($modsApi, $soundsApi)) {
        if ($apiResult) {
            foreach ($item in $apiResult) {
                if ($item.type -eq "file" -and $item.name -match "\.(rpf|oiv|asi|dll)$") {
                    $githubFiles += $item
                }
            }
        }
    }

    $downloadedCount = 0

    if ($githubFiles.Count -gt 0) {
        Write-Log "$($githubFiles.Count) mod bestand(en) gevonden op GitHub, downloaden..." "Yellow"
        foreach ($file in $githubFiles) {
            $fileName = $file.name
            $downloadUrl = $file.download_url
            if (-not $downloadUrl) { $downloadUrl = "$repo/mods/$fileName" }
            $tempPath = Join-Path $modsStagingPath $fileName

            Write-Log "Downloaden: $fileName" "Yellow"
            if (Download-FileWithRetry -Url $downloadUrl -OutFile $tempPath) {
                Write-Log "  Gedownload: $fileName" "Green"
                $downloadedCount++

                # Bepaal doel locatie automatisch
                $isSound = $fileName -match "sound|audio|sfx|voice|awc" -or $file.path -match "sound"
                $destinations = @()

                if ($isSound) {
                    if ($gtaAudioMods) { $destinations += $gtaAudioMods }
                    if ($gtaPath) { $destinations += "$gtaPath\x64\audio\sfx" } # ook direct zonder mods folder voor testen
                    if ($fiveMMods) { $destinations += $fiveMMods }
                } else {
                    if ($gtaModsPath) { $destinations += $gtaModsPath }
                    if ($fiveMMods) { $destinations += $fiveMMods }
                    # Als .rpf een vehicle mod is, probeer ook mods\update\x64\dlcpacks
                    if ($fileName -match "dlc|vehicle|car") {
                        $dlcPath = if ($gtaModsPath) { Join-Path $gtaModsPath "update\x64\dlcpacks" } else { $null }
                        if ($dlcPath) {
                            if (-not (Test-Path $dlcPath)) { New-Item -ItemType Directory -Path $dlcPath -Force | Out-Null }
                            $destinations += $dlcPath
                        }
                    }
                }
                # Altijd ook staging copy bewaren
                $destinations += $modsLocalPath

                foreach ($dest in $destinations | Select-Object -Unique) {
                    if (-not $dest) { continue }
                    $destFile = Join-Path $dest $fileName
                    try {
                        if (Test-Path $destFile) { Backup-File -Path $destFile }
                        Copy-Item -Path $tempPath -Destination $destFile -Force
                        Write-Log "    -> Auto geplaatst in $destFile" "Green"
                    } catch {
                        Write-Log "    -> Mislukt voor $dest : $($_.Exception.Message)" "Red"
                    }
                }
            } else {
                Write-Log "Download mislukt: $fileName" "Red"
            }
        }
    } else {
        Write-Log "Geen mods gevonden op GitHub (mods/ of sounds/ map leeg of bestaat niet)" "Yellow"
        Write-Log "Tip: plaats .rpf bestanden in https://github.com/z8ic/reset/tree/main/mods" "Gray"
    }

    # 2. Installeer lokale mods (als gebruiker zelf .rpf in Desktop\Apps\Mods heeft gezet)
    $localMods = Get-ChildItem -Path $modsLocalPath -Filter "*.rpf" -File -ErrorAction SilentlyContinue
    $localMods += Get-ChildItem -Path $modsLocalPath -Filter "*.oiv" -File -ErrorAction SilentlyContinue
    $localMods += Get-ChildItem -Path $modsLocalPath -Filter "*.awc" -File -ErrorAction SilentlyContinue
    # Ook subfolders
    $localMods += Get-ChildItem -Path $modsLocalPath -Recurse -Include "*.rpf","*.oiv","*.awc" -File -ErrorAction SilentlyContinue | Where-Object { $_.DirectoryName -ne $modsLocalPath }

    # Filter dubbele die net gedownload zijn (al geplaatst)
    $localOnly = $localMods | Where-Object { $_.FullName -notlike "$modsStagingPath*" } | Select-Object -Unique

    if ($localOnly -and $localOnly.Count -gt 0) {
        Write-Log "$($localOnly.Count) lokale mod(s) gevonden in $modsLocalPath" "Cyan"
        foreach ($mod in $localOnly) {
            $fileName = $mod.Name
            # Skip als al via GitHub geplaatst en zelfde file
            if ($githubFiles.name -contains $fileName -and $downloadedCount -gt 0) { continue }
            
            Write-Log "Lokaal installeren: $fileName" "Yellow"
            $isSound = $fileName -match "sound|audio|sfx|voice"
            $destinations = @()
            if ($isSound) {
                if ($gtaAudioMods) { $destinations += $gtaAudioMods }
                if ($fiveMMods) { $destinations += $fiveMMods }
            } else {
                if ($gtaModsPath) { $destinations += $gtaModsPath }
                if ($fiveMMods) { $destinations += $fiveMMods }
            }
            if ($destinations.Count -eq 0) {
                Write-Log "  Geen GTA/FiveM pad gevonden, laat staan in $modsLocalPath" "Yellow"
                continue
            }
            foreach ($dest in $destinations | Select-Object -Unique) {
                $destFile = Join-Path $dest $fileName
                try {
                    if (Test-Path $destFile) { Backup-File -Path $destFile }
                    Copy-Item -Path $mod.FullName -Destination $destFile -Force
                    Write-Log "  -> Geplaatst in $dest" "Green"
                } catch {
                    Write-Log "  -> Mislukt: $($_.Exception.Message)" "Red"
                }
            }
        }
    }

    # 2b. Check Downloads folder voor minimap.rpf en blood_mod.rpf (en andere .rpf)
    $downloadsPath = "$env:USERPROFILE\Downloads"
    if (Test-Path $downloadsPath) {
        $downloadMods = @()
        # Specifiek de 2 gevraagde mods
        $downloadMods += Get-ChildItem -Path $downloadsPath -Filter "minimap.rpf" -File -ErrorAction SilentlyContinue
        $downloadMods += Get-ChildItem -Path $downloadsPath -Filter "blood_mod.rpf" -File -ErrorAction SilentlyContinue
        # Ook andere .rpf in Downloads (als gebruiker er meer heeft)
        # We tonen ze maar installeren alleen de 2 gevraagde automatisch, rest met vraag
        if ($downloadMods -and $downloadMods.Count -gt 0) {
            Write-Log "$($downloadMods.Count) mod(s) gevonden in Downloads (minimap.rpf / blood_mod.rpf)" "Cyan"
            foreach ($mod in $downloadMods | Select-Object -Unique) {
                $fileName = $mod.Name
                Write-Log "Downloads -> installeren: $fileName" "Yellow"
                $isSound = $fileName -match "sound|audio|sfx|voice"
                $destinations = @()
                if ($fileName -match "minimap") {
                    # minimap hoort meestal in mods of FiveM
                    if ($gtaModsPath) { $destinations += $gtaModsPath }
                    if ($fiveMMods) { $destinations += $fiveMMods }
                    # ook FiveM citizen map voor minimap
                    if ($fiveMPath) { $destinations += "$fiveMPath\citizen\common\data" }
                } elseif ($fileName -match "blood_mod") {
                    if ($gtaModsPath) { $destinations += $gtaModsPath }
                    if ($fiveMMods) { $destinations += $fiveMMods }
                } else {
                    if ($gtaModsPath) { $destinations += $gtaModsPath }
                    if ($fiveMMods) { $destinations += $fiveMMods }
                }
                # Ook altijd backup naar Desktop\Apps\Mods
                $destinations += $modsLocalPath
                foreach ($dest in $destinations | Select-Object -Unique) {
                    if (-not $dest) { continue }
                    if (-not (Test-Path $dest)) { try { New-Item -ItemType Directory -Path $dest -Force | Out-Null } catch {} }
                    $destFile = Join-Path $dest $fileName
                    try {
                        if (Test-Path $destFile) { Backup-File -Path $destFile }
                        Copy-Item -Path $mod.FullName -Destination $destFile -Force
                        Write-Log "  -> $fileName -> $dest" "Green"
                    } catch { Write-Log "  -> Mislukt $dest : $($_.Exception.Message)" "Red" }
                }
            }
        } else {
            Write-Log "Geen minimap.rpf / blood_mod.rpf gevonden in $downloadsPath (zijn ze al verplaatst?)" "Gray"
        }
        # Toon ook andere .rpf in Downloads ter info
        $otherRpf = Get-ChildItem -Path $downloadsPath -Filter "*.rpf" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @("minimap.rpf","blood_mod.rpf") }
        if ($otherRpf) {
            Write-Log "$($otherRpf.Count) andere .rpf in Downloads gevonden (niet auto-geinstalleerd): $($otherRpf.Name -join ', ')" "DarkGray"
            Write-Log "Tip: sleep ze naar $modsLocalPath voor auto-install bij volgende run" "Gray"
        }
    }

    # 3. Ook .rpf in staging die niet via GitHub kwamen (handmatig daar geplaatst)
    $stagingMods = Get-ChildItem -Path $modsStagingPath -Include "*.rpf","*.oiv" -File -ErrorAction SilentlyContinue
    if ($stagingMods.Count -gt 0 -and $downloadedCount -eq 0) {
        Write-Log "$($stagingMods.Count) staging mods gevonden" "Gray"
    }

    # 4. Joker's Google Drive Packs (automatisch, zonder roblox tree.rpf)
    Write-Log "Joker's Packs check (Google Drive) - automatisch downloaden..." "Cyan"
    try { Install-JokersPacksAuto | Out-Null } catch { Write-Log "Joker's packs fout: $($_.Exception.Message)" "Yellow" }

    # 4b. Custom BLOOD_MOD.RPF van Drive (jouw eigen Drive)
    Write-Log "Custom BLOOD_MOD.RPF check (Drive)..." "Cyan"
    try { Install-CustomBloodMod | Out-Null } catch { Write-Log "Custom BLOOD_MOD fout: $($_.Exception.Message)" "Yellow" }

    # 4c. Custom minimap.rpf van Drive
    Write-Log "Custom minimap.rpf check (Drive)..." "Cyan"
    try { Install-CustomMinimap | Out-Null } catch { Write-Log "Custom minimap fout: $($_.Exception.Message)" "Yellow" }

    Write-Log "Mods installatie klaar!" "Green"
    Write-Log "GTA Mods: $gtaModsPath" "Gray"
    Write-Log "FiveM Mods: $fiveMMods" "Gray"
    Write-Log "Lokaal: $modsLocalPath (sleep hier zelf .rpf heen voor auto-install volgende keer)" "Gray"

    # Maak README voor mods
    $modReadme = Join-Path $modsLocalPath "README_MODS.txt"
    @"
RESET TOOL - MODS AUTO INSTALL
==============================
Datum: $(Get-Date)

HOE WERKT HET AUTOMATISCH:

1. GitHub mods: plaats .rpf / .oiv / sound packs in je GitHub repo onder:
   - reset/mods/        -> voor algemene .rpf (vehicles, maps, etc)
   - reset/sounds/      -> voor sound packs (.rpf met audio)

   Het script download ze automatisch van:
   $repoApiMods

2. Lokale mods: sleep .rpf bestanden naar:
   $modsLocalPath
   Bij volgende run worden ze automatisch naar GTA & FiveM gekopieerd.

WAAR WORDT HET GEPLAATST:

- GTA V: $gtaPath
  -> mods\  (OpenIV mods folder)
  -> mods\x64\audio\sfx\  (voor sound packs)
  -> mods\update\x64\dlcpacks\ (voor DLC vehicle mods)

- FiveM: $fiveMPath
  -> mods\

Backups worden automatisch gemaakt als *.bak_*

TIP: installeer OpenIV en maak een "mods" folder aan in GTA V als je die nog niet hebt!
"@ | Out-File -FilePath $modReadme -Encoding UTF8

    if ($downloadedCount -eq 0 -and (-not $localOnly -or $localOnly.Count -eq 0)) {
        Write-Log "Geen mods geinstalleerd. Voeg .rpf toe aan GitHub mods/ of $modsLocalPath" "Yellow"
        return $false
    }
    return $true
}

function Run-UserBenchmark {
    $confirm = Read-Host "Wil je UserBenchmark downloaden van https://www.userbenchmark.com/? (Y/N)"
    if ($confirm -notmatch "^[Yy]$") {
        Write-Log "Geannuleerd." "Yellow"
        return
    }
    Make-Folders
    Write-Log "UserBenchmark downloaden..." "Yellow"
    $installerPath = "$benchmarkPath\UserBenchmarkInstaller.exe"
    if (Download-FileWithRetry -Url "https://www.userbenchmark.com/resources/download/UserBenchmarkInstaller.exe" -OutFile $installerPath) {
        Write-Log "UserBenchmark starten..." "Green"
        Start-Process $installerPath
    } else {
        Write-Log "Download mislukt" "Red"
    }
}

# ================= MENU LOOP =================
Update-WingetSource

while ($true) {
    Write-Header
    Write-Host "1. Alles installeren + AUTOMATISCH configureren (Aanrader)" -ForegroundColor Green
    Write-Host "2. Zelf kiezen welke apps" -ForegroundColor White
    Write-Host "3. Alles downloaden naar Apps\Installers (zonder installeren)" -ForegroundColor White
    Write-Host "4. Configs AUTOMATISCH plaatsen (Joker 1/2/3 + fivem.cfg etc)" -ForegroundColor Cyan
    Write-Host "5. Mods & Sound Packs (.rpf) AUTOMATISCH installeren [incl. Joker's Packs + minimap/blood_mod]" -ForegroundColor Magenta
    Write-Host "6. Open Chris Titus Tool" -ForegroundColor White
    Write-Host "7. Download & Run UserBenchmark" -ForegroundColor White
    Write-Host "8. FULL RESET - Alles doen: Apps + Configs + Mods + Prereqs (VCRedist/DirectX) + Debloat + Updates" -ForegroundColor Yellow
    Write-Host "9. Alleen Joker's Packs downloaden (Soundpack + NVE zonder roblox tree)" -ForegroundColor DarkYellow
    Write-Host "10. Game Prereqs: VCRedist + DirectX + .NET" -ForegroundColor White
    Write-Host "11. Windows Update check" -ForegroundColor White
    Write-Host "12. Debloat & Tweaks (CTT auto)" -ForegroundColor White
    Write-Host "13. Alleen BLOOD_MOD + minimap (jouw Drive)" -ForegroundColor DarkMagenta
    Write-Host "0. Exit" -ForegroundColor Red
    Write-Host ""
    Write-Host "Apps: Discord, Spotify, Brave, VLC, VS Code, WinRAR, Rockstar, Epic, Steam, FiveM, ReShade, NVIDIA" -ForegroundColor DarkGray
    Write-Host "Log: $logFile" -ForegroundColor DarkGray
    Write-Host ""
    $choice = Read-Host "Maak een keuze (0-13)"

    switch ($choice) {
        "1" {
            Write-Log "=== OPTIE 1: Alles installeren ===" "Cyan"
            foreach ($app in $apps.Keys) {
                Install-AppWinget -Name $app -WingetId $apps[$app]
            }
            Install-SpotifyAuto
            Install-NvidiaAppAuto
            Write-Host ""
            Install-ConfigsAuto | Out-Null
            Write-Log "Klaar! Alles geinstalleerd + configs automatisch geplaatst." "Green"
            pause
        }
        "2" {
            Write-Log "=== OPTIE 2: Zelf kiezen ===" "Cyan"
            foreach ($app in $apps.Keys) {
                $answer = Read-Host "Wil je $app installeren? (Y/N)"
                if ($answer -match "^[Yy]$") {
                    Install-AppWinget -Name $app -WingetId $apps[$app]
                }
            }
            # Spotify zit al in lijst (incl. fallback), alleen NVIDIA apart omdat die speciale direct URL heeft
            $answer = Read-Host "Wil je NVIDIA App installeren? (Y/N)"
            if ($answer -match "^[Yy]$") { Install-NvidiaAppAuto }

            $answer = Read-Host "Wil je configs AUTOMATISCH plaatsen? (Y/N)"
            if ($answer -match "^[Yy]$") { Install-ConfigsAuto | Out-Null }

            $answer = Read-Host "Wil je mods (.rpf/sounds) AUTOMATISCH installeren? (Y/N)"
            if ($answer -match "^[Yy]$") { Install-ModsAuto | Out-Null }

            Write-Log "Klaar!" "Green"
            pause
        }
        "3" {
            Write-Log "=== OPTIE 3: Alles downloaden ===" "Cyan"
            Make-Folders
            foreach ($app in $apps.Values) {
                Write-Log "Downloaden $app..." "Yellow"
                try { winget download --id $app --source winget -e --download-directory $downloadPath --disable-interactivity --accept-package-agreements --accept-source-agreements --skip-license | Out-Null } catch { Write-Log "Download mislukt voor $app" "Red" }
            }
            Download-FileWithRetry -Url "https://download.scdn.co/SpotifySetup.exe" -OutFile "$downloadPath\Spotify_Setup.exe" | Out-Null
            Download-FileWithRetry -Url $nvidiaUrl -OutFile "$downloadPath\NVIDIA_App_Setup.exe" | Out-Null
            try { Remove-Item "$downloadPath\*.yaml" -Force -ErrorAction SilentlyContinue } catch {}
            Write-Log "Klaar! Installers in $downloadPath" "Green"
            pause
        }
        "4" {
            Install-ConfigsAuto | Out-Null
            pause
        }
        "5" {
            Install-ModsAuto | Out-Null
            pause
        }
        "6" {
            Write-Log "Chris Titus Tool openen..." "Cyan"
            try {
                Invoke-RestMethod -Uri "https://christitus.com/win" -UseBasicParsing | Invoke-Expression
            } catch {
                Write-Log "Kon Chris Titus Tool niet laden." "Red"
            }
            pause
        }
        "7" {
            Run-UserBenchmark
            pause
        }
        "8" {
            Write-Log "=== FULL AUTO RESET: Apps + Configs + Mods + Prereqs + Debloat + Update ===" "Cyan"
            Write-Log "Stap 1/8: Game Prereqs (VCRedist + DirectX + .NET)..." "Yellow"
            Install-VCRedistDirectX | Out-Null

            Write-Log "Stap 2/8: Apps installeren (Discord, Spotify, Brave, VLC, VS Code, WinRAR, Rockstar, Epic, Steam, FiveM, ReShade, NVIDIA)..." "Yellow"
            foreach ($app in $apps.Keys) { Install-AppWinget -Name $app -WingetId $apps[$app] }
            Install-SpotifyAuto
            Install-NvidiaAppAuto

            Write-Log "Stap 3/8: Configs automatisch plaatsen (Joker 1/2/3)..." "Yellow"
            Install-ConfigsAuto | Out-Null

            Write-Log "Stap 4/8: Mods & Sound Packs installeren (GitHub + lokaal + minimap)..." "Yellow"
            Install-ModsAuto | Out-Null

            Write-Log "Stap 5/8: Joker's Packs (Google Drive) - Soundpack + NVE zonder roblox tree..." "Yellow"
            Install-JokersPacksAuto | Out-Null

            Write-Log "Stap 6/8: Custom BLOOD_MOD.RPF + minimap.rpf (jouw Drive)..." "Yellow"
            Install-CustomBloodMod | Out-Null
            Install-CustomMinimap | Out-Null

            Write-Log "Stap 7/8: Debloat & Tweaks (CTT auto)..." "Yellow"
            Invoke-CTTDebloatAuto -Silent | Out-Null

            Write-Log "Stap 8/8: Windows Update check..." "Yellow"
            Invoke-WindowsUpdateAuto | Out-Null

            Write-Log "FULL AUTO RESET KLAAR! Alles staat automatisch op de juiste plek." "Green"
            Write-Log "Herstart je PC en daarna FiveM / GTA en geniet!" "Cyan"
            Write-Log "Log staat in $logFile" "Gray"
            pause
        }
        "9" {
            Write-Log "=== Alleen Joker's Packs ===" "Cyan"
            Install-JokersPacksAuto | Out-Null
            pause
        }
        "10" {
            Install-VCRedistDirectX | Out-Null
            pause
        }
        "11" {
            Invoke-WindowsUpdateAuto | Out-Null
            pause
        }
        "12" {
            Invoke-CTTDebloatAuto | Out-Null
            pause
        }
        "13" {
            Install-CustomBloodMod | Out-Null
            Install-CustomMinimap | Out-Null
            pause
        }
        "0" {
            Write-Host "Tot ziens, boss!" -ForegroundColor Cyan
            exit
        }
        Default {
            Write-Host "Ongeldige keuze." -ForegroundColor Red
            Start-Sleep 1
        }
    }
}
