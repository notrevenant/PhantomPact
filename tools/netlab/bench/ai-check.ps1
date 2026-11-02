. (Join-Path $PSScriptRoot 'tourlib.ps1')
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") return 1'
[void](Ask $script:H $load); [void](Ask $script:C $load)
"host tidy: " + (Ask $script:H 'return FIGHT.tidy():sub(1,70)')
"guest tidy: " + (Ask $script:C 'return FIGHT.tidy():sub(1,70)')
"guest brains: " + (Ask $script:C 'return REAL.brains()')
$t = Log-End
[void](Ask $script:H 'return REAL.list(4)'); [void](Ask $script:C 'return REAL.list(4)')
Lines $t 'STATE' | ForEach-Object { if ($_.Length -gt 130) { $_.Substring(0, 130) } else { $_ } }
Start-Sleep -Seconds 12
"guest brains after 12 s: " + (Ask $script:C 'return REAL.brains()')
Send-Dev $script:H 'puppets'; Send-Dev $script:C 'puppets'
Start-Sleep -Seconds 1
Lines $t 'Puppets:' | Select-Object -Last 2
