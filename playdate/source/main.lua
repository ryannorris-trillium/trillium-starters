@@"playbit/header.lua"

import("CoreLibs/graphics")

local gfx = playdate.graphics

!if LOVE2D then
-- Browser only. The Playdate screen is 400 x 240, so draw it at double size.
playbit.graphics.setCanvasScale(2)
playbit.graphics.setWindowSize(800, 480)
!end

local player = { x = 200, y = 120, r = 8 }
local target = { x = 300, y = 60, size = 14 }
local score = 0
local speed = 3

-- Send the target somewhere new, keeping it off the edges.
local function moveTarget()
  target.x = math.random(20, 380)
  target.y = math.random(20, 220)
end

-- playdate.update runs once per frame. Everything happens here.
function playdate.update()
  -- Move the player with the d-pad.
  if playdate.buttonIsPressed(playdate.kButtonLeft) then player.x = player.x - speed end
  if playdate.buttonIsPressed(playdate.kButtonRight) then player.x = player.x + speed end
  if playdate.buttonIsPressed(playdate.kButtonUp) then player.y = player.y - speed end
  if playdate.buttonIsPressed(playdate.kButtonDown) then player.y = player.y + speed end

  -- Keep the player on the screen.
  if player.x < player.r then player.x = player.r end
  if player.x > 400 - player.r then player.x = 400 - player.r end
  if player.y < player.r then player.y = player.r end
  if player.y > 240 - player.r then player.y = 240 - player.r end

  -- Touching the target scores a point and moves it.
  local dx = player.x - target.x
  local dy = player.y - target.y
  if math.sqrt(dx * dx + dy * dy) < player.r + target.size / 2 then
    score = score + 1
    moveTarget()
  end

  -- The crank turns a needle. In the browser the crank is the scroll wheel.
  local angle = math.rad(playdate.getCrankPosition())
  local needleX = player.x + math.sin(angle) * 26
  local needleY = player.y - math.cos(angle) * 26

  -- Draw the frame. Clear first, or last frame stays on screen.
  gfx.clear(gfx.kColorWhite)
  gfx.setColor(gfx.kColorBlack)
  gfx.fillCircleAtPoint(player.x, player.y, player.r)
  gfx.drawLine(player.x, player.y, needleX, needleY)
  gfx.fillRect(target.x - target.size / 2, target.y - target.size / 2, target.size, target.size)
  gfx.drawText("Score: " .. score, 6, 6)
end

moveTarget()
