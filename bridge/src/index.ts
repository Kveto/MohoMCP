#!/usr/bin/env node

/**
 * MohoMCP Bridge Server
 *
 * Entry point for the MCP server that bridges MCP clients (Claude Desktop,
 * Claude Code) to a MOHO Lua TCP server running on localhost.
 *
 * Communication flow:
 *   MCP Client <--stdio--> This Bridge <--TCP/JSON-RPC--> MOHO Lua Plugin
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { config } from "./config.js";
import { MohoClient } from "./moho-client.js";
import { registerTools } from "./tools.js";
import { registerResources } from "./resources.js";

// ---------------------------------------------------------------------------
// Bootstrap
// ---------------------------------------------------------------------------

async function main(): Promise<void> {
  process.stderr.write(
    `[moho-mcp] Starting ${config.server.name} v${config.server.version}\n`,
  );

  // Create the MCP server
  const server = new McpServer(
    {
      name: config.server.name,
      version: config.server.version,
    },
    {
      instructions: [
        "MohoMCP controls Moho animation software via file-based IPC. Each individual tool call incurs ~200-400ms of IPC overhead (polling latency).",
        "",
        "## CRITICAL: Use batch_execute to minimize latency",
        "",
        "Always use the batch_execute tool when you need 2 or more operations. A batch of N operations completes in a single IPC round-trip (~300ms total), whereas N individual calls take ~300ms × N.",
        "",
        "### When to batch (ALWAYS prefer this)",
        "- Setting bone transforms across multiple frames or multiple bones",
        "- Reading several layer/bone properties at once",
        "- Setting keyframes and then setting their interpolation modes",
        "- Any sequence of document.setFrame, bone.setTransform, animation.setKeyframe, etc.",
        "- Mixed read+write sequences where reads don't gate later operations",
        "",
        "### When to use individual calls",
        "- You need to read a result BEFORE deciding the next operation (data-dependent branching)",
        "- Using document_screenshot (not allowed in batches — too heavyweight)",
        "- A single standalone operation",
        "",
        "### Batch method names use dot notation",
        'Inside batch_execute operations, method names use dots (e.g. "bone.setTransform", "layer.getProperties"), NOT underscores. The params match each tool\'s parameter schema exactly.',
        "",
        "### Example: Animate a bone wave across 5 frames",
        "Instead of 5 separate bone_setTransform calls, use ONE batch_execute:",
        '{',
        '  "operations": [',
        '    { "method": "bone.setTransform", "params": { "layerId": 1, "boneId": 0, "frame": 1, "angle": 0.1 } },',
        '    { "method": "bone.setTransform", "params": { "layerId": 1, "boneId": 0, "frame": 5, "angle": 0.3 } },',
        '    { "method": "bone.setTransform", "params": { "layerId": 1, "boneId": 0, "frame": 10, "angle": -0.1 } },',
        '    { "method": "bone.setTransform", "params": { "layerId": 1, "boneId": 0, "frame": 15, "angle": -0.3 } },',
        '    { "method": "bone.setTransform", "params": { "layerId": 1, "boneId": 0, "frame": 20, "angle": 0.0 } }',
        '  ]',
        '}',
        "This takes ~300ms instead of ~1500ms.",
      ].join("\n"),
    },
  );

  // Create the MOHO TCP client (connection is lazy — established on first tool call)
  const mohoClient = new MohoClient();

  // Register all MOHO tools on the MCP server
  registerTools(server, mohoClient);

  // Register static knowledge resources (shortcuts, tools reference)
  registerResources(server);

  // Wire up stdio transport (stdin/stdout for MCP protocol, stderr for logging)
  const transport = new StdioServerTransport();
  await server.connect(transport);

  process.stderr.write("[moho-mcp] MCP server running on stdio transport\n");

  // -----------------------------------------------------------------------
  // Graceful shutdown
  // -----------------------------------------------------------------------

  const shutdown = (): void => {
    process.stderr.write("[moho-mcp] Shutting down...\n");
    mohoClient.disconnect();
    process.exit(0);
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
  process.on("SIGHUP", shutdown);
}

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------

main().catch((err: unknown) => {
  process.stderr.write(
    `[moho-mcp] Fatal error: ${err instanceof Error ? err.message : String(err)}\n`,
  );
  process.exit(1);
});
