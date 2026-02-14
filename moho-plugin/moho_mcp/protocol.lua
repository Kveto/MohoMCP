-- protocol.lua
-- JSON-RPC 2.0 message parsing and serialization for MohoMCP
-- Assumes the global `json` table is available (loaded by the main server script)

local protocol = {}

-- Standard JSON-RPC 2.0 error codes
protocol.PARSE_ERROR      = -32700
protocol.INVALID_REQUEST  = -32600
protocol.METHOD_NOT_FOUND = -32601
protocol.INVALID_PARAMS   = -32602
protocol.INTERNAL_ERROR   = -32603

--- Parse a JSON-RPC 2.0 request string into a request table.
-- Validates that the decoded object contains jsonrpc="2.0", id, and method fields.
-- @param jsonStr string  The raw JSON string to parse
-- @return table|nil  The parsed request table on success, or nil on failure
-- @return string|nil  An error message on failure
function protocol.parseRequest(jsonStr)
    if type(jsonStr) ~= "string" or jsonStr == "" then
        return nil, "Invalid input: expected non-empty JSON string"
    end

    local ok, decoded = pcall(json.decode, jsonStr)
    if not ok or type(decoded) ~= "table" then
        return nil, "Parse error: malformed JSON"
    end

    -- Validate required JSON-RPC 2.0 fields
    if decoded.jsonrpc ~= "2.0" then
        return nil, "Invalid request: missing or incorrect jsonrpc version (must be \"2.0\")"
    end

    if decoded.id == nil then
        return nil, "Invalid request: missing id field"
    end

    if type(decoded.method) ~= "string" or decoded.method == "" then
        return nil, "Invalid request: missing or invalid method field"
    end

    return decoded, nil
end

--- Create a JSON-RPC 2.0 success response string.
-- @param id  The request id to echo back
-- @param result  The result value to include in the response
-- @return string  The encoded JSON-RPC 2.0 response
function protocol.createResponse(id, result)
    local response = {
        jsonrpc = "2.0",
        id      = id,
        result  = result
    }
    return json.encode(response)
end

--- Create a JSON-RPC 2.0 error response string.
-- @param id  The request id to echo back (may be nil for parse errors)
-- @param code number  The JSON-RPC error code
-- @param message string  A short human-readable error message
-- @param data any|nil  Optional additional error data
-- @return string  The encoded JSON-RPC 2.0 error response
function protocol.createError(id, code, message, data)
    local errorObj = {
        code    = code,
        message = message
    }
    if data ~= nil then
        errorObj.data = data
    end

    local response = {
        jsonrpc = "2.0",
        id      = id,
        error   = errorObj
    }
    return json.encode(response)
end

return protocol
