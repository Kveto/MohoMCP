-- validator.lua
-- Allow-list validator for MohoMCP methods and parameter validation
-- Validates incoming JSON-RPC method names and their parameters against expected schemas.

local validator = {}

-- Allow-list of tool method names
local allowedMethods = {
    -- Phase 1: Read-only tools
    ["document.getInfo"]       = true,
    ["document.getLayers"]     = true,
    ["layer.getProperties"]    = true,
    ["layer.getChildren"]      = true,
    ["layer.getBones"]         = true,
    ["bone.getProperties"]     = true,
    ["animation.getKeyframes"] = true,
    ["animation.getFrameState"]= true,
    ["mesh.getPoints"]         = true,
    ["mesh.getShapes"]         = true,
    -- Phase 2: Write tools
    ["bone.setTransform"]             = true,
    ["bone.selectBone"]               = true,
    ["layer.setTransform"]            = true,
    ["layer.setVisibility"]           = true,
    ["layer.setOpacity"]              = true,
    ["layer.setName"]                 = true,
    ["layer.selectLayer"]             = true,
    ["animation.setKeyframe"]         = true,
    ["animation.deleteKeyframe"]      = true,
    ["animation.setInterpolation"]    = true,
    ["document.setFrame"]             = true,
    -- Phase 3: Visual feedback
    ["document.screenshot"]           = true,
    -- Batch execution
    ["batch.execute"]                 = true,
}

-- Parameter schemas for each method.
-- Each entry is a list of { name, type } tables describing required parameters.
local paramSchemas = {
    ["document.getInfo"]       = {},
    ["document.getLayers"]     = {},
    ["layer.getProperties"]    = {
        { name = "layerId", type = "number" },
    },
    ["layer.getChildren"]      = {
        { name = "layerId", type = "number" },
    },
    ["layer.getBones"]         = {
        { name = "layerId", type = "number" },
    },
    ["bone.getProperties"]     = {
        { name = "layerId", type = "number" },
        { name = "boneId",  type = "number" },
    },
    ["animation.getKeyframes"] = {
        { name = "layerId", type = "number" },
        { name = "channel", type = "string" },
    },
    ["animation.getFrameState"]= {
        { name = "layerId", type = "number" },
        { name = "frame",   type = "number" },
    },
    ["mesh.getPoints"]         = {
        { name = "layerId", type = "number" },
    },
    ["mesh.getShapes"]         = {
        { name = "layerId", type = "number" },
    },
    -- Phase 2: Write tools
    ["bone.setTransform"]      = {
        { name = "layerId", type = "number" },
        { name = "boneId",  type = "number" },
        { name = "frame",   type = "number" },
    },
    ["bone.selectBone"]        = {
        { name = "layerId", type = "number" },
        { name = "boneId",  type = "number" },
    },
    ["layer.setTransform"]     = {
        { name = "layerId", type = "number" },
        { name = "frame",   type = "number" },
    },
    ["layer.setVisibility"]    = {
        { name = "layerId", type = "number" },
        { name = "visible", type = "boolean" },
    },
    ["layer.setOpacity"]       = {
        { name = "layerId", type = "number" },
        { name = "frame",   type = "number" },
        { name = "opacity", type = "number" },
    },
    ["layer.setName"]          = {
        { name = "layerId", type = "number" },
        { name = "name",    type = "string" },
    },
    ["layer.selectLayer"]      = {
        { name = "layerId", type = "number" },
    },
    ["animation.setKeyframe"]  = {
        { name = "layerId", type = "number" },
        { name = "channel", type = "string" },
        { name = "frame",   type = "number" },
    },
    ["animation.deleteKeyframe"] = {
        { name = "layerId", type = "number" },
        { name = "channel", type = "string" },
        { name = "frame",   type = "number" },
    },
    ["animation.setInterpolation"] = {
        { name = "layerId", type = "number" },
        { name = "channel", type = "string" },
        { name = "frame",   type = "number" },
        { name = "mode",    type = "string" },
    },
    ["document.setFrame"]      = {
        { name = "frame",   type = "number" },
    },
    -- Phase 3: Visual feedback (no required params — frame/width/height are optional)
    ["document.screenshot"]    = {},
    -- Batch execution
    ["batch.execute"]          = {
        { name = "operations", type = "table" },
    },
}

--- Check whether a method name is in the allow-list.
-- @param method string  The JSON-RPC method name
-- @return boolean  true if the method is allowed, false otherwise
function validator.isAllowed(method)
    return allowedMethods[method] == true
end

--- Validate parameters for a given method against its expected schema.
-- @param method string  The JSON-RPC method name
-- @param params table|nil  The params table from the request
-- @return boolean  true if params are valid
-- @return string|nil  An error message if validation fails
function validator.validateParams(method, params)
    local schema = paramSchemas[method]
    if schema == nil then
        return false, "Unknown method: " .. tostring(method)
    end

    -- Methods with no required params always pass
    if #schema == 0 then
        return true, nil
    end

    -- If there are required params, params must be a table
    if type(params) ~= "table" then
        return false, "Missing params: expected a table of parameters"
    end

    -- Validate each required parameter
    for _, field in ipairs(schema) do
        local value = params[field.name]
        if value == nil then
            return false, "Missing required parameter: " .. field.name
        end
        if type(value) ~= field.type then
            return false, "Invalid parameter type for '" .. field.name
                .. "': expected " .. field.type .. ", got " .. type(value)
        end
    end

    return true, nil
end

return validator
