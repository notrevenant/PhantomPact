<#
.SYNOPSIS
    Shows that two players' traffic is the same in two versions of the relay, byte for byte: builds wirecheck.cpp against each
    native folder, runs the same simulated session on both, and compares every packet. PASS or FAIL on the last line.

.EXAMPLE
    git worktree add ..\old HEAD~1
    .\tools\netlab\wirecheck.ps1 -Old ..\old\native
#>
param([Parameter(Mandatory)][string]$Old, [string]$New = (Join-Path $PSScriptRoot '..\..\native'), [string]$Work = (Join-Path $env:TEMP "pp-wirecheck-$PID"))
$ErrorActionPreference = 'Stop'
$Old = (Resolve-Path $Old).Path
$New = (Resolve-Path $New).Path
New-Item -ItemType Directory -Force $Work | Out-Null
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
$source = Join-Path $PSScriptRoot 'wirecheck.cpp'
$flags = '/nologo /std:c++20 /O1 /MT /EHsc /W3 /utf-8 /D_WINSOCK_DEPRECATED_NO_WARNINGS'
$libs = 'ws2_32.lib bcrypt.lib winmm.lib user32.lib'

foreach ($side in 'old', 'new') {
    $native = if ($side -eq 'old') { $Old } else { $New }
    $dir = Join-Path $Work $side
    New-Item -ItemType Directory -Force $dir | Out-Null
    $bat = Join-Path $dir 'build.bat'
    @"
@echo off
call "$vcvars" >nul 2>nul
cd /d "$dir"
cl $flags /I"$native" "$source" /Fe:wirecheck.exe /link /NOLOGO $libs || exit /b 1
"@ | Set-Content $bat -Encoding ascii
    & cmd /c $bat | Where-Object { $_ -match 'error' }
    if ($LASTEXITCODE -ne 0) { throw "wirecheck didn't build against $native" }
    & (Join-Path $dir 'wirecheck.exe') (Join-Path $dir 'wire.txt')
    if ($LASTEXITCODE -ne 0) { throw "wirecheck failed against $native" }
}
$a = Join-Path $Work 'old\wire.txt'
$b = Join-Path $Work 'new\wire.txt'
$lines = (Get-Content $a | Measure-Object -Line).Lines
$bytes = (Get-Item $a).Length
if ((Get-FileHash $a).Hash -eq (Get-FileHash $b).Hash) {
    "PASS: $lines lines, $bytes bytes, the same on both"
    exit 0
}
"Different. First lines that differ:"
$x = Get-Content $a
$y = Get-Content $b
$shown = 0
for ($i = 0; $i -lt [Math]::Max($x.Count, $y.Count) -and $shown -lt 5; $i++) {
    if ($x[$i] -ne $y[$i]) {
        "  old $($i + 1): $($x[$i])"
        "  new $($i + 1): $($y[$i])"
        $shown++
    }
}
"FAIL"
exit 1
