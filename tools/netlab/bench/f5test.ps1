. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$start = Log-End
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") return 1'
[void](Ask $H $load); [void](Ask $C $load 8)
"host  " + (Ask $H 'return STORY.where()'); "guest " + (Ask $C 'return STORY.where()'); "guest " + (Ask $C 'return REAL.gap()')
$w = [NetLab.Win]::Unreal($C.Pid)
"guest window $w"
$p = (Ask $H 'return STORY.where()') -split ' '
$x = [int]$p[3] + 30000; $y = [int]$p[4]; $z = [int]$p[5] + 500
if ((Ask $C 'return REAL.gap()') -match 'same map false') { 'guest is on another map: F5 across maps first' }
else {
    "same map, 300 m off: " + (Ask $C "return REAL.flyTo($x, $y, $z)")
    Start-Sleep -Seconds 3
    "before F5: " + (Ask $C 'return REAL.gap()')
    [NetLab.Win]::Key($w, 0x74)
    Start-Sleep -Seconds 6
    "after F5:  " + (Ask $C 'return REAL.gap()') + " | " + (Ask $C 'return STORY.where()')
    Start-Sleep -Seconds 4
    "settled:   " + (Ask $C 'return REAL.gap()') + " | mode " + (Ask $C 'return tostring(select(2,PBZ.getPlayer1()).CharacterMovement.MovementMode)')
    "to another map: " + (Ask $C 'return STORY.go("NLES_001")' 8)
    Start-Sleep -Seconds 6
    "arrived: " + (Wait-Player $C 90)
    Start-Sleep -Seconds 8
}
"before F5: " + (Ask $C 'return REAL.gap()') + " | " + (Ask $C 'return STORY.where()')
[NetLab.Win]::Key($w, 0x74)
Start-Sleep -Seconds 8
"loading: " + (Wait-Player $C 90)
Start-Sleep -Seconds 8
"after F5:  " + (Ask $C 'return REAL.gap()') + " | " + (Ask $C 'return STORY.where()')
Lines $start 'F5|Going to the other|Partner key|rror|takes you|not now|isn.t known|wouldn' | Where-Object { $_ -notmatch 'eval ok' } | Select-Object -Last 8 | ForEach-Object { if ($_.Length -gt 150) { $_.Substring(0, 150) } else { $_ } }
"alive guest: " + (Alive $C) + ", host: " + (Alive $H)
