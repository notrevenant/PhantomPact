# Gets an already-running copy (my D:\SteamLibrary one) from the main menu into gameplay: RETURN until the mod sees a pawn.
. "C:\Users\TheCo\Downloads\Coop Mode - Onimusha Way of the Sword\tools\game-driver.ps1" -GameWin64 'D:\SteamLibrary\steamapps\common\PBZ\platform\steam' -ProcessName 'PBZ'
$p = Get-Process PBZ -ErrorAction SilentlyContinue | Where-Object { $_.Path -like 'D:\SteamLibrary\*' } | Select-Object -First 1
if (-not $p) { "NO GAME PROCESS"; exit 1 }
Select-GameInstance -ProcessId $p.Id -Instance 1
"pid $($p.Id) window $(Get-GameWindow) at $(Get-Date -Format HH:mm:ss)"
$pawn = $false
for ($k = 0; $k -lt 14 -and -not $pawn; $k++) {
    $t = Get-Date
    Send-ModCommand 'eval local _,p=PBZ.getPlayer1() return "pawn="..tostring(p~=nil)'
    Start-Sleep 3
    $pawn = [bool](Get-ModLog -Since $t -Last 100 | Where-Object { $_ -match 'pawn=true' })
    if (-not $pawn) {
        if ((Get-GameWindow) -eq [IntPtr]::Zero) { "no window yet"; Start-Sleep 10; continue }
        Show-Game; Start-Sleep -Milliseconds 500; Send-GameKey RETURN; Start-Sleep 12
    }
}
"gameplay: $pawn at $(Get-Date -Format HH:mm:ss)"
Get-ModLog -Since $p.StartTime -Last 80 | Where-Object { $_ -notmatch 'METER' -and $_ -notmatch '\] > ' } | ForEach-Object { $_ -replace '^\[[^\]]*\] \[Lua\] ', '' }
"DONE"
