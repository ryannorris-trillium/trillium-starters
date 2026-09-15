-- Turns source/ into real Playdate Lua in _pdx/, which pdc compiles into a .pdx.
local build = require("playbit.build")

build.build({
  assert = true,
  debug = true,
  platform = "playdate",
  output = "_pdx",
  clearBuildFolder = true,
  fileProcessors = {
    lua = build.luaProcessor,
  },
  files = {
    { "playbit/playbit", "playbit" },
    { "source/main.lua", "main.lua" },
    { "source/metadata.json", "pdxinfo",
      { json = { build.pdxinfoProcessor, { incrementBuildNumber = false } } }
    },
  },
})
