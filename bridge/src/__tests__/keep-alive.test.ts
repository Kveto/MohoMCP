import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { EventEmitter } from "node:events";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { config } from "../config.js";
import { startKeepAlive, stopKeepAlive } from "../keep-alive.js";

vi.mock("node:child_process", () => ({ spawn: vi.fn() }));

describe("keep-alive lifecycle", () => {
  let directory: string;
  let originalDirectory: string;
  let child: EventEmitter & { kill: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    directory = fs.mkdtempSync(path.join(os.tmpdir(), "moho-keep-alive-"));
    vi.spyOn(os, "tmpdir").mockReturnValue(directory);
    originalDirectory = config.moho.ipcDir;
    Object.assign(config.moho, { ipcDir: directory });
    child = Object.assign(new EventEmitter(), { kill: vi.fn() });
    vi.mocked(spawn).mockReturnValue(child as unknown as ReturnType<typeof spawn>);
    vi.spyOn(os, "platform").mockReturnValue("darwin");
  });

  afterEach(() => {
    stopKeepAlive();
    Object.assign(config.moho, { ipcDir: originalDirectory });
    vi.restoreAllMocks();
    vi.clearAllMocks();
    fs.rmSync(directory, { recursive: true, force: true });
  });

  it("passes the configured IPC directory as data to a persistent macOS helper", () => {
    Object.assign(config.moho, { ipcDir: path.join(directory, 'custom "quoted" IPC') });
    startKeepAlive();
    const scriptPath = path.join(config.moho.ipcDir, "keep-alive.scpt");
    expect(spawn).toHaveBeenCalledWith("osascript", [scriptPath, config.moho.ipcDir], {
      stdio: "ignore", detached: false,
    });
    const script = fs.readFileSync(scriptPath, "utf8");
    expect(script).toContain("on run argv");
    expect(script).toContain("repeat");
    expect(script).toContain("end repeat");
    expect(script).toContain("quoted form of ipcDirectory");
    expect(script).toContain('if pendingRequest is not "" then');
    expect(script).not.toContain(config.moho.ipcDir);
    expect(script).not.toContain("on idle");
  });

  it("does not spawn duplicate helpers and cleans up on disconnect", () => {
    startKeepAlive();
    startKeepAlive();
    expect(spawn).toHaveBeenCalledTimes(1);
    const scriptPath = path.join(directory, "keep-alive.scpt");
    expect(fs.existsSync(scriptPath)).toBe(true);
    stopKeepAlive();
    expect(child.kill).toHaveBeenCalledTimes(1);
    expect(fs.existsSync(scriptPath)).toBe(false);
    stopKeepAlive();
    expect(child.kill).toHaveBeenCalledTimes(1);
  });

  it("can restart after the helper exits", () => {
    startKeepAlive();
    child.emit("exit", 0);
    startKeepAlive();
    expect(spawn).toHaveBeenCalledTimes(2);
  });

  it("keeps the Windows helper backend with a custom IPC directory", () => {
    vi.mocked(os.platform).mockReturnValue("win32");
    startKeepAlive();
    expect(spawn).toHaveBeenCalledWith("powershell", expect.arrayContaining([
      "-File", path.join(directory, "keep-alive.ps1"),
    ]), expect.any(Object));
    expect(fs.existsSync(path.join(directory, "keep-alive.ps1"))).toBe(true);
  });
});
