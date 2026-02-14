-- test_json.lua
-- Tests for json.lua: encode, decode, round-trip, edge cases, utilities.

local json = require("json")

-------------------------------------------------------------------------------
-- Encode tests
-------------------------------------------------------------------------------

test("encode: string", function()
    assert_eq(json.encode("hello"), '"hello"')
end)

test("encode: empty string", function()
    assert_eq(json.encode(""), '""')
end)

test("encode: string with special characters", function()
    local result = json.encode('line1\nline2\ttab"quote\\slash')
    assert_eq(result, '"line1\\nline2\\ttab\\"quote\\\\slash"')
end)

test("encode: string with control characters", function()
    -- A BEL character (U+0007) should produce \\u0007.
    local result = json.encode("\7")
    assert_eq(result, '"\\u0007"')
end)

test("encode: integer number", function()
    assert_eq(json.encode(42), "42")
end)

test("encode: zero", function()
    assert_eq(json.encode(0), "0")
end)

test("encode: negative number", function()
    assert_eq(json.encode(-17), "-17")
end)

test("encode: float number", function()
    local result = json.encode(3.14)
    -- The encoder uses %.17g for non-integer values.
    local decoded = tonumber(result)
    assert_true(decoded, "should be a valid number string")
    assert_true(math.abs(decoded - 3.14) < 1e-15, "should round-trip correctly")
end)

test("encode: large integer within 2^53", function()
    local n = 2^52
    local result = json.encode(n)
    assert_eq(result, "4503599627370496")
end)

test("encode: boolean true", function()
    assert_eq(json.encode(true), "true")
end)

test("encode: boolean false", function()
    assert_eq(json.encode(false), "false")
end)

test("encode: nil becomes null", function()
    assert_eq(json.encode(nil), "null")
end)

test("encode: json.null becomes null", function()
    assert_eq(json.encode(json.null), "null")
end)

test("encode: empty table becomes empty array", function()
    assert_eq(json.encode({}), "[]")
end)

test("encode: simple array", function()
    assert_eq(json.encode({1, 2, 3}), "[1,2,3]")
end)

test("encode: array of mixed types", function()
    local result = json.encode({1, "two", true, json.null})
    assert_eq(result, '[1,"two",true,null]')
end)

test("encode: simple object", function()
    local result = json.encode({a = 1, b = 2})
    -- Keys are sorted alphabetically.
    assert_eq(result, '{"a":1,"b":2}')
end)

test("encode: nested object", function()
    local result = json.encode({outer = {inner = "value"}})
    assert_eq(result, '{"outer":{"inner":"value"}}')
end)

test("encode: nested array in object", function()
    local result = json.encode({list = {1, 2, 3}})
    assert_eq(result, '{"list":[1,2,3]}')
end)

test("encode: object in array", function()
    local result = json.encode({{a = 1}, {b = 2}})
    assert_eq(result, '[{"a":1},{"b":2}]')
end)

test("encode: json.object() marks empty table as object", function()
    local t = json.object()
    assert_eq(json.encode(t), "{}")
end)

test("encode: json.object() with values", function()
    local t = json.object({name = "test"})
    assert_eq(json.encode(t), '{"name":"test"}')
end)

test("encode: NaN raises error", function()
    assert_error(function() json.encode(0/0) end, "NaN")
end)

test("encode: Infinity raises error", function()
    assert_error(function() json.encode(math.huge) end, "Infinity")
end)

test("encode: -Infinity raises error", function()
    assert_error(function() json.encode(-math.huge) end, "Infinity")
end)

test("encode: function type raises error", function()
    assert_error(function() json.encode(function() end) end, "cannot encode")
end)

test("encode: pretty-print with indent", function()
    local result = json.encode({a = 1}, {indent = "  "})
    assert_true(result:find("\n"), "should contain newlines")
    assert_true(result:find("  "), "should contain indentation")
    -- Should produce:
    -- {
    --   "a": 1
    -- }
    assert_true(result:find('"a": 1'), "should have space after colon")
end)

test("encode: pretty-print array", function()
    local result = json.encode({1, 2}, {indent = "\t"})
    assert_true(result:find("\n"), "should contain newlines")
    assert_true(result:find("\t"), "should contain tab indentation")
end)

test("encode: sorted keys for deterministic output", function()
    local result = json.encode({z = 1, a = 2, m = 3})
    assert_eq(result, '{"a":2,"m":3,"z":1}')
end)

test("encode: string with backspace and form feed", function()
    local result = json.encode("\b\f")
    assert_eq(result, '"\\b\\f"')
end)

test("encode: string with carriage return", function()
    local result = json.encode("line1\rline2")
    assert_eq(result, '"line1\\rline2"')
end)

-------------------------------------------------------------------------------
-- Decode tests
-------------------------------------------------------------------------------

test("decode: simple string", function()
    assert_eq(json.decode('"hello"'), "hello")
end)

test("decode: empty string value", function()
    assert_eq(json.decode('""'), "")
end)

test("decode: string with escapes", function()
    local result = json.decode('"line1\\nline2\\ttab"')
    assert_eq(result, "line1\nline2\ttab")
end)

test("decode: string with escaped quotes and backslash", function()
    local result = json.decode('"say \\"hi\\" and \\\\done"')
    assert_eq(result, 'say "hi" and \\done')
end)

test("decode: string with escaped forward slash", function()
    assert_eq(json.decode('"a\\/b"'), "a/b")
end)

test("decode: string with unicode escape", function()
    -- \u0041 = 'A'
    assert_eq(json.decode('"\\u0041"'), "A")
end)

test("decode: string with unicode escape for non-ASCII", function()
    -- \u00E9 = e-acute (UTF-8: 0xC3 0xA9)
    local result = json.decode('"\\u00e9"')
    assert_eq(result, "\xC3\xA9")
end)

test("decode: string with surrogate pair", function()
    -- \uD83D\uDE00 = U+1F600 (grinning face)
    local result = json.decode('"\\uD83D\\uDE00"')
    -- UTF-8 encoding of U+1F600 is F0 9F 98 80
    assert_eq(#result, 4, "should be 4 bytes in UTF-8")
    assert_eq(string.byte(result, 1), 0xF0)
    assert_eq(string.byte(result, 2), 0x9F)
    assert_eq(string.byte(result, 3), 0x98)
    assert_eq(string.byte(result, 4), 0x80)
end)

test("decode: integer", function()
    assert_eq(json.decode("42"), 42)
end)

test("decode: negative integer", function()
    assert_eq(json.decode("-17"), -17)
end)

test("decode: zero", function()
    assert_eq(json.decode("0"), 0)
end)

test("decode: float", function()
    local result = json.decode("3.14")
    assert_true(math.abs(result - 3.14) < 1e-15, "float decode")
end)

test("decode: scientific notation", function()
    assert_eq(json.decode("1e2"), 100)
end)

test("decode: negative exponent", function()
    local result = json.decode("5e-1")
    assert_true(math.abs(result - 0.5) < 1e-15, "5e-1 should be 0.5")
end)

test("decode: true", function()
    assert_eq(json.decode("true"), true)
end)

test("decode: false", function()
    assert_eq(json.decode("false"), false)
end)

test("decode: null becomes json.null", function()
    local result = json.decode("null")
    assert_eq(result, json.null)
end)

test("decode: empty array", function()
    local result = json.decode("[]")
    assert_eq(type(result), "table")
    assert_eq(#result, 0)
    assert_eq(next(result), nil)
end)

test("decode: simple array", function()
    local result = json.decode("[1,2,3]")
    assert_eq(result[1], 1)
    assert_eq(result[2], 2)
    assert_eq(result[3], 3)
    assert_eq(#result, 3)
end)

test("decode: array with whitespace", function()
    local result = json.decode("[ 1 , 2 , 3 ]")
    assert_eq(result[1], 1)
    assert_eq(result[2], 2)
    assert_eq(result[3], 3)
end)

test("decode: nested array", function()
    local result = json.decode("[[1,2],[3,4]]")
    assert_eq(result[1][1], 1)
    assert_eq(result[1][2], 2)
    assert_eq(result[2][1], 3)
    assert_eq(result[2][2], 4)
end)

test("decode: empty object", function()
    local result = json.decode("{}")
    assert_eq(type(result), "table")
    assert_eq(next(result), nil)
end)

test("decode: simple object", function()
    local result = json.decode('{"a":1,"b":2}')
    assert_eq(result.a, 1)
    assert_eq(result.b, 2)
end)

test("decode: object with whitespace", function()
    local result = json.decode('{ "key" : "value" }')
    assert_eq(result.key, "value")
end)

test("decode: nested object", function()
    local result = json.decode('{"outer":{"inner":"deep"}}')
    assert_eq(result.outer.inner, "deep")
end)

test("decode: complex nested structure", function()
    local input = '{"users":[{"name":"Alice","age":30},{"name":"Bob","age":25}]}'
    local result = json.decode(input)
    assert_eq(result.users[1].name, "Alice")
    assert_eq(result.users[1].age, 30)
    assert_eq(result.users[2].name, "Bob")
    assert_eq(result.users[2].age, 25)
end)

test("decode: whitespace around value", function()
    assert_eq(json.decode("  42  "), 42)
end)

test("decode: leading zeros not allowed", function()
    assert_error(function() json.decode("01") end, "leading zeros")
end)

test("decode: trailing comma in array errors", function()
    assert_error(function() json.decode("[1,2,]") end, "trailing comma")
end)

test("decode: trailing comma in object errors", function()
    assert_error(function() json.decode('{"a":1,}') end, "trailing comma")
end)

test("decode: empty string input raises error", function()
    assert_error(function() json.decode("") end, "empty string")
end)

test("decode: non-string input raises error", function()
    assert_error(function() json.decode(123) end, "expected string")
end)

test("decode: malformed JSON raises error", function()
    assert_error(function() json.decode("{invalid}") end)
end)

test("decode: trailing content raises error", function()
    assert_error(function() json.decode("42 extra") end, "trailing content")
end)

test("decode: unterminated string raises error", function()
    assert_error(function() json.decode('"no end') end, "unterminated")
end)

test("decode: invalid escape raises error", function()
    assert_error(function() json.decode('"\\x"') end, "invalid escape")
end)

test("decode: invalid literal raises error", function()
    assert_error(function() json.decode("tru") end, "invalid literal")
end)

-------------------------------------------------------------------------------
-- Round-trip tests
-------------------------------------------------------------------------------

test("round-trip: string", function()
    local original = "hello world"
    assert_eq(json.decode(json.encode(original)), original)
end)

test("round-trip: string with special chars", function()
    local original = 'tab\there\nnewline"quote'
    assert_eq(json.decode(json.encode(original)), original)
end)

test("round-trip: integer", function()
    assert_eq(json.decode(json.encode(42)), 42)
end)

test("round-trip: float", function()
    local original = 3.141592653589793
    local result = json.decode(json.encode(original))
    assert_true(math.abs(result - original) < 1e-15, "float round-trip")
end)

test("round-trip: boolean true", function()
    assert_eq(json.decode(json.encode(true)), true)
end)

test("round-trip: boolean false", function()
    assert_eq(json.decode(json.encode(false)), false)
end)

test("round-trip: null", function()
    assert_eq(json.decode(json.encode(json.null)), json.null)
end)

test("round-trip: array", function()
    local encoded = json.encode({1, "two", true})
    local decoded = json.decode(encoded)
    assert_eq(decoded[1], 1)
    assert_eq(decoded[2], "two")
    assert_eq(decoded[3], true)
end)

test("round-trip: object", function()
    local encoded = json.encode({name = "test", count = 5})
    local decoded = json.decode(encoded)
    assert_eq(decoded.name, "test")
    assert_eq(decoded.count, 5)
end)

test("round-trip: nested structure", function()
    local original_json = '{"data":{"items":[1,2,3],"active":true},"status":"ok"}'
    local decoded = json.decode(original_json)
    local re_encoded = json.encode(decoded)
    local re_decoded = json.decode(re_encoded)
    assert_eq(re_decoded.status, "ok")
    assert_eq(re_decoded.data.active, true)
    assert_eq(re_decoded.data.items[1], 1)
    assert_eq(re_decoded.data.items[2], 2)
    assert_eq(re_decoded.data.items[3], 3)
end)

-------------------------------------------------------------------------------
-- json.null sentinel tests
-------------------------------------------------------------------------------

test("json.null: tostring", function()
    assert_eq(tostring(json.null), "json.null")
end)

test("json.null: is a table", function()
    assert_eq(type(json.null), "table")
end)

test("json.null: identity equality", function()
    local a = json.null
    local b = json.null
    assert_eq(a, b)
end)

test("json.null: in array", function()
    local result = json.encode({1, json.null, 3})
    assert_eq(result, "[1,null,3]")
end)

test("json.null: in object", function()
    local result = json.encode({key = json.null})
    assert_eq(result, '{"key":null}')
end)

test("json.null: decoded null round-trips", function()
    local decoded = json.decode('[null]')
    assert_eq(decoded[1], json.null)
    local re_encoded = json.encode(decoded)
    assert_eq(re_encoded, "[null]")
end)

-------------------------------------------------------------------------------
-- json.object() tests
-------------------------------------------------------------------------------

test("json.object: creates empty table", function()
    local t = json.object()
    assert_eq(type(t), "table")
    assert_eq(next(t), nil)
end)

test("json.object: wraps existing table", function()
    local original = {x = 10}
    local t = json.object(original)
    assert_eq(t, original, "should return the same table")
    assert_eq(t.x, 10)
end)

test("json.object: encode as {} not []", function()
    assert_eq(json.encode(json.object()), "{}")
    assert_eq(json.encode({}), "[]")  -- Without marker, empty table is array.
end)

-------------------------------------------------------------------------------
-- Pretty-print tests
-------------------------------------------------------------------------------

test("pretty-print: nested object", function()
    local result = json.encode({a = {b = 1}}, {indent = "  "})
    -- Verify multi-line output.
    local lines = {}
    for line in result:gmatch("[^\n]+") do
        lines[#lines + 1] = line
    end
    assert_true(#lines >= 4, "should have at least 4 lines")
    assert_eq(lines[1], "{")
    -- "a" key line should be indented with 2 spaces.
    assert_true(lines[2]:find("^  "), "first level indented")
end)

test("pretty-print: empty array stays compact", function()
    assert_eq(json.encode({}, {indent = "  "}), "[]")
end)

test("pretty-print: empty object stays compact", function()
    assert_eq(json.encode(json.object(), {indent = "  "}), "{}")
end)
