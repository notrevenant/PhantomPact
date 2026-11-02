# Several questions to the guest, one per argument line in a file.
param([string]$File)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
foreach ($l in Get-Content $File) {
    if ($l.Trim()) { "> " + $(if ($l.Length -gt 70) { $l.Substring(0, 70) } else { $l }); Ask $script:C $l 8 }
}
