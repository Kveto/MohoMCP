/**
 * macOS input simulation for the MOHO application window.
 * Sends mouse clicks, drags, and keyboard shortcuts via osascript / cliclick.
 *
 * Uses AppleScript's System Events for keyboard shortcuts and
 * the `cliclick` CLI tool (or CoreGraphics via osascript) for mouse operations.
 */

import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

/**
 * Run an osascript (AppleScript) command and return stdout.
 */
async function runAppleScript(script: string): Promise<string> {
  const { stdout, stderr } = await execFileAsync(
    "osascript",
    ["-e", script],
    { timeout: 15000 },
  );
  const trimmed = stdout.trim();
  if (!trimmed && stderr?.trim()) {
    throw new Error(`AppleScript error: ${stderr.trim()}`);
  }
  return trimmed;
}

/**
 * Run a JXA (JavaScript for Automation) script via osascript.
 */
async function runJXA(script: string): Promise<string> {
  const { stdout, stderr } = await execFileAsync(
    "osascript",
    ["-l", "JavaScript", "-e", script],
    { timeout: 15000 },
  );
  const trimmed = stdout.trim();
  if (!trimmed && stderr?.trim()) {
    throw new Error(`JXA error: ${stderr.trim()}`);
  }
  return trimmed;
}

/**
 * Get the MOHO window position and size via JXA.
 * Returns { x, y, width, height } of the frontmost Moho window.
 */
async function getMohoWindowBounds(): Promise<{
  x: number;
  y: number;
  width: number;
  height: number;
}> {
  const script = `
    const app = Application("Moho");
    app.activate();
    delay(0.05);
    const se = Application("System Events");
    const proc = se.processes.byName("Moho");
    const win = proc.windows[0];
    const pos = win.position();
    const size = win.size();
    JSON.stringify({ x: pos[0], y: pos[1], width: size[0], height: size[1] });
  `;
  const output = await runJXA(script);
  return JSON.parse(output);
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
  const bounds = await getMohoWindowBounds();
  const screenX = bounds.x + x;
  const screenY = bounds.y + y;

  const clickCount = clickType === "double" ? 2 : 1;

  // Use cliclick for mouse operations (more reliable than AppleScript for clicks)
  // Fall back to AppleScript if cliclick is not available
  try {
    const cmd = button === "right" ? "rc" : "c";
    const args: string[] = [];
    for (let i = 0; i < clickCount; i++) {
      args.push(`${cmd}:${screenX},${screenY}`);
    }
    await execFileAsync("cliclick", args, { timeout: 10000 });
  } catch {
    // Fallback: use AppleScript with System Events
    const clickCmd = button === "right"
      ? `click at {${screenX}, ${screenY}} with command down`
      : `click at {${screenX}, ${screenY}}`;

    for (let i = 0; i < clickCount; i++) {
      await runAppleScript(
        `tell application "System Events" to ${clickCmd}`,
      );
    }
  }

  return { success: true, screenX, screenY };
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
  const bounds = await getMohoWindowBounds();
  const sx = bounds.x + startX;
  const sy = bounds.y + startY;
  const ex = bounds.x + endX;
  const ey = bounds.y + endY;

  try {
    // cliclick supports drag via dd (drag down) and du (drag up)
    const args = [`dd:${sx},${sy}`, `du:${ex},${ey}`];
    await execFileAsync("cliclick", args, { timeout: 10000 });
  } catch {
    // Fallback: use JXA with CoreGraphics events
    const script = `
      ObjC.import('CoreGraphics');
      const sx = ${sx}, sy = ${sy}, ex = ${ex}, ey = ${ey};
      const steps = ${steps};

      // Move to start
      $.CGEventPost($.kCGHIDEventTap,
        $.CGEventCreateMouseEvent(null, $.kCGEventMouseMoved, $.CGPointMake(sx, sy), $.kCGMouseButtonLeft));
      delay(0.05);

      // Press
      $.CGEventPost($.kCGHIDEventTap,
        $.CGEventCreateMouseEvent(null, $.kCGEventLeftMouseDown, $.CGPointMake(sx, sy), $.kCGMouseButtonLeft));
      delay(0.05);

      // Drag
      for (let i = 1; i <= steps; i++) {
        const t = i / steps;
        const cx = sx + (ex - sx) * t;
        const cy = sy + (ey - sy) * t;
        $.CGEventPost($.kCGHIDEventTap,
          $.CGEventCreateMouseEvent(null, $.kCGEventLeftMouseDragged, $.CGPointMake(cx, cy), $.kCGMouseButtonLeft));
        delay(0.015);
      }

      // Release
      $.CGEventPost($.kCGHIDEventTap,
        $.CGEventCreateMouseEvent(null, $.kCGEventLeftMouseUp, $.CGPointMake(ex, ey), $.kCGMouseButtonLeft));
      "OK";
    `;
    await runJXA(script);
  }

  return { success: true };
}

/**
 * macOS key code mapping for common keys.
 * These are macOS virtual key codes (CGKeyCode values).
 */
const MAC_KEY_MAP: Record<string, number> = {
  // Letters a-z
  a: 0, s: 1, d: 2, f: 3, h: 4, g: 5, z: 6, x: 7, c: 8, v: 9,
  b: 11, q: 12, w: 13, e: 14, r: 15, y: 16, t: 17, "1": 18, "2": 19,
  "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
  "-": 27, "8": 28, "0": 29, "]": 30, o: 31, u: 32, "[": 33, i: 34,
  p: 35, l: 37, j: 38, "'": 39, k: 40, ";": 41, "\\": 42, ",": 43,
  "/": 44, n: 45, m: 46, ".": 47, "`": 50,
  // Special keys
  enter: 36, return: 36,
  tab: 48,
  space: 49,
  delete: 51, backspace: 51,
  escape: 53, esc: 53,
  // Function keys
  f1: 122, f2: 120, f3: 99, f4: 118,
  f5: 96, f6: 97, f7: 98, f8: 100,
  f9: 101, f10: 109, f11: 103, f12: 111,
  // Arrow keys
  left: 123, right: 124, down: 125, up: 126,
  // Navigation
  home: 115, end: 119, pageup: 116, pagedown: 121,
  del: 117, // forward delete
  insert: 114, // help key on Mac
};

const MODIFIER_KEYS = new Set(["ctrl", "control", "shift", "alt", "cmd", "command"]);

/**
 * Send a keyboard shortcut to the MOHO window.
 * On macOS, "ctrl" maps to Command (as Moho uses Cmd for shortcuts).
 */
export async function sendKeys(
  keys: string,
): Promise<{ success: boolean; keys: string }> {
  const parts = keys.toLowerCase().split("+").map((s) => s.trim());
  const modifiers: string[] = [];
  let mainKeyName: string | undefined;

  for (const part of parts) {
    if (MODIFIER_KEYS.has(part)) {
      modifiers.push(part);
    } else {
      if (MAC_KEY_MAP[part] === undefined) {
        throw new Error(
          `Unknown key: "${part}". Supported keys: ${Object.keys(MAC_KEY_MAP).filter((k) => !MODIFIER_KEYS.has(k)).join(", ")}`,
        );
      }
      mainKeyName = part;
    }
  }

  if (!mainKeyName) {
    throw new Error(
      `No main key found in shortcut "${keys}". Need at least one non-modifier key.`,
    );
  }

  // Build AppleScript keystroke command
  // Map "ctrl" to "command" for macOS (Moho uses Cmd instead of Ctrl)
  const asModifiers: string[] = [];
  for (const mod of modifiers) {
    if (mod === "ctrl" || mod === "control" || mod === "cmd" || mod === "command") {
      asModifiers.push("command down");
    } else if (mod === "shift") {
      asModifiers.push("shift down");
    } else if (mod === "alt") {
      asModifiers.push("option down");
    }
  }

  const keyCode = MAC_KEY_MAP[mainKeyName];
  const modifierStr = asModifiers.length > 0 ? ` using {${asModifiers.join(", ")}}` : "";

  // Activate Moho first, then send the key
  const script =
    `tell application "Moho" to activate\n` +
    `delay 0.05\n` +
    `tell application "System Events" to key code ${keyCode}${modifierStr}`;

  await runAppleScript(script);
  return { success: true, keys };
}
