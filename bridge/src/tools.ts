/**
 * MCP tool definitions and handlers for the MOHO bridge.
 *
 * Each tool maps 1-to-1 to a JSON-RPC method exposed by the MOHO Lua server.
 */

import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { MohoClient } from "./moho-client.js";
import { config } from "./config.js";
import { captureAppWindow } from "./window-capture.js";
import { sendMouseClick, sendMouseDrag, sendKeys } from "./win32-input.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Formats a successful MOHO result as MCP text content.
 */
function successContent(result: unknown): { content: Array<{ type: "text"; text: string }> } {
  return {
    content: [
      {
        type: "text" as const,
        text: JSON.stringify(result, null, 2),
      },
    ],
  };
}

/**
 * Formats an error as an MCP error response.
 */
function errorContent(err: unknown): {
  content: Array<{ type: "text"; text: string }>;
  isError: true;
} {
  const message = err instanceof Error ? err.message : String(err);
  return {
    content: [
      {
        type: "text" as const,
        text: message,
      },
    ],
    isError: true,
  };
}

/**
 * Ensures the client is connected before making a request.
 * If not connected, attempts to connect first.
 */
async function ensureConnected(client: MohoClient): Promise<void> {
  if (!client.isConnected()) {
    await client.connect();
  }
}

// ---------------------------------------------------------------------------
// Tool registration
// ---------------------------------------------------------------------------

/**
 * Register all MOHO tools on the given MCP server instance.
 */
export function registerTools(server: McpServer, client: MohoClient): void {
  // 1. document.getInfo — No input params
  server.tool(
    "document_getInfo",
    "Get information about the currently open MOHO document (name, path, dimensions, frame range, FPS)",
    {},
    async () => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("document.getInfo");
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 2. document.getLayers — No input params
  server.tool(
    "document_getLayers",
    "Get a list of all top-level layers in the current MOHO document",
    {},
    async () => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("document.getLayers");
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 3. layer.getProperties — layerId required
  server.tool(
    "layer_getProperties",
    "Get detailed properties of a specific layer (type, visibility, transform, etc.)",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
    },
    async ({ layerId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.getProperties", {
          layerId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 4. layer.getChildren — layerId required
  server.tool(
    "layer_getChildren",
    "Get child layers of a group layer",
    {
      layerId: z.number().describe("The numeric ID of the parent group layer"),
    },
    async ({ layerId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.getChildren", {
          layerId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 5. layer.getBones — layerId required
  server.tool(
    "layer_getBones",
    "Get all bones in a bone layer",
    {
      layerId: z.number().describe("The numeric ID of the bone layer"),
    },
    async ({ layerId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.getBones", {
          layerId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 6. bone.getProperties — layerId and boneId required
  server.tool(
    "bone_getProperties",
    "Get detailed properties of a specific bone (position, angle, scale, parent, etc.)",
    {
      layerId: z.number().describe("The numeric ID of the bone layer"),
      boneId: z.number().describe("The numeric ID of the bone within the layer"),
    },
    async ({ layerId, boneId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("bone.getProperties", {
          layerId,
          boneId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 7. animation.getKeyframes — layerId and channel required
  server.tool(
    "animation_getKeyframes",
    "Get keyframe data for a specific animation channel on a layer",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      channel: z
        .string()
        .describe(
          'The animation channel name (e.g. "translation", "rotation", "scale", "opacity")',
        ),
    },
    async ({ layerId, channel }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("animation.getKeyframes", {
          layerId,
          channel,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 8. animation.getFrameState — layerId and frame required
  server.tool(
    "animation_getFrameState",
    "Get the full animation state of a layer at a specific frame",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      frame: z.number().describe("The frame number to query"),
    },
    async ({ layerId, frame }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("animation.getFrameState", {
          layerId,
          frame,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 9. mesh.getPoints — layerId required
  server.tool(
    "mesh_getPoints",
    "Get all mesh points (vertices) in a vector layer",
    {
      layerId: z.number().describe("The numeric ID of the vector layer"),
    },
    async ({ layerId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("mesh.getPoints", {
          layerId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 10. mesh.getShapes — layerId required
  server.tool(
    "mesh_getShapes",
    "Get all shapes (filled regions) in a vector layer",
    {
      layerId: z.number().describe("The numeric ID of the vector layer"),
    },
    async ({ layerId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("mesh.getShapes", {
          layerId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // =========================================================================
  // Phase 2: Write Tools
  // =========================================================================

  // 11. bone.setTransform — Pose a bone at a frame
  server.tool(
    "bone_setTransform",
    "Set the transform (angle, position, scale) of a bone at a specific frame. Creates keyframes automatically. All transform params (angle, posX, posY, scale) are optional — only supplied values are changed.",
    {
      layerId: z.number().describe("The numeric ID of the bone layer"),
      boneId: z.number().describe("The 0-based bone index within the skeleton"),
      frame: z.number().describe("The frame number to set the keyframe at"),
      angle: z
        .number()
        .optional()
        .describe("Bone rotation in radians"),
      posX: z
        .number()
        .optional()
        .describe("Bone X position"),
      posY: z
        .number()
        .optional()
        .describe("Bone Y position"),
      scale: z
        .number()
        .optional()
        .describe("Bone scale factor"),
    },
    async ({ layerId, boneId, frame, angle, posX, posY, scale }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("bone.setTransform", {
          layerId,
          boneId,
          frame,
          angle,
          posX,
          posY,
          scale,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 12. bone.selectBone — Select a bone in the UI
  server.tool(
    "bone_selectBone",
    "Select a bone in the MOHO UI (deselects all others first)",
    {
      layerId: z.number().describe("The numeric ID of the bone layer"),
      boneId: z.number().describe("The 0-based bone index within the skeleton"),
    },
    async ({ layerId, boneId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("bone.selectBone", {
          layerId,
          boneId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 13. animation.setKeyframe — Set a keyframe value on any animation channel
  server.tool(
    "animation_setKeyframe",
    "Set a keyframe value on an animation channel. For vec2 channels (translation, scale), pass value as {x, y}. For scalar channels (rotation, opacity, shear), pass a number.",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      channel: z
        .string()
        .describe(
          'The animation channel name (e.g. "translation", "rotation", "scale", "opacity", "shear")',
        ),
      frame: z.number().describe("The frame number to set the keyframe at"),
      value: z
        .union([z.number(), z.object({ x: z.number(), y: z.number() })])
        .describe("The keyframe value — number for scalar channels, {x, y} for vec2 channels"),
    },
    async ({ layerId, channel, frame, value }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("animation.setKeyframe", {
          layerId,
          channel,
          frame,
          value,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 14. animation.deleteKeyframe — Remove a keyframe
  server.tool(
    "animation_deleteKeyframe",
    "Delete a keyframe from an animation channel at a specific frame",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      channel: z
        .string()
        .describe(
          'The animation channel name (e.g. "translation", "rotation", "scale", "opacity")',
        ),
      frame: z.number().describe("The frame number of the keyframe to delete"),
    },
    async ({ layerId, channel, frame }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("animation.deleteKeyframe", {
          layerId,
          channel,
          frame,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 15. animation.setInterpolation — Set easing mode on a keyframe
  server.tool(
    "animation_setInterpolation",
    "Set the interpolation/easing mode on an existing keyframe (linear, smooth, ease_in, ease_out, step)",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      channel: z
        .string()
        .describe(
          'The animation channel name (e.g. "translation", "rotation", "scale", "opacity")',
        ),
      frame: z.number().describe("The frame number of the keyframe"),
      mode: z
        .string()
        .describe(
          'Interpolation mode: "linear", "smooth", "ease_in", "ease_out", or "step"',
        ),
    },
    async ({ layerId, channel, frame, mode }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("animation.setInterpolation", {
          layerId,
          channel,
          frame,
          mode,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 16. document.setFrame — Navigate to a specific frame
  server.tool(
    "document_setFrame",
    "Navigate to a specific frame on the MOHO timeline",
    {
      frame: z.number().describe("The frame number to navigate to"),
    },
    async ({ frame }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("document.setFrame", {
          frame,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 17. layer.setTransform — Move/rotate/scale a layer at a frame
  server.tool(
    "layer_setTransform",
    "Set the transform (translation, rotation, scale) of a layer at a specific frame. All transform params are optional — only supplied values are changed.",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      frame: z.number().describe("The frame number to set the keyframe at"),
      transX: z
        .number()
        .optional()
        .describe("Layer X translation"),
      transY: z
        .number()
        .optional()
        .describe("Layer Y translation"),
      rotation: z
        .number()
        .optional()
        .describe("Layer rotation in radians"),
      scaleX: z
        .number()
        .optional()
        .describe("Layer X scale"),
      scaleY: z
        .number()
        .optional()
        .describe("Layer Y scale"),
    },
    async ({ layerId, frame, transX, transY, rotation, scaleX, scaleY }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.setTransform", {
          layerId,
          frame,
          transX,
          transY,
          rotation,
          scaleX,
          scaleY,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 18. layer.setVisibility — Show/hide a layer
  server.tool(
    "layer_setVisibility",
    "Show or hide a layer in the MOHO scene",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      visible: z.boolean().describe("Whether the layer should be visible"),
    },
    async ({ layerId, visible }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.setVisibility", {
          layerId,
          visible,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 19. layer.setOpacity — Set layer transparency at a frame
  server.tool(
    "layer_setOpacity",
    "Set the opacity/transparency of a layer at a specific frame (0.0 = fully transparent, 1.0 = fully opaque)",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      frame: z.number().describe("The frame number to set the keyframe at"),
      opacity: z.number().describe("Opacity value from 0.0 (transparent) to 1.0 (opaque)"),
    },
    async ({ layerId, frame, opacity }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.setOpacity", {
          layerId,
          frame,
          opacity,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 20. layer.setName — Rename a layer
  server.tool(
    "layer_setName",
    "Rename a layer in the MOHO scene",
    {
      layerId: z.number().describe("The numeric ID of the layer"),
      name: z.string().describe("The new name for the layer"),
    },
    async ({ layerId, name }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.setName", {
          layerId,
          name,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 21. layer.selectLayer — Select a layer in the UI
  server.tool(
    "layer_selectLayer",
    "Select a layer in the MOHO UI",
    {
      layerId: z.number().describe("The numeric ID of the layer to select"),
    },
    async ({ layerId }) => {
      try {
        await ensureConnected(client);
        const result = await client.sendRequest("layer.selectLayer", {
          layerId,
        });
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // =========================================================================
  // Phase 3: Visual Feedback
  // =========================================================================

  // 22. document.screenshot — Render the scene and return as an image
  server.tool(
    "document_screenshot",
    'Render the MOHO scene or capture the full application window and return as an image. Use mode "scene" (default) for a clean rendered frame, or "full" for the entire MOHO UI including timeline, layers panel, etc.',
    {
      mode: z
        .enum(["scene", "full"])
        .optional()
        .describe(
          '"scene" = rendered animation frame only (default), "full" = entire MOHO application window via Win32 capture',
        ),
      frame: z
        .number()
        .optional()
        .describe("Frame number to render (defaults to current frame)"),
      width: z
        .number()
        .optional()
        .describe("Output width in pixels (defaults to document width, scene mode only)"),
      height: z
        .number()
        .optional()
        .describe("Output height in pixels (defaults to document height, scene mode only)"),
    },
    async ({ mode, frame, width, height }) => {
      try {
        const captureMode = mode ?? "scene";

        if (captureMode === "full") {
          // Navigate to requested frame first (via Lua), then Win32 capture
          if (frame !== undefined) {
            await ensureConnected(client);
            await client.sendRequest("document.setFrame", { frame });
          }

          const tempDir = path.join(os.tmpdir(), "moho-mcp");
          await fs.promises.mkdir(tempDir, { recursive: true });
          const tempPath = path.join(
            tempDir,
            `capture_${Date.now()}.png`,
          );

          const dims = await captureAppWindow(tempPath);

          const imageBuffer = await fs.promises.readFile(tempPath);
          const base64 = imageBuffer.toString("base64");
          await fs.promises.unlink(tempPath).catch(() => {});

          return {
            content: [
              {
                type: "image" as const,
                mimeType: "image/png" as const,
                data: base64,
              },
              {
                type: "text" as const,
                text: JSON.stringify({
                  mode: "full",
                  frame: frame ?? null,
                  width: dims.width,
                  height: dims.height,
                }),
              },
            ],
          };
        }

        // Scene mode — use MOHO's FileRender via Lua
        await ensureConnected(client);
        const params: Record<string, unknown> = {};
        if (frame !== undefined) params.frame = frame;
        if (width !== undefined) params.width = width;
        if (height !== undefined) params.height = height;

        const result = (await client.sendRequest(
          "document.screenshot",
          params,
          { timeout: config.moho.renderTimeout },
        )) as {
          success: boolean;
          filePath: string;
          frame: number;
          width: number;
          height: number;
        };

        // Read the rendered PNG from disk
        const imageBuffer = await fs.promises.readFile(result.filePath);
        const base64 = imageBuffer.toString("base64");

        // Clean up the temp file
        await fs.promises.unlink(result.filePath).catch(() => {});

        return {
          content: [
            {
              type: "image" as const,
              mimeType: "image/png" as const,
              data: base64,
            },
            {
              type: "text" as const,
              text: JSON.stringify({
                mode: "scene",
                frame: result.frame,
                width: result.width,
                height: result.height,
              }),
            },
          ],
        };
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // =========================================================================
  // Phase 3b: Input Tools (Mouse & Keyboard)
  // =========================================================================

  // 23. input.mouseClick — Click at a position in the MOHO window
  server.tool(
    "input_mouseClick",
    "Click at (x, y) coordinates relative to the MOHO window top-left. Use with document_screenshot(mode='full') to identify UI element positions, then click them.",
    {
      x: z.number().describe("X coordinate relative to MOHO window top-left"),
      y: z.number().describe("Y coordinate relative to MOHO window top-left"),
      button: z
        .enum(["left", "right", "middle"])
        .optional()
        .describe('Mouse button: "left" (default), "right", "middle"'),
      clickType: z
        .enum(["single", "double"])
        .optional()
        .describe('Click type: "single" (default), "double"'),
    },
    async ({ x, y, button, clickType }) => {
      try {
        const result = await sendMouseClick(
          x,
          y,
          button ?? "left",
          clickType ?? "single",
        );
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 24. input.mouseDrag — Drag from one point to another in the MOHO window
  server.tool(
    "input_mouseDrag",
    "Drag from (startX, startY) to (endX, endY) relative to the MOHO window. Useful for dragging timeline playhead, sliders, or drawing operations.",
    {
      startX: z.number().describe("Drag start X coordinate (window-relative)"),
      startY: z.number().describe("Drag start Y coordinate (window-relative)"),
      endX: z.number().describe("Drag end X coordinate (window-relative)"),
      endY: z.number().describe("Drag end Y coordinate (window-relative)"),
      button: z
        .enum(["left", "right"])
        .optional()
        .describe('Mouse button: "left" (default), "right"'),
      steps: z
        .number()
        .optional()
        .describe("Number of intermediate points for smooth drag (default 10)"),
    },
    async ({ startX, startY, endX, endY, button, steps }) => {
      try {
        const result = await sendMouseDrag(
          startX,
          startY,
          endX,
          endY,
          button ?? "left",
          steps ?? 10,
        );
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // 25. input.sendKeys — Send keyboard shortcut to MOHO
  server.tool(
    "input_sendKeys",
    'Send a keyboard shortcut to the MOHO window. Supports modifiers (ctrl, shift, alt) combined with keys. Examples: "ctrl+z" (undo), "ctrl+shift+z" (redo), "space" (play/pause), "delete", "ctrl+s" (save), "f5".',
    {
      keys: z
        .string()
        .describe(
          'Shortcut string like "ctrl+z", "ctrl+shift+z", "space", "delete", "ctrl+s", "f5", "a"',
        ),
    },
    async ({ keys }) => {
      try {
        const result = await sendKeys(keys);
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );

  // =========================================================================
  // Batch Execution
  // =========================================================================

  // 26. batch.execute — Execute multiple operations in a single IPC round-trip
  server.tool(
    "batch_execute",
    "Execute multiple MOHO operations in a single IPC round-trip (~300ms total) instead of one round-trip per call (~300ms each). " +
      "PREFER THIS over individual calls whenever you have 2+ operations.\n\n" +
      "Method names use DOT notation: \"bone.setTransform\", \"layer.getProperties\", \"animation.setKeyframe\", etc. " +
      "Params match each tool's schema exactly.\n\n" +
      "Supports all methods EXCEPT: document.screenshot (too slow), batch.execute (no nesting).\n\n" +
      "Common patterns:\n" +
      "- Multi-frame animation: batch bone.setTransform across frames 1,5,10,15,...\n" +
      "- Bulk reads: batch document.getInfo + document.getLayers + layer.getProperties for several layers\n" +
      "- Keyframe + easing: batch animation.setKeyframe then animation.setInterpolation for each\n" +
      "- Multi-bone pose: batch bone.setTransform for each bone in a skeleton at the same frame\n" +
      "- Layer setup: batch layer.setName + layer.setVisibility + layer.setOpacity\n\n" +
      "Returns { results: [{ success, index, result|error }], summary: { total, executed, succeeded, failed, stoppedEarly } }. " +
      "Use stopOnError: true when later operations depend on earlier ones succeeding.",
    {
      operations: z
        .array(
          z.object({
            method: z.string().describe("The JSON-RPC method name (e.g. \"bone.setTransform\", \"layer.getProperties\")"),
            params: z.record(z.unknown()).optional().describe("Parameters for the method"),
          }),
        )
        .min(1)
        .max(config.moho.maxBatchSize)
        .describe("Array of operations to execute sequentially"),
      stopOnError: z
        .boolean()
        .optional()
        .default(false)
        .describe("If true, stop executing after the first failed operation"),
    },
    async ({ operations, stopOnError }) => {
      try {
        await ensureConnected(client);
        const timeout =
          config.moho.requestTimeout +
          operations.length * config.moho.batchTimeoutPerOp;
        const result = await client.sendRequest(
          "batch.execute",
          { operations, stopOnError },
          { timeout },
        );
        return successContent(result);
      } catch (err) {
        return errorContent(err);
      }
    },
  );
}
