# Two Steam accounts mean two saves: the guest starts from an older save of the dev install, perhaps on another map, while
# the host stays where it is (dev-start.ps1 for both first). Only C:\PBZDev's save is touched, and it's put back at the end.
param([string]$Save = '3Daily\20261030-190455-176.sav', [int]$WatchSeconds = 30)
. (Join-Path $PSScriptRoot '..\dev.ps1')
$h = Get-Content "$PSScriptRoot\dev-host.json" -Raw | ConvertFrom-Json
$c = Get-Content "$PSScriptRoot\dev-guest.json" -Raw | ConvertFrom-Json
$h.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop'
$c.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop\inst2'
$lab = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path -replace '\\', '/'
$match = 'Relay:|Ghost |Status:|map|Map|No packet|Lost the|enemies within|eval error|attempt to|traceback|net error|event .* error'
function Show([datetime]$Since) {
    Get-DevLog $h $Since $match | Where-Object { $_ -notmatch '\] > ' } | ForEach-Object { $_ -replace '^\[\d{4}-\d\d-\d\d (\S+)\] \[Lua\] ', '$1 ' } |
        ForEach-Object { if ($_.Length -gt 300) { $_.Substring(0, 300) } else { $_ } } | Select-Object -Last 24
}
$folder = (Get-ChildItem 'C:\PBZDev\ProjectPBZ\Saved\SaveGames\Steam' -Directory | Select-Object -First 1).FullName
$live = Join-Path $folder 'PBZSaveGame.sav'
$keep = Join-Path $folder 'PBZSaveGame.keep'
$s = Get-Date
Stop-DevGame $c
Start-Sleep -Seconds 3
Copy-Item $live $keep -Force
Copy-Item (Join-Path $folder $Save) $live -Force
"guest starts from $Save ($((Get-Item $live).Length) bytes)"
try {
    $c = Start-DevGame -Role Guest -Instance 2 -Settings @{ ThisPcOnly = 'On' }
    $c | ConvertTo-Json | Set-Content "$PSScriptRoot\dev-guest.json"
    "gameplay: $(Wait-DevGameplay $c 240) at $(Get-Date -Format HH:mm:ss)"
    Start-Sleep -Seconds 8
    $load = "eval dofile(`"$lab/perf.lua`") dofile(`"$lab/pair.lua`") return 1"
    Send-Dev $h $load; Send-Dev $c $load
    Start-Sleep -Seconds 1
    Send-Dev $h 'eval PAIR.walk(10, 300) PAIR.swing(10) return 1'; Send-Dev $c 'eval PAIR.walk(10, 300) PAIR.swing(10) return 1'
    Start-Sleep -Seconds $WatchSeconds
    Send-Dev $h 'netstatus'; Send-Dev $c 'netstatus'
    Start-Sleep -Seconds 1
    Send-Dev $h 'eval PERF.count() return 1'; Send-Dev $c 'eval PERF.count() return 1'
    Start-Sleep -Seconds 1
    Show $s
    "alive: host $([bool](Get-Process -Id $h.Pid -ErrorAction SilentlyContinue)), guest $([bool](Get-Process -Id $c.Pid -ErrorAction SilentlyContinue))"
} finally {
    Copy-Item $keep $live -Force
    'save put back; it can be overwritten by a running copy, so close both before relying on it'
}
'DONE'
