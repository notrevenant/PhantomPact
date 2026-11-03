# The online panel on the two running copies: language, MORE, TP > PARTNER, joining. -Bell: a bell on another map.
# Joining needs the two copies on two PCs with two Steam accounts that are friends: one account can't reach itself.
param([string]$Bell = 'Bell_XM_001', [string]$Away = 'SZ_001')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$shots = 'C:\PBZDev\pp-netlab\panel-shots'
New-Item -ItemType Directory -Force $shots | Out-Null
$failed = 0
function Check([string]$What, [bool]$Ok, [string]$Seen = '') {
    if (-not $Ok) { $script:failed++ }
    "$(if ($Ok) { 'PASS' } else { 'FAIL' })  $What  $Seen"
}
function Ini($g, [string]$Key) {
    ((Get-Content (Join-Path $g.Dir 'settings.txt') -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object { $_ -match "^\s*$Key\s*=" }) -join ' ').Trim()
}
function Status($g) { "$(Get-Content (Join-Path $g.Dir 'net_status.txt') -ErrorAction SilentlyContinue)" }
function Cmd($g, [string]$Line, [double]$Wait = 0.9) { Send-Dev $g $Line; Start-Sleep -Seconds $Wait }
function Reaches($g, [string]$Text, [double]$Seconds = 25) {
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) { if ((Status $g) -match $Text) { return $true }; Start-Sleep -Milliseconds 500 }
    return $false
}
function Shot([string]$Name) {
    $d = Join-Path $shots $Name
    New-Item -ItemType Directory -Force $d | Out-Null
    & (Join-Path $PSScriptRoot 'shots.ps1') -Out $d | Out-Null
}
function SameMap() { (Ask $C 'return REAL.gap()') -match 'same map true' }

$findApi = 'local a for _,f in pairs(PBZ.coop.handlers) do for i=1,250 do local n,v=debug.getupvalue(f,i) if n==nil then break end if n=="api" then a=v end end end'
$load = "dofile(`"C:/PBZDev/netlab/perf.lua`") dofile(`"C:/PBZDev/netlab/pair.lua`") dofile(`"C:/PBZDev/netlab/fights.lua`") dofile(`"C:/PBZDev/netlab/real.lua`") dofile(`"C:/PBZDev/netlab/story.lua`") $findApi API=a return tostring(API.lang~=nil)"
"api: host $(Ask $H $load 8) guest $(Ask $C $load 8)"
$from = Log-End

'--- defaults'
Check 'starts in English' ((Ask $C 'return API.lang.code') -eq 'en')
Check 'TP > PARTNER starts off' ((Ask $C 'return tostring(API.partner.teleport)') -eq 'false')
Check 'linked' ((Status $C) -match 'connected=yes') (Status $C).Substring(0, 40)

'--- the panel, in both languages'
Cmd $C 'onlinepanel toggle' 1.5
Shot 'en-main'
Cmd $C 'onlinepanel press 150 30' 1.5
Check 'Chinese chosen' ((Ask $C 'return API.lang.code') -eq 'zh')
Check 'kept in settings.txt' ((Ini $C 'Language') -match 'Chinese') (Ini $C 'Language')
Check 'a line in Chinese' ((Ask $C 'return tostring(API.lang.say("Waiting for a partner.") ~= "Waiting for a partner.")') -eq 'true')
# (The log shows Chinese as question marks: read the shape, the screenshots show the words.)
Check 'numbers survive' ((Ask $C 'return API.lang.say("Connected to 1.2.3.4. Ping 23 ms. Route: direct.")') -match '1[.]2[.]3[.]4.* 23 ')
Shot 'zh-main'
Cmd $C 'onlinepanel press 775 515' 1.5
Shot 'zh-more'
'--- TP > PARTNER'
Cmd $C 'onlinepanel press 60 515' 1.0
Cmd $C 'onlinepanel press 70 30' 1.5
Check 'back to English' ((Ask $C 'return API.lang.code') -eq 'en')
Cmd $C 'onlinepanel press 775 515' 1.5
Shot 'en-more'
$mark = Log-End
[void](Ask $C 'API.partner.go() return "pressed"')
Start-Sleep -Seconds 1
Check 'F3 refused while off' (@(Lines $mark 'TP > PARTNER is off').Count -gt 0)
Cmd $C 'onlinepanel press 440 110' 1.0
Check 'row turns it on' ((Ask $C 'return tostring(API.partner.teleport)') -eq 'true')
Check 'kept in settings.txt' ((Ini $C 'PartnerTeleport') -match 'On') (Ini $C 'PartnerTeleport')
Cmd $C 'onlinepanel press 304 110' 1.0
Check 'row turns it off' ((Ask $C 'return tostring(API.partner.teleport)') -eq 'false')
Cmd $C 'onlinepanel press 60 515' 1.0
Cmd $C 'onlinepanel toggle' 1.0

'--- joining goes to the host once, with TP > PARTNER off'
[void](Ask $H "return STORY.go(`"$Bell`")" 8)
Start-Sleep -Seconds 6
"host: $(Wait-Player $H 150)"
[void](Ask $H $load 8)
[void](Ask $C "return STORY.go(`"$Away`")" 8)
Start-Sleep -Seconds 6
"guest: $(Wait-Player $C 150)"
[void](Ask $C $load 8)
Start-Sleep -Seconds 6
Check 'apart first' (-not (SameMap)) (Ask $C 'return REAL.gap()')
Cmd $C 'onlinepanel leave' 1.5
Cmd $C 'onlinepanel join' 2
$end = (Get-Date).AddSeconds(90)
while ((Get-Date) -lt $end -and -not (SameMap)) { Start-Sleep -Seconds 3 }
"guest: $(Wait-Player $C 150)"
[void](Ask $C $load 8)
Start-Sleep -Seconds 4
Check 'joining took the guest to the host' (SameMap) (Ask $C 'return REAL.gap()')

'--- script errors'
$errs = @(Lines $from 'Error executing|attempt to|Online panel error|Partner key error' | Where-Object { $_ -notmatch 'eval' })
Check 'none' ($errs.Count -eq 0) ($errs | Select-Object -First 3)
"failed: $failed"
