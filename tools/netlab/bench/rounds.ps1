# The wait rule in a real fight: a live boss, real swings, and what each side saw.
#   1 the guest dies, the host fights on, then the host dies too.
#   2 the host dies, the guest fights on, then the guest dies too.
#   3 the guest dies, the host kills the boss with real hits.
#   4 the host dies, the guest kills the boss with real hits.
param([int[]]$Rounds = @(1, 2, 3), [string]$Boss = '', [int]$BossX = -67612, [int]$BossY = 78394, [int]$BossZ = 858, [int]$Swings = 3)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
function Say([string]$s) { "$(Get-Date -Format HH:mm:ss) $s" }
function Me($g) { Ask $g 'local _,p=PBZ.getPlayer1() local h,m=PBZ.game.getHealth(p) return "hp "..math.floor(h).."/"..math.floor(m).." dead "..tostring(PBZ.game.isDead(p)).." bars "..tostring(FIGHT.bars()).." watching "..tostring(PBZ.game.isSpectating())' 5 }
function BossHp { "boss h " + (Ask $H "return REAL.hp(`"$Boss`")" 4) + " | g " + (Ask $C "return REAL.hp(`"$Boss`")" 4) }
function Hits($g) {
    [void](Ask $g "return REAL.hoverTo(`"$Boss`", 300)" 4)
    Start-Sleep -Seconds 2
    [void](Ask $g 'return REAL.land(1)' 4)
    [void](Ask $g "return REAL.fight(`"$Boss`", $Swings)" 4)
    Start-Sleep -Seconds ($Swings * 2)
}
function Arena {
    [void](Ask $H "return REAL.flyTo($($BossX - 900), $BossY, $($BossZ + 400))"); [void](Ask $C "return REAL.flyTo($($BossX - 1000), $BossY, $($BossZ + 400))")
    Start-Sleep -Seconds 11
    [void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
    if (-not $script:Boss) {
        $script:Boss = ((Ask $H 'local out={} for name,a in pairs(PBZ.coop.enemies()) do if PBZ.valid(a) and not PBZ.game.isDead(a) and PBZ.game.isBoss(a) then out[#out+1]=name end end return table.concat(out," ")' 6) -split ' ')[0]
        "boss: $script:Boss"
    }
    Hits $H
    "fight: host " + (Ask $H 'return FIGHT.bars()' 4) + ", guest " + (Ask $C 'return FIGHT.bars()' 4) + ", " + (Ask $C 'return REAL.gap()' 4)
    BossHp
}
function Back($g, [int]$Seconds = 45) {
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) {
        Start-Sleep -Seconds 2
        if ((Ask $g 'return tostring(PBZ.game.isDead(select(2,PBZ.getPlayer1())))' 4) -eq 'false') { return $true }
    }
    return $false
}
$kill = 'local _,p=PBZ.getPlayer1() PBZ.game.killPlayer(p) return "killed"'
foreach ($r in $Rounds) {
    Say "--- round $r"
    Arena
    $from = Log-End
    $first, $second = if ($r -eq 2 -or $r -eq 4) { $H, $C } else { $C, $H }
    Say ("first down: " + (Ask $first $kill 6))
    foreach ($i in 1..3) {
        Start-Sleep -Seconds 4
        Say ("  dead one: " + (Me $first))
        Say ("  other:    " + (Me $second))
    }
    Say 'the other one fights on'
    Hits $second
    Say (BossHp)
    Hits $second
    Say (BossHp)
    Say ("  dead one: " + (Me $first))
    Say ("  other:    " + (Me $second))
    if ($r -ge 3) {
        Say ("dust before: host " + (Ask $H 'return FIGHT.dust()' 4) + ", guest " + (Ask $C 'return FIGHT.dust()' 4))
        [void](Ask $H "return REAL.keepLow(`"$Boss`", 14, 40)" 5)
        Hits $second
        Hits $second
        Say (BossHp)
    } else {
        Say ("second down: " + (Ask $second $kill 6))
    }
    Say "the first one is back: $(Back $first)"
    if ($r -lt 3) { Say "the second one is back: $(Back $second)" }
    Start-Sleep -Seconds 12
    Say ("first:  " + (Me $first))
    Say ("second: " + (Me $second))
    Say (BossHp)
    if ($r -ge 3) { Say ("dust after: host " + (Ask $H 'return FIGHT.dust()' 4) + ", guest " + (Ask $C 'return FIGHT.dust()' 4)) }
    Lines $from "you'll be back|You died|host died|watching|camera back|Back on your feet|Status: your partner is (down|back)|Showing boss bar|given no place|Enemy died here: BP_Monster_(Gui|Female)" | Where-Object { $_ -notmatch 'eval|> ' } | Select-Object -First 20 | ForEach-Object { '   ' + $(if ($_.Length -gt 130) { $_.Substring(0, 130) } else { $_ }) }
    "bars shown: host " + @(Lines $from 'PBZCoop\] Showing boss bar').Count + ", guest " + @(Lines $from 'PBZCoop#2\] Showing boss bar').Count
    "script errors: " + @(Lines $from 'Error executing|attempt to|Timer error|Kill failed' | Where-Object { $_ -notmatch 'eval' }).Count
    [void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
    Start-Sleep -Seconds 8
}
"crashes: $(@(Get-ChildItem 'C:\PBZDev\platform\steam\ue4ss\crash_*.dmp').Count), copies alive: host $(Alive $H), guest $(Alive $C)"
'ROUNDS DONE'
