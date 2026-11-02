# Told who to go for, does the enemy really go there, with the other player closer?
param([string]$Boss = 'sp:HookManP1_Seq022')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/aggro.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
function Now { (Get-Date -Format HH:mm:ss) + ' ' + (Ask $H 'return AGGRO.now(6000)' 5) + ' | ' + (Ask $H "return REAL.hp(`"$Boss`")" 4) }
function Me($g) { Ask $g 'local _,p=PBZ.getPlayer1() local h,m=PBZ.game.getHealth(p) return "hp "..math.floor(h)' 4 }
"--- host beside it, guest 12 m off, told to go for the guest"
[void](Ask $C "return REAL.hoverTo(`"$Boss`", 1200)"); [void](Ask $H "return REAL.hoverTo(`"$Boss`", 150)")
Start-Sleep -Seconds 1
[void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
Start-Sleep -Seconds 1
[void](Ask $H "return AGGRO.force(`"$Boss`", `"GUEST`", 14)" 5)
foreach ($i in 1..5) { Start-Sleep -Seconds 2; Now }
"host " + (Me $H) + ", guest " + (Me $C)
Start-Sleep -Seconds 5
"--- guest beside it, host 12 m off, told to go for the host"
[void](Ask $H "return REAL.hoverTo(`"$Boss`", 1200)"); [void](Ask $C "return REAL.hoverTo(`"$Boss`", 150)")
Start-Sleep -Seconds 1
[void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
Start-Sleep -Seconds 1
[void](Ask $H "return AGGRO.force(`"$Boss`", `"HOST`", 14)" 5)
foreach ($i in 1..5) { Start-Sleep -Seconds 2; Now }
"host " + (Me $H) + ", guest " + (Me $C)
Start-Sleep -Seconds 4
