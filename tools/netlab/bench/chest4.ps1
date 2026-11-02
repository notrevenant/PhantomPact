# The whole share by hand: the host opens a chest, the guest's copy pays, both backpacks compared from the same mark.
param([string]$Name = 'BP_Chest_C_UAID_74563C6BC2BD740003_1783844450', [int]$X = -220716, [int]$Y = 108083, [int]$Z = 5760, [int]$Dx = -110, [int]$Dy = 0)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
Ask $H 'return REAL.bagMark()'; Ask $C 'return REAL.bagMark()'
[void](Ask $H "return REAL.flyTo($($X + $Dx), $($Y + $Dy), $($Z + 60))")
Start-Sleep -Seconds 4
[void](Ask $H 'return REAL.land(1)')
Start-Sleep -Seconds 2
$face = 'local _,p=PBZ.getPlayer1() local l=p:K2_GetActorLocation() local yaw=math.deg(math.atan(XX-l.Y,WW-l.X)) p:K2_SetActorRotation({Pitch=0.0,Yaw=yaw,Roll=0.0},false) local pc=PBZ.getPlayer1() pc:SetControlRotation({Pitch=-15.0,Yaw=yaw,Roll=0.0}) return "yaw "..math.floor(yaw)'
[void](Ask $H ($face -replace 'XX', "$Y" -replace 'WW', "$X"))
Start-Sleep -Seconds 1
$from = Log-End
Ask $H 'local cm=STORY.gm() cm:GM_Input("interact") return "interact sent"'
Start-Sleep -Seconds 8
"after the host opened it:"
"  host  " + (Ask $H 'return REAL.bagDiff()' 5)
"  guest " + (Ask $C 'return REAL.bagDiff()' 5)
Ask $C "return LOOTP.mirrorPay(`"$Name`")" 8
Start-Sleep -Seconds 5
"after the guest's copy paid:"
"  host  " + (Ask $H 'return REAL.bagDiff()' 5)
"  guest " + (Ask $C 'return REAL.bagDiff()' 5)
Lines $from 'LOOTMAP|Shared|rror' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 8 | ForEach-Object { if ($_.Length -gt 150) { $_.Substring(0, 150) } else { $_ } }
