# One real chest opened by one player, on the build with chest sharing: both backpacks and both chests compared.
param([string]$Who = 'host', [int]$X, [int]$Y, [int]$Z, [string]$Name = '', [int]$Dx = -110, [int]$Dy = 0, [double]$Wait = 10, [switch]$Together)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
$g, $o = if ($Who -eq 'host') { $H, $C } else { $C, $H }
[void](Ask $H 'return REAL.bagMark()'); [void](Ask $C 'return REAL.bagMark()')
$face = 'local _,p=PBZ.getPlayer1() local l=p:K2_GetActorLocation() local yaw=math.deg(math.atan(XX-l.Y,WW-l.X)) p:K2_SetActorRotation({Pitch=0.0,Yaw=yaw,Roll=0.0},false) local pc=PBZ.getPlayer1() pc:SetControlRotation({Pitch=-15.0,Yaw=yaw,Roll=0.0}) return 1'
$movers = @($g); if ($Together) { $movers = @($H, $C) }
foreach ($p in $movers) { [void](Ask $p "return REAL.flyTo($($X + $Dx), $($Y + $Dy), $($Z + 60))") }
Start-Sleep -Seconds 4
foreach ($p in $movers) { [void](Ask $p 'return REAL.land(1)') }
Start-Sleep -Seconds 2
foreach ($p in $movers) { [void](Ask $p ($face -replace 'XX', "$Y" -replace 'WW', "$X")) }
Start-Sleep -Seconds 1
$from = Log-End
foreach ($p in $movers) { [void](Ask $p 'local cm=STORY.gm() cm:GM_Input("interact") return 1') }
Start-Sleep -Seconds $Wait
"host  " + (Ask $H 'return REAL.bagDiff()' 5)
"guest " + (Ask $C 'return REAL.bagDiff()' 5)
if ($Name) {
    "open here: host " + (Ask $H "local a=LOOTP.chest(`"$Name`") return tostring(a and a.CurSwitchState)" 5) + ", guest " + (Ask $C "local a=LOOTP.chest(`"$Name`") return tostring(a and a.CurSwitchState)" 5)
}
Lines $from 'Opened BP_|partner opened a chest|partner searched|Shared|rror|LOOTBAG|LOOTMAP' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 8 | ForEach-Object { if ($_.Length -gt 130) { $_.Substring(0, 130) } else { $_ } }
