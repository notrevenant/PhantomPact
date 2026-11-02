# The guest lands the killing blow, the host alive beside them: does the game record the boss as dead, and does a rest bring it back?
param([string]$Boss, [string]$Id, [int]$X, [int]$Y, [int]$Z)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/g5.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
[void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
Start-Sleep -Seconds 2
"before: " + (Ask $H "return SAVEDBOSS(`"$Id`")" 6) + " | " + ((Ask $H "return REAL.hp(`"$Boss`")" 4) -replace ' montage.*', '')
[void](Ask $H "return REAL.keepLow(`"$Boss`", 16, 40)" 5)
foreach ($i in 1..3) {
    [void](Ask $C "return REAL.hoverTo(`"$Boss`", 300)" 4)
    Start-Sleep -Seconds 1
    [void](Ask $C 'return REAL.land(1)' 4)
    [void](Ask $C "return REAL.fight(`"$Boss`", 3)" 4)
    Start-Sleep -Seconds 4
    $st = Ask $H "return REAL.hp(`"$Boss`")" 4
    if ($st -match 'dead=true' -or $st -eq 'gone') { break }
}
"after the blow: " + ($st -replace ' montage.*', '')
Start-Sleep -Seconds 3
"record: " + (Ask $H "return SAVEDBOSS(`"$Id`")" 6)
Ask $H 'local pc=PBZ.getPlayer1() local gm=PBZ.gs():GetGameMode(pc) gm["Refresh Monster"](gm) return "rested"' 6
Start-Sleep -Seconds 12
"after the rest: " + (Ask $H "return SAVEDBOSS(`"$Id`")" 6) + " | host sees " + ((Ask $H "return REAL.hp(`"$Boss`")" 4) -replace ' montage.*', '') + " | guest sees " + ((Ask $C "return REAL.hp(`"$Boss`")" 4) -replace ' montage.*', '')
"alive bosses on the host: " + (Ask $H 'local n=0 local o={} for k,a in pairs(PBZ.coop.enemies()) do if PBZ.valid(a) and not PBZ.game.isDead(a) and PBZ.game.isBoss(a) then o[#o+1]=k end end return table.concat(o," ")' 5)
