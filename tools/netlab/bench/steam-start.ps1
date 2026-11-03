# Steam on the dev install: two copies on one account. One account can't reach itself through Steam, so this only
# proves the Steam link starts inside the game and stays up; the real connection needs a second account on another PC.
# Stops the dev copies first. steam-check.ps1 does the same on the real install.
param([int]$WatchSeconds = 60)
. (Join-Path $PSScriptRoot '..\dev.ps1')
Get-Process PBZ -ErrorAction SilentlyContinue | Where-Object { $_.Path -like 'C:\PBZDev\*' } | Stop-Process -Force -Confirm:$false
Start-Sleep -Seconds 3
"mod hash " + (Install-DevMod)
$began = Get-Date
$set = @{}
foreach ($f in 'relay_log.txt', 'relay_error.txt', 'net_status.txt') {
    Remove-Item (Join-Path (Get-DevDir 1) $f), (Join-Path (Get-DevDir 2) $f) -ErrorAction SilentlyContinue
}
$h = Start-DevGame -Role Host -Settings $set
Start-Sleep -Seconds 3
$c = Start-DevGame -Role Guest -Instance 2 -Settings $set
$h | ConvertTo-Json | Set-Content "$PSScriptRoot\dev-host.json"
$c | ConvertTo-Json | Set-Content "$PSScriptRoot\dev-guest.json"
"host $($h.Pid), guest $($c.Pid)"
"gameplay: host $(Wait-DevGameplay $h 200), guest $(Wait-DevGameplay $c 200) at $(Get-Date -Format HH:mm:ss)"
Start-Sleep -Seconds $WatchSeconds
foreach ($g in $h, $c) {
    "--- copy $($g.Instance), alive: $([bool](Get-Process -Id $g.Pid -ErrorAction SilentlyContinue))"
    foreach ($f in 'relay_log.txt', 'relay_error.txt', 'net_status.txt') {
        $p = Join-Path $g.Dir $f
        if (Test-Path $p) { "[$f]"; Get-Content $p -Tail 12 | ForEach-Object { if ($_.Length -gt 300) { $_.Substring(0, 300) } else { $_ } } }
    }
}
'--- log'
Get-DevLog $h $began 'Relay|Steam|relay|Status:|net error|event .* error|attempt to|traceback|\.lua:\d+' | Where-Object { $_ -notmatch '\] > ' } |
    ForEach-Object { $_ -replace '^\[\d{4}-\d\d-\d\d (\S+)\] \[Lua\] ', '$1 ' } | ForEach-Object { if ($_.Length -gt 240) { $_.Substring(0, 240) } else { $_ } } | Select-Object -Last 30
'DONE'
