# Can a dead player's respawn be held and let go? Guest dies, the death screen's tick is held, then released.
param([int]$Hold = 25)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
$from = Log-End
Ask $C 'local _,p=PBZ.getPlayer1() PBZ.game.killPlayer(p) return "killed"' 6
Start-Sleep -Seconds 2
Ask $C 'local _,p=PBZ.getPlayer1() local w=p["Death Widget"] if PBZ.valid(w) then w.NotTick=true return "held "..tostring(w.NotTick).." finish "..tostring(w.IsFinishDead) end return "no widget"' 6
$state = 'local _,p=PBZ.getPlayer1() local w=p["Death Widget"] local a,b="?","?" if PBZ.valid(w) then a=tostring(w.IsFinishDead) b=tostring(w.IsCompleteStreaming) end return "dead "..tostring(PBZ.game.isDead(p)).." finish "..a.." streaming "..b'
$t0 = Get-Date
while (((Get-Date) - $t0).TotalSeconds -lt $Hold) {
    Start-Sleep -Seconds 6
    "$([int]((Get-Date) - $t0).TotalSeconds + 2) s: " + (Ask $C $state 5)
}
"respawn so far: " + (@(Lines $from 'You died and respawned').Count -gt 0)
Ask $C 'local _,p=PBZ.getPlayer1() local w=p["Death Widget"] if PBZ.valid(w) then w.NotTick=false return "released" end return "no widget"' 6
$t1 = Get-Date
$back = $false
while (((Get-Date) - $t1).TotalSeconds -lt 30 -and -not $back) {
    Start-Sleep -Seconds 1
    $back = @(Lines $from 'You died and respawned').Count -gt 0
}
"respawned $([int]((Get-Date) - $t1).TotalSeconds) s after the release: $back"
Ask $C 'local _,p=PBZ.getPlayer1() local h,m=PBZ.game.getHealth(p) return "guest hp "..math.floor(h).."/"..math.floor(m).." dead "..tostring(PBZ.game.isDead(p))' 5
Lines $from 'watching|camera back|Back on your feet' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 5 | ForEach-Object { if ($_.Length -gt 110) { $_.Substring(0, 110) } else { $_ } }
