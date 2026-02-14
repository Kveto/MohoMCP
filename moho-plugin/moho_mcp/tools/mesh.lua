-- mesh.lua
-- Tool handlers for querying mesh (vector layer) data in Moho.
-- Returns a table of handler functions that accept (moho, params) and return
-- a result table on success, or nil + errorMessage on failure.

local mesh = {}

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

--- Retrieve the mesh object from a vector layer.
-- Validates the layer type and casts it before accessing the mesh.
-- @param moho  The global ScriptInterface object
-- @param layerId number  Absolute layer ID
-- @return userdata|nil  The mesh object
-- @return userdata|nil  The vector layer object
-- @return string|nil  An error message on failure
local function getMesh(moho, layerId)
    local lyr, err = getLayerById(moho, layerId)
    if not lyr then
        return nil, nil, err
    end

    -- Verify this is a vector layer
    -- No IsVectorType() method exists, so compare LayerType() against known constant
    local ltOk, lt = pcall(function() return lyr:LayerType() end)
    if not ltOk then
        return nil, nil, "Failed to read layer type"
    end

    local isVector = false
    pcall(function()
        local M = MOHO or (LM and LM.MOHO)
        if M and lt == M.LT_VECTOR then isVector = true end
    end)
    if not isVector then
        return nil, nil, "Layer " .. tostring(layerId) .. " is not a vector layer"
    end

    -- Cast to vector layer
    local vOk, vecLyr = pcall(function() return moho:LayerAsVector(lyr) end)
    if not vOk or not vecLyr then
        return nil, nil, "Failed to cast layer to vector layer"
    end

    -- Get mesh from the vector layer
    local mOk, meshObj = pcall(function() return vecLyr:Mesh() end)
    if not mOk or not meshObj then
        return nil, nil, "Failed to get mesh from vector layer"
    end

    return meshObj, vecLyr
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

--- Convert a Moho color value to a hex string.
-- Moho colors can be various types (userdata); this attempts a safe conversion.
local function colorToHex(color)
    if color == nil then
        return nil
    end

    -- Try reading r, g, b, a — force to numbers since MOHO may return userdata
    local ok, r, g, b, a = pcall(function()
        return tonumber(color.r), tonumber(color.g), tonumber(color.b), tonumber(color.a)
    end)

    if not ok or not r or not g or not b then
        return nil
    end

    -- If values are floats 0.0-1.0, scale to 0-255
    if r <= 1.0 and g <= 1.0 and b <= 1.0 then
        r = math.floor(r * 255 + 0.5)
        g = math.floor(g * 255 + 0.5)
        b = math.floor(b * 255 + 0.5)
        if a then
            a = math.floor(a * 255 + 0.5)
        end
    end

    if a and a < 255 then
        return string.format("#%02X%02X%02X%02X", r, g, b, a)
    else
        return string.format("#%02X%02X%02X", r, g, b)
    end
end

--- Get all points in a vector layer's mesh.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain params.layerId (number)
-- @return table|nil  A result table containing the points array
-- @return string|nil  An error message on failure
function mesh.getPoints(moho, params)
    if not params then
        return nil, "Missing parameters"
    end
    if params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local meshObj, vecLyr, err = getMesh(moho, params.layerId)
    if not meshObj then
        return nil, err
    end

    local countOk, pointCount = pcall(function() return meshObj:CountPoints() end)
    if not countOk then
        return nil, "Failed to count points: " .. tostring(pointCount)
    end

    local points = {}

    for i = 0, pointCount - 1 do
        local pOk, pt = pcall(function() return meshObj:Point(i) end)
        if pOk and pt then
            local entry = {
                index    = i,
                position = vec2table(pt.fPos),
            }

            -- Selection state
            local selOk, sel = pcall(function() return pt.fSelected end)
            entry.selected = selOk and sel or false

            points[#points + 1] = entry
        end
    end

    return {
        layerId    = params.layerId,
        pointCount = pointCount,
        points     = points,
    }
end

--- Get all shapes in a vector layer's mesh.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain params.layerId (number)
-- @return table|nil  A result table containing the shapes array
-- @return string|nil  An error message on failure
function mesh.getShapes(moho, params)
    if not params then
        return nil, "Missing parameters"
    end
    if params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local meshObj, vecLyr, err = getMesh(moho, params.layerId)
    if not meshObj then
        return nil, err
    end

    local countOk, shapeCount = pcall(function() return meshObj:CountShapes() end)
    if not countOk then
        return nil, "Failed to count shapes: " .. tostring(shapeCount)
    end

    local shapes = {}

    for i = 0, shapeCount - 1 do
        local sOk, shape = pcall(function() return meshObj:Shape(i) end)
        if sOk and shape then
            local entry = {
                index = i,
            }

            -- Shape name
            local nOk, name = pcall(function() return shape:Name() end)
            entry.name = nOk and name or ""

            -- Edge count
            local eOk, edgeCount = pcall(function() return shape:CountEdges() end)
            entry.edgeCount = eOk and edgeCount or 0

            -- Fill color
            local fillOk, fillColor = pcall(function()
                local style = shape.fMyStyle
                if style then
                    return style.fFillCol
                end
                return nil
            end)
            if fillOk and fillColor then
                entry.fillColor = colorToHex(fillColor)
            end

            -- Stroke color
            local strokeOk, strokeColor = pcall(function()
                local style = shape.fMyStyle
                if style then
                    return style.fLineCol
                end
                return nil
            end)
            if strokeOk and strokeColor then
                entry.strokeColor = colorToHex(strokeColor)
            end

            -- Stroke width
            local swOk, strokeWidth = pcall(function()
                local style = shape.fMyStyle
                if style then
                    return style.fLineWidth
                end
                return nil
            end)
            if swOk and strokeWidth then
                entry.strokeWidth = tonumber(strokeWidth) or 0
            end

            -- Whether the shape is filled / has a stroke
            local hasFillOk, hasFill = pcall(function()
                local style = shape.fMyStyle
                if style then
                    return style.fHasFill
                end
                return nil
            end)
            if hasFillOk and hasFill ~= nil then
                entry.hasFill = hasFill
            end

            local hasStrokeOk, hasStroke = pcall(function()
                local style = shape.fMyStyle
                if style then
                    return style.fHasLine
                end
                return nil
            end)
            if hasStrokeOk and hasStroke ~= nil then
                entry.hasStroke = hasStroke
            end

            shapes[#shapes + 1] = entry
        end
    end

    return {
        layerId    = params.layerId,
        shapeCount = shapeCount,
        shapes     = shapes,
    }
end

return mesh
