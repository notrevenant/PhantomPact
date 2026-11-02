. (Join-Path $PSScriptRoot 'tourlib.ps1')
Start-Sleep -Seconds 14
[void](Ask $script:H 'return REAL.land(1)')
Start-Sleep -Seconds 3
"host: " + (Ask $script:H 'return dofile("C:/PBZDev/g3.lua")' 6)
