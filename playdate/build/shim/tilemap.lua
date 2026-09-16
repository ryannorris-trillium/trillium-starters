-- playdate.graphics.tilemap.
--
-- A tilemap is a grid of numbers, each one an index into an imagetable, and a
-- draw call that paints the lot in one go. It is how a level with thousands of
-- blocks in it costs almost nothing to draw.
--
-- Playbit has the shape of the class but not much else: draw asserts,
-- getCollisionRects and getTiles raise errors, setSize throws the grid away,
-- and setTileAtPosition indexes the grid with x times y, so setting the tile
-- at (2, 3) and the tile at (3, 2) both write to slot 6. Between them that
-- leaves tilemaps unusable, which is what the coverage notes used to say.

local gfx = playdate.graphics
local pbg = playbit.graphics

local module = {}

local tilemap = gfx.tilemap
local meta = tilemap.__index

-- The grid ---------------------------------------------------------------------

-- Row major, one based, the same order the SDK uses: the tile at column x and
-- row y is at (y - 1) * width + x.
local function indexOf(map, x, y)
  if x < 1 or y < 1 or x > map._width or y > map._height then
    return nil
  end
  return (y - 1) * map._width + x
end

function meta:setSize(width, height)
  local old = self._tiles or {}
  local oldWidth = self._width or 0

  self._width = width
  self._height = height
  self._length = width * height

  -- Keep whatever was already set, where it still fits, and fill the rest
  -- with 0, which is the empty tile. Playbit emptied the grid here, so a
  -- game that sets the size and then fills it in found every write ignored.
  local tiles = {}
  for y = 1, height do
    for x = 1, width do
      local value = 0
      if oldWidth > 0 and x <= oldWidth then
        value = old[(y - 1) * oldWidth + x] or 0
      end
      tiles[(y - 1) * width + x] = value
    end
  end
  self._tiles = tiles
end

function meta:setTileAtPosition(x, y, index)
  local at = indexOf(self, x, y)
  if not at then
    return
  end
  self._tiles[at] = index
end

function meta:getTileAtPosition(x, y)
  local at = indexOf(self, x, y)
  if not at then
    return nil
  end
  return self._tiles[at]
end

function meta:setTiles(data, width)
  self._width = width
  self._height = math.floor(#data / width)
  self._length = width * self._height
  local tiles = {}
  for i = 1, #data do
    tiles[i] = data[i]
  end
  self._tiles = tiles
end

function meta:getTiles()
  local out = {}
  for i = 1, self._length do
    out[i] = self._tiles[i] or 0
  end
  return out, self._width
end

function meta:getSize()
  return self._width, self._height
end

function meta:getTileSize()
  if not self._imagetable then
    return 0, 0
  end
  return self._imagetable._frameWidth, self._imagetable._frameHeight
end

function meta:getPixelSize()
  local tileWidth, tileHeight = self:getTileSize()
  return self._width * tileWidth, self._height * tileHeight
end

-- Drawing -----------------------------------------------------------------------

-- sourceRect, when given, is the part of the map worth drawing, in pixels.
-- Skipping everything outside it is the whole point of a tilemap on a machine
-- this small, so it is worth honouring.
local function drawMap(map, x, y, sourceRect)
  local sheet = map._imagetable
  if not sheet then
    return
  end

  local tileWidth = sheet._frameWidth
  local tileHeight = sheet._frameHeight
  if not tileWidth or tileWidth < 1 or tileHeight < 1 then
    return
  end

  local firstColumn, lastColumn = 1, map._width
  local firstRow, lastRow = 1, map._height

  if sourceRect then
    firstColumn = math.max(1, math.floor(sourceRect.x / tileWidth) + 1)
    lastColumn = math.min(map._width,
      math.ceil((sourceRect.x + sourceRect.width) / tileWidth))
    firstRow = math.max(1, math.floor(sourceRect.y / tileHeight) + 1)
    lastRow = math.min(map._height,
      math.ceil((sourceRect.y + sourceRect.height) / tileHeight))
  end

  local images = sheet._images
  local count = #images
  local tiles = map._tiles

  -- Images draw at full brightness, like everything else Playbit draws.
  local r, g, b = love.graphics.getColor()
  love.graphics.setColor(1, 1, 1, 1)

  for row = firstRow, lastRow do
    local rowStart = (row - 1) * map._width
    local top = y + (row - 1) * tileHeight
    for column = firstColumn, lastColumn do
      local tile = tiles[rowStart + column]
      if tile and tile > 0 and tile <= count then
        love.graphics.draw(images[tile].data, x + (column - 1) * tileWidth, top)
      end
    end
  end

  love.graphics.setColor(r, g, b, 1)
  pbg.updateContext()
end

function meta:draw(x, y, sourceRect)
  if type(x) == "table" then
    -- draw(point, sourceRect)
    x, y, sourceRect = x.x, x.y, y
  end
  drawMap(self, x or 0, y or 0, sourceRect)
end

-- Same picture, ignoring the drawing offset the camera has set.
function meta:drawIgnoringOffset(x, y, sourceRect)
  local offsetX, offsetY = pbg.drawOffset.x, pbg.drawOffset.y
  love.graphics.push()
  love.graphics.translate(-offsetX, -offsetY)
  self:draw(x, y, sourceRect)
  love.graphics.pop()
end

-- Collision -----------------------------------------------------------------------

-- The solid tiles, grouped into as few rectangles as will cover them: take the
-- longest run of solid tiles to the right, then push it down as far as every
-- tile below it is solid too. A level made of long floors comes out as a
-- handful of rectangles instead of a thousand.
--
-- The rects are in tile coordinates, one based, the same as
-- setTileAtPosition. addWallSprites below turns them into pixels.
function meta:getCollisionRects(emptyIDs)
  local empty = {}
  if type(emptyIDs) == "table" then
    for i = 1, #emptyIDs do
      empty[emptyIDs[i]] = true
    end
  end

  local width, height = self._width, self._height
  local tiles = self._tiles
  local taken = {}

  local function solid(x, y)
    local index = (y - 1) * width + x
    if taken[index] then
      return false
    end
    local tile = tiles[index]
    return tile ~= nil and tile > 0 and not empty[tile]
  end

  local rects = {}
  for y = 1, height do
    local x = 1
    while x <= width do
      if solid(x, y) then
        local runWidth = 0
        while x + runWidth <= width and solid(x + runWidth, y) do
          runWidth = runWidth + 1
        end

        local runHeight = 1
        local growing = true
        while growing and y + runHeight <= height do
          for column = x, x + runWidth - 1 do
            if not solid(column, y + runHeight) then
              growing = false
              break
            end
          end
          if growing then
            runHeight = runHeight + 1
          end
        end

        for row = y, y + runHeight - 1 do
          for column = x, x + runWidth - 1 do
            taken[(row - 1) * width + column] = true
          end
        end

        rects[#rects + 1] = playdate.geometry.rect.new(x, y, runWidth, runHeight)
        x = x + runWidth
      else
        x = x + 1
      end
    end
  end

  return rects
end

-- Sprites ----------------------------------------------------------------------------

-- One invisible collision sprite per rectangle of solid tiles. This is how a
-- level's floors and pipes become something the player can stand on without
-- one sprite per block.
function gfx.sprite.addWallSprites(map, emptyIDs, xOffset, yOffset)
  xOffset = xOffset or 0
  yOffset = yOffset or 0
  local tileWidth, tileHeight = map:getTileSize()
  local rects = map:getCollisionRects(emptyIDs)
  local sprites = {}
  for i = 1, #rects do
    local r = rects[i]
    sprites[i] = gfx.sprite.addEmptyCollisionSprite(
      (r.x - 1) * tileWidth + xOffset,
      (r.y - 1) * tileHeight + yOffset,
      r.width * tileWidth,
      r.height * tileHeight)
  end
  return sprites
end

-- A sprite that draws a tilemap. Its size is the map's; shim/sprite.lua draws
-- it, because that is where the display list is.
function gfx.sprite:setTilemap(map)
  self.tilemap = map
  if map then
    local width, height = map:getPixelSize()
    self:setSize(width, height)
  end
end

function gfx.sprite:getTilemap()
  return self.tilemap
end

return module
