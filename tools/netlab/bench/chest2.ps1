# The guest's own copy of a chest the host opened: what its functions are, and what opening it without the player does.
param([string]$Name = 'BP_Chest_C_UAID_74563C6BC2BDD7FF02_1160523931')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $C $load 8)
Ask $C "return LOOTP.chestClass(`"$Name`")" 6
[void](Ask $H 'return REAL.bagMark()'); [void](Ask $C 'return REAL.bagMark()')
$from = Log-End
Ask $C "return LOOTP.mirror(`"$Name`")" 6
Start-Sleep -Seconds 4
"host  " + (Ask $H 'return REAL.bagDiff()' 5)
"guest " + (Ask $C 'return REAL.bagDiff()' 5)
Lines $from 'LOOTROLL|LOOTBAG|rror' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 10 | ForEach-Object { if ($_.Length -gt 150) { $_.Substring(0, 150) } else { $_ } }
Ask $C "local a=LOOTP.chest(`"$Name`") return tostring(a and a.CurSwitchState)" 5
