# Helpers for the story tour on the two running copies. Dot-source it.
. (Join-Path $PSScriptRoot '..\dev.ps1')
$script:H = Get-Content "C:\Users\TheCo\Downloads\PhantomPact-online\tools\netlab\bench\dev-host.json" -Raw | ConvertFrom-Json
$script:C = Get-Content "C:\Users\TheCo\Downloads\PhantomPact-online\tools\netlab\bench\dev-guest.json" -Raw | ConvertFrom-Json
$script:H.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop'
$script:C.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop\inst2'
$script:Log = 'C:\PBZDev\platform\steam\ue4ss\UE4SS.log'

function Read-LogFrom([long]$Offset) {
    $fs = [IO.File]::Open($script:Log, 'Open', 'Read', 'ReadWrite, Delete')
    try {
        [void]$fs.Seek($Offset, 'Begin')
        $text = (New-Object IO.StreamReader $fs).ReadToEnd()
        return @{ Text = $text; Offset = $fs.Length }
    } finally { $fs.Dispose() }
}
function Log-End { (Get-Item $script:Log).Length }
function Alive($g) { [bool](Get-Process -Id $g.Pid -ErrorAction SilentlyContinue) }
function Tag($g) { if ($g.Instance -eq 1) { '[PBZCoop]' } else { '[PBZCoop#2]' } }

# Runs Lua on one copy and returns what it returned, or $null if nothing came back in time.
function Ask($g, [string]$Lua, [double]$Timeout = 4) {
    $from = Log-End
    Send-Dev $g "eval $Lua"
    $deadline = (Get-Date).AddSeconds($Timeout)
    $tag = [regex]::Escape((Tag $g))
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 150
        $r = Read-LogFrom $from
        foreach ($line in ($r.Text -split "`r?`n")) {
            if ($line -match "$tag eval ok: (.*)$") { return $Matches[1] }
            if ($line -match "$tag eval (error|compile)[^:]*: (.*)$") { return "ERROR " + $Matches[2] }
        }
    }
    return $null
}

# Waits until a copy has a player again after a load.
function Wait-Player($g, [double]$Timeout = 180) {
    $deadline = (Get-Date).AddSeconds($Timeout)
    while ((Get-Date) -lt $deadline) {
        if (-not (Alive $g)) { return "EXITED" }
        $a = Ask $g 'local _,p=PBZ.getPlayer1() return "pawn="..tostring(PBZ.valid(p))' 3
        if ($a -eq 'pawn=true') { return "ready" }
        Start-Sleep -Seconds 2
    }
    return "TIMEOUT"
}

function Lines($from, [string]$Match) {
    $r = Read-LogFrom $from
    ($r.Text -split "`r?`n") | Where-Object { $_ -match $Match } | ForEach-Object { $_ -replace '^\[\d{4}-\d\d-\d\d (\S+)\] \[Lua\] ', '$1 ' }
}
