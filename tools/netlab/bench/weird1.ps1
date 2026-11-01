. (Join-Path $PSScriptRoot '..\dev.ps1')
$h = Get-Content "$PSScriptRoot\dev-host.json" -Raw | ConvertFrom-Json
$c = Get-Content "$PSScriptRoot\dev-guest.json" -Raw | ConvertFrom-Json
$h.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop'
$c.Dir = 'C:\PBZDev\platform\steam\ue4ss\Mods\PBZCoop\inst2'
$lab = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path -replace '\\', '/'
$t = Get-Date
function Show($since, $match) {
    Get-DevLog $h $since $match | Where-Object { $_ -notmatch '\] > ' } | ForEach-Object { $_ -replace '^\[\d{4}-\d\d-\d\d (\S+)\] \[Lua\] ', '$1 ' } | ForEach-Object { if ($_.Length -gt 210) { $_.Substring(0, 210) } else { $_ } }
}
$load = "dofile(`"$lab/perf.lua`") dofile(`"$lab/pair.lua`")"
Send-Dev $h "eval $load return 1"; Send-Dev $c "eval $load return 1"
Start-Sleep -Seconds 1

'--- bell rest on the host (R reaches the guest)'
$s = Get-Date
Send-Dev $h 'rest'
Start-Sleep -Seconds 3
Show $s 'Refresh Monster|rested|Rested|respawning enemies|rror'

'--- guest turns sync off and on'
$s = Get-Date
Send-Dev $c 'netoff'
Start-Sleep -Seconds 2
Send-Dev $c 'neton client'
Start-Sleep -Seconds 3
Send-Dev $h 'netstatus'; Send-Dev $c 'netstatus'
Start-Sleep -Seconds 1
Show $s 'sync|Ghost |Mod:|started sync|Status|rror'

'--- boss: host starts one, guest mirrors it'
$s = Get-Date
Send-Dev $h 'eval local n=0 for _,sp in ipairs(FindAllOf("AISpawner") or {}) do local id=sp.SpawnerID:ToString() if id:find("Elite") or id:find("Boss") then n=n+1 PBZ.log("SPAWNER "..id) end end return n'
Start-Sleep -Seconds 2
Show $s 'SPAWNER|rror' | Select-Object -First 8
'DONE'
