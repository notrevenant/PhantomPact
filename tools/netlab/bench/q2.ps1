# One question to the guest.
param([string]$Lua = 'return 1', [double]$Timeout = 5)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
Ask $script:C $Lua $Timeout
