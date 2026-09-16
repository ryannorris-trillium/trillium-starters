-- playdate.timer and playdate.frameTimer.
--
-- Playbit has a timer, but timer:remove() removes the wrong entry from its
-- list and discardOnCompletion inserts a nil, so a game that makes and drops
-- timers slowly corrupts the list. Its frameTimer.lua is all errors. Both are
-- the same object with a different clock, so this file builds them from one
-- implementation: milliseconds for timer, frames for frameTimer.
--
-- Requiring Playbit's versions first puts them in the module cache, so a later
-- import("CoreLibs/timer") gets these instead.

require("shim.compat")
require("playdate.timer")
require("playdate.frameTimer")

local easings = playdate.easingFunctions
local unpackArgs = unpack or table.unpack

local function buildTimerModule(stepFn)
  local module = {}
  local meta = {}
  local methods = {}

  local timers = {}

  -- Read-only properties the SDK exposes, then the methods table.
  meta.__index = function(t, key)
    if key == "running" then
      return rawget(t, "active") and not rawget(t, "paused")
    elseif key == "timeLeft" then
      return math.max(0, rawget(t, "duration") - rawget(t, "currentTime"))
    end
    return methods[key]
  end

  module.__index = meta

  -- new(duration, callback, ...)
  -- new(duration, startValue, endValue, [easingFunction])
  function module.new(duration, startValue, ...)
    local self = setmetatable({}, meta)
    local endValue, easingFunction, callback, args, argCount

    if type(startValue) == "function" then
      callback = startValue
      argCount = select("#", ...)
      if argCount > 0 then
        args = { ... }
      end
      startValue = nil
    else
      endValue, easingFunction = ...
    end

    self.duration = duration
    self.currentTime = 0
    self.startValue = startValue or 0
    self.endValue = endValue or 0
    self.easingFunction = easingFunction or easings.linear
    self.value = self.startValue
    self.easingAmplitude = nil
    self.easingPeriod = nil
    self.reverseEasingFunction = nil
    self.delay = 0
    self.discardOnCompletion = true
    self.repeats = false
    self.reverses = false
    self.paused = false
    self.active = true
    self.timerEndedCallback = callback
    self.timerEndedArgs = args
    self._argCount = argCount
    self.updateCallback = nil
    self._hasReversed = false
    self._remainingDelay = nil
    self._originalStart = self.startValue
    self._originalEnd = self.endValue
    self._originalEasing = self.easingFunction

    timers[#timers + 1] = self
    return self
  end

  function module.performAfterDelay(delay, fn, ...)
    return module.new(delay, fn, ...)
  end

  -- Fires straight away, then every repeatDelay while the timer lives.
  function module.keyRepeatTimerWithDelay(initialDelay, repeatDelay, fn, ...)
    local args = { ... }
    local argCount = select("#", ...)

    local function fire()
      if argCount > 0 then
        fn(unpackArgs(args, 1, argCount))
      else
        fn()
      end
    end

    local t = module.new(initialDelay, function() end)
    t.discardOnCompletion = false
    t.repeats = true
    t.timerEndedCallback = function(self)
      fire()
      self.duration = repeatDelay
    end
    fire()
    return t
  end

  function module.keyRepeatTimer(fn, ...)
    return module.keyRepeatTimerWithDelay(300, 100, fn, ...)
  end

  function module.allTimers()
    return timers
  end

  function methods:pause()
    self.paused = true
  end

  function methods:start()
    self.paused = false
    self.active = true
  end

  function methods:reset()
    self.startValue = self._originalStart
    self.endValue = self._originalEnd
    self.easingFunction = self._originalEasing
    self.currentTime = 0
    self.value = self.startValue
    self.active = true
    self.paused = false
    self._hasReversed = false
    self._remainingDelay = self.delay
  end

  function methods:remove()
    self.active = false
    for i = 1, #timers do
      if timers[i] == self then
        table.remove(timers, i)
        break
      end
    end
  end

  local function updateValue(self)
    if self.startValue ~= self.endValue and self.duration ~= 0 then
      self.value = self.easingFunction(self.currentTime, self.startValue,
        self.endValue - self.startValue, self.duration,
        self.easingAmplitude, self.easingPeriod)
    else
      self.value = self.endValue
    end
  end

  local function fireEnded(self)
    if not self.timerEndedCallback then
      return
    end
    if self.timerEndedArgs then
      self.timerEndedCallback(unpackArgs(self.timerEndedArgs, 1, self._argCount))
    else
      self.timerEndedCallback(self)
    end
  end

  function module.updateTimers()
    local step = stepFn()

    -- Copy first: a callback is allowed to make or remove timers.
    local live = {}
    for i = 1, #timers do
      live[i] = timers[i]
    end

    local finished = {}

    for i = 1, #live do
      local self = live[i]
      if self.active and not self.paused then
        if not self._remainingDelay then
          self._remainingDelay = self.delay
        end

        if self._remainingDelay > 0 then
          self._remainingDelay = self._remainingDelay - step
        else
          self.currentTime = self.currentTime + step

          if self.currentTime <= self.duration then
            updateValue(self)
            if self.updateCallback then
              self.updateCallback(self)
            end
          elseif self.reverses and not self._hasReversed then
            self.startValue, self.endValue = self.endValue, self.startValue
            self.currentTime = 0
            self._hasReversed = true
            if self.reverseEasingFunction then
              self.easingFunction = self.reverseEasingFunction
            end
          elseif self.repeats then
            local overshoot = self.currentTime - self.duration
            fireEnded(self)
            self.currentTime = overshoot
            self._hasReversed = false
            self._remainingDelay = self.delay
            updateValue(self)
          else
            self.active = false
            self.currentTime = self.duration
            self.value = self.endValue
            fireEnded(self)
            if self.discardOnCompletion then
              finished[#finished + 1] = self
            end
          end
        end
      end
    end

    for i = 1, #finished do
      finished[i]:remove()
    end
  end

  return module
end

-- Milliseconds, read from the same clock the rest of the SDK uses.
local lastTime = nil
playdate.timer = buildTimerModule(function()
  local now = playdate.getCurrentTimeMilliseconds()
  if not lastTime then
    lastTime = now
  end
  local delta = now - lastTime
  lastTime = now
  return delta
end)

-- While the system menu is open the game is paused and updateTimers is never
-- called, but the clock keeps going. Without this the first frame after the
-- menu closes is handed the whole length of the pause and every timer in the
-- game jumps forward by it. shim/ui.lua calls this when the menu closes: as
-- far as the timers are concerned the pause did not happen.
function playdate.shim.forgetPausedTime()
  lastTime = nil
end

-- Frames. One call to updateTimers is one frame, whatever the clock says.
playdate.frameTimer = buildTimerModule(function()
  return 1
end)

-- The frame count is what you read on a frame timer, under the SDK's name.
local frameTimerMeta = playdate.frameTimer.__index
local baseIndex = frameTimerMeta.__index
frameTimerMeta.__index = function(t, key)
  if key == "frame" then
    return rawget(t, "currentTime")
  end
  return baseIndex(t, key)
end

return {
  timer = playdate.timer,
  frameTimer = playdate.frameTimer,
}
