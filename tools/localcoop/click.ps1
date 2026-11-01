# Focuses the game and left-clicks at a point given in half-scale screenshot pixels (as in run.ps1 -Shot captures).
param([Parameter(Mandatory = $true)][int]$X, [Parameter(Mandatory = $true)][int]$Y, [string]$Shot)
. "C:\Users\TheCo\Downloads\Coop Mode - Onimusha Way of the Sword\tools\game-driver.ps1" -GameWin64 'D:\SteamLibrary\steamapps\common\PBZ\platform\steam' -ProcessName 'PBZ'
$p = Get-Process PBZ -ErrorAction SilentlyContinue | Where-Object { $_.Path -like 'D:\SteamLibrary\*' } | Select-Object -First 1
if (-not $p) { "NO GAME PROCESS"; exit 1 }
Select-GameInstance -ProcessId $p.Id -Instance 1
if (-not ('FgCheck.Native' -as [type])) { Add-Type -Namespace FgCheck -Name Native -MemberDefinition '[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();' }
Show-Game
if ([FgCheck.Native]::GetForegroundWindow() -ne (Get-GameWindow)) { "REFUSED: the game window is not in the foreground (another window, e.g. a system prompt, has focus); no keys or clicks sent."; exit 2 }
Invoke-GameClick -X $X -Y $Y -Scale 0.5
if ($Shot) { Start-Sleep -Milliseconds 800; Save-GameScreenshot $Shot -Scale 0.5 | Out-Null; "shot: $Shot" }
"clicked $X,$Y"
