/**
 * macOS window capture for the MOHO application.
 * Uses the `screencapture` CLI tool to capture a specific window.
 */

import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { readFile } from "node:fs/promises";

const execFileAsync = promisify(execFile);

/**
 * Get the Moho window ID using JXA (JavaScript for Automation).
 * We need the CGWindowID for screencapture -l flag.
 */
async function getMohoWindowId(): Promise<number> {
  // Use CoreGraphics window list to find Moho's window
  const script = `
    ObjC.import('CoreGraphics');
    ObjC.import('Foundation');
    const windows = $.CGWindowListCopyWindowInfo($.kCGWindowListOptionOnScreenOnly, $.kCGNullWindowID);
    const count = $.CFArrayGetCount(windows);
    for (let i = 0; i < count; i++) {
      const win = ObjC.castRefToObject($.CFArrayGetValueAtIndex(windows, i));
      const owner = ObjC.unwrap(win.valueForKey('kCGWindowOwnerName'));
      if (owner && owner.match(/Moho/i)) {
        const layer = ObjC.unwrap(win.valueForKey('kCGWindowLayer'));
        if (layer === 0) {
          const wid = ObjC.unwrap(win.valueForKey('kCGWindowNumber'));
          wid;
          break;
        }
      }
    }
  `;

  const { stdout } = await execFileAsync(
    "osascript",
    ["-l", "JavaScript", "-e", script],
    { timeout: 10000 },
  );

  const windowId = parseInt(stdout.trim(), 10);
  if (isNaN(windowId)) {
    throw new Error("MOHO process not found. Is Moho running?");
  }
  return windowId;
}

/**
 * Capture the MOHO application window to a PNG file.
 *
 * Uses macOS `screencapture` with the `-l` flag to capture a specific
 * window by its CGWindowID. This captures the exact window contents
 * without requiring it to be frontmost.
 *
 * @param outputPath - Absolute path where the PNG will be saved
 * @returns The pixel dimensions of the captured image
 */
export async function captureAppWindow(
  outputPath: string,
): Promise<{ width: number; height: number }> {
  const windowId = await getMohoWindowId();

  // screencapture -l <windowId> -o (no shadow) -x (no sound) <path>
  await execFileAsync(
    "screencapture",
    ["-l", String(windowId), "-o", "-x", outputPath],
    { timeout: 15000 },
  );

  // Read the image to get dimensions using sips (built into macOS)
  const { stdout } = await execFileAsync(
    "sips",
    ["-g", "pixelWidth", "-g", "pixelHeight", outputPath],
    { timeout: 5000 },
  );

  let width = 0;
  let height = 0;
  const widthMatch = stdout.match(/pixelWidth:\s*(\d+)/);
  const heightMatch = stdout.match(/pixelHeight:\s*(\d+)/);
  if (widthMatch) width = parseInt(widthMatch[1], 10);
  if (heightMatch) height = parseInt(heightMatch[1], 10);

  if (width <= 0 || height <= 0) {
    throw new Error(`Failed to parse window dimensions from captured image`);
  }

  return { width, height };
}
