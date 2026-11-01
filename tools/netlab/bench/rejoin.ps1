# The host quits and comes back while the guest plays on (dev-start.ps1 for both first). A hard stop, like a crash or a
# closed window. Ends with what each side says about the other, and the enemies that died before the quit.
param([int]$AwaySeconds = 30)
. (Join-Path $PSScriptRoot '..\dev.ps1')
$h = Get-Content "$PSScriptRoot\dev-host.json" -Raw | ConvertFrom-Json
$c = Get-Content "$PSScriptRoot\dev-guest.json" -Raw | ConvertFrom-Json
$h.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop'
$c.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop\inst2'
$lab = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path -replace '\\', '/'
$load = "eval dofile(`"$lab/perf.lua`") dofile(`"$lab/pair.lua`") dofile(`"$lab/fights.lua`") return 1"
$match = 'Relay:|No packet|Lost the|Ghost hidden|Ghost back|Ghost shown|other player|started sync|enemies within|PAIR |eval error|attempt to|traceback'
function Show([datetime]$Since) {
    Get-DevLog $c $Since $match | Where-Object { $_ -notmatch '\] > ' } | ForEach-Object { $_ -replace '^\[\d{4}-\d\d-\d\d (\S+)\] \[Lua\] ', '$1 ' } |
        ForEach-Object { if ($_.Length -gt 260) { $_.Substring(0, 260) } else { $_ } }
}
function Head([string]$s) { "--- $s  $(Get-Date -Format HH:mm:ss)" }

Head 'both in a crowd'
$s = Get-Date
Send-Dev $h $load; Send-Dev $c $load
Start-Sleep -Seconds 1
Send-Dev $h 'eval PERF.crowd() return 1'; Send-Dev $c 'eval PERF.crowd() return 1'
Start-Sleep -Seconds 14
$land = 'eval local _,p=PBZ.getPlayer1() p.CharacterMovement:SetMovementMode(1,0) PBZ.game.setMinHealth(p,1) return 1'
Send-Dev $h $land; Send-Dev $c $land
Start-Sleep -Seconds 3
Show $s

Head 'the host kills two'
$s = Get-Date
foreach ($i in 1, 2) {
    Send-Dev $h 'eval PAIR.kill() return 1'
    Start-Sleep -Seconds 2
}
Send-Dev $h 'eval PERF.count() return 1'; Send-Dev $c 'eval PERF.count() return 1'
Start-Sleep -Seconds 1
Show $s

Head 'the host is gone'
$s = Get-Date
Stop-DevGame $h
while (((Get-Date) - $s).TotalSeconds -lt $AwaySeconds) {
    Send-Dev $c 'eval PAIR.walk(5, 200) return 1'
    Start-Sleep -Seconds 6
    Send-Dev $c 'netstatus'
    Start-Sleep -Seconds 1
    Send-Dev $c 'eval PERF.count() return 1'
    Start-Sleep -Seconds 1
}
Show $s

Head 'the host comes back'
$s = Get-Date
$h = Start-DevGame -Role Host -Settings @{ ThisPcOnly = 'On'; OnlinePanel = 'On' }
$h | ConvertTo-Json | Set-Content "$PSScriptRoot\dev-host.json"
$ok = Wait-DevGameplay $h 200
"gameplay: $ok at $(Get-Date -Format HH:mm:ss), $([int]((Get-Date) - $s).TotalSeconds) s"
Send-Dev $h $load
Start-Sleep -Seconds 12
Send-Dev $h 'netstatus'; Send-Dev $c 'netstatus'
Start-Sleep -Seconds 1
Send-Dev $h 'eval PERF.count() return 1'; Send-Dev $c 'eval PERF.count() return 1'
Start-Sleep -Seconds 1
Show $s
'DONE'
