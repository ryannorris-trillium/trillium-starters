-- The browser compatibility layer.
--
-- Playbit rewrites a good part of the Playdate SDK on top of Love2d, but not
-- all of it, and some of what it has raises an error instead of running. This
-- fills the gaps so that code written against the real SDK documentation
-- behaves the same way in a browser tab as it does on the hardware. What is
-- here, what is faked, and what is missing: docs/api-coverage.md.
--
-- Loaded by build/entry.lua, which build/web.lua writes to the browser build
-- as main.lua. The device build never sees any of this.
--
-- Lua 5.1 only. love.js has no jump labels, no integer division, no bitwise
-- operators, and no bit library beyond build/bit51.lua.

local shim = {}
playdate.shim = shim

shim.warn = require("shim.warn")
require("shim.compat")
require("shim.geometry")
require("shim.graphics")
require("shim.font")
require("shim.sprite")
require("shim.tilemap")
require("shim.file")
require("shim.timer")
require("shim.animator")
require("shim.sound")
shim.input = require("shim.input")
shim.ui = require("shim.ui")

function shim.missingSoFar()
  return shim.warn.warnedList()
end

print("playdate shim: browser build. Anything missing prints a line here. See docs/api-coverage.md")

return shim
