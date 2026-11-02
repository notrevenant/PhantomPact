# The guest drops out in the middle of a fight: the enemies must leave the stand-in alone and go for the host.
param([string]$Boss)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/aggro.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
[void](Ask $H "return REAL.hoverTo(`"$Boss`", 1500)"); [void](Ask $C "return REAL.hoverTo(`"$Boss`", -200)")
Start-Sleep -Seconds 1
[void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
Start-Sleep -Seconds 8
"before: " + (Ask $H 'return AGGRO.now(6000)' 5)
$from = Log-End
Stop-Process -Id $C.Pid -Force
"guest gone at $(Get-Date -Format HH:mm:ss)"
foreach ($i in 1..9) {
    Start-Sleep -Seconds 3
    "$(Get-Date -Format HH:mm:ss) " + (Ask $H 'return AGGRO.now(6000)' 5)
}
Lines $from 'Lost the other|Ghost hidden|Ghost visible' | Where-Object { $_ -notmatch 'eval' } | ForEach-Object { '   ' + $_.Substring(0, [Math]::Min(120, $_.Length)) }
"host alive $(Alive $H)"
