# After a real story boss dies, does a rest bring it back? On each side.
param([int]$Row = 46, [string]$Bell = '', [string]$Name = 'Zhui Ming')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
& (Join-Path $PSScriptRoot 'boss.ps1') -Row $Row -Bell $Bell -Name $Name -RealKill
$alive = 'local out={} for n,a in pairs(PBZ.coop.enemies()) do if PBZ.valid(a) and PBZ.game.isBoss(a) then local h,m=PBZ.game.getHealth(a) out[#out+1]=n:sub(1,44).." "..a:GetClass():GetFName():ToString():sub(1,34).." "..math.floor(h or -1).."/"..math.floor(m or -1).." dead "..tostring(PBZ.game.isDead(a)) end end return #out.." bosses: "..table.concat(out," ; ")'
"--- before the rest"
"host:  " + (Ask $H $alive 5)
"guest: " + (Ask $C $alive 5)
"host at " + (Ask $H 'return STORY.where()' 4)
"guest " + (Ask $C 'return REAL.gap()' 4)
$from = Log-End
Ask $H 'local pc=PBZ.getPlayer1() local gm=PBZ.gs():GetGameMode(pc) gm["Refresh Monster"](gm) return "rested"' 6
Start-Sleep -Seconds 14
"--- after the rest"
"host:  " + (Ask $H $alive 5)
"guest: " + (Ask $C $alive 5)
"bars host " + (Ask $H 'return FIGHT.bars()' 3) + " guest " + (Ask $C 'return FIGHT.bars()' 3)
Lines $from 'Rested at a bell|rested at a bell|Boss fight|boss fight with|Host said|Host says' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 10 | ForEach-Object { '   ' + $_.Substring(0, [Math]::Min(130, $_.Length)) }
