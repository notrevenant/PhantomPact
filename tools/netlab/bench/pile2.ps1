param([string]$Tail = 'BC2BD740003_1995371452')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
"hooks " + (Ask $C 'return LOOTP.mapHook()' 6)
[void](Ask $C 'return REAL.bagMark()')
$from = Log-End
Ask $C "return LOOTP.payPile2(`"$Tail`")" 8
Start-Sleep -Seconds 3
"guest " + (Ask $C 'return REAL.bagDiff()' 5)
Lines $from 'LOOTMAP|Shared|rror' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 5 | ForEach-Object { if ($_.Length -gt 130) { $_.Substring(0, 130) } else { $_ } }
"still there: " + (Ask $C "return LOOTP.pile(`"$Tail`")" 5)
