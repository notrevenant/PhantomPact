# In a live boss fight: how many bars each player has, second by second, and whether real hits land the same on both.
param([string]$Boss = '', [int]$BossX = -149486, [int]$BossY = -20369, [int]$BossZ = 887)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
$find = 'local out={} for name,a in pairs(PBZ.coop.enemies()) do if PBZ.valid(a) and not PBZ.game.isDead(a) and PBZ.game.isBoss(a) then out[#out+1]=name end end return table.concat(out," ")'
[void](Ask $H "return REAL.flyTo($($BossX - 900), $BossY, $($BossZ + 400))"); [void](Ask $C "return REAL.flyTo($($BossX - 1000), $BossY, $($BossZ + 400))")
Start-Sleep -Seconds 11
$e = ((Ask $H $find 6) -split ' ')[0]
"boss: $e"
if (-not $e) { 'NO BOSS HERE'; return }
[void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
[void](Ask $H "return REAL.hoverTo(`"$e`", 300)")
Start-Sleep -Seconds 1
[void](Ask $H 'return REAL.land(1)')
$from = Log-End
foreach ($i in 1..9) {
    Start-Sleep -Seconds 1
    "$i s  host " + (Ask $H 'return FIGHT.bars()' 3) + " | guest " + (Ask $C 'return FIGHT.bars()' 3) + " | hp h " + ((Ask $H "return REAL.hp(`"$e`")" 3) -replace ' .*', '') + " g " + ((Ask $C "return REAL.hp(`"$e`")" 3) -replace ' .*', '')
}
$d = 'C:\PBZDev\pp-netlab\bar-shots'
New-Item -ItemType Directory -Force $d | Out-Null
& (Join-Path $PSScriptRoot 'shots.ps1') -Out $d | Out-Null
"bars shown in 9 s: host " + @(Lines $from 'PBZCoop\] Showing boss bar').Count + ", guest " + @(Lines $from 'PBZCoop#2\] Showing boss bar').Count
"--- real hits: host"
"before  h " + ((Ask $H "return REAL.hp(`"$e`")" 3) -replace ' .*', '') + " g " + ((Ask $C "return REAL.hp(`"$e`")" 3) -replace ' .*', '')
[void](Ask $H "return REAL.fight(`"$e`", 3)")
Start-Sleep -Seconds 5
"after 3 h " + ((Ask $H "return REAL.hp(`"$e`")" 3) -replace ' .*', '') + " g " + ((Ask $C "return REAL.hp(`"$e`")" 3) -replace ' .*', '')
"--- real hits: guest"
[void](Ask $C "return REAL.hoverTo(`"$e`", 300)")
Start-Sleep -Seconds 2
[void](Ask $C 'return REAL.land(1)')
[void](Ask $C "return REAL.fight(`"$e`", 3)")
Start-Sleep -Seconds 5
"after 3 h " + ((Ask $H "return REAL.hp(`"$e`")" 3) -replace ' .*', '') + " g " + ((Ask $C "return REAL.hp(`"$e`")" 3) -replace ' .*', '')
"bars now: host " + (Ask $H 'return FIGHT.bars()' 3) + " | guest " + (Ask $C 'return FIGHT.bars()' 3)
