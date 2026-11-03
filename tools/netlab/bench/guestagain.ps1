# The guest quit and started again on the files as they are now, with the host left running. No password needed.
$lab = 'C:\Users\TheCo\Downloads\PhantomPact-online\tools\netlab'
. (Join-Path $PSScriptRoot 'tourlib.ps1')
. (Join-Path $lab 'dev.ps1')
$quit = 'eval local pc=PBZ.getPlayer1() StaticFindObject("/Script/Engine.Default__KismetSystemLibrary"):QuitGame(pc, pc, 0, false)'
Send-Dev $script:C $quit
$deadline = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $deadline -and (Get-Process -Id $script:C.Pid -ErrorAction SilentlyContinue)) { Start-Sleep -Seconds 1 }
if (Get-Process -Id $script:C.Pid -ErrorAction SilentlyContinue) { Stop-Process -Id $script:C.Pid -Force; Start-Sleep -Seconds 2 }
"mod hash " + (Install-DevMod)
$set = @{}
$env:steam_master_ipc_name_override = 'steam2'
$c = Start-DevGame -Role Guest -Instance 2 -Settings $set
$c | ConvertTo-Json | Set-Content "$lab\bench\dev-guest.json"
"guest pid $($c.Pid)"
Start-Sleep -Seconds 20
"guest gameplay: $(Wait-DevGameplay $c 300 -AfterCrash) at $(Get-Date -Format HH:mm:ss)"
Start-Sleep -Seconds 15
Get-Content (Join-Path $c.Dir 'net_status.txt') -Raw -ErrorAction SilentlyContinue
