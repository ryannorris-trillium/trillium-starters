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
    -- The compatibility layer: the parts of the Playdate SDK that Playbit
    -- does not have. Copied as is, not run through the preprocessor, because
    -- it is already plain Lua 5.1. Browser only; build/device.lua omits it.
    { "build/shim", "shim", { lua = build.defaultProcessor } },
    -- Love2d always starts at main.lua, so the entry point goes there and the
    -- game goes to game.lua. That gives the shim a place to load in between.
    { "build/entry.lua", "main.lua", { lua = build.defaultProcessor } },
    -- Your game.
    { "source/conf.lua", "conf.lua" },
    { "source/main.lua", "game.lua" },
    { "source/metadata.json", "pdxinfo",
      { json = { build.pdxinfoProcessor, { incrementBuildNumber = false } } }
    },
  },
})
