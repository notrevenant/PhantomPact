. (Join-Path $PSScriptRoot 'tourlib.ps1')
Start-Sleep -Seconds 6
"host " + (Wait-Player $script:H 90); "guest " + (Wait-Player $script:C 90)
Start-Sleep -Seconds 5
(Ask $script:H 'return STORY.where()'); (Ask $script:C 'return STORY.where()')
