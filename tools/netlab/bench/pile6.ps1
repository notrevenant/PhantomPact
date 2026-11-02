param([string]$Tail = 'BC2BD730003_2115473268')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $C $load 8)
[void](Ask $C 'return REAL.bagMark()')
Ask $C "return LOOTP.payPile4(`"$Tail`")" 8
Start-Sleep -Seconds 5
"guest " + (Ask $C 'return REAL.bagDiff()' 5)
"after: " + (Ask $C "return LOOTP.pile(`"$Tail`")" 5)
