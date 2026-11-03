<#
.SYNOPSIS
    The online panel on two real copies: F4, its words, Leave, a refused Host, Join, Host again on the same port, a role swap,
    closing. One PASS or FAIL per check, and pictures in -Shots. Take the bench first. About a minute and a half.

    Commands go through cmd.txt and run what the buttons run, so nothing takes the focus; F4 is posted to the game's window.
    A real mouse click isn't tested: the clicks here enter at the same point, with panel coordinates.

    The copies connect through Steam only, so the Join and connection checks need two PCs with two Steam accounts that are
    friends: one account can't reach itself.

    -NoStart uses the copies already up and connected (dev-host.json, dev-guest.json) and leaves them as it found them:
    connected, panel closed, game running. Their panel was off at startup, so this repo's onlinepanel.lua is loaded into them
    (api is an upvalue of coop's event handlers). Without it, two copies start here. -Look stops after
    the first two pictures, with the panels closed again.
#>
param([string]$Shots = $env:TEMP, [switch]$NoStart, [switch]$Look)
. (Join-Path $PSScriptRoot '..\dev.ps1')
if (-not ('PanelShot.Win' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Threading; using System.Runtime.InteropServices;
namespace PanelShot { public static class Win {
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern uint MapVirtualKey(uint c, uint t);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr h, ref Point p);
    [StructLayout(LayoutKind.Sequential)] struct R { public int L, T, Rt, B; }
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out R r);
    const uint NOSIZE_NOMOVE_NOACTIVATE = 1 | 2 | 0x10;

    static bool Blank(Bitmap b) {
        int lo = 255, hi = 0;
        for (int y = 0; y < b.Height; y += Math.Max(1, b.Height / 40))
            for (int x = 0; x < b.Width; x += Math.Max(1, b.Width / 40)) {
                Color c = b.GetPixel(x, y);
                int v = (c.R + c.G + c.B) / 3;
                lo = Math.Min(lo, v); hi = Math.Max(hi, v);
            }
        return hi - lo < 12;
    }

    // The window's own picture, so nothing comes to the front. If that's blank, the window is lifted above the others for a
    // moment, without the focus, and read off the screen. Says which it was.
    public static string Save(IntPtr h, string path) {
        R r; GetClientRect(h, out r);
        int w = r.Rt - r.L, t = r.B - r.T;
        using (Bitmap b = new Bitmap(w, t)) {
            using (Graphics g = Graphics.FromImage(b)) {
                IntPtr dc = g.GetHdc(); PrintWindow(h, dc, 3); g.ReleaseHdc(dc);
            }
            if (!Blank(b)) { b.Save(path, ImageFormat.Png); return "window"; }
            SetWindowPos(h, new IntPtr(-1), 0, 0, 0, 0, NOSIZE_NOMOVE_NOACTIVATE);
            Thread.Sleep(300);
            Point p = new Point(0, 0); ClientToScreen(h, ref p);
            using (Graphics g = Graphics.FromImage(b)) g.CopyFromScreen(p.X, p.Y, 0, 0, new Size(w, t));
            SetWindowPos(h, new IntPtr(-2), 0, 0, 0, 0, NOSIZE_NOMOVE_NOACTIVATE);
            b.Save(path, ImageFormat.Png);
            return Blank(b) ? "BLANK" : "screen";
        }
    }

    // Held long enough for the mod's 40 ms look at the key, on a busy game's slow frames.
    public static void Press(IntPtr h, uint vk, int ms) {
        uint s = MapVirtualKey(vk, 0);
        PostMessage(h, 0x100, (IntPtr)vk, (IntPtr)(1 | (s << 16)));
        Thread.Sleep(ms);
        PostMessage(h, 0x101, (IntPtr)vk, unchecked((IntPtr)(int)(1u | (s << 16) | (1u << 30) | (1u << 31))));
    }
} }
'@
}

$began = Get-Date
$run = Get-Random -Maximum 1000000
$script:asked = 0
$repoPanel = (Join-Path $script:RepoRoot 'mod\PBZCoop\Scripts\onlinepanel.lua') -replace '\\', '/'
$findApi = 'local a for _,f in pairs(PBZ.coop.handlers) do for i=1,250 do local n,v=debug.getupvalue(f,i) if n==nil then break end if n=="api" then a=v end end end'
$paused = 'PBZ.gs():IsGamePaused((PBZ.getPlayer1()))'
$F4 = 0x73

function Check([string]$What, [bool]$Ok, [string]$Seen = '') { "$(if ($Ok) { 'PASS' } else { 'FAIL' })  $What  $Seen" }
function Status($g) { "$(Get-Content (Join-Path $g.Dir 'net_status.txt') -ErrorAction SilentlyContinue)" }
function Short($g) { $s = Status $g; $s.Substring(0, [Math]::Min(50, $s.Length)) }
function Ini($g, [string]$Key) { (Get-Content (Join-Path $g.Dir 'settings.txt') -ErrorAction SilentlyContinue | Where-Object { $_ -match "^\s*$Key\s*=" }) -join ' ' }
function Sockets($g) { @(Get-NetUDPEndpoint -OwningProcess $g.Pid -ErrorAction SilentlyContinue).Count }
function Shot($g, [string]$Name) { "picture $Name ($([PanelShot.Win]::Save([NetLab.Win]::Unreal($g.Pid), (Join-Path $Shots "$Name.png"))))" }

function Tail {
    $fs = [IO.File]::Open((Join-Path $script:GameDir 'ue4ss\UE4SS.log'), 'Open', 'Read', 'ReadWrite, Delete')
    [void]$fs.Seek([Math]::Max(0, $fs.Length - 40000), 'Begin')
    $text = (New-Object IO.StreamReader $fs).ReadToEnd()
    $fs.Dispose()
    $text
}

# Runs Lua in a copy (cmd.txt is read twice a second) and returns the expression's value as text.
function Ask($g, [string]$Expression, [string]$First = '') {
    $script:asked++
    $mark = "A$run.$($script:asked)="
    Send-Dev $g "eval $First return `"$mark`" .. tostring($Expression)"
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 100
        $line = (Tail) -split "`r?`n" | Where-Object { $_ -match [regex]::Escape($mark) -and $_ -match 'eval ok' } | Select-Object -Last 1
        if ($line) { return ($line -replace ('^.*' + [regex]::Escape($mark)), '') }
    }
    'no answer'
}

function Panel($g, [string]$Word) { [void](Ask $g "ONLINE_PANEL.command(`"$Word`")") }
function Words($g) { Ask $g 'ONLINE_PANEL.describe()' }
function Press-F4($g) { [PanelShot.Win]::Press([NetLab.Win]::Unreal($g.Pid), $F4, 250); Start-Sleep -Milliseconds 300 }

function Reaches($g, [string]$Pattern, [double]$Seconds = 6) {
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) {
        if ((Status $g) -match $Pattern) { return $true }
        Start-Sleep -Milliseconds 150
    }
    (Status $g) -match $Pattern
}

function Soon($g, [string]$Expression, [double]$Seconds = 5) {
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) {
        if ((Ask $g $Expression) -eq 'true') { return $true }
    }
    $false
}

if ($NoStart) {
    $a = Get-Content (Join-Path $PSScriptRoot 'dev-host.json') -Raw | ConvertFrom-Json
    $b = Get-Content (Join-Path $PSScriptRoot 'dev-guest.json') -Raw | ConvertFrom-Json
    foreach ($g in $a, $b) {
        $p = Get-Process -Id $g.Pid -ErrorAction SilentlyContinue
        if (-not $p -or $p.Path -notlike 'C:\PBZDev\*') { throw "Copy $($g.Pid) isn't running from the dev install." }
    }
    # A second run in one session retires the first one's loops: closed, and their F4 does nothing.
    $load = "$findApi if ONLINE_PANEL then if ONLINE_PANEL.open then ONLINE_PANEL.close() end ONLINE_PANEL.show=function() end end " +
        "ONLINE_PANEL=dofile(`"$repoPanel`")(a) a.onlinepanel=ONLINE_PANEL ONLINE_PANEL.start()"
} else {
    "mod hash " + (Install-DevMod)
    $a = Start-DevGame -Role Host
    $b = Start-DevGame -Role Guest -Instance 2
    "gameplay: $(Wait-DevGameplay $a 200) $(Wait-DevGameplay $b 120) at $(Get-Date -Format HH:mm:ss)"
    [void](Reaches $b 'connected=yes' 20)
    $load = "$findApi ONLINE_PANEL=a.onlinepanel"
}

$got = (Ask $a 'ONLINE_PANEL ~= nil' $load), (Ask $b 'ONLINE_PANEL ~= nil' $load)
Check 'panel started by command' (($got[0] -eq 'true') -and ($got[1] -eq 'true')) "$got"
if (($got[0] -ne 'true') -or ($got[1] -ne 'true')) { throw 'The panel is not in these copies: restart them with this repo's mod.' }
"start: $(Short $a) | $(Short $b)"

"--- open, on a connected pair"
Panel $a 'toggle'
Panel $b 'toggle'
$open = (Ask $a 'ONLINE_PANEL.open'), (Ask $b 'ONLINE_PANEL.open')
Check 'it opens' (($open[0] -eq 'true') -and ($open[1] -eq 'true')) "$open"
if (($open[0] -ne 'true') -or ($open[1] -ne 'true')) {
    foreach ($g in $a, $b) {
        "copy $($g.Instance): paused $(Ask $g $paused), scene $(Ask $g 'PBZ.game.inCutscene()'), dead $(Ask $g 'PBZ.game.isDead(select(2,PBZ.getPlayer1()))')"
    }
    Get-DevLog $a $began 'Screen up' | Select-Object -Last 2
}
Check 'the game is paused behind it' ((Ask $a $paused) -eq 'true')
Start-Sleep -Milliseconds 1000
$mouse = "$(Get-Content (Join-Path $a.Dir 'mouse.txt') -ErrorAction SilentlyContinue)"
Check 'main.dll feeds it the mouse and the focus' ($mouse -match '^-?\d+ -?\d+ [01] [01] [01] [01]$') $mouse
$w = Words $a
Check 'words: connected to whom, ping' ($w -match '^Connected to 127\.0\.0\.1\. Ping \d+ ms\.') $w
Shot $a 'online-panel-1-host'
Shot $b 'online-panel-2-guest'
if ($Look) {
    Panel $a 'toggle'
    Panel $b 'toggle'
    "closed: $(Ask $a 'ONLINE_PANEL.open') $(Ask $b 'ONLINE_PANEL.open'), paused $(Ask $a $paused) $(Ask $b $paused)"
    return
}

"--- Leave"
$n = Sockets $b
Panel $b 'leave'
Check 'Leave: relay stopped' (Reaches $b 'stopped=yes' 3) (Status $b)
Check 'Leave: socket closed' ((Sockets $b) -eq ($n - 1)) "$n then $(Sockets $b)"
Check 'Leave: sync off, ghost gone' (((Ask $b 'PBZ.net.enabled') -eq 'false') -and ((Ask $b 'PBZ.valid(PBZ.net.ghost)') -eq 'false'))
Check 'Leave: saved' ((Ini $b 'Role') -match 'Off') (Ini $b 'Role')
$w = Words $b
Check 'words: not connected' ($w -eq 'Not connected.') $w
Start-Sleep -Milliseconds 700
Shot $b 'online-panel-3-left'

Check 'the host notices' (Reaches $a 'connected=no' 5) (Short $a)
$w = Words $a
Check 'words: waiting for a partner' ($w -eq 'Waiting for a partner.') $w
Start-Sleep -Milliseconds 700
Shot $a 'online-panel-4-waiting'

"--- refused, then back in"
Panel $b 'host'
Check 'Host on a taken port fails in the status' (Reaches $b 'error=' 3) (Status $b)
Start-Sleep -Milliseconds 700
$w = Words $b
Check 'words: why it failed' ($w -match "^Couldn't start") $w
Shot $b 'online-panel-5-refused'
Panel $b 'join'
Check 'Join: connected' (Reaches $b 'role=client.*connected=yes' 8) (Short $b)
Check 'Join: the host sees it' (Reaches $a 'connected=yes' 5)
Check 'Join: ghost back' (Soon $b 'PBZ.valid(PBZ.net.ghost)')
Check 'Join: saved' ((Ini $b 'Role') -match 'Guest') (Ini $b 'Role')

"--- the host leaves and comes back"
$n = Sockets $a
Panel $a 'leave'
Check 'host Leave: stopped' (Reaches $a 'stopped=yes' 3) (Short $a)
Check 'host Leave: socket closed' ((Sockets $a) -eq ($n - 1)) "$n then $(Sockets $a)"
Panel $a 'host'
Check 'Host again on the same port, partner back' (Reaches $a 'role=host.*connected=yes' 6) (Short $a)

"--- roles swapped, Host to Join with no Leave"
Panel $b 'leave'
Panel $a 'join'
Panel $b 'host'
$swap = (Reaches $a 'role=client.*connected=yes' 8), (Reaches $b 'role=host.*connected=yes' 8)
Check 'roles swapped' ($swap[0] -and $swap[1]) "$(Short $a) | $(Short $b)"

"--- back as they were"
Panel $b 'leave'
Panel $a 'host'
Panel $b 'join'
$back = (Reaches $a 'role=host.*connected=yes' 8), (Reaches $b 'role=client.*connected=yes' 8)
Check 'host and guest again' ($back[0] -and $back[1]) "$(Short $a) | $(Short $b)"
Check 'saved' (((Ini $a 'Role') -match 'Host') -and ((Ini $b 'Role') -match 'Guest')) "$(Ini $a 'Role') | $(Ini $b 'Role')"

"--- closing"
Panel $a 'press 860 30'
Check 'the X closes it (panel coordinates)' ((Ask $a 'ONLINE_PANEL.open') -eq 'false')
# A key posted to a window in the background didn't reach IsInputKeyDown (0 of 45 looks over 1.5 s, 2026-11-01): this check
# only means something with the copy in the foreground.
Press-F4 $a
$open = Ask $a 'ONLINE_PANEL.open'
Check 'F4 opens it (key posted to the window)' ($open -eq 'true') $open
if ($open -eq 'true') { Panel $a 'toggle' }
Panel $b 'toggle'
foreach ($g in $a, $b) {
    Check "closed, copy $($g.Instance): the game runs, no cursor" (((Ask $g $paused) -eq 'false') -and ((Ask $g '(PBZ.getPlayer1()).bShowMouseCursor') -eq 'false'))
    Check "closed, copy $($g.Instance): main.dll told to stop" (-not (Test-Path (Join-Path $g.Dir 'pads_want.txt')))
}

"--- a paused game keeps it shut (the pause the game's menus use)"
[void](Ask $a 'true' 'PBZ.gs():SetGamePaused((PBZ.getPlayer1()),true)')
Panel $a 'toggle'
$open = Ask $a 'ONLINE_PANEL.open'
Check 'stays shut' ($open -eq 'false') $open
if ($open -eq 'true') { Panel $a 'toggle' }
[void](Ask $a 'true' 'PBZ.gs():SetGamePaused((PBZ.getPlayer1()),false)')
Check 'runs again' ((Ask $a $paused) -eq 'false')

"--- at the end"
Check 'sync on both, ghosts up' ((Soon $a 'PBZ.net.enabled and PBZ.valid(PBZ.net.ghost)') -and (Soon $b 'PBZ.net.enabled and PBZ.valid(PBZ.net.ghost)'))
"$(Short $a) | $(Short $b)"
$bad = @(Get-DevLog $a $began 'Online panel error|net error')
Check 'no panel or net errors in the log' ($bad.Count -eq 0) "$($bad.Count) lines"
$bad | Select-Object -Last 4
"DONE in $([int]((Get-Date) - $began).TotalSeconds) s"
