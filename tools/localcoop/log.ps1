# Prints the mod's log lines of the last N minutes with their timestamps (no METER spam).
param([double]$Minutes = 3, [int]$Last = 60)
. "C:\Users\TheCo\Downloads\Coop Mode - Onimusha Way of the Sword\tools\game-driver.ps1" -GameWin64 'D:\SteamLibrary\steamapps\common\PBZ\platform\steam' -ProcessName 'PBZ'
$p = Get-Process PBZ -ErrorAction SilentlyContinue | Where-Object { $_.Path -like 'D:\SteamLibrary\*' } | Select-Object -First 1
if (-not $p) { "NO GAME PROCESS"; exit 1 }
Select-GameInstance -ProcessId $p.Id -Instance 1
Get-ModLog -Since (Get-Date).AddMinutes(-$Minutes) -Last 2000 | Where-Object { $_ -notmatch 'METER' } | Select-Object -Last $Last | ForEach-Object { $_ -replace '\] \[Lua\] \[PBZCoop\] ', '] ' }
