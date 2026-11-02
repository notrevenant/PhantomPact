# One story boss, for real: both copies rewind, take the story up to just before the event, walk to the quest marker and
# let the game start the fight. Then the boss is finished and both quest logs are compared.
param([int]$Row, [string]$Bell, [string]$Name = '', [int]$Wait = 150, [string]$Out = 'C:\PBZDev\pp-netlab\boss-log.txt', [switch]$RealKill)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
function Note([string]$s) { $s; Add-Content -Path $Out -Value $s -Encoding utf8 }
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/walker.lua") dofile("C:/PBZDev/netlab/walker2.lua") return 1'
$from = Log-End
Note "=== row $Row $Name bell $Bell $(Get-Date -Format HH:mm:ss)"
[void](Ask $H $load 8); [void](Ask $C $load 8)
[void](Ask $H 'WALK.stop() local cm=STORY.gm() cm:GM_LoadGame("ManualSave1") return 1' 6); [void](Ask $C 'WALK.stop() local cm=STORY.gm() cm:GM_LoadGame("ManualSave1") return 1' 6)
Start-Sleep -Seconds 6
$a = Wait-Player $H 120; $b = Wait-Player $C 120
if ($a -ne 'ready' -or $b -ne 'ready') { Note "  rewind failed: $a $b"; return }
Start-Sleep -Seconds 4
[void](Ask $H $load 8); [void](Ask $C $load 8)
if ($Row -gt 1) {
    $last = $Row - 1
    [void](Ask $H "return STORY.apply(1, $last)" 20); [void](Ask $C "return STORY.apply(1, $last)" 20)
}
if ($Bell) {
    [void](Ask $H "return STORY.go(`"$Bell`")" 8); [void](Ask $C "return STORY.go(`"$Bell`")" 8)
    Start-Sleep -Seconds 6
    $a = Wait-Player $H 150; $b = Wait-Player $C 150
    if ($a -ne 'ready' -or $b -ne 'ready') { Note "  travel failed: $a $b"; return }
    Start-Sleep -Seconds 4
    [void](Ask $H $load 8); [void](Ask $C $load 8)
}
$steps = 'local o={} for _,e in ipairs(WALK.active()) do o[#o+1]=e.qname:gsub("_C$","").."/"..e.point end return table.concat(o," "):sub(1,170)'
Note ("  before H " + (Ask $H $steps)); Note ("  before G " + (Ask $C $steps))
$nf = 'WALK.cfg.forceS=1e9 local _,p=PBZ.getPlayer1() PBZ.game.setMinHealth(p,1) return WALK.start(900, nil)'
[void](Ask $H $nf 8); [void](Ask $C $nf 8)
$boss = ''
$end = (Get-Date).AddSeconds($Wait)
$find = 'for n,a in pairs(PBZ.coop.enemies()) do if PBZ.valid(a) and not PBZ.game.isDead(a) and PBZ.game.isBoss(a) then local h,m=PBZ.game.getHealth(a) return n.."|"..a:GetClass():GetFName():ToString().."|"..tostring(h).."|"..tostring(m) end end return "none"'
while ((Get-Date) -lt $end) {
    if (-not (Alive $H) -or -not (Alive $C)) { Note '  A COPY IS GONE'; return }
    $r = Ask $H $find 3
    if ($r -and $r -ne 'none') { $boss = $r; break }
    Start-Sleep -Seconds 4
}
if (-not $boss) {
    Note ("  no boss came in $Wait s; host at " + (Ask $H 'return STORY.where()'))
    Lines $from 'WALK (step|cutscene |no target|teleport)' | Select-Object -Last 5 | ForEach-Object { '    ' + $_.Substring(16, [Math]::Min(100, $_.Length - 16)) } | ForEach-Object { Note $_ }
    [void](Ask $H 'return WALK.stop()'); [void](Ask $C 'return WALK.stop()')
    return
}
$e = ($boss -split '\|')[0]
Note "  boss $boss at $(Get-Date -Format HH:mm:ss)"
Start-Sleep -Seconds 8
$g = Ask $C "return REAL.hp(`"$e`")"
Note ("  guest sees: " + ($g -replace ' montage.*', '') + " bars host " + (Ask $H 'return FIGHT.bars()') + " guest " + (Ask $C 'return FIGHT.bars()'))
if ($RealKill) {
    # Whatever real blow lands next is the one that kills it, so the game's whole death runs.
    [void](Ask $H "return REAL.keepLow(`"$e`", 30, 15)")
    [void](Ask $H "return REAL.fight(`"$e`", 14)")
    Start-Sleep -Seconds 18
} else {
    [void](Ask $H "local e=PBZ.coop.enemyActor(`"$e`") PBZ.game.setHealth(e, 120) return 1")
    Start-Sleep -Seconds 14
}
$st = Ask $H "return REAL.hp(`"$e`")"
Note ("  after 14 s of real hits: host " + ($st -replace ' montage.*', '') + " guest " + ((Ask $C "return REAL.hp(`"$e`")") -replace ' montage.*', ''))
if ($st -notmatch 'dead=true' -and $st -ne 'gone') {
    [void](Ask $H "local e=PBZ.coop.enemyActor(`"$e`") if e then PBZ.game.kill(e) end return 1")
    Note '  (finished by script)'
}
Start-Sleep -Seconds 25
Note ("  after H " + (Ask $H $steps)); Note ("  after G " + (Ask $C $steps))
Note ("  bars host " + (Ask $H 'return FIGHT.bars()') + " guest " + (Ask $C 'return FIGHT.bars()') + " | " + (Ask $H 'return STORY.where()'))
[void](Ask $H 'return WALK.stop()'); [void](Ask $C 'return WALK.stop()')
Lines $from 'Host says|Enemy died here|Killing blow|boss fight with|Joining|healed on|Error executing|attempt to|not matched' | Where-Object { $_ -notmatch 'eval' } | Select-Object -Last 8 | ForEach-Object { '    ' + $_.Substring(16, [Math]::Min(110, $_.Length - 16)) } | ForEach-Object { Note $_ }
Lines $from 'WALK (cutscene S|cutscene [A-Za-z])' | Select-Object -Last 6 | ForEach-Object { '    ' + $_.Substring(16, [Math]::Min(80, $_.Length - 16)) } | ForEach-Object { Note $_ }
