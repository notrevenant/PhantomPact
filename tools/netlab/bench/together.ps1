param([string]$Name = 'near', [int]$Radius = 300)
. (Join-Path $PSScriptRoot '..\dev.ps1')
$h = Get-Content "$PSScriptRoot\dev-host.json" -Raw | ConvertFrom-Json
$c = Get-Content "$PSScriptRoot\dev-guest.json" -Raw | ConvertFrom-Json
$h.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop'
$c.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop\inst2'
$lab = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path -replace '\\', '/'
$work = (Join-Path $env:TEMP 'pp-netlab') -replace '\\', '/'
$t = Get-Date
$load = "dofile(`"$lab/perf.lua`") dofile(`"$lab/pair.lua`")"
Send-Dev $h "eval $load return 1"; Send-Dev $c "eval $load return 1"
Start-Sleep -Seconds 1
Send-Dev $h 'eval local t=PBZ.net.target local _,p=PBZ.getPlayer1() p.CharacterMovement:SetMovementMode(5,0) p:K2_SetActorLocation({X=t.X+150,Y=t.Y,Z=t.Z+120},false,{},true) return 1'
Start-Sleep -Seconds 13
Send-Dev $h 'eval local _,p=PBZ.getPlayer1() p.CharacterMovement:SetMovementMode(1,0) return 1'
Start-Sleep -Seconds 3
Send-Dev $h "eval PAIR.record(28, `"$work/$Name-host.txt`") PAIR.walk(12, $Radius) PAIR.swing(12) return 1"
Send-Dev $c "eval PAIR.record(28, `"$work/$Name-guest.txt`") return 1"
Start-Sleep -Seconds 14
Send-Dev $c "eval PAIR.walk(12, $Radius) PAIR.swing(12) return 1"
Start-Sleep -Seconds 15
Send-Dev $h 'netstatus'; Send-Dev $c 'netstatus'
Start-Sleep -Seconds 1
python -I "$lab/pair_report.py" "$work/$Name-host.txt" "$work/$Name-guest.txt"
Get-DevLog $h $t 'Relay:|net error|event .* error|rror:|No packet|Ghost |Lost' | Where-Object { $_ -notmatch '\] > ' } | ForEach-Object { $_ -replace '^\[\d{4}-\d\d-\d\d (\S+)\] \[Lua\] ', '$1 ' } | ForEach-Object { if ($_.Length -gt 300) { $_.Substring(0, 300) } else { $_ } } | Select-Object -Last 12
'DONE'
