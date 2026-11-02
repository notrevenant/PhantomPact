# One question to each copy.
param([string]$Lua = 'return 1', [double]$Timeout = 5)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
"H " + (Ask $script:H $Lua $Timeout)
"G " + (Ask $script:C $Lua $Timeout)
