# One copy on its own, as the guest on the second Steam: no password needed, and its enemies are its own once it finds no host.
$lab = 'C:\Users\TheCo\Downloads\PhantomPact-online\tools\netlab'
. (Join-Path $lab 'dev.ps1')
$set = @{}
$env:steam_master_ipc_name_override = 'steam2'
$c = Start-DevGame -Role Guest -Instance 2 -Settings $set
$c | ConvertTo-Json | Set-Content "$lab\bench\dev-guest.json"
"guest pid $($c.Pid)"
Start-Sleep -Seconds 20
$q = Get-Process -Id $c.Pid -ErrorAction SilentlyContinue
"guest after 20 s: alive $([bool]$q), title [$($q.MainWindowTitle)]"
if (-not $q) { return }
"guest gameplay: $(Wait-DevGameplay $c 300 -AfterCrash) at $(Get-Date -Format HH:mm:ss)"
