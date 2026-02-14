-- **************************************************
-- Provide Moho with the name of this script object
-- **************************************************

ScriptName = "MohoMCP_Server"

-- **************************************************
-- General information about this script
-- **************************************************

MohoMCP_Server = MohoMCP_Server or {}

-- Module references (preserve across re-loads)
if MohoMCP_Server.server == nil then
	MohoMCP_Server.server = nil
	MohoMCP_Server.isLoaded = false
	MohoMCP_Server.BASE_DIR = ""
	MohoMCP_Server.pollActive = false
end

function MohoMCP_Server:Name()
	return "MohoMCP Server"
end

function MohoMCP_Server:Version()
	return "0.1.0"
end

function MohoMCP_Server:Description()
	return "Start/stop the MohoMCP server for LLM integration (Claude Desktop, Claude Code)"
end

function MohoMCP_Server:Creator()
	return "MohoMCP Project"
end

function MohoMCP_Server:UILabel()
	return "Start/Stop MohoMCP Server"
end

-- **************************************************
-- Helpers
-- **************************************************

--- Determine the directory this script lives in so we can load siblings.
local function getScriptDir()
	local info = debug.getinfo(1, "S")
	local path = info.source
	if path:sub(1, 1) == "@" then
		path = path:sub(2)
	end
	-- Normalize to forward slashes
	path = path:gsub("\\", "/")
	local dir = path:match("^(.*/)")
	return dir or "./"
end

--- Add the plugin directory to Lua's package.path.
local function setupPackagePath(baseDir)
	local sep = package.config:sub(1, 1)
	local pattern = baseDir .. "?.lua;" .. baseDir .. "?" .. sep .. "init.lua"
	if not package.path:find(baseDir, 1, true) then
		package.path = pattern .. ";" .. package.path
	end
end

-- **************************************************
-- Module loading
-- **************************************************

local function loadModules(baseDir)
	if MohoMCP_Server.isLoaded then
		return true
	end

	setupPackagePath(baseDir)

	-- Load the JSON library and make it globally available
	local jsonOk, jsonMod = pcall(require, "json")
	if not jsonOk then
		print("[MohoMCP] ERROR: Failed to load json.lua: " .. tostring(jsonMod))
		return false
	end
	_G.json = jsonMod

	-- Load core modules
	local protocolOk, protocolMod = pcall(require, "moho_mcp.protocol")
	if not protocolOk then
		print("[MohoMCP] ERROR: Failed to load protocol: " .. tostring(protocolMod))
		return false
	end

	local validatorOk, validatorMod = pcall(require, "moho_mcp.validator")
	if not validatorOk then
		print("[MohoMCP] ERROR: Failed to load validator: " .. tostring(validatorMod))
		return false
	end

	local serverOk, srv = pcall(require, "moho_mcp.server")
	if not serverOk then
		print("[MohoMCP] ERROR: Failed to load server: " .. tostring(srv))
		return false
	end

	-- Initialize server with dependencies
	srv.init({ protocol = protocolMod, validator = validatorMod, json = jsonMod })

	-- Load tool handlers
	local toolModules = {
		{ name = "moho_mcp.tools.document",  methods = { "document.getInfo", "document.getLayers", "document.setFrame", "document.screenshot" } },
		{ name = "moho_mcp.tools.layer",     methods = { "layer.getProperties", "layer.getChildren", "layer.getBones", "layer.setTransform", "layer.setVisibility", "layer.setOpacity", "layer.setName", "layer.selectLayer" } },
		{ name = "moho_mcp.tools.bone",      methods = { "bone.getProperties", "bone.setTransform", "bone.selectBone" } },
		{ name = "moho_mcp.tools.animation", methods = { "animation.getKeyframes", "animation.getFrameState", "animation.setKeyframe", "animation.deleteKeyframe", "animation.setInterpolation" } },
		{ name = "moho_mcp.tools.mesh",      methods = { "mesh.getPoints", "mesh.getShapes" } },
		{ name = "moho_mcp.tools.batch",     methods = { "batch.execute" } },
	}

	for _, toolDef in ipairs(toolModules) do
		local toolOk, toolMod = pcall(require, toolDef.name)
		if toolOk and toolMod then
			for _, method in ipairs(toolDef.methods) do
				local funcName = method:match("%.(.+)$")
				if funcName and toolMod[funcName] then
					srv.registerHandler(method, toolMod[funcName])
					print("[MohoMCP] Registered handler: " .. method)
				else
					print("[MohoMCP] WARNING: No handler for " .. method)
				end
			end
		else
			print("[MohoMCP] WARNING: Failed to load " .. toolDef.name .. ": " .. tostring(toolMod))
		end
	end

	MohoMCP_Server.server = srv
	MohoMCP_Server.isLoaded = true
	return true
end

-- **************************************************
-- Continuous polling by wrapping tool DrawMe callbacks
-- **************************************************

--- Inject polling into existing MOHO tool scripts.
--- MOHO calls DrawMe on the active tool every viewport repaint,
--- so wrapping it gives us a reliable, frequent polling hook
--- regardless of which tool the user has selected.
local function installDrawMeHooks()
	if MohoMCP_Server._hooksInstalled then
		return
	end

	-- List of known MOHO tool globals to wrap
	local toolNames = {
		"LM_TransformPoints", "LM_SelectPoints", "LM_AddPoint", "LM_Curvature",
		"LM_Freehand", "LM_Shape", "LM_DeleteEdge", "LM_Magnet",
		"LM_Brush", "LM_Eraser", "LM_PointReduction", "LM_ScatterBrush",
		"LM_PerspectivePoints", "LM_ShearPoints", "LM_BendPoints", "LM_Noise",
		"LM_SelectShape", "LM_CreateShape", "LM_PaintBucket", "LM_DeleteShape",
		"LM_LineWidth", "LM_HideEdge", "LM_CurveExposure", "LM_CurveProfile",
		"LM_SelectBone", "LM_AddBone", "LM_TransformBone", "LM_ManipulateBones",
		"LM_ReparentBone", "LM_BoneStrength", "LM_BoneGroups",
		"LM_BindLayer", "LM_BindPoints", "LM_OffsetBone",
		"LM_TransformLayer", "LM_SetOrigin",
		"LM_FollowCurve", "LM_RotateLayerXY", "LM_ShearLayer",
		"LM_TrackCamera", "LM_ZoomCamera", "LM_RollCamera", "LM_PanTiltCamera",
		"LM_PanWorkspace", "LM_ZoomWorkspace", "LM_RotateWorkspace", "LM_OrbitWorkspace",
	}

	local wrapped = 0
	for _, name in ipairs(toolNames) do
		local tool = _G[name]
		if tool and tool.DrawMe then
			local original = tool.DrawMe
			tool.DrawMe = function(self, moho, view)
				-- Poll for MohoMCP requests (wrapped in pcall to survive crashes)
				if MohoMCP_Server.pollActive and MohoMCP_Server.server then
					local pollOk, pollErr = pcall(MohoMCP_Server.server.poll, moho)
					if not pollOk then
						print("[MohoMCP] Poll error (non-fatal): " .. tostring(pollErr))
					end
					-- Self-sustaining timer: call UpdateUI() throttled to ~4Hz
					-- This triggers another DrawMe, keeping the poll loop alive
					-- even when the user isn't interacting with the viewport
					local now = os.clock()
					if not MohoMCP_Server._lastPollTime or (now - MohoMCP_Server._lastPollTime) > 0.25 then
						MohoMCP_Server._lastPollTime = now
						pcall(function() moho:UpdateUI() end)
					end
				end
				return original(self, moho, view)
			end
			wrapped = wrapped + 1
		end
	end

	MohoMCP_Server._hooksInstalled = true
	print("[MohoMCP] Injected polling into " .. wrapped .. " tool DrawMe callbacks")
end

-- **************************************************
-- IsEnabled — called by MOHO to update menu state.
-- We piggyback on this for reliable polling since it
-- fires periodically even without viewport interaction.
-- **************************************************

function MohoMCP_Server:IsEnabled(moho)
	if MohoMCP_Server.pollActive and MohoMCP_Server.server then
		local pollOk, pollErr = pcall(MohoMCP_Server.server.poll, moho)
		if not pollOk then
			print("[MohoMCP] Poll error (non-fatal): " .. tostring(pollErr))
		end
	end
	return true
end

-- **************************************************
-- The guts of this script
-- **************************************************

function MohoMCP_Server:Run(moho)
	-- Determine base directory on first run
	if MohoMCP_Server.BASE_DIR == "" then
		MohoMCP_Server.BASE_DIR = getScriptDir()
	end

	-- Load modules on first run
	if not MohoMCP_Server.isLoaded then
		local loaded = loadModules(MohoMCP_Server.BASE_DIR)
		if not loaded then
			LM.GUI.Alert(LM.GUI.ALERT_WARNING,
				"MohoMCP failed to load modules.",
				"Check the script console (Window > Script Console) for details.",
				nil,
				MOHO.Localize("/Scripts/OK=OK"),
				nil, nil)
			return
		end
	end

	local srv = MohoMCP_Server.server

	if srv.isRunning() then
		-- Stop the server
		srv.stop()
		MohoMCP_Server.pollActive = false
		LM.GUI.Alert(LM.GUI.ALERT_INFO,
			"MohoMCP Server stopped.",
			nil, nil,
			MOHO.Localize("/Scripts/OK=OK"),
			nil, nil)
	else
		-- Start the server
		local ok, err = srv.start()
		if ok then
			MohoMCP_Server.pollActive = true
			-- Hook into all tool DrawMe callbacks for continuous polling
			installDrawMeHooks()
			-- Do an initial poll with the current moho reference
			srv.poll(moho)
			LM.GUI.Alert(LM.GUI.ALERT_INFO,
				"MohoMCP Server started!",
				"IPC directory: " .. srv.getInfo().ipcDir,
				"Use Claude Desktop or Claude Code to connect.",
				MOHO.Localize("/Scripts/OK=OK"),
				nil, nil)
		else
			LM.GUI.Alert(LM.GUI.ALERT_WARNING,
				"MohoMCP Server failed to start.",
				tostring(err),
				nil,
				MOHO.Localize("/Scripts/OK=OK"),
				nil, nil)
		end
	end
end
