# One stop of the tour: both players at the same place, compared, then a real fight on one enemy, both ways, to the kill.
param([string]$Bell = '', [int]$Swings = 3, [switch]$NoFight, [string]$Enemy = '')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$start = Log-End
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") return 1'
if ($Bell) {
    $t0 = Get-Date
    [void](Ask $H "return STORY.go(`"$Bell`")" 8); [void](Ask $C "return STORY.go(`"$Bell`")" 8)
    Start-Sleep -Seconds 6
    $a = Wait-Player $H 150; $b = Wait-Player $C 150
    "travel to ${Bell}: host $a, guest $b, $([int]((Get-Date)-$t0).TotalSeconds) s"
    if ($a -ne 'ready' -or $b -ne 'ready') { 'STOP: a copy did not arrive'; return }
    Start-Sleep -Seconds 4
}
[void](Ask $H $load); [void](Ask $C $load)
"host  " + (Ask $H 'return STORY.where()')
"guest " + (Ask $C 'return STORY.where()')
"host  " + (Ask $H 'return REAL.ghost()')
"guest " + (Ask $C 'return REAL.ghost()')
Start-Sleep -Seconds 3
$hn = (Ask $H 'return REAL.names()' 5) -replace '^NAMES ', '' -split ' ' | Where-Object { $_ }
$cn = (Ask $C 'return REAL.names()' 5) -replace '^NAMES ', '' -split ' ' | Where-Object { $_ }
$both = @($hn | Where-Object { $cn -contains $_ })
"enemies: host $($hn.Count), guest $($cn.Count), on both $($both.Count)"
$near = Ask $H 'return REAL.near()'
"nearest on host: $near"
if ($NoFight -or -not $near -or $near -eq 'none') { 'no fight here' }
else {
    $e = ($near -split '\|')[0]
    if ($Enemy) { $e = $Enemy }
    elseif ($both.Count -gt 0) {
        $e = (Ask $C "return REAL.nearOf(`"$($both -join ' ')`")" 5)
        "using shared enemy $e"
    }
    $hover = "return REAL.hoverTo(`"$e`", 300)"
    [void](Ask $H $hover); [void](Ask $C "return REAL.hoverTo(`"$e`", 350)")
    Start-Sleep -Seconds 6
    [void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
    Start-Sleep -Seconds 2
    $w = "return REAL.watch(`"$e`", 18)"
    [void](Ask $H $w); [void](Ask $C $w)
    "before: host " + (Ask $H "return REAL.hp(`"$e`")") + " | guest " + (Ask $C "return REAL.hp(`"$e`")")
    [void](Ask $H "return REAL.fight(`"$e`", $Swings)")
    Start-Sleep -Seconds ([int](1.2 * $Swings + 1))
    "after host: host " + (Ask $H "return REAL.hp(`"$e`")") + " | guest " + (Ask $C "return REAL.hp(`"$e`")")
    [void](Ask $C "return REAL.fight(`"$e`", $Swings)")
    Start-Sleep -Seconds ([int](1.2 * $Swings + 1))
    "after guest: host " + (Ask $H "return REAL.hp(`"$e`")") + " | guest " + (Ask $C "return REAL.hp(`"$e`")")
    [void](Ask $H "local e=PBZ.coop.enemyActor(`"$e`") if e then PBZ.game.setHealth(e,1) end return 1")
    [void](Ask $H "return REAL.fight(`"$e`", 3)")
    Start-Sleep -Seconds 5
    "kill: host " + (Ask $H "return REAL.hp(`"$e`")") + " | guest " + (Ask $C "return REAL.hp(`"$e`")")
    $sw = Lines $start 'STATE swing' | ForEach-Object { if ($_ -match 'swing \d+ (swing \S+): (\S+) -> (\S+)') { $Matches[1] + ':' + $Matches[3] } }
    "swings: " + ($sw -join ' ')
    $w = Lines $start 'WATCH'
    $hw = @($w | Where-Object { $_ -notmatch '#2' }); $cw = @($w | Where-Object { $_ -match '#2' })
    $hm = @($hw | ForEach-Object { ($_ -split ' ')[-1] } | Where-Object { $_ -ne '-' }); $cm = @($cw | ForEach-Object { ($_ -split ' ')[-1] } | Where-Object { $_ -ne '-' })
    $same = @($hm | Where-Object { $cm -contains $_ }).Count
    "moves: host $($hm.Count), guest $($cm.Count), host moves also seen on guest $same; guest-only: " + (@($cm | Where-Object { $hm -notcontains $_ } | Select-Object -Unique | Select-Object -First 5) -join ' ')
}
Send-Dev $H 'puppets'; Send-Dev $C 'puppets'
Start-Sleep -Seconds 1
Lines $start 'Puppets:' | Select-Object -Last 2 | ForEach-Object { $_.Substring([Math]::Min(16, $_.Length)) }
"errors:"
Lines $start 'rror|attempt to|nil value|Fatal|exception' | Where-Object { $_ -notmatch 'eval ok|STATE|WATCH' } | Select-Object -First 8 | ForEach-Object { if ($_.Length -gt 170) { $_.Substring(0, 170) } else { $_ } }
foreach ($g in $H, $C) { "alive $($g.Instance): " + (Alive $g) }
$s = Get-Content (Join-Path $H.Dir 'net_status.txt') -Raw -ErrorAction SilentlyContinue
if ($s -match 'connected=(\S+).*rtt_ms=(\S+).*loss_pct=(\S+)') { "link: connected=$($Matches[1]) rtt=$($Matches[2]) loss=$($Matches[3])" }
'DONE'
