# Unattended soak: both players wander, sprint and attack around the save point for N minutes; enemies are spawned
# now and then; positions, health and Lua errors are logged every round. Prints a summary at the end.
param([int]$Minutes = 8)
$sp = $PSScriptRoot
. "C:\Users\TheCo\Downloads\Coop Mode - Onimusha Way of the Sword\tools\game-driver.ps1" -GameWin64 'D:\SteamLibrary\steamapps\common\PBZ\platform\steam' -ProcessName 'PBZ'
$p = Get-Process PBZ -ErrorAction SilentlyContinue | Where-Object { $_.Path -like 'D:\SteamLibrary\*' } | Select-Object -First 1
if (-not $p) { "NO GAME"; exit 1 }
Select-GameInstance -ProcessId $p.Id -Instance 1
$t0 = Get-Date; $rounds = 0; $errors = 0; $crashed = $false
$rand = New-Object System.Random
while (((Get-Date) - $t0).TotalMinutes -lt $Minutes) {
    if (-not (Get-Process PBZ -ErrorAction SilentlyContinue | Where-Object { $_.Path -like 'D:\SteamLibrary\*' })) { $crashed = $true; break }
    $rounds++
    $x1 = [math]::Round($rand.NextDouble() * 2 - 1, 2); $y1 = [math]::Round($rand.NextDouble() * 2 - 1, 2)
    $x2 = [math]::Round($rand.NextDouble() * 2 - 1, 2); $y2 = [math]::Round($rand.NextDouble() * 2 - 1, 2)
    $cmds = @("eval T.move(1,$x1,$y1,3) T.move(2,$x2,$y2,3) if $($rounds % 3) == 0 then T.hold(1,'IA_Sprint',1,0,3) T.hold(2,'IA_Sprint',1,0,3) end return 'round $rounds moving'")
    if ($rounds % 4 -eq 0) { $cmds += "spawnenemy BP_Monster_MaleThug_Sword_Blue 500" }
    if ($rounds % 2 -eq 0) { $cmds += "eval T.press(1,'IA_AttackL_Press',0.2) T.press(2,'IA_AttackL_Press',0.2) return 'attack'" }
    $cmds += 'eval local p1,p2=T.pawn(1),T.pawn(2) local a,b=p1:K2_GetActorLocation(),p2:K2_GetActorLocation() return string.format("STATE P1 %.0f,%.0f,%.0f hp %s | P2 %.0f,%.0f,%.0f hp %s | apart %.0f", a.X,a.Y,a.Z,tostring(PBZ.game.getHealth(p1)),b.X,b.Y,b.Z,tostring(PBZ.game.getHealth(p2)),PBZ.distance(a,b))'
    $tr = Get-Date
    foreach ($c in $cmds) { Send-ModCommand $c; Start-Sleep 4 }
    $lines = Get-ModLog -Since $tr -Last 100 | Where-Object { $_ -notmatch '> eval|METER' }
    $errs = @($lines | Where-Object { $_ -match 'error|Error' -and $_ -notmatch 'eval error' })
    $errors += $errs.Count
    ($lines | Where-Object { $_ -match 'STATE|Player|error|Woke|down|back' } | ForEach-Object { $_ -replace '^\[[^\]]*\] \[Lua\] \[PBZCoop\] ', '' }) -join "`n"
    Start-Sleep 6
}
"SOAK DONE rounds=$rounds errors=$errors crashed=$crashed minutes=$([math]::Round(((Get-Date)-$t0).TotalMinutes,1))"
