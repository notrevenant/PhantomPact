. (Join-Path $PSScriptRoot 'tourlib.ps1')
$load = 'dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $script:C $load 8)
Ask $script:C 'return LOOTP.piles(9000, "C:/PBZDev/pp-netlab/piles-guest.txt")' 8
$class = Ask $script:C 'local a=FindFirstOf("BP_Rubbish_C") return a and a:GetClass():GetFullName() or "none"' 6
$class
