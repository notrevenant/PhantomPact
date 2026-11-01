# Runs one or more mod commands in the running game and prints the mod's new log lines (no METER spam).
param([Parameter(Mandatory = $true)][string[]]$Cmd, [double]$Wait = 2.0, [string]$Shot)
. "C:\Users\TheCo\Downloads\Coop Mode - Onimusha Way of the Sword\tools\game-driver.ps1" -GameWin64 'D:\SteamLibrary\steamapps\common\PBZ\platform\steam' -ProcessName 'PBZ'
$p = Get-Process PBZ -ErrorAction SilentlyContinue | Where-Object { $_.Path -like 'D:\SteamLibrary\*' } | Select-Object -First 1
if (-not $p) { "NO GAME PROCESS"; exit 1 }
Select-GameInstance -ProcessId $p.Id -Instance 1
$t0 = Get-Date
foreach ($c in $Cmd) { Send-ModCommand $c; Start-Sleep -Milliseconds ([int]($Wait * 1000)) }
Get-ModLog -Since $t0 -Last 400 | Where-Object { $_ -notmatch '\] > ' -and $_ -notmatch 'METER' } | ForEach-Object { $_ -replace '^\[[^\]]*\] \[Lua\] \[PBZCoop\] ', '' }
if ($Shot) { Save-GameScreenshot $Shot -Scale 0.5 | Out-Null; "shot: $Shot" }
