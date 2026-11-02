. (Join-Path $PSScriptRoot 'tourlib.ps1')
$load = 'dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $script:H $load 8); [void](Ask $script:C $load 8)
Ask $script:H 'return LOOTP.openList("C:/PBZDev/pp-netlab/open-host.txt")' 8
Ask $script:C 'return LOOTP.openList("C:/PBZDev/pp-netlab/open-guest.txt")' 8
