# At what distance from the host do enemies stop fighting the guest? Guest among enemies, host this many metres off.
param([int[]]$Gaps = @(20, 45, 80, 120, 200), [int]$X = -130813, [int]$Y = 42223, [int]$Z = 816, [int]$Watch = 15)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
if ((Ask $H 'return tostring(PBZ.game.mapName(select(2,PBZ.getPlayer1())))' 6) -ne 'PBZ_Pangzhen_WP') {
    [void](Ask $H 'return STORY.go("SZ_001")' 8); [void](Ask $C 'return STORY.go("SZ_001")' 8)
    Start-Sleep -Seconds 6
    "host $(Wait-Player $H 150), guest $(Wait-Player $C 150)"
    [void](Ask $H $load 8); [void](Ask $C $load 8)
    Start-Sleep -Seconds 6
}
$hp = 'local _,p=PBZ.getPlayer1() local h=PBZ.game.getHealth(p) return math.floor(h)'
foreach ($gap in $Gaps) {
    [void](Ask $H 'local pc=PBZ.getPlayer1() local gm=PBZ.gs():GetGameMode(pc) gm["Refresh Monster"](gm) return 1' 6)
    Start-Sleep -Seconds 4
    [void](Ask $H "return REAL.flyTo($($X + $gap * 100), $Y, $($Z + 500))")
    [void](Ask $C "return REAL.flyTo($X, $Y, $($Z + 500))")
    Start-Sleep -Seconds 10
    [void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
    Start-Sleep -Seconds 3
    $near = Ask $C 'return REAL.near()' 5
    if ($near -and $near -ne 'none') {
        $e = ($near -split '\|')[0]
        [void](Ask $C "return REAL.hoverTo(`"$e`", 260)")
        Start-Sleep -Seconds 2
        [void](Ask $C 'return REAL.land(1)')
    }
    Start-Sleep -Seconds 2
    $hp0 = Ask $C $hp 5
    $low = [int]$hp0
    $hits = 0
    foreach ($i in 1..$Watch) {
        Start-Sleep -Seconds 1
        $now = Ask $C $hp 3
        if ($now -and [int]$now -lt $low) { $hits++; $low = [int]$now }
    }
    $gapNow = Ask $C 'return REAL.gap()' 5
    $parts = $near -split '\|'
    "gap asked $gap m | $gapNow | enemy $($parts[1] -replace 'BP_Monster_', '') at $($parts[2]) m | guest hp $hp0 -> $low, $hits drops in $Watch s | " + (Ask $C 'return REAL.alone()' 5)
    [void](Ask $C 'return REAL.land(1)')
}
'REACH DONE'
