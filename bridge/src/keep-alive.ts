/**
 * Windows keep-alive for MOHO viewport polling.
 *
 * MOHO's Lua polling relies on DrawMe callbacks that only fire during
 * viewport repaints.  When the user isn't interacting with MOHO the
 * viewport stops repainting and polling stalls.
 *
 * This module spawns a hidden PowerShell process that periodically calls
 * Win32 InvalidateRect on the MOHO window, forcing viewport repaints
 * (~4 Hz) so the polling loop stays alive.
 */

import { spawn, ChildProcess } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";

let keepAliveProcess: ChildProcess | null = null;
let scriptPath: string | null = null;

// PowerShell script that forces MOHO viewport repaints via Win32 API.
// Uses RedrawWindow on the main window + PostMessage WM_MOUSEMOVE on all
// child windows to ensure the viewport's DrawMe callback fires.
const PS_SCRIPT = `
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class MohoKeepAlive {
    [DllImport("user32.dll")]
    public static extern bool RedrawWindow(IntPtr hWnd, IntPtr lprcUpdate, IntPtr hrgnUpdate, uint flags);

    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumChildWindows(IntPtr hWndParent, EnumChildProc lpEnumFunc, IntPtr lParam);

    public delegate bool EnumChildProc(IntPtr hWnd, IntPtr lParam);

    private static List<IntPtr> childWindows = new List<IntPtr>();

    private static bool EnumCallback(IntPtr hWnd, IntPtr lParam) {
        childWindows.Add(hWnd);
        return true;
    }

    public static IntPtr[] GetChildWindows(IntPtr parent) {
        childWindows.Clear();
        EnumChildWindows(parent, EnumCallback, IntPtr.Zero);
        return childWindows.ToArray();
    }
}
"@

$WM_MOUSEMOVE = 0x0200
$RDW_INVALIDATE = 0x0001
$RDW_UPDATENOW  = 0x0100
$RDW_ALLCHILDREN = 0x0080
$rdwFlags = $RDW_INVALIDATE -bor $RDW_UPDATENOW -bor $RDW_ALLCHILDREN

while ($true) {
    $procs = Get-Process -Name "Moho*" -ErrorAction SilentlyContinue
    if (-not $procs) {
        Start-Sleep -Seconds 2
        continue
    }
    foreach ($p in $procs) {
        $hwnd = $p.MainWindowHandle
        if ($hwnd -ne [IntPtr]::Zero) {
            [MohoKeepAlive]::RedrawWindow($hwnd, [IntPtr]::Zero, [IntPtr]::Zero, $rdwFlags) | Out-Null
            $children = [MohoKeepAlive]::GetChildWindows($hwnd)
            foreach ($child in $children) {
                [MohoKeepAlive]::PostMessage($child, $WM_MOUSEMOVE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
            }
        }
    }
    Start-Sleep -Milliseconds 250
}
`;

/**
 * Start the keep-alive process.  No-op on non-Windows or if already running.
 */
export function startKeepAlive(): void {
  if (os.platform() !== "win32" || keepAliveProcess) {
    return;
  }

  // Write the script to the IPC temp directory
  const dir = path.join(os.tmpdir(), "moho-mcp");
  try {
    fs.mkdirSync(dir, { recursive: true });
  } catch {
    // already exists
  }

  scriptPath = path.join(dir, "keep-alive.ps1");
  fs.writeFileSync(scriptPath, PS_SCRIPT, "utf-8");

  keepAliveProcess = spawn(
    "powershell",
    ["-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", scriptPath],
    {
      stdio: "ignore",
      detached: false,
      windowsHide: true,
    },
  );

  keepAliveProcess.on("exit", () => {
    keepAliveProcess = null;
  });

  process.stderr.write("[moho-mcp] Keep-alive started (MOHO viewport refresh)\n");
}

/**
 * Stop the keep-alive process and clean up the temp script.
 */
export function stopKeepAlive(): void {
  if (keepAliveProcess) {
    keepAliveProcess.kill();
    keepAliveProcess = null;
    process.stderr.write("[moho-mcp] Keep-alive stopped\n");
  }

  if (scriptPath) {
    try {
      fs.unlinkSync(scriptPath);
    } catch {
      // ignore cleanup errors
    }
    scriptPath = null;
  }
}
