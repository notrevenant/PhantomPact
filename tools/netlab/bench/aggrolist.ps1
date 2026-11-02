# Only one player left on its hatred list: does the enemy turn and go for that one, with the other standing closer?
param([string]$Boss = 'sp:HookManP1_Seq022')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/aggro.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
function Now { (Get-Date -Format HH:mm:ss) + ' ' + (Ask $H 'return AGGRO.now(6000)' 5) + ' | ' + ((Ask $H "return REAL.hp(`"$Boss`")" 4) -replace '^\S+ dead=\S+ ', '') }
function Me($g) { Ask $g 'local _,p=PBZ.getPlayer1() local h=PBZ.game.getHealth(p) return math.floor(h)' 4 }
$drop = "local e=PBZ.coop.enemyActor(`"$Boss`") local hm=e.BP_PBZHatredManagerComponent local _,p=PBZ.getPlayer1() local g=PBZ.net.ghost"
"--- host beside it, guest 12 m off, only the guest on its list"
[void](Ask $C "return REAL.hoverTo(`"$Boss`", 1200)"); [void](Ask $H "return REAL.hoverTo(`"$Boss`", 150)")
Start-Sleep -Seconds 1
[void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
Start-Sleep -Seconds 1
Now
Ask $H "$drop hm:RemoveActorFromHatredList(p) return AGGRO.hatred(e)" 5
foreach ($i in 1..5) { Start-Sleep -Seconds 2; Now }
"host hp " + (Me $H) + ", guest hp " + (Me $C)
"--- guest beside it, host 12 m off, only the host on its list"
[void](Ask $H "return REAL.hoverTo(`"$Boss`", 1200)"); [void](Ask $C "return REAL.hoverTo(`"$Boss`", 150)")
Start-Sleep -Seconds 1
[void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
Start-Sleep -Seconds 1
Ask $H "$drop hm:AddActorToHatredList(p, {}) hm:RemoveActorFromHatredList(g) return AGGRO.hatred(e)" 5
foreach ($i in 1..5) { Start-Sleep -Seconds 2; Now }
"host hp " + (Me $H) + ", guest hp " + (Me $C)
Ask $H "$drop hm:AddActorToHatredList(g, {}) return AGGRO.hatred(e)" 5
