# Flies the guest over each level. The host stays where it is.
param([string[]]$Levels = @('PBZ_Xigu_WP:NLES_001','PBZ_Fujizhilin_WP:LZSJ_001','PBZ_Zhengdaodaying_WP:SXC_01_01','PBZ_Pangzhen_WP:SZ_001','PBZ_Houjie_WP:SZ_005','PBZ_DengDingShanDao_WP:JJYBP_001','PBZ_Huanshuyiji2_WP:BrokenBell_HSSYJ_01','PBZ_Ximeng_WP:Bell_XM_001','PBZ_Duanhun_WP:DH_001'), [double]$Every = 4.5)
. (Join-Path $PSScriptRoot 'tourlib.ps1')
$C = $script:C
$load = 'dofile("C:/PBZDev/netlab/perf.lua") dofile("C:/PBZDev/netlab/pair.lua") dofile("C:/PBZDev/netlab/fights.lua") dofile("C:/PBZDev/netlab/real.lua") dofile("C:/PBZDev/netlab/story.lua") dofile("C:/PBZDev/netlab/survey.lua") dofile("C:/PBZDev/netlab/surveypoints.lua") return 1'
[void](Ask $C $load 8)
foreach ($e in $Levels) {
    $lvl, $bell = $e -split ':'
    "=== $lvl via $bell $(Get-Date -Format HH:mm:ss)"
    [void](Ask $C "return STORY.go(`"$bell`")" 8)
    Start-Sleep -Seconds 6
    $r = Wait-Player $C 120
    "arrived: $r"
    if ($r -ne 'ready') { return }
    Start-Sleep -Seconds 3
    $file = "C:/PBZDev/pp-netlab/survey-$lvl.tsv"
    Remove-Item $file -ErrorAction SilentlyContinue
    $from = Log-End
    "start: " + (Ask $C "return SURVEY.run(`"$file`", SURVEY.points.$lvl, $Every)" 8)
    $deadline = (Get-Date).AddMinutes(8)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        if (-not (Alive $C)) { 'guest gone'; return }
        $l = Lines $from 'SURVEY done'
        if ($l) { $l | Select-Object -Last 1; break }
    }
    (Get-Content $file -ErrorAction SilentlyContinue | ForEach-Object { ($_ -split "`t")[0] } | Group-Object | ForEach-Object { "$($_.Name) $($_.Count)" }) -join ', '
}
'SURVEY ALL DONE'
