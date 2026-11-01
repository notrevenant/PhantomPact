. (Join-Path $PSScriptRoot '..\dev.ps1')
$h = Get-Content "$PSScriptRoot\dev-host.json" -Raw | ConvertFrom-Json
$c = Get-Content "$PSScriptRoot\dev-guest.json" -Raw | ConvertFrom-Json
$h.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop'
$c.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop\inst2'
$lab = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path -replace '\\', '/'
$work = (Join-Path $env:TEMP 'pp-netlab') -replace '\\', '/'
$t = Get-Date
$go = 'eval local e,n=PAIR.nearest() local l=e:K2_GetActorLocation() local _,p=PBZ.getPlayer1() p:K2_SetActorLocation({X=l.X+200,Y=l.Y,Z=l.Z+30},false,{},true) PBZ.log("PAIR host went to "..n) return 1'
Send-Dev $h $go
Start-Sleep -Seconds 1
Send-Dev $h "eval PAIR.record(20, `"$work/combat-host.txt`") return 1"
Send-Dev $c "eval PAIR.record(20, `"$work/combat-guest.txt`") return 1"
Start-Sleep -Seconds 12
$hurt = 'eval local e,n=PAIR.nearest() if e then PAIR.lastName=n local hp=PBZ.game.getHealth(e) PBZ.game.setHealth(e,hp*0.6) PBZ.log("PAIR near "..n) end return 1'
Send-Dev $h $hurt
Start-Sleep -Milliseconds 400
Send-Dev $h 'eval PAIR.look(PAIR.lastName) return "HOST"'
$name = (Get-DevLog $h $t 'PAIR near' | Select-Object -Last 1) -replace '^.*PAIR near ', ''
"enemy: $name"
Send-Dev $c "eval PAIR.look(`"$name`") return `"GUEST`""
Start-Sleep -Seconds 9
Send-Dev $h 'puppets'; Send-Dev $c 'puppets'
Start-Sleep -Seconds 1
Send-Dev $h 'moves'; Send-Dev $c 'moves'
Start-Sleep -Seconds 1
Send-Dev $h 'netstatus'; Send-Dev $c 'netstatus'
Start-Sleep -Seconds 1
python -I "$lab/pair_report.py" "$work/combat-host.txt" "$work/combat-guest.txt"
Get-DevLog $h $t 'PAIR|Puppets|Moves:|Relay:|net error|event .* error|rror:' | Where-Object { $_ -notmatch '\] > ' } | ForEach-Object { $_ -replace '^\[\d{4}-\d\d-\d\d (\S+)\] \[Lua\] ', '$1 ' } | ForEach-Object { if ($_.Length -gt 330) { $_.Substring(0, 330) } else { $_ } }
'DONE'
