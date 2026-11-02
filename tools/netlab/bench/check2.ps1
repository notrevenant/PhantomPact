# Join from far with the new "not now" checks, then a walk off a ledge after it, then the guest beside an enemy far from the host.
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$findApi = 'local a for _,f in pairs(PBZ.coop.handlers) do for i=1,250 do local n,v=debug.getupvalue(f,i) if n==nil then break end if n=="api" then a=v end end end'
$load = "dofile(`"C:/PBZDev/netlab/real.lua`") dofile(`"C:/PBZDev/netlab/story.lua`") dofile(`"C:/PBZDev/netlab/lootprobe.lua`") $findApi API=a return 1"
[void](Ask $H $load 8); [void](Ask $C $load 8)
"why not now? paused " + (Ask $C 'return tostring(PBZ.gs():IsGamePaused((PBZ.getPlayer1())))' 5) + ", bell " + (Ask $C 'return tostring(API.localcoop.bellMenuUp())' 5) + ", screen " + (Ask $C 'return tostring(API.localcoop.screenUp())' 5) + ", boss " + (Ask $C 'return tostring(PBZ.game.bossFightActive())' 5) + ", cutscene " + (Ask $C 'return tostring(PBZ.game.inCutscene())' 5)
[void](Ask $C 'local _,p=PBZ.getPlayer1() local l=p:K2_GetActorLocation() return REAL.flyTo(l.X+25000,l.Y,l.Z+800)')
Start-Sleep -Seconds 8
[void](Ask $C 'return REAL.land(1)')
Start-Sleep -Seconds 4
"apart: " + (Ask $C 'return REAL.gap()' 5)
$from = Log-End
"join: " + (Ask $C 'return tostring(PBZ.coop.joinPartner())' 6)
Start-Sleep -Seconds 6
"after: " + (Ask $C 'return REAL.gap()' 5)
"arrival watch still on: " + (Ask $C 'return tostring(PBZ.net.arrival ~= nil)' 5)
Ask $C 'local _,p=PBZ.getPlayer1() local l=p:K2_GetActorLocation() p:K2_SetActorLocation({X=l.X,Y=l.Y,Z=l.Z-500},false,{},true) return "dropped 5 m"'
Start-Sleep -Seconds 4
"yanked back: " + (@(Lines $from 'ground isn.t loaded').Count -gt 0)
