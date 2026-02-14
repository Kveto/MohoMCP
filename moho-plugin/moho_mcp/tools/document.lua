-- document.lua
-- Tool handlers for querying document-level information in Moho.
-- Returns a table of handler functions that accept (moho, params) and return
-- a result table on success, or nil + errorMessage on failure.

local document = {}

-- Map numeric layer type constants to human-readable strings.
-- Uses pcall so the module can be loaded outside Moho for testing.
local LAYER_TYPE_NAMES = {}
local function initLayerTypeNames()
    if next(LAYER_TYPE_NAMES) ~= nil then
        return
    end
    -- Try MOHO global first, then LM.MOHO
    local M = nil
    pcall(function() M = MOHO end)
    if not M then
        pcall(function() M = LM.MOHO end)
    end
    if M then
        pcall(function() LAYER_TYPE_NAMES[M.LT_VECTOR]   = "vector" end)
        pcall(function() LAYER_TYPE_NAMES[M.LT_BONE]     = "bone" end)
        pcall(function() LAYER_TYPE_NAMES[M.LT_GROUP]    = "group" end)
        pcall(function() LAYER_TYPE_NAMES[M.LT_IMAGE]    = "image" end)
        pcall(function() LAYER_TYPE_NAMES[M.LT_AUDIO]    = "audio" end)
        pcall(function() LAYER_TYPE_NAMES[M.LT_SWITCH]   = "switch" end)
        pcall(function() LAYER_TYPE_NAMES[M.LT_PARTICLE] = "particle" end)
        pcall(function() LAYER_TYPE_NAMES[M.LT_NOTE]     = "note" end)
        pcall(function() LAYER_TYPE_NAMES[M.LT_PATCH]    = "patch" end)
    end
end

--- Return a human-readable name for a Moho layer type constant.
-- @param layerType number  The numeric layer type from layer:LayerType()
-- @return string  The human-readable type name, or "unknown"
local function layerTypeName(layerType)
    initLayerTypeNames()
    return LAYER_TYPE_NAMES[layerType] or "unknown"
end

--- Recursively build an array describing the children of a group layer.
-- @param moho  The global ScriptInterface object
-- @param groupLayer  A group-layer object (already cast via moho:LayerAsGroup)
-- @param parentId  The absolute ID of the parent group layer, or -1 for root
-- @return table  An array of layer descriptor tables
local function collectChildren(moho, groupLayer, parentId)
    local children = {}
    local count = groupLayer:CountLayers()

    for i = 0, count - 1 do
        local ok, childOrErr = pcall(function() return groupLayer:Layer(i) end)
        if ok and childOrErr then
            local child = childOrErr
            local idOk, absId = pcall(function() return moho.document:LayerAbsoluteID(child) end)
            local entry = {
                id       = idOk and absId or -1,
                name     = child:Name(),
                type     = layerTypeName(child:LayerType()),
                visible  = child:IsVisible(),
                locked   = child:IsLocked(),
                parentId = parentId,
                children = {}
            }

            -- Recurse into group layers
            if child:IsGroupType() then
                local gOk, group = pcall(function() return moho:LayerAsGroup(child) end)
                if gOk and group then
                    entry.children = collectChildren(moho, group, entry.id)
                end
            end

            children[#children + 1] = entry
        end
    end

    return children
end

--- Get general document information.
-- @param moho  The global ScriptInterface object
-- @param params table  (unused)
-- @return table|nil  A table of document properties on success
-- @return string|nil  An error message on failure
function document.getInfo(moho, params)
    local ok, err = pcall(function()
        if not moho or not moho.document then
            error("No active document")
        end
    end)
    if not ok then
        return nil, tostring(err)
    end

    local doc = moho.document

    local result = {}

    -- Name and path
    local nOk, name = pcall(function() return doc:Name() end)
    result.name = nOk and name or ""

    local pOk, path = pcall(function() return doc:Path() end)
    result.filePath = pOk and path or ""

    -- Dimensions
    local wOk, w = pcall(function() return doc:Width() end)
    result.width = wOk and w or 0

    local hOk, h = pcall(function() return doc:Height() end)
    result.height = hOk and h or 0

    -- Timing
    local fOk, fps = pcall(function() return doc:Fps() end)
    result.fps = fOk and fps or 24

    local sOk, sf = pcall(function() return doc:StartFrame() end)
    result.startFrame = sOk and sf or 0

    local eOk, ef = pcall(function() return doc:EndFrame() end)
    result.endFrame = eOk and ef or 0

    local cOk, cf = pcall(function() return doc:CurrentFrame() end)
    result.currentFrame = cOk and cf or 0

    -- Duration in seconds
    if result.fps > 0 then
        result.duration = (result.endFrame - result.startFrame) / result.fps
    else
        result.duration = 0
    end

    -- Layer count summary
    local tlOk, tl = pcall(function() return doc:TotalLayerCount() end)
    result.totalLayers = tlOk and tl or 0

    local clOk, cl = pcall(function() return doc:CountLayers() end)
    result.topLevelLayers = clOk and cl or 0

    return result
end

--- Get the full layer tree of the document.
-- Recursively walks all layers and returns a hierarchical structure.
-- @param moho  The global ScriptInterface object
-- @param params table  (unused)
-- @return table|nil  An array of top-level layer descriptors (each may contain children)
-- @return string|nil  An error message on failure
function document.getLayers(moho, params)
    if not moho or not moho.document then
        return nil, "No active document"
    end

    local doc = moho.document
    local layers = {}

    local countOk, topCount = pcall(function() return doc:CountLayers() end)
    if not countOk then
        return nil, "Failed to count top-level layers: " .. tostring(topCount)
    end

    for i = 0, topCount - 1 do
        local ok, layerOrErr = pcall(function() return doc:Layer(i) end)
        if ok and layerOrErr then
            local lyr = layerOrErr
            local idOk, absId = pcall(function() return doc:LayerAbsoluteID(lyr) end)
            local entry = {
                id       = idOk and absId or -1,
                name     = lyr:Name(),
                type     = layerTypeName(lyr:LayerType()),
                visible  = lyr:IsVisible(),
                locked   = lyr:IsLocked(),
                parentId = -1,
                children = {}
            }

            if lyr:IsGroupType() then
                local gOk, group = pcall(function() return moho:LayerAsGroup(lyr) end)
                if gOk and group then
                    entry.children = collectChildren(moho, group, entry.id)
                end
            end

            layers[#layers + 1] = entry
        end
    end

    return layers
end

--- Navigate to a specific frame on the timeline.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain frame (number)
-- @return table|nil  Confirmation on success
-- @return string|nil  An error message on failure
function document.setFrame(moho, params)
    if not params or params.frame == nil then
        return nil, "Missing required parameter: frame"
    end

    if not moho or not moho.document then
        return nil, "No active document"
    end

    local frame = params.frame
    if type(frame) ~= "number" then
        return nil, "frame must be a number"
    end

    local ok, setErr = pcall(function()
        moho:SetCurFrame(frame)
    end)

    if not ok then
        return nil, "Failed to set frame: " .. tostring(setErr)
    end

    -- Read back the actual current frame to confirm
    local curFrame = frame
    pcall(function() curFrame = moho.document:CurrentFrame() end)

    return {
        success = true,
        frame   = curFrame,
    }
end

--- Render the scene to a temporary PNG and return the file path.
-- The bridge will read the file, base64-encode it, and return an MCP image.
-- @param moho  The global ScriptInterface object
-- @param params table  Optional: frame (number), width (number), height (number)
-- @return table|nil  {success, filePath, frame, width, height} on success
-- @return string|nil  An error message on failure
function document.screenshot(moho, params)
    if not moho or not moho.document then
        return nil, "No active document"
    end

    params = params or {}
    local doc = moho.document

    -- Navigate to requested frame if specified
    if params.frame ~= nil then
        if type(params.frame) ~= "number" then
            return nil, "frame must be a number"
        end
        local ok, err = pcall(function() moho:SetCurFrame(params.frame) end)
        if not ok then
            return nil, "Failed to set frame: " .. tostring(err)
        end
    end

    -- Read current frame
    local curFrame = 0
    pcall(function() curFrame = doc:CurrentFrame() end)

    -- Get document dimensions
    local docWidth = 0
    local docHeight = 0
    pcall(function() docWidth = doc:Width() end)
    pcall(function() docHeight = doc:Height() end)

    local renderWidth = params.width or docWidth
    local renderHeight = params.height or docHeight

    if renderWidth <= 0 or renderHeight <= 0 then
        return nil, "Invalid render dimensions: " .. renderWidth .. "x" .. renderHeight
    end

    -- Build unique temp file path
    local tempDir = os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
    local mcpDir = tempDir .. "/moho-mcp"
    os.execute('mkdir "' .. mcpDir .. '" 2>NUL')

    local timestamp = tostring(os.clock()):gsub("%.", "_")
    local tempPath = mcpDir .. "/render_" .. timestamp .. ".png"

    -- Render the scene
    local renderOk, renderErr = pcall(function()
        moho:FileRender(tempPath)
    end)

    if not renderOk then
        return nil, "FileRender failed: " .. tostring(renderErr)
    end

    -- Verify the file was created
    local f = io.open(tempPath, "rb")
    if not f then
        return nil, "Render file was not created at: " .. tempPath
    end
    f:close()

    return {
        success  = true,
        filePath = tempPath,
        frame    = curFrame,
        width    = renderWidth,
        height   = renderHeight,
    }
end

return document
