# Every story boss in order, each from a rewind. boss.ps1 does one.
param([int]$StartAt = 0, [int]$Count = 99)
$list = @(
    @(25, '', 'Axe chief'), @(42, '', 'Bride A-Hua'), @(46, '', 'Zhui Ming'), @(48, '', 'Can Gang'),
    @(119, 'LZSJ_001', 'Bai Chilian'),
    @(155, 'SXC_01_01', 'Big Mother'), @(173, 'SXC_01_01', 'Sect leader'), @(177, 'SXC_01_01', 'Yu Zan'), @(182, 'SXC_01_01', 'Mu Xiaokui'), @(232, 'SXC_01_01', 'Dang Hui'),
    @(244, 'SZ_001', 'Big Head'), @(285, 'SZ_005', 'Fallen General'), @(306, 'SZ_005', 'Little Lion'),
    @(348, 'YXZR_001', 'Wan Junke'), @(349, 'YXZR_001', 'Wu Lengshuang'), @(354, 'YXZR_001', 'Elder Brother'), @(361, 'YXZR_001', 'Sword Puppet'),
    @(431, 'SZ_020', 'Yan Qiansui'),
    @(490, 'JJYBP_001', 'Blade Captain'), @(501, 'JJYBP_001', 'Shaqi Mask'), @(509, 'JJYBP_001', 'Jade Face'), @(510, 'JJYBP_001', 'Huang Xingzi'),
    @(550, 'BrokenBell_HSSYJ_01', 'Scavenger'), @(558, 'BrokenBell_HSSYJ_01', 'The Supreme'),
    @(586, 'Bell_XM_001', 'Lei Dang'), @(623, 'DH_001', 'Three-Headed Puppet')
)
$i = 0
foreach ($b in $list) {
    if ($i -ge $StartAt -and $i -lt $StartAt + $Count) {
        & (Join-Path $PSScriptRoot 'boss.ps1') -Row $b[0] -Bell $b[1] -Name $b[2]
    }
    $i++
}
Add-Content -Path 'C:\PBZDev\pp-netlab\boss-log.txt' -Value 'BOSSES DONE' -Encoding utf8
'BOSSES DONE'
