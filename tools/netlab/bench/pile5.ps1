param([string]$Tail = 'BC2BDDAE302_1734620634')
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$C = $script:C
$load = 'dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/lootprobe.lua") return 1'
[void](Ask $C $load 8)
Ask $C 'return LOOTP.params("/Game/PBZContent/Blueprint/Item/Device/BP_Rubbish.BP_Rubbish_C:End Interact")' 6
Ask $C 'return LOOTP.params("/Game/PBZContent/Blueprint/Item/Device/BP_Rubbish.BP_Rubbish_C:ChangeSwitchState")' 6
foreach ($how in 'switch', 'end', 'state') {
    Ask $C "return LOOTP.pileEnd(`"$Tail`", `"$how`")" 6
    Start-Sleep -Seconds 2
    Ask $C "return LOOTP.pileFields(`"$Tail`")" 6
    if ((Ask $C "return tostring(LOOTP.find(`"BP_Rubbish_C`", `"$Tail`") ~= nil)" 5) -eq 'false') { 'pile gone'; break }
}
