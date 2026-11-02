# Fights at the survey's spots, both players, one summary line each. Level changes go by a bell.
param([int]$Start = 0, [int]$Count = 999, [string]$Out = 'C:\PBZDev\pp-netlab\spots-log.txt', [int]$Swings = 2, [int]$Settle = 0)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
function Note([string]$s) { $s; Add-Content -Path $Out -Value $s -Encoding utf8 }
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
$spots = Get-Content 'C:\PBZDev\pp-netlab\spots.tsv' -Encoding UTF8
$level = ''
for ($i = $Start; $i -lt [Math]::Min($spots.Count, $Start + $Count); $i++) {
    $f = $spots[$i] -split "`t"
    $lv, $bell, $x, $y, $z, $why = $f[0], $f[1], [int]$f[2], [int]$f[3], [int]$f[4], $f[5]
    if (-not (Alive $H) -or -not (Alive $C)) { Note "A COPY IS GONE at spot $i"; return }
    $from = Log-End
    $now = (Ask $H 'return tostring(PBZ.game.mapName(select(2,PBZ.getPlayer1())))' 6)
    if ($now -ne $lv) {
        [void](Ask $H "return STORY.go(`"$bell`")" 8); [void](Ask $C "return STORY.go(`"$bell`")" 8)
        Start-Sleep -Seconds 6
        $a = Wait-Player $H 150; $b = Wait-Player $C 150
        if ($a -ne 'ready' -or $b -ne 'ready') { Note "STOP level $lv host $a guest $b"; return }
        [void](Ask $H $load 8); [void](Ask $C $load 8)
        Start-Sleep -Seconds 4
    }
    [void](Ask $H "return REAL.flyTo($($x - 150), $y, $($z + 500))"); [void](Ask $C "return REAL.flyTo($($x + 150), $y, $($z + 500))")
    Start-Sleep -Seconds (8 + $Settle)
    [void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
    Start-Sleep -Seconds 4
    $hz = Ask $H 'return tostring(math.floor(select(2,PBZ.getPlayer1()):K2_GetActorLocation().Z))'
    $cz = Ask $C 'return tostring(math.floor(select(2,PBZ.getPlayer1()):K2_GetActorLocation().Z))'
    $hn = @((Ask $H 'return REAL.names()' 5) -replace '^NAMES ?', '' -split ' ' | Where-Object { $_ })
    $cn = @((Ask $C 'return REAL.names()' 5) -replace '^NAMES ?', '' -split ' ' | Where-Object { $_ })
    $both = @($hn | Where-Object { $cn -contains $_ })
    $line = "$i $lv $why h$($hn.Count) g$($cn.Count) both$($both.Count) z$($z)/$hz/$cz"
    if ($both.Count -eq 0) { Note "$line | no shared enemy"; continue }
    $e = Ask $C "return REAL.nearOf(`"$($both -join ' ')`")" 5
    $cls = Ask $H "local a=PBZ.coop.enemyActor(`"$e`") return a and a:GetClass():GetFName():ToString():gsub('BP_Monster_',''):gsub('_C`$','') or 'gone'"
    $hb = Ask $H "local a=PBZ.coop.enemyActor(`"$e`") return tostring(a and PBZ.game.isBoss(a))"
    [void](Ask $H "return REAL.hoverTo(`"$e`", 250)"); [void](Ask $C "return REAL.hoverTo(`"$e`", 300)")
    Start-Sleep -Seconds 3
    [void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
    Start-Sleep -Seconds 2
    $w = "return REAL.watch(`"$e`", 14)"
    [void](Ask $H $w); [void](Ask $C $w)
    $hp0 = (Ask $H "return REAL.hp(`"$e`")") -replace ' .*', ''
    [void](Ask $H "return REAL.fight(`"$e`", $Swings)")
    Start-Sleep -Seconds ([int](1.2 * $Swings + 1))
    $hp1h = (Ask $H "return REAL.hp(`"$e`")") -replace ' .*', ''; $hp1c = (Ask $C "return REAL.hp(`"$e`")") -replace ' .*', ''
    [void](Ask $C "return REAL.fight(`"$e`", $Swings)")
    Start-Sleep -Seconds ([int](1.2 * $Swings + 1))
    $hp2h = (Ask $H "return REAL.hp(`"$e`")") -replace ' .*', ''; $hp2c = (Ask $C "return REAL.hp(`"$e`")") -replace ' .*', ''
    [void](Ask $H "local e=PBZ.coop.enemyActor(`"$e`") if e then PBZ.game.setHealth(e,1) end return 1")
    [void](Ask $H "return REAL.fight(`"$e`", 2)")
    Start-Sleep -Seconds 3
    [void](Ask $H "local e=PBZ.coop.enemyActor(`"$e`") if e and not PBZ.game.isDead(e) then PBZ.game.kill(e) end return 1")
    Start-Sleep -Seconds 2
    $hp3h = Ask $H "return REAL.hp(`"$e`")"; $hp3c = Ask $C "return REAL.hp(`"$e`")"
    $k = if ($hp3h -match 'dead=true' -or $hp3h -eq 'gone') { 'K' } else { 'alive' }
    $k2 = if ($hp3c -match 'dead=true' -or $hp3c -eq 'gone') { 'K' } else { 'alive' }
    $mv = Lines $from 'WATCH'
    $hm = @($mv | Where-Object { $_ -notmatch '#2' } | ForEach-Object { ($_ -split ' ')[-1] } | Where-Object { $_ -ne '-' })
    $cm = @($mv | Where-Object { $_ -match '#2' } | ForEach-Object { ($_ -split ' ')[-1] } | Where-Object { $_ -ne '-' })
    $same = @($hm | Where-Object { $cm -contains $_ }).Count
    $extra = @($cm | Where-Object { $hm -notcontains $_ -and $_ -notmatch 'Hit|Stun|Dead|Knock|Parry|Block|Guard' } | Select-Object -Unique | Select-Object -First 3) -join ','
    $sw = @(Lines $from 'STATE swing' | Where-Object { $_ -match 'swing \d+ swing true' }).Count
    $bad = @(Lines $from 'Error executing|attempt to|not replayed' | ForEach-Object { if ($_.Length -gt 120) { $_.Substring(16, 104) } else { $_ } } | Select-Object -Unique -First 3) -join ' ; '
    Note "$line | $cls boss=$hb hp $hp0 h$hp1h=g$hp1c h$hp2h=g$hp2c kill $k/$k2 | moves $($hm.Count)/$($cm.Count) same $same extra[$extra] swings $sw | $bad"
    if ($hp1h -ne $hp1c -or $hp2h -ne $hp2c) { Note "   ^ HEALTH DIFFERS" }
}
Note 'SPOTS DONE'
