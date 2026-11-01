. (Join-Path $PSScriptRoot '..\dev.ps1')
$c = Get-Content "$PSScriptRoot\dev-guest.json" -Raw | ConvertFrom-Json
$c.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop\inst2'
"gameplay: " + (Wait-DevGameplay $c 150) + " at " + (Get-Date -Format HH:mm:ss)
