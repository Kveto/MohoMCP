# MohoMCP Tool Reference

Complete reference for all 26 MCP tools and 2 knowledge resources.

---

## Document Tools

### `document_getInfo`

Get metadata about the currently open MOHO document.

**Parameters:** None

**Returns:**
```json
{
  "name": "MyAnimation",
  "filePath": "C:/Projects/MyAnimation.moho",
  "width": 1920,
  "height": 1080,
  "fps": 24,
  "startFrame": 0,
  "endFrame": 120,
  "currentFrame": 45
}
```

---

### `document_getLayers`

Get a hierarchical list of all layers in the document.

**Parameters:** None

**Returns:**
```json
{
  "totalLayers": 5,
  "layers": [
    {
      "id": 0,
      "name": "Character",
      "type": "group",
      "visible": true,
      "locked": false,
      "children": [
        {
          "id": 1,
          "name": "Body",
          "type": "vector",
          "visible": true,
          "locked": false,
          "children": []
        }
      ]
    }
  ]
}
```

---

### `document_setFrame`

Navigate to a specific frame on the MOHO timeline.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `frame` | number | Yes | The frame number to navigate to |

**Returns:**
```json
{ "success": true, "frame": 24 }
```

---

### `document_screenshot`

Render the MOHO scene or capture the full application window as a PNG image.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `mode` | `"scene"` \| `"full"` | No | `"scene"` (default): clean rendered frame via Lua. `"full"`: entire MOHO UI via Win32 capture |
| `frame` | number | No | Frame to render (defaults to current frame) |
| `width` | number | No | Output width in pixels (scene mode only, defaults to document width) |
| `height` | number | No | Output height in pixels (scene mode only, defaults to document height) |

**Returns:** MCP image content (base64-encoded PNG) plus metadata:
```json
{ "mode": "scene", "frame": 24, "width": 1920, "height": 1080 }
```

**Notes:**
- `mode="scene"` uses MOHO's `FileRender` API for a clean render without UI elements
- `mode="full"` uses Win32 `PrintWindow` to capture the entire application window including timeline, layers panel, toolbar, etc.
- Full mode is useful for identifying UI element positions before using `input_mouseClick`

---

## Layer Tools

### `layer_getProperties`

Get detailed properties of a specific layer.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID (0-indexed) |

**Returns:**
```json
{
  "id": 1,
  "name": "Body",
  "type": "vector",
  "visible": true,
  "locked": false,
  "opacity": 1.0,
  "blendMode": "normal",
  "transform": {
    "translation": { "x": 0, "y": 0 },
    "rotation": 0,
    "scale": { "x": 1, "y": 1 }
  }
}
```

**Layer types:** `vector`, `bone`, `group`, `image`, `audio`, `switch`, `particle`, `note`, `patch`

---

### `layer_getChildren`

Get direct children of a group layer.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID of the group |

**Returns:**
```json
{
  "layerId": 0,
  "children": [
    { "id": 1, "name": "Body", "type": "vector" },
    { "id": 2, "name": "Skeleton", "type": "bone" }
  ]
}
```

---

### `layer_getBones`

Get all bones in a bone layer.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID of the bone layer |

**Returns:**
```json
{
  "layerId": 2,
  "boneCount": 3,
  "bones": [
    { "id": 0, "name": "Hip", "parentId": -1, "position": { "x": 0, "y": 0 } },
    { "id": 1, "name": "Torso", "parentId": 0, "position": { "x": 0, "y": 0.5 } },
    { "id": 2, "name": "Head", "parentId": 1, "position": { "x": 0, "y": 1.0 } }
  ]
}
```

---

### `layer_setTransform`

Set the transform of a layer at a specific frame. Creates keyframes automatically. All transform parameters are optional — only supplied values are changed.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID |
| `frame` | number | Yes | Frame number to set the keyframe at |
| `transX` | number | No | Layer X translation |
| `transY` | number | No | Layer Y translation |
| `rotation` | number | No | Layer rotation in radians |
| `scaleX` | number | No | Layer X scale |
| `scaleY` | number | No | Layer Y scale |

---

### `layer_setVisibility`

Show or hide a layer.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID |
| `visible` | boolean | Yes | Whether the layer should be visible |

---

### `layer_setOpacity`

Set the opacity/transparency of a layer at a specific frame.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID |
| `frame` | number | Yes | Frame number for the keyframe |
| `opacity` | number | Yes | Opacity value: 0.0 (transparent) to 1.0 (opaque) |

---

### `layer_setName`

Rename a layer.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID |
| `name` | string | Yes | New name for the layer |

---

### `layer_selectLayer`

Select a layer in the MOHO UI.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID to select |

---

## Bone Tools

### `bone_getProperties`

Get detailed properties of a specific bone.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID of the bone layer |
| `boneId` | number | Yes | 0-based bone index within the layer |

**Returns:**
```json
{
  "id": 1,
  "name": "Torso",
  "position": { "x": 0, "y": 0.5 },
  "angle": 0,
  "scale": 1,
  "length": 0.5,
  "parentId": 0,
  "selected": false,
  "constraints": {
    "enabled": false,
    "minAngle": -180,
    "maxAngle": 180
  }
}
```

---

### `bone_setTransform`

Set the transform of a bone at a specific frame. Creates keyframes automatically. All transform parameters are optional — only supplied values are changed.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID of the bone layer |
| `boneId` | number | Yes | 0-based bone index |
| `frame` | number | Yes | Frame number for the keyframe |
| `angle` | number | No | Bone rotation in radians |
| `posX` | number | No | Bone X position |
| `posY` | number | No | Bone Y position |
| `scale` | number | No | Bone scale factor |

---

### `bone_selectBone`

Select a bone in the MOHO UI (deselects all others first).

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID of the bone layer |
| `boneId` | number | Yes | 0-based bone index |

---

## Animation Tools

### `animation_getKeyframes`

Get keyframe data for a specific animation channel.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID |
| `channel` | string | Yes | Channel name: `translation`, `rotation`, `scale`, `opacity`, `shear` |

**Returns:**
```json
{
  "layerId": 1,
  "channel": "translation",
  "keyCount": 3,
  "keyframes": [
    { "frame": 0, "value": { "x": 0, "y": 0 }, "interpolation": "smooth" },
    { "frame": 12, "value": { "x": 1, "y": 0.5 }, "interpolation": "smooth" },
    { "frame": 24, "value": { "x": 0, "y": 0 }, "interpolation": "smooth" }
  ]
}
```

---

### `animation_getFrameState`

Get the full animation state of a layer at a specific frame (interpolated values).

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID |
| `frame` | number | Yes | Frame number to query |

**Returns:**
```json
{
  "layerId": 1,
  "frame": 12,
  "translation": { "x": 1, "y": 0.5 },
  "rotation": 0,
  "scale": { "x": 1, "y": 1 },
  "opacity": 1.0,
  "visible": true
}
```

---

### `animation_setKeyframe`

Set a keyframe value on an animation channel.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID |
| `channel` | string | Yes | Channel name: `translation`, `rotation`, `scale`, `opacity`, `shear` |
| `frame` | number | Yes | Frame number for the keyframe |
| `value` | number \| `{x, y}` | Yes | Scalar for `rotation`/`opacity`/`shear`, `{x, y}` for `translation`/`scale` |

**Examples:**
```json
// Scalar channel (rotation)
{ "layerId": 1, "channel": "rotation", "frame": 24, "value": 1.57 }

// Vec2 channel (translation)
{ "layerId": 1, "channel": "translation", "frame": 24, "value": { "x": 2.0, "y": 0.5 } }
```

---

### `animation_deleteKeyframe`

Remove a keyframe from an animation channel.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID |
| `channel` | string | Yes | Channel name |
| `frame` | number | Yes | Frame number of the keyframe to delete |

---

### `animation_setInterpolation`

Set the interpolation/easing mode on an existing keyframe.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID |
| `channel` | string | Yes | Channel name |
| `frame` | number | Yes | Frame number of the keyframe |
| `mode` | string | Yes | `"linear"`, `"smooth"`, `"ease_in"`, `"ease_out"`, or `"step"` |

---

## Mesh/Vector Tools

### `mesh_getPoints`

Get all mesh points (vertices) in a vector layer.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID of the vector layer |

**Returns:**
```json
{
  "layerId": 1,
  "pointCount": 4,
  "points": [
    { "index": 0, "position": { "x": -1, "y": -1 }, "selected": false },
    { "index": 1, "position": { "x": 1, "y": -1 }, "selected": false },
    { "index": 2, "position": { "x": 1, "y": 1 }, "selected": false },
    { "index": 3, "position": { "x": -1, "y": 1 }, "selected": false }
  ]
}
```

---

### `mesh_getShapes`

Get all shapes (filled regions, outlines) in a vector layer.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `layerId` | number | Yes | Absolute layer ID of the vector layer |

**Returns:**
```json
{
  "layerId": 1,
  "shapeCount": 1,
  "shapes": [
    {
      "index": 0,
      "name": "Shape 1",
      "edgeCount": 4,
      "fillColor": "#FF0000",
      "strokeColor": "#000000",
      "strokeWidth": 2.0,
      "hasFill": true,
      "hasStroke": true
    }
  ]
}
```

---

## Input Tools

### `input_mouseClick`

Click at coordinates relative to the MOHO window top-left.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `x` | number | Yes | X coordinate (window-relative) |
| `y` | number | Yes | Y coordinate (window-relative) |
| `button` | `"left"` \| `"right"` \| `"middle"` | No | Mouse button (default: `"left"`) |
| `clickType` | `"single"` \| `"double"` | No | Click type (default: `"single"`) |

**Workflow:** Use `document_screenshot(mode="full")` to see the UI, identify the pixel coordinates of a button/tool, then click it.

---

### `input_mouseDrag`

Drag from one point to another in the MOHO window.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `startX` | number | Yes | Drag start X (window-relative) |
| `startY` | number | Yes | Drag start Y (window-relative) |
| `endX` | number | Yes | Drag end X (window-relative) |
| `endY` | number | Yes | Drag end Y (window-relative) |
| `button` | `"left"` \| `"right"` | No | Mouse button (default: `"left"`) |
| `steps` | number | No | Number of intermediate points for smooth drag (default: 10) |

**Use cases:** Dragging timeline playhead, adjusting sliders, drawing operations.

---

### `input_sendKeys`

Send a keyboard shortcut to the MOHO window.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `keys` | string | Yes | Shortcut string, e.g. `"ctrl+z"`, `"ctrl+shift+z"`, `"space"`, `"a"`, `"f5"` |

**Examples:**
| Keys | Action |
|------|--------|
| `"ctrl+z"` | Undo |
| `"ctrl+shift+z"` | Redo |
| `"ctrl+s"` | Save |
| `"space"` | Play/pause animation |
| `"a"` | Activate Add Point tool (Draw group) |
| `"b"` | Activate Select Bone tool (Bone group) |
| `"f5"` | New frame |
| `"delete"` | Delete selected |

See the `moho://shortcuts` resource for the complete shortcut reference.

---

## Batch Execution

### `batch_execute`

Execute multiple MOHO operations in a single IPC round-trip. This dramatically reduces latency — a batch of N operations takes ~300ms total instead of ~300ms per individual call.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `operations` | array | Yes | Array of 1–50 operations to execute sequentially |
| `stopOnError` | boolean | No | If `true`, stop after the first failure (default: `false`) |

Each operation in the array:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `method` | string | Yes | Dot-notation method name (e.g. `"bone.setTransform"`) |
| `params` | object | No | Parameters for the method (matches the individual tool's schema) |

**Restrictions:**
- Maximum 50 operations per batch
- `document.screenshot` is not allowed (too heavyweight)
- `batch.execute` cannot be nested

**Returns:**
```json
{
  "results": [
    { "success": true, "index": 1, "result": { "..." : "..." } },
    { "success": false, "index": 2, "error": { "code": -32602, "message": "Missing required parameter: layerId" } },
    { "success": true, "index": 3, "result": { "..." : "..." } }
  ],
  "summary": {
    "total": 3,
    "executed": 3,
    "succeeded": 2,
    "failed": 1,
    "stoppedEarly": false
  }
}
```

**Example — Animate a bone across 5 frames:**
```json
{
  "operations": [
    { "method": "bone.setTransform", "params": { "layerId": 1, "boneId": 0, "frame": 1, "angle": 0.1 } },
    { "method": "bone.setTransform", "params": { "layerId": 1, "boneId": 0, "frame": 6, "angle": 0.3 } },
    { "method": "bone.setTransform", "params": { "layerId": 1, "boneId": 0, "frame": 12, "angle": 0.0 } },
    { "method": "bone.setTransform", "params": { "layerId": 1, "boneId": 0, "frame": 18, "angle": -0.3 } },
    { "method": "bone.setTransform", "params": { "layerId": 1, "boneId": 0, "frame": 24, "angle": 0.0 } }
  ]
}
```

**Example — Bulk read (gather document info + layers + specific layer properties):**
```json
{
  "operations": [
    { "method": "document.getInfo" },
    { "method": "document.getLayers" },
    { "method": "layer.getProperties", "params": { "layerId": 0 } },
    { "method": "layer.getProperties", "params": { "layerId": 1 } }
  ]
}
```

**Example — Set keyframes with easing in one batch:**
```json
{
  "operations": [
    { "method": "animation.setKeyframe", "params": { "layerId": 1, "channel": "rotation", "frame": 0, "value": 0 } },
    { "method": "animation.setKeyframe", "params": { "layerId": 1, "channel": "rotation", "frame": 24, "value": 3.14 } },
    { "method": "animation.setInterpolation", "params": { "layerId": 1, "channel": "rotation", "frame": 0, "mode": "ease_out" } },
    { "method": "animation.setInterpolation", "params": { "layerId": 1, "channel": "rotation", "frame": 24, "mode": "ease_in" } }
  ]
}
```

**`stopOnError` behavior:**

When `stopOnError: true`, if operation #3 out of 5 fails:
- Operations 1–2: executed normally (results included)
- Operation 3: failed (error included)
- Operations 4–5: skipped with `"Skipped (stopOnError)"` message

This is useful when later operations depend on earlier ones succeeding (e.g. creating a keyframe then setting its interpolation).

**When to use `batch_execute`:**
- Setting bone transforms across multiple frames or bones
- Reading several layer/bone properties at once
- Setting keyframes and then configuring their interpolation modes
- Any sequence of operations where you don't need to read one result before deciding the next
- Mixed read + write operations in a single round-trip

**When to use individual calls instead:**
- You need to read a result before deciding what to do next (data-dependent branching)
- Using `document_screenshot` (not batchable)
- A single standalone operation

**Important:** Method names inside batch operations use **dot notation** (`"bone.setTransform"`), not the underscore format used in MCP tool names (`bone_setTransform`).

---

## Knowledge Resources

### `moho://shortcuts`

Static MCP resource containing all Moho Pro 14 keyboard shortcuts as JSON.

**Categories:**
- `file` — File menu (Ctrl+N, Ctrl+S, Ctrl+E, etc.)
- `edit` — Edit menu (Ctrl+Z, Ctrl+C, Ctrl+V, etc.)
- `draw` — Draw menu (Ctrl+T, Ctrl+P, Ctrl+M, etc.)
- `bone` — Bone menu (Ctrl+F, Alt+Ctrl+F)
- `animation` — Animation menu (Ctrl+Shift+N)
- `view` — View menu (Ctrl+G, Ctrl+L, Ctrl+J, etc.)
- `window` — Window panel toggles (Ctrl+Shift+E/K/W/Y/F/M/L/O)
- `windowDocking` — Dock/undock panels (Alt+Shift+Ctrl+...)
- `navigation` — Global navigation (Escape, Home, Enter, Tab, Arrows, Space, Delete)
- `timeline` — Timeline operations (F5/F6, Alt+Backspace, Ctrl+1-9, Shift+{/})
- `style` — Style window (]/[)
- `layers` — Layers window (Alt+D, Alt+C)
- `workspaceView` — Workspace navigation (Alt+Shift+{/}, RMB drag)
- `contextual` — Context-dependent modifiers (Shift, Alt, Up/Down)
- `toolActivation` — Single-key tool shortcuts organized by group (draw, fill, bone, layer, camera)

---

### `moho://tools`

Static MCP resource containing all Moho Pro 14 tools as JSON, organized by toolbar group.

**Groups:** `draw` (24 tools), `fill` (11 tools), `bone` (11 tools), `layer` (13 tools), `camera` (4 tools), `workspace` (4 tools)

Each tool entry:
```json
{
  "name": "Add Point",
  "shortcut": "A",
  "description": "Create new curve segments by clicking to place points",
  "modifiers": ["Alt: force start a new separate line", "Space: weld two points together"],
  "animatable": false
}
```

Includes Moho 14 new tools: Liquid Shapes, Curver, Compressible Curver, Quad Mesh, Multi-Stroke Fill, Connect and Create, Merge Shapes.

---

## Error Handling

All tools return standard JSON-RPC 2.0 errors:

| Code | Meaning |
|------|---------|
| -32700 | Parse error — invalid JSON |
| -32600 | Invalid request — missing required JSON-RPC fields |
| -32601 | Method not found — method not in allow-list |
| -32602 | Invalid parameters — wrong type or missing required params |
| -32603 | Internal error — unexpected Lua error |
| -32001 | No document — no MOHO document is open |
| -32002 | Layer not found — invalid layer ID |
| -32003 | Bone not found — invalid bone ID |
| -32004 | Invalid frame — frame number out of range |
| -32010 | MOHO error — general MOHO API failure |

## Layer IDs

Layer IDs are **absolute indices** within the document, assigned at runtime by MOHO:

- **0-indexed** (first layer is 0)
- **Session-scoped** — IDs may change when the document is reopened
- Use `document_getLayers` to discover current layer IDs
- Group layers contain children; use `layer_getChildren` to traverse the hierarchy
