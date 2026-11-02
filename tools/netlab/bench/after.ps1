# Read only: what each player gained since mark.ps1, and what the mod and the game said about it.
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$from = [long](Get-Content 'C:\PBZDev\pp-netlab\mark-log.txt')
"host  " + (Ask $script:H 'return REAL.bagDiff()' 6)
"host  " + (Ask $script:H 'return LOOTP.gearDiff()' 6)
"guest " + (Ask $script:C 'return REAL.bagDiff()' 6)
"guest " + (Ask $script:C 'return LOOTP.gearDiff()' 6)
Lines $from 'Opened BP_|partner opened|partner searched|Shared|LOOTBAG|LOOTMAP|Status:|Picked|took |rror' | Where-Object { $_ -notmatch 'eval' } | Select-Object -Last 16 | ForEach-Object { if ($_.Length -gt 135) { $_.Substring(0, 135) } else { $_ } }
