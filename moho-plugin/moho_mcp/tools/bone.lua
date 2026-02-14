-- bone.lua
-- Tool handlers for querying individual bone properties in Moho.
-- Returns a table of handler functions that accept (moho, params) and return
-- a result table on success, or nil + errorMessage on failure.

local bone = {}

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

--- Safely retrieve a skeleton and bone from layer + bone IDs.
-- @param moho  The global ScriptInterface object
-- @param layerId number  Absolute layer ID of a bone layer
-- @param boneId number  0-based bone index within the skeleton
-- @return userdata|nil  The bone object
-- @return userdata|nil  The skeleton object
-- @return string|nil  An error message on failure
local function getBone(moho, layerId, boneId)
    local lyr, err = getLayerById(moho, layerId)
    if not lyr then
        return nil, nil, err
    end

    -- Verify this is a bone layer using IsBoneType() method
    local isBoneOk, isBone = pcall(function() return lyr:IsBoneType() end)
    if not isBoneOk or not isBone then
        return nil, nil, "Layer " .. tostring(layerId) .. " is not a bone layer"
    end

    -- Cast to bone layer and get skeleton
    local bOk, boneLyr = pcall(function() return moho:LayerAsBone(lyr) end)
    if not bOk or not boneLyr then
        return nil, nil, "Failed to cast layer to bone layer"
    end

    local skelOk, skel = pcall(function() return boneLyr:Skeleton() end)
    if not skelOk or not skel then
        return nil, nil, "Failed to get skeleton from bone layer"
    end

    -- Validate bone index
    if type(boneId) ~= "number" then
        return nil, nil, "boneId must be a number"
    end

    local count = skel:CountBones()
    if boneId < 0 or boneId >= count then
        return nil, nil, "Bone index " .. tostring(boneId) .. " out of range (0.." .. tostring(count - 1) .. ")"
    end

    local boneOk, boneObj = pcall(function() return skel:Bone(boneId) end)
    if not boneOk or not boneObj then
        return nil, nil, "Failed to retrieve bone " .. tostring(boneId)
    end

    return boneObj, skel
end

--- Get detailed properties of a single bone.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain params.layerId (number) and params.boneId (number)
-- @return table|nil  A table of bone properties on success
-- @return string|nil  An error message on failure
function bone.getProperties(moho, params)
    if not params then
        return nil, "Missing parameters"
    end
    if params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if params.boneId == nil then
        return nil, "Missing required parameter: boneId"
    end

    local b, skel, err = getBone(moho, params.layerId, params.boneId)
    if not b then
        return nil, err
    end

    local result = {
        id       = params.boneId,
        layerId  = params.layerId,
    }

    -- Name
    local nOk, name = pcall(function() return b:Name() end)
    result.name = nOk and name or ""

    -- Position (rest / setup pose)
    result.position = vec2table(b.fPos)

    -- Angle (radians)
    local aOk, angle = pcall(function() return b.fAngle end)
    result.angle = (aOk and angle) or 0

    -- Scale
    local scOk, scale = pcall(function() return b.fScale end)
    result.scale = (scOk and scale) or 1

    -- Length
    local lOk, length = pcall(function() return b.fLength end)
    result.length = (lOk and length) or 0

    -- Parent bone index (-1 means no parent)
    local pOk, parent = pcall(function() return b.fParent end)
    result.parentId = (pOk and parent) or -1

    -- Selection state
    local selOk, sel = pcall(function() return b.fSelected end)
    result.selected = selOk and sel or false

    -- Constraints (if available)
    local constraints = {}

    local minOk, minAngle = pcall(function() return b.fMinConstraint end)
    if minOk and minAngle then
        constraints.minAngle = minAngle
    end

    local maxOk, maxAngle = pcall(function() return b.fMaxConstraint end)
    if maxOk and maxAngle then
        constraints.maxAngle = maxAngle
    end

    local conOk, conEnabled = pcall(function() return b.fConstraints end)
    if conOk then
        constraints.enabled = conEnabled and true or false
    end

    local posConOk, posCon = pcall(function() return b.fPosControl end)
    if posConOk then
        constraints.positionControl = posCon and true or false
    end

    local angleConOk, angleCon = pcall(function() return b.fAngleControl end)
    if angleConOk then
        constraints.angleControl = angleCon and true or false
    end

    local scaleConOk, scaleCon = pcall(function() return b.fScaleControl end)
    if scaleConOk then
        constraints.scaleControl = scaleCon and true or false
    end

    result.constraints = constraints

    -- Animated values at current frame
    local frame = 0
    pcall(function() frame = moho.document:CurrentFrame() end)

    local animated = {}

    -- Try to get the bone's animated position at the current frame
    local animPosOk, animPos = pcall(function()
        return b.fAnimPos:GetValue(frame)
    end)
    if animPosOk and animPos then
        animated.position = vec2table(animPos)
    end

    local animAngleOk, animAngle = pcall(function()
        return b.fAnimAngle:GetValue(frame)
    end)
    if animAngleOk and animAngle then
        animated.angle = animAngle
    end

    local animScaleOk, animScale = pcall(function()
        return b.fAnimScale:GetValue(frame)
    end)
    if animScaleOk and animScale then
        animated.scale = animScale
    end

    if next(animated) ~= nil then
        result.animated = animated
    end

    return result
end

--- Set the transform (angle, position, scale) of a bone at a specific frame.
-- Creates a keyframe automatically. All transform parameters are optional;
-- only supplied values are applied.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain layerId, boneId, frame; optionally angle, posX, posY, scale
-- @return table|nil  Confirmation on success
-- @return string|nil  An error message on failure
function bone.setTransform(moho, params)
    if not params then
        return nil, "Missing parameters"
    end
    if params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if params.boneId == nil then
        return nil, "Missing required parameter: boneId"
    end
    if params.frame == nil then
        return nil, "Missing required parameter: frame"
    end

    local b, skel, err = getBone(moho, params.layerId, params.boneId)
    if not b then
        return nil, err
    end

    local frame = params.frame

    -- Get the layer for PrepUndo
    local lyr = getLayerById(moho, params.layerId)
    moho.document:PrepUndo(lyr)

    local changed = {}

    -- Angle (radians)
    if params.angle ~= nil then
        local ok, setErr = pcall(function()
            b.fAnimAngle:SetValue(frame, params.angle)
        end)
        if ok then
            changed.angle = params.angle
        else
            return nil, "Failed to set angle: " .. tostring(setErr)
        end
    end

    -- Position
    if params.posX ~= nil or params.posY ~= nil then
        local ok, setErr = pcall(function()
            -- Get current position to preserve unchanged axis
            local cur = b.fAnimPos:GetValue(frame)
            local newX = params.posX or cur.x
            local newY = params.posY or cur.y
            local vec = LM.Vector2:new_local()
            vec.x = newX
            vec.y = newY
            b.fAnimPos:SetValue(frame, vec)
        end)
        if ok then
            changed.posX = params.posX
            changed.posY = params.posY
        else
            return nil, "Failed to set position: " .. tostring(setErr)
        end
    end

    -- Scale
    if params.scale ~= nil then
        local ok, setErr = pcall(function()
            b.fAnimScale:SetValue(frame, params.scale)
        end)
        if ok then
            changed.scale = params.scale
        else
            return nil, "Failed to set scale: " .. tostring(setErr)
        end
    end

    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
        boneId  = params.boneId,
        frame   = frame,
        changed = changed,
    }
end

--- Select a bone in the UI.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain layerId and boneId
-- @return table|nil  Confirmation on success
-- @return string|nil  An error message on failure
function bone.selectBone(moho, params)
    if not params then
        return nil, "Missing parameters"
    end
    if params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if params.boneId == nil then
        return nil, "Missing required parameter: boneId"
    end

    local b, skel, err = getBone(moho, params.layerId, params.boneId)
    if not b then
        return nil, err
    end

    local ok, selErr = pcall(function()
        skel:SelectNone()
        b.fSelected = true
    end)

    if not ok then
        return nil, "Failed to select bone: " .. tostring(selErr)
    end

    return {
        success = true,
        layerId = params.layerId,
        boneId  = params.boneId,
        boneName = b:Name(),
    }
end

return bone
