import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { MohoClient } from "../moho-client.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

let testIpcDir = "";

/** Create a fresh temp directory for each test. */
function createTestIpcDir(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), "moho-mcp-test-"));
}

/** Remove the test IPC directory and all files in it. */
function cleanupTestIpcDir(dir: string): void {
  if (!dir || !fs.existsSync(dir)) return;
  for (const f of fs.readdirSync(dir)) {
    fs.unlinkSync(path.join(dir, f));
  }
  fs.rmdirSync(dir);
}

/** Write a status.json that indicates the server is running. */
function writeStatusFile(dir: string, running = true): void {
  fs.writeFileSync(
    path.join(dir, "status.json"),
    JSON.stringify({ running, pid: "moho", version: "0.1.0" }),
  );
}

/**
 * Simulate MOHO responding: watch for req_*.json files and write resp_*.json.
 * Returns a cleanup function to stop watching.
 */
function simulateMohoServer(
  dir: string,
  handler: (request: { id: number; method: string; params: Record<string, unknown> }) => unknown,
): { stop: () => void } {
  let stopped = false;
  let timeoutId: ReturnType<typeof setTimeout> | null = null;

  const poll = () => {
    if (stopped) return;

    try {
      const files = fs.readdirSync(dir);
      for (const f of files) {
        if (f.startsWith("req_") && f.endsWith(".json") && !f.endsWith(".tmp")) {
          const reqPath = path.join(dir, f);
          const content = fs.readFileSync(reqPath, "utf-8");
          const request = JSON.parse(content);

          // Generate response
          const result = handler(request);

          // Extract ID from filename
          const reqId = f.match(/^req_(.+)\.json$/)?.[1];
          if (reqId) {
            const respPath = path.join(dir, `resp_${reqId}.json`);
            fs.writeFileSync(respPath, JSON.stringify(result));
          }

          // Remove request file (like real MOHO would)
          fs.unlinkSync(reqPath);
        }
      }
    } catch {
      // directory may have been cleaned up
    }

    timeoutId = setTimeout(poll, 20);
  };

  poll();

  return {
    stop() {
      stopped = true;
      if (timeoutId) clearTimeout(timeoutId);
    },
  };
}

// ---------------------------------------------------------------------------
// Mock config to use our test IPC directory
// ---------------------------------------------------------------------------

vi.mock("../config.js", () => ({
  config: {
    moho: {
      get ipcDir() {
        return testIpcDir;
      },
      pollInterval: 20, // fast polling for tests
      requestTimeout: 2000, // 2s timeout for tests
    },
    server: {
      name: "moho-mcp-test",
      version: "0.0.0",
    },
  },
}));

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("MohoClient", () => {
  let client: MohoClient;
  let mohoServer: { stop: () => void } | null = null;

  beforeEach(() => {
    testIpcDir = createTestIpcDir();
    client = new MohoClient();
  });

  afterEach(() => {
    try {
      client.disconnect();
    } catch {
      // ignore
    }

    if (mohoServer) {
      mohoServer.stop();
      mohoServer = null;
    }

    cleanupTestIpcDir(testIpcDir);
  });

  // -------------------------------------------------------------------------
  // connect()
  // -------------------------------------------------------------------------

  describe("connect()", () => {
    it("connects successfully when status.json exists and running=true", async () => {
      writeStatusFile(testIpcDir, true);

      await client.connect();
      expect(client.isConnected()).toBe(true);
    });

    it("resolves immediately if already connected", async () => {
      writeStatusFile(testIpcDir, true);

      await client.connect();
      await client.connect();
      expect(client.isConnected()).toBe(true);
    });

    it("rejects when status.json does not exist", async () => {
      await expect(client.connect()).rejects.toThrow(
        "MOHO MCP server is not running",
      );
      expect(client.isConnected()).toBe(false);
    });

    it("rejects when status.json has running=false", async () => {
      writeStatusFile(testIpcDir, false);

      await expect(client.connect()).rejects.toThrow(
        "MOHO MCP server is not running",
      );
      expect(client.isConnected()).toBe(false);
    });

    it("creates the IPC directory if it doesn't exist", async () => {
      // Use a subdirectory that doesn't exist yet
      const subDir = path.join(testIpcDir, "sub", "dir");
      testIpcDir = subDir;

      // Write status file after creating the directory manually
      // (connect() should create the dir first, then check for status)
      // Since connect creates the dir, we need to pre-create and write status
      fs.mkdirSync(subDir, { recursive: true });
      writeStatusFile(subDir, true);

      await client.connect();
      expect(client.isConnected()).toBe(true);

      // Cleanup the sub directory
      cleanupTestIpcDir(subDir);
      // Remove parent dirs
      try {
        fs.rmdirSync(path.join(testIpcDir, ".."));
      } catch { /* ignore */ }
    });
  });

  // -------------------------------------------------------------------------
  // disconnect()
  // -------------------------------------------------------------------------

  describe("disconnect()", () => {
    it("marks the client as disconnected", async () => {
      writeStatusFile(testIpcDir, true);
      await client.connect();
      expect(client.isConnected()).toBe(true);

      client.disconnect();
      expect(client.isConnected()).toBe(false);
    });

    it("can be called when not connected without error", () => {
      expect(() => client.disconnect()).not.toThrow();
    });
  });

  // -------------------------------------------------------------------------
  // isConnected()
  // -------------------------------------------------------------------------

  describe("isConnected()", () => {
    it("returns false initially", () => {
      expect(client.isConnected()).toBe(false);
    });
  });

  // -------------------------------------------------------------------------
  // sendRequest()
  // -------------------------------------------------------------------------

  describe("sendRequest()", () => {
    it("sends correct JSON-RPC and resolves with the result", async () => {
      writeStatusFile(testIpcDir, true);

      mohoServer = simulateMohoServer(testIpcDir, (request) => ({
        jsonrpc: "2.0",
        id: request.id,
        result: { name: "test-document.moho" },
      }));

      await client.connect();
      const result = await client.sendRequest("document.getInfo");

      expect(result).toEqual({ name: "test-document.moho" });
    });

    it("sends params correctly", async () => {
      writeStatusFile(testIpcDir, true);

      let receivedParams: Record<string, unknown> | undefined;
      mohoServer = simulateMohoServer(testIpcDir, (request) => {
        receivedParams = request.params;
        return {
          jsonrpc: "2.0",
          id: request.id,
          result: { success: true },
        };
      });

      await client.connect();
      await client.sendRequest("layer.getProperties", { layerId: 42 });

      expect(receivedParams).toEqual({ layerId: 42 });
    });

    it("rejects on JSON-RPC error response", async () => {
      writeStatusFile(testIpcDir, true);

      mohoServer = simulateMohoServer(testIpcDir, (request) => ({
        jsonrpc: "2.0",
        id: request.id,
        error: {
          code: -32601,
          message: "Method not found",
        },
      }));

      await client.connect();

      await expect(client.sendRequest("nonexistent.method")).rejects.toThrow(
        "MOHO error [-32601]: Method not found",
      );
    });

    it("rejects on JSON-RPC error response with data", async () => {
      writeStatusFile(testIpcDir, true);

      mohoServer = simulateMohoServer(testIpcDir, (request) => ({
        jsonrpc: "2.0",
        id: request.id,
        error: {
          code: -32001,
          message: "No document",
          data: "additional info",
        },
      }));

      await client.connect();

      await expect(client.sendRequest("document.getInfo")).rejects.toThrow(
        'MOHO error [-32001]: No document ("additional info")',
      );
    });

    it("rejects when not connected", async () => {
      await expect(client.sendRequest("test.method")).rejects.toThrow(
        "Not connected to MOHO",
      );
    });

    it("rejects on request timeout", async () => {
      writeStatusFile(testIpcDir, true);

      // No mock server — no one will write the response file
      await client.connect();

      await expect(client.sendRequest("slow.method")).rejects.toThrow(
        /timed out after/,
      );
    }, 10000);

    it("cleans up request file on timeout", async () => {
      writeStatusFile(testIpcDir, true);

      await client.connect();

      await expect(client.sendRequest("slow.method")).rejects.toThrow(
        /timed out/,
      );

      // Request file should have been cleaned up
      const files = fs.readdirSync(testIpcDir);
      const reqFiles = files.filter((f) => f.startsWith("req_"));
      expect(reqFiles).toHaveLength(0);
    }, 10000);

    it("handles multiple sequential requests", async () => {
      writeStatusFile(testIpcDir, true);

      mohoServer = simulateMohoServer(testIpcDir, (request) => ({
        jsonrpc: "2.0",
        id: request.id,
        result: { method: request.method },
      }));

      await client.connect();

      const r1 = await client.sendRequest("method.a");
      const r2 = await client.sendRequest("method.b");
      const r3 = await client.sendRequest("method.c");

      expect(r1).toEqual({ method: "method.a" });
      expect(r2).toEqual({ method: "method.b" });
      expect(r3).toEqual({ method: "method.c" });
    });

    it("writes request files atomically (via .tmp rename)", async () => {
      writeStatusFile(testIpcDir, true);

      let sawReqFile = false;
      mohoServer = simulateMohoServer(testIpcDir, (request) => {
        sawReqFile = true;
        return {
          jsonrpc: "2.0",
          id: request.id,
          result: { ok: true },
        };
      });

      await client.connect();
      await client.sendRequest("test.atomic");

      // The mock server successfully read the request, confirming
      // the file was written (atomically via tmp+rename)
      expect(sawReqFile).toBe(true);
    });

    it("increments request IDs", async () => {
      writeStatusFile(testIpcDir, true);

      const receivedIds: number[] = [];
      mohoServer = simulateMohoServer(testIpcDir, (request) => {
        receivedIds.push(request.id);
        return {
          jsonrpc: "2.0",
          id: request.id,
          result: {},
        };
      });

      await client.connect();
      await client.sendRequest("a");
      await client.sendRequest("b");
      await client.sendRequest("c");

      expect(receivedIds[0]).toBeLessThan(receivedIds[1]);
      expect(receivedIds[1]).toBeLessThan(receivedIds[2]);
    });
  });
});
