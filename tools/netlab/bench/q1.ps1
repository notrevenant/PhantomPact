# One question to the host.
param([string]$Lua = 'return 1', [double]$Timeout = 5)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
Ask $script:H $Lua $Timeout
