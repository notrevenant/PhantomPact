param([string]$Boss = 'sp:ZhangMeng1a')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") return 1'
[void](Ask $H $load 8)
"where: " + (Ask $H "return REAL.hp(`"$Boss`")" 5)
[void](Ask $H "return REAL.hoverTo(`"$Boss`", 200)" 5)
Start-Sleep -Seconds 1
[void](Ask $H 'return REAL.land(1)' 5)
[void](Ask $H "return REAL.fight(`"$Boss`", 3)" 5)
$end = (Get-Date).AddSeconds(14)
while ((Get-Date) -lt $end) {
    Start-Sleep -Seconds 2
    if ((Ask $H 'return tostring(PBZ.game.bossFightActive())' 4) -eq 'true') { 'fight on'; break }
}
"host fight " + (Ask $H 'return tostring(PBZ.game.bossFightActive())' 4)
