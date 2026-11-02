# One real chest opened by one player, with both backpacks compared. -Who host|guest, -X -Y -Z the chest.
param([string]$Who = "host", [int]$X, [int]$Y, [int]$Z, [double]$Wait = 9, [int]$Dx = -110, [int]$Dy = 0)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $C $load 8)
$g = if ($Who -eq 'host') { $H } else { $C }
[void](Ask $C 'return REAL.bagMark()')
"fly: " + (Ask $g "return REAL.flyTo($($X + $Dx), $($Y + $Dy), $($Z + 60))")
Start-Sleep -Seconds 3
"land: " + (Ask $g 'return REAL.land(1)')
Start-Sleep -Seconds 2
$face = 'local _,p=PBZ.getPlayer1() local l=p:K2_GetActorLocation() local yaw=math.deg(math.atan(XX-l.Y,WW-l.X)) p:K2_SetActorRotation({Pitch=0.0,Yaw=yaw,Roll=0.0},false) local pc=PBZ.getPlayer1() pc:SetControlRotation({Pitch=-15.0,Yaw=yaw,Roll=0.0}) return "yaw "..math.floor(yaw)'
"face: " + (Ask $g ($face -replace 'XX', "$Y" -replace 'WW', "$X"))
Start-Sleep -Seconds 1
$from = Log-End
"press: " + (Ask $g 'local cm=STORY.gm() cm:GM_Input("interact") return "interact sent"')
Start-Sleep -Seconds $Wait

"guest " + (Ask $C 'return REAL.bagDiff()' 5)
Lines $from "LOOTROLL|LOOTBAG|LOOTCHEST|LOOTMAP|Shared|took |rror" | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 14 | ForEach-Object { if ($_.Length -gt 150) { $_.Substring(0, 150) } else { $_ } }
"chests: " + (Ask $g 'return LOOTP.chests(1)' 6)
