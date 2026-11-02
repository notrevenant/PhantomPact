# The guest waits out a fight it joined during, and the host dies in it: it should go to the host once they're back up.
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$state = 'local _,p=PBZ.getPlayer1() local l=p:K2_GetActorLocation() local h=PBZ.game.getHealth(p) return string.format("mode %s hp %.0f at %.0f %.0f spectating %s watching %s partner fighting %s ",tostring(p.CharacterMovement.MovementMode),h or -1,l.X,l.Y,tostring(PBZ.game.isSpectating()),tostring(PBZ.net.watchingFight),tostring(PBZ.net.partnerFighting))..REAL.gap()'
$load = 'dofile("C:/PBZDev/netlab/real.lua") return 1'
[void](Ask $C $load 8)
"waiting: " + (Ask $C $state 5)
"host down: " + (Ask $H 'local _,p=PBZ.getPlayer1() PBZ.game.killPlayer(p) return "killed"' 6)
$from = Log-End
foreach ($i in 1..12) {
    Start-Sleep -Seconds 4
    "$(Get-Date -Format HH:mm:ss) " + (Ask $C $state 5)
}
"host: " + (Ask $H 'local _,p=PBZ.getPlayer1() local h=PBZ.game.getHealth(p) return "hp "..tostring(h).." dead "..tostring(PBZ.game.isDead(p))' 5)
Lines $from 'Going to|boss fight|You died|respawned|couldn.t reach' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 8 | ForEach-Object { '   ' + $_.Substring(0, [Math]::Min(125, $_.Length)) }
