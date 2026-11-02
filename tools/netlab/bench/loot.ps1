# Who gets what from a kill: real swings on the two running copies, both backpacks compared before and after.
#   -Who host|guest    who lands the killing blow
#   -X -Y -Z           where to fight (spots.tsv), -Count kills in a row, -Refresh respawns the enemies first
param([string]$Who = 'host', [int]$X = -221234, [int]$Y = 89570, [int]$Z = 6962, [int]$Count = 2, [switch]$Refresh, [string]$Want = '')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
$from = Log-End
if ($Refresh) {
    'host rests (enemies back on both sides)'
    [void](Ask $H 'local pc=PBZ.getPlayer1() local gm=PBZ.gs():GetGameMode(pc) gm["Refresh Monster"](gm) return "refreshed"' 6)
    Start-Sleep -Seconds 5
}
[void](Ask $H "return REAL.flyTo($($X - 150), $Y, $($Z + 500))"); [void](Ask $C "return REAL.flyTo($($X + 150), $Y, $($Z + 500))")
Start-Sleep -Seconds 10
[void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
Start-Sleep -Seconds 4
$killer, $other = if ($Who -eq 'host') { $H, $C } else { $C, $H }
for ($n = 1; $n -le $Count; $n++) {
    $hn = @((Ask $H 'return REAL.names()' 5) -replace '^NAMES ?', '' -split ' ' | Where-Object { $_ })
    $cn = @((Ask $C 'return REAL.names()' 5) -replace '^NAMES ?', '' -split ' ' | Where-Object { $_ })
    $both = @($hn | Where-Object { $cn -contains $_ })
    if ($Want) { $both = @($both | Where-Object { $_ -match $Want }) }
    if ($both.Count -eq 0) { "kill $n : no shared enemy here (host $($hn.Count), guest $($cn.Count))"; break }
    $e = Ask $C "return REAL.nearOf(`"$($both -join ' ')`")" 5
    $cls = Ask $H "local a=PBZ.coop.enemyActor(`"$e`") return a and a:GetClass():GetFName():ToString():gsub('BP_Monster_',''):gsub('_C`$','') or 'gone'"
    $boss = Ask $H "local a=PBZ.coop.enemyActor(`"$e`") return tostring(a and PBZ.game.isBoss(a))"
    $roll = Ask $H "local a=PBZ.coop.enemyActor(`"$e`") local d,items,l=PBZ.game.rollLoot(a) local t={} for _,i in ipairs(items) do t[#t+1]=i.id..'x'..i.count end return 'table dust '..d..' level '..l..' items ['..table.concat(t,' ')..']'"
    [void](Ask $H 'return REAL.bagMark()'); [void](Ask $C 'return REAL.bagMark()')
    [void](Ask $H "return REAL.hoverTo(`"$e`", 250)"); [void](Ask $C "return REAL.hoverTo(`"$e`", 300)")
    Start-Sleep -Seconds 3
    [void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
    Start-Sleep -Seconds 2
    $mark = Log-End
    [void](Ask $H "local e=PBZ.coop.enemyActor(`"$e`") if e then PBZ.game.setHealth(e,1) end return 1")
    Start-Sleep -Seconds 1
    [void](Ask $killer "return REAL.fight(`"$e`", 4)")
    Start-Sleep -Seconds 8
    $dead = Ask $H "return REAL.hp(`"$e`")"
    $hb = Ask $H 'return REAL.bagDiff()' 5; $cb = Ask $C 'return REAL.bagDiff()' 5
    "kill $n $Who on $cls boss=$boss : $dead"
    "   $roll"
    "   host  $hb"
    "   guest $cb"
    Lines $mark 'LOOTROLL|LOOTBAG|Shared dust|Shared loot|partner.s kill|Boss items|killing blow|Picked up|took ' | Where-Object { $_ -notmatch 'eval' } |
        Select-Object -First 8 | ForEach-Object { '   ' + $(if ($_.Length -gt 120) { $_.Substring(0, 120) } else { $_ }) }
}
Lines $from 'Error executing|attempt to' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 3
'LOOT DONE'
