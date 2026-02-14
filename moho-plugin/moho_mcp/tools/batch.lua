-- batch.lua
-- Batch execution handler for MohoMCP.
-- Executes multiple operations in a single IPC round-trip, collapsing
-- N file-based request/response cycles into one Lua poll cycle.

local batch = {}

-- Maximum number of operations allowed in a single batch
local MAX_OPERATIONS = 50

-- Methods that are not allowed inside a batch
local disallowedInBatch = {
    ["document.screenshot"] = true,  -- too slow / heavyweight for batching
    ["batch.execute"]       = true,  -- no nesting
}

--- Execute a batch of operations.
-- @param moho  The MOHO ScriptInterface object
-- @param params table  { operations: table[], stopOnError?: boolean }
-- @return table  { results: table[], summary: table }
function batch.execute(moho, params)
    local operations = params.operations
    local stopOnError = params.stopOnError or false

    -- Validate operations is a non-empty array
    if type(operations) ~= "table" or #operations == 0 then
        return nil, "operations must be a non-empty array"
    end

    if #operations > MAX_OPERATIONS then
        return nil, "Too many operations: " .. #operations
            .. " (max " .. MAX_OPERATIONS .. ")"
    end

    -- Lazy-load dependencies (available via package.loaded after server.init)
    local validator = require("moho_mcp.validator")
    local server = require("moho_mcp.server")

    local results = {}
    local succeeded = 0
    local failed = 0
    local executed = 0
    local stoppedEarly = false

    for i, op in ipairs(operations) do
        -- Check if we should stop due to a previous error
        if stoppedEarly then
            results[i] = {
                success = false,
                index = i,
                error = { code = -32000, message = "Skipped (stopOnError)" },
            }
            goto continue
        end

        -- Validate operation structure
        if type(op) ~= "table" or type(op.method) ~= "string" then
            results[i] = {
                success = false,
                index = i,
                error = { code = -32600, message = "Invalid operation at index " .. i .. ": must have a string 'method'" },
            }
            failed = failed + 1
            executed = executed + 1
            if stopOnError then
                stoppedEarly = true
            end
            goto continue
        end

        local method = op.method
        local opParams = op.params or {}

        -- Check disallowed methods
        if disallowedInBatch[method] then
            results[i] = {
                success = false,
                index = i,
                error = { code = -32601, message = "Method not allowed in batch: " .. method },
            }
            failed = failed + 1
            executed = executed + 1
            if stopOnError then
                stoppedEarly = true
            end
            goto continue
        end

        -- Check allow-list
        if not validator.isAllowed(method) then
            results[i] = {
                success = false,
                index = i,
                error = { code = -32601, message = "Method not found: " .. method },
            }
            failed = failed + 1
            executed = executed + 1
            if stopOnError then
                stoppedEarly = true
            end
            goto continue
        end

        -- Validate params
        local valid, validErr = validator.validateParams(method, opParams)
        if not valid then
            results[i] = {
                success = false,
                index = i,
                error = { code = -32602, message = validErr or "Invalid parameters" },
            }
            failed = failed + 1
            executed = executed + 1
            if stopOnError then
                stoppedEarly = true
            end
            goto continue
        end

        -- Look up handler
        local handler = server.getHandler(method)
        if not handler then
            results[i] = {
                success = false,
                index = i,
                error = { code = -32601, message = "No handler registered for: " .. method },
            }
            failed = failed + 1
            executed = executed + 1
            if stopOnError then
                stoppedEarly = true
            end
            goto continue
        end

        -- Execute with pcall
        local ok, result, handlerErr = pcall(handler, moho, opParams)
        executed = executed + 1

        if not ok then
            -- pcall caught an error (result is the error message)
            results[i] = {
                success = false,
                index = i,
                error = { code = -32603, message = "Handler error: " .. tostring(result) },
            }
            failed = failed + 1
            if stopOnError then
                stoppedEarly = true
            end
        elseif result == nil and handlerErr then
            -- Handler returned nil + error string
            results[i] = {
                success = false,
                index = i,
                error = { code = -32603, message = handlerErr },
            }
            failed = failed + 1
            if stopOnError then
                stoppedEarly = true
            end
        else
            results[i] = {
                success = true,
                index = i,
                result = result,
            }
            succeeded = succeeded + 1
        end

        ::continue::
    end

    -- Fill any remaining slots if stoppedEarly (already done in the loop above)

    return {
        results = results,
        summary = {
            total = #operations,
            executed = executed,
            succeeded = succeeded,
            failed = failed,
            stoppedEarly = stoppedEarly,
        },
    }
end

return batch
