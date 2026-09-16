-- Turns source/ into a Love2D project in _web/, which love.js packages for the browser.
local build = require("playbit.build")
-- Playdate Lua has +=, -=, *= and /=; plain Lua does not. See build/ops.lua.
local ops = require("build.ops")

build.build({
  assert = true,
  debug = true,
  platform = "love2d",
  output = "_web",
  clearBuildFolder = true,
  fileProcessors = {
    lua = ops.luaProcessor,
    fnt = build.fntProcessor,
  },
  files = {
    -- Playbit: the Playdate API rewritten in Love2D.
    { "playbit/playbit", "playbit" },
    { "playbit/playdate", "playdate" },
    { "playbit/json/json.lua", "json/json.lua" },
    -- Playbit's header: import(), love.draw, and the default font. It used to
    -- be pasted into the top of the game file; build/entry.lua loads it here
    -- instead, so a game file can be plain Playdate code.
    { "playbit/header.lua", "playbit/header.lua" },
    { "playbit/fonts", "fonts" },
    -- The compatibility layer: the parts of the Playdate SDK that Playbit
    -- does not have. Copied as is, not run through the preprocessor, because
    -- it is already plain Lua 5.1. Browser only; build/device.lua omits it.
    { "build/shim", "shim", { lua = build.defaultProcessor } },
    -- Your game. Everything under source/ keeps its folder layout, so
    -- `import "Fish/fish"` and image paths like "images/bg" resolve the same
    -- way they do on the device. .fnt files are copied as they are:
    -- shim/font.lua reads the Playdate format at run time, so there is
    -- nothing to convert.
    { "source", ".", { fnt = build.defaultProcessor } },
    -- Love2d always starts at main.lua, so the entry point goes there and the
    -- game goes to game.lua. That gives the shim a place to load in between.
    -- This has to come after the source tree: source/main.lua lands on
    -- main.lua too, and entry.lua has to be the one that wins.
    { "build/entry.lua", "main.lua", { lua = build.defaultProcessor } },
    { "source/main.lua", "game.lua" },
    { "source/metadata.json", "pdxinfo",
      { json = { build.pdxinfoProcessor, { incrementBuildNumber = false } } }
    },
  },
})
