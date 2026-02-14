-- layer.lua
-- Tool handlers for querying individual layer properties in Moho.
-- Returns a table of handler functions that accept (moho, params) and return
-- a result table on success, or nil + errorMessage on failure.

local layer = {}

-- Map numeric layer type constants to human-readable strings.
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

local function layerTypeName(layerType)
    initLayerTypeNames()
    return LAYER_TYPE_NAMES[layerType] or "unknown"
end

--- Safely retrieve a layer by its absolute ID.
-- @param moho  The global ScriptInterface object
-- @param layerId number  The absolute layer ID
-- @return userdata|nil  The layer object, or nil
-- @return string|nil  An error message on failure
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

--- Convert an LM.Vector2 (or similar) to a plain {x, y} table.
-- Falls back gracefully if the value is not a vector.
local function vec2table(v)
    if v == nil then
        return { x = 0, y = 0 }
    end
    local ok, x, y = pcall(function() return v.x, v.y end)
    if ok then
        return { x = x or 0, y = y or 0 }
    end
    return { x = 0, y = 0 }
end

--- Read the static transform properties of a layer.
-- Wraps each accessor in pcall so a missing channel does not abort everything.
local function readTransform(lyr, frame)
    local transform = {}
    frame = frame or 0

    -- Translation via fTranslation (AnimVec2)
    local tOk, tx, ty = pcall(function()
        local val = lyr.fTranslation:GetValue(frame)
        return val.x, val.y
    end)
    if tOk then
        transform.translation = { x = tx, y = ty }
    else
        transform.translation = { x = 0, y = 0 }
    end

    -- Rotation via fRotationZ (AnimVal, radians)
    local rOk, rVal = pcall(function()
        return lyr.fRotationZ:GetValue(frame)
    end)
    transform.rotation = rOk and rVal or 0

    -- Scale via fScale (AnimVec2)
    local sOk, sx, sy = pcall(function()
        local val = lyr.fScale:GetValue(frame)
        return val.x, val.y
    end)
    if sOk then
        transform.scale = { x = sx, y = sy }
    else
        transform.scale = { x = 1, y = 1 }
    end

    return transform
end

--- Get detailed properties of a single layer.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain params.layerId (number)
-- @return table|nil  A table of layer properties on success
-- @return string|nil  An error message on failure
function layer.getProperties(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    local result = {
        id      = params.layerId,
        name    = lyr:Name(),
        type    = layerTypeName(lyr:LayerType()),
        visible = lyr:IsVisible(),
        locked  = lyr:IsLocked(),
    }

    -- Opacity via fAlpha AnimVal channel
    local opOk, opacity = pcall(function()
        local frame = moho.document:CurrentFrame()
        return lyr.fAlpha:GetValue(frame)
    end)
    result.opacity = opOk and opacity or 1.0

    -- Blend mode
    local bmOk, blendMode = pcall(function() return lyr:BlendingMode() end)
    result.blendMode = bmOk and blendMode or 0

    -- Current frame for reading animated transform values
    local frame = 0
    local fOk, f = pcall(function() return moho.document:CurrentFrame() end)
    if fOk then frame = f end

    result.transform = readTransform(lyr, frame)

    -- Extras depending on type
    if lyr:IsGroupType() then
        local gOk, group = pcall(function() return moho:LayerAsGroup(lyr) end)
        if gOk and group then
            result.childCount = group:CountLayers()
        end
    end

    local lt = lyr:LayerType()
    initLayerTypeNames()
    if LAYER_TYPE_NAMES[lt] == "bone" then
        local bOk, boneLyr = pcall(function() return moho:LayerAsBone(lyr) end)
        if bOk and boneLyr then
            local skelOk, skel = pcall(function() return boneLyr:Skeleton() end)
            if skelOk and skel then
                result.boneCount = skel:CountBones()
            end
        end
    elseif LAYER_TYPE_NAMES[lt] == "vector" then
        local vOk, vecLyr = pcall(function() return moho:LayerAsVector(lyr) end)
        if vOk and vecLyr then
            local mOk, mesh = pcall(function() return vecLyr:Mesh() end)
            if mOk and mesh then
                result.pointCount = mesh:CountPoints()
                result.shapeCount = mesh:CountShapes()
            end
        end
    end

    return result
end

--- Get direct children of a group layer.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain params.layerId (number) pointing to a group layer
-- @return table|nil  An array of child-layer summary tables on success
-- @return string|nil  An error message on failure
function layer.getChildren(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    if not lyr:IsGroupLayer() then
        return nil, "Layer " .. tostring(params.layerId) .. " is not a group layer"
    end

    local gOk, group = pcall(function() return moho:LayerAsGroup(lyr) end)
    if not gOk or not group then
        return nil, "Failed to cast layer to group: " .. tostring(group)
    end

    local children = {}
    local count = group:CountLayers()

    for i = 0, count - 1 do
        local cOk, child = pcall(function() return group:Layer(i) end)
        if cOk and child then
            children[#children + 1] = {
                id      = moho.document:LayerAbsoluteID(child),
                name    = child:Name(),
                type    = layerTypeName(child:LayerType()),
                visible = child:IsVisible(),
                locked  = child:IsLocked(),
                isGroup = child:IsGroupType(),
            }
        end
    end

    return children
end

--- Get all bones in a bone layer.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain params.layerId (number) pointing to a bone layer
-- @return table|nil  An array of bone descriptor tables on success
-- @return string|nil  An error message on failure
function layer.getBones(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    local isBoneOk, isBone = pcall(function() return lyr:IsBoneType() end)
    if not isBoneOk or not isBone then
        return nil, "Layer " .. tostring(params.layerId) .. " is not a bone layer"
    end

    local bOk, boneLyr = pcall(function() return moho:LayerAsBone(lyr) end)
    if not bOk or not boneLyr then
        return nil, "Failed to cast layer to bone layer: " .. tostring(boneLyr)
    end

    local skelOk, skel = pcall(function() return boneLyr:Skeleton() end)
    if not skelOk or not skel then
        return nil, "Failed to get skeleton: " .. tostring(skel)
    end

    local bones = {}
    local count = skel:CountBones()

    for i = 0, count - 1 do
        local ok, boneOrErr = pcall(function() return skel:Bone(i) end)
        if ok and boneOrErr then
            local b = boneOrErr
            local entry = {
                id       = i,
                name     = b:Name(),
                position = vec2table(b.fPos),
                angle    = b.fAngle or 0,
                scale    = b.fScale or 1,
                length   = b.fLength or 0,
                parentId = b.fParent or -1,
                selected = b.fSelected or false,
            }
            bones[#bones + 1] = entry
        end
    end

    return bones
end

--- Set the transform of a layer at a specific frame.
-- All transform parameters are optional; only supplied values are applied.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain layerId, frame; optionally transX, transY, rotation, scaleX, scaleY
-- @return table|nil  Confirmation on success
-- @return string|nil  An error message on failure
function layer.setTransform(moho, params)
    if not params or params.layerId == nil then
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
    moho.document:PrepUndo(lyr)

    local changed = {}

    -- Translation
    if params.transX ~= nil or params.transY ~= nil then
        local ok, setErr = pcall(function()
            local cur = lyr.fTranslation:GetValue(frame)
            local newX = params.transX or cur.x
            local newY = params.transY or cur.y
            local vec = LM.Vector2:new_local()
            vec.x = newX
            vec.y = newY
            lyr.fTranslation:SetValue(frame, vec)
        end)
        if ok then
            changed.transX = params.transX
            changed.transY = params.transY
        else
            return nil, "Failed to set translation: " .. tostring(setErr)
        end
    end

    -- Rotation (radians)
    if params.rotation ~= nil then
        local ok, setErr = pcall(function()
            lyr.fRotationZ:SetValue(frame, params.rotation)
        end)
        if ok then
            changed.rotation = params.rotation
        else
            return nil, "Failed to set rotation: " .. tostring(setErr)
        end
    end

    -- Scale
    if params.scaleX ~= nil or params.scaleY ~= nil then
        local ok, setErr = pcall(function()
            local cur = lyr.fScale:GetValue(frame)
            local newX = params.scaleX or cur.x
            local newY = params.scaleY or cur.y
            local vec = LM.Vector2:new_local()
            vec.x = newX
            vec.y = newY
            lyr.fScale:SetValue(frame, vec)
        end)
        if ok then
            changed.scaleX = params.scaleX
            changed.scaleY = params.scaleY
        else
            return nil, "Failed to set scale: " .. tostring(setErr)
        end
    end

    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
        frame   = frame,
        changed = changed,
    }
end

--- Set visibility of a layer.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain layerId and visible (boolean)
-- @return table|nil  Confirmation on success
-- @return string|nil  An error message on failure
function layer.setVisibility(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if params.visible == nil then
        return nil, "Missing required parameter: visible"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    moho.document:PrepUndo(lyr)

    local ok, setErr = pcall(function()
        lyr:SetVisible(params.visible == true)
    end)

    if not ok then
        return nil, "Failed to set visibility: " .. tostring(setErr)
    end

    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
        visible = params.visible == true,
    }
end

--- Set opacity of a layer at a specific frame.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain layerId, frame, opacity (0.0 to 1.0)
-- @return table|nil  Confirmation on success
-- @return string|nil  An error message on failure
function layer.setOpacity(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if params.frame == nil then
        return nil, "Missing required parameter: frame"
    end
    if params.opacity == nil then
        return nil, "Missing required parameter: opacity"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    moho.document:PrepUndo(lyr)

    local ok, setErr = pcall(function()
        lyr.fAlpha:SetValue(params.frame, params.opacity)
    end)

    if not ok then
        return nil, "Failed to set opacity: " .. tostring(setErr)
    end

    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
        frame   = params.frame,
        opacity = params.opacity,
    }
end

--- Rename a layer.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain layerId and name (string)
-- @return table|nil  Confirmation on success
-- @return string|nil  An error message on failure
function layer.setName(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if type(params.name) ~= "string" then
        return nil, "Missing required parameter: name (string)"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    moho.document:PrepUndo(lyr)

    local ok, setErr = pcall(function()
        lyr:SetName(params.name)
    end)

    if not ok then
        return nil, "Failed to set name: " .. tostring(setErr)
    end

    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
        name    = params.name,
    }
end

--- Select a layer in the UI.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain layerId
-- @return table|nil  Confirmation on success
-- @return string|nil  An error message on failure
function layer.selectLayer(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    local ok, selErr = pcall(function()
        moho:SetSelLayer(lyr)
    end)

    if not ok then
        return nil, "Failed to select layer: " .. tostring(selErr)
    end

    return {
        success = true,
        layerId = params.layerId,
        name    = lyr:Name(),
    }
end

return layer
