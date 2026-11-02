# The guest, far from the host, searches piles that hold real items: what each player gets, at once.
param([int]$X = 6613, [int]$Y = 276394, [int]$Z = -33181, [int]$Metres = 260, [int]$Tries = 6)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
$face = 'local _,p=PBZ.getPlayer1() local l=p:K2_GetActorLocation() local yaw=math.deg(math.atan(XX-l.Y,WW-l.X)) p:K2_SetActorRotation({Pitch=0.0,Yaw=yaw,Roll=0.0},false) local pc=PBZ.getPlayer1() pc:SetControlRotation({Pitch=-15.0,Yaw=yaw,Roll=0.0}) return 1'
[void](Ask $C "return REAL.flyTo($X, $Y, $($Z + 500))")
Start-Sleep -Seconds 12
"gap: " + (Ask $C 'return REAL.gap()' 5)
$list = Ask $C "local _,p=PBZ.getPlayer1() local here=p:K2_GetActorLocation() local rows={} for _,a in ipairs(FindAllOf(`"BP_Rubbish_C`") or {}) do if PBZ.valid(a) then local l=a:K2_GetActorLocation() local d=PBZ.distance(l,here)/100 if d<=$Metres then local id=`"?`" pcall(function() id=a[`"Loot Item ID`"]:ToString() end) if id~=`"None`" and not id:find(`"Dust`",1,true) then rows[#rows+1]={d,l,id} end end end end table.sort(rows,function(x,y) return x[1]<y[1] end) local t={} for i=1,math.min($Tries,#rows) do local r=rows[i] t[#t+1]=math.floor(r[2].X)..`",`"..math.floor(r[2].Y)..`",`"..math.floor(r[2].Z)..`",`"..r[3] end return table.concat(t,`" `")" 8
$got = 0
foreach ($p in @($list -split ' ' | Where-Object { $_ })) {
    $x, $y, $z, $id = $p -split ','
    [void](Ask $H 'return REAL.bagMark()'); [void](Ask $C 'return REAL.bagMark()')
    [void](Ask $C "return REAL.flyTo($([int]$x - 110), $y, $([int]$z + 60))")
    Start-Sleep -Seconds 4
    [void](Ask $C 'return REAL.land(1)')
    Start-Sleep -Seconds 2
    [void](Ask $C ($face -replace 'XX', "$y" -replace 'WW', "$x"))
    Start-Sleep -Seconds 1
    $mark = Log-End
    [void](Ask $C 'local cm=STORY.gm() cm:GM_Input("interact") return 1')
    Start-Sleep -Seconds 7
    $seen = @(Lines $mark 'Opened BP_Rubbish').Count
    "guest at pile $id : reported $seen"
    if ($seen -gt 0) {
        $got++
        "    host  " + (Ask $H 'return REAL.bagDiff()' 5)
        "    guest " + (Ask $C 'return REAL.bagDiff()' 5)
        Lines $mark 'Opened |Shared|here too|rror' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 5 | ForEach-Object { '   ' + $(if ($_.Length -gt 120) { $_.Substring(0, 120) } else { $_ }) }
        if ($got -ge 2) { break }
    }
}
"piles shared: $got"
