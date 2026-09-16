-- Language and namespace repairs that everything else in the shim depends on.
--
-- Three jobs:
--   1. Lua 5.1 is missing table.pack and table.unpack, which Playbit's timer
--      uses. love.js runs plain Lua 5.1, so fill them in.
--   2. import("CoreLibs/x") turns into require("playdate.x"). Several of those
--      files do not exist in Playbit, and one of them (animator) requires a
--      file under the wrong name. An import that fails is a blue screen before
--      the game has drawn a single frame, so pre-register every CoreLibs path.
--   3. The small playdate.* functions that report what machine you are on.

local warn = require("shim.warn")

local module = {}

-- 1. Lua 5.1 -----------------------------------------------------------------

if not table.unpack then
  table.unpack = unpack
end
if not unpack then
  unpack = table.unpack
end
if not table.pack then
  function table.pack(...)
    local t = { ... }
    t.n = select("#", ...)
    return t
  end
end
-- Lua 5.4 dropped math.atan2; Playbit calls it. Harmless where it exists.
if not math.atan2 then
  function math.atan2(y, x)
    return math.atan(y, x)
  end
end

-- love.filesystem.exists was replaced by getInfo in Love 11.
function module.fileExists(path)
  if love.filesystem.getInfo then
    return love.filesystem.getInfo(path) ~= nil
  end
  return love.filesystem.exists(path)
end

-- 2. CoreLibs ----------------------------------------------------------------

-- playdate/easing.lua defines playdate.easingFunctions but nothing loads it,
-- and playdate/animator.lua asks for it as "easing" rather than
-- "playdate.easing". Load it once and answer to both names.
require("playdate.easing")
package.loaded["easing"] = playdate.easingFunctions
package.loaded["playdate.easing"] = playdate.easingFunctions

-- Defines playdate.getCrankTicks.
require("playdate.crank")

-- Defines the global class() and Object, which sprites are built on.
require("playdate.object")

playdate.ui = playdate.ui or {}
package.loaded["playdate.ui"] = playdate.ui

-- CoreLibs/sprites has no Playbit file at all; shim/sprite.lua fills it.
package.loaded["playdate.sprites"] = true

-- playdate.math: two helpers, both one line.
playdate.math = playdate.math or {}
package.loaded["playdate.math"] = playdate.math

function playdate.math.lerp(min, max, t)
  return min + (max - min) * t
end

function playdate.math.clamp(value, min, max)
  if min > max then
    min, max = max, min
  end
  if value < min then
    return min
  end
  if value > max then
    return max
  end
  return value
end

-- Imports that must not explode even though the feature is missing.
playdate.keyboard = playdate.keyboard or {}
package.loaded["playdate.keyboard"] = playdate.keyboard
warn.fillMissing("playdate.keyboard.", playdate.keyboard, {
  "show", "hide", "setCapitalizationBehavior", "isVisible", "text",
  "left", "width", "setText",
})

playdate.pathfinder = playdate.pathfinder or {}
package.loaded["playdate.pathfinder"] = playdate.pathfinder
playdate.pathfinder.graph = playdate.pathfinder.graph or {}
warn.fillMissing("playdate.pathfinder.graph.", playdate.pathfinder.graph, {
  "new", "new2DGrid",
})

playdate.nineSlice = playdate.nineSlice or {}
package.loaded["playdate.nineslice"] = playdate.nineSlice
warn.fillMissing("playdate.nineSlice.", playdate.nineSlice, { "new" })

package.loaded["playdate.utilities"] = true
package.loaded["playdate.utilities.where"] = true
package.loaded["playdate.qrcode"] = true
playdate.graphics.generateQRCode = warn.stub("playdate.graphics.generateQRCode")

-- 3. What machine is this ----------------------------------------------------

playdate.isSimulator = 1

function playdate.getReduceFlashing()
  return false
end

function playdate.getFlipped()
  return false
end

function playdate.getSystemLanguage()
  return "English"
end

local elapsedStart = 0

function playdate.resetElapsedTime()
  elapsedStart = love.timer.getTime()
end

function playdate.getElapsedTime()
  return love.timer.getTime() - elapsedStart
end

playdate.resetElapsedTime()

function playdate.getFPS()
  return love.timer.getFPS()
end

function playdate.drawFPS(x, y)
  playdate.graphics.drawText(tostring(love.timer.getFPS()), x or 0, y or 0)
end

function playdate.getPowerStatus()
  return { charging = false, USB = false, screws = false }
end

function playdate.getBatteryPercentage()
  return 100
end

function playdate.getBatteryVoltage()
  return 4.2
end

function playdate.setAutoLockDisabled() end
function playdate.setCollectsGarbage() end
function playdate.setMinimumGCTime() end
function playdate.setGCScaling() end
function playdate.setCrankSoundsDisabled() end
function playdate.setNewlineAdjustment() end
function playdate.clearConsole() end
function playdate.setDebugDrawColor() end
function playdate.wait() end
function playdate.stop() end
function playdate.start() end

playdate.restart = warn.stub("playdate.restart")
playdate.getStats = warn.stub("playdate.getStats")

function playdate.apiVersion()
  return 2, 7, 6
end

-- The accelerometer. A Chromebook has none, so report the device lying flat
-- on a table, face up, which is what the numbers below mean.
local accelerometerRunning = false

function playdate.startAccelerometer()
  accelerometerRunning = true
end

function playdate.stopAccelerometer()
  accelerometerRunning = false
end

function playdate.accelerometerIsRunning()
  return accelerometerRunning
end

function playdate.readAccelerometer()
  if not accelerometerRunning then
    warn.note("playdate.readAccelerometer() was called before startAccelerometer()")
  end
  return 0, 0, 1
end

function playdate.getDeviceOrientation()
  return "up"
end

function playdate.getPitchAndRoll()
  return 0, 0
end

-- printTable() is a real debugging tool on the Playdate and Playbit raises an
-- error for it, which is the opposite of helpful when you are debugging.
local function dump(value, indent, seen, out)
  if type(value) ~= "table" then
    out[#out + 1] = tostring(value)
    return
  end
  if seen[value] then
    out[#out + 1] = "<repeated table>"
    return
  end
  seen[value] = true
  local pad = string.rep(" ", indent + 2)
  out[#out + 1] = "{\n"
  for k, v in pairs(value) do
    out[#out + 1] = pad .. tostring(k) .. " = "
    dump(v, indent + 2, seen, out)
    out[#out + 1] = ",\n"
  end
  out[#out + 1] = string.rep(" ", indent) .. "}"
end

function printTable(value)
  local out = {}
  dump(value, 0, {}, out)
  print(table.concat(out))
end

function where()
  print(debug.traceback("", 2))
end

function sample(name, fn)
  if fn then
    return fn()
  end
end

return module
