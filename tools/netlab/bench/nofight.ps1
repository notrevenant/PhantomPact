# Dying with no boss fight on: back at the bell in the usual time, whichever player it is, with no one waiting.
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
$kill = 'local _,p=PBZ.getPlayer1() PBZ.game.killPlayer(p) return "killed"'
foreach ($p in @(@('guest', $C), @('host', $H))) {
    $n, $g = $p
    $from = Log-End
    $t0 = Get-Date
    "$n down: " + (Ask $g $kill 6) + ", bars host " + (Ask $H 'return FIGHT.bars()' 3) + " guest " + (Ask $C 'return FIGHT.bars()' 3)
    $back = $false
    while (-not $back -and ((Get-Date) - $t0).TotalSeconds -lt 40) {
        Start-Sleep -Seconds 1
        $back = (Ask $g 'return tostring(PBZ.game.isDead(select(2,PBZ.getPlayer1())))' 4) -eq 'false'
    }
    "$n back: $back after $([int]((Get-Date) - $t0).TotalSeconds) s"
    Lines $from "you'll be back" | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 3 | ForEach-Object { '   HELD: ' + $_.Substring(0, [Math]::Min(120, $_.Length)) }
    Start-Sleep -Seconds 6
}
