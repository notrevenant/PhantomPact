<#
.SYNOPSIS
    Blood Pact-style self-test for PBZCoop: two copies of the game on this PC. Copy 1 = host (mod folder), copy 2 = client
    (mod folder\inst2). Each copy gets PBZCOOP_INSTANCE and a PhantomPact.ini for its role, so each mod starts the relay
    in its main.dll by itself and turns co-op on once it's in gameplay.

.PARAMETER Stop
    Close the game copies this script started (read from the last run's state file) and put PhantomPact.ini back.
.PARAMETER Connect
    Udp: over this PC's loopback (ThisPcOnly), so Windows' firewall has nothing to ask. Steam: through Steam, where one
    account can't reach itself, so the relays start but never connect (steam-check.ps1).
.PARAMETER Exe
    Override the game exe (normally found from the Steam manifest, like pbz-setup.ps1).

.EXAMPLE
    .\tools\pbz-selftest.ps1
    .\tools\pbz-selftest.ps1 -Stop
#>
param(
    [switch]$Stop,
    [ValidateSet('Udp', 'Steam')][string]$Connect = 'Udp',
    [string]$Exe,
    [string]$SteamLibrary = 'D:\SteamLibrary',
    [int]$SteamAppId = 4115450,
    [int]$Port = 47800,
    [int]$WindowTimeoutSec = 90
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$logsRoot = Join-Path $projectRoot 'logs'
$statePath = Join-Path $logsRoot 'selftest-last.json'
$iniKept = Join-Path $logsRoot 'selftest-PhantomPact.ini'    # the ini as it was, until -Stop puts it back

if ($Stop) {
    if (-not (Test-Path $statePath)) { Write-Output "No self-test state found."; return }
    $state = Get-Content $statePath -Raw | ConvertFrom-Json
    foreach ($id in (@($state.Games) | Where-Object { $_ -is [int] -or $_ -is [long] })) {
        $p = Get-Process -Id $id -ErrorAction SilentlyContinue
        # After a reboot the same PID can belong to something else.
        if ($p -and $p.ProcessName -eq [IO.Path]::GetFileNameWithoutExtension($state.Exe)) { Stop-Process -Id $id -Force; Write-Output "Stopped $($p.ProcessName) ($id)" }
    }
    # Back to the settings from before the run, so a normal game start doesn't auto-host.
    if ($state.ModRoot) {
        if (Test-Path $iniKept) { Move-Item $iniKept (Join-Path $state.ModRoot 'PhantomPact.ini') -Force }
        Remove-Item (Join-Path $state.ModRoot 'inst2\PhantomPact.ini') -ErrorAction SilentlyContinue
    }
    return
}

# Find the game (same lookup as pbz-setup.ps1: PBZ's real game is platform\steam\PBZ.exe, steam\PBZ.exe is a launcher).
$manifest = Join-Path $SteamLibrary "steamapps\appmanifest_$SteamAppId.acf"
$installDir = [regex]::Match((Get-Content $manifest -Raw), '"installdir"\s+"([^"]+)"').Groups[1].Value
$gameRoot = Join-Path $SteamLibrary "steamapps\common\$installDir"
if (-not $Exe) {
    $found = Get-ChildItem $gameRoot -Recurse -Filter '*-Win64-Shipping.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $found) {
        $found = Get-ChildItem (Join-Path $gameRoot 'platform') -Recurse -Filter '*.exe' -ErrorAction SilentlyContinue |
            Sort-Object Length -Descending | Select-Object -First 1
    }
    if (-not $found) { throw "Game exe not found. Has PBZ unlocked and installed?" }
    $Exe = $found.FullName
}
$win64 = Split-Path $Exe -Parent
$procName = [IO.Path]::GetFileNameWithoutExtension($Exe)
$modRoot = Join-Path $win64 'ue4ss\Mods\PBZCoop'
$inst2 = Join-Path $modRoot 'inst2'
if (-not (Test-Path (Join-Path $modRoot 'enabled.txt'))) { throw "PBZCoop isn't installed in $win64 (run pbz-setup.ps1 first)." }
if (-not (Test-Path (Join-Path $modRoot 'dlls\main.dll'))) { throw "No relay in $modRoot (run tools\build-native.ps1, then tools\install-mod.ps1)." }
New-Item -ItemType Directory -Force $inst2, $logsRoot | Out-Null

# Both copies use the same save folder, so back it up before every run.
$project = (Get-ChildItem $gameRoot -Directory | Where-Object { $_.Name -ne 'Engine' -and (Test-Path (Join-Path $_.FullName 'Content\Paks')) } | Select-Object -First 1).Name
if ([string]::IsNullOrEmpty($project)) { throw "No game project folder (one with Content\Paks) in $gameRoot. Is PBZ fully installed?" }
# PBZ keeps saves in the game folder (<game>\ProjectPBZ\Saved\SaveGames); most UE games use %LOCALAPPDATA%.
$saves = @((Join-Path $gameRoot "$project\Saved\SaveGames"), (Join-Path $env:LOCALAPPDATA "$project\Saved\SaveGames")) |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if ($saves) {
    $bk = Join-Path (Split-Path $SteamLibrary -Qualifier) "\PBZSaveBackup\selftest-$(Get-Date -Format yyyyMMdd-HHmmss)"
    New-Item -ItemType Directory -Force $bk | Out-Null
    Copy-Item "$saves\*" $bk -Recurse
    Write-Output "Saves backed up to $bk"
} else {
    Write-Warning "No SaveGames folder found; check where PBZ saves before letting two copies run for long."
}

# Each mod reads its ini as it loads. A run that failed before its -Stop already kept the real one: that one stays.
$ini1, $ini2 = (Join-Path $modRoot 'PhantomPact.ini'), (Join-Path $inst2 'PhantomPact.ini')
if ((Test-Path $ini1) -and -not (Test-Path $iniKept)) { Copy-Item $ini1 $iniKept }
if ($Connect -eq 'Steam') {
    Set-Content $ini1 "Role = Host`r`nConnect = Steam" -Encoding ascii
    Set-Content $ini2 "Role = Guest`r`nConnect = Steam" -Encoding ascii
} else {
    Set-Content $ini1 "Role = Host`r`nPort = $Port`r`nThisPcOnly = On" -Encoding ascii
    Set-Content $ini2 "Role = Guest`r`nHostAddress = 127.0.0.1`r`nPort = $Port`r`nThisPcOnly = On" -Encoding ascii
}
# An earlier run's status would read as connected.
Remove-Item (Join-Path $modRoot 'net_status.txt'), (Join-Path $inst2 'net_status.txt') -ErrorAction SilentlyContinue

function Save-State($Games) {
    @{ Games = $Games; Exe = $Exe; ModRoot = $modRoot } | ConvertTo-Json | Set-Content $statePath -Encoding utf8
}

function Start-Copy([int]$instance) {
    $before = @(Get-Process -Name $procName -ErrorAction SilentlyContinue | ForEach-Object Id)
    $env:PBZCOOP_INSTANCE = "$instance"
    # Same arguments PBZ's launcher (steam\PBZ.exe) passes to the real game. Without steam_appid.txt next to the
    # exe, the game restarts itself through Steam and PBZCOOP_INSTANCE is lost.
    # -allowmultipleinstances is PBZ's own switch for its "already running on this machine" check (its log says
    # "Pass -allowmultipleinstances to override"); without it the second copy exits.
    $exeArgs = @($project, "-basedir=`"$(Join-Path $gameRoot "$project\Binaries\Win64")`"", '-pc-platform=Steam', '-allowmultipleinstances')
    $p = Start-Process -FilePath $Exe -ArgumentList $exeArgs -WorkingDirectory $win64 -PassThru
    Remove-Item Env:\PBZCOOP_INSTANCE
    $deadline = (Get-Date).AddSeconds($WindowTimeoutSec)
    do {
        Start-Sleep -Seconds 2
        $alive = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
        $new = Get-Process -Name $procName -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.Id }
    } until (($alive -and $alive.MainWindowHandle -ne 0) -or (-not $alive) -or (Get-Date) -gt $deadline)
    if ($alive -and $alive.MainWindowHandle -ne 0) { return $p.Id }
    if (-not $alive -and $new) {
        Write-Warning "Copy $instance exited and another process ($($new.Id -join ',')) appeared: the game probably relaunched itself through Steam, which drops PBZCOOP_INSTANCE."
    } elseif (-not $alive) {
        Write-Warning "Copy $instance exited on its own (exit code $($p.ExitCode))."
    } else {
        Write-Warning "Copy $instance has no window after $WindowTimeoutSec s."
    }
    return 0
}

Save-State @()    # so -Stop can undo a run that fails below

Write-Output "Starting copy 1 (host)..."
$pid1 = Start-Copy 1
if (-not $pid1) { throw "Copy 1 didn't start; see the warning above." }
Save-State @($pid1)
Write-Output "Starting copy 2 (client)..."
$pid2 = Start-Copy 2
if (-not $pid2) { Write-Warning "PBZ won't run a second copy this way." }
Save-State (@($pid1, $pid2) | Where-Object { $_ -gt 0 })

Write-Output "`nCopy 1 (host)   PID $pid1   files: $modRoot"
Write-Output "Copy 2 (client) PID $pid2   files: $inst2"
Write-Output "`nLoad a save in both copies: co-op turns on by itself. Drive them with:"
Write-Output ". .\tools\game-driver.ps1 -GameWin64 '$win64' -ProcessName '$procName'"
Write-Output "Select-GameInstance -ProcessId $pid1 -Instance 1; Send-ModCommand netstatus"
if ($pid2) { Write-Output "Select-GameInstance -ProcessId $pid2 -Instance 2; Send-ModCommand netstatus" }
Write-Output "Stop everything: .\tools\pbz-selftest.ps1 -Stop"
