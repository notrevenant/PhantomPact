# The online panel on the two running copies: language, MORE, TP > PARTNER, joining, the password both ways.
# The panel's clipboard read is replaced for the test, so the real clipboard isn't touched. -Bell: a bell on another map.
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
    ((Get-Content (Join-Path $g.Dir 'PhantomPact.ini') -Encoding UTF8 | Where-Object { $_ -match "^\s*$Key\s*=" }) -join ' ').Trim()
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
$load = "dofile(`"C:/PBZDev/netlab/perf.lua`") dofile(`"C:/PBZDev/netlab/pair.lua`") dofile(`"C:/PBZDev/netlab/fights.lua`") dofile(`"C:/PBZDev/netlab/real.lua`") dofile(`"C:/PBZDev/netlab/story.lua`") $findApi API=a PASTE=PASTE or PBZ.link.paste return tostring(API.lang~=nil)"
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
Check 'kept in the ini' ((Ini $C 'Language') -match 'Chinese') (Ini $C 'Language')
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
Check 'kept in the ini' ((Ini $C 'PartnerTeleport') -match 'On') (Ini $C 'PartnerTeleport')
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

'--- the password'
$fake = { param($t) "PBZ.link.paste=function() return `"  $t  `" end return 1" }
[void](Ask $H (& $fake 'test-pass-1')); [void](Ask $C (& $fake 'test-pass-1'))
Cmd $H 'onlinepanel toggle' 1; Cmd $C 'onlinepanel toggle' 1
Cmd $H 'onlinepanel leave' 1.5; Cmd $C 'onlinepanel leave' 1.5
Cmd $H 'onlinepanel press 610 350' 1; Cmd $C 'onlinepanel press 610 350' 1
Check 'saved on the host, trimmed' ((Ini $H 'Secret') -eq 'Secret = test-pass-1') (Ini $H 'Secret')
Check 'saved on the guest' ((Ini $C 'Secret') -eq 'Secret = test-pass-1')
Shot 'password-set'
$logged = @(Lines $mark 'test-pass-1' | Where-Object { $_ -notmatch 'eval|> ' }).Count
Check 'never in the log' ($logged -eq 0) "$logged lines"
Cmd $H 'onlinepanel host' 3; Cmd $C 'onlinepanel join' 3
Check 'connects with the same password' (Reaches $C 'connected=yes' 30)
Check 'signed' ((Status $C) -match 'auth=on') ((Status $C) -replace '.*(auth=\S+).*', '$1')
Cmd $H 'onlinepanel leave' 1.5; Cmd $C 'onlinepanel leave' 1.5
Cmd $C 'onlinepanel press 610 350' 1
Check 'pressed again it goes' ((Ini $C 'Secret') -eq 'Secret =') (Ini $C 'Secret')
[void](Ask $C (& $fake 'different'))
Cmd $C 'onlinepanel press 610 350' 1
Check 'a different one' ((Ini $C 'Secret') -eq 'Secret = different') (Ini $C 'Secret')
$mark = Log-End
Cmd $H 'onlinepanel host' 3; Cmd $C 'onlinepanel join' 3
Start-Sleep -Seconds 14
Check 'a wrong password stays out' ((Status $C) -notmatch 'connected=yes') ((Status $C) -replace '.*(rejected=\S+).*', '$1')
Check 'the guest is told' (@(Lines $mark 'packets refused|no friend hosting').Count -gt 0) ((Lines $mark 'Status:' | Select-Object -Last 1))
[void](Ask $C 'PBZ.link.paste=function() return "bad\nline" end return 1')
Cmd $H 'onlinepanel leave' 1.5; Cmd $C 'onlinepanel leave' 1.5
Cmd $C 'onlinepanel press 610 350' 1
Cmd $C 'onlinepanel press 610 350' 1
Check 'two lines are refused' ((Ini $C 'Secret') -eq 'Secret =') (Ini $C 'Secret')
Cmd $H 'onlinepanel press 610 350' 1
Check 'host clear' ((Ini $H 'Secret') -eq 'Secret =') (Ini $H 'Secret')
[void](Ask $H 'PBZ.link.paste=PASTE return 1'); [void](Ask $C 'PBZ.link.paste=PASTE return 1')
Cmd $H 'onlinepanel toggle' 1; Cmd $C 'onlinepanel toggle' 1
Cmd $H 'onlinepanel host' 3; Cmd $C 'onlinepanel join' 3
Check 'back together with none' (Reaches $C 'connected=yes' 30)
Check 'not signed' ((Status $C) -notmatch 'auth=on')

'--- script errors'
$errs = @(Lines $from 'Error executing|attempt to|Online panel error|Partner key error' | Where-Object { $_ -notmatch 'eval' })
Check 'none' ($errs.Count -eq 0) ($errs | Select-Object -First 3)
"failed: $failed"
