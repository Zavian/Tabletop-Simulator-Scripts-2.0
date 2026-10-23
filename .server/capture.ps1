param([int]$MaxWidth = 1280, [switch]$Foreground, [switch]$List)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class W {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
}
'@
[void][W]::SetProcessDPIAware()

# Process name only: browser tabs titled "Tabletop Simulator" must not match.
$p = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.ProcessName -match 'Tabletop' } | Select-Object -First 1

if ($List) {
  if ($p) { "found: $($p.MainWindowTitle)" } else { 'not found' }
  exit 0
}
if (-not $p) { [Console]::Error.WriteLine('Tabletop Simulator window not found'); exit 1 }

$h = $p.MainWindowHandle
if ($Foreground) {
  if ([W]::IsIconic($h)) { [void][W]::ShowWindow($h, 9) }
  [void][W]::SetForegroundWindow($h)
  Start-Sleep -Milliseconds 300
}

$r = New-Object W+RECT
[void][W]::GetClientRect($h, [ref]$r)
$pt = New-Object W+POINT
[void][W]::ClientToScreen($h, [ref]$pt)
if ($r.Right -le 0 -or $r.Bottom -le 0) { [Console]::Error.WriteLine('window is minimized; use foreground'); exit 1 }

$bmp = New-Object System.Drawing.Bitmap $r.Right, $r.Bottom
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($pt.X, $pt.Y, 0, 0, $bmp.Size)
$g.Dispose()

if ($bmp.Width -gt $MaxWidth) {
  $nh = [int]($bmp.Height * $MaxWidth / $bmp.Width)
  $small = New-Object System.Drawing.Bitmap $MaxWidth, $nh
  $g = [System.Drawing.Graphics]::FromImage($small)
  $g.InterpolationMode = 'HighQualityBicubic'
  $g.DrawImage($bmp, 0, 0, $MaxWidth, $nh)
  $g.Dispose()
  $bmp.Dispose()
  $bmp = $small
}

$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
[Console]::Out.Write([Convert]::ToBase64String($ms.ToArray()))
