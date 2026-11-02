# Follows a boss fight from both sides: one line every few seconds, plus what the mod says about it.
param([int]$Seconds = 60, [int]$Every = 4)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
$from = Log-End
$look = 'local n=REAL.near() local b=FIGHT.bars() local g=REAL.ghost() local c=tostring(PBZ.game.inCutscene()) local l=select(2,PBZ.getPlayer1()):K2_GetActorLocation() return string.format("%.0f,%.0f %s bars %s cut %s %s", l.X, l.Y, n:gsub("BP_Monster_",""), b, c, g:gsub("ghost valid=true ",""))'
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end) {
    if (-not (Alive $H) -or -not (Alive $C)) { 'A COPY IS GONE'; break }
    $t = (Get-Date).ToString('HH:mm:ss')
    "$t H " + (Ask $H $look 3)
    "$t G " + (Ask $C $look 3)
    Start-Sleep -Seconds $Every
}
'--- mod log'
Lines $from 'oss|died|Killing|Spawned|Joining|Host said|Host says|arrive|not matched|healed|rror' | Where-Object { $_ -notmatch 'eval|WALK' } | Select-Object -Last 24 | ForEach-Object { if ($_.Length -gt 130) { $_.Substring(0, 130) } else { $_ } }
