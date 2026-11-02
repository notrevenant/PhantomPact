# Does this boss heal itself? Its health and what it's doing, second by second, after it's brought low.
param([string]$Boss = 'sp:XiongZhang', [double]$Start = 30000, [int]$Seconds = 16)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
"before: " + (Ask $H "return REAL.hp(`"$Boss`")" 4)
[void](Ask $H "local e=PBZ.coop.enemyActor(`"$Boss`") PBZ.game.setHealth(e,$Start) return 1" 5)
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end) {
    "$(Get-Date -Format HH:mm:ss) " + (Ask $H "return REAL.hp(`"$Boss`")" 4) + " | " + (Ask $H "return REAL.active(`"$Boss`")" 4)
    Start-Sleep -Milliseconds 700
}
