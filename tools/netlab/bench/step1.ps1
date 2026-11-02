. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/walker.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
$imm = 'local cm=STORY.gm() cm:GM_State("preset","immortal","on") return "GM immortal"'
Ask $H $imm; Ask $C $imm
$m = 'local cm=STORY.gm() cm:GM_MoveTo("2340,275793,-32341", 250.0, 60.0, "auto") return "GM moving"'
Ask $H $m; Ask $C $m
for ($i = 0; $i -lt 12; $i++) {
    Start-Sleep -Seconds 4
    $a = Ask $H 'local _,p=PBZ.getPlayer1() local l=p:K2_GetActorLocation() local cm=STORY.gm() return string.format("%.0f %.0f %.0f done=%s", l.X,l.Y,l.Z,tostring(cm:GM_IsMoveToComplete()))'
    $b = Ask $C 'local _,p=PBZ.getPlayer1() local l=p:K2_GetActorLocation() local cm=STORY.gm() return string.format("%.0f %.0f %.0f done=%s", l.X,l.Y,l.Z,tostring(cm:GM_IsMoveToComplete()))'
    "$((Get-Date).ToString('HH:mm:ss')) host $a | guest $b"
    if ($a -match 'done=true' -and $b -match 'done=true') { break }
}
"steps: " + (Ask $H 'return WALK.show()')
