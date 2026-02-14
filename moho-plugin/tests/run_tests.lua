#!/usr/bin/env lua
-- run_tests.lua
-- Minimal test framework and runner for MohoMCP Lua modules.
-- Usage: lua run_tests.lua

-------------------------------------------------------------------------------
-- Package path setup
-- We need to find modules in the moho-plugin directory (parent of tests/).
-------------------------------------------------------------------------------

local this_dir = debug.getinfo(1, "S").source:match("@(.+[/\\])")
if not this_dir then
    this_dir = "./"
end

-- Normalize separators to forward slashes.
this_dir = this_dir:gsub("\\", "/")

-- Parent directory is moho-plugin/.
local plugin_dir = this_dir:gsub("tests/$", ""):gsub("tests\\$", "")
if plugin_dir == this_dir then
    -- Fallback: assume we are running from inside the tests directory.
    plugin_dir = "../"
end

package.path = plugin_dir .. "?.lua;"
            .. plugin_dir .. "?/init.lua;"
            .. plugin_dir .. "moho_mcp/?.lua;"
            .. package.path

-------------------------------------------------------------------------------
-- Load json globally (protocol.lua depends on a global `json`)
-------------------------------------------------------------------------------

json = require("json")

-------------------------------------------------------------------------------
-- Minimal test framework
-------------------------------------------------------------------------------

local passed  = 0
local failed  = 0
local errors  = {}

--- Define and immediately run a single test case.
function test(name, fn)
    io.write("  " .. name .. " ... ")
    io.flush()
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("PASS")
    else
        failed = failed + 1
        errors[#errors + 1] = { name = name, err = tostring(err) }
        print("FAIL")
        print("    " .. tostring(err))
    end
end

--- Assert that actual == expected.
function assert_eq(actual, expected, msg)
    if actual ~= expected then
        local detail = string.format("expected %s (%s), got %s (%s)",
            tostring(expected), type(expected),
            tostring(actual), type(actual))
        if msg then detail = msg .. ": " .. detail end
        error(detail, 2)
    end
end

--- Assert that val is truthy.
function assert_true(val, msg)
    if not val then
        error((msg or "expected truthy value") .. ", got " .. tostring(val), 2)
    end
end

--- Assert that val is falsy (false or nil).
function assert_false(val, msg)
    if val then
        error((msg or "expected falsy value") .. ", got " .. tostring(val), 2)
    end
end

--- Assert that calling fn raises an error.
--- Optionally checks that the error message contains `pattern` (plain match).
function assert_error(fn, pattern)
    local ok, err = pcall(fn)
    if ok then
        error("expected an error but function succeeded", 2)
    end
    if pattern then
        local err_str = tostring(err)
        if not err_str:find(pattern, 1, true) then
            error(string.format(
                "error message %q does not contain %q", err_str, pattern), 2)
        end
    end
end

--- Assert that a decoded table has the expected key/value pairs (shallow).
function assert_table_eq(actual, expected, msg)
    if type(actual) ~= "table" then
        error((msg or "") .. " expected table, got " .. type(actual), 2)
    end
    for k, v in pairs(expected) do
        if actual[k] ~= v then
            error(string.format("%s key %s: expected %s, got %s",
                msg or "", tostring(k), tostring(v), tostring(actual[k])), 2)
        end
    end
    -- Check no extra keys in actual that are not in expected.
    for k, _ in pairs(actual) do
        if expected[k] == nil then
            error(string.format("%s unexpected key %s in actual table",
                msg or "", tostring(k)), 2)
        end
    end
end

--- Print a section header.
function section(name)
    print()
    print(string.rep("-", 60))
    print(name)
    print(string.rep("-", 60))
end

-------------------------------------------------------------------------------
-- Run test files
-------------------------------------------------------------------------------

section("json.lua tests")
dofile(this_dir .. "test_json.lua")

section("protocol.lua tests")
dofile(this_dir .. "test_protocol.lua")

section("validator.lua tests")
dofile(this_dir .. "test_validator.lua")

-------------------------------------------------------------------------------
-- Summary
-------------------------------------------------------------------------------

print()
print(string.rep("=", 60))
local total = passed + failed
print(string.format("Results: %d passed, %d failed, %d total", passed, failed, total))

if #errors > 0 then
    print()
    print("Failed tests:")
    for _, e in ipairs(errors) do
        print("  - " .. e.name)
        print("    " .. e.err)
    end
end

print(string.rep("=", 60))

-- Return non-zero exit code on failure.
if failed > 0 then
    os.exit(1)
else
    os.exit(0)
end
