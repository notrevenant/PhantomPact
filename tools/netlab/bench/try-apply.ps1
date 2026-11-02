param([int]$From = 1, [int]$To = 97, [switch]$OnHost)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$g = if ($OnHost) { $script:H } else { $script:C }
$t = Log-End
"before " + (Ask $g 'return STORY.where()')
"active bells before: " + (Ask $g 'return #STORY.list(STORY.bm():GetAllActivateBellIDs())')
"apply: " + (Ask $g "return STORY.apply($From, $To)" 15)
Start-Sleep -Seconds 3
"active bells after: " + (Ask $g 'return #STORY.list(STORY.bm():GetAllActivateBellIDs())')
"after " + (Ask $g 'return STORY.where()')
Lines $t 'rror|Fatal|attempt' | Where-Object { $_ -notmatch 'eval ok' } | Select-Object -First 6 | ForEach-Object { if ($_.Length -gt 170) { $_.Substring(0, 170) } else { $_ } }
"alive: " + (Alive $g)
