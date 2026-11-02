# A brand-new accessory on the guest and a brand-new medicine on the host: each must reach the other by itself.
param([string]$Ac = 'AC_Chaos', [string]$Med = 'Medicine_AdditionalRecover')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
"gap: " + (Ask $C 'return REAL.gap()' 5)
"host  " + (Ask $H 'return LOOTP.gearMark()' 6)
"guest " + (Ask $C 'return LOOTP.gearMark()' 6)
$from = Log-End
"--- accessory $Ac appears on the guest"
Ask $C "return LOOTP.addAc(`"$Ac`", `"push`")" 6
Start-Sleep -Seconds 9
"host  " + (Ask $H 'return LOOTP.gearDiff()' 6)
"guest " + (Ask $C 'return LOOTP.gearDiff()' 6)
"--- medicine $Med appears on the host"
Ask $H "return LOOTP.addMed(`"$Med`")" 6
Start-Sleep -Seconds 9
"host  " + (Ask $H 'return LOOTP.gearDiff()' 6)
"guest " + (Ask $C 'return LOOTP.gearDiff()' 6)
Lines $from 'Shared loot|here too|Status:|rror' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 8 | ForEach-Object { if ($_.Length -gt 120) { $_.Substring(0, 120) } else { $_ } }
