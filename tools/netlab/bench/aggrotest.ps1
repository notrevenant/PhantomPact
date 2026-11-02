# What makes an enemy change who it's after: standing close, a hit, or being told.
param([string]$Boss = 'sp:HookManP1_Seq022')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/aggro.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
function Now { Ask $H 'return AGGRO.now(6000)' 5 }
[void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
"start: " + (Now)
[void](Ask $H 'return AGGRO.watch(40, 6000)' 5)
"--- host right beside it, guest 12 m off"
[void](Ask $C "return REAL.hoverTo(`"$Boss`", 1200)"); [void](Ask $H "return REAL.hoverTo(`"$Boss`", 150)")
Start-Sleep -Seconds 1
[void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
Start-Sleep -Seconds 7
"after 8 s: " + (Now)
"--- guest right beside it, host 12 m off"
[void](Ask $H "return REAL.hoverTo(`"$Boss`", 1200)"); [void](Ask $C "return REAL.hoverTo(`"$Boss`", 150)")
Start-Sleep -Seconds 1
[void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
Start-Sleep -Seconds 7
"after 8 s: " + (Now)
"--- host far (12 m), hits land from the guest only"
[void](Ask $C "return REAL.fight(`"$Boss`", 3)")
Start-Sleep -Seconds 5
"after guest hits: " + (Now)
"--- guest far, hits from the host only"
[void](Ask $C "return REAL.hoverTo(`"$Boss`", 1200)")
Start-Sleep -Seconds 1
[void](Ask $C 'return REAL.land(1)')
[void](Ask $H "return REAL.fight(`"$Boss`", 3)")
Start-Sleep -Seconds 5
"after host hits: " + (Now)
Lines (Log-End) 'x' | Out-Null
