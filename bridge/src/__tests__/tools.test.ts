import { describe, it, expect, vi, beforeEach } from "vitest";
import { registerTools } from "../tools.js";
import { MohoClient } from "../moho-client.js";

// ---------------------------------------------------------------------------
// We mock MohoClient so we don't need a real TCP connection
// ---------------------------------------------------------------------------

vi.mock("../moho-client.js", () => {
  const MohoClient = vi.fn();
  MohoClient.prototype.isConnected = vi.fn().mockReturnValue(true);
  MohoClient.prototype.connect = vi.fn().mockResolvedValue(undefined);
  MohoClient.prototype.sendRequest = vi.fn().mockResolvedValue({ ok: true });
  MohoClient.prototype.disconnect = vi.fn();
  return { MohoClient };
});

// ---------------------------------------------------------------------------
// Minimal mock of McpServer that captures tool registrations
// ---------------------------------------------------------------------------

interface RegisteredTool {
  name: string;
  description: string;
  schema: Record<string, unknown>;
  handler: (...args: unknown[]) => Promise<unknown>;
}

function createMockMcpServer() {
  const tools: RegisteredTool[] = [];

  return {
    tools,
    tool(
      name: string,
      description: string,
      schema: Record<string, unknown>,
      handler: (...args: unknown[]) => Promise<unknown>,
    ) {
      tools.push({ name, description, schema, handler });
    },
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("registerTools", () => {
  let mockServer: ReturnType<typeof createMockMcpServer>;
  let client: MohoClient;

  beforeEach(() => {
    mockServer = createMockMcpServer();
    client = new MohoClient();
    vi.clearAllMocks();
  });

  it("registers tools without throwing", () => {
    expect(() =>
      registerTools(mockServer as unknown as Parameters<typeof registerTools>[0], client),
    ).not.toThrow();
  });

  it("registers exactly 25 tools", () => {
    registerTools(mockServer as unknown as Parameters<typeof registerTools>[0], client);
    expect(mockServer.tools).toHaveLength(25);
  });

  it("registers all expected tool names", () => {
    registerTools(mockServer as unknown as Parameters<typeof registerTools>[0], client);

    const names = mockServer.tools.map((t) => t.name);

    // Read-only query tools
    expect(names).toContain("document_getInfo");
    expect(names).toContain("document_getLayers");
    expect(names).toContain("layer_getProperties");
    expect(names).toContain("layer_getChildren");
    expect(names).toContain("layer_getBones");
    expect(names).toContain("bone_getProperties");
    expect(names).toContain("animation_getKeyframes");
    expect(names).toContain("animation_getFrameState");
    expect(names).toContain("mesh_getPoints");
    expect(names).toContain("mesh_getShapes");

    // Mutation tools
    expect(names).toContain("bone_setTransform");
    expect(names).toContain("bone_selectBone");
    expect(names).toContain("animation_setKeyframe");
    expect(names).toContain("animation_deleteKeyframe");
    expect(names).toContain("animation_setInterpolation");
    expect(names).toContain("document_setFrame");
    expect(names).toContain("layer_setTransform");
    expect(names).toContain("layer_setVisibility");
    expect(names).toContain("layer_setOpacity");
    expect(names).toContain("layer_setName");
    expect(names).toContain("layer_selectLayer");

    // Screenshot & input tools
    expect(names).toContain("document_screenshot");
    expect(names).toContain("input_mouseClick");
    expect(names).toContain("input_mouseDrag");
    expect(names).toContain("input_sendKeys");
  });

  it("each tool has a non-empty description", () => {
    registerTools(mockServer as unknown as Parameters<typeof registerTools>[0], client);

    for (const tool of mockServer.tools) {
      expect(tool.description).toBeTruthy();
      expect(typeof tool.description).toBe("string");
      expect(tool.description.length).toBeGreaterThan(0);
    }
  });

  describe("tool handlers", () => {
    beforeEach(() => {
      registerTools(
        mockServer as unknown as Parameters<typeof registerTools>[0],
        client,
      );
    });

    function findTool(name: string): RegisteredTool {
      const tool = mockServer.tools.find((t) => t.name === name);
      if (!tool) throw new Error(`Tool ${name} not found`);
      return tool;
    }

    it("document_getInfo handler returns success content on success", async () => {
      (client.sendRequest as ReturnType<typeof vi.fn>).mockResolvedValue({
        name: "doc.moho",
      });

      const tool = findTool("document_getInfo");
      const result = (await tool.handler({})) as {
        content: Array<{ type: string; text: string }>;
      };

      expect(result.content).toBeDefined();
      expect(result.content).toHaveLength(1);
      expect(result.content[0].type).toBe("text");

      const parsed = JSON.parse(result.content[0].text);
      expect(parsed.name).toBe("doc.moho");
    });

    it("handler returns error content on failure", async () => {
      (client.sendRequest as ReturnType<typeof vi.fn>).mockRejectedValue(
        new Error("Connection lost"),
      );

      const tool = findTool("document_getInfo");
      const result = (await tool.handler({})) as {
        content: Array<{ type: string; text: string }>;
        isError: boolean;
      };

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toBe("Connection lost");
    });

    it("handler calls ensureConnected (connect if not connected)", async () => {
      (client.isConnected as ReturnType<typeof vi.fn>).mockReturnValue(false);
      (client.sendRequest as ReturnType<typeof vi.fn>).mockResolvedValue({});

      const tool = findTool("document_getLayers");
      await tool.handler({});

      expect(client.connect).toHaveBeenCalled();
    });

    it("layer_getProperties handler passes layerId param", async () => {
      (client.sendRequest as ReturnType<typeof vi.fn>).mockResolvedValue({
        type: "vector",
      });

      const tool = findTool("layer_getProperties");
      await tool.handler({ layerId: 5 });

      expect(client.sendRequest).toHaveBeenCalledWith("layer.getProperties", {
        layerId: 5,
      });
    });

    it("bone_getProperties handler passes layerId and boneId params", async () => {
      (client.sendRequest as ReturnType<typeof vi.fn>).mockResolvedValue({
        angle: 45,
      });

      const tool = findTool("bone_getProperties");
      await tool.handler({ layerId: 1, boneId: 3 });

      expect(client.sendRequest).toHaveBeenCalledWith("bone.getProperties", {
        layerId: 1,
        boneId: 3,
      });
    });

    it("animation_getKeyframes handler passes layerId and channel params", async () => {
      (client.sendRequest as ReturnType<typeof vi.fn>).mockResolvedValue([]);

      const tool = findTool("animation_getKeyframes");
      await tool.handler({ layerId: 2, channel: "rotation" });

      expect(client.sendRequest).toHaveBeenCalledWith(
        "animation.getKeyframes",
        {
          layerId: 2,
          channel: "rotation",
        },
      );
    });

    it("animation_getFrameState handler passes layerId and frame params", async () => {
      (client.sendRequest as ReturnType<typeof vi.fn>).mockResolvedValue({
        frame: 10,
      });

      const tool = findTool("animation_getFrameState");
      await tool.handler({ layerId: 3, frame: 10 });

      expect(client.sendRequest).toHaveBeenCalledWith(
        "animation.getFrameState",
        {
          layerId: 3,
          frame: 10,
        },
      );
    });
  });
});
