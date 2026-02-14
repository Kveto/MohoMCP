/**
 * Platform-dispatch wrapper for window capture.
 * Routes to window-capture.ts on Windows or darwin-capture.ts on macOS.
 */

import os from "node:os";

let _captureAppWindow: typeof import("./window-capture.js").captureAppWindow;
let _loaded = false;

async function loadBackend(): Promise<void> {
  if (_loaded) return;
  const platform = os.platform();
  if (platform === "win32") {
    const mod = await import("./window-capture.js");
    _captureAppWindow = mod.captureAppWindow;
  } else if (platform === "darwin") {
    const mod = await import("./darwin-capture.js");
    _captureAppWindow = mod.captureAppWindow;
  } else {
    throw new Error(
      `Window capture is not supported on ${platform}. ` +
      `Supported platforms: Windows (win32), macOS (darwin).`,
    );
  }
  _loaded = true;
}

export async function captureAppWindow(
  outputPath: string,
): Promise<{ width: number; height: number }> {
  await loadBackend();
  return _captureAppWindow(outputPath);
}
