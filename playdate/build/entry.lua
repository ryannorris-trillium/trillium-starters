-- Browser build entry point. The real Playdate never sees this file.
--
-- Love2d always starts at main.lua, and build/web.lua writes this file there.
-- The game (source/main.lua) is written to game.lua instead, so the
-- compatibility shim has somewhere to stand: after the playdate namespace
-- exists, before any game code runs.
--
-- Requiring Playbit here is not a second load. require() caches, so when the
-- header inlined at the top of game.lua asks for these same three modules it
-- gets the ones already in memory.

require("playbit.graphics")
require("playdate.playdate")
require("playdate.graphics")

-- Everything the Playdate SDK has and Playbit does not. See docs/api-coverage.md.
require("shim.init")

-- The game.
require("game")

-- Wraps playdate.update, which only exists now that game.lua has run.
require("shim.post")
