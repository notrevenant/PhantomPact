# One step on the two running copies: an eval (or a command) on each, then the log lines it caused.
#   x.ps1 -H 'return FIGHT.state()' -C 'return FIGHT.state()'     (a line starting with ! is sent as a plain command)
param([string]$H, [string]$C, [double]$Wait = 1.2, [string]$Match = 'STATE|LOOT|eval ok|eval error|eval compile|rror|Boss|boss|fog|Host says|Enemy died|illing blow|Shared|Puppets|died|Revive|down|Rested|rested|respawn', [switch]$All)
. (Join-Path $PSScriptRoot '..\dev.ps1')
$hg = Get-Content "$PSScriptRoot\dev-host.json" -Raw | ConvertFrom-Json
$cg = Get-Content "$PSScriptRoot\dev-guest.json" -Raw | ConvertFrom-Json
$hg.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop'
$cg.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop\inst2'
function Line([string]$s) { if ($s.StartsWith('!')) { $s.Substring(1) } else { "eval $s" } }
$t = Get-Date
if ($H) { Send-Dev $hg (Line $H) }
if ($C) { Send-Dev $cg (Line $C) }
Start-Sleep -Milliseconds ([int]($Wait * 1000))
$lines = Get-DevLog $hg $t $(if ($All) { '.' } else { $Match })
$lines | Where-Object { $_ -notmatch '\] > ' } | ForEach-Object { $_ -replace '^\[\d{4}-\d\d-\d\d (\S+)\] \[Lua\] ', '$1 ' } | ForEach-Object { if ($_.Length -gt 420) { $_.Substring(0, 420) } else { $_ } }
