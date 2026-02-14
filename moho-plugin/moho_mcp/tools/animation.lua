-- animation.lua
-- Tool handlers for querying animation channels and keyframe data in Moho.
-- Returns a table of handler functions that accept (moho, params) and return
-- a result table on success, or nil + errorMessage on failure.

local animation = {}

--- Safely retrieve a layer by its absolute ID.
local function getLayerById(moho, layerId)
    if not moho or not moho.document then
        return nil, "No active document"
    end

    if type(layerId) ~= "number" then
        return nil, "layerId must be a number"
    end

    local ok, lyr = pcall(function()
        return moho.document:LayerByAbsoluteID(layerId)
    end)

    if not ok or not lyr then
        return nil, "Layer not found with absolute ID " .. tostring(layerId)
    end

    return lyr
end

--- Convert an LM.Vector2 (userdata) to a plain table with numeric values.
local function vec2table(v)
    if v == nil then
        return { x = 0, y = 0 }
    end
    local ok, x, y = pcall(function() return tonumber(v.x) or 0, tonumber(v.y) or 0 end)
    if ok then
        return { x = x, y = y }
    end
    return { x = 0, y = 0 }
end

--- Force a value to a plain Lua number (handles MOHO userdata wrappers).
local function toPlainNumber(val, default)
    if val == nil then return default or 0 end
    local n = tonumber(val)
    if n then return n end
    -- Some MOHO types expose a value via tostring
    local s = tostring(val)
    return tonumber(s) or default or 0
end

--- Map a human-readable channel name to the corresponding Moho channel accessor.
-- Each mapping entry is a table: { getter = function(layer), valueConverter = function(val) }
-- The getter retrieves the animation channel object from the layer.
-- The valueConverter turns the raw value into a JSON-friendly Lua type.
local CHANNEL_MAP = {
    translation = {
        getter = function(lyr) return lyr.fTranslation end,
        valueConverter = function(val) return vec2table(val) end,
    },
    position = {
        getter = function(lyr) return lyr.fTranslation end,
        valueConverter = function(val) return vec2table(val) end,
    },
    rotation = {
        getter = function(lyr) return lyr.fRotationZ end,
        valueConverter = function(val) return toPlainNumber(val, 0) end,
    },
    scale = {
        getter = function(lyr) return lyr.fScale end,
        valueConverter = function(val) return vec2table(val) end,
    },
    opacity = {
        getter = function(lyr) return lyr.fAlpha end,
        valueConverter = function(val) return toPlainNumber(val, 1.0) end,
    },
    shear = {
        getter = function(lyr) return lyr.fShear end,
        valueConverter = function(val) return toPlainNumber(val, 0) end,
    },
}

--- Map an interpolation mode to a human-readable name.
-- Built lazily on first call with pcall per constant for safety.
local INTERP_NAMES = nil
local function interpName(interpMode)
    if interpMode == nil then
        return "unknown"
    end
    if INTERP_NAMES == nil then
        INTERP_NAMES = {}
        local function tryMap(constName, label)
            pcall(function()
                local M = MOHO or (LM and LM.MOHO)
                if M and M[constName] ~= nil then
                    INTERP_NAMES[M[constName]] = label
                end
            end)
        end
        tryMap("INTERP_LINEAR",   "linear")
        tryMap("INTERP_SMOOTH",   "smooth")
        tryMap("INTERP_EASE_IN",  "ease_in")
        tryMap("INTERP_EASE_OUT", "ease_out")
        tryMap("INTERP_STEP",     "step")
        tryMap("INTERP_NOISY",    "noisy")
        tryMap("INTERP_CYCLE",    "cycle")
    end
    return INTERP_NAMES[interpMode] or tostring(interpMode)
end

--- Get keyframes for a specific animation channel on a layer.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain:
--   params.layerId (number) - absolute layer ID
--   params.channel (string) - channel name ("translation", "rotation", "scale", "opacity", "shear")
-- @return table|nil  An array of keyframe descriptors on success
-- @return string|nil  An error message on failure
function animation.getKeyframes(moho, params)
    if not params then
        return nil, "Missing parameters"
    end
    if params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if type(params.channel) ~= "string" or params.channel == "" then
        return nil, "Missing required parameter: channel (string)"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    local channelName = string.lower(params.channel)
    local mapping = CHANNEL_MAP[channelName]
    if not mapping then
        local validNames = {}
        for k, _ in pairs(CHANNEL_MAP) do
            validNames[#validNames + 1] = k
        end
        table.sort(validNames)
        return nil, "Unknown channel '" .. params.channel .. "'. Valid channels: " .. table.concat(validNames, ", ")
    end

    -- Get the animation channel object from the layer
    local chOk, channel = pcall(function() return mapping.getter(lyr) end)
    if not chOk or not channel then
        return nil, "Failed to get '" .. channelName .. "' channel from layer: " .. tostring(channel)
    end

    -- Read keyframe count
    local countOk, keyCount = pcall(function() return channel:CountKeys() end)
    if not countOk then
        return nil, "Failed to count keyframes: " .. tostring(keyCount)
    end

    local keyframes = {}

    for i = 0, keyCount - 1 do
        local entry = {}

        -- Frame number for this key
        local fOk, frame = pcall(function() return channel:GetKeyWhen(i) end)
        if fOk then
            entry.frame = frame
        else
            entry.frame = i -- fallback
        end

        -- Value at this keyframe
        local vOk, val = pcall(function() return channel:GetValue(entry.frame) end)
        if vOk and val ~= nil then
            local cvOk, converted = pcall(function() return mapping.valueConverter(val) end)
            entry.value = cvOk and converted or tostring(val)
        else
            entry.value = nil
        end

        -- Interpolation mode
        local iOk, interp = pcall(function() return channel:GetKeyInterpMode(i) end)
        if iOk and interp ~= nil then
            entry.interpolation = interpName(interp)
        else
            entry.interpolation = "unknown"
        end

        keyframes[#keyframes + 1] = entry
    end

    return {
        layerId  = params.layerId,
        channel  = channelName,
        keyCount = keyCount,
        keyframes = keyframes,
    }
end

--- Get all animated property values for a layer at a specific frame.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain:
--   params.layerId (number) - absolute layer ID
--   params.frame (number)   - the frame number to query
-- @return table|nil  A table of property values at the given frame
-- @return string|nil  An error message on failure
function animation.getFrameState(moho, params)
    if not params then
        return nil, "Missing parameters"
    end
    if params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if params.frame == nil then
        return nil, "Missing required parameter: frame"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    local frame = params.frame

    -- Validate frame is within document range
    local doc = moho.document
    local startFrame = 0
    local endFrame = 0
    pcall(function() startFrame = doc:StartFrame() end)
    pcall(function() endFrame = doc:EndFrame() end)

    if type(frame) ~= "number" then
        return nil, "frame must be a number"
    end

    local result = {
        layerId = params.layerId,
        frame   = frame,
    }

    -- Translation via fTranslation (AnimVec2)
    local tOk, tVal = pcall(function()
        return lyr.fTranslation:GetValue(frame)
    end)
    if tOk and tVal then
        result.translation = vec2table(tVal)
    else
        result.translation = { x = 0, y = 0 }
    end

    -- Rotation via fRotationZ (AnimVal)
    local rOk, rVal = pcall(function()
        return lyr.fRotationZ:GetValue(frame)
    end)
    result.rotation = rOk and toPlainNumber(rVal, 0) or 0

    -- Scale via fScale (AnimVec2)
    local sOk, sVal = pcall(function()
        return lyr.fScale:GetValue(frame)
    end)
    if sOk and sVal then
        result.scale = vec2table(sVal)
    else
        result.scale = { x = 1, y = 1 }
    end

    -- Opacity via fAlpha (AnimVal)
    local opOk, opVal = pcall(function()
        return lyr.fAlpha:GetValue(frame)
    end)
    result.opacity = opOk and toPlainNumber(opVal, 1.0) or 1.0

    -- Shear via fShear (AnimVal)
    local shOk, shVal = pcall(function()
        return lyr.fShear:GetValue(frame)
    end)
    result.shear = shOk and toPlainNumber(shVal, 0) or 0

    -- Visibility (layer-level, not channel-based in most cases)
    local visOk, vis = pcall(function() return lyr:IsVisible() end)
    result.visible = visOk and (vis == true) or true

    return result
end

--- Set a keyframe value on an animation channel.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain layerId, channel, frame, value
-- @return table|nil  Confirmation on success
-- @return string|nil  An error message on failure
function animation.setKeyframe(moho, params)
    if not params then
        return nil, "Missing parameters"
    end
    if params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if type(params.channel) ~= "string" or params.channel == "" then
        return nil, "Missing required parameter: channel (string)"
    end
    if params.frame == nil then
        return nil, "Missing required parameter: frame"
    end
    if params.value == nil then
        return nil, "Missing required parameter: value"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    local channelName = string.lower(params.channel)
    local mapping = CHANNEL_MAP[channelName]
    if not mapping then
        local validNames = {}
        for k, _ in pairs(CHANNEL_MAP) do
            validNames[#validNames + 1] = k
        end
        table.sort(validNames)
        return nil, "Unknown channel '" .. params.channel .. "'. Valid channels: " .. table.concat(validNames, ", ")
    end

    local chOk, channel = pcall(function() return mapping.getter(lyr) end)
    if not chOk or not channel then
        return nil, "Failed to get '" .. channelName .. "' channel from layer"
    end

    moho.document:PrepUndo(lyr)

    local frame = params.frame
    local value = params.value

    local ok, setErr = pcall(function()
        -- For vec2 channels (translation, scale), value should be {x, y}
        if channelName == "translation" or channelName == "position" or channelName == "scale" then
            local vec = LM.Vector2:new_local()
            if type(value) == "table" then
                vec.x = value.x or value[1] or 0
                vec.y = value.y or value[2] or 0
            else
                vec.x = value
                vec.y = value
            end
            channel:SetValue(frame, vec)
        else
            -- Scalar channels (rotation, opacity, shear)
            channel:SetValue(frame, value)
        end
    end)

    if not ok then
        return nil, "Failed to set keyframe: " .. tostring(setErr)
    end

    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
        channel = channelName,
        frame   = frame,
        value   = value,
    }
end

--- Delete a keyframe from an animation channel.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain layerId, channel, frame
-- @return table|nil  Confirmation on success
-- @return string|nil  An error message on failure
function animation.deleteKeyframe(moho, params)
    if not params then
        return nil, "Missing parameters"
    end
    if params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if type(params.channel) ~= "string" or params.channel == "" then
        return nil, "Missing required parameter: channel (string)"
    end
    if params.frame == nil then
        return nil, "Missing required parameter: frame"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    local channelName = string.lower(params.channel)
    local mapping = CHANNEL_MAP[channelName]
    if not mapping then
        local validNames = {}
        for k, _ in pairs(CHANNEL_MAP) do
            validNames[#validNames + 1] = k
        end
        table.sort(validNames)
        return nil, "Unknown channel '" .. params.channel .. "'. Valid channels: " .. table.concat(validNames, ", ")
    end

    local chOk, channel = pcall(function() return mapping.getter(lyr) end)
    if not chOk or not channel then
        return nil, "Failed to get '" .. channelName .. "' channel from layer"
    end

    moho.document:PrepUndo(lyr)

    local ok, delErr = pcall(function()
        channel:DeleteKey(params.frame)
    end)

    if not ok then
        return nil, "Failed to delete keyframe: " .. tostring(delErr)
    end

    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
        channel = channelName,
        frame   = params.frame,
    }
end

--- Set interpolation mode on a keyframe.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain layerId, channel, frame, mode (string: "linear", "smooth", "ease_in", "ease_out", "step")
-- @return table|nil  Confirmation on success
-- @return string|nil  An error message on failure
function animation.setInterpolation(moho, params)
    if not params then
        return nil, "Missing parameters"
    end
    if params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if type(params.channel) ~= "string" or params.channel == "" then
        return nil, "Missing required parameter: channel (string)"
    end
    if params.frame == nil then
        return nil, "Missing required parameter: frame"
    end
    if type(params.mode) ~= "string" or params.mode == "" then
        return nil, "Missing required parameter: mode (string)"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    local channelName = string.lower(params.channel)
    local mapping = CHANNEL_MAP[channelName]
    if not mapping then
        return nil, "Unknown channel '" .. params.channel .. "'"
    end

    local chOk, channel = pcall(function() return mapping.getter(lyr) end)
    if not chOk or not channel then
        return nil, "Failed to get '" .. channelName .. "' channel from layer"
    end

    -- Map mode string to MOHO constant
    local M = MOHO or (LM and LM.MOHO)
    if not M then
        return nil, "Cannot access MOHO constants"
    end

    local modeMap = {
        linear   = M.INTERP_LINEAR,
        smooth   = M.INTERP_SMOOTH,
        ease_in  = M.INTERP_EASE_IN,
        ease_out = M.INTERP_EASE_OUT,
        step     = M.INTERP_STEP,
    }

    local modeName = string.lower(params.mode)
    local interpMode = modeMap[modeName]
    if interpMode == nil then
        return nil, "Unknown interpolation mode '" .. params.mode .. "'. Valid modes: linear, smooth, ease_in, ease_out, step"
    end

    moho.document:PrepUndo(lyr)

    -- Find the key index for this frame
    local ok, setErr = pcall(function()
        local keyCount = channel:CountKeys()
        for i = 0, keyCount - 1 do
            if channel:GetKeyWhen(i) == params.frame then
                channel:SetKeyInterp(i, interpMode, 0, 0)
                return
            end
        end
        error("No keyframe found at frame " .. tostring(params.frame))
    end)

    if not ok then
        return nil, "Failed to set interpolation: " .. tostring(setErr)
    end

    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
        channel = channelName,
        frame   = params.frame,
        mode    = modeName,
    }
end

return animation
