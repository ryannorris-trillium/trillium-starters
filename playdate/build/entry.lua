-- Browser build entry point. The real Playdate never sees this file.
--
-- Love2d always starts at main.lua, and build/web.lua writes this file there.
-- The game (source/main.lua) is written to game.lua instead, so the
-- compatibility shim has somewhere to stand: after the playdate namespace
-- exists, before any game code runs.

require("playbit.graphics")
require("playdate.playdate")
require("playdate.graphics")

-- Everything the Playdate SDK has and Playbit does not. See docs/api-coverage.md.
require("shim.init")

-- Playbit's header: the import() function and love.draw, which calls
-- playdate.update once a frame. Playbit expects this pasted into the top of
-- the game file. Loading it here instead means a game file is plain Playdate
-- code, with nothing in it that only makes sense in a browser, which is what
-- lets the examples in the Playdate SDK run unchanged.
require("playbit.header")

-- The game.
require("game")

-- Wraps playdate.update, which only exists now that game.lua has run.
require("shim.post")
