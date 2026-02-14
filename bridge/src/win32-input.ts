/**
 * Win32 input simulation for the MOHO application window.
 * Sends mouse clicks, drags, and keyboard shortcuts via PowerShell + P/Invoke.
 */

import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

/**
 * Common C# declarations for Win32 input functions.
 * Shared across all input scripts to avoid duplication.
 */
const WIN32_INPUT_TYPES = `
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class WinInput {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    public const uint MOUSEEVENTF_LEFTDOWN   = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP     = 0x0004;
    public const uint MOUSEEVENTF_RIGHTDOWN  = 0x0008;
    public const uint MOUSEEVENTF_RIGHTUP    = 0x0010;
    public const uint MOUSEEVENTF_MIDDLEDOWN = 0x0020;
    public const uint MOUSEEVENTF_MIDDLEUP   = 0x0040;

    public const uint KEYEVENTF_KEYUP = 0x0002;
}
'@
`;

/**
 * PowerShell snippet to find the MOHO window and set it as foreground.
 * Returns $hwnd and $rect for coordinate conversion.
 */
const FIND_MOHO_WINDOW = `
[WinInput]::SetProcessDPIAware() | Out-Null

$proc = Get-Process | Where-Object {
    $_.ProcessName -match 'Moho' -and $_.MainWindowHandle -ne [IntPtr]::Zero
} | Select-Object -First 1

if (-not $proc) { throw "MOHO process not found. Is Moho running?" }

$hwnd = $proc.MainWindowHandle
[WinInput]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 50

$rect = New-Object WinInput+RECT
[WinInput]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
`;

/**
 * Execute a PowerShell script and return stdout.
 */
async function runPowerShell(script: string): Promise<string> {
  const { stdout, stderr } = await execFileAsync(
    "powershell.exe",
    ["-NoProfile", "-NonInteractive", "-Command", script],
    { timeout: 15000 },
  );

  const trimmed = stdout.trim();
  if (!trimmed) {
    throw new Error(
      `Input command failed: ${stderr?.trim() || "no output from PowerShell"}`,
    );
  }
  return trimmed;
}

/**
 * Send a mouse click at (x, y) relative to the MOHO window top-left.
 */
export async function sendMouseClick(
  x: number,
  y: number,
  button: "left" | "right" | "middle" = "left",
  clickType: "single" | "double" = "single",
): Promise<{ success: boolean; screenX: number; screenY: number }> {
  const downFlag =
    button === "right"
      ? "MOUSEEVENTF_RIGHTDOWN"
      : button === "middle"
        ? "MOUSEEVENTF_MIDDLEDOWN"
        : "MOUSEEVENTF_LEFTDOWN";
  const upFlag =
    button === "right"
      ? "MOUSEEVENTF_RIGHTUP"
      : button === "middle"
        ? "MOUSEEVENTF_MIDDLEUP"
        : "MOUSEEVENTF_LEFTUP";

  const clickCount = clickType === "double" ? 2 : 1;

  const psScript = `
${WIN32_INPUT_TYPES}
${FIND_MOHO_WINDOW}

$screenX = $rect.Left + ${x}
$screenY = $rect.Top + ${y}

[WinInput]::SetCursorPos($screenX, $screenY) | Out-Null
Start-Sleep -Milliseconds 50

for ($i = 0; $i -lt ${clickCount}; $i++) {
    [WinInput]::mouse_event([WinInput]::${downFlag}, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 50
    [WinInput]::mouse_event([WinInput]::${upFlag}, 0, 0, 0, [UIntPtr]::Zero)
    if ($i -lt ${clickCount - 1}) {
        Start-Sleep -Milliseconds 50
    }
}

Write-Output "$screenX,$screenY"
`;

  const output = await runPowerShell(psScript);
  const [sxStr, syStr] = output.split(",");
  return {
    success: true,
    screenX: parseInt(sxStr, 10),
    screenY: parseInt(syStr, 10),
  };
}

/**
 * Drag from (startX, startY) to (endX, endY) relative to the MOHO window.
 */
export async function sendMouseDrag(
  startX: number,
  startY: number,
  endX: number,
  endY: number,
  button: "left" | "right" = "left",
  steps: number = 10,
): Promise<{ success: boolean }> {
  const downFlag =
    button === "right" ? "MOUSEEVENTF_RIGHTDOWN" : "MOUSEEVENTF_LEFTDOWN";
  const upFlag =
    button === "right" ? "MOUSEEVENTF_RIGHTUP" : "MOUSEEVENTF_LEFTUP";

  const psScript = `
${WIN32_INPUT_TYPES}
${FIND_MOHO_WINDOW}

$startScreenX = $rect.Left + ${startX}
$startScreenY = $rect.Top + ${startY}
$endScreenX = $rect.Left + ${endX}
$endScreenY = $rect.Top + ${endY}

# Move to start and press
[WinInput]::SetCursorPos($startScreenX, $startScreenY) | Out-Null
Start-Sleep -Milliseconds 50
[WinInput]::mouse_event([WinInput]::${downFlag}, 0, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 50

# Interpolate intermediate positions
$steps = ${steps}
for ($i = 1; $i -le $steps; $i++) {
    $t = $i / $steps
    $cx = [int]($startScreenX + ($endScreenX - $startScreenX) * $t)
    $cy = [int]($startScreenY + ($endScreenY - $startScreenY) * $t)
    [WinInput]::SetCursorPos($cx, $cy) | Out-Null
    Start-Sleep -Milliseconds 15
}

# Release at end position
[WinInput]::SetCursorPos($endScreenX, $endScreenY) | Out-Null
Start-Sleep -Milliseconds 50
[WinInput]::mouse_event([WinInput]::${upFlag}, 0, 0, 0, [UIntPtr]::Zero)

Write-Output "OK"
`;

  await runPowerShell(psScript);
  return { success: true };
}

/**
 * Virtual key code mapping for common keys.
 */
const VK_MAP: Record<string, number> = {
  // Modifiers
  ctrl: 0x11,
  control: 0x11,
  shift: 0x10,
  alt: 0x12,
  // Function keys
  f1: 0x70, f2: 0x71, f3: 0x72, f4: 0x73,
  f5: 0x74, f6: 0x75, f7: 0x76, f8: 0x77,
  f9: 0x78, f10: 0x79, f11: 0x7a, f12: 0x7b,
  // Special keys
  enter: 0x0d, return: 0x0d,
  tab: 0x09,
  escape: 0x1b, esc: 0x1b,
  space: 0x20,
  backspace: 0x08,
  delete: 0x2e, del: 0x2e,
  insert: 0x2d,
  home: 0x24,
  end: 0x23,
  pageup: 0x21,
  pagedown: 0x22,
  up: 0x26,
  down: 0x28,
  left: 0x25,
  right: 0x27,
  // Punctuation / symbols
  ",": 0xbc, ".": 0xbe, "/": 0xbf,
  ";": 0xba, "'": 0xde,
  "[": 0xdb, "]": 0xdd, "\\": 0xdc,
  "-": 0xbd, "=": 0xbb,
  "`": 0xc0,
  // Number keys 0-9
  "0": 0x30, "1": 0x31, "2": 0x32, "3": 0x33, "4": 0x34,
  "5": 0x35, "6": 0x36, "7": 0x37, "8": 0x38, "9": 0x39,
};

// Add a-z keys (VK codes 0x41-0x5A)
for (let i = 0; i < 26; i++) {
  const letter = String.fromCharCode(97 + i); // 'a' to 'z'
  VK_MAP[letter] = 0x41 + i;
}

const MODIFIER_KEYS = new Set(["ctrl", "control", "shift", "alt"]);

/**
 * Send a keyboard shortcut to the MOHO window.
 * @param keys - Shortcut string like "ctrl+z", "ctrl+shift+z", "space", "f5", "a"
 */
export async function sendKeys(
  keys: string,
): Promise<{ success: boolean; keys: string }> {
  const parts = keys.toLowerCase().split("+").map((s) => s.trim());
  const modifiers: number[] = [];
  let mainKey: number | undefined;

  for (const part of parts) {
    if (MODIFIER_KEYS.has(part)) {
      const vk = VK_MAP[part];
      if (vk !== undefined) modifiers.push(vk);
    } else {
      const vk = VK_MAP[part];
      if (vk === undefined) {
        throw new Error(`Unknown key: "${part}". Supported keys: ${Object.keys(VK_MAP).filter((k) => !MODIFIER_KEYS.has(k)).join(", ")}`);
      }
      mainKey = vk;
    }
  }

  if (mainKey === undefined) {
    throw new Error(`No main key found in shortcut "${keys}". Need at least one non-modifier key.`);
  }

  // Build PowerShell keybd_event calls
  const pressModifiers = modifiers
    .map((vk) => `[WinInput]::keybd_event(${vk}, 0, 0, [UIntPtr]::Zero)`)
    .join("\n");
  const releaseModifiers = modifiers
    .reverse()
    .map((vk) => `[WinInput]::keybd_event(${vk}, 0, [WinInput]::KEYEVENTF_KEYUP, [UIntPtr]::Zero)`)
    .join("\n");

  const psScript = `
${WIN32_INPUT_TYPES}
${FIND_MOHO_WINDOW}

# Press modifiers
${pressModifiers}
Start-Sleep -Milliseconds 30

# Press and release main key
[WinInput]::keybd_event(${mainKey}, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 50
[WinInput]::keybd_event(${mainKey}, 0, [WinInput]::KEYEVENTF_KEYUP, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 30

# Release modifiers
${releaseModifiers}

Write-Output "OK"
`;

  await runPowerShell(psScript);
  return { success: true, keys };
}
