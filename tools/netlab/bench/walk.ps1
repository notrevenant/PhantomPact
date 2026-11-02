param([int]$Seconds = 300, [int]$Kill = 1500, [switch]$NoGuest)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/walker.lua") dofile("C:/PBZDev/netlab/walker2.lua") return 1'
[void](Ask $H $load 8)
Ask $H "return WALK.start($Seconds, $Kill)" 8
if (-not $NoGuest) { [void](Ask $C $load 8); Ask $C "return WALK.start($Seconds, nil)" 8 }
