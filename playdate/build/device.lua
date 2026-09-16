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
    -- Everything under source/, folder layout and all, so a game split over
    -- several files with its own art builds the same way a one file game does.
    { "source", "." },
    { "source/metadata.json", "pdxinfo",
      { json = { build.pdxinfoProcessor, { incrementBuildNumber = false } } }
    },
  },
})
