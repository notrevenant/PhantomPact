# Read only: both players' backpack and gear, kept to compare with later.
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
foreach ($g in $script:H, $script:C) {
    [void](Ask $g $load 8)
    Ask $g 'return REAL.bagMark()' 6
    Ask $g 'return LOOTP.gearMark()' 6
}
[void](Ask $script:H 'return LOOTP.gearFile("C:/PBZDev/pp-netlab/gear-host.txt")' 6)
[void](Ask $script:C 'return LOOTP.gearFile("C:/PBZDev/pp-netlab/gear-guest.txt")' 6)
"mark at $(Log-End)" | Set-Content 'C:\PBZDev\pp-netlab\mark-pos.txt'
Log-End | Set-Content 'C:\PBZDev\pp-netlab\mark-log.txt'
