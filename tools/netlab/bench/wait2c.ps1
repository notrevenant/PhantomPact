. (Join-Path $PSScriptRoot 'tourlib.ps1')
Start-Sleep -Seconds 6
"host " + (Wait-Player $script:H 120)
Start-Sleep -Seconds 4
Ask $script:H 'dofile("C:/PBZDev/netlab/real.lua") return tostring(PBZ.game.mapName(select(2,PBZ.getPlayer1()))).." "..REAL.gap().." hp "..tostring(PBZ.game.getHealth(select(2,PBZ.getPlayer1())))' 6
