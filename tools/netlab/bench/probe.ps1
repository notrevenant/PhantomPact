. (Join-Path $PSScriptRoot '..\dev.ps1')
$h = Get-Content "$PSScriptRoot\dev-host.json" -Raw | ConvertFrom-Json
$c = Get-Content "$PSScriptRoot\dev-guest.json" -Raw | ConvertFrom-Json
$h.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop'
$c.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop\inst2'
$t = Get-Date
$probe = @'
eval local _,p=PBZ.getPlayer1() local l=p:K2_GetActorLocation() local n=0 for k in pairs(PBZ.net.remoteEnemies) do n=n+1 end local m=0 for k in pairs(PBZ.coop.enemies()) do m=m+1 end local list={} for _,e in ipairs(PBZ.game.listEnemies(true)) do if PBZ.valid(e) then local a=e:K2_GetActorLocation() local hp=PBZ.game.getHealth(e) list[#list+1]={d=PBZ.distance(a,l),t=string.format("%.0fm hp%.0f",PBZ.distance(a,l)/100,hp or -1)} end end table.sort(list,function(x,y) return x.d<y.d end) local s={} for i=1,math.min(6,#list) do s[i]=list[i].t end return string.format("PROBE at %.0f %.0f %.0f hp %s mode %s dead %s remote %d matched %d ghost %s hidden %s near: %s",l.X,l.Y,l.Z,tostring(PBZ.game.getHealth(p)),tostring(p.CharacterMovement.MovementMode),tostring(PBZ.game.isDead(p)),n,m,tostring(PBZ.valid(PBZ.net.ghost)),tostring(PBZ.net.ghostHidden),table.concat(s,", "))
'@
Send-Dev $h $probe; Send-Dev $c $probe
Start-Sleep -Seconds 2
Get-DevLog $h $t 'PROBE|eval error|compile' | Where-Object { $_ -notmatch '\] > ' } | ForEach-Object { $_ -replace '^\[\d{4}-\d\d-\d\d (\S+)\] \[Lua\] ', '$1 ' } | ForEach-Object { if ($_.Length -gt 300) { $_.Substring(0, 300) } else { $_ } }
$tail = Get-DevLog $h (Get-Date).AddMinutes(-1) 'Status|Ghost|Lost|back|Respawn|died|You ' | Select-Object -Last 8
$tail | ForEach-Object { $_ -replace '^\[\d{4}-\d\d-\d\d (\S+)\] \[Lua\] ', '$1 ' } | ForEach-Object { if ($_.Length -gt 170) { $_.Substring(0, 170) } else { $_ } }
'DONE'
