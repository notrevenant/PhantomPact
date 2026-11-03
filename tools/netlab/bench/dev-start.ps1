param([string]$Role = 'Host', [int]$Instance = 1, [hashtable]$Settings = @{}, [switch]$NoInstall)
. (Join-Path $PSScriptRoot '..\dev.ps1')
if (-not $NoInstall) { "mod hash " + (Install-DevMod) }
$g = Start-DevGame -Role $Role -Instance $Instance -Settings $Settings
"started pid $($g.Pid) at $(Get-Date -Format HH:mm:ss)"
$g | ConvertTo-Json | Set-Content "$PSScriptRoot\dev-$($Role.ToLower()).json"
$ok = Wait-DevGameplay $g 240
"gameplay: $ok at $(Get-Date -Format HH:mm:ss)"
$p = Get-Process -Id $g.Pid -ErrorAction SilentlyContinue
if ($p) { "alive, WS $([int]($p.WorkingSet64 / 1MB)) MB" } else { 'EXITED' }
Get-DevLog $g $g.Started 'PBZCoop|Lua.*rror|error' | Where-Object { $_ -notmatch 'pawn=|eval local _,p' } | Select-Object -Last 22 | ForEach-Object { $_ -replace '^\[[^\]]*\] \[Lua\] ', '' }
'DONE'
