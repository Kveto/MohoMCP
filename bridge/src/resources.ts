/**
 * MCP resource definitions for MOHO knowledge.
 *
 * Provides static reference data (shortcuts, tools) scraped from the official
 * MOHO manual so that Claude can look up the right shortcut or tool without
 * needing a round-trip to the running application.
 *
 * Target version: Moho Pro 14.4
 *
 * Data sources:
 *   - https://www.lostmarble.com/moho/manual/shortcuts.html
 *   - https://defkey.com/moho-13-shortcuts
 *   - https://www.lostmarble.com/moho/manual/ (individual tool pages)
 *   - https://moho.lostmarble.com/pages/features (Moho 14 new features)
 */

import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

// ---------------------------------------------------------------------------
// Shortcuts data
// ---------------------------------------------------------------------------

const shortcuts = {
  file: [
    { keys: "Ctrl+N", action: "New" },
    { keys: "Ctrl+O", action: "Open" },
    { keys: "Ctrl+W", action: "Close" },
    { keys: "Alt+Ctrl+W", action: "Close all" },
    { keys: "Ctrl+S", action: "Save" },
    { keys: "Ctrl+Shift+S", action: "Save As" },
    { keys: "Alt+Shift+Ctrl+S", action: "Save all" },
    { keys: "Ctrl+Shift+P", action: "Project settings" },
    { keys: "Alt+Ctrl+M", action: "Refresh media" },
    { keys: "Ctrl+R", action: "Preview" },
    { keys: "Ctrl+Shift+R", action: "Preview animation" },
    { keys: "Ctrl+E", action: "Export animation" },
    { keys: "Alt+Ctrl+E", action: "Export animation with previous settings" },
    { keys: "Ctrl+B", action: "Moho exporter" },
    { keys: "Alt+Ctrl+O", action: "Open profile" },
    { keys: "Alt+Ctrl+S", action: "Save profile" },
    { keys: "Alt+Ctrl+Y", action: "General import" },
    { keys: "Ctrl+Q", action: "Quit" },
  ],
  edit: [
    { keys: "Ctrl+Z", action: "Undo" },
    { keys: "Ctrl+Shift+Z", action: "Redo" },
    { keys: "Ctrl+X", action: "Cut" },
    { keys: "Ctrl+C", action: "Copy" },
    { keys: "Ctrl+V", action: "Paste" },
    { keys: "Ctrl+A", action: "Select all" },
    { keys: "Ctrl+I", action: "Select inverse" },
  ],
  draw: [
    { keys: "Ctrl+T", action: "Insert text" },
    { keys: "Alt+Ctrl+L", action: "Reset line width" },
    { keys: "Ctrl+D", action: "Random line width" },
    { keys: "Ctrl+P", action: "Peak" },
    { keys: "Ctrl+M", action: "Smooth" },
    { keys: "Ctrl+Shift+H", action: "Hide shape" },
    { keys: "Ctrl+Shift+U", action: "Show all shapes" },
    { keys: "Ctrl+F", action: "Freeze points" },
  ],
  bone: [
    { keys: "Alt+Ctrl+F", action: "Use selected bones for flexi-binding" },
    { keys: "Ctrl+F", action: "Freeze pose" },
  ],
  animation: [
    { keys: "Ctrl+Shift+N", action: "Nudge physics object" },
  ],
  view: [
    { keys: "Alt+Ctrl+9", action: "Zoom in" },
    { keys: "Alt+Ctrl+8", action: "Zoom out" },
    { keys: "Ctrl+G", action: "Enable grid" },
    { keys: "Ctrl+Shift+G", action: "Grid settings" },
    { keys: "Ctrl+Shift+V", action: "Video safe zones" },
    { keys: "Ctrl+J", action: "Show output only" },
    { keys: "Ctrl+L", action: "Enable onion skins" },
    { keys: "Ctrl+Y", action: "Select tracing image" },
    { keys: "Ctrl+U", action: "Show tracing image" },
    { keys: "Ctrl+Shift+C", action: "Show curves" },
    { keys: "Ctrl+Shift+A", action: "Fade unselected layers" },
    { keys: "Ctrl+Shift+D", action: "Design mode" },
    { keys: "Ctrl+Shift+2", action: "Stereo" },
    { keys: "Alt+Ctrl+J", action: "Show document tabs" },
  ],
  window: [
    { keys: "Ctrl+Shift+E", action: "Tools" },
    { keys: "Ctrl+Shift+K", action: "Layers" },
    { keys: "Ctrl+Shift+W", action: "Timeline" },
    { keys: "Ctrl+Shift+Y", action: "Style" },
    { keys: "Ctrl+Shift+F", action: "Keyframe" },
    { keys: "Ctrl+Shift+M", action: "Actions" },
    { keys: "Ctrl+Shift+L", action: "Light" },
    { keys: "Ctrl+Shift+O", action: "BitmapColor" },
    { keys: "Alt+L", action: "Library" },
    { keys: "Ctrl+Shift+B", action: "Blend morphs" },
    { keys: "Ctrl+Shift+I", action: "Layer settings" },
    { keys: "Ctrl+Shift+J", action: "Layer comps" },
  ],
  windowDocking: [
    { keys: "Alt+Shift+Ctrl+E", action: "Dock/undock Tools" },
    { keys: "Alt+Shift+Ctrl+K", action: "Dock/undock Layers" },
    { keys: "Alt+Shift+Ctrl+J", action: "Dock/undock Layer comps" },
    { keys: "Alt+Shift+Ctrl+W", action: "Dock/undock Timeline" },
    { keys: "Alt+Shift+Ctrl+Y", action: "Dock/undock Style" },
    { keys: "Alt+Shift+Ctrl+F", action: "Dock/undock Keyframe" },
    { keys: "Alt+Shift+Ctrl+M", action: "Dock/undock Actions" },
    { keys: "Alt+Shift+Ctrl+L", action: "Dock/undock Light" },
    { keys: "Alt+Shift+Ctrl+O", action: "Dock/undock BitmapColor" },
  ],
  navigation: [
    { keys: "Escape", action: "Auto-fit view to active layer (Shift: zoom to selection)" },
    { keys: "Home", action: "Reset view to see overall project" },
    { keys: "Enter", action: "Deselect all points" },
    { keys: "Tab", action: "Select all points connected to current selection" },
    { keys: "Left", action: "Step back one frame (Shift: rewind to start)" },
    { keys: "Right", action: "Step forward one frame (Shift: advance to end)" },
    { keys: "Space", action: "Play / stop animation" },
    { keys: "Delete", action: "Delete selected points / shapes / bones" },
    { keys: "Shift+Z", action: "Activate previous tool" },
    { keys: "`", action: "Close / open secondary windows" },
    { keys: "Alt+Shift+Ctrl+R", action: "Reload tools and brushes" },
  ],
  timeline: [
    { keys: "F5", action: "New frame" },
    { keys: "F6", action: "Duplicate frame" },
    { keys: "Shift+F5", action: "Delete frame" },
    { keys: "Alt+Backspace", action: "Delete selected keyframe(s)" },
    { keys: "Alt+C", action: "Copy selected keyframe(s)" },
    { keys: "Alt+V", action: "Paste previously copied keyframe(s)" },
    { keys: "Ctrl+1", action: "Interpolation: Linear" },
    { keys: "Ctrl+2", action: "Interpolation: Smooth" },
    { keys: "Ctrl+3", action: "Interpolation: Ease in/out" },
    { keys: "Ctrl+4", action: "Interpolation: Ease in" },
    { keys: "Ctrl+5", action: "Interpolation: Ease out" },
    { keys: "Ctrl+6", action: "Interpolation: Bezier" },
    { keys: "Ctrl+7", action: "Interpolation: Step" },
    { keys: "Ctrl+8", action: "Interpolation: Noisy" },
    { keys: "Ctrl+9", action: "Interpolation: Cycle" },
    { keys: "Shift+{", action: "Previous selected key" },
    { keys: "Shift+}", action: "Next selected key" },
    { keys: "Alt+Shift++", action: "Zoom in timeline" },
    { keys: "Alt+Shift+-", action: "Zoom out timeline" },
    { keys: "Alt+Shift+A", action: "Pan timeline up" },
    { keys: "Alt+Shift+Z", action: "Pan timeline down" },
    { keys: "Alt+Shift+X", action: "Auto zoom timeline" },
    { keys: "Page Up", action: "Zoom in graph mode (Shift: move graph up)" },
    { keys: "Page Down", action: "Zoom out graph mode (Shift: move graph down)" },
    { keys: "End", action: "Auto-zoom timeline by active animation channel" },
  ],
  style: [
    { keys: "]", action: "Increase line width" },
    { keys: "[", action: "Decrease line width" },
  ],
  layers: [
    { keys: "Alt+D", action: "Activate previous switch layer child" },
    { keys: "Alt+C", action: "Activate next switch layer child" },
  ],
  workspaceView: [
    { keys: "Alt+Shift+{", action: "Rotate view left" },
    { keys: "Alt+Shift+}", action: "Rotate view right" },
    { keys: "RMB drag", action: "Pan workspace" },
    { keys: "Shift+RMB drag", action: "Zoom workspace" },
    { keys: "Ctrl+RMB drag", action: "Rotate workspace" },
  ],
  contextual: [
    { keys: "Shift", action: "Constrain movement to horizontal/vertical or 45° angles (most tools)" },
    { keys: "Alt", action: "Color pick from canvas (Fill tools); depth/Z-axis (Layer translate)" },
    { keys: "Up", action: "Raise shape one level (Shift: to top) / Select parent bone" },
    { keys: "Down", action: "Lower shape one level (Shift: to bottom) / Select child bone" },
  ],
  toolActivation: {
    draw: [
      { keys: "G", action: "Select Points" },
      { keys: "T", action: "Transform Points" },
      { keys: "A", action: "Add Point" },
      { keys: "F", action: "Freehand" },
      { keys: "J", action: "Blob Brush" },
      { keys: "S", action: "Draw Shape" },
      { keys: "E", action: "Eraser" },
      { keys: "R", action: "Point Reduction" },
      { keys: "D", action: "Delete Edge" },
      { keys: "C", action: "Curvature" },
      { keys: "X", action: "Magnet" },
      { keys: "N", action: "Noise" },
    ],
    fill: [
      { keys: "Q", action: "Select Shape" },
      { keys: "U", action: "Create Shape" },
      { keys: "P", action: "Paint Bucket" },
      { keys: "W", action: "Line Width" },
      { keys: "H", action: "Hide Edge" },
      { keys: "K", action: "Color Points" },
      { keys: "C", action: "Crop" },
      { keys: "A", action: "Video Tracking" },
    ],
    bone: [
      { keys: "B", action: "Select Bone" },
      { keys: "T", action: "Transform Bone" },
      { keys: "A", action: "Add Bone" },
      { keys: "P", action: "Reparent Bone" },
      { keys: "S", action: "Bone Strength" },
      { keys: "Z", action: "Manipulate Bones" },
      { keys: "I", action: "Bind Points" },
    ],
    layer: [
      { keys: "M", action: "Transform Layer" },
      { keys: "O", action: "Set Origin" },
      { keys: "L", action: "Eyedropper" },
    ],
    camera: [
      { keys: "4", action: "Track Camera" },
    ],
  },
};

// ---------------------------------------------------------------------------
// Tools data
// ---------------------------------------------------------------------------

interface ToolEntry {
  name: string;
  shortcut: string | null;
  description: string;
  modifiers?: string[];
  animatable: boolean;
}

const tools: Record<string, ToolEntry[]> = {
  draw: [
    {
      name: "Select Points",
      shortcut: "G",
      description: "Select/deselect points via rectangle, single click, curve selection, or filled area",
      modifiers: ["Shift: extend selection", "Alt: prevent curve/shape selection", "Ctrl: lasso mode"],
      animatable: false,
    },
    {
      name: "Transform Points",
      shortcut: "T",
      description: "Move, scale, and rotate selected points. Combines translate/scale/rotate in one tool",
      modifiers: ["Shift: constrain to horizontal/vertical", "Space: weld points together"],
      animatable: true,
    },
    {
      name: "Add Point",
      shortcut: "A",
      description: "Create new curve segments by clicking to place points. Can extend existing curves or start new ones",
      modifiers: ["Alt: force start a new separate line", "Space: weld two points together"],
      animatable: false,
    },
    {
      name: "Freehand",
      shortcut: "F",
      description: "Draw complex shapes by dragging the mouse. Sensitivity controls how many points are created",
      animatable: false,
    },
    {
      name: "Blob Brush",
      shortcut: "J",
      description: "Paint filled shapes with a brush-like tool. Creates filled vector shapes as you paint",
      animatable: false,
    },
    {
      name: "Draw Shape",
      shortcut: "S",
      description: "Quick shape creation: rectangles, ovals, arrows. Choose shape type from options bar",
      modifiers: ["Shift: constrain proportions (square/circle)", "Alt: draw from center"],
      animatable: false,
    },
    {
      name: "Eraser",
      shortcut: "E",
      description: "Erase portions of drawn shapes by painting over them",
      animatable: false,
    },
    {
      name: "Point Reduction",
      shortcut: "R",
      description: "Simplify curves by removing unnecessary points while preserving shape",
      animatable: false,
    },
    {
      name: "Delete Edge",
      shortcut: "D",
      description: "Remove curve segments between points while keeping the points themselves",
      animatable: false,
    },
    {
      name: "Curvature",
      shortcut: "C",
      description: "Adjust the smoothness level of curves passing through selected points",
      animatable: true,
    },
    {
      name: "Magnet",
      shortcut: "X",
      description: "Move points based on proximity — nearby points move more, distant points less",
      animatable: false,
    },
    {
      name: "Noise",
      shortcut: "N",
      description: "Move points in random directions for organic distortion effects",
      animatable: true,
    },
    {
      name: "Shear Points X",
      shortcut: null,
      description: "Slant selected points left or right horizontally",
      animatable: true,
    },
    {
      name: "Shear Points Y",
      shortcut: null,
      description: "Slant selected points up or down vertically",
      animatable: true,
    },
    {
      name: "Perspective Points H",
      shortcut: null,
      description: "Add horizontal perspective effect to selected points",
      animatable: true,
    },
    {
      name: "Perspective Points V",
      shortcut: null,
      description: "Add vertical perspective effect to selected points",
      animatable: true,
    },
    {
      name: "Bend Points H",
      shortcut: null,
      description: "Bend selected points horizontally. Works best on wider groups",
      animatable: true,
    },
    {
      name: "Bend Points V",
      shortcut: null,
      description: "Bend selected points vertically. Works best on taller groups",
      animatable: true,
    },
    {
      name: "Flip Points H",
      shortcut: null,
      description: "Mirror selected points horizontally",
      animatable: true,
    },
    {
      name: "Flip Points V",
      shortcut: null,
      description: "Mirror selected points vertically",
      animatable: true,
    },
    // --- Moho 14 new draw tools ---
    {
      name: "Liquid Shapes",
      shortcut: null,
      description: "Draw and animate soft shapes. Combine, Subtract, Intersect, or Blend shapes in real-time for elemental animation or expressive rigging",
      animatable: true,
    },
    {
      name: "Curver",
      shortcut: null,
      description: "Bend vectors and images freely. Rig with Bones and Smart Bones for tails, hair, snakes, tentacles",
      animatable: true,
    },
    {
      name: "Compressible Curver",
      shortcut: null,
      description: "Like Curver but preserves volume when bending, preventing stretching artifacts",
      animatable: true,
    },
    {
      name: "Quad Mesh",
      shortcut: null,
      description: "Animate artwork in true perspective using four-point quad shapes. Attach quads to artwork for 3D-like deformation",
      animatable: true,
    },
  ],
  fill: [
    {
      name: "Select Shape",
      shortcut: "Q",
      description: "Select an existing shape (fill or outline) for editing",
      modifiers: [
        "Ctrl+Down: select lower shape in stack",
        "Ctrl+Up: select higher shape in stack",
        "Alt: color pick from canvas",
        "Alt+Ctrl: push color to other shapes",
      ],
      animatable: false,
    },
    {
      name: "Create Shape",
      shortcut: "U",
      description: "Select edges/regions then press Space to create a filled shape or outline",
      modifiers: ["Alt: color pick from canvas", "Alt+Ctrl: push color to other shapes"],
      animatable: false,
    },
    {
      name: "Paint Bucket",
      shortcut: "P",
      description: "Click on an enclosed region to instantly create a filled shape",
      animatable: false,
    },
    {
      name: "Line Width",
      shortcut: "W",
      description: "Adjust the width of a line at a specific point for tapering effects",
      animatable: false,
    },
    {
      name: "Hide Edge",
      shortcut: "H",
      description: "Hide specific edges from outlines without affecting the fill",
      animatable: false,
    },
    {
      name: "Color Points",
      shortcut: "K",
      description: "Assign per-point colors for gradient effects along curves",
      animatable: false,
    },
    {
      name: "Crop",
      shortcut: "C",
      description: "Crop the visible area of a layer",
      animatable: false,
    },
    {
      name: "Video Tracking",
      shortcut: "A",
      description: "Track motion in video reference layers",
      animatable: false,
    },
    // --- Moho 14 new fill tools ---
    {
      name: "Multi-Stroke Fill",
      shortcut: null,
      description: "Quickly fill drawings that span multiple strokes. Select multiple strokes and fill them as one shape",
      animatable: false,
    },
    {
      name: "Connect and Create",
      shortcut: null,
      description: "Connect separate strokes and create a filled shape in one step",
      animatable: false,
    },
    {
      name: "Merge Shapes",
      shortcut: null,
      description: "Combine multiple shapes into a single unified shape",
      animatable: false,
    },
  ],
  bone: [
    {
      name: "Select Bone",
      shortcut: "B",
      description: "Click on a bone to select it for deletion or adding child bones. Click elsewhere to deselect",
      animatable: false,
    },
    {
      name: "Transform Bone",
      shortcut: "T",
      description: "Reposition bones after creation. Combines translate/rotate/scale in one tool",
      modifiers: [
        "Shift: constrain to horizontal/vertical or 45° angles",
        "Ctrl+Arrow: nudge selected bone",
        "Shift+Ctrl+Arrow: larger nudge increments",
      ],
      animatable: true,
    },
    {
      name: "Add Bone",
      shortcut: "A",
      description: "Create new bones: click sets base, drag sets endpoint. Parent is determined by prior selection",
      modifiers: ["Shift: constrain direction to 45° angles"],
      animatable: false,
    },
    {
      name: "Reparent Bone",
      shortcut: "P",
      description: "Change a bone's parent. Click new parent (blue highlight) or background for root",
      animatable: false,
    },
    {
      name: "Bone Strength",
      shortcut: "S",
      description: "Adjust influence region around bones. Drag side to side to grow/shrink the influence area",
      animatable: false,
    },
    {
      name: "Manipulate Bones",
      shortcut: "Z",
      description: "Test skeleton at frame 0 (temporary) or create animation keyframes at later frames",
      animatable: true,
    },
    {
      name: "Bind Points",
      shortcut: "I",
      description: "Select vector points to bind to bones. Press Space to confirm binding",
      animatable: false,
    },
    {
      name: "Scale Bone",
      shortcut: null,
      description: "Change the length of a bone during animation (not at frame 0)",
      animatable: true,
    },
    {
      name: "Rotate Bone",
      shortcut: null,
      description: "Change bone direction by dragging the tip around the base",
      modifiers: ["Shift: constrain to 45° multiples"],
      animatable: true,
    },
    {
      name: "Bind Layer",
      shortcut: null,
      description: "Connect entire layers to specific bones for coordinated movement",
      animatable: false,
    },
    {
      name: "Offset Bone",
      shortcut: null,
      description: "Apply additional movement starting at frame 1 to simplify complex character setup",
      animatable: false,
    },
  ],
  layer: [
    {
      name: "Transform Layer",
      shortcut: "M",
      description: "Move the entire layer. Combines translate/scale/rotate controls",
      modifiers: [
        "Shift: constrain to horizontal/vertical",
        "Alt: move in depth/Z-axis",
        "Ctrl+Arrow: nudge by arrow keys",
      ],
      animatable: true,
    },
    {
      name: "Set Origin",
      shortcut: "O",
      description: "Click to set the rotation/resize pivot point for the layer",
      animatable: false,
    },
    {
      name: "Eyedropper",
      shortcut: "L",
      description: "Sample colors and styles from existing shapes on the canvas",
      animatable: false,
    },
    {
      name: "Scale Layer",
      shortcut: null,
      description: "Resize entire layer using corner and edge handles",
      modifiers: ["Alt: maintain volume for squash/stretch effect"],
      animatable: true,
    },
    {
      name: "Rotate Layer Z",
      shortcut: null,
      description: "Spin layer around the Z-axis (screen plane)",
      modifiers: ["Shift: constrain to 45° increments"],
      animatable: true,
    },
    {
      name: "Rotate Layer X",
      shortcut: null,
      description: "Rotate layer around the X (horizontal) axis in 3D space",
      animatable: true,
    },
    {
      name: "Rotate Layer Y",
      shortcut: null,
      description: "Rotate layer around the Y (vertical) axis in 3D space",
      animatable: true,
    },
    {
      name: "Shear Layer X",
      shortcut: null,
      description: "Slant layer left or right horizontally",
      animatable: true,
    },
    {
      name: "Shear Layer Y",
      shortcut: null,
      description: "Slant layer up or down vertically",
      animatable: true,
    },
    {
      name: "Switch Layer",
      shortcut: null,
      description: "Specialized tool for Switch layers — popup menu selects active sub-layer",
      animatable: true,
    },
    {
      name: "Particle Layer",
      shortcut: null,
      description: "Specialized tool for Particle layers — controls emission on/off",
      animatable: true,
    },
    {
      name: "Flip Layer H",
      shortcut: null,
      description: "Mirror layer horizontally (button click action)",
      animatable: true,
    },
    {
      name: "Flip Layer V",
      shortcut: null,
      description: "Mirror layer vertically (button click action)",
      animatable: true,
    },
  ],
  camera: [
    {
      name: "Track Camera",
      shortcut: "4",
      description: "Move the camera up/down and side-to-side. Show Path option displays motion trajectory",
      modifiers: ["Shift: constrain to horizontal/vertical", "Alt: move camera forward/backward in depth"],
      animatable: true,
    },
    {
      name: "Zoom Camera",
      shortcut: null,
      description: "Adjust magnification by changing field of view angle (focal length)",
      animatable: true,
    },
    {
      name: "Roll Camera",
      shortcut: null,
      description: "Roll/tilt the camera view side to side",
      animatable: true,
    },
    {
      name: "Pan/Tilt Camera",
      shortcut: null,
      description: "Alter viewing angle: vertical drag tilts, horizontal drag pans. Best for layered 3D scenes",
      modifiers: ["Shift: constrain rotation to single direction"],
      animatable: true,
    },
  ],
  workspace: [
    {
      name: "Pan Workspace",
      shortcut: null,
      description: "Click and drag to move the view side-to-side and up/down. Also: RMB drag",
      animatable: false,
    },
    {
      name: "Zoom Workspace",
      shortcut: null,
      description: "Adjust magnification level. Also: Shift+RMB drag",
      animatable: false,
    },
    {
      name: "Rotate Workspace",
      shortcut: null,
      description: "Temporarily rotate the workspace for drawing from different angles. Also: Ctrl+RMB drag. Home to reset",
      animatable: false,
    },
    {
      name: "Orbit Workspace",
      shortcut: null,
      description: "View scene from external perspective, like holding the scene and turning it around. Home to reset",
      animatable: false,
    },
  ],
};

// ---------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------

export function registerResources(server: McpServer): void {
  server.resource(
    "shortcuts",
    "moho://shortcuts",
    { description: "Comprehensive Moho Pro 14 keyboard shortcuts organized by category" },
    (_uri) => ({
      contents: [
        {
          uri: "moho://shortcuts",
          mimeType: "application/json",
          text: JSON.stringify(shortcuts, null, 2),
        },
      ],
    }),
  );

  server.resource(
    "tools",
    "moho://tools",
    { description: "All Moho Pro 14 tools organized by toolbar group with shortcuts and descriptions" },
    (_uri) => ({
      contents: [
        {
          uri: "moho://tools",
          mimeType: "application/json",
          text: JSON.stringify(tools, null, 2),
        },
      ],
    }),
  );
}
