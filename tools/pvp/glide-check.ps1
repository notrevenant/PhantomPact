# Mirrored enemies following the host (puppets.lua steer, SNAP_CM), on a running two-copy session (pvp-session.ps1): the
# same enemy is spawned in both worlds, then the guest's copy is pushed away and its distance to the host's copy is
# sampled. 2 m and 8 m: it comes back without a jump. 15 m: it jumps at once.
$run = "$PSScriptRoot\pvp-run.ps1"
& $run -I 1 -Cmd 'spawnenemy BP_Monster_MaleThug_Sword_Blue 900' -Wait 2 | Out-Null
& $run -I 2 -Cmd 'spawnenemy BP_Monster_MaleThug_Sword_Blue 900' -Wait 3 | Out-Null
$pair = 'local e,r for n,x in pairs(PBZ.net.remoteEnemies) do local c=PBZ.coop.enemyActor(n) if PBZ.valid(c) then e,r=c,x end end'
# Sampled inside the game every 100 ms: each read over the mod's command file takes a second or more. r is the table the
# mod keeps updating, so r.X is always the host's newest. game.after, not LoopAsync: that thread corrupts Lua's heap.
function Sample([string]$Name, [double]$Push) {
    "--- $Name"
    $code = "eval $pair if not e then return 'no enemy pair' end e:K2_SetActorLocation({X=r.X+$Push,Y=r.Y,Z=r.Z},false,{},true) local n,out=0,{} local function step() if not PBZ.valid(e) then return end n=n+1 local a=e:K2_GetActorLocation() out[n]=string.format('%.0f',math.sqrt((a.X-r.X)^2+(a.Y-r.Y)^2)) if n<=20 then PBZ.game.after(0.1,step) else PBZ.log('glide samples: '..table.concat(out,' ')) end end PBZ.game.after(0.1,step) return 'pushed'"
    & $run -I 2 -Cmd $code -Wait 3.5
}
Sample 'walks back (2 m)' 200
Sample 'glides back (8 m)' 800
Sample 'jump (15 m)' 1500
