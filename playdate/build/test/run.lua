-- Tests for the browser shim. Run against a finished web build:
--
--   lua build/test/run.lua _web
--
-- It loads the same files the browser loads, on top of the Love2d stand-in in
-- fakelove.lua, and checks the answers by hand. No browser, no Love, no
-- graphics card.

local webFolder = arg[1] or "_web"
local testFolder = string.match(arg[0], "^(.*)[/\\][^/\\]+$") or "."

package.path = table.concat({
  webFolder .. "/?.lua",
  webFolder .. "/?/init.lua",
  testFolder .. "/?.lua",
  package.path,
}, ";")

-- Tiny test framework -------------------------------------------------------

local passed, failed = 0, 0
local currentTest = "?"

local function check(condition, message)
  if condition then
    passed = passed + 1
  else
    failed = failed + 1
    print("  FAIL  " .. currentTest .. ": " .. message)
  end
end

local function near(a, b, tolerance)
  return math.abs(a - b) <= (tolerance or 0.001)
end

local function checkEqual(actual, expected, message)
  if type(actual) == "number" and type(expected) == "number" then
    check(near(actual, expected), message .. " (expected " .. tostring(expected) ..
      ", got " .. tostring(actual) .. ")")
  else
    check(actual == expected, message .. " (expected " .. tostring(expected) ..
      ", got " .. tostring(actual) .. ")")
  end
end

local tests = {}

local function test(name, fn)
  tests[#tests + 1] = { name = name, fn = fn }
end

-- Boot ----------------------------------------------------------------------

local fake = require("fakelove")
fake.install()

-- build/bit51.lua, which dev-web.sh prepends to main.lua in the real build.
local bitChunk = assert(loadfile(testFolder .. "/../bit51.lua"))
bitChunk()

-- Some image files for the imagetable tests.
fake.files["hero-table-1.png"] = { width = 16, height = 16 }
fake.files["hero-table-2.png"] = { width = 16, height = 16 }
fake.files["hero-table-3.png"] = { width = 16, height = 16 }

require("playbit.graphics")
require("playdate.playdate")
require("playdate.graphics")

-- playbit/header.lua loads a real font from fonts/. Nothing here reads a .fnt
-- file, so stand one in, the same way the header would.
playbit.graphics.fallbackFont = {
  data = {},
  getTextWidth = function(self, str) return #tostring(str) * 6 end,
  getHeight = function() return 12 end,
  getLeading = function() return 2 end,
  drawText = function(self, str, x, y) fake.record("text", str, x, y) end,
  drawTextAligned = function(self, str, x, y) fake.record("text", str, x, y) end,
  _drawTextInRect = function(self, str, x, y) fake.record("text", str, x, y) end,
}

require("shim.init")

local gfx = playdate.graphics
local sprite = gfx.sprite

-- Reachability ---------------------------------------------------------------

local function resolve(path)
  local node = _G
  for part in string.gmatch(path, "[^%.]+") do
    if type(node) ~= "table" then
      return nil
    end
    node = node[part]
  end
  return node
end

test("every shim function is reachable from the playdate namespace", function()
  local expected = {
    -- sprites
    "playdate.graphics.sprite.new",
    "playdate.graphics.sprite.update",
    "playdate.graphics.sprite.redraw",
    "playdate.graphics.sprite.removeAll",
    "playdate.graphics.sprite.getAllSprites",
    "playdate.graphics.sprite.querySpritesInRect",
    "playdate.graphics.sprite.querySpritesAtPoint",
    "playdate.graphics.sprite.setBackgroundDrawingCallback",
    "playdate.graphics.sprite.addSprite",
    "playdate.graphics.sprite.removeSprite",
    "playdate.graphics.sprite.spriteCount",
    "playdate.graphics.sprite.performOnAllSprites",
    "playdate.graphics.sprite.allOverlappingSprites",
    "playdate.graphics.sprite.setImage",
    "playdate.graphics.sprite.add",
    "playdate.graphics.sprite.remove",
    "playdate.graphics.sprite.moveTo",
    "playdate.graphics.sprite.moveBy",
    "playdate.graphics.sprite.getPosition",
    "playdate.graphics.sprite.setCenter",
    "playdate.graphics.sprite.getCenter",
    "playdate.graphics.sprite.setZIndex",
    "playdate.graphics.sprite.getZIndex",
    "playdate.graphics.sprite.setVisible",
    "playdate.graphics.sprite.isVisible",
    "playdate.graphics.sprite.setSize",
    "playdate.graphics.sprite.getSize",
    "playdate.graphics.sprite.setBounds",
    "playdate.graphics.sprite.getBounds",
    "playdate.graphics.sprite.setCollideRect",
    "playdate.graphics.sprite.getCollideRect",
    "playdate.graphics.sprite.clearCollideRect",
    "playdate.graphics.sprite.setTag",
    "playdate.graphics.sprite.getTag",
    "playdate.graphics.sprite.setGroups",
    "playdate.graphics.sprite.setCollidesWithGroups",
    "playdate.graphics.sprite.setGroupMask",
    "playdate.graphics.sprite.setCollidesWithGroupsMask",
    "playdate.graphics.sprite.moveWithCollisions",
    "playdate.graphics.sprite.checkCollisions",
    "playdate.graphics.sprite.overlappingSprites",
    "playdate.graphics.sprite.collisionResponse",
    "playdate.graphics.sprite.setCollisionResponse",
    "playdate.graphics.sprite.setImageFlip",
    "playdate.graphics.sprite.setScale",
    "playdate.graphics.sprite.markDirty",
    "playdate.graphics.sprite.addEmptyCollisionSprite",
    "playdate.graphics.sprite.draw",
    -- animation
    "playdate.graphics.animator.new",
    "playdate.graphics.animation.loop.new",
    "playdate.graphics.animation.blinker.new",
    "playdate.easingFunctions.linear",
    "playdate.easingFunctions.inQuad",
    "playdate.easingFunctions.outQuad",
    "playdate.easingFunctions.inOutQuad",
    "playdate.easingFunctions.inOutSine",
    "playdate.easingFunctions.outBounce",
    -- timers
    "playdate.timer.new",
    "playdate.timer.updateTimers",
    "playdate.timer.performAfterDelay",
    "playdate.timer.keyRepeatTimer",
    "playdate.timer.keyRepeatTimerWithDelay",
    "playdate.timer.allTimers",
    "playdate.frameTimer.new",
    "playdate.frameTimer.updateTimers",
    "playdate.frameTimer.performAfterDelay",
    "playdate.frameTimer.allTimers",
    -- graphics
    "playdate.graphics.drawRoundRect",
    "playdate.graphics.fillRoundRect",
    "playdate.graphics.drawTriangle",
    "playdate.graphics.fillTriangle",
    "playdate.graphics.drawPolygon",
    "playdate.graphics.fillPolygon",
    "playdate.graphics.setClipRect",
    "playdate.graphics.clearClipRect",
    "playdate.graphics.setDitherPattern",
    "playdate.graphics.setStrokeLocation",
    "playdate.graphics.setLineWidth",
    "playdate.graphics.setDrawOffset",
    "playdate.graphics.getImageDrawMode",
    "playdate.graphics.setImageDrawMode",
    "playdate.graphics.drawTextAligned",
    "playdate.graphics.image.new",
    "playdate.graphics.image.imageSizeAtPath",
    "playdate.graphics.imagetable.new",
    -- sound
    "playdate.sound.synth.new",
    "playdate.sound.sampleplayer.new",
    "playdate.sound.fileplayer.new",
    "playdate.sound.sample.new",
    "playdate.sound.getSampleRate",
    -- ui, display, system
    "playdate.ui.crankIndicator.draw",
    "playdate.ui.crankIndicator.update",
    "playdate.ui.crankIndicator.start",
    "playdate.display.setRefreshRate",
    "playdate.display.getRefreshRate",
    "playdate.display.getWidth",
    "playdate.display.getHeight",
    "playdate.display.setInverted",
    "playdate.display.setScale",
    "playdate.file.exists",
    "playdate.file.isdir",
    "playdate.file.listFiles",
    "playdate.file.delete",
    "playdate.file.mkdir",
    "playdate.file.getType",
    "playdate.file.rename",
    "playdate.datastore.write",
    "playdate.datastore.read",
    "playdate.datastore.delete",
    "playdate.getSystemMenu",
    "playdate.setMenuImage",
    "playdate.getCurrentTimeMilliseconds",
    "playdate.getElapsedTime",
    "playdate.resetElapsedTime",
    "playdate.getReduceFlashing",
    "playdate.buttonIsPressed",
    "playdate.buttonJustPressed",
    "playdate.buttonJustReleased",
    "playdate.getCrankPosition",
    "playdate.getCrankChange",
    "playdate.getCrankTicks",
    "playdate.isCrankDocked",
    "playdate.startAccelerometer",
    "playdate.readAccelerometer",
    "playdate.math.lerp",
    "json.encode",
    "json.decode",
    "printTable",
  }

  for i = 1, #expected do
    local value = resolve(expected[i])
    check(type(value) == "function", expected[i] .. " should be a function, is " .. type(value))
  end

  checkEqual(type(playdate.isSimulator), "number", "playdate.isSimulator is set")
  checkEqual(playdate.getReduceFlashing(), false, "getReduceFlashing is false")
  checkEqual(playdate.isCrankDocked(), false, "isCrankDocked is false")
  local ax, ay, az = playdate.readAccelerometer()
  checkEqual(ax, 0, "accelerometer x")
  checkEqual(ay, 0, "accelerometer y")
  checkEqual(az, 1, "accelerometer z")
end)

-- Sprites --------------------------------------------------------------------

test("sprites draw in z order, then in the order they were added", function()
  sprite.removeAll()
  local drawn = {}

  local function makeSprite(name, z)
    local s = sprite.new()
    s:setSize(10, 10)
    s:moveTo(50, 50)
    s:setZIndex(z)
    s.draw = function()
      drawn[#drawn + 1] = name
    end
    s:add()
    return s
  end

  makeSprite("top", 10)
  makeSprite("bottom", -5)
  makeSprite("middleA", 0)
  makeSprite("middleB", 0)

  sprite.update()

  checkEqual(#drawn, 4, "all four sprites drew")
  checkEqual(drawn[1], "bottom", "lowest z first")
  checkEqual(drawn[2], "middleA", "equal z keeps add order")
  checkEqual(drawn[3], "middleB", "equal z keeps add order")
  checkEqual(drawn[4], "top", "highest z last")
end)

test("a hidden sprite does not draw, and removeAll empties the list", function()
  sprite.removeAll()
  local drew = false
  local s = sprite.new()
  s:setSize(10, 10)
  s.draw = function() drew = true end
  s:add()
  s:setVisible(false)
  sprite.update()
  checkEqual(drew, false, "hidden sprite stayed hidden")
  checkEqual(sprite.spriteCount(), 1, "hidden sprite is still in the list")
  sprite.removeAll()
  checkEqual(sprite.spriteCount(), 0, "removeAll emptied the list")
end)

test("a sprite's own update() runs, and the class update() does not recurse", function()
  sprite.removeAll()
  local ticks = 0
  local s = sprite.new()
  s:setSize(4, 4)
  s.update = function(self)
    ticks = ticks + 1
  end
  s:add()

  local plain = sprite.new()
  plain:setSize(4, 4)
  plain:add()

  sprite.update()
  sprite.update()
  checkEqual(ticks, 2, "the overriding sprite updated twice")
  -- The plain sprite inherits the class update(); calling it must do nothing.
  plain:update()
  checkEqual(sprite.spriteCount(), 2, "calling update on a plain sprite is harmless")
end)

test("bounds, center and collide rect line up the way the SDK says", function()
  sprite.removeAll()
  local s = sprite.new()
  s:setSize(20, 10)
  s:moveTo(100, 50)

  local x, y, w, h = s:getBounds()
  checkEqual(x, 90, "default center 0.5 puts bounds half a width left")
  checkEqual(y, 45, "default center 0.5 puts bounds half a height up")
  checkEqual(w, 20, "bounds width")
  checkEqual(h, 10, "bounds height")

  s:setCenter(0, 0)
  x, y = s:getBounds()
  checkEqual(x, 100, "center 0,0 puts bounds at the position")
  checkEqual(y, 50, "center 0,0 puts bounds at the position")

  s:setCenter(0.5, 0.5)
  s:setBounds(0, 0, 40, 40)
  local px, py = s:getPosition()
  checkEqual(px, 20, "setBounds moves the center")
  checkEqual(py, 20, "setBounds moves the center")

  s:setCollideRect(2, 3, 10, 10)
  local rx, ry, rw, rh = s:_worldCollideRect()
  checkEqual(rx, 2, "collide rect is measured from the top left of the bounds")
  checkEqual(ry, 3, "collide rect is measured from the top left of the bounds")
  checkEqual(rw, 10, "collide rect width")
  checkEqual(rh, 10, "collide rect height")
end)

-- The four collision cases, each worked out on paper first.
--
-- The player is 20 by 20 with its collide rect filling it, so its rect runs
-- from x - 10 to x + 10. The wall is 20 by 20 at x = 100, so its rect runs
-- from 90 to 110. Moving right, the player can get to x = 80 before the two
-- rects touch: 80 + 10 = 90.
local function collisionSetup(response)
  sprite.removeAll()
  local player = sprite.new()
  player:setSize(20, 20)
  player:setCollideRect(0, 0, 20, 20)
  player:moveTo(50, 50)
  player.collisionResponse = function()
    return response
  end
  player:add()

  local wall = sprite.new()
  wall:setSize(20, 20)
  wall:setCollideRect(0, 0, 20, 20)
  wall:moveTo(100, 50)
  wall:add()

  return player, wall
end

test("moveWithCollisions freeze stops at contact and gives up the other axis", function()
  local player = collisionSetup(sprite.kCollisionTypeFreeze)
  local ax, ay, collisions, count = player:moveWithCollisions(200, 120)
  checkEqual(ax, 80, "stopped where the rects touch")
  checkEqual(ay, 50, "freeze cancels the vertical move too")
  checkEqual(count, 1, "one collision")
  checkEqual(collisions[1].type, sprite.kCollisionTypeFreeze, "collision type is freeze")
  checkEqual(collisions[1].normal.x, -1, "normal points back the way it came")
  checkEqual(collisions[1].normal.y, 0, "normal has no vertical part")
  checkEqual(collisions[1].overlaps, false, "freeze is not an overlap")
  checkEqual(collisions[1].other ~= nil, true, "the other sprite is reported")
end)

test("moveWithCollisions slide stops on x and keeps the y movement", function()
  local player = collisionSetup(sprite.kCollisionTypeSlide)
  local ax, ay, collisions, count = player:moveWithCollisions(200, 120)
  checkEqual(ax, 80, "stopped where the rects touch")
  checkEqual(ay, 120, "slid down past the wall")
  checkEqual(count, 1, "one collision")
  checkEqual(collisions[1].type, sprite.kCollisionTypeSlide, "collision type is slide")
end)

test("moveWithCollisions overlap passes through and still reports the hit", function()
  local player = collisionSetup(sprite.kCollisionTypeOverlap)
  local ax, ay, collisions, count = player:moveWithCollisions(200, 50)
  checkEqual(ax, 200, "overlap does not block")
  checkEqual(ay, 50, "overlap does not block")
  checkEqual(count, 1, "the hit is still reported")
  checkEqual(collisions[1].overlaps, true, "reported as an overlap")
end)

test("moveWithCollisions bounce reflects the leftover movement", function()
  -- Asking for x = 100 with contact at 80 leaves 20 pixels of movement, which
  -- come back the other way: 80 - 20 = 60.
  local player = collisionSetup(sprite.kCollisionTypeBounce)
  local ax, ay, collisions, count = player:moveWithCollisions(100, 50)
  checkEqual(ax, 60, "bounced back past the contact point")
  checkEqual(ay, 50, "no vertical movement was asked for")
  checkEqual(count, 1, "one collision")
  checkEqual(collisions[1].type, sprite.kCollisionTypeBounce, "collision type is bounce")
end)

test("a fast move does not step over a collectible", function()
  -- 150 pixels in one frame, with a small coin in the middle of the path.
  sprite.removeAll()
  local player = sprite.new()
  player:setSize(20, 20)
  player:setCollideRect(0, 0, 20, 20)
  player:moveTo(50, 50)
  player.collisionResponse = function()
    return sprite.kCollisionTypeOverlap
  end
  player:add()

  local coin = sprite.new()
  coin:setSize(10, 10)
  coin:setCollideRect(0, 0, 10, 10)
  coin:moveTo(100, 50)
  coin:add()

  local ax, _, collisions, count = player:moveWithCollisions(200, 50)
  checkEqual(ax, 200, "the player kept going")
  checkEqual(count, 1, "the coin in the middle of the path was noticed")
  checkEqual(collisions[1].other, coin, "and it was the coin")
end)

test("a sprite with no collide rect just moves", function()
  sprite.removeAll()
  local s = sprite.new()
  s:setSize(10, 10)
  s:moveTo(10, 10)
  s:add()
  local ax, ay, collisions, count = s:moveWithCollisions(300, 200)
  checkEqual(ax, 300, "moved all the way")
  checkEqual(ay, 200, "moved all the way")
  checkEqual(count, 0, "no collisions")
end)

test("checkCollisions answers without moving", function()
  local player = collisionSetup(sprite.kCollisionTypeFreeze)
  local ax, ay, _, count = player:checkCollisions(200, 50)
  checkEqual(ax, 80, "reports where it would have stopped")
  checkEqual(count, 1, "reports the collision")
  local px = player:getPosition()
  checkEqual(px, 50, "but the sprite did not move")
end)

test("addEmptyCollisionSprite makes an invisible wall", function()
  sprite.removeAll()
  local player = sprite.new()
  player:setSize(20, 20)
  player:setCollideRect(0, 0, 20, 20)
  player:moveTo(50, 50)
  player.collisionResponse = function() return sprite.kCollisionTypeSlide end
  player:add()

  sprite.addEmptyCollisionSprite(90, 40, 20, 20)

  local ax, _, _, count = player:moveWithCollisions(200, 50)
  checkEqual(ax, 80, "the invisible wall stopped it in the same place")
  checkEqual(count, 1, "and reported the collision")
  checkEqual(sprite.spriteCount(), 2, "the wall is in the display list")
end)

test("groups decide who collides with whom", function()
  sprite.removeAll()
  local player = sprite.new()
  player:setSize(20, 20)
  player:setCollideRect(0, 0, 20, 20)
  player:moveTo(50, 50)
  player:setCollidesWithGroups({ 2 })
  player:add()

  local ignored = sprite.new()
  ignored:setSize(20, 20)
  ignored:setCollideRect(0, 0, 20, 20)
  ignored:moveTo(100, 50)
  ignored:setGroups({ 3 })
  ignored:add()

  local ax, _, _, count = player:moveWithCollisions(200, 50)
  checkEqual(count, 0, "group 3 is not in the collides-with list")
  checkEqual(ax, 200, "so nothing stopped the move")

  player:moveTo(50, 50)
  ignored:setGroups({ 2 })
  local bx, _, _, hits = player:moveWithCollisions(200, 50)
  checkEqual(hits, 1, "group 2 is in the collides-with list")
  checkEqual(bx, 80, "and it blocked the move")
end)

test("overlappingSprites and querySpritesInRect find the right sprites", function()
  sprite.removeAll()
  local a = sprite.new()
  a:setSize(20, 20)
  a:setCollideRect(0, 0, 20, 20)
  a:moveTo(50, 50)
  a:add()

  local b = sprite.new()
  b:setSize(20, 20)
  b:setCollideRect(0, 0, 20, 20)
  b:moveTo(55, 50)
  b:add()

  local far = sprite.new()
  far:setSize(20, 20)
  far:setCollideRect(0, 0, 20, 20)
  far:moveTo(300, 200)
  far:add()

  local touching = a:overlappingSprites()
  checkEqual(#touching, 1, "one sprite overlaps a")
  checkEqual(touching[1], b, "and it is b")

  local inRect = sprite.querySpritesInRect(0, 0, 100, 100)
  checkEqual(#inRect, 2, "two sprites are in the top left corner")

  local atPoint = sprite.querySpritesAtPoint(300, 200)
  checkEqual(#atPoint, 1, "one sprite is at that point")
  checkEqual(atPoint[1], far, "and it is the far one")
end)

test("the background drawing callback runs once per update", function()
  sprite.removeAll()
  local calls = 0
  sprite.setBackgroundDrawingCallback(function(x, y, w, h)
    calls = calls + 1
    check(w == 400 and h == 240, "background callback gets the whole screen")
  end)
  sprite.update()
  sprite.update()
  checkEqual(calls, 2, "called once per update")
  sprite.setBackgroundDrawingCallback(nil)
end)

test("class(...).extends(gfx.sprite) makes a working subclass", function()
  sprite.removeAll()
  class("TestPlayer").extends(gfx.sprite)
  function TestPlayer:init()
    TestPlayer.super.init(self)
    self:setSize(8, 8)
    self.ticks = 0
  end
  function TestPlayer:update()
    self.ticks = self.ticks + 1
  end

  local p = TestPlayer()
  p:moveTo(20, 20)
  p:add()
  sprite.update()
  checkEqual(p.ticks, 1, "the subclass update ran")
  checkEqual(p:isa(gfx.sprite), true, "and it is a sprite")
  local x, y = p:getPosition()
  checkEqual(x, 20, "inherited methods work")
  checkEqual(y, 20, "inherited methods work")
  sprite.removeAll()
end)

-- Animator --------------------------------------------------------------------

test("animator reads the right value at the start, the middle and the end", function()
  fake.setTime(0)
  local a = gfx.animator.new(1000, 0, 100)
  checkEqual(a:valueAtTime(0), 0, "linear at t=0")
  checkEqual(a:valueAtTime(500), 50, "linear at halfway")
  checkEqual(a:valueAtTime(1000), 100, "linear at the end")
  checkEqual(a:valueAtTime(5000), 100, "past the end it holds")

  local eased = gfx.animator.new(1000, 0, 100, playdate.easingFunctions.outQuad)
  checkEqual(eased:valueAtTime(0), 0, "outQuad at t=0")
  checkEqual(eased:valueAtTime(500), 75, "outQuad at halfway is three quarters")
  checkEqual(eased:valueAtTime(1000), 100, "outQuad at the end")
end)

test("animator follows the clock", function()
  fake.setTime(0)
  local a = gfx.animator.new(1000, 0, 100)
  checkEqual(a:currentValue(), 0, "at the start")
  checkEqual(a:progress(), 0, "no progress yet")
  checkEqual(a:ended(), false, "not ended")
  fake.setTime(0.5)
  checkEqual(a:currentValue(), 50, "halfway through")
  checkEqual(a:progress(), 0.5, "half progress")
  fake.setTime(1)
  checkEqual(a:currentValue(), 100, "at the end")
  checkEqual(a:ended(), true, "ended")
  fake.setTime(1.5)
  checkEqual(a:currentValue(), 100, "stays at the end")

  a:reset()
  checkEqual(a:currentValue(), 0, "reset starts over")
end)

test("a reversing animator goes out and comes back", function()
  fake.setTime(0)
  local a = gfx.animator.new(1000, 0, 100)
  a.reverses = true
  checkEqual(a:valueAtTime(0), 0, "starts at 0")
  checkEqual(a:valueAtTime(1000), 100, "reaches the far end halfway through the cycle")
  checkEqual(a:valueAtTime(1500), 50, "and comes back")
  checkEqual(a:valueAtTime(2000), 0, "ending where it started")
end)

test("an animator between two points moves both coordinates", function()
  fake.setTime(0)
  local from = playdate.geometry.point.new(0, 100)
  local to = playdate.geometry.point.new(200, 0)
  local a = gfx.animator.new(1000, from, to)
  local halfway = a:valueAtTime(500)
  checkEqual(halfway.x, 100, "x halfway")
  checkEqual(halfway.y, 50, "y halfway")
end)

-- Timers -----------------------------------------------------------------------

test("playdate.timer counts milliseconds and fires once", function()
  fake.setTime(100)
  for _, t in ipairs(playdate.timer.allTimers()) do
    t:remove()
  end
  playdate.timer.updateTimers()

  local fired = 0
  playdate.timer.performAfterDelay(500, function()
    fired = fired + 1
  end)

  fake.advance(0.2)
  playdate.timer.updateTimers()
  checkEqual(fired, 0, "not yet")
  fake.advance(0.4)
  playdate.timer.updateTimers()
  checkEqual(fired, 1, "fired after the delay")
  fake.advance(1)
  playdate.timer.updateTimers()
  checkEqual(fired, 1, "and only once")
  checkEqual(#playdate.timer.allTimers(), 0, "a finished timer is discarded")
end)

test("removing a timer removes that timer, not another one", function()
  for _, t in ipairs(playdate.timer.allTimers()) do
    t:remove()
  end
  local firedA, firedB = false, false
  local a = playdate.timer.new(100, function() firedA = true end)
  local b = playdate.timer.new(100, function() firedB = true end)
  b:remove()
  checkEqual(#playdate.timer.allTimers(), 1, "one timer left")
  checkEqual(playdate.timer.allTimers()[1], a, "and it is the one that was kept")
  fake.advance(0.2)
  playdate.timer.updateTimers()
  checkEqual(firedA, true, "the kept timer fired")
  checkEqual(firedB, false, "the removed timer did not")
end)

test("a value timer eases between two numbers", function()
  for _, t in ipairs(playdate.timer.allTimers()) do
    t:remove()
  end
  local t = playdate.timer.new(1000, 0, 100)
  checkEqual(t.value, 0, "starts at the start value")
  fake.advance(0.5)
  playdate.timer.updateTimers()
  checkEqual(t.value, 50, "halfway")
  fake.advance(0.6)
  playdate.timer.updateTimers()
  checkEqual(t.value, 100, "ends at the end value")
  t:remove()
end)

test("frame timers count frames, not seconds", function()
  for _, t in ipairs(playdate.frameTimer.allTimers()) do
    t:remove()
  end
  local fired = false
  local t = playdate.frameTimer.new(3, function() fired = true end)
  playdate.frameTimer.updateTimers()
  playdate.frameTimer.updateTimers()
  checkEqual(fired, false, "two frames is not three")
  checkEqual(t.frame, 2, "two frames counted")
  playdate.frameTimer.updateTimers()
  playdate.frameTimer.updateTimers()
  checkEqual(fired, true, "fired on the fourth call, one past the duration")
end)

-- Datastore ------------------------------------------------------------------------

test("datastore writes a table and reads the same table back", function()
  playdate.datastore.write({ score = 42, name = "hazel", flags = { true, false } }, "scores")
  local loaded = playdate.datastore.read("scores")
  checkEqual(type(loaded), "table", "something came back")
  checkEqual(loaded.score, 42, "numbers survive")
  checkEqual(loaded.name, "hazel", "strings survive")
  checkEqual(loaded.flags[1], true, "nested tables survive")

  playdate.datastore.write({ level = 3 })
  local defaultFile = playdate.datastore.read()
  checkEqual(defaultFile.level, 3, "the default file name works")

  playdate.datastore.delete("scores")
  checkEqual(playdate.datastore.read("scores"), nil, "delete removes it")

  -- prettyPrint used to raise an error rather than being ignored.
  playdate.datastore.write({ a = 1 }, "pretty", true)
  checkEqual(playdate.datastore.read("pretty").a, 1, "the pretty print flag is accepted")
end)

test("the playdate.file questions Playbit raises errors for now answer", function()
  fake.files["notes/hello.txt"] = "hi"
  checkEqual(playdate.file.exists("notes/hello.txt"), true, "exists finds a file")
  checkEqual(playdate.file.exists("notes/nope.txt"), false, "and says no to one that is not there")
  checkEqual(playdate.file.getType("notes/hello.txt"), "file", "getType says file")
  local listed = playdate.file.listFiles("notes")
  checkEqual(#listed, 1, "listFiles found it")
  checkEqual(listed[1], "hello.txt", "with the right name")
  playdate.file.rename("notes/hello.txt", "notes/renamed.txt")
  checkEqual(playdate.file.exists("notes/renamed.txt"), true, "rename moved it")
  checkEqual(playdate.file.exists("notes/hello.txt"), false, "and the old name is gone")
  playdate.file.delete("notes/renamed.txt")
  checkEqual(playdate.file.exists("notes/renamed.txt"), false, "delete removed it")
end)

test("json encodes as well as decodes", function()
  local text = json.encode({ n = 7 })
  checkEqual(type(text), "string", "encode returns a string")
  checkEqual(json.decode(text).n, 7, "and it round trips")
end)

-- Imagetable ---------------------------------------------------------------------

test("an imagetable loads a numbered sequence of files", function()
  local it = gfx.imagetable.new("hero")
  checkEqual(it:getLength(), 3, "found three frames")
  checkEqual(type(it:getImage(1)), "table", "frame 1 is an image")
  checkEqual(it[2] ~= nil, true, "index notation works")
  local w, h = it:getImage(1):getSize()
  checkEqual(w, 16, "frame width")
  checkEqual(h, 16, "frame height")
end)

test("a missing imagetable says so instead of failing deep inside Playbit", function()
  local ok, message = pcall(gfx.imagetable.new, "nothing-here")
  checkEqual(ok, false, "it raises")
  checkEqual(string.find(message, "imagetable") ~= nil, true, "and the message names the problem")
end)

test("animation.loop walks an imagetable", function()
  fake.setTime(0)
  local it = gfx.imagetable.new("hero")
  local loop = gfx.animation.loop.new(100, it, true)
  checkEqual(loop.frame, 1, "starts on frame 1")
  checkEqual(loop.endFrame, 3, "knows how many frames there are")
end)

-- Sound -----------------------------------------------------------------------------

test("the synth makes a noise", function()
  fake.clearLog()
  local synth = playdate.sound.synth.new(playdate.sound.kWaveSquare)
  synth:playNote(440, 0.5, 0.1)
  local played = false
  for _, entry in ipairs(fake.log) do
    if entry.name == "audio.play" then
      played = true
    end
  end
  checkEqual(played, true, "a source was played")
  checkEqual(synth:isPlaying(), true, "and the synth says so")
end)

test("the synth understands note names and MIDI numbers", function()
  local synth = playdate.sound.synth.new()
  local ok = pcall(function() synth:playNote("C4", 1, 0.05) end)
  checkEqual(ok, true, "a note name is accepted")
  ok = pcall(function() synth:playMIDINote(60, 1, 0.05) end)
  checkEqual(ok, true, "a MIDI number is accepted")
end)

test("a sample player for a file that is not there stays quiet instead of crashing", function()
  local player = playdate.sound.sampleplayer.new("no-such-sound")
  checkEqual(player:play(), false, "play is safe")
  checkEqual(player:isPlaying(), false, "and reports nothing playing")
end)

-- Menu, display, crank indicator ---------------------------------------------------

test("the system menu holds items and A activates them", function()
  local menu = playdate.getSystemMenu()
  menu:removeAllMenuItems()

  local pressed = 0
  menu:addMenuItem("Restart", function() pressed = pressed + 1 end)

  local checkValue = nil
  local checkItem = menu:addCheckmarkMenuItem("Sound", true, function(value)
    checkValue = value
  end)

  local optionValue = nil
  local optionItem = menu:addOptionsMenuItem("Speed", { "slow", "fast" }, "slow", function(value)
    optionValue = value
  end)

  checkEqual(#menu:getMenuItems(), 3, "three items")
  checkEqual(checkItem:getValue(), true, "checkmark starts on")
  checkEqual(optionItem:getTitle(), "Speed", "the options item kept its title")

  local ui = playdate.shim.ui
  ui.menuKey("m")
  checkEqual(ui.menuIsOpen(), true, "M opens the menu")
  ui.menuKey("s")
  checkEqual(pressed, 1, "A ran the first item")
  ui.menuKey("down")
  ui.menuKey("s")
  checkEqual(checkValue, false, "A toggled the checkmark")
  ui.menuKey("down")
  ui.menuKey("s")
  checkEqual(optionValue, "fast", "A stepped the options item")
  ui.menuKey("m")
  checkEqual(ui.menuIsOpen(), false, "M closes it again")

  menu:removeAllMenuItems()
  checkEqual(#menu:getMenuItems(), 0, "items cleared")
end)

test("display reports the Playdate screen and holds a refresh rate", function()
  checkEqual(playdate.display.getWidth(), 400, "400 across")
  checkEqual(playdate.display.getHeight(), 240, "240 down")
  checkEqual(playdate.display.getRefreshRate(), 30, "30 frames a second by default")
  playdate.display.setRefreshRate(50)
  checkEqual(playdate.display.getRefreshRate(), 50, "and it can be changed")
  playdate.display.setRefreshRate(30)
  playdate.display.setInverted(true)
  checkEqual(playdate.display.getInverted(), true, "inverted")
  playdate.display.setInverted(false)
end)

test("the crank indicator draws without complaining", function()
  fake.clearLog()
  playdate.ui.crankIndicator:start()
  local ok, message = pcall(function()
    playdate.ui.crankIndicator:update()
  end)
  checkEqual(ok, true, "it drew: " .. tostring(message))
  checkEqual(#fake.log > 0, true, "and it put something on the screen")
end)

-- Graphics gaps -----------------------------------------------------------------------

test("the drawing calls Playbit raises errors for now work", function()
  local calls = {
    function() gfx.drawRoundRect(10, 10, 40, 20, 4) end,
    function() gfx.fillRoundRect(10, 10, 40, 20, 4) end,
    function() gfx.drawTriangle(0, 0, 10, 0, 5, 10) end,
    function() gfx.fillPolygon(0, 0, 10, 0, 10, 10, 0, 10) end,
    function() gfx.setClipRect(0, 0, 100, 100) end,
    function() gfx.clearClipRect() end,
    function() gfx.setDitherPattern(0.5) end,
    function() gfx.setImageDrawMode(gfx.kDrawModeBlackTransparent) end,
    function() gfx.setImageDrawMode(gfx.kDrawModeCopy) end,
    function() gfx.fillEllipseInRect(0, 0, 20, 10) end,
  }
  for i = 1, #calls do
    local ok, message = pcall(calls[i])
    check(ok, "drawing call " .. i .. " failed: " .. tostring(message))
  end
end)

test("missing features warn once instead of stopping the game", function()
  local before = #playdate.shim.missingSoFar()
  local image = gfx.image.new(8, 8)
  image:setMaskImage(nil)
  image:setMaskImage(nil)
  image:setMaskImage(nil)
  local after = #playdate.shim.missingSoFar()
  checkEqual(after - before, 1, "three calls, one warning")
end)

test("image helpers Playbit leaves as errors now work", function()
  local image = gfx.image.new(8, 8)
  local ok, message = pcall(function()
    local copy = image:copy()
    local w, h = copy:getSize()
    check(w == 8 and h == 8, "the copy is the same size")
    image:drawCentered(10, 10)
    image:drawAnchored(10, 10, 1, 1)
    image:drawTiled(0, 0, 32, 32)
  end)
  check(ok, "image helpers failed: " .. tostring(message))
end)

-- Run -------------------------------------------------------------------------------

print("")
for i = 1, #tests do
  currentTest = tests[i].name
  local ok, message = pcall(tests[i].fn)
  if not ok then
    failed = failed + 1
    print("  ERROR " .. currentTest .. ": " .. tostring(message))
  end
end

print("")
print(passed .. " checks passed, " .. failed .. " failed, across " .. #tests .. " tests")
if failed > 0 then
  os.exit(1)
end
os.exit(0)
