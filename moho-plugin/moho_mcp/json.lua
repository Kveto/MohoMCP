--[[
    json.lua - A pure-Lua JSON encoder/decoder

    MIT License

    Copyright (c) 2026 MohoMCP Project Contributors

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

    Compatible with Lua 5.4 (MOHO 14 animation software).
    No external dependencies.
]]

local json = {}

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

-- Sentinel value representing JSON null.
-- Use json.null in Lua tables where you need an explicit null in the output.
json.null = setmetatable({}, {
    __tostring = function() return "json.null" end,
})

-------------------------------------------------------------------------------
-- Forward declarations
-------------------------------------------------------------------------------

local encode_value
local decode_value

-------------------------------------------------------------------------------
-- Encoder: escape map and helpers
-------------------------------------------------------------------------------

local escape_char_map = {
    ["\\"] = "\\\\",
    ["\""] = "\\\"",
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
}

-- Encode control characters U+0000 through U+001F that are not in the map
-- above as \u00XX.
local function escape_char(c)
    return escape_char_map[c]
        or string.format("\\u%04x", string.byte(c))
end

local function encode_string(val)
    -- Replace special / control characters with their escape sequences.
    return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end

local function encode_number(val)
    -- Handle special IEEE-754 values that have no JSON representation.
    if val ~= val then
        error("cannot encode NaN as JSON")
    elseif val == math.huge then
        error("cannot encode Infinity as JSON")
    elseif val == -math.huge then
        error("cannot encode -Infinity as JSON")
    end
    -- Use integer format when the value has no fractional part and fits
    -- comfortably in a 64-bit integer range.
    if val == math.floor(val) and math.abs(val) < 2^53 then
        return string.format("%.0f", val)
    end
    -- Use enough precision to round-trip a double.
    return string.format("%.17g", val)
end

--- Determine whether a Lua table should be encoded as a JSON array.
--- A table is treated as an array when:
---   1. It is not marked with json.object(), AND
---   2. It has only consecutive positive integer keys starting at 1.
--- Empty tables without the object marker are encoded as arrays ([]).
local function is_array(t)
    -- Check for explicit object marker from json.object().
    local mt = getmetatable(t)
    if mt and mt.__is_json_object then
        return false
    end

    local max = 0
    local count = 0
    for k, _ in pairs(t) do
        if type(k) ~= "number" then
            return false
        end
        if k ~= math.floor(k) or k <= 0 then
            return false
        end
        if k > max then
            max = k
        end
        count = count + 1
    end
    return count == max
end

local function encode_array(val, indent, depth)
    local n = #val
    if n == 0 then
        return "[]"
    end

    local parts = {}
    local newline, separator, indent_str, end_indent
    if indent then
        newline = "\n"
        separator = ",\n"
        indent_str = string.rep(indent, depth + 1)
        end_indent = string.rep(indent, depth)
    else
        newline = ""
        separator = ","
        indent_str = ""
        end_indent = ""
    end

    for i = 1, n do
        local v = val[i]
        parts[i] = indent_str .. encode_value(v, indent, depth + 1)
    end

    return "[" .. newline
        .. table.concat(parts, separator)
        .. newline .. end_indent .. "]"
end

local function encode_object(val, indent, depth)
    -- Collect string keys and sort them for deterministic output.
    local keys = {}
    for k, _ in pairs(val) do
        if type(k) == "string" then
            keys[#keys + 1] = k
        elseif type(k) ~= "number" then
            error("cannot encode table key of type " .. type(k) .. " as JSON")
        end
    end

    if #keys == 0 and not next(val) then
        return "{}"
    end

    table.sort(keys)

    local newline, separator, colon, indent_str, end_indent
    if indent then
        newline = "\n"
        separator = ",\n"
        colon = ": "
        indent_str = string.rep(indent, depth + 1)
        end_indent = string.rep(indent, depth)
    else
        newline = ""
        separator = ","
        colon = ":"
        indent_str = ""
        end_indent = ""
    end

    local parts = {}
    for _, k in ipairs(keys) do
        local v = val[k]
        parts[#parts + 1] = indent_str
            .. encode_string(k) .. colon
            .. encode_value(v, indent, depth + 1)
    end

    return "{" .. newline
        .. table.concat(parts, separator)
        .. newline .. end_indent .. "}"
end

--- Core recursive value encoder.
--- @param val       any         The Lua value to encode.
--- @param indent    string|nil  If non-nil, pretty-print using this string per level.
--- @param depth     number      Current nesting depth (starts at 0).
--- @return string   The JSON fragment.
encode_value = function(val, indent, depth)
    local t = type(val)

    if val == json.null then
        return "null"
    elseif t == "string" then
        return encode_string(val)
    elseif t == "number" then
        return encode_number(val)
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "nil" then
        return "null"
    elseif t == "table" then
        if is_array(val) then
            return encode_array(val, indent, depth)
        else
            return encode_object(val, indent, depth)
        end
    else
        error("cannot encode value of type " .. t .. " as JSON")
    end
end

-------------------------------------------------------------------------------
-- Public encoder API
-------------------------------------------------------------------------------

--- Encode a Lua value to a JSON string.
--- @param val    any        The value to encode (table, string, number, boolean, nil, or json.null).
--- @param opts   table|nil  Optional settings table.
---   opts.indent  string|nil  Pretty-print indentation string (e.g. "  " or "\t").
--- @return string  The JSON-encoded string.
function json.encode(val, opts)
    local indent = opts and opts.indent or nil
    local ok, result = pcall(encode_value, val, indent, 0)
    if not ok then
        error("json.encode: " .. tostring(result), 2)
    end
    return result
end

-------------------------------------------------------------------------------
-- Decoder: helpers
-------------------------------------------------------------------------------

--- Create an informative error message including the position in the source.
local function decode_error(str, pos, msg)
    -- Count line and column for a friendlier message.
    local line = 1
    local col  = 1
    for i = 1, pos - 1 do
        if str:sub(i, i) == "\n" then
            line = line + 1
            col = 1
        else
            col = col + 1
        end
    end
    error(string.format("json.decode: %s at line %d, col %d (byte %d)", msg, line, col, pos), 0)
end

--- Skip whitespace and return the position of the next non-whitespace character.
local function skip_ws(str, pos)
    -- JSON whitespace: space, tab, newline, carriage return.
    local p = str:find("[^ \t\n\r]", pos)
    if not p then
        return #str + 1
    end
    return p
end

-------------------------------------------------------------------------------
-- Decoder: string
-------------------------------------------------------------------------------

local escape_char_decode = {
    ['"']  = '"',
    ["\\"] = "\\",
    ["/"]  = "/",
    ["b"]  = "\b",
    ["f"]  = "\f",
    ["n"]  = "\n",
    ["r"]  = "\r",
    ["t"]  = "\t",
}

--- Decode a \uXXXX escape (and handle surrogate pairs for characters above U+FFFF).
--- Returns the UTF-8 encoded string and the position after the escape.
local function decode_unicode_escape(str, pos)
    local hex = str:sub(pos, pos + 3)
    if #hex ~= 4 or not hex:match("^%x%x%x%x$") then
        decode_error(str, pos, "invalid unicode escape '\\u" .. hex .. "'")
    end
    local codepoint = tonumber(hex, 16)
    pos = pos + 4

    -- Handle UTF-16 surrogate pairs (U+D800 to U+DBFF high, U+DC00 to U+DFFF low).
    if codepoint >= 0xD800 and codepoint <= 0xDBFF then
        -- Expect a low surrogate.
        if str:sub(pos, pos + 1) ~= "\\u" then
            decode_error(str, pos, "expected low surrogate after high surrogate")
        end
        pos = pos + 2
        local hex2 = str:sub(pos, pos + 3)
        if #hex2 ~= 4 or not hex2:match("^%x%x%x%x$") then
            decode_error(str, pos, "invalid unicode escape in surrogate pair")
        end
        local low = tonumber(hex2, 16)
        if low < 0xDC00 or low > 0xDFFF then
            decode_error(str, pos, "invalid low surrogate value")
        end
        codepoint = 0x10000 + (codepoint - 0xD800) * 0x400 + (low - 0xDC00)
        pos = pos + 4
    elseif codepoint >= 0xDC00 and codepoint <= 0xDFFF then
        decode_error(str, pos - 6, "unexpected low surrogate without preceding high surrogate")
    end

    -- Encode the codepoint as UTF-8.
    local result
    if codepoint <= 0x7F then
        result = string.char(codepoint)
    elseif codepoint <= 0x7FF then
        result = string.char(
            0xC0 + math.floor(codepoint / 0x40),
            0x80 + (codepoint % 0x40)
        )
    elseif codepoint <= 0xFFFF then
        result = string.char(
            0xE0 + math.floor(codepoint / 0x1000),
            0x80 + math.floor((codepoint % 0x1000) / 0x40),
            0x80 + (codepoint % 0x40)
        )
    elseif codepoint <= 0x10FFFF then
        result = string.char(
            0xF0 + math.floor(codepoint / 0x40000),
            0x80 + math.floor((codepoint % 0x40000) / 0x1000),
            0x80 + math.floor((codepoint % 0x1000) / 0x40),
            0x80 + (codepoint % 0x40)
        )
    else
        decode_error(str, pos, "invalid unicode codepoint")
    end

    return result, pos
end

local function decode_string(str, pos)
    -- pos should point to the opening '"'.
    if str:sub(pos, pos) ~= '"' then
        decode_error(str, pos, "expected '\"'")
    end
    pos = pos + 1

    local parts = {}
    local start = pos

    while pos <= #str do
        local c = str:sub(pos, pos)

        if c == '"' then
            -- End of string.
            parts[#parts + 1] = str:sub(start, pos - 1)
            return table.concat(parts), pos + 1
        elseif c == "\\" then
            -- Flush any accumulated literal text.
            parts[#parts + 1] = str:sub(start, pos - 1)
            pos = pos + 1
            local esc = str:sub(pos, pos)
            if esc == "" then
                decode_error(str, pos, "unexpected end of string in escape")
            end
            if esc == "u" then
                local decoded, new_pos = decode_unicode_escape(str, pos + 1)
                parts[#parts + 1] = decoded
                pos = new_pos
            elseif escape_char_decode[esc] then
                parts[#parts + 1] = escape_char_decode[esc]
                pos = pos + 1
            else
                decode_error(str, pos, "invalid escape character '\\" .. esc .. "'")
            end
            start = pos
        elseif c:byte() < 0x20 then
            decode_error(str, pos, "control character in string (byte " .. c:byte() .. ")")
        else
            pos = pos + 1
        end
    end

    decode_error(str, start - 1, "unterminated string")
end

-------------------------------------------------------------------------------
-- Decoder: number
-------------------------------------------------------------------------------

local function decode_number(str, pos)
    -- Match the JSON number grammar:
    --   -? (0 | [1-9][0-9]*) ( "." [0-9]+ )? ( [eE] [+-]? [0-9]+ )?
    local num_str = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
    if not num_str then
        decode_error(str, pos, "invalid number")
    end

    local val = tonumber(num_str)
    if not val then
        decode_error(str, pos, "invalid number '" .. num_str .. "'")
    end

    -- Validate the number more strictly according to JSON rules.
    -- Leading zeros are not allowed (except for "0", "0.x", "-0", "-0.x").
    local check = num_str
    if check:sub(1, 1) == "-" then
        check = check:sub(2)
    end
    if #check > 1
        and check:sub(1, 1) == "0"
        and check:sub(2, 2) ~= "."
        and check:sub(2, 2):lower() ~= "e"
    then
        decode_error(str, pos, "leading zeros not allowed in JSON number")
    end

    return val, pos + #num_str
end

-------------------------------------------------------------------------------
-- Decoder: array
-------------------------------------------------------------------------------

local function decode_array(str, pos)
    -- pos points to '['.
    pos = pos + 1
    local arr = {}
    local idx = 1

    pos = skip_ws(str, pos)
    if str:sub(pos, pos) == "]" then
        return arr, pos + 1
    end

    while true do
        local val
        val, pos = decode_value(str, pos)
        arr[idx] = val
        idx = idx + 1

        pos = skip_ws(str, pos)
        local c = str:sub(pos, pos)
        if c == "]" then
            return arr, pos + 1
        elseif c == "," then
            pos = skip_ws(str, pos + 1)
            -- Trailing comma check (not allowed in JSON).
            if str:sub(pos, pos) == "]" then
                decode_error(str, pos, "trailing comma in array")
            end
        else
            decode_error(str, pos, "expected ',' or ']' in array, got '" .. c .. "'")
        end
    end
end

-------------------------------------------------------------------------------
-- Decoder: object
-------------------------------------------------------------------------------

local function decode_object(str, pos)
    -- pos points to '{'.
    pos = pos + 1
    local obj = {}

    pos = skip_ws(str, pos)
    if str:sub(pos, pos) == "}" then
        return obj, pos + 1
    end

    while true do
        pos = skip_ws(str, pos)

        -- Key must be a string.
        if str:sub(pos, pos) ~= '"' then
            decode_error(str, pos,
                "expected string key in object, got '" .. str:sub(pos, pos) .. "'")
        end

        local key
        key, pos = decode_string(str, pos)

        pos = skip_ws(str, pos)
        if str:sub(pos, pos) ~= ":" then
            decode_error(str, pos, "expected ':' after object key")
        end
        pos = skip_ws(str, pos + 1)

        local val
        val, pos = decode_value(str, pos)
        obj[key] = val

        pos = skip_ws(str, pos)
        local c = str:sub(pos, pos)
        if c == "}" then
            return obj, pos + 1
        elseif c == "," then
            pos = pos + 1
            -- Trailing comma check.
            pos = skip_ws(str, pos)
            if str:sub(pos, pos) == "}" then
                decode_error(str, pos, "trailing comma in object")
            end
        else
            decode_error(str, pos, "expected ',' or '}' in object, got '" .. c .. "'")
        end
    end
end

-------------------------------------------------------------------------------
-- Decoder: core dispatcher
-------------------------------------------------------------------------------

--- Decode a JSON value starting at position pos.
--- @param str  string  The full JSON source string.
--- @param pos  number  Current byte position (1-based).
--- @return any, number  The decoded Lua value and the position after it.
decode_value = function(str, pos)
    pos = skip_ws(str, pos)

    if pos > #str then
        decode_error(str, pos, "unexpected end of input")
    end

    local c = str:sub(pos, pos)

    if c == '"' then
        return decode_string(str, pos)
    elseif c == "{" then
        return decode_object(str, pos)
    elseif c == "[" then
        return decode_array(str, pos)
    elseif c == "-" or (c >= "0" and c <= "9") then
        return decode_number(str, pos)
    elseif c == "t" then
        if str:sub(pos, pos + 3) == "true" then
            return true, pos + 4
        end
        decode_error(str, pos, "invalid literal")
    elseif c == "f" then
        if str:sub(pos, pos + 4) == "false" then
            return false, pos + 5
        end
        decode_error(str, pos, "invalid literal")
    elseif c == "n" then
        if str:sub(pos, pos + 3) == "null" then
            return json.null, pos + 4
        end
        decode_error(str, pos, "invalid literal")
    else
        decode_error(str, pos, "unexpected character '" .. c .. "'")
    end
end

-------------------------------------------------------------------------------
-- Public decoder API
-------------------------------------------------------------------------------

--- Decode a JSON string into a Lua value.
--- @param str   string  The JSON string to decode.
--- @return any  The decoded Lua value. JSON null becomes json.null.
function json.decode(str)
    if type(str) ~= "string" then
        error("json.decode: expected string argument, got " .. type(str), 2)
    end
    if str == "" then
        error("json.decode: empty string", 2)
    end

    local val, pos = decode_value(str, 1)

    -- Ensure there is no trailing non-whitespace.
    pos = skip_ws(str, pos)
    if pos <= #str then
        decode_error(str, pos, "unexpected trailing content")
    end

    return val
end

-------------------------------------------------------------------------------
-- Utility: object marker
-------------------------------------------------------------------------------

--- Mark a table so that it will be encoded as a JSON object ({}) rather than
--- as an array ([]).  Useful for empty tables that should produce {} instead
--- of [].
--- @param t table|nil  The table to mark (creates a new table if nil).
--- @return table       The marked table.
function json.object(t)
    t = t or {}
    local mt = getmetatable(t) or {}
    mt.__is_json_object = true
    setmetatable(t, mt)
    return t
end

return json
