-- server.lua
-- File-based IPC server for MohoMCP. Runs inside MOHO's Lua 5.4 environment.
-- Uses a shared directory for request/response JSON files instead of TCP sockets.
-- Designed to be polled from MOHO's Run callback to avoid UI freezes.

local server = {}

-- Dependencies (set by init)
local protocol = nil
local validator = nil

-- Server state
local isRunning = false
local ipcDir = ""

-- Tool handler registry: method name -> function(moho, params) -> result, err
local handlers = {}

-- Platform detection
local SEP = package.config:sub(1, 1) -- "/" on unix, "\" on windows

--- Initialize the server module with its dependencies.
-- @param deps table  Dependencies: { protocol, validator, json }
function server.init(deps)
    protocol = deps.protocol
    validator = deps.validator
end

--- Register a tool handler for a given method name.
-- @param method string  The JSON-RPC method name
-- @param handler function  Handler function(moho, params) -> result, err
function server.registerHandler(method, handler)
    handlers[method] = handler
end

--- Look up a registered handler by method name.
-- Used by the batch handler to dispatch operations without going through processRequest().
-- @param method string  The JSON-RPC method name
-- @return function|nil  The handler function, or nil if not registered
function server.getHandler(method)
    return handlers[method]
end

--- Get the IPC directory path.
-- Uses TEMP/moho-mcp/ on Windows, /tmp/moho-mcp/ on others.
local function getIpcDir()
    local tmp = os.getenv("TEMP") or os.getenv("TMP") or os.getenv("TMPDIR") or "/tmp"
    return tmp .. SEP .. "moho-mcp" .. SEP
end

--- Check if a file exists by trying to open it.
local function fileExists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

--- Read the entire contents of a file.
local function readFile(path)
    local f, err = io.open(path, "r")
    if not f then
        return nil, err
    end
    local content = f:read("*a")
    f:close()
    return content
end

--- Write content to a file atomically (write to .tmp then rename).
local function writeFile(path, content)
    local tmpPath = path .. ".tmp"
    local f, err = io.open(tmpPath, "w")
    if not f then
        return false, "Failed to open " .. tmpPath .. ": " .. tostring(err)
    end
    f:write(content)
    f:close()
    -- Rename .tmp to final path (atomic on most filesystems)
    os.remove(path)
    local ok, renameErr = os.rename(tmpPath, path)
    if not ok then
        return false, "Failed to rename: " .. tostring(renameErr)
    end
    return true
end

--- Create a directory without spawning a visible cmd window.
local function mkdirp(path)
    -- Use io.popen instead of os.execute to avoid visible cmd windows
    local cmd
    if SEP == "\\" then
        cmd = 'cmd /c mkdir "' .. path .. '" 2>NUL'
    else
        cmd = 'mkdir -p "' .. path .. '" 2>/dev/null'
    end
    local handle = io.popen(cmd)
    if handle then handle:close() end
end

--- Find request/response files by probing for known ID patterns.
--- Pure Lua — no shell commands, no visible windows.
--- The bridge uses incrementing integer IDs (1, 2, 3, …) so we
--- scan a range of IDs and check if the file exists via io.open.
--- Scan a fixed window of IDs starting from 1.
--- On modern SSDs, probing ~200 files via io.open is <5ms.
--- The bridge resets its counter on restart, so IDs are typically low.
local function findFilesByPrefix(dir, prefix)
    local files = {}
    local misses = 0
    for id = 1, 10000 do
        local fname = prefix .. id .. ".json"
        local f = io.open(dir .. fname, "r")
        if f then
            f:close()
            files[#files + 1] = fname
            misses = 0
        else
            misses = misses + 1
            -- Stop after 100 consecutive misses (covers any reasonable gap)
            if misses > 100 then
                break
            end
        end
    end
    return files
end

--- One-time wide scan to discover the current bridge ID range.
--- Called once at server start. Uses io.popen (single cmd window, one time only).
local function discoverCurrentIdRange(dir)
    local cmd
    if SEP == "\\" then
        cmd = 'cmd /c dir /b "' .. dir .. 'req_*.json" 2>NUL'
    else
        cmd = 'ls -1 "' .. dir .. '"req_*.json 2>/dev/null'
    end
    local handle = io.popen(cmd)
    if handle then
        for line in handle:lines() do
            local id = line:match("req_(%d+)%.json")
            if id then
                local numId = tonumber(id)
                if numId and numId > lastSeenMaxId then
                    lastSeenMaxId = numId
                end
            end
        end
        handle:close()
    end
    -- Also check response files for ID range
    if SEP == "\\" then
        cmd = 'cmd /c dir /b "' .. dir .. 'resp_*.json" 2>NUL'
    else
        cmd = 'ls -1 "' .. dir .. '"resp_*.json 2>/dev/null'
    end
    handle = io.popen(cmd)
    if handle then
        for line in handle:lines() do
            local id = line:match("resp_(%d+)%.json")
            if id then
                local numId = tonumber(id)
                if numId and numId > lastSeenMaxId then
                    lastSeenMaxId = numId
                end
            end
        end
        handle:close()
    end
    print("[MohoMCP] Discovered max ID: " .. tostring(lastSeenMaxId))
end

--- Start the file-based IPC server.
-- @return boolean  true if started successfully
-- @return string|nil  Error message on failure
function server.start()
    if isRunning then
        return true
    end

    ipcDir = getIpcDir()
    mkdirp(ipcDir)

    -- Verify directory is accessible
    local testPath = ipcDir .. ".mcp_test"
    local ok, err = writeFile(testPath, "ok")
    if not ok then
        return false, "Cannot write to IPC directory " .. ipcDir .. ": " .. tostring(err)
    end
    os.remove(testPath)

    -- Clean up any stale request/response files from previous sessions
    local staleReqs = findFilesByPrefix(ipcDir, "req_")
    for _, fname in ipairs(staleReqs) do
        os.remove(ipcDir .. fname)
    end
    local staleResps = findFilesByPrefix(ipcDir, "resp_")
    for _, fname in ipairs(staleResps) do
        os.remove(ipcDir .. fname)
    end

    -- Write a status file so the bridge knows we're running
    writeFile(ipcDir .. "status.json", json.encode({
        running = true,
        pid = "moho",
        version = "0.1.0",
        startedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }))

    isRunning = true
    print("[MohoMCP] Server started. IPC directory: " .. ipcDir)
    return true
end

--- Stop the IPC server.
function server.stop()
    if not isRunning then
        return
    end

    -- Remove status file
    os.remove(ipcDir .. "status.json")

    -- Clean up any remaining files
    local reqs = findFilesByPrefix(ipcDir, "req_")
    for _, fname in ipairs(reqs) do
        os.remove(ipcDir .. fname)
    end
    local resps = findFilesByPrefix(ipcDir, "resp_")
    for _, fname in ipairs(resps) do
        os.remove(ipcDir .. fname)
    end

    isRunning = false
    print("[MohoMCP] Server stopped")
end

--- Check if the server is currently running.
-- @return boolean
function server.isRunning()
    return isRunning
end

--- Process a single JSON-RPC request and return a response string.
-- @param requestStr string  The raw JSON-RPC request
-- @param moho  The MOHO ScriptInterface object
-- @return string  The JSON-RPC response string
local function processRequest(requestStr, moho)
    -- Parse the JSON-RPC request
    local request, parseErr = protocol.parseRequest(requestStr)
    if not request then
        return protocol.createError(nil, protocol.PARSE_ERROR, parseErr or "Parse error")
    end

    local method = request.method
    local params = request.params or {}
    local id = request.id

    -- Check allow-list
    if not validator.isAllowed(method) then
        return protocol.createError(id, protocol.METHOD_NOT_FOUND,
            "Method not found: " .. tostring(method))
    end

    -- Validate parameters
    local valid, validErr = validator.validateParams(method, params)
    if not valid then
        return protocol.createError(id, protocol.INVALID_PARAMS,
            validErr or "Invalid parameters")
    end

    -- Look up the handler
    local handler = handlers[method]
    if not handler then
        return protocol.createError(id, protocol.METHOD_NOT_FOUND,
            "No handler registered for: " .. tostring(method))
    end

    -- Execute the handler with pcall for safety
    local ok, result, handlerErr = pcall(handler, moho, params)
    if not ok then
        return protocol.createError(id, protocol.INTERNAL_ERROR,
            "Handler error: " .. tostring(result))
    end

    if result == nil and handlerErr then
        return protocol.createError(id, protocol.INTERNAL_ERROR,
            handlerErr)
    end

    return protocol.createResponse(id, result)
end

--- Poll for incoming request files and process them.
-- Call this from the Run or OnIdle callback.
-- Processes at most a few requests per call to avoid blocking the UI.
-- @param moho  The MOHO ScriptInterface object
function server.poll(moho)
    if not isRunning then
        return
    end

    -- Look for request files (req_*.json)
    local reqFiles = findFilesByPrefix(ipcDir, "req_")

    -- Process at most 2 requests per poll to keep UI responsive
    local processed = 0
    for _, fname in ipairs(reqFiles) do
        if processed >= 2 then
            break
        end

        local reqPath = ipcDir .. fname
        local content, readErr = readFile(reqPath)

        if content then
            -- Process the request (wrapped in pcall for resilience)
            local procOk, response = pcall(processRequest, content, moho)
            if not procOk then
                -- processRequest itself crashed — build an error response
                print("[MohoMCP] processRequest crashed: " .. tostring(response))
                response = protocol.createError(nil, protocol.INTERNAL_ERROR,
                    "Server crash: " .. tostring(response))
            end

            -- Extract request ID from filename: req_<id>.json -> resp_<id>.json
            local reqId = fname:match("^req_(.+)%.json$")
            if reqId then
                local respPath = ipcDir .. "resp_" .. reqId .. ".json"
                writeFile(respPath, response)
            end

            -- Remove the request file
            os.remove(reqPath)
            processed = processed + 1
        end
    end
end

--- Get server info for status display.
-- @return table  Server status info
function server.getInfo()
    return {
        running = isRunning,
        ipcDir = ipcDir,
    }
end

return server
