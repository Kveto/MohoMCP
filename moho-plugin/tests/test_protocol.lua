-- test_protocol.lua
-- Tests for moho_mcp/protocol.lua: parseRequest, createResponse, createError, error codes.

local protocol = require("protocol")

-------------------------------------------------------------------------------
-- Error code constants
-------------------------------------------------------------------------------

test("error codes: PARSE_ERROR is -32700", function()
    assert_eq(protocol.PARSE_ERROR, -32700)
end)

test("error codes: INVALID_REQUEST is -32600", function()
    assert_eq(protocol.INVALID_REQUEST, -32600)
end)

test("error codes: METHOD_NOT_FOUND is -32601", function()
    assert_eq(protocol.METHOD_NOT_FOUND, -32601)
end)

test("error codes: INVALID_PARAMS is -32602", function()
    assert_eq(protocol.INVALID_PARAMS, -32602)
end)

test("error codes: INTERNAL_ERROR is -32603", function()
    assert_eq(protocol.INTERNAL_ERROR, -32603)
end)

-------------------------------------------------------------------------------
-- parseRequest tests
-------------------------------------------------------------------------------

test("parseRequest: valid request", function()
    local input = json.encode({
        jsonrpc = "2.0",
        id = 1,
        method = "document.getInfo",
        params = {}
    })
    local req, err = protocol.parseRequest(input)
    assert_true(req, "should parse successfully")
    assert_eq(err, nil, "no error")
    assert_eq(req.jsonrpc, "2.0")
    assert_eq(req.id, 1)
    assert_eq(req.method, "document.getInfo")
end)

test("parseRequest: valid request with string id", function()
    local input = json.encode({
        jsonrpc = "2.0",
        id = "abc-123",
        method = "layer.getProperties",
        params = {layerId = 1}
    })
    local req, err = protocol.parseRequest(input)
    assert_true(req, "should parse successfully")
    assert_eq(err, nil)
    assert_eq(req.id, "abc-123")
    assert_eq(req.method, "layer.getProperties")
    assert_eq(req.params.layerId, 1)
end)

test("parseRequest: valid request without params field", function()
    local input = json.encode({
        jsonrpc = "2.0",
        id = 1,
        method = "document.getInfo"
    })
    local req, err = protocol.parseRequest(input)
    assert_true(req, "should parse successfully")
    assert_eq(err, nil)
    assert_eq(req.params, nil)
end)

test("parseRequest: missing jsonrpc field", function()
    local input = json.encode({id = 1, method = "test"})
    local req, err = protocol.parseRequest(input)
    assert_eq(req, nil, "should fail")
    assert_true(err:find("jsonrpc"), "error mentions jsonrpc")
end)

test("parseRequest: wrong jsonrpc version", function()
    local input = json.encode({jsonrpc = "1.0", id = 1, method = "test"})
    local req, err = protocol.parseRequest(input)
    assert_eq(req, nil)
    assert_true(err:find("jsonrpc"), "error mentions jsonrpc")
end)

test("parseRequest: missing id field", function()
    local input = json.encode({jsonrpc = "2.0", method = "test"})
    local req, err = protocol.parseRequest(input)
    assert_eq(req, nil)
    assert_true(err:find("id"), "error mentions id")
end)

test("parseRequest: missing method field", function()
    local input = json.encode({jsonrpc = "2.0", id = 1})
    local req, err = protocol.parseRequest(input)
    assert_eq(req, nil)
    assert_true(err:find("method"), "error mentions method")
end)

test("parseRequest: empty method field", function()
    local input = json.encode({jsonrpc = "2.0", id = 1, method = ""})
    local req, err = protocol.parseRequest(input)
    assert_eq(req, nil)
    assert_true(err:find("method"), "error mentions method")
end)

test("parseRequest: method is a number (wrong type)", function()
    -- Manually build JSON because encode would encode it fine.
    local input = '{"jsonrpc":"2.0","id":1,"method":42}'
    local req, err = protocol.parseRequest(input)
    assert_eq(req, nil)
    assert_true(err:find("method"), "error mentions method")
end)

test("parseRequest: empty string input", function()
    local req, err = protocol.parseRequest("")
    assert_eq(req, nil)
    assert_true(err:find("Invalid input"), "error mentions invalid input")
end)

test("parseRequest: nil input", function()
    local req, err = protocol.parseRequest(nil)
    assert_eq(req, nil)
    assert_true(err:find("Invalid input"), "error mentions invalid input")
end)

test("parseRequest: number input", function()
    local req, err = protocol.parseRequest(123)
    assert_eq(req, nil)
    assert_true(err:find("Invalid input"), "error mentions invalid input")
end)

test("parseRequest: malformed JSON", function()
    local req, err = protocol.parseRequest("{not valid json}")
    assert_eq(req, nil)
    assert_true(err:find("Parse error") or err:find("malformed"),
        "error mentions parse/malformed")
end)

test("parseRequest: JSON array instead of object", function()
    local req, err = protocol.parseRequest("[1,2,3]")
    -- An array is a table but won't have jsonrpc field.
    assert_eq(req, nil)
    assert_true(err ~= nil, "should return an error")
end)

test("parseRequest: JSON string instead of object", function()
    local req, err = protocol.parseRequest('"just a string"')
    -- json.decode returns a string, not a table.
    assert_eq(req, nil)
    assert_true(err:find("Parse error") or err:find("malformed"),
        "error about non-table")
end)

-------------------------------------------------------------------------------
-- createResponse tests
-------------------------------------------------------------------------------

test("createResponse: simple result", function()
    local result_json = protocol.createResponse(1, "ok")
    local decoded = json.decode(result_json)
    assert_eq(decoded.jsonrpc, "2.0")
    assert_eq(decoded.id, 1)
    assert_eq(decoded.result, "ok")
end)

test("createResponse: numeric result", function()
    local result_json = protocol.createResponse(42, 3.14)
    local decoded = json.decode(result_json)
    assert_eq(decoded.id, 42)
    assert_true(math.abs(decoded.result - 3.14) < 1e-10, "numeric result")
end)

test("createResponse: table result", function()
    local result_json = protocol.createResponse(1, {name = "test", value = 100})
    local decoded = json.decode(result_json)
    assert_eq(decoded.jsonrpc, "2.0")
    assert_eq(decoded.id, 1)
    assert_eq(decoded.result.name, "test")
    assert_eq(decoded.result.value, 100)
end)

test("createResponse: boolean result", function()
    local result_json = protocol.createResponse(1, true)
    local decoded = json.decode(result_json)
    assert_eq(decoded.result, true)
end)

test("createResponse: null result", function()
    local result_json = protocol.createResponse(1, json.null)
    local decoded = json.decode(result_json)
    assert_eq(decoded.result, json.null)
end)

test("createResponse: string id", function()
    local result_json = protocol.createResponse("req-1", {status = "done"})
    local decoded = json.decode(result_json)
    assert_eq(decoded.id, "req-1")
end)

test("createResponse: array result", function()
    local result_json = protocol.createResponse(1, {10, 20, 30})
    local decoded = json.decode(result_json)
    assert_eq(decoded.result[1], 10)
    assert_eq(decoded.result[2], 20)
    assert_eq(decoded.result[3], 30)
end)

-------------------------------------------------------------------------------
-- createError tests
-------------------------------------------------------------------------------

test("createError: basic error", function()
    local err_json = protocol.createError(1, -32600, "Invalid Request")
    local decoded = json.decode(err_json)
    assert_eq(decoded.jsonrpc, "2.0")
    assert_eq(decoded.id, 1)
    assert_eq(decoded.error.code, -32600)
    assert_eq(decoded.error.message, "Invalid Request")
    assert_eq(decoded.error.data, nil)
end)

test("createError: with data field", function()
    local err_json = protocol.createError(2, -32602, "Invalid params", "layerId missing")
    local decoded = json.decode(err_json)
    assert_eq(decoded.error.code, -32602)
    assert_eq(decoded.error.message, "Invalid params")
    assert_eq(decoded.error.data, "layerId missing")
end)

test("createError: with table data", function()
    local err_json = protocol.createError(1, -32603, "Internal error",
        {details = "stack overflow"})
    local decoded = json.decode(err_json)
    assert_eq(decoded.error.data.details, "stack overflow")
end)

test("createError: nil id for parse errors", function()
    local err_json = protocol.createError(json.null, -32700, "Parse error")
    local decoded = json.decode(err_json)
    assert_eq(decoded.id, json.null)
    assert_eq(decoded.error.code, -32700)
end)

test("createError: uses standard error codes", function()
    local err_json = protocol.createError(1, protocol.METHOD_NOT_FOUND, "Method not found")
    local decoded = json.decode(err_json)
    assert_eq(decoded.error.code, -32601)
end)

test("createError: response has no result field", function()
    local err_json = protocol.createError(1, -32600, "bad")
    local decoded = json.decode(err_json)
    assert_eq(decoded.result, nil, "error response should not have result")
end)
