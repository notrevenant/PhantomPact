# A rubbish pile the host searched: its state on both sides, then the guest's copy pays, then the guest tries it for real.
param([string]$Tail = 'BC2BDD9B702_1435257579', [int]$X = -197449, [int]$Y = 85342, [int]$Z = 4808)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
[void](Ask $C 'return LOOTP.rubbishHooks().." "..LOOTP.mapHook()' 8)
"host  " + (Ask $H "return LOOTP.pile(`"$Tail`")" 6)
"guest " + (Ask $C "return LOOTP.pile(`"$Tail`")" 6)
$from = Log-End
"guest " + (Ask $C "return LOOTP.payPile(`"$Tail`")" 6)
Start-Sleep -Seconds 3
"guest " + (Ask $C "return LOOTP.pile(`"$Tail`")" 6)
Lines $from 'LOOTMAP|LOOTCHEST|rror' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 6 | ForEach-Object { if ($_.Length -gt 130) { $_.Substring(0, 130) } else { $_ } }
'--- the guest goes there and presses interact'
[void](Ask $C "return REAL.flyTo($($X - 110), $Y, $($Z + 60))")
Start-Sleep -Seconds 4
[void](Ask $C 'return REAL.land(1)')
Start-Sleep -Seconds 2
$face = 'local _,p=PBZ.getPlayer1() local l=p:K2_GetActorLocation() local yaw=math.deg(math.atan(XX-l.Y,WW-l.X)) p:K2_SetActorRotation({Pitch=0.0,Yaw=yaw,Roll=0.0},false) local pc=PBZ.getPlayer1() pc:SetControlRotation({Pitch=-15.0,Yaw=yaw,Roll=0.0}) return 1'
[void](Ask $C ($face -replace 'XX', "$Y" -replace 'WW', "$X"))
Start-Sleep -Seconds 1
$from = Log-End
[void](Ask $C 'local cm=STORY.gm() cm:GM_Input("interact") return 1')
Start-Sleep -Seconds 8
Lines $from 'LOOTMAP|LOOTCHEST' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 6 | ForEach-Object { if ($_.Length -gt 130) { $_.Substring(0, 130) } else { $_ } }
'done'
