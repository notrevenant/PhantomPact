# The guest dies in the fight: does the bar repeat, and does the boss keep its health?
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$e = 'sp:XiongZhang'
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
"before: hp h " + ((Ask $H "return REAL.hp(`"$e`")" 3) -replace ' .*', '') + " g " + ((Ask $C "return REAL.hp(`"$e`")" 3) -replace ' .*', '') + " bars h " + (Ask $H 'return FIGHT.bars()' 3) + " g " + (Ask $C 'return FIGHT.bars()' 3) + " " + (Ask $C 'return REAL.gap()' 3)
$from = Log-End
Ask $C 'local _,p=PBZ.getPlayer1() PBZ.game.killPlayer(p) return "guest killed"' 6
foreach ($i in 1..7) {
    Start-Sleep -Seconds 2
    "$($i * 2) s  bars h " + (Ask $H 'return FIGHT.bars()' 3) + " g " + (Ask $C 'return FIGHT.bars()' 3) + " | hp h " + ((Ask $H "return REAL.hp(`"$e`")" 3) -replace ' .*', '') + " g " + ((Ask $C "return REAL.hp(`"$e`")" 3) -replace ' .*', '')
}
$d = 'C:\PBZDev\pp-netlab\bar-dead'
New-Item -ItemType Directory -Force $d | Out-Null
& (Join-Path $PSScriptRoot 'shots.ps1') -Out $d | Out-Null
"bars shown while dead: host " + @(Lines $from 'PBZCoop\] Showing boss bar').Count + ", guest " + @(Lines $from 'PBZCoop#2\] Showing boss bar').Count
"host hits the boss while the guest is dead"
[void](Ask $H "return REAL.hoverTo(`"$e`", 300)")
Start-Sleep -Seconds 2
[void](Ask $H 'return REAL.land(1)')
[void](Ask $H "return REAL.fight(`"$e`", 3)")
Start-Sleep -Seconds 5
"after: hp h " + ((Ask $H "return REAL.hp(`"$e`")" 3) -replace ' .*', '') + " g " + ((Ask $C "return REAL.hp(`"$e`")" 3) -replace ' .*', '') + " | guest dead " + (Ask $C 'return tostring(PBZ.game.isDead(select(2,PBZ.getPlayer1())))' 3)
