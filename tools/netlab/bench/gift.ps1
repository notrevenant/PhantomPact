# Two checks on a brand-new accessory and on buying. Uses the mod's own grant, as a receiver would.
param([string]$Ac = '', [string]$Buy = 'Item_001')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
[void](Ask $H 'return LOOTP.gearMark()' 6); [void](Ask $C 'return LOOTP.gearMark()' 6)
[void](Ask $H 'return REAL.bagMark()' 6); [void](Ask $C 'return REAL.bagMark()' 6)
"--- a new accessory, as received: $Ac"
$from = Log-End
Ask $C "local _,p=PBZ.getPlayer1() PBZ.game.grantLoot(p,`"$Ac`",`"accessory`",1) return `"granted`"" 6
Start-Sleep -Seconds 7
"guest " + (Ask $C 'return LOOTP.gearDiff()' 6)
"host  " + (Ask $H 'return LOOTP.gearDiff()' 6)
"--- the watcher: a new accessory the game gives must go to the partner, and not come back"
Lines $from 'Shared loot|here too' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 5 | ForEach-Object { if ($_.Length -gt 120) { $_.Substring(0, 120) } else { $_ } }
