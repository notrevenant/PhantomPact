# Both copies quit the way the game's own menu does, so the next start has no crash question.
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$quit = 'eval local pc=PBZ.getPlayer1() StaticFindObject("/Script/Engine.Default__KismetSystemLibrary"):QuitGame(pc, pc, 0, false)'
Send-Dev $script:C $quit
Start-Sleep -Seconds 4
Send-Dev $script:H $quit

$deadline = (Get-Date).AddSeconds(45)
while ((Get-Date) -lt $deadline -and @(Get-Process PBZ -ErrorAction SilentlyContinue).Count -gt 0) { Start-Sleep -Seconds 1 }
"copies left: $(@(Get-Process PBZ -ErrorAction SilentlyContinue).Count)"
