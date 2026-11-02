param([string]$Who = 'C', [double]$Timeout = 90)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$g = if ($Who -eq 'H') { $script:H } else { $script:C }
Start-Sleep -Seconds 4
"ready: " + (Wait-Player $g $Timeout)
Start-Sleep -Seconds 4
[void](Ask $g 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/walker.lua") return 1' 8)
(Ask $g 'return STORY.where()')
(Ask $g 'return tostring(PBZ.game.mapName(select(2,PBZ.getPlayer1())))')
(Ask $g 'return WALK.look()')
