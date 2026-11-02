param([string]$Tail = 'BC2BDDAE302_1734620634', [string]$Fresh = 'BC2BD730003_2115473268')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $C $load 8)
'--- paid pile: its fields, then asked to pay again'
Ask $C "return LOOTP.pileFields(`"$Tail`")" 6
[void](Ask $C 'return REAL.bagMark()')
$from = Log-End
Ask $C "return LOOTP.payPile3(`"$Tail`")" 8
Start-Sleep -Seconds 3
"guest " + (Ask $C 'return REAL.bagDiff()' 5)
Ask $C "return LOOTP.pileFields(`"$Tail`")" 6
'--- a fresh pile: its fields before'
Ask $C "return LOOTP.pileFields(`"$Fresh`")" 6
