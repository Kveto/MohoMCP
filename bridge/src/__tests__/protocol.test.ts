import { describe, it, expect } from "vitest";
import { createRequest, parseResponse, ErrorCodes } from "../protocol.js";

// ---------------------------------------------------------------------------
// createRequest
// ---------------------------------------------------------------------------

describe("createRequest", () => {
  it("produces a newline-delimited string", () => {
    const result = createRequest(1, "test.method", { foo: "bar" });
    expect(result.endsWith("\n")).toBe(true);
  });

  it("produces valid JSON (before the trailing newline)", () => {
    const result = createRequest(1, "test.method", { key: 42 });
    const parsed = JSON.parse(result.trim());
    expect(parsed).toBeDefined();
  });

  it("includes all required JSON-RPC 2.0 fields", () => {
    const result = createRequest(7, "document.getInfo", { layerId: 3 });
    const parsed = JSON.parse(result.trim());

    expect(parsed.jsonrpc).toBe("2.0");
    expect(parsed.id).toBe(7);
    expect(parsed.method).toBe("document.getInfo");
    expect(parsed.params).toEqual({ layerId: 3 });
  });

  it("handles empty params", () => {
    const result = createRequest(1, "noop", {});
    const parsed = JSON.parse(result.trim());

    expect(parsed.params).toEqual({});
  });

  it("preserves complex nested params", () => {
    const params = { a: [1, 2], b: { nested: true } };
    const result = createRequest(99, "complex", params);
    const parsed = JSON.parse(result.trim());

    expect(parsed.params).toEqual(params);
  });
});

// ---------------------------------------------------------------------------
// parseResponse
// ---------------------------------------------------------------------------

describe("parseResponse", () => {
  it("parses a valid success response", () => {
    const raw = JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      result: { name: "test.moho" },
    });

    const resp = parseResponse(raw);
    expect(resp.jsonrpc).toBe("2.0");
    expect(resp.id).toBe(1);
    expect(resp.result).toEqual({ name: "test.moho" });
    expect(resp.error).toBeUndefined();
  });

  it("parses a valid error response", () => {
    const raw = JSON.stringify({
      jsonrpc: "2.0",
      id: 2,
      error: { code: -32601, message: "Method not found" },
    });

    const resp = parseResponse(raw);
    expect(resp.jsonrpc).toBe("2.0");
    expect(resp.id).toBe(2);
    expect(resp.error).toBeDefined();
    expect(resp.error!.code).toBe(-32601);
    expect(resp.error!.message).toBe("Method not found");
  });

  it("throws on empty string", () => {
    expect(() => parseResponse("")).toThrow("Empty response from MOHO server");
  });

  it("throws on whitespace-only string", () => {
    expect(() => parseResponse("   \n  ")).toThrow(
      "Empty response from MOHO server",
    );
  });

  it("throws on invalid JSON", () => {
    expect(() => parseResponse("{not valid json}")).toThrow(
      "Invalid JSON from MOHO server",
    );
  });

  it("throws on missing jsonrpc field", () => {
    const raw = JSON.stringify({ id: 1, result: "ok" });
    expect(() => parseResponse(raw)).toThrow("Unexpected jsonrpc version");
  });

  it("throws on wrong jsonrpc version", () => {
    const raw = JSON.stringify({ jsonrpc: "1.0", id: 1, result: "ok" });
    expect(() => parseResponse(raw)).toThrow("Unexpected jsonrpc version");
  });

  it("throws when response is not an object (e.g. array)", () => {
    // Arrays pass typeof === "object" check, so parseResponse falls through
    // to the jsonrpc version validation, which catches the problem.
    expect(() => parseResponse("[1,2,3]")).toThrow();
  });

  it("throws when response is a primitive", () => {
    expect(() => parseResponse('"hello"')).toThrow(
      "MOHO server response is not a JSON object",
    );
  });

  it("handles trailing whitespace in input", () => {
    const raw = JSON.stringify({ jsonrpc: "2.0", id: 5, result: null }) + "  \n";
    const resp = parseResponse(raw);
    expect(resp.id).toBe(5);
  });
});

// ---------------------------------------------------------------------------
// ErrorCodes
// ---------------------------------------------------------------------------

describe("ErrorCodes", () => {
  it("has PARSE_ERROR = -32700", () => {
    expect(ErrorCodes.PARSE_ERROR).toBe(-32700);
  });

  it("has INVALID_REQUEST = -32600", () => {
    expect(ErrorCodes.INVALID_REQUEST).toBe(-32600);
  });

  it("has METHOD_NOT_FOUND = -32601", () => {
    expect(ErrorCodes.METHOD_NOT_FOUND).toBe(-32601);
  });

  it("has INVALID_PARAMS = -32602", () => {
    expect(ErrorCodes.INVALID_PARAMS).toBe(-32602);
  });

  it("has INTERNAL_ERROR = -32603", () => {
    expect(ErrorCodes.INTERNAL_ERROR).toBe(-32603);
  });

  it("has NO_DOCUMENT = -32001", () => {
    expect(ErrorCodes.NO_DOCUMENT).toBe(-32001);
  });

  it("has LAYER_NOT_FOUND = -32002", () => {
    expect(ErrorCodes.LAYER_NOT_FOUND).toBe(-32002);
  });

  it("has BONE_NOT_FOUND = -32003", () => {
    expect(ErrorCodes.BONE_NOT_FOUND).toBe(-32003);
  });

  it("has INVALID_FRAME = -32004", () => {
    expect(ErrorCodes.INVALID_FRAME).toBe(-32004);
  });

  it("has MOHO_ERROR = -32010", () => {
    expect(ErrorCodes.MOHO_ERROR).toBe(-32010);
  });

  it("contains exactly 10 error codes", () => {
    expect(Object.keys(ErrorCodes)).toHaveLength(10);
  });
});
