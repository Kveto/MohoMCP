# Installation Guide

## Prerequisites

- **Moho Pro 14** (14.4 or later recommended) installed
- **Node.js** 18+ installed ([nodejs.org](https://nodejs.org))
- **Windows 10/11** (required for screenshot and input tools; read/write tools are cross-platform)

## Step 1: Install the MOHO Plugin

The plugin consists of Lua files that run inside MOHO's scripting environment.

### Locate Your MOHO Scripts Directory

| Platform | Path |
|----------|------|
| Windows (default install) | `C:\Program Files\Moho 14\Resources\Support\Scripts\Menu\` |
| Windows (user scripts) | `C:\Users\<username>\Documents\Moho\scripts\menu\` |
| macOS | `~/Library/Application Support/Moho/scripts/menu/` |

### Copy Files

Copy the following from the `moho-plugin/` directory into your MOHO scripts/menu folder:

```
MohoMCP_Server.lua          <- Main menu script & DrawMe hooks
MohoMCP_Poller.lua          <- Polling utilities
json.lua                    <- JSON encoder/decoder library
moho_mcp/                   <- Module directory
  ├── server.lua            <- File-based IPC server core
  ├── protocol.lua          <- JSON-RPC 2.0 protocol handling
  ├── validator.lua         <- Method allow-list & parameter validation
  └── tools/                <- Tool handler implementations
      ├── document.lua      <- document.* methods (getInfo, getLayers, setFrame, screenshot)
      ├── layer.lua         <- layer.* methods (getProperties, setTransform, setVisibility, etc.)
      ├── bone.lua          <- bone.* methods (getProperties, setTransform, selectBone)
      ├── animation.lua     <- animation.* methods (getKeyframes, setKeyframe, etc.)
      ├── mesh.lua          <- mesh.* methods (getPoints, getShapes)
      └── batch.lua         <- batch.execute (multi-operation batching)
```

### Verify Installation

1. Open Moho Pro 14
2. Check the **Scripts** menu — you should see **"MohoMCP Server"**
3. Click it to start the server — check MOHO's script console for `[MohoMCP] Server started`

## Step 2: Build the Bridge Server

```bash
cd bridge
npm install
npm run build
```

This compiles the TypeScript source to JavaScript in `bridge/dist/`.

## Step 3: Configure Your MCP Client

### Claude Code

Place a `.mcp.json` in your project root (or wherever you run Claude Code from):

```json
{
  "mcpServers": {
    "moho-mcp": {
      "command": "node",
      "args": ["C:/path/to/MohoMCP/bridge/dist/index.js"]
    }
  }
}
```

Claude Code will automatically discover and connect to the server.

### Claude Desktop

Edit your Claude Desktop configuration file:

- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`
- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`

Add the MohoMCP server:

```json
{
  "mcpServers": {
    "moho-mcp": {
      "command": "node",
      "args": ["C:/path/to/MohoMCP/bridge/dist/index.js"]
    }
  }
}
```

## Step 4: Start Everything

1. **Open Moho Pro 14** and load a project
2. **Start the plugin:** Scripts > MohoMCP Server
3. **Start Claude Desktop** (or open Claude Code in a directory with `.mcp.json`) — the bridge auto-connects

## How Communication Works

The bridge and MOHO communicate via JSON files in a temp directory:

```
%TEMP%\moho-mcp\
├── status.json          <- Written by Lua when server starts
├── req_1.json           <- Bridge writes request
├── resp_1.json          <- Lua writes response, deletes req file
└── ...
```

1. Bridge writes a JSON-RPC 2.0 request as `req_<id>.json`
2. MOHO Lua plugin polls for new request files during DrawMe/IsEnabled callbacks
3. Lua processes the request, writes `resp_<id>.json`, deletes the request file
4. Bridge reads the response, deletes the response file

A background PowerShell keep-alive process periodically forces MOHO viewport repaints (~4 Hz) so the Lua polling loop stays responsive even when the user isn't interacting with MOHO.

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MOHO_MCP_IPC_DIR` | `%TEMP%\moho-mcp` | Directory for file-based IPC communication |

### Internal Timeouts

Configured in `bridge/src/config.ts`:

| Setting | Default | Description |
|---------|---------|-------------|
| `pollInterval` | 100ms | How often bridge checks for response files |
| `requestTimeout` | 10,000ms | Max wait for a normal Lua response |
| `renderTimeout` | 30,000ms | Max wait for screenshot/render operations |
| `batchTimeoutPerOp` | 500ms | Additional timeout per operation in a batch |
| `maxBatchSize` | 50 | Maximum operations per `batch_execute` call |

## Troubleshooting

### Server doesn't appear in Scripts menu

- Ensure `MohoMCP_Server.lua` is in the correct scripts directory
- Restart MOHO after copying files
- Check MOHO's script console for Lua load errors

### Bridge can't connect (no status.json)

- Ensure MOHO is running and the MohoMCP Server script has been activated
- Check that `%TEMP%\moho-mcp\status.json` exists
- Verify the IPC directory with: `ls %TEMP%\moho-mcp\`

### Requests time out

- MOHO may not be repainting frequently enough. The keep-alive mechanism should handle this automatically, but verify that MOHO's main window is visible (not minimized)
- Check MOHO's script console for error messages
- Try increasing `requestTimeout` in `config.ts`

### Screenshot returns black image

- Ensure a document is open in MOHO
- For `mode="scene"`: MOHO needs a valid frame to render
- For `mode="full"`: The MOHO window must be visible (not minimized or occluded)

### Input tools don't work

- Mouse/keyboard tools require the MOHO window to be in the foreground
- Coordinates are relative to the MOHO window's top-left corner
- Use `document_screenshot(mode="full")` first to identify UI element positions
