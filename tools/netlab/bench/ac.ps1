param([string]$Ac = 'AC_BreakRegen')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$C = $script:C
[void](Ask $C 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1' 8)
[void](Ask $C 'return LOOTP.gearMark()' 6)
Ask $C "return LOOTP.addAc(`"$Ac`", `"give`")" 6
Start-Sleep -Seconds 1
"after give: " + (Ask $C 'return LOOTP.gearDiff()' 6)
Ask $C "return LOOTP.addAc(`"$Ac`", `"push`")" 6
Start-Sleep -Seconds 1
"after push: " + (Ask $C 'return LOOTP.gearDiff()' 6)
