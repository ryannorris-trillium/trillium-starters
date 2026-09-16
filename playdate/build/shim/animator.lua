-- playdate.graphics.animator.
--
-- An animator is a value that reads differently depending on what time it is.
-- You make one, then ask it for currentValue() every frame. Playbit ships the
-- file with every function raising an error, and it asks for the easing
-- functions under a name that does not resolve, so requiring it first (to fill
-- the module cache) and then replacing it is the whole job.

local warn = require("shim.warn")

require("shim.compat")
require("playdate.animation")
require("playdate.animator")

local gfx = playdate.graphics
local easings = playdate.easingFunctions

local animator = {}
gfx.animator = animator

local meta = {}
meta.__index = meta
animator.__index = meta

local function isPoint(value)
  return type(value) == "table" and value.x ~= nil and value.y ~= nil
end

-- animator.new(duration, startValue, endValue, [easingFunction], [startTimeOffset])
-- The values are numbers, or playdate.geometry.points.
function animator.new(duration, startValue, endValue, easingFunction, startTimeOffset)
  local self = setmetatable({}, meta)

  if type(duration) == "table" then
    warn.once("animator.new() with a table of durations")
    duration, startValue, endValue = 1000, 0, 1
  elseif type(startValue) == "table" and not isPoint(startValue) then
    warn.once("animator.new() along a line, arc or polygon")
    startValue, endValue = 0, 1
  end

  self.duration = duration
  self.startValue = startValue or 0
  self.endValue = endValue or 0
  self.easingFunction = easingFunction or easings.linear
  self.startTimeOffset = startTimeOffset or 0
  self.easingAmplitude = nil
  self.easingPeriod = nil
  self.repeatCount = 0
  self.reverses = false
  self.s = 1
  self._startTime = playdate.getCurrentTimeMilliseconds() + self.startTimeOffset
  return self
end

-- With reverses on, a full cycle runs out and back, so it takes twice as long.
local function cycleLength(self)
  if self.reverses then
    return self.duration * 2
  end
  return self.duration
end

-- nil means it never ends.
local function totalLength(self)
  if self.repeatCount < 0 then
    return nil
  end
  return cycleLength(self) * (self.repeatCount + 1)
end

function meta:valueAtTime(time)
  local duration = self.duration
  if duration <= 0 then
    return self.endValue
  end

  local t = time
  if t < 0 then
    t = 0
  end

  local cycle = cycleLength(self)
  local total = totalLength(self)
  if total and t >= total then
    t = cycle
  elseif t >= cycle then
    t = t - math.floor(t / cycle) * cycle
  end

  -- Second half of a reversing cycle: walk back down.
  if self.reverses and t > duration then
    t = cycle - t
  end
  if t > duration then
    t = duration
  end

  local ease = self.easingFunction
  if isPoint(self.startValue) then
    local fraction = ease(t, 0, 1, duration, self.easingAmplitude, self.easingPeriod)
    local sx, sy = self.startValue.x, self.startValue.y
    local ex, ey = self.endValue.x, self.endValue.y
    return playdate.geometry.point.new(sx + (ex - sx) * fraction, sy + (ey - sy) * fraction)
  end

  return ease(t, self.startValue, self.endValue - self.startValue, duration,
    self.easingAmplitude, self.easingPeriod)
end

function meta:_elapsed()
  return playdate.getCurrentTimeMilliseconds() - self._startTime
end

function meta:currentValue()
  return self:valueAtTime(self:_elapsed())
end

function meta:progress()
  if self.duration <= 0 then
    return 1
  end
  local p = self:_elapsed() / self.duration
  if p < 0 then
    return 0
  end
  if p > 1 then
    return 1
  end
  return p
end

function meta:ended()
  local total = totalLength(self)
  if not total then
    return false
  end
  return self:_elapsed() >= total
end

function meta:reset(duration, startTimeOffset)
  if duration then
    self.duration = duration
  end
  if startTimeOffset then
    self.startTimeOffset = startTimeOffset
  end
  self._startTime = playdate.getCurrentTimeMilliseconds() + self.startTimeOffset
end

-- playdate.graphics.animation.loop already works in Playbit. blinker does not:
-- it is a flag that flips on and off on a schedule, which is how "press A"
-- prompts flash.
local blinker = {}
gfx.animation.blinker = blinker

local blinkerMeta = {}
blinkerMeta.__index = blinkerMeta
blinker.__index = blinkerMeta

local blinkers = {}

function blinker.new(onDuration, offDuration, loop, cycles, default)
  local self = setmetatable({}, blinkerMeta)
  self.onDuration = onDuration or 200
  self.offDuration = offDuration or 200
  self.loop = loop or false
  self.cycles = cycles or 6
  self.default = default
  if self.default == nil then
    self.default = true
  end
  self.on = self.default
  self.running = false
  self.counter = 0
  self._changeTime = 0
  blinkers[#blinkers + 1] = self
  return self
end

function blinkerMeta:start(onDuration, offDuration, loop, cycles, default)
  if onDuration then self.onDuration = onDuration end
  if offDuration then self.offDuration = offDuration end
  if loop ~= nil then self.loop = loop end
  if cycles then self.cycles = cycles end
  if default ~= nil then self.default = default end
  self.on = true
  self.running = true
  self.counter = self.cycles
  self._changeTime = playdate.getCurrentTimeMilliseconds()
end

function blinkerMeta:startLoop()
  self.loop = true
  self:start()
end

function blinkerMeta:stop()
  self.running = false
  self.on = self.default
  self.counter = 0
end

function blinkerMeta:remove()
  self:stop()
  for i = 1, #blinkers do
    if blinkers[i] == self then
      table.remove(blinkers, i)
      break
    end
  end
end

function blinkerMeta:update()
  if not self.running then
    return
  end
  local now = playdate.getCurrentTimeMilliseconds()
  local span = self.on and self.onDuration or self.offDuration
  if now - self._changeTime < span then
    return
  end
  self._changeTime = now
  self.on = not self.on
  if self.on then
    self.counter = self.counter - 1
    if self.counter <= 0 then
      if self.loop then
        self.counter = self.cycles
      else
        self:stop()
      end
    end
  end
end

function blinker.updateAll()
  for i = 1, #blinkers do
    blinkers[i]:update()
  end
end

function blinker.stopAll()
  for i = 1, #blinkers do
    blinkers[i]:stop()
  end
end

return animator
