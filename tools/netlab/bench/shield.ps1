. (Join-Path $PSScriptRoot '..\dev.ps1')
$h = Get-Content "$PSScriptRoot\dev-host.json" -Raw | ConvertFrom-Json
$c = Get-Content "$PSScriptRoot\dev-guest.json" -Raw | ConvertFrom-Json
$h.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop'
$c.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop\inst2'
$lab = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path -replace '\\', '/'
$work = (Join-Path $env:TEMP 'pp-netlab') -replace '\\', '/'
$t = Get-Date
# The host is put among awake enemies with its health back, and walks through them for 18 s.
$go = 'eval local e,n=PAIR.nearest() local l=e:K2_GetActorLocation() local _,p=PBZ.getPlayer1() local h,m=PBZ.game.getHealth(p) PBZ.game.setHealth(p,m) p:K2_SetActorLocation({X=l.X+150,Y=l.Y,Z=l.Z+30},false,{},true) return 1'
Send-Dev $h $go
Send-Dev $h 'puppets'; Send-Dev $c 'puppets'
Start-Sleep -Seconds 1
Send-Dev $h "eval PAIR.record(18, `"$work/shield-host.txt`") PAIR.walk(18, 400) PAIR.swing(18) return 1"
Send-Dev $c "eval PAIR.record(18, `"$work/shield-guest.txt`") return 1"
Start-Sleep -Seconds 20
Send-Dev $h 'puppets'; Send-Dev $c 'puppets'
Start-Sleep -Seconds 1
Send-Dev $h 'eval local _,p=PBZ.getPlayer1() return "HOSTHP "..tostring(PBZ.game.getHealth(p))'
Send-Dev $c 'eval local g=PBZ.net.ghost return "GHOSTHP "..tostring(PBZ.game.getHealth(g))'
Start-Sleep -Seconds 1
python -I "$lab/pair_report.py" "$work/shield-host.txt" "$work/shield-guest.txt"
Get-DevLog $h $t 'Puppets|HOSTHP|GHOSTHP|rror' | Where-Object { $_ -notmatch '\] > ' } | ForEach-Object { $_ -replace '^\[\d{4}-\d\d-\d\d (\S+)\] \[Lua\] ', '$1 ' } | ForEach-Object { if ($_.Length -gt 220) { $_.Substring(0, 220) } else { $_ } }
'DONE'
