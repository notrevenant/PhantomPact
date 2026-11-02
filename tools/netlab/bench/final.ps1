# The checks for the last fixes, on the two running copies. -Only picks: errors piles chests alone expiry slope.
param([string[]]$Only = @('errors', 'piles', 'chests', 'alone', 'expiry', 'slope'))
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
function Load { [void](Ask $H $load 8); [void](Ask $C $load 8) }
function Say([string]$s) { "$(Get-Date -Format HH:mm:ss) $s" }
function Show($from, [string]$Match) {
    Lines $from $Match | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 8 | ForEach-Object { '   ' + $(if ($_.Length -gt 125) { $_.Substring(0, 125) } else { $_ }) }
}
$face = 'local _,p=PBZ.getPlayer1() local l=p:K2_GetActorLocation() local yaw=math.deg(math.atan(XX-l.Y,WW-l.X)) p:K2_SetActorRotation({Pitch=0.0,Yaw=yaw,Roll=0.0},false) local pc=PBZ.getPlayer1() pc:SetControlRotation({Pitch=-15.0,Yaw=yaw,Roll=0.0}) return 1'
# One player goes up to a thing and presses interact. True if the press changed that backpack or the mod reported it.
function Press($g, [int]$X, [int]$Y, [int]$Z, [double]$Wait = 16) {
    [void](Ask $g "return REAL.flyTo($($X - 110), $Y, $($Z + 60))")
    Start-Sleep -Seconds 4
    [void](Ask $g 'return REAL.land(1)')
    Start-Sleep -Seconds 2
    [void](Ask $g ($face -replace 'XX', "$Y" -replace 'WW', "$X"))
    Start-Sleep -Seconds 1
    [void](Ask $g 'local cm=STORY.gm() cm:GM_Input("interact") return 1')
    Start-Sleep -Seconds $Wait
}
function Piles($g, [int]$Metres = 200) {
    $r = Ask $g "local _,p=PBZ.getPlayer1() local here=p:K2_GetActorLocation() local rows={} for _,a in ipairs(FindAllOf(`"BP_Rubbish_C`") or {}) do if PBZ.valid(a) then local l=a:K2_GetActorLocation() local d=PBZ.distance(l,here)/100 if d<=$Metres then local id=`"?`" pcall(function() id=a[`"Loot Item ID`"]:ToString() end) if id~=`"None`" then rows[#rows+1]={d,l,id} end end end end table.sort(rows,function(x,y) return x[1]<y[1] end) local t={} for i=1,math.min(6,#rows) do local r=rows[i] t[#t+1]=math.floor(r[2].X)..`",`"..math.floor(r[2].Y)..`",`"..math.floor(r[2].Z)..`",`"..r[3] end return table.concat(t,`" `")" 8
    @($r -split ' ' | Where-Object { $_ })
}
Load
$from0 = Log-End

if ($Only -contains 'errors') {
    Say '--- after the start'
    "status: " + (Ask $H 'return tostring(PBZ.game.mapName(select(2,PBZ.getPlayer1())))' 5) + " / " + (Ask $C 'return tostring(PBZ.game.mapName(select(2,PBZ.getPlayer1())))' 5) + " | " + (Ask $C 'return REAL.gap()' 5)
}

if ($Only -contains 'piles') {
    Say '--- a pile searched by each player'
    foreach ($who in 'host', 'guest') {
        $g, $o = if ($who -eq 'host') { $H, $C } else { $C, $H }
        $done = $false
        foreach ($p in (Piles $g 250)) {
            $x, $y, $z, $id = $p -split ','
            [void](Ask $H 'return REAL.bagMark()'); [void](Ask $C 'return REAL.bagMark()')
            $mark = Log-End
            Press $g $x $y $z 8
            $seen = @(Lines $mark 'Opened BP_Rubbish').Count
            "  $who at pile $id : reported $seen"
            "    host  " + (Ask $H 'return REAL.bagDiff()' 5)
            "    guest " + (Ask $C 'return REAL.bagDiff()' 5)
            Show $mark 'Opened |Shared|here too'
            if ($seen -gt 0) { $done = $true; break }
        }
        "  $who shared a pile: $done"
    }
}

if ($Only -contains 'alone') {
    Say '--- guest alone 900 m off, among enemies'
    [void](Ask $H 'return STORY.go("SZ_001")' 8); [void](Ask $C 'return STORY.go("SZ_001")' 8)
    Start-Sleep -Seconds 6
    "host $(Wait-Player $H 150), guest $(Wait-Player $C 150)"
    Load
    Start-Sleep -Seconds 8
    [void](Ask $H 'local pc=PBZ.getPlayer1() local gm=PBZ.gs():GetGameMode(pc) gm["Refresh Monster"](gm) return 1' 6)
    Start-Sleep -Seconds 4
    [void](Ask $C 'return REAL.flyTo(-130813, 42223, 1316)')
    Start-Sleep -Seconds 14
    [void](Ask $C 'return REAL.land(1)')
    Start-Sleep -Seconds 4
    Ask $C 'return REAL.gap()'
    Ask $C 'return REAL.alone()'
    $hp = 'local _,p=PBZ.getPlayer1() local h=PBZ.game.getHealth(p) return math.floor(h)'
    $low = [int](Ask $C $hp 5); $hp0 = $low; $hits = 0
    foreach ($i in 1..20) {
        Start-Sleep -Seconds 1
        $now = Ask $C $hp 3
        if ($now -and [int]$now -lt $low) { $hits++; $low = [int]$now }
    }
    "guest hp $hp0 -> $low, $hits drops in 20 s"
    Say ('after: ' + (Ask $C 'return REAL.alone()'))
    $mark = Log-End
    $e = (Ask $C 'return REAL.near()' 5) -split '\|'
    "guest kills " + ($e[1] -replace 'BP_Monster_', '') + " on its own"
    [void](Ask $C "local e=PBZ.coop.enemyActor(`"$($e[0])`") if e then PBZ.game.setHealth(e,1) end return 1")
    [void](Ask $C "return REAL.fight(`"$($e[0])`", 4)")
    Start-Sleep -Seconds 7
    Ask $C "return REAL.hp(`"$($e[0])`")"
    Show $mark 'Shared dust|died|rror'
    [void](Ask $C 'return REAL.land(1)')
}

if ($Only -contains 'expiry') {
    Say '--- Revive runs out: the player must die for real and come back'
    Send-Dev $H 'revive on'; Send-Dev $C 'revive on'
    Start-Sleep -Seconds 1
    $from = Log-End
    Ask $C 'local _,p=PBZ.getPlayer1() PBZ.game.setHealth(p,1) return "guest at 1"'
    Start-Sleep -Seconds 2
    Send-Dev $C 'revive'
    $end = (Get-Date).AddSeconds(75)
    $back = $false
    while ((Get-Date) -lt $end -and -not $back) {
        Start-Sleep -Seconds 3
        $back = @(Lines $from 'You died and respawned').Count -gt 0
    }
    Say "came back: $back"
    Ask $C 'local _,p=PBZ.getPlayer1() local h,m=PBZ.game.getHealth(p) return "guest hp "..math.floor(h).."/"..math.floor(m).." dead "..tostring(PBZ.game.isDead(p))'
    Show $from 'Revive: |died and respawned|Kill failed|partner is'
    Send-Dev $H 'revive off'; Send-Dev $C 'revive off'
    Start-Sleep -Seconds 1
    [void](Ask $C 'return REAL.land(1)')
}

if ($Only -contains 'slope') {
    Say '--- join on the same map, then a walk downhill: no yank back'
    $mark = Log-End
    Ask $C 'return REAL.gap()'
    Ask $C 'return tostring(PBZ.coop.joinPartner())'
    Start-Sleep -Seconds 5
    Ask $C 'return REAL.gap()'
    Ask $C 'local _,p=PBZ.getPlayer1() local l=p:K2_GetActorLocation() p:K2_SetActorLocation({X=l.X,Y=l.Y,Z=l.Z-500},false,{},true) return "dropped 5 m"'
    Start-Sleep -Seconds 3
    "yanked back: " + (@(Lines $mark 'ground isn.t loaded').Count -gt 0)
}

Say '--- script errors'
Show $from0 'Error executing|attempt to|Timer error|Kill failed|Partner key error|Online panel error'
"crashes: $(@(Get-ChildItem 'C:\PBZDev\platform\steam\ue4ss\crash_*.dmp').Count), copies alive: host $(Alive $H), guest $(Alive $C)"
'FINAL DONE'
