# One player dies in a boss fight: what their screen does, whether they watch the partner, and how they come back.
param([string]$Who = 'guest', [int]$Respawn = 45, [switch]$Land)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
$g = if ($Who -eq 'host') { $H } else { $C }
$dir = "C:\PBZDev\pp-netlab\spec-$Who"
New-Item -ItemType Directory -Force $dir | Out-Null
function Shot([string]$n) { $d = Join-Path $dir $n; New-Item -ItemType Directory -Force $d | Out-Null; & (Join-Path $PSScriptRoot 'shots.ps1') -Out $d | Out-Null }
if ($Land) {
    [void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
    Start-Sleep -Seconds 7
}
"bars host: " + (Ask $H 'return FIGHT.bars()' 5)
"bars guest: " + (Ask $C 'return FIGHT.bars()' 5)
"gap: " + (Ask $C 'return REAL.gap()' 5)
$from = Log-End
Shot 'before'
$kill = 'local _,p=PBZ.getPlayer1() PBZ.game.killPlayer(p) return "killed"'
"$Who dies: " + (Ask $g $kill 6)
Start-Sleep -Seconds 3
Shot 'dead-3s'
Start-Sleep -Seconds 5
Shot 'dead-8s'
$end = (Get-Date).AddSeconds($Respawn)
$back = $false
$word = if ($Who -eq 'host') { 'You died as host' } else { 'You died and respawned' }
while ((Get-Date) -lt $end -and -not $back) {
    Start-Sleep -Seconds 2
    $back = @(Lines $from $word).Count -gt 0
}
"respawned: $back at $(Get-Date -Format HH:mm:ss)"
Start-Sleep -Seconds 6
Shot 'after'
"host  " + (Ask $H 'local _,p=PBZ.getPlayer1() local h,m=PBZ.game.getHealth(p) return "hp "..math.floor(h).."/"..math.floor(m).." dead "..tostring(PBZ.game.isDead(p)).." bars "..tostring(FIGHT.bars())' 5)
"guest " + (Ask $C 'local _,p=PBZ.getPlayer1() local h,m=PBZ.game.getHealth(p) return "hp "..math.floor(h).."/"..math.floor(m).." dead "..tostring(PBZ.game.isDead(p)).." bars "..tostring(FIGHT.bars())' 5)
"gap: " + (Ask $C 'return REAL.gap()' 5)
Lines $from 'died|respawn|down|back|watching|Ghost|Joining|fog|Boss|boss|Status' | Where-Object { $_ -notmatch 'eval|> ' } | Select-Object -First 16 | ForEach-Object { if ($_.Length -gt 125) { $_.Substring(0, 125) } else { $_ } }
