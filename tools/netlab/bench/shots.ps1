param([string]$Out, [string[]]$Only = @('host', 'guest'))
$lab = 'C:\Users\TheCo\Downloads\PhantomPact-online\tools\netlab'
. (Join-Path $lab 'dev.ps1')
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
namespace ShotD { public static class Win {
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [StructLayout(LayoutKind.Sequential)] struct R { public int L, T, Rt, B; }
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out R r);
    public static string Save(IntPtr h, string path) {
        R r; GetClientRect(h, out r);
        using (Bitmap b = new Bitmap(r.Rt - r.L, r.B - r.T)) {
            using (Graphics g = Graphics.FromImage(b)) { IntPtr dc = g.GetHdc(); PrintWindow(h, dc, 3); g.ReleaseHdc(dc); }
            b.Save(path, ImageFormat.Png);
            return b.Width + "x" + b.Height;
        }
    }
} }
'@
foreach ($n in $Only) {
    $g = Get-Content (Join-Path $lab "bench\dev-$n.json") -Raw | ConvertFrom-Json
    $n + ' ' + [ShotD.Win]::Save([NetLab.Win]::Unreal($g.Pid), (Join-Path $Out "$n.png"))
}
