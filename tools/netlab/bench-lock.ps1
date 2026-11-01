<#
.SYNOPSIS
    One team at a time on the game copies: this PC's memory holds two copies, no more. Take the bench before starting any
    game copy, and give it back when done. Giving it back closes every copy running from the dev install.

.EXAMPLE
    .\tools\netlab\bench-lock.ps1 -Take ghost       # waits for its turn
    .\tools\netlab\bench-lock.ps1 -Give
    .\tools\netlab\bench-lock.ps1 -Who
#>
param([string]$Take, [switch]$Give, [switch]$Keep, [switch]$Who, [int]$WaitMinutes = 40, [int]$StaleMinutes = 15)
$lock = 'C:\PBZDev\bench.lock'
$note = Join-Path $lock 'owner.txt'

function Close-Copies {
    Get-Process PBZ -ErrorAction SilentlyContinue | Where-Object { $_.Path -like 'C:\PBZDev\*' } | Stop-Process -Force -Confirm:$false
}

if ($Who) {
    if (Test-Path $note) { Get-Content $note } else { 'free' }
    return
}
if ($Give) {
    if (-not $Keep) { Close-Copies }     # -Keep: the next team goes on with the same running copies
    Remove-Item $note -ErrorAction SilentlyContinue
    if (Test-Path $lock) { [IO.Directory]::Delete($lock) }
    'bench free'
    return
}
if (-not $Take) { throw 'Use -Take <name>, -Give or -Who.' }
$deadline = (Get-Date).AddMinutes($WaitMinutes)
while ($true) {
    try {
        New-Item -ItemType Directory -Path $lock -ErrorAction Stop | Out-Null
        "$Take since $(Get-Date -Format HH:mm:ss)" | Set-Content $note
        "bench is yours, $Take. Give it back within $StaleMinutes minutes."
        return
    } catch {
        $age = if (Test-Path $note) { ((Get-Date) - (Get-Item $note).LastWriteTime).TotalMinutes } else { 0 }
        if ($age -gt $StaleMinutes) {
            "taking the bench over from: $(Get-Content $note -ErrorAction SilentlyContinue)"
            Close-Copies
            Remove-Item $note -ErrorAction SilentlyContinue
            [IO.Directory]::Delete($lock)
            continue
        }
        if ((Get-Date) -gt $deadline) { throw "The bench stayed busy for $WaitMinutes minutes: $(Get-Content $note -ErrorAction SilentlyContinue)" }
        Start-Sleep -Seconds 5
    }
}
