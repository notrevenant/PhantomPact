<#
.SYNOPSIS
    The relay as separate processes over real sockets, no game needed: one side going away and coming back, Secrets, an old
    partner, garbage, and the sure lane through a bad connection. What relay_cli test can't show from inside one process.
    Ends with a line saying how many checks failed, and exit code 1 if any did.

.EXAMPLE
    .\tools\netlab\restart-test.ps1
    .\tools\netlab\restart-test.ps1 -Cli C:\somewhere\relay_cli.exe -Port 48100
#>
param([int]$Port = 47830, [string]$Cli = '')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$cli = if ($Cli) { $Cli } else { Join-Path $root 'native\build\relay_cli.exe' }
$work = Join-Path $env:TEMP "pp-restart-$PID"
New-Item -ItemType Directory -Force "$work\h", "$work\c" | Out-Null
$failed = 0
$all = [System.Collections.ArrayList]::new()

function Check([bool]$ok, [string]$what) {
    if ($ok) { "  ok   $what" } else { "  FAIL $what"; $script:failed++ }
}

function Bot($role, $seconds, $out, [string[]]$more = @(), $port = $Port) {
    $a = @('bot', $role, '--port', $port, '--dir', "$work\$($role[0])", '--seconds', $seconds) + $more
    $p = Start-Process $cli -ArgumentList $a -PassThru -WindowStyle Hidden -RedirectStandardOutput "$work\$out"
    [void]$p.Handle      # keeps the exit code and CPU time readable after it ends
    [void]$all.Add($p)
    $p
}

function Netem($front, $back, $loss, $seconds) {
    $a = @('netem', $front, $back, '--delay', 15, '--jitter', 10, '--loss', $loss, '--seconds', $seconds)
    $p = Start-Process $cli -ArgumentList $a -PassThru -WindowStyle Hidden -RedirectStandardOutput "$work\netem-$loss.txt"
    [void]$all.Add($p)
    $p
}

function Field($file, $key) {
    $line = Get-Content "$work\$file" -ErrorAction SilentlyContinue | Where-Object { $_ -match "^(role=|sure_lane )" -and $_ -match "\b$key=" } | Select-Object -Last 1
    if ($line -match "\b$key=(\S+)") { $Matches[1] } else { '' }
}

function SendUdp($port, [byte[][]]$packets) {
    $u = New-Object System.Net.Sockets.UdpClient
    foreach ($p in $packets) {
        [byte[]]$bytes = @()                    # typed: an empty array that passes through a block comes out as nothing
        if ($null -ne $p) { $bytes = $p }
        [void]$u.Send($bytes, $bytes.Length, '127.0.0.1', $port)
    }
    $u.Close()
}

function Text([string]$s) { [Text.Encoding]::ASCII.GetBytes($s) }

function SureThrough($loss, $base, [string[]]$more, $label) {
    $n = Netem ($base + 1) $base $loss 24
    $h = Bot 'host' 10 "sure-h-$loss.txt" (@('--event-every', 0.02, '--events-for', 7) + $more) $base
    Start-Sleep -Milliseconds 300
    $c = Bot 'client' 10 "sure-c-$loss.txt" (@('--event-every', 0.02, '--events-for', 7) + $more) ($base + 1)
    [void]$c.WaitForExit(16000)
    [void]$h.WaitForExit(6000)
    [void]$n.WaitForExit(14000)
    if (-not $n.HasExited) { Stop-Process -Id $n.Id -Force -Confirm:$false }
    # Numbers restart per direction. What was sent before the partner was heard is dropped by design (SureSender::forget).
    foreach ($pair in @(@("sure-h-$loss.txt", "sure-c-$loss.txt", 'host to guest'), @("sure-c-$loss.txt", "sure-h-$loss.txt", 'guest to host'))) {
        $sent = [int](Field $pair[0] 'sent'); $got = [int](Field $pair[1] 'got'); $wrong = Field $pair[1] 'wrong_order'
        Check ($got -gt 0 -and $got -ge $sent - 150 -and $wrong -eq '0') "$label, $($pair[2]): $got of $sent arrived, $wrong out of order"
    }
}

'== the host leaves and comes back'
$c = Bot 'client' 16 'c1.txt' @('--event-every', 0.05)
$h1 = Bot 'host' 6 'h1.txt' @('--event-every', 0.05)
Start-Sleep -Seconds 10
$h2 = Bot 'host' 7 'h2.txt' @('--event-every', 0.05)
[void]$c.WaitForExit(24000)
[void]$h1.WaitForExit(2000)
[void]$h2.WaitForExit(8000)
Check ((Field 'c1.txt' 'connected') -eq 'yes') 'the guest is connected again at the end'
Check ([int](Field 'c1.txt' 'restarts') -ge 2) "the guest's game was told of the new host ($(Field 'c1.txt' 'restarts') S events)"
Check ((Field 'c1.txt' 'wrong_order') -eq '0') 'its events stayed in order through all of it'
Check ([int](Field 'h2.txt' 'got') -gt 50) "the new host hears the guest ($(Field 'h2.txt' 'got') events)"

'== the guest leaves and comes back, on a new port'
$h = Bot 'host' 16 'h5.txt' @('--event-every', 0.05)
$c1 = Bot 'client' 5 'c5.txt' @('--event-every', 0.05)
Start-Sleep -Seconds 8
$c2 = Bot 'client' 6 'c6.txt' @('--event-every', 0.05)
[void]$h.WaitForExit(22000)
[void]$c1.WaitForExit(2000)
[void]$c2.WaitForExit(6000)
Check ((Field 'h5.txt' 'connected') -eq 'yes') 'the host takes the new guest'
Check ((Field 'h5.txt' 'wrong_order') -eq '0') 'events stayed in order on the host'
Check ([int](Field 'c6.txt' 'got') -gt 50) "the new guest hears the host ($(Field 'c6.txt' 'got') events)"

'== the same Secret on both'
Set-Content "$work\secret.ini" 'Secret = four random words here' -Encoding ascii
Set-Content "$work\other.ini" 'Secret = another four words here' -Encoding ascii
$h = Bot 'host' 6 'h3.txt' @('--ini', "$work\secret.ini")
Start-Sleep -Milliseconds 600
$c = Bot 'client' 5 'c3.txt' @('--ini', "$work\secret.ini")
[void]$c.WaitForExit(12000)
[void]$h.WaitForExit(5000)
Check ((Field 'c3.txt' 'connected') -eq 'yes' -and (Field 'c3.txt' 'auth') -eq 'on') 'they connect, signed'
Check ([int](Field 'c3.txt' 'got') -gt 10 -and (Field 'c3.txt' 'wrong_order') -eq '0') "events flow ($(Field 'c3.txt' 'got'))"

'== different Secrets, and a Secret on one side'
$h = Bot 'host' 5 'h4.txt' @('--ini', "$work\secret.ini")
Start-Sleep -Milliseconds 600
$c = Bot 'client' 3 'c4.txt' @('--ini', "$work\other.ini")
[void]$c.WaitForExit(9000)
[void]$h.WaitForExit(5000)
Check ((Field 'h4.txt' 'connected') -eq 'no' -and (Field 'h4.txt' 'rejected') -ne '0') "different Secrets never connect ($(Field 'h4.txt' 'rejected') refused)"
Check ((Field 'c4.txt' 'got') -eq '0') 'and the guest heard nothing'
$h = Bot 'host' 5 'h7.txt' @('--ini', "$work\secret.ini")
Start-Sleep -Milliseconds 600
$c = Bot 'client' 3 'c7.txt'
[void]$c.WaitForExit(9000)
[void]$h.WaitForExit(5000)
Check ((Field 'h7.txt' 'connected') -eq 'no' -and (Field 'h7.txt' 'rejected') -ne '0') 'a Secret on the host alone never connects'

'== an old partner, garbage, and then the real one'
$p = $Port + 5
$h = Bot 'host' 11 'h8.txt' @() $p
Start-Sleep -Milliseconds 500
SendUdp $p @(, (Text '{"v":2,"t":"state","s":"P 1 0 0 0 0 0 0"}'))
Start-Sleep -Milliseconds 1300
$seen = Get-Content "$work\h\net_status.txt" -ErrorAction SilentlyContinue
Check ($seen -match 'partner_version=1\.4\.1-or-older') 'a 1.4.1 JSON packet shows as an old partner'
$bad = [System.Collections.Generic.List[byte[]]]::new()
foreach ($t in @('', '{', 'PPA1', 'null', '[]', '12', '{"v":2}', '{"v":3,"t":"ping"}')) { $bad.Add((Text $t)) }
$bad.Add((Text ('[' * 60000)))
$bad.Add((Text ('PPA1' + ('x' * 80))))
$bad.Add([byte[]](@(0xFF) * 100))
$bad.Add([byte[]](@(0xA3)))
$bad.Add([byte[]](@(0xA3, 3)))
$bad.Add([byte[]](@(0xA3, 9) + (@(0) * 40)))
$rng = New-Object System.Random 7
for ($i = 0; $i -lt 3000; $i++) {
    $b = New-Object byte[] ($rng.Next(1, 1300))
    $rng.NextBytes($b)
    if ($i % 2) { $b[0] = 0xA3; if ($b.Length -gt 1) { $b[1] = 3 } }
    $bad.Add($b)
}
SendUdp $p $bad.ToArray()
Start-Sleep -Milliseconds 300
Check (-not $h.HasExited) "$($bad.Count) bad packets didn't stop the relay"
# Garbage with the right marker can pin the host for PEER_TIMEOUT, so the partner may need that long.
$c = Bot 'client' 5 'c8.txt' @() $p
[void]$c.WaitForExit(12000)
[void]$h.WaitForExit(9000)
Check ((Field 'c8.txt' 'connected') -eq 'yes') 'and the real partner still connects'
Check ([int](Field 'c8.txt' 'got') -gt 0) "and hears events ($(Field 'c8.txt' 'got'))"

'== the sure lane through a bad connection, both ways at once'
SureThrough 5 ($Port + 10) @() '5% loss'
SureThrough 30 ($Port + 12) @() '30% loss'
SureThrough 31 ($Port + 14) @('--burst', 500, '--event-bytes', 900) '30% loss with a burst of 500 of the longest events'

'== nothing to do costs nothing'
$h = Bot 'host' 5 'h9.txt' @() ($Port + 20)
Start-Sleep -Milliseconds 300
$c = Bot 'client' 5 'c9.txt' @() ($Port + 20)
Start-Sleep -Seconds 4
$cpu = [math]::Round($h.TotalProcessorTime.TotalSeconds, 2)
Check ($cpu -lt 1.5) "a relay and a 60 FPS bot use $cpu s of CPU in 4.3 s, not a whole core"
[void]$c.WaitForExit(8000)
[void]$h.WaitForExit(6000)

'== a port that is in use'
$u = New-Object System.Net.Sockets.UdpClient
$u.Client.ExclusiveAddressUse = $true
$u.Client.Bind((New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Loopback), ($Port + 21)))
$h = Bot 'host' 1 'h10.txt' @() ($Port + 21)
[void]$h.WaitForExit(8000)
$u.Close()
$error_text = Get-Content "$work\h\relay_error.txt" -ErrorAction SilentlyContinue
Check ($error_text -match 'in use') 'the bot reports it instead of failing silently'

foreach ($p in $all) { if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -Confirm:$false } }
Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
if ($failed) { "restart-test: $failed FAILED"; exit 1 }
'restart-test: all passed'
exit 0
