-- Loads the real built game the way the browser does and runs a few frames.
--
--   lua build/test/smoke.lua _web
--
-- run.lua checks the shim's answers. This checks that the whole stack starts:
-- entry point, Playbit header, shim, the game in source/main.lua, and the
-- frame rate wrapper in shim/post.lua. If this passes, the tab should show
-- something rather than a blue screen.

local webFolder = arg[1] or "_web"
local testFolder = string.match(arg[0], "^(.*)[/\\][^/\\]+$") or "."

package.path = table.concat({
  webFolder .. "/?.lua",
  webFolder .. "/?/init.lua",
  testFolder .. "/?.lua",
  package.path,
}, ";")

local fake = require("fakelove")
fake.install()

-- dev-web.sh prepends this to main.lua, so it is already there in the browser.
assert(loadfile(testFolder .. "/../bit51.lua"))()

require("playbit.graphics")
require("playdate.playdate")
require("playdate.graphics")

-- The header loads a real bitmap font off disk. Nothing here can read a .fnt,
-- so hand it one that measures and records instead.
playdate.graphics.font.new = function()
  return {
    data = {},
    getTextWidth = function(self, str) return #tostring(str) * 6 end,
    getHeight = function() return 12 end,
    getLeading = function() return 2 end,
    drawText = function(self, str, x, y) fake.record("text", str, x, y) end,
    drawTextAligned = function(self, str, x, y) fake.record("text", str, x, y) end,
    _drawTextInRect = function(self, str, x, y) fake.record("text", str, x, y) end,
  }
end

local ok, message = pcall(dofile, webFolder .. "/main.lua")
if not ok then
  print("FAIL: the built game did not load")
  print("  " .. tostring(message))
  os.exit(1)
end

if type(love.draw) ~= "function" then
  print("FAIL: love.draw was never defined, so the header did not run")
  os.exit(1)
end

-- Sixty browser frames. At the Playdate's 30 frames a second the game should
-- run about thirty of them and skip the rest, so it plays at the same speed
-- here as it does on the hardware.
fake.clearLog()
for i = 1, 60 do
  fake.advance(1 / 60)
  local frameOk, frameError = pcall(love.draw)
  if not frameOk then
    print("FAIL: frame " .. i .. " raised")
    print("  " .. tostring(frameError))
    os.exit(1)
  end
  if love.update then
    love.update(1 / 60)
  end
end

local gameFrames = playdate.shim.framesRun
local drew = 0
for _, entry in ipairs(fake.log) do
  if entry.name == "circle" or entry.name == "rectangle" or entry.name == "text"
    or entry.name == "draw" or entry.name == "line" then
    drew = drew + 1
  end
end

print("60 browser frames ran, the game updated " .. gameFrames .. " times, " ..
  drew .. " drawing calls recorded")

if drew == 0 then
  print("FAIL: the game drew nothing")
  os.exit(1)
end

if gameFrames < 25 or gameFrames > 35 then
  print("FAIL: expected about 30 game frames out of 60 browser frames, got " .. gameFrames)
  os.exit(1)
end

print("smoke test passed")
os.exit(0)
