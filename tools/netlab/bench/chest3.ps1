# On the guest: the chest pays out by its own steps, with the backpack compared.
param([string]$Name = 'BP_Chest_C_UAID_74563C6BC2BDEC0103_1550784488', [string]$Steps = 'Collect Items,Pickup Items', [switch]$Hook)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $C $load 8)
if ($Hook) { Ask $C 'return LOOTP.mapHook()' 6 }
Ask $C "return LOOTP.props(`"$Name`")" 6
[void](Ask $H 'return REAL.bagMark()'); [void](Ask $C 'return REAL.bagMark()')
$from = Log-End
Ask $C "return LOOTP.pay(`"$Name`", `"$Steps`")" 8
Start-Sleep -Seconds 4
"host  " + (Ask $H 'return REAL.bagDiff()' 5)
"guest " + (Ask $C 'return REAL.bagDiff()' 5)
Lines $from 'LOOTROLL|LOOTBAG|LOOTMAP|rror' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 10 | ForEach-Object { if ($_.Length -gt 150) { $_.Substring(0, 150) } else { $_ } }
