# Both players by an enemy for a while: who does it go for, and who gets hurt? With the focus rule, or -Plain without.
param([string]$Boss = 'sp:HookManP1_Seq022', [int]$Seconds = 45, [switch]$Plain, [int]$HostCm = 300, [int]$GuestCm = 450)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/aggro.lua") dofile("C:/PBZDev/netlab/twitch.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
function Me($g) { Ask $g 'local _,p=PBZ.getPlayer1() local h,m=PBZ.game.getHealth(p) return math.floor(m-h)' 4 }
[void](Ask $H "return REAL.hoverTo(`"$Boss`", $HostCm)"); [void](Ask $C "return REAL.hoverTo(`"$Boss`", -$GuestCm)")
Start-Sleep -Seconds 1
[void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
$from = Log-End
[void](Ask $H "return AGGRO.watch($Seconds, 6000)" 5)
[void](Ask $H "return TWITCH.sample(`"$Boss`", $Seconds)" 5); [void](Ask $C "return TWITCH.sample(`"$Boss`", $Seconds)" 5)
$hurtH = 0; $hurtC = 0
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end) {
    Start-Sleep -Seconds 3
    $hurtH += [int](Me $H); $hurtC += [int](Me $C)
    [void](Ask $H 'return REAL.land(1)'); [void](Ask $C 'return REAL.land(1)')
}
"hurt in $Seconds s: host $hurtH, guest $hurtC"
Start-Sleep -Seconds 2
Lines $from 'TWITCH' | Where-Object { $_ -notmatch 'eval' } | ForEach-Object { '   ' + ($_ -replace '^.*\] \[Lua\] ', '') }
Lines $from 'not replayed' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 8 | ForEach-Object { '   ' + ($_ -replace '^.*not replayed: ', 'not replayed: ').Substring(0, [Math]::Min(120, ($_ -replace '^.*not replayed: ', 'not replayed: ').Length)) }
Lines $from 'AGGRO' | Where-Object { $_ -notmatch 'eval' } | ForEach-Object { '   ' + ($_ -replace '^.*AGGRO ', '') } | Select-Object -Last 26
