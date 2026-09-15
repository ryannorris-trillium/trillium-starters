-- Turns source/ into a Love2D project in _web/, which love.js packages for the browser.
local build = require("playbit.build")

build.build({
  assert = true,
  debug = true,
  platform = "love2d",
  output = "_web",
  clearBuildFolder = true,
  fileProcessors = {
    lua = build.luaProcessor,
    fnt = build.fntProcessor,
  },
  files = {
    -- Playbit: the Playdate API rewritten in Love2D.
    { "playbit/playbit", "playbit" },
    { "playbit/playdate", "playdate" },
    { "playbit/json/json.lua", "json/json.lua" },
    { "playbit/fonts", "fonts" },
    -- Your game.
    { "source/conf.lua", "conf.lua" },
    { "source/main.lua", "main.lua" },
    { "source/metadata.json", "pdxinfo",
      { json = { build.pdxinfoProcessor, { incrementBuildNumber = false } } }
    },
  },
})
