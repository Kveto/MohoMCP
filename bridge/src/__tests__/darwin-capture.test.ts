import { beforeEach, describe, expect, it, vi } from "vitest";
import { captureAppWindow } from "../darwin-capture.js";

const state = vi.hoisted(() => ({
  windows: [] as Array<Record<string, string | number>>,
  calls: [] as Array<{ command: string; args: string[] }>,
}));

vi.mock("node:child_process", async () => {
  const { promisify } = await import("node:util");
  const execFile = Object.assign(vi.fn(), {
    [promisify.custom]: async (command: string, args: string[]) => {
      state.calls.push({ command, args });
      if (command === "osascript") {
        const { default: vm } = await import("node:vm");
        const windows = state.windows.map(values => ({ valueForKey: (key: string) => values[key] }));
        const result = vm.runInNewContext(args[3], {
          ObjC: { import: () => {}, unwrap: (v: unknown) => v, castRefToObject: (v: unknown) => v },
          $: {
            kCGWindowListOptionOnScreenOnly: 1, kCGNullWindowID: 0,
            CGWindowListCopyWindowInfo: () => windows,
            CFArrayGetCount: (v: unknown[]) => v.length,
            CFArrayGetValueAtIndex: (v: unknown[], i: number) => v[i],
          },
        });
        return { stdout: result === undefined ? "" : String(result), stderr: "" };
      }
      return { stdout: command === "sips" ? "pixelWidth: 1280\npixelHeight: 720\n" : "", stderr: "" };
    },
  });
  return { execFile };
});

describe("macOS window capture", () => {
  beforeEach(() => { state.calls.length = 0; state.windows = []; });

  it("returns the main Moho window ID from the executed JXA script", async () => {
    state.windows = [
      { kCGWindowOwnerName: "Other app", kCGWindowLayer: 0, kCGWindowNumber: 10 },
      { kCGWindowOwnerName: "Moho", kCGWindowLayer: 8, kCGWindowNumber: 20 },
      { kCGWindowOwnerName: "Moho", kCGWindowLayer: 0, kCGWindowNumber: 321 },
    ];
    await expect(captureAppWindow("/tmp/moho-test.png")).resolves.toEqual({ width: 1280, height: 720 });
    expect(state.calls.find(c => c.command === "screencapture")?.args).toEqual([
      "-l", "321", "-o", "-x", "/tmp/moho-test.png",
    ]);
  });

  it("fails before capturing if no on-screen Moho window exists", async () => {
    await expect(captureAppWindow("/tmp/moho-test.png")).rejects.toThrow("No on-screen Moho window found");
    expect(state.calls.some(c => c.command === "screencapture")).toBe(false);
  });
});
