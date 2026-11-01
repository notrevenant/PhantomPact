param([switch]$WalkOnly, [switch]$FightOnly)
. (Join-Path $PSScriptRoot '..\dev.ps1')
$h = Get-Content "$PSScriptRoot\dev-host.json" -Raw | ConvertFrom-Json
$c = Get-Content "$PSScriptRoot\dev-guest.json" -Raw | ConvertFrom-Json
$h.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop'
$c.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop\inst2'
$lab = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path -replace '\\', '/'
$work = (Join-Path $env:TEMP 'pp-netlab') -replace '\\', '/'
New-Item -ItemType Directory -Force $work | Out-Null
$load = "dofile(`"$lab/perf.lua`") dofile(`"$lab/pair.lua`")"
$t = Get-Date
Send-Dev $h "eval $load return 1"; Send-Dev $c "eval $load return 1"
Start-Sleep -Seconds 2
if (-not $FightOnly) {
    'walk: host walks 13 s, then the guest'
    Send-Dev $h "eval PAIR.record(30, `"$work/rec-host.txt`") PAIR.walk(13, 700) return 1"
    Send-Dev $c "eval PAIR.record(30, `"$work/rec-guest.txt`") return 1"
    Start-Sleep -Seconds 15
    Send-Dev $c 'eval PAIR.walk(13, 700) return 1'
    Start-Sleep -Seconds 17
    python -I "$lab/pair_report.py" "$work/rec-host.txt" "$work/rec-guest.txt"
}
if (-not $WalkOnly) {
    'fight: both go to the crowd'
    Send-Dev $h 'eval PERF.crowd() return 1'; Send-Dev $c 'eval PERF.crowd() return 1'
    Start-Sleep -Seconds 14
    $land = 'eval local _,p=PBZ.getPlayer1() p.CharacterMovement:SetMovementMode(1,0) PBZ.game.setMinHealth(p,1) return 1'
    Send-Dev $h $land; Send-Dev $c $land
    Start-Sleep -Seconds 4
    Send-Dev $h 'eval PERF.count() return 1'; Send-Dev $c 'eval PERF.count() return 1'
    Start-Sleep -Seconds 2
    Send-Dev $h "eval PAIR.record(22, `"$work/fight-host.txt`") PERF.stages(10) PERF.frames(10, `"host fight`") return 1"
    Send-Dev $c "eval PAIR.record(22, `"$work/fight-guest.txt`") PERF.stages(10) PERF.frames(10, `"guest fight`") return 1"
    Start-Sleep -Seconds 11
    'hits and kills'
    Send-Dev $h 'eval PAIR.hurt(0.4) return 1'
    Start-Sleep -Seconds 2
    Send-Dev $c 'eval PAIR.hurt(0.3) return 1'
    Start-Sleep -Seconds 2
    Send-Dev $h 'eval PAIR.kill() return 1'
    Start-Sleep -Seconds 2
    Send-Dev $c 'eval local e=PAIR.nearest() if e then PBZ.game.setHealth(e, 1.0) end return "guest killing blow" '
    Start-Sleep -Seconds 8
    python -I "$lab/pair_report.py" "$work/fight-host.txt" "$work/fight-guest.txt"
    Send-Dev $h 'netstatus'; Send-Dev $c 'netstatus'
    Start-Sleep -Seconds 1
}
Get-DevLog $h $t 'PERF|PAIR|Enemy died here|Host says|Killing blow|killing blow|Boss|eval error|net error|event .* error|rror:' | Where-Object { $_ -notmatch '\] > ' } | ForEach-Object { $_ -replace '^\[\d{4}-\d\d-\d\d (\S+)\] \[Lua\] ', '$1 ' } | ForEach-Object { if ($_.Length -gt 200) { $_.Substring(0, 200) } else { $_ } } | Select-Object -Last 70
Get-Process PBZ | Select-Object Id, @{n='WS_MB';e={[int]($_.WorkingSet64/1MB)}} | Format-Table -AutoSize
'DONE'
