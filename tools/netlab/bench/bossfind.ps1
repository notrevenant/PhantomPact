# Flies both players to the boss spots on this map until one is alive there. Leaves them beside it, not yet in the fight.
param([string[]]$Spots = @('-122346,73997,2074', '-149486,-20369,887', '-67612,78394,858', '-51821,13291,2355', '-177413,-7616,1583', '-183873,119290,-4012'), [string]$Map = 'PBZ_Pangzhen_WP', [string]$Bell = 'SZ_001')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
$find = 'local out={} for name,a in pairs(PBZ.coop.enemies()) do if PBZ.valid(a) and not PBZ.game.isDead(a) and PBZ.game.isBoss(a) then local h,m=PBZ.game.getHealth(a) out[#out+1]=name.."|"..a:GetClass():GetFName():ToString().."|"..math.floor(h or 0).."/"..math.floor(m or 0) end end return "BOSS "..table.concat(out," ; ")'
if ((Ask $H 'return tostring(PBZ.game.mapName(select(2,PBZ.getPlayer1())))' 6) -ne $Map) {
    [void](Ask $H "return STORY.go(`"$Bell`")" 8); [void](Ask $C "return STORY.go(`"$Bell`")" 8)
    Start-Sleep -Seconds 6
    "host $(Wait-Player $H 150), guest $(Wait-Player $C 150)"
    [void](Ask $H $load 8); [void](Ask $C $load 8)
    Start-Sleep -Seconds 6
}
foreach ($s in $Spots) {
    $x, $y, $z = $s -split ','
    [void](Ask $H "return REAL.flyTo($([int]$x - 900), $y, $([int]$z + 400))"); [void](Ask $C "return REAL.flyTo($([int]$x - 1000), $y, $([int]$z + 400))")
    Start-Sleep -Seconds 11
    $b = Ask $H $find 6
    "$s : $b"
    if ($b -match '\|') { "FOUND $s"; break }
}
