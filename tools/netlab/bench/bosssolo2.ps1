# With co-op off, after that boss died: another rest, then away and back.
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$c2 = $script:C
$list = 'return dofile("C:/PBZDev/g3.lua")'
Ask $c2 'local pc=PBZ.getPlayer1() local gm=PBZ.gs():GetGameMode(pc) gm["Refresh Monster"](gm) return "rested again"' 6
Start-Sleep -Seconds 8
"after a second rest: " + (Ask $c2 $list 6)
[void](Ask $c2 'return STORY.go("SZ_005")' 8)
Start-Sleep -Seconds 6
"at another bell: " + (Wait-Player $c2 120)
Start-Sleep -Seconds 4
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") return 1'
[void](Ask $c2 $load 8)
[void](Ask $c2 "return REAL.flyTo(-184773, 119290, -3612)")
Start-Sleep -Seconds 14
[void](Ask $c2 'return REAL.land(1)')
Start-Sleep -Seconds 3
"back at its place: " + (Ask $c2 $list 6)
