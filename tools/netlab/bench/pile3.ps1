param([string]$Tail = 'BC2BDDAE302_1734620634')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
Ask $C 'return LOOTP.params("/Game/PBZContent/Blueprint/Item/Device/BP_Rubbish.BP_Rubbish_C:OnInteract")' 6
Ask $C 'return LOOTP.params("/Game/PBZContent/Blueprint/Item/Device/BP_Rubbish.BP_Rubbish_C:Collect Items")' 6
[void](Ask $C 'return REAL.bagMark()')
$from = Log-End
Ask $C "return LOOTP.payPile3(`"$Tail`")" 8
Start-Sleep -Seconds 4
"guest " + (Ask $C 'return REAL.bagDiff()' 5)
Lines $from 'LOOTMAP|LOOTBAG|Shared|rror' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 5 | ForEach-Object { if ($_.Length -gt 130) { $_.Substring(0, 130) } else { $_ } }
"after: " + (Ask $C "return LOOTP.pile(`"$Tail`")" 5)
