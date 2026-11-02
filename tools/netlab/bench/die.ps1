# The guest dies by the game's own kill effect, then what follows on both sides.
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $H $load 8); [void](Ask $C $load 8)
"before: " + (Ask $C 'return REAL.gap()')
$from = Log-End
Ask $C 'local path="/Game/PBZContent/Blueprint/Ability/GameplayEffects/GE_Kill.GE_Kill_C" if type(LoadAsset)=="function" then pcall(LoadAsset,"/Game/PBZContent/Blueprint/Ability/GameplayEffects/GE_Kill") end return LOOTP.geKill(path)' 8
$end = (Get-Date).AddSeconds(45)
$back = $false
while ((Get-Date) -lt $end -and -not $back) {
    Start-Sleep -Seconds 3
    $back = @(Lines $from 'You died and respawned').Count -gt 0
}
"respawned: $back at $(Get-Date -Format HH:mm:ss)"
Start-Sleep -Seconds 5
Ask $C 'local _,p=PBZ.getPlayer1() local h,m=PBZ.game.getHealth(p) return "guest hp "..math.floor(h).."/"..math.floor(m).." dead "..tostring(PBZ.game.isDead(p))'
Ask $C 'return REAL.gap()'
Lines $from 'died|respawn|partner is down|partner is back|Ghost hidden|Ghost visible|removed again|down:' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 10 | ForEach-Object { if ($_.Length -gt 125) { $_.Substring(0, 125) } else { $_ } }
