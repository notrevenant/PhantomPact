# Does a boss killed by a real hit stay dead after a rest, with co-op off? One copy alone, Role = Off, nothing of the mod running.
param([string]$Class = 'BP_Monster_GuiChai_Yellow_MoDao_C', [int]$X = -183873, [int]$Y = 119290, [int]$Z = -4012, [string]$Bell = '')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$lab = 'C:\Users\TheCo\Downloads\PhantomPact-online\tools\netlab'
. (Join-Path $lab 'dev.ps1')
$C = $script:C
$quit = 'eval local pc=PBZ.getPlayer1() StaticFindObject("/Script/Engine.Default__KismetSystemLibrary"):QuitGame(pc, pc, 0, false)'
if (Get-Process -Id $C.Pid -ErrorAction SilentlyContinue) {
    Send-Dev $C $quit
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline -and (Get-Process -Id $C.Pid -ErrorAction SilentlyContinue)) { Start-Sleep -Seconds 1 }
}
$env:steam_master_ipc_name_override = 'steam2'
$c2 = Start-DevGame -Role Off -Instance 2
$c2 | ConvertTo-Json | Set-Content "$lab\bench\dev-guest.json"
"alone: pid $($c2.Pid)"
Start-Sleep -Seconds 20
"in the world: $(Wait-DevGameplay $c2 300 -AfterCrash) at $(Get-Date -Format HH:mm:ss)"
$script:C = $c2
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") return 1'
"load: " + (Ask $c2 $load 8)
"map: " + (Ask $c2 'return tostring(PBZ.game.mapName(select(2,PBZ.getPlayer1())))' 6)
if ($Bell) {
    [void](Ask $c2 "return STORY.go(`"$Bell`")" 8)
    Start-Sleep -Seconds 6
    "travel: " + (Wait-Player $c2 150)
    Start-Sleep -Seconds 4
    [void](Ask $c2 $load 8)
}
[void](Ask $c2 "return REAL.flyTo($($X - 900), $Y, $($Z + 400))")
Start-Sleep -Seconds 14
[void](Ask $c2 'return REAL.land(1)')
Start-Sleep -Seconds 3
$look = "local e=FindFirstOf(`"$Class`") if not PBZ.valid(e) then return `"none here`" end local h,m=PBZ.game.getHealth(e) local l=e:K2_GetActorLocation() return string.format(`"hp %.0f/%.0f dead %s at %.0f %.0f`",h or -1,m or -1,tostring(PBZ.game.isDead(e)),l.X,l.Y)"
"boss: " + (Ask $c2 $look 5)
$hit = "local e=FindFirstOf(`"$Class`") if not PBZ.valid(e) or PBZ.game.isDead(e) then return `"dead`" end PBZ.game.setMinHealth(e,0) PBZ.game.setHealth(e,30) FIGHT.beside(e,170) return FIGHT.swing()"
foreach ($i in 1..14) {
    $r = Ask $c2 $hit 4
    Start-Sleep -Milliseconds 900
    if ($r -eq 'dead') { "dead after $i tries"; break }
}
"after hits: " + (Ask $c2 $look 5)
Start-Sleep -Seconds 12
"story so far unchanged? " + (Ask $c2 'return STORY.where()' 5)
Ask $c2 'local pc=PBZ.getPlayer1() local gm=PBZ.gs():GetGameMode(pc) gm["Refresh Monster"](gm) return "rested"' 6
Start-Sleep -Seconds 12
"after the rest: " + (Ask $c2 $look 5)
$all = 'local out={} for _,e in ipairs(FindAllOf("' + $Class + '") or {}) do if PBZ.valid(e) then local h=PBZ.game.getHealth(e) out[#out+1]=string.format("hp %.0f dead %s",h or -1,tostring(PBZ.game.isDead(e))) end end return #out.." of them: "..table.concat(out," ; ")'
"all of them: " + (Ask $c2 $all 5)
