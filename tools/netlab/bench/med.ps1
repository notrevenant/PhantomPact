param([string]$Name = 'BP_Chest_C_UAID_60CF848099097AF402_1345083770')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$C = $script:C
$from = Log-End
Ask $C "return LOOTP.mirrorPay(`"$Name`")" 8
Start-Sleep -Seconds 3
Lines $from 'LOOTBAG|LOOTMAP' | Where-Object { $_ -notmatch 'eval' } | Select-Object -First 10 | ForEach-Object { if ($_.Length -gt 130) { $_.Substring(0, 130) } else { $_ } }
