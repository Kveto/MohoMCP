import { describe, it } from "vitest";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { lua, lauxlib, lualib, to_luastring, to_jsstring } from "fengari";

const plugin = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../../moho-plugin");

// Execute the real Lua modules. Only the Moho API and the file system are
// replaced, so these regressions can run without Moho or a system Lua install.
function runLua(body) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  for (const [name, relative] of Object.entries({
    jsonSource: "json.lua", protocolSource: "moho_mcp/protocol.lua",
    validatorSource: "moho_mcp/validator.lua", serverSource: "moho_mcp/server.lua",
    documentSource: "moho_mcp/tools/document.lua", animationSource: "moho_mcp/tools/animation.lua",
  })) {
    lua.lua_pushstring(L, to_luastring(fs.readFileSync(path.join(plugin, relative), "utf8")));
    lua.lua_setglobal(L, to_luastring(name));
  }
  try {
    if (lauxlib.luaL_dostring(L, to_luastring(body)) !== lua.LUA_OK) {
      throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
    }
  } finally { lua.lua_close(L); }
}

const serverSetup = `
local files = {}
os.getenv = function(name) if name == "TMPDIR" then return "/ipc" end end
os.remove = function(p) files[p] = nil; return true end
os.rename = function(a,b) files[b] = files[a]; files[a] = nil; return true end
io = {
  popen = function() return {close = function() end} end,
  open = function(p, mode)
    if mode == "r" or mode == "rb" then
      if files[p] == nil then return nil, "not found" end
      return {read = function() return files[p] end, close = function() end}
    end
    return {write = function(_, s) files[p] = s end, close = function() end}
  end,
}
json = assert(load(jsonSource))()
local protocol = assert(load(protocolSource))()
local validator = assert(load(validatorSource))()
local server = assert(load(serverSource))()
server.init({json=json, protocol=protocol, validator=validator})
assert(server.start())
local dir = server.getInfo().ipcDir
local function request(id)
  files[dir .. "req_" .. id .. ".json"] = json.encode({jsonrpc="2.0",id=id,method="document.getInfo"})
end
`;

describe("Lua IPC polling", () => {
  it("dispatches an in-flight request once when a handler triggers a nested repaint", () => runLua(serverSetup + `
    local calls = 0
    server.registerHandler("document.getInfo", function(moho)
      calls = calls + 1
      if calls == 1 then server.poll(moho) end
      return {calls=calls}
    end)
    request(1)
    server.poll({})
    assert(calls == 1, "nested callbacks dispatched the in-flight request twice")
    assert(files[dir .. "req_1.json"] == nil)
    assert(json.decode(files[dir .. "resp_1.json"]).result.calls == 1)
  `));

  it("releases the guard after an unexpected polling error", () => runLua(serverSetup + `
    server.registerHandler("document.getInfo", function() return {ok=true} end)
    request(1)
    local open = io.open
    io.open = function() error("transient file system error") end
    assert(not pcall(server.poll, {}))
    io.open = open
    server.poll({})
    assert(files[dir .. "resp_1.json"] ~= nil, "polling remained locked after an error")
  `));

  it("continues handling later requests after a handler fails", () => runLua(serverSetup + `
    local calls = 0
    server.registerHandler("document.getInfo", function()
      calls = calls + 1
      if calls == 1 then error("handler failed") end
      return {ok=true}
    end)
    request(1); server.poll({})
    assert(json.decode(files[dir .. "resp_1.json"]).error.code == -32603)
    request(2); server.poll({})
    assert(json.decode(files[dir .. "resp_2.json"]).result.ok)
  `));
});

const documentSetup = `
local document = assert(load(documentSource))()
local function layer(children)
  return {
    IsGroupType=function() return children ~= nil end,
    CountLayers=function() return #children end,
    Layer=function(_,i) return children[i+1] end,
  }
end
local children={layer(), layer({layer(),layer({layer()})})}
local doc={
  Width=function() return 1280 end, Height=function() return 720 end,
  Fps=function() return 24 end, StartFrame=function() return 1 end,
  EndFrame=function() return 48 end, CountLayers=function() return #children end,
  Layer=function(_,i) return children[i+1] end,
}
local moho={document=doc,LayerAsGroup=function(_,l) return l end}
`;

describe("Lua document metadata", () => {
  it("counts both endpoints in the rendered duration", () => runLua(documentSetup + `
    assert(document.getInfo(moho, {}).duration == 2)
    doc.StartFrame=function() return 9 end; doc.EndFrame=function() return 9 end
    assert(document.getInfo(moho, {}).duration == 1/24)
  `));

  it("counts nested layers when TotalLayerCount is unavailable", () => runLua(documentSetup + `
    local info=document.getInfo(moho,{})
    assert(info.totalLayers == 5)
    assert(info.topLevelLayers == 2)
  `));

  it("keeps a native TotalLayerCount result when available", () => runLua(documentSetup + `
    doc.TotalLayerCount=function() return 7 end
    assert(document.getInfo(moho,{}).totalLayers == 7)
  `));
});

describe("Lua animation keyframes", () => {
  it("queries interpolation at each key's frame rather than its index", () => runLua(`
    MOHO={INTERP_LINEAR=0,INTERP_SMOOTH=1,INTERP_STEP=5}
    local frames={0,12,48}
    local modes={[0]=0,[12]=1,[48]=5}
    local channel={
      CountKeys=function() return #frames end,
      GetKeyWhen=function(_,i) return frames[i+1] end,
      GetValue=function(_,f) return {x=f,y=f} end,
      GetKeyInterpMode=function(_,f) return modes[f] end,
    }
    local lyr={fTranslation=channel}
    local moho={document={LayerByAbsoluteID=function() return lyr end}}
    local animation=assert(load(animationSource))()
    local result=assert(animation.getKeyframes(moho,{layerId=0,channel="translation"}))
    assert(result.keyframes[1].interpolation == "linear")
    assert(result.keyframes[2].interpolation == "smooth")
    assert(result.keyframes[3].interpolation == "step")
  `));
});
