# The "wait until everyone is dead" rule in a real boss fight.
#   1 the guest dies: held. The host dies too: both come back.
#   2 the host dies: held. The guest dies too: both come back.
#   3 the guest dies: held. The boss dies: the guest comes back.
param([int[]]$Rounds = @(1, 2, 3), [int]$BossX = -122346, [int]$BossY = 73997, [int]$BossZ = 2074, [int]$Hold = 18)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") return 1'
function Load { [void](Ask $H $load 8); [void](Ask $C $load 8) }
function Say([string]$s) { "$(Get-Date -Format HH:mm:ss) $s" }
function State($g) { Ask $g 'local _,p=PBZ.getPlayer1() local h,m=PBZ.game.getHealth(p) return "hp "..math.floor(h).."/"..math.floor(m).." dead "..tostring(PBZ.game.isDead(p)).." bars "..tostring(FIGHT.bars()).." watching "..tostring(PBZ.game.isSpectating())' 5 }
function Show($from, [string]$Match) {
    Lines $from $Match | Where-Object { $_ -notmatch 'eval|> ' } | Select-Object -First 12 | ForEach-Object { '   ' + $(if ($_.Length -gt 120) { $_.Substring(0, 120) } else { $_ }) }
}
# Both beside the boss, on the ground, with the fight on.
function Arena {
    [void](Ask $H "return REAL.flyTo($($BossX - 900), $BossY, $($BossZ + 400))"); [void](Ask $C "return REAL.flyTo($($BossX - 1000), $BossY, $($BossZ + 400))")
    Start-Sleep -Seconds 10
    [void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
    $end = (Get-Date).AddSeconds(25)
    while ((Get-Date) -lt $end) {
        Start-Sleep -Seconds 2
        if ((Ask $H 'return FIGHT.bars()' 4) -notmatch '^0') { break }
    }
    "fight: host " + (Ask $H 'return FIGHT.bars()' 4) + ", guest " + (Ask $C 'return FIGHT.bars()' 4) + ", " + (Ask $C 'return REAL.gap()' 4)
}
$kill = 'local _,p=PBZ.getPlayer1() PBZ.game.killPlayer(p) return "killed"'
Load
if ((Ask $H 'return tostring(PBZ.game.mapName(select(2,PBZ.getPlayer1())))' 6) -ne 'PBZ_Pangzhen_WP') {
    [void](Ask $H 'return STORY.go("SZ_001")' 8); [void](Ask $C 'return STORY.go("SZ_001")' 8)
    Start-Sleep -Seconds 6
    "host $(Wait-Player $H 150), guest $(Wait-Player $C 150)"
    Load
    Start-Sleep -Seconds 6
}
foreach ($r in $Rounds) {
    Say "--- round $r"
    Arena
    $first, $second = if ($r -eq 2) { $H, $C } else { $C, $H }
    $from = Log-End
    Say ("first down: " + (Ask $first $kill 6))
    Start-Sleep -Seconds $Hold
    Say ("after $Hold s, dead one: " + (State $first))
    Say ("              other:    " + (State $second))
    if ($r -eq 3) {
        Say 'the host kills the boss'
        Ask $H "local e=PBZ.coop.enemyActor(`"sp:YanQianSui`") if e then PBZ.game.setHealth(e,1) return REAL.fight(`"sp:YanQianSui`",3) end return `"no boss`"" 6
        Start-Sleep -Seconds 6
        [void](Ask $H "local e=PBZ.coop.enemyActor(`"sp:YanQianSui`") if e and not PBZ.game.isDead(e) then PBZ.game.kill(e) end return 1" 5)
    } else {
        Say ("second down: " + (Ask $second $kill 6))
    }
    $end = (Get-Date).AddSeconds(40)
    $back = $false
    while ((Get-Date) -lt $end -and -not $back) {
        Start-Sleep -Seconds 2
        $back = (Ask $first 'return tostring(PBZ.game.isDead(select(2,PBZ.getPlayer1())))' 4) -eq 'false'
    }
    Say "the first one is back: $back"
    Start-Sleep -Seconds 12
    Say ("first:  " + (State $first))
    Say ("second: " + (State $second))
    Show $from "you'll be back|You died|host died|watching|camera back|Back on your feet|Status: your partner is (down|back)"
    [void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
    if ($r -eq 3) {
        [void](Ask $H 'local pc=PBZ.getPlayer1() local gm=PBZ.gs():GetGameMode(pc) gm["Refresh Monster"](gm) return 1' 6)
    }
    Start-Sleep -Seconds 6
}
"script errors: " + @(Lines $from 'Error executing|attempt to|Timer error|Kill failed' | Where-Object { $_ -notmatch 'eval' }).Count
"crashes: $(@(Get-ChildItem 'C:\PBZDev\platform\steam\ue4ss\crash_*.dmp').Count), copies alive: host $(Alive $H), guest $(Alive $C)"
'WAIT DONE'
