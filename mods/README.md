Mods Automatisch Installatie

Plaats hier je rpf, oiv, asi bestanden.

Het script main.ps1 optie 5 of 8 doet automatisch:
1. Download alle bestanden uit mods en sounds vanaf GitHub
2. Detecteert je GTA V en FiveM installatie
3. Plaatst ze op de juiste plekken:
   - GTA V mods OpenIV
   - GTA V mods x64 audio sfx voor sound packs
   - GTA V mods update x64 dlcpacks voor DLC vehicle mods
   - FiveM mods
   - Desktop Apps Mods lokale backup

Voorbeelden:

mods
  - car_pack.rpf gaat naar GTA mods plus FiveM mods
  - weapon_pack.oiv gaat naar GTA mods
sounds
  - my_soundpack.rpf gaat naar GTA mods x64 audio sfx plus FiveM
  - awc_pack.rpf herkend als sound naam bevat sound audio sfx

Lokaal toevoegen zonder GitHub push:

Sleep je rpf gewoon naar Desktop Apps Mods op je PC.
Bij volgende run optie 5 wordt het automatisch naar GTA en FiveM gekopieerd.

Backups worden automatisch gemaakt als bak_TIMESTAMP.
