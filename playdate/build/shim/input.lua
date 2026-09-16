-- The button and crank callbacks.
--
-- The SDK lets a game answer a button by name instead of asking every frame:
--
--   function playdate.AButtonDown() player:jump() end
--   function playdate.leftButtonUp() player:stopTurning() end
--
-- Playbit records which buttons are down but never calls any of these, so a
-- game written that way sits there doing nothing. Almost every example Panic
-- ships is written that way.
--
-- shim/post.lua calls dispatch() once per game frame, just before
-- playdate.update, which is where the hardware calls them too.

local warn = require("shim.warn")

local module = {}

local buttons = {
  { button = playdate.kButtonA, down = "AButtonDown", up = "AButtonUp", held = "AButtonHeld" },
  { button = playdate.kButtonB, down = "BButtonDown", up = "BButtonUp", held = "BButtonHeld" },
  { button = playdate.kButtonUp, down = "upButtonDown", up = "upButtonUp" },
  { button = playdate.kButtonDown, down = "downButtonDown", up = "downButtonUp" },
  { button = playdate.kButtonLeft, down = "leftButtonDown", up = "leftButtonUp" },
  { button = playdate.kButtonRight, down = "rightButtonDown", up = "rightButtonUp" },
}

-- When each button that is currently down was pressed, so that AButtonHeld
-- can fire a second later, once, the way the hardware does it.
local heldSince = {}
local heldFired = {}

local HOLD_SECONDS = 1

local wasDocked = nil

-- Button names -----------------------------------------------------------------
--
-- The SDK takes the constants playdate.kButtonA and friends, or the same
-- things spelled out. Panic's own examples write
--
--   if playdate.buttonJustPressed("A") then self:jump() end
--
-- with a capital A, and hardware answers. Playbit looks the name up in a table
-- keyed by the lower case spellings, so a capital found nothing, every test
-- came back false, and the jump button quietly did nothing at all. Arrow keys
-- were unaffected, because "left" and "up" have no capitals to get wrong,
-- which is what made it look like only A and B were broken.
local function buttonName(button)
  if type(button) == "string" then
    return string.lower(button)
  end
  return button
end

module.buttonName = buttonName

local realIsPressed = playdate.buttonIsPressed
local realJustPressed = playdate.buttonJustPressed
local realJustReleased = playdate.buttonJustReleased

function playdate.buttonIsPressed(button)
  return realIsPressed(buttonName(button))
end

function playdate.buttonJustPressed(button)
  return realJustPressed(buttonName(button))
end

function playdate.buttonJustReleased(button)
  return realJustReleased(buttonName(button))
end

-- getButtonState answers three questions: is it down now, did it go down this
-- frame, did it come up this frame. Playbit returns "is it down" twice.
function playdate.getButtonState(button)
  local name = buttonName(button)
  return realIsPressed(name), realJustPressed(name), realJustReleased(name)
end

-- Input handlers ---------------------------------------------------------------
--
-- A handler is a table of the same callbacks under the same names, pushed on
-- top of the ones on playdate itself. A menu can push its own controls, and
-- pop them again when it closes, without the game underneath having to know.
-- Pushing with masksPreviousHandlers stops the search there, so a button the
-- handler does not answer does nothing at all rather than falling through.
local handlers = {}

playdate.inputHandlers = playdate.inputHandlers or {}

function playdate.inputHandlers.push(handler, masksPreviousHandlers)
  handlers[#handlers + 1] = { handler = handler, masks = masksPreviousHandlers }
end

function playdate.inputHandlers.pop()
  handlers[#handlers] = nil
end

local function call(name, ...)
  for i = #handlers, 1, -1 do
    local entry = handlers[i]
    local fn = entry.handler[name]
    if type(fn) == "function" then
      fn(...)
      return
    end
    if entry.masks then
      return
    end
  end
  local fn = playdate[name]
  if type(fn) == "function" then
    fn(...)
  end
end

-- A Chromebook has no scroll wheel, so the keys turn the crank instead: comma
-- and full stop, or q and e, six degrees a frame in either direction. Playbit
-- moves the crank from the wheel, so this moves it the same way and everything
-- downstream -- getCrankPosition, getCrankChange, the cranked callback -- sees
-- a real turn. The wheel still works where there is one, and a docked crank
-- ignores both, as it does on hardware.
local function crankFromKeys()
  if not (love.keyboard and love.keyboard.isDown) then
    return
  end
  if love.keyboard.isDown(",", "q") then
    love.wheelmoved(0, 1)
  end
  if love.keyboard.isDown(".", "e") then
    love.wheelmoved(0, -1)
  end
end

function module.dispatch()
  local now = love.timer.getTime()

  crankFromKeys()

  for i = 1, #buttons do
    local entry = buttons[i]
    local button = entry.button

    if playdate.buttonJustPressed(button) then
      heldSince[button] = now
      heldFired[button] = false
      call(entry.down)
    end

    if playdate.buttonJustReleased(button) then
      heldSince[button] = nil
      heldFired[button] = nil
      call(entry.up)
    end

    if entry.held and heldSince[button] and not heldFired[button]
      and now - heldSince[button] >= HOLD_SECONDS then
      heldFired[button] = true
      call(entry.held)
    end
  end

  -- The crank. Playbit tracks the angle; the callback is the SDK's way of
  -- being told about it.
  local change, accelerated = playdate.getCrankChange()
  if change and change ~= 0 then
    call("cranked", change, accelerated or change)
  end

  local docked = playdate.isCrankDocked()
  if wasDocked == nil then
    wasDocked = docked
  elseif docked ~= wasDocked then
    wasDocked = docked
    if docked then
      call("crankDocked")
    else
      call("crankUndocked")
    end
  end
end

-- The system menu opening and closing is the browser's nearest thing to the
-- hardware's pause, so the game hears about it there.
function module.pause()
  call("gameWillPause")
end

function module.resume()
  call("gameWillResume")
end

return module
