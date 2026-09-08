-- A tiny LÖVE game. Arrow keys move the circle.
local x, y, speed = 320, 200, 240

function love.update(dt)
  if love.keyboard.isDown("left") then x = x - speed * dt end
  if love.keyboard.isDown("right") then x = x + speed * dt end
  if love.keyboard.isDown("up") then y = y - speed * dt end
  if love.keyboard.isDown("down") then y = y + speed * dt end
end

function love.draw()
  love.graphics.clear(0.09, 0.11, 0.14)
  love.graphics.setColor(0.47, 0.78, 0.63)
  love.graphics.circle("fill", x, y, 24)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Arrow keys move the circle", 16, 16)
end
