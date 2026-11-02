param([string]$Item = 'Weapon_Material_01')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
[void](Ask $H 'return REAL.bagMark()' 6); [void](Ask $C 'return REAL.bagMark()' 6)
$from = Log-End
Ask $C "return LOOTP.buy(`"$Item`")" 6
Start-Sleep -Seconds 3
"host  " + (Ask $H 'return REAL.bagDiff()' 6)
"guest " + (Ask $C 'return REAL.bagDiff()' 6)
Lines $from 'Shared loot' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 3
