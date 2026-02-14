/**
 * JSON-RPC 2.0 types and helpers for communication with the MOHO Lua TCP server.
 * Messages are framed as newline-delimited JSON over TCP.
 */

// ---------------------------------------------------------------------------
// Interfaces
// ---------------------------------------------------------------------------

export interface JsonRpcRequest {
  jsonrpc: "2.0";
  id: number;
  method: string;
  params?: Record<string, unknown>;
}

export interface JsonRpcError {
  code: number;
  message: string;
  data?: unknown;
}

export interface JsonRpcResponse {
  jsonrpc: "2.0";
  id: number | null;
  result?: unknown;
  error?: JsonRpcError;
}

// ---------------------------------------------------------------------------
// Error code constants (mirror the Lua side)
// ---------------------------------------------------------------------------

export const ErrorCodes = {
  PARSE_ERROR: -32700,
  INVALID_REQUEST: -32600,
  METHOD_NOT_FOUND: -32601,
  INVALID_PARAMS: -32602,
  INTERNAL_ERROR: -32603,

  // Application-specific error codes (reserved range -32000 to -32099)
  NO_DOCUMENT: -32001,
  LAYER_NOT_FOUND: -32002,
  BONE_NOT_FOUND: -32003,
  INVALID_FRAME: -32004,
  MOHO_ERROR: -32010,
} as const;

export type ErrorCode = (typeof ErrorCodes)[keyof typeof ErrorCodes];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Serializes a JSON-RPC 2.0 request to a newline-delimited JSON string
 * suitable for sending over TCP.
 */
export function createRequest(
  id: number,
  method: string,
  params: Record<string, unknown>,
): string {
  const request: JsonRpcRequest = {
    jsonrpc: "2.0",
    id,
    method,
    params,
  };
  return JSON.stringify(request) + "\n";
}

/**
 * Parses a raw JSON string into a JsonRpcResponse.
 * Throws if the payload is not valid JSON or does not look like a JSON-RPC 2.0 response.
 */
export function parseResponse(data: string): JsonRpcResponse {
  const trimmed = data.trim();
  if (trimmed.length === 0) {
    throw new Error("Empty response from MOHO server");
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(trimmed);
  } catch {
    throw new Error(`Invalid JSON from MOHO server: ${trimmed.slice(0, 200)}`);
  }

  if (typeof parsed !== "object" || parsed === null) {
    throw new Error("MOHO server response is not a JSON object");
  }

  const obj = parsed as Record<string, unknown>;

  if (obj.jsonrpc !== "2.0") {
    throw new Error(
      `Unexpected jsonrpc version: ${String(obj.jsonrpc ?? "missing")}`,
    );
  }

  return obj as unknown as JsonRpcResponse;
}
