<#
.SYNOPSIS
    Records a real co-op session for debugging: UE4SS.log from every launch (the game overwrites it on each start),
    crash dumps, every line of net_status.txt with memory use, and how Tailscale reaches the partner (direct or
    relayed). Waits for PBZ.exe, and stops by itself once the game has been closed for -GoneMinutes. Any Secret in the
    ini is left out of the copy.

    Reads only; changes nothing in the game (-Perf is the one exception, see below).

    net_status.log has one line per status: the relay's whole line, once a second. summary.txt, written at the end, turns
    it into the numbers to set against docs\NETCODE.md: ping, jitter, loss, the partner's playback delay, gaps,
    packets per second. Ghost distances and kill delays need two recordings on one clock, so they stay with
    tools\netlab\bench\pair-run.ps1.

.PARAMETER Perf
    Developer installs only (they have dev.txt): turns on one eval that logs the frame rate and the mod's game-thread
    time every 10 s, as "PERF session" lines in the UE4SS log, and summary.txt reports them. Without it the packets
    sent per second stand in for the frame rate: one a frame while sync is on, at most 62.
.PARAMETER Summarize
    Writes summary.txt again for a folder this script recorded (one a player sent you), and prints it.

.EXAMPLE
    .\tools\record-session.ps1 -Out D:\PhantomPactLogs
    .\tools\record-session.ps1 -Perf
    .\tools\record-session.ps1 -Summarize D:\PhantomPactLogs\20261101-203000
#>
param(
    [string]$Out = (Join-Path $env:USERPROFILE 'PhantomPactLogs'),
    [double]$GoneMinutes = 15,
    [double]$MaxHours = 16,
    [switch]$Perf,
    [string]$Summarize,
    [string]$ProcessName = 'PBZ'
)
$ErrorActionPreference = 'SilentlyContinue'

# A line of net_status.log as a table: mem, role, connected, rtt_ms...
function Read-Fields([string]$Line) {
    $fields = @{}
    foreach ($m in [regex]::Matches($Line, '(\w+)=(\S*)')) { $fields[$m.Groups[1].Value] = $m.Groups[2].Value }
    $fields
}

# "p50 31  p95 44  max 212"; -Low asks for the low end instead, for rates: "p50 60  low 52".
function Spread($Values, [switch]$Low) {
    $sorted = @($Values | Sort-Object)
    if (-not $sorted.Count) { return 'no data' }
    $at = { param($p) '{0:0.#}' -f $sorted[[math]::Min($sorted.Count - 1, [int][math]::Floor($sorted.Count * $p))] }
    if ($Low) { "p50 $(& $at 0.5)  low $(& $at 0.05)" } else { "p50 $(& $at 0.5)  p95 $(& $at 0.95)  max $('{0:0.#}' -f $sorted[-1])" }
}

function Write-Summary([string]$Folder) {
    $ErrorActionPreference = 'Stop'
    $lines = @(Get-Content (Join-Path $Folder 'net_status.log') -ErrorAction SilentlyContinue)
    $rtt, $jitter, $delay, $sentRate, $receivedRate, $gaps, $fps, $modMs = 1..8 | ForEach-Object { New-Object Collections.Generic.List[double] }
    $connected, $drops, $lossyLines, $lossSum, $lossWorst, $pendingMost, $memMost = 0, 0, 0, 0.0, 0.0, 0, 0.0
    $prev, $last, $failures = $null, $null, @()
    foreach ($line in $lines) {
        $f = Read-Fields $line
        $memMost = [math]::Max($memMost, [double]($f.mem -replace 'MB$'))
        if (-not $f.time) {
            # "stopped=yes": the player left, or with error= the relay failed, in its own words (spaces and all, so last).
            if ($line -match ' error=(.*)$') { $failures += $Matches[1] }
            $prev = $null
            continue
        }
        $last = $f
        $linked = $f.connected -eq 'yes'
        if ($linked) {
            $connected++
            if ($f.rtt_ms -match '^[\d.]+$') { $rtt.Add([double]$f.rtt_ms) }
            $jitter.Add([double]$f.jitter_ms)
            $delay.Add([double]$f.delay_ms)
            # loss_pct covers the second before each line, so this needs every line: the recorder reads twice a second.
            $loss = [double]$f.loss_pct
            $lossSum += $loss
            $lossWorst = [math]::Max($lossWorst, $loss)
            if ($loss -gt 0) { $lossyLines++ }
            $pendingMost = [math]::Max($pendingMost, [long]$f.pending)
            if ($prev -and $prev.connected -eq 'yes') {
                $span = [math]::Max(1, [long]$f.time - [long]$prev.time)
                $sent, $received = (([long]$f.sent - [long]$prev.sent) / $span), (([long]$f.received - [long]$prev.received) / $span)
                if ($sent -ge 0 -and $received -ge 0) { $sentRate.Add($sent); $receivedRate.Add($received) }    # below 0: a new game launch
            }
        } elseif ($prev -and $prev.connected -eq 'yes') {
            $drops++
        }
        $prev = $f
    }
    foreach ($hit in Select-String -Path (Join-Path $Folder 'UE4SS-*.log') -Pattern 'No packet for ([\d.]+) s|PERF session fps=([\d.]+) mod_ms_s=([\d.]+)') {
        $g = $hit.Matches[0].Groups
        if ($g[1].Success) { $gaps.Add([double]$g[1].Value) } else { $fps.Add([double]$g[2].Value); $modMs.Add([double]$g[3].Value) }
    }

    $out = New-Object Collections.Generic.List[string]
    $out.Add("Phantom Pact session $(Split-Path $Folder -Leaf). docs\NETCODE.md has the numbers to set these against.")
    foreach ($failure in ($failures | Select-Object -Unique)) { $out.Add("The relay failed: $failure") }
    if (-not $last) {
        $out.Add('The relay never reported: check Role in PhantomPact.ini, dlls\main.dll, and any relay_error.txt here.')
    } else {
        $out.Add("Recorded $($lines.Count) status lines, $($lines[0].Substring(0, 8)) to $($lines[-1].Substring(0, 8)), memory peak $memMost MB.")
        $out.Add("$($last.role) via $($last.via), version $($last.version), partner $($last.partner_version), partner's map $($last.partner_map), signed $($last.auth)")
        $out.Add("Connected in $connected of $($lines.Count) lines ($('{0:0.#}' -f (100 * $connected / $lines.Count))%). Drops: $drops. Settings that differ: $($last.mismatch)")
        $out.Add("Refused packets: $($last.filtered) filtered, $($last.rejected) rejected")
        $out.Add('')
        $out.Add("Ping (rtt_ms)                $(Spread $rtt)")
        $out.Add("Jitter (jitter_ms)           $(Spread $jitter)")
        $out.Add("Partner's delay (delay_ms)   $(Spread $delay)")
        $average = if ($connected) { $lossSum / $connected } else { 0 }
        $out.Add("Loss (loss_pct)              average $('{0:0.##}' -f $average), worst second $lossWorst, $lossyLines seconds with any")
        $longest = if ($gaps.Count) { ($gaps | Measure-Object -Maximum).Maximum } else { 0 }
        $out.Add("Gaps of 0.5 s or more        $($gaps.Count), longest $longest s")
        $out.Add('')
        $out.Add("Packets sent per second      $(Spread $sentRate -Low)    (one a frame while sync is on, at most 62: your frame rate)")
        $out.Add("Packets received per second  $(Spread $receivedRate -Low)    (the same for your partner)")
        $out.Add("Sure lane                    $($last.events_acked) acknowledged, $($last.events_in) arrived, $($last.resent) resent, at most $pendingMost waiting")
        if ($fps.Count) {
            $out.Add('')
            $out.Add("FPS with sync on (-Perf)     $(Spread $fps -Low)")
            $out.Add("Mod's ms/s of game thread    $(Spread $modMs)")
        }
    }
    $out | Set-Content (Join-Path $Folder 'summary.txt') -Encoding utf8
    $out
}

if ($Summarize) {
    Write-Summary $Summarize
    return
}

$folder = Join-Path $Out (Get-Date -Format 'yyyyMMdd-HHmmss')
New-Item -ItemType Directory -Force $folder | Out-Null
$began = Get-Date
$tailscale = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
function Note([string]$File, [string]$Text) { Add-Content (Join-Path $folder $File) "$(Get-Date -Format 'HH:mm:ss.fff') $Text" -Encoding utf8 }
Note 'recorder.txt' "recording to $folder"

# -Perf: a frame counter on the mod's own per-frame tick, and its stage timing (coop.lua runStage, as PERF.stages reads it).
$perfEval = 'eval local net,n,t0=PBZ.net,0,os.clock() net.profile={} PBZ.coop.frameTicks.record=function() n=n+1 local now=os.clock() if now-t0<10 then return end local s=0 for _,p in pairs(net.profile or {}) do s=s+p.t end PBZ.log(string.format("PERF session fps=%.1f mod_ms_s=%.1f",n/(now-t0),s*1000/(now-t0))) net.profile={} n,t0=0,now end return "session perf on"'

$seenAt, $ue4ss, $described, $stamp, $statusLine, $relayUp, $perfFor = $null, $null, $false, $null, '', $null, $null
$nextCopy, $nextPing = $began, $began
try {
    while (((Get-Date) - $began).TotalHours -lt $MaxHours) {
        # The launcher is also PBZ.exe, elsewhere and small: the real game is the one beside ue4ss.
        $game = Get-Process $ProcessName | Where-Object { $_.Path -and (Test-Path (Join-Path (Split-Path $_.Path) 'ue4ss')) } | Sort-Object StartTime | Select-Object -First 1
        if ($game) {
            $seenAt = Get-Date
            $ue4ss = Join-Path (Split-Path $game.Path) 'ue4ss'
            $mod = Join-Path $ue4ss 'Mods\PBZCoop'
            if (-not $described) {
                $described = $true
                Get-Content (Join-Path $mod 'PhantomPact.ini') | Where-Object { $_ -notmatch '^\s*Secret\s*=' } | Set-Content (Join-Path $folder 'PhantomPact.ini')
                Note 'setup.txt' "main.dll $((Get-FileHash (Join-Path $mod 'dlls\main.dll')).Hash)"
                Get-NetConnectionProfile | ForEach-Object { Note 'setup.txt' "network: $($_.InterfaceAlias) $($_.NetworkCategory)" }
                # Throws when the exe has no rule, which is worth knowing too (Windows never asked, or the prompt was missed).
                try {
                    Get-NetFirewallApplicationFilter -Program $game.Path -ErrorAction Stop | Get-NetFirewallRule | ForEach-Object { Note 'setup.txt' "firewall: $($_.Action) $($_.Direction) profile=$($_.Profile) enabled=$($_.Enabled)" }
                } catch {
                    Note 'setup.txt' 'firewall: no rule for this exe'
                }
            }
            # Named by the game's start time, so the next launch can't overwrite this copy.
            $stamp = $game.StartTime.ToString('HHmmss')

            # The relay rewrites this once a second, and its time= says whether that's now or a line left by an earlier run.
            $status = "$(Get-Content (Join-Path $mod 'net_status.txt') -Raw)".Trim()
            $up = $status -match 'time=(\d+)' -and ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [long]$Matches[1]) -le 10
            if ($status -ne $statusLine -and ($up -or $status -match 'stopped=yes')) {
                $statusLine = $status
                Note 'net_status.log' ("mem={0}MB {1}" -f [math]::Round($game.WorkingSet64 / 1MB), $status)
            }
            if ($up -ne $relayUp) {
                $relayUp = $up
                Note 'recorder.txt' $(if ($up) { 'relay running' } else { 'relay not running: no fresh net_status.txt (Role in the ini, dlls\main.dll, relay_error.txt)' })
            }
            if ($Perf -and $up -and $perfFor -ne $stamp) {
                $perfFor = $stamp
                if (Test-Path (Join-Path $mod 'dev.txt')) {
                    [IO.File]::WriteAllText((Join-Path $mod 'cmd.txt'), $perfEval)
                    Note 'recorder.txt' 'asked the mod for PERF session lines'
                } else {
                    Note 'recorder.txt' '-Perf needs eval, and this install has no dev.txt: no FPS in this recording'
                }
            }
            if ((Get-Date) -ge $nextCopy) {
                $nextCopy = (Get-Date).AddSeconds(10)
                Copy-Item (Join-Path $ue4ss 'UE4SS.log') (Join-Path $folder "UE4SS-$stamp.log") -Force
                foreach ($f in 'relay_log.txt', 'relay_error.txt') { Copy-Item (Join-Path $mod $f) (Join-Path $folder "$stamp-$f") -Force }
            }
            if ((Get-Date) -ge $nextPing -and (Test-Path $tailscale) -and $statusLine -match 'peer=(\d+\.\d+\.\d+\.\d+)') {
                $nextPing = (Get-Date).AddSeconds(30)
                $peer = $Matches[1]
                Note 'tailscale.log' ("ping: " + ((& $tailscale ping --c 1 --timeout 3s $peer 2>&1 | ForEach-Object { "$_".Trim() } | Where-Object { $_ }) -join ' | '))
                Note 'tailscale.log' ("status: " + ((& $tailscale status 2>&1 | Where-Object { "$_" -match [regex]::Escape($peer) } | ForEach-Object { "$_".Trim() }) -join ' | '))
            }
        } elseif ($seenAt -and ((Get-Date) - $seenAt).TotalMinutes -ge $GoneMinutes) {
            break
        }
        if ($ue4ss) {
            # The final copy after a crash or quit, and the crash dump, kept even if the game is gone.
            Get-ChildItem $ue4ss -Filter *.dmp | Where-Object { $_.LastWriteTime -gt $began -and -not (Test-Path (Join-Path $folder $_.Name)) } | ForEach-Object {
                Copy-Item $_.FullName $folder
                Note 'recorder.txt' "crash dump: $($_.Name)"
            }
            if (-not $game -and $stamp) {
                Copy-Item (Join-Path $ue4ss 'UE4SS.log') (Join-Path $folder "UE4SS-$stamp.log") -Force
                foreach ($f in 'relay_log.txt', 'relay_error.txt') { Copy-Item (Join-Path $mod $f) (Join-Path $folder "$stamp-$f") -Force }
                $stamp = $null
            }
        }
        # Twice a second, so no status line is missed (they come once a second).
        Start-Sleep -Milliseconds 500
    }
} finally {
    Note 'recorder.txt' 'stopped'
    try { Write-Summary $folder } catch { Note 'recorder.txt' "no summary: $_" }
}
