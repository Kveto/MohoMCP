import path from "node:path";
import os from "node:os";

const defaultIpcDir = process.env.MOHO_MCP_IPC_DIR ||
  path.join(os.tmpdir(), "moho-mcp");

export const config = {
  moho: {
    ipcDir: defaultIpcDir,
    pollInterval: 100,      // ms between checking for response files
    requestTimeout: 10000,  // ms before a request times out
    renderTimeout: 30000,   // ms timeout for render/screenshot requests
    batchTimeoutPerOp: 500, // additional ms per operation in a batch
    maxBatchSize: 50,       // maximum number of operations in a single batch
  },
  server: {
    name: "moho-mcp",
    version: "0.1.0",
  },
} as const;
