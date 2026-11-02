# Finds chests that hold a weapon, accessory or medicine: flies the host from bell to bell on one map, reading the chests loaded there.
param([string]$Level = 'PBZ_Xigu_WP', [string]$Bell = 'NLES_001', [string]$Words = 'Tang IronBlade .Long .Double GuiTouBlade UnnamedBow BrutalAxe ShachiHook HuangJinHuoChong TanLang Medicine', [int]$Max = 24)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $H $load 8)
if ((Ask $H 'return tostring(PBZ.game.mapName(select(2,PBZ.getPlayer1())))' 6) -ne $Level) {
    [void](Ask $H "return STORY.go(`"$Bell`")" 8)
    Start-Sleep -Seconds 6
    "host: $(Wait-Player $H 150)"
    [void](Ask $H $load 8)
    Start-Sleep -Seconds 6
}
$list = Ask $H "local t={} for id,b in pairs(STORY.loadBells()) do if b.level==`"$Level`" and #b.t>=10 then t[#t+1]=math.floor(b.t[5])..`",`"..math.floor(b.t[6])..`",`"..math.floor(b.t[7]) end end return table.concat(t,`" `")" 8
$spots = @($list -split ' ' | Where-Object { $_ }) | Select-Object -First $Max
"$($spots.Count) bells"
$seen = @{}
foreach ($s in $spots) {
    $x, $y, $z = $s -split ','
    [void](Ask $H "return REAL.flyTo($x, $y, $([int]$z + 400))")
    Start-Sleep -Seconds 6
    $r = Ask $H "return LOOTP.scan(`"$Words`")" 6
    foreach ($row in (($r -replace '^SCAN ?', '') -split ' ; ' | Where-Object { $_ })) {
        $k = ($row -split '\|')[0]
        if (-not $seen[$k]) { $seen[$k] = $row; $row }
    }
}
[void](Ask $H 'return REAL.land(1)')
"found $($seen.Count)"
