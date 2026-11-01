# Launches one copy of PBZ with the mod (Role = Local), gets it into gameplay (CONTINUE), prints a done marker.
$ErrorActionPreference = 'Continue'
$GameWin64 = 'D:\SteamLibrary\steamapps\common\PBZ\platform\steam'
. "C:\Users\TheCo\Downloads\Coop Mode - Onimusha Way of the Sword\tools\game-driver.ps1" -GameWin64 $GameWin64 -ProcessName 'PBZ'
Get-Process PBZ -ErrorAction SilentlyContinue | Where-Object { $_.Path -like 'D:\SteamLibrary\*' } | Stop-Process -Force
Start-Sleep 3
$exe = Join-Path $GameWin64 'PBZ.exe'
$gameRoot = 'D:\SteamLibrary\steamapps\common\PBZ'
$exeArgs = @('ProjectPBZ', "-basedir=`"$gameRoot\ProjectPBZ\Binaries\Win64`"", '-pc-platform=Steam', '-allowmultipleinstances')
$p = Start-Process -FilePath $exe -ArgumentList $exeArgs -WorkingDirectory $GameWin64 -PassThru
"started pid $($p.Id) at $(Get-Date -Format HH:mm:ss)"
$deadline = (Get-Date).AddSeconds(120)
do { Start-Sleep 2; $alive = Get-Process -Id $p.Id -ErrorAction SilentlyContinue } until ((-not $alive) -or ($alive.MainWindowHandle -ne 0) -or ((Get-Date) -gt $deadline))
if (-not $alive) { "EXITED early"; exit 1 }
Select-GameInstance -ProcessId $p.Id -Instance 1
"window up at $(Get-Date -Format HH:mm:ss); waiting for the mod"
Start-Sleep 25
$pawn = $false
for ($k = 0; $k -lt 14 -and -not $pawn; $k++) {
    $t = Get-Date
    Send-ModCommand 'eval local _,p=PBZ.getPlayer1() return "pawn="..tostring(p~=nil)'
    Start-Sleep 3
    $pawn = [bool](Get-ModLog -Since $t -Last 100 | Where-Object { $_ -match 'pawn=true' })
    if (-not $pawn) { Show-Game; Start-Sleep -Milliseconds 500; Send-GameKey RETURN; Start-Sleep 12 }
}
"gameplay: $pawn at $(Get-Date -Format HH:mm:ss)"
Get-ModLog -Since $p.StartTime -Last 60 | Where-Object { $_ -notmatch 'METER' -and $_ -notmatch '\] > ' } | ForEach-Object { $_ -replace '^\[[^\]]*\] \[Lua\] ', '' }
"DONE"
