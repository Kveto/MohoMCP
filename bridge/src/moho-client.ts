/**
 * File-based IPC client that communicates with the MOHO Lua server.
 *
 * Protocol:
 * - Bridge writes request to: <ipcDir>/req_<id>.json
 * - MOHO reads the request, processes it, writes: <ipcDir>/resp_<id>.json
 * - MOHO deletes the request file after processing
 * - Bridge reads the response file, then deletes it
 */

import fs from "node:fs";
import path from "node:path";
import { config } from "./config.js";
import { parseResponse } from "./protocol.js";
import { startKeepAlive, stopKeepAlive } from "./keep-alive.js";

// ---------------------------------------------------------------------------
// MohoClient
// ---------------------------------------------------------------------------

export class MohoClient {
  private nextId = 1;
  private connected = false;

  // -----------------------------------------------------------------------
  // Connection lifecycle
  // -----------------------------------------------------------------------

  /**
   * "Connect" by verifying the IPC directory exists and MOHO's status file
   * indicates the server is running.
   */
  async connect(): Promise<void> {
    if (this.connected) {
      return;
    }

    const { ipcDir } = config.moho;

    // Ensure the IPC directory exists
    try {
      await fs.promises.mkdir(ipcDir, { recursive: true });
    } catch {
      // directory may already exist
    }

    // Check for MOHO's status file
    const statusPath = path.join(ipcDir, "status.json");
    try {
      const content = await fs.promises.readFile(statusPath, "utf-8");
      const status = JSON.parse(content);
      if (!status.running) {
        throw new Error("MOHO MCP server is not running (status.running=false)");
      }
    } catch (err) {
      if ((err as NodeJS.ErrnoException).code === "ENOENT") {
        throw new Error(
          `MOHO MCP server is not running. No status file found at ${statusPath}. ` +
          "Start the MohoMCP Server from MOHO's Scripts menu first.",
        );
      }
      throw err;
    }

    this.connected = true;
    startKeepAlive();
    process.stderr.write(
      `[moho-mcp] Connected to MOHO via file IPC at ${ipcDir}\n`,
    );
  }

  /**
   * Disconnect — no-op for file IPC but resets state.
   */
  disconnect(): void {
    stopKeepAlive();
    this.connected = false;
  }

  /**
   * Returns whether the client is "connected" (IPC dir verified).
   */
  isConnected(): boolean {
    return this.connected;
  }

  // -----------------------------------------------------------------------
  // Request / response
  // -----------------------------------------------------------------------

  /**
   * Send a JSON-RPC request to MOHO via file IPC and await the response.
   */
  async sendRequest(
    method: string,
    params: Record<string, unknown> = {},
    options?: { timeout?: number },
  ): Promise<unknown> {
    if (!this.connected) {
      throw new Error(
        "Not connected to MOHO. Is the MOHO application running with the MCP plugin loaded?",
      );
    }

    const id = this.nextId++;
    const { ipcDir, pollInterval, requestTimeout } = config.moho;
    const timeout = options?.timeout ?? requestTimeout;

    // Build JSON-RPC request
    const request = {
      jsonrpc: "2.0",
      id,
      method,
      params,
    };

    const reqFileName = `req_${id}.json`;
    const respFileName = `resp_${id}.json`;
    const reqPath = path.join(ipcDir, reqFileName);
    const respPath = path.join(ipcDir, respFileName);

    // Write request file atomically (write to .tmp then rename)
    const tmpPath = reqPath + ".tmp";
    await fs.promises.writeFile(tmpPath, JSON.stringify(request), "utf-8");
    await fs.promises.rename(tmpPath, reqPath);

    // Poll for response file
    const startTime = Date.now();

    while (true) {
      // Check if response file exists
      try {
        const content = await fs.promises.readFile(respPath, "utf-8");
        // Delete response file
        await fs.promises.unlink(respPath).catch(() => {});

        // Parse and return
        const response = parseResponse(content);

        if (response.error) {
          throw new Error(
            `MOHO error [${response.error.code}]: ${response.error.message}${
              response.error.data
                ? ` (${JSON.stringify(response.error.data)})`
                : ""
            }`,
          );
        }

        return response.result;
      } catch (err) {
        // File doesn't exist yet — keep polling
        if ((err as NodeJS.ErrnoException).code === "ENOENT") {
          // Check timeout
          if (Date.now() - startTime > timeout) {
            // Clean up the request file if it's still there
            await fs.promises.unlink(reqPath).catch(() => {});
            throw new Error(
              `Request ${method} (id=${id}) timed out after ${timeout}ms. ` +
              "Is the MOHO MCP server running and polling?",
            );
          }

          // Wait before next poll
          await new Promise((resolve) => setTimeout(resolve, pollInterval));
          continue;
        }

        // Re-throw non-ENOENT errors (parse errors, MOHO errors, etc.)
        throw err;
      }
    }
  }
}
