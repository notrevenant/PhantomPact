<#
.SYNOPSIS
    The last check before a release: two real copies through a bad connection, walking and fighting for some minutes. Ends
    with the error count, crash dumps, memory at the start and the end, and the link's numbers. Take the bench first; it
    starts its own copies, so close others.

.EXAMPLE
    .\tools\netlab\bench\soak.ps1 -Minutes 5
#>
param([int]$Minutes = 5, [string]$Via = '--delay 75 --jitter 15 --loss 5')
. (Join-Path $PSScriptRoot '..\dev.ps1')
$lab = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path -replace '\\', '/'
$cli = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\native\build\relay_cli.exe')).Path
$ue = 'C:\PBZDev\platform\steam\ue4ss'
$began = Get-Date
"mod hash " + (Install-DevMod)
$dumps = @(Get-ChildItem $ue -Filter 'crash_*.dmp' -ErrorAction SilentlyContinue).Count
$netem = Start-Process $cli -ArgumentList (@('netem', 47811, 47810, '--seconds', ($Minutes * 60 + 400)) + ($Via -split ' ')) -PassThru -WindowStyle Hidden
$h = Start-DevGame -Role Host
Start-Sleep -Seconds 3
$c = Start-DevGame -Role Guest -Instance 2 -Port 47811
$h | ConvertTo-Json | Set-Content "$PSScriptRoot\dev-host.json"
$c | ConvertTo-Json | Set-Content "$PSScriptRoot\dev-guest.json"
"host $($h.Pid), guest $($c.Pid), started $(Get-Date -Format HH:mm:ss)"
$okH = Wait-DevGameplay $h 200
$okC = Wait-DevGameplay $c 200
"gameplay: host $okH, guest $okC at $(Get-Date -Format HH:mm:ss)"
$load = "dofile(`"$lab/perf.lua`") dofile(`"$lab/pair.lua`")"
Send-Dev $h "eval $load PERF.crowd() return 1"
Send-Dev $c "eval $load PERF.crowd() return 1"
Start-Sleep -Seconds 14
$land = 'eval local _,p=PBZ.getPlayer1() p.CharacterMovement:SetMovementMode(1,0) PBZ.game.setMinHealth(p,1) return 1'
Send-Dev $h $land; Send-Dev $c $land
Start-Sleep -Seconds 3
function Mem { (Get-Process -Id $h.Pid, $c.Pid -ErrorAction SilentlyContinue | ForEach-Object { "$($_.Id) $([int]($_.WorkingSet64 / 1MB)) MB" }) -join ', ' }
"memory at the start: $(Mem)"
$soakStart = Get-Date
$stop = $soakStart.AddMinutes($Minutes)
$round = 0
while ((Get-Date) -lt $stop) {
    if (-not (Get-Process -Id $h.Pid -ErrorAction SilentlyContinue)) { 'THE HOST COPY IS GONE'; break }
    if (-not (Get-Process -Id $c.Pid -ErrorAction SilentlyContinue)) { 'THE GUEST COPY IS GONE'; break }
    $round++
    Send-Dev $h 'eval PAIR.walk(14, 400) PAIR.swing(14) return 1'
    Start-Sleep -Seconds 2
    Send-Dev $c 'eval PAIR.walk(14, 400) PAIR.swing(14) return 1'
    Start-Sleep -Seconds 14
    Send-Dev $h 'eval local e=PAIR.nearest() if e then PAIR.hurt(0.2) end return 1'
    Start-Sleep -Seconds 1
    Send-Dev $c 'eval local e=PAIR.nearest() if e then PAIR.hurt(0.2) end return 1'
    Start-Sleep -Seconds 3
}
"$round rounds; memory at the end: $(Mem)"
Send-Dev $h 'netstatus'; Send-Dev $c 'netstatus'
Start-Sleep -Seconds 2
$log = Get-DevLog $h $soakStart 'net error|event .* error|eval error|attempt to|stack traceback'
"errors in the log: $(@($log).Count)"
$log | Select-Object -Last 12 | ForEach-Object { if ($_.Length -gt 220) { $_.Substring(0, 220) } else { $_ } }
"new crash dumps: $(@(Get-ChildItem $ue -Filter 'crash_*.dmp' -ErrorAction SilentlyContinue).Count - $dumps)"
Get-DevLog $h $soakStart 'Relay:|No packet|Lost the|Ghost hidden' | Select-Object -Last 10 | ForEach-Object { $_ -replace '^\[\d{4}-\d\d-\d\d (\S+)\] \[Lua\] ', '$1 ' } | ForEach-Object { if ($_.Length -gt 300) { $_.Substring(0, 300) } else { $_ } }
if (-not $netem.HasExited) { Stop-Process -Id $netem.Id -Force -Confirm:$false }
'DONE'
