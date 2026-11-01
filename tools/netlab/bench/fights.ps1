# Boss fights on the two running copies (dev-start.ps1 for both first). Steps run in order; -From skips the first ones.
#   1 the host starts the elite: bar, health both ways, then a host kill mid-swing
#   2 the guest starts it: bar, the guest's real killing blow, dust on both sides
#   3 the guest dies during the fight: the host's goes on, the guest comes back
#   4 revive: the guest goes down, the host strikes it up
param([int]$From = 1, [int]$To = 4)
$b = $PSScriptRoot
$lab = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path -replace '\\', '/'
function X { param([string]$H, [string]$C, [double]$Wait = 1.0, [switch]$All) & "$b\x.ps1" -H $H -C $C -Wait $Wait -All:$All }
function Head([string]$s) { "--- $s  $(Get-Date -Format HH:mm:ss)" }
$load = "dofile(`"$lab/perf.lua`") dofile(`"$lab/pair.lua`") dofile(`"$lab/fights.lua`") return FIGHT.huds()"
X -H $load -C $load
$hook = 'return FIGHT.hookLoot("/Game/RenewalContent/Prototypes/Character/BP_RenewalNPC.BP_RenewalNPC_C:LootItems")'
X -H $hook -C $hook
$fly = 'local e=FIGHT.boss() local l=e:K2_GetActorLocation() local _,p=PBZ.getPlayer1() p.CharacterMovement:SetMovementMode(5,0) p:K2_SetActorLocation({X=l.X-500,Y=l.Y,Z=l.Z+200},false,{},true) return "flying"'
$land = 'local _,p=PBZ.getPlayer1() p.CharacterMovement:SetMovementMode(1,0) PBZ.game.setMinHealth(p,1) return FIGHT.state()'
$sample = 'FIGHT.t0=os.clock() FIGHT.n=0 LoopInGameThreadWithDelay(250,function() FIGHT.n=FIGHT.n+1 if FIGHT.n<=24 then PBZ.log(string.format("STATE bars %.2f %s %s",os.clock()-FIGHT.t0,FIGHT.bars(),FIGHT.huds())) end return false end) return 1'
if ($From -le 1 -and $To -ge 1) {
    Head 'host starts the elite'
    X -H '!spawner XIGU_1_4_A_EliteSword' -Wait 2.5
    X -H $fly -Wait 4.5
    X -H $land -C $sample -Wait 3.5
    X -H 'return FIGHT.state()' -C 'return FIGHT.state()' -Wait 1
    Head 'host 60%, then a guest hit'
    X -H 'PBZ.game.setHealth(FIGHT.boss(),7000) return FIGHT.bars()' -Wait 1
    X -C 'local e=FIGHT.boss() PBZ.game.setHealth(e,PBZ.game.getHealth(e)-1000) return FIGHT.bars()' -Wait 1
    X -H 'return FIGHT.state()' -C 'return FIGHT.state()' -Wait 1
    X -H '!puppets' -C '!puppets' -Wait 0.8
    Head 'host kills it mid-swing: what the boss does after'
    X -C 'local e=FIGHT.boss() FIGHT.e=e PBZ.game.after(0.15,function() PBZ.log("LOOT guest +0.15 "..FIGHT.doing(FIGHT.e)) end) PBZ.game.after(0.6,function() PBZ.log("LOOT guest +0.6 "..FIGHT.doing(FIGHT.e)) end) return FIGHT.doing(e)' -H 'local e=FIGHT.boss() local before=FIGHT.doing(e) local d=FIGHT.dust() PBZ.game.applyDamage(e,1e9,0) PBZ.game.after(0.15,function() PBZ.log("LOOT host +0.15 "..FIGHT.doing(e)) end) PBZ.game.after(0.6,function() PBZ.log("LOOT host +0.6 "..FIGHT.doing(e).." "..FIGHT.dust()) end) return before.." "..d' -Wait 1.5
    X -H 'return FIGHT.state()' -C 'return FIGHT.state()' -Wait 1
}
if ($From -le 2 -and $To -ge 2) {
    Head 'guest starts the elite'
    X -C '!spawner XIGU_1_4_A_EliteSword' -Wait 1.5
    X -C 'local _,p=PBZ.getPlayer1() local e=FIGHT.boss() if e then local l=e:K2_GetActorLocation() p.CharacterMovement:SetMovementMode(5,0) p:K2_SetActorLocation({X=l.X-300,Y=l.Y,Z=l.Z+150},false,{},true) end return "guest flies"' -Wait 3
    X -C $land -Wait 3
    X -H 'return FIGHT.state()' -C 'return FIGHT.state()' -Wait 1
    Head 'the guest lands the killing blow, for real'
    X -H 'return FIGHT.dust()' -C 'local e=FIGHT.boss() FIGHT.beside(e,170) PBZ.game.setHealth(e,1) return FIGHT.swing()' -Wait 0.9
    X -C 'local e=FIGHT.boss() if e and not PBZ.game.isDead(e) then FIGHT.beside(e,170) return FIGHT.swing() end return "gone"' -Wait 0.9
    X -C 'local e=FIGHT.boss() if e and not PBZ.game.isDead(e) then FIGHT.beside(e,170) return FIGHT.swing() end return "gone"' -Wait 1.2
    X -H 'return FIGHT.state()' -C 'return FIGHT.state()' -Wait 1
}
if ($From -le 3 -and $To -ge 3) {
    Head 'the guest dies in the host''s fight'
    X -H '!spawner XIGU_1_4_A_EliteSword' -Wait 1.5
    X -H $fly -Wait 3
    X -H $land -Wait 3
    X -H 'return FIGHT.state()' -C 'local _,p=PBZ.getPlayer1() PBZ.game.setMinHealth(p,0) PBZ.game.killPlayer(p) return FIGHT.state()' -Wait 6
    X -H 'return FIGHT.state()' -C 'return FIGHT.state()' -Wait 6
    X -H 'return FIGHT.state()' -C 'return FIGHT.state()' -Wait 1
}
if ($From -le 4 -and $To -ge 4) {
    Head 'revive: the guest goes down, the host strikes'
    X -H '!revive on' -C '!revive on' -Wait 1
    X -H '!revive trace' -Wait 0.7
    X -C 'local _,p=PBZ.getPlayer1() PBZ.game.setHealth(p,1) return "guest at 1"' -Wait 1.2
    X -H '!revive' -C '!revive' -Wait 0.8
    X -H 'local me=select(2,PBZ.getPlayer1()) local g=PBZ.net.ghost:K2_GetActorLocation() me:K2_SetActorLocation({X=g.X-170,Y=g.Y,Z=g.Z+5},false,{},true) return "beside"' -Wait 0.7
    for ($i = 0; $i -lt 6; $i++) { X -H 'return tostring(PAIR.swing(0.2))' -Wait 0.75 }
    X -H '!revive' -C '!revive' -Wait 0.8
    X -C 'local _,p=PBZ.getPlayer1() return FIGHT.dust()' -Wait 0.7
}
Head 'end'
