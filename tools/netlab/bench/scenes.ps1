# What's left to prove over Steam, on the two running copies. -Only picks scenes: alone death rest revive crash.
param([string[]]$Only = @('alone', 'death', 'rest', 'revive', 'crash'), [string]$Bell = 'SZ_001', [string]$Bell2 = 'SZ_005',
    [int]$FarX = -130813, [int]$FarY = 42223, [int]$FarZ = 816)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") return 1'
function Load { [void](Ask $H $load 8); [void](Ask $C $load 8) }
function Say([string]$s) { "$(Get-Date -Format HH:mm:ss) $s" }
function Log-Lines($from, [string]$Match) {
    Lines $from $Match | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 10 | ForEach-Object { '   ' + $(if ($_.Length -gt 125) { $_.Substring(0, 125) } else { $_ }) }
}
function Go-Both([string]$To) {
    [void](Ask $H "return STORY.go(`"$To`")" 8); [void](Ask $C "return STORY.go(`"$To`")" 8)
    Start-Sleep -Seconds 6
    $a = Wait-Player $H 150; $b = Wait-Player $C 150
    Load
    Start-Sleep -Seconds 8
    "both at $To : host $a, guest $b, " + (Ask $C 'return REAL.gap()')
}
Load
$from0 = Log-End

if ($Only -contains 'alone') {
    Say '--- guest alone, far from the host'
    Go-Both $Bell
    [void](Ask $C "return REAL.flyTo($FarX, $FarY, $($FarZ + 500))")
    Start-Sleep -Seconds 14
    [void](Ask $C 'return REAL.land(1)')
    Start-Sleep -Seconds 6
    Ask $C 'return REAL.gap()'
    Ask $C 'return REAL.alone()'
    "enemies known: host " + (@((Ask $H 'return REAL.names()' 5) -split ' ').Count - 1) + ", guest " + (@((Ask $C 'return REAL.names()' 5) -split ' ').Count - 1)
    $hp0 = Ask $C 'return REAL.near()' 5
    Say "nearest to the guest: $hp0"
    foreach ($i in 1..4) {
        Start-Sleep -Seconds 5
        Say ("guest hp " + (Ask $C 'local _,p=PBZ.getPlayer1() local h,m=PBZ.game.getHealth(p) return math.floor(h).."/"..math.floor(m)' 5) + " | " + (Ask $C 'return REAL.near()' 5))
    }
    Say ('after: ' + (Ask $C 'return REAL.alone()'))
}

if ($Only -contains 'death') {
    Say '--- the guest dies beside the host, among enemies'
    $from = Log-End
    [void](Ask $H "return REAL.flyTo($($FarX + 200), $FarY, $($FarZ + 500))")
    Start-Sleep -Seconds 10
    [void](Ask $H 'return REAL.land(1)')
    Start-Sleep -Seconds 4
    Ask $C 'return REAL.gap()'
    Ask $C 'local _,p=PBZ.getPlayer1() PBZ.game.setMinHealth(p,0) PBZ.game.killPlayer(p) return "killed the guest"'
    $end = (Get-Date).AddSeconds(60)
    $back = $false
    while ((Get-Date) -lt $end -and -not $back) {
        Start-Sleep -Seconds 3
        $back = @(Lines $from 'You died and respawned').Count -gt 0
    }
    Say "respawned: $back"
    Start-Sleep -Seconds 8
    Ask $C 'return REAL.gap()'
    Ask $C 'local _,p=PBZ.getPlayer1() local h,m=PBZ.game.getHealth(p) return "guest hp "..math.floor(h).."/"..math.floor(m).." dead "..tostring(PBZ.game.isDead(p))'
    Ask $H 'local _,p=PBZ.getPlayer1() local h,m=PBZ.game.getHealth(p) return "host hp "..math.floor(h).."/"..math.floor(m).." dead "..tostring(PBZ.game.isDead(p))'
    Log-Lines $from 'died|respawn|partner is down|partner is back|Ghost hidden|Ghost visible|removed again'
    [void](Ask $C 'return REAL.land(1)'); [void](Ask $H 'return REAL.land(1)')
}

if ($Only -contains 'rest') {
    Say '--- a bell rest, each side'
    Go-Both $Bell
    foreach ($g in $H, $C) {
        $from = Log-End
        Ask $g 'local pc=PBZ.getPlayer1() local gm=PBZ.gs():GetGameMode(pc) gm["Refresh Monster"](gm) return "rested"' 6
        Start-Sleep -Seconds 6
        Log-Lines $from 'Rested at a bell|rested at a bell|respawning enemies|host died'
    }
}

if ($Only -contains 'revive') {
    Say '--- Revive, then a map change, then Revive again (the ring crashed here before the fix)'
    Go-Both $Bell
    & (Join-Path $PSScriptRoot 'fights.ps1') -From 4 -To 4 | Where-Object { $_ -match 'Revive:|STATE|rror|--- ' } | Select-Object -Last 8 | ForEach-Object { '   ' + $(if ($_.Length -gt 125) { $_.Substring(0, 125) } else { $_ }) }
    Go-Both $Bell2
    & (Join-Path $PSScriptRoot 'fights.ps1') -From 4 -To 4 | Where-Object { $_ -match 'Revive:|STATE|rror|--- ' } | Select-Object -Last 8 | ForEach-Object { '   ' + $(if ($_.Length -gt 125) { $_.Substring(0, 125) } else { $_ }) }
    Send-Dev $H 'revive off'; Send-Dev $C 'revive off'
    Start-Sleep -Seconds 1
}

if ($Only -contains 'crash') {
    Say '--- the moment that crashed: a hit, then a map change inside 0.9 s'
    foreach ($to in $Bell, $Bell2, $Bell) {
        $fire = 'local _,p=PBZ.getPlayer1() PBZ.game.staggerSelf(p,"CharacterState.Hitreact.State.Normal.Heavy") return STORY.go("' + $to + '")'
        "hit and go to $to : " + (Ask $H $fire 8)
        "hit and go to $to : " + (Ask $C $fire 8)
        Start-Sleep -Seconds 6
        "host $(Wait-Player $H 150), guest $(Wait-Player $C 150)"
        Load
        Start-Sleep -Seconds 3
    }
}

Say '--- script errors in all of it'
Log-Lines $from0 'Error executing|attempt to|Timer error|Partner key error|Online panel error'
"copies alive: host $(Alive $H), guest $(Alive $C)"
'SCENES DONE'
