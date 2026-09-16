-- Sprites, collisions, sound and saving.
--
-- Copy this over source/main.lua to try it:
--
--   cp source/main.lua source/main-backup.lua
--   cp examples/sprites/main.lua source/main.lua
--   bash dev-web.sh
--
-- Arrow keys move. Walls block you. Touch the prize to score. The crank sets
-- how fast you move. Your best score is saved and comes back next time.

import("CoreLibs/graphics")
import("CoreLibs/sprites")
import("CoreLibs/object")
import("CoreLibs/animator")
import("CoreLibs/easing")
import("CoreLibs/ui")

local gfx = playdate.graphics

-- Every sprite carries a tag so the collision code can tell them apart.
local TAG_PLAYER = 1
local TAG_WALL = 2
local TAG_PRIZE = 3

-- Pictures ------------------------------------------------------------------

-- A sprite needs an image. You can load one from a file, or draw one here at
-- the start, which is what these do. pushContext points the drawing commands
-- at the image instead of at the screen.

local function circleImage(size)
  local image = gfx.image.new(size, size)
  gfx.pushContext(image)
  gfx.setColor(gfx.kColorBlack)
  gfx.fillCircleAtPoint(size / 2, size / 2, size / 2 - 1)
  gfx.popContext()
  return image
end

local function blockImage(width, height)
  local image = gfx.image.new(width, height)
  gfx.pushContext(image)
  gfx.setColor(gfx.kColorBlack)
  gfx.fillRect(0, 0, width, height)
  gfx.popContext()
  return image
end

local function prizeImage(size)
  local image = gfx.image.new(size, size)
  gfx.pushContext(image)
  gfx.setColor(gfx.kColorBlack)
  gfx.drawRect(0, 0, size, size)
  gfx.fillRect(3, 3, size - 6, size - 6)
  gfx.popContext()
  return image
end

-- Sprites ---------------------------------------------------------------------

local player = gfx.sprite.new(circleImage(16))
player:setTag(TAG_PLAYER)
player:moveTo(60, 180)
-- A collide rect is the box the collision code uses. It is measured from the
-- top left of the sprite, so 0, 0, 16, 16 means "the whole thing".
player:setCollideRect(0, 0, 16, 16)
player:setZIndex(10)
player:add()

-- What happens when the player runs into something. Slide along walls, pass
-- through the prize.
function player:collisionResponse(other)
  if other:getTag() == TAG_PRIZE then
    return gfx.sprite.kCollisionTypeOverlap
  end
  return gfx.sprite.kCollisionTypeSlide
end

local function addWall(x, y, width, height)
  local wall = gfx.sprite.new(blockImage(width, height))
  wall:setTag(TAG_WALL)
  -- setCenter 0, 0 means x and y are the top left corner instead of the middle.
  wall:setCenter(0, 0)
  wall:moveTo(x, y)
  wall:setCollideRect(0, 0, width, height)
  wall:add()
  return wall
end

-- The edges of the screen.
addWall(0, 0, 400, 8)
addWall(0, 232, 400, 8)
addWall(0, 0, 8, 240)
addWall(392, 0, 8, 240)
-- And some things to slide along.
addWall(90, 60, 120, 12)
addWall(250, 100, 12, 110)
addWall(120, 160, 90, 12)

local prize = gfx.sprite.new(prizeImage(14))
prize:setTag(TAG_PRIZE)
prize:setCollideRect(0, 0, 14, 14)
prize:add()

local function movePrize()
  prize:moveTo(math.random(30, 370), math.random(30, 210))
end

-- The background. With setAlwaysRedraw on, this runs every frame and covers
-- the whole screen, which keeps things simple: nothing has to be erased by
-- hand.
gfx.sprite.setAlwaysRedraw(true)
gfx.sprite.setBackgroundDrawingCallback(function(x, y, width, height)
  gfx.setColor(gfx.kColorWhite)
  gfx.fillRect(x, y, width, height)
end)

-- Sound -----------------------------------------------------------------------

-- A synth makes a note without needing a sound file.
local beep = playdate.sound.synth.new(playdate.sound.kWaveSquare)

-- Saving ------------------------------------------------------------------------

-- datastore.read comes back nil the first time, because nothing is saved yet.
local score = 0
local best = 0
local saved = playdate.datastore.read("sprite-demo")
if saved and saved.best then
  best = saved.best
end

-- The title ----------------------------------------------------------------------

-- An animator is a number that changes over time. This one drops the title in
-- from above the screen and lets it bounce.
local titleDrop = gfx.animator.new(1200, -30, 40, playdate.easingFunctions.outBounce)

-- The frame ------------------------------------------------------------------------

local crankUsed = false
local lastCrank = playdate.getCrankPosition()

function playdate.update()
  -- The crank sets the speed, from 2 up to 6 pixels a frame.
  local crank = playdate.getCrankPosition()
  local speed = 2 + (crank / 360) * 4
  if math.abs(crank - lastCrank) > 0.5 then
    crankUsed = true
  end
  lastCrank = crank

  local goalX, goalY = player:getPosition()
  if playdate.buttonIsPressed(playdate.kButtonLeft) then goalX = goalX - speed end
  if playdate.buttonIsPressed(playdate.kButtonRight) then goalX = goalX + speed end
  if playdate.buttonIsPressed(playdate.kButtonUp) then goalY = goalY - speed end
  if playdate.buttonIsPressed(playdate.kButtonDown) then goalY = goalY + speed end

  -- moveWithCollisions hands back where the sprite ended up, which is not
  -- always where you asked, plus a list of everything it touched on the way.
  local actualX, actualY, collisions, count = player:moveWithCollisions(goalX, goalY)

  for i = 1, count do
    if collisions[i].other:getTag() == TAG_PRIZE then
      score = score + 1
      beep:playNote(660, 0.4, 0.08)
      movePrize()
      if score > best then
        best = score
        playdate.datastore.write({ best = best }, "sprite-demo")
      end
    end
  end

  -- Update every sprite, then draw them all in z order.
  gfx.sprite.update()

  gfx.drawText("Score " .. score, 14, 14)
  gfx.drawText("Best " .. best, 300, 14)

  if not titleDrop:ended() then
    gfx.drawText("sprite demo", 150, titleDrop:currentValue())
  end

  -- Ask for the crank until it has been turned.
  if not crankUsed then
    playdate.ui.crankIndicator:update()
  end
end

movePrize()

