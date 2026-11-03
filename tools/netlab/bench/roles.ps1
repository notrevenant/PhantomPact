. (Join-Path $PSScriptRoot 'tourlib.ps1')
$H = $script:H; $C = $script:C
foreach ($g in $C, $H) { Send-Dev $g 'onlinepanel leave'; Start-Sleep -Seconds 2 }
Send-Dev $H 'onlinepanel host'; Start-Sleep -Seconds 4
Send-Dev $C 'onlinepanel join'
$end = (Get-Date).AddSeconds(40)
while ((Get-Date) -lt $end) {
    Start-Sleep -Seconds 2
    $a = Get-Content (Join-Path $H.Dir 'net_status.txt') -Raw -ErrorAction SilentlyContinue
    $b = Get-Content (Join-Path $C.Dir 'net_status.txt') -Raw -ErrorAction SilentlyContinue
    if ($a -match 'role=host.*connected=yes' -and $b -match 'role=client.*connected=yes') { 'roles back: copy 1 hosts, copy 2 joined'; break }
}
($a -split ' ')[0..3] -join ' '
($b -split ' ')[0..3] -join ' '
