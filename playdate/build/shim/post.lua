-- Runs after the game has been loaded, because it wraps playdate.update,
-- which does not exist until then. build/entry.lua requires this last.
--
-- Two jobs: hold the game to the hardware frame rate, and put the system menu
-- on screen.

local ui = require("shim.ui")
local input = require("shim.input")

local userUpdate = playdate.update
if type(userUpdate) ~= "function" then
  print("playdate shim: this game has no playdate.update() function, so the screen will stay blank")
  userUpdate = function() end
end

-- M opens the menu. While it is open the game is paused, the same as on
-- hardware, so the menu swallows the keys it uses.
local previousKeyHook = playbit.keyPressed
playbit.keyPressed = function(key)
  local handled = ui.menuKey(key)
  if not handled and previousKeyHook then
    previousKeyHook(key)
  end
end

-- A Playdate runs at 30 frames a second. A browser tab calls love.draw at
-- whatever the monitor does, usually 60, so without this every game runs at
-- double speed here and normal speed on the device. Skip the extra frames.
--
-- The canvas keeps the last frame, so a skipped frame still shows something.
-- Input is the catch: Playbit clears "just pressed" at the end of every
-- love.draw, so on a skipped frame that clear has to be held back or a button
-- press can be used up by a frame the game never ran.
local realUpdateInput = playdate.updateInput
local function noUpdateInput() end

local nextFrameTime = 0

-- How many frames the game itself has run, as opposed to how many times the
-- browser asked. Handy when a game feels slow: compare it to love.timer.getFPS.
playdate.shim.framesRun = 0

function playdate.update()
  local rate = playdate.display.getRefreshRate()
  local now = love.timer.getTime()

  if rate and rate > 0 then
    if nextFrameTime == 0 then
      nextFrameTime = now
    end
    if now < nextFrameTime then
      playdate.updateInput = noUpdateInput
      return
    end
    nextFrameTime = nextFrameTime + 1 / rate
    if nextFrameTime < now then
      nextFrameTime = now + 1 / rate
    end
  end

  playdate.updateInput = realUpdateInput

  if ui.menuIsOpen() then
    ui.drawMenu()
    return
  end

  -- The menu covered part of the screen. A game that repaints every pixel
  -- every frame does not care, but a sprite game repaints only where its
  -- sprites are, so without this the menu stays printed on the screen after
  -- it closes.
  if ui.takeJustClosed() then
    playdate.graphics.clear()
  end

  playdate.shim.framesRun = playdate.shim.framesRun + 1
  -- The SDK calls these just before update, so this does too.
  input.dispatch()
  userUpdate()
  ui.drawMenu()
end
