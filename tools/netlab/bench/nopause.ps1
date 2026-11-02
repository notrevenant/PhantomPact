# With a partner linked nothing pauses: the F5 panel, then the game's own pause menu (Escape), on each copy in turn.
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$findApi = 'local a for _,f in pairs(PBZ.coop.handlers) do for i=1,250 do local n,v=debug.getupvalue(f,i) if n==nil then break end if n=="api" then a=v end end end'
$load = "$findApi API=a return tostring(a~=nil)"
[void](Ask $H $load 8); [void](Ask $C $load 8)
$paused = 'local c=PBZ.getPlayer1() return "paused "..tostring(PBZ.gs():IsGamePaused(c)).." screen "..tostring(API.localcoop.screenUp()).." linked "..tostring(PBZ.coop.linked()).." world time "..string.format("%.1f",PBZ.gs():GetTimeSeconds(c)).." dilation "..tostring(PBZ.gs():GetGlobalTimeDilation(c))'
foreach ($p in @(@('host', $H), @('guest', $C))) {
    $n, $g = $p
    "--- $n"
    "start: " + (Ask $g $paused 5)
    Send-Dev $g 'onlinepanel toggle'
    Start-Sleep -Seconds 2
    "F5 panel open: " + (Ask $g $paused 5)
    Send-Dev $g 'onlinepanel toggle'
    Start-Sleep -Seconds 2
    "closed: " + (Ask $g $paused 5)
    $w = [NetLab.Win]::Unreal($g.Pid)
    [NetLab.Win]::Key($w, 0x1B)
    Start-Sleep -Seconds 2
    "pause menu: " + (Ask $g $paused 5)
    Start-Sleep -Seconds 2
    "pause menu +2 s: " + (Ask $g $paused 5)
    [NetLab.Win]::Key($w, 0x1B)
    Start-Sleep -Seconds 2
    "menu closed: " + (Ask $g $paused 5)
}
