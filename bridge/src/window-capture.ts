/**
 * Captures the MOHO application window using the Win32 PrintWindow API
 * via PowerShell. Returns the dimensions of the captured image.
 */

import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

/**
 * Capture the MOHO application window to a PNG file.
 *
 * Uses PowerShell to call Win32 `PrintWindow` with `PW_RENDERFULLCONTENT`
 * flag (2), which works even when the window is partially occluded and
 * handles DWM composition on modern Windows.
 *
 * @param outputPath - Absolute path where the PNG will be saved
 * @returns The pixel dimensions of the captured image
 */
export async function captureAppWindow(
  outputPath: string,
): Promise<{ width: number; height: number }> {
  const safePath = outputPath.replace(/'/g, "''");

  const psScript = `
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class WinCapture {
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
}
'@

# Make this process DPI-aware so GetWindowRect returns true pixel dimensions
[WinCapture]::SetProcessDPIAware() | Out-Null

$proc = Get-Process | Where-Object {
    $_.ProcessName -match 'Moho' -and $_.MainWindowHandle -ne [IntPtr]::Zero
} | Select-Object -First 1

if (-not $proc) { throw "MOHO process not found. Is Moho running?" }

$hwnd = $proc.MainWindowHandle
$rect = New-Object WinCapture+RECT
[WinCapture]::GetWindowRect($hwnd, [ref]$rect) | Out-Null

$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top

if ($w -le 0 -or $h -le 0) {
    throw ("Invalid window dimensions: " + $w + "x" + $h)
}

$bmp = New-Object System.Drawing.Bitmap($w, $h)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $gfx.GetHdc()
# PW_RENDERFULLCONTENT = 2 (works with DWM composition on Win10/11)
[WinCapture]::PrintWindow($hwnd, $hdc, 2) | Out-Null
$gfx.ReleaseHdc($hdc)

$outFile = '${safePath}'
$bmp.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
$gfx.Dispose()
$bmp.Dispose()

Write-Output "$w,$h"
`;

  const { stdout, stderr } = await execFileAsync(
    "powershell.exe",
    ["-NoProfile", "-NonInteractive", "-Command", psScript],
    { timeout: 15000 },
  );

  const trimmed = stdout.trim();
  if (!trimmed) {
    throw new Error(
      `Window capture failed: ${stderr?.trim() || "no output from PowerShell"}`,
    );
  }

  const [wStr, hStr] = trimmed.split(",");
  const width = parseInt(wStr, 10);
  const height = parseInt(hStr, 10);

  if (isNaN(width) || isNaN(height)) {
    throw new Error(`Failed to parse window dimensions from: ${trimmed}`);
  }

  return { width, height };
}
