-- playdate.graphics gaps: drawing primitives, clipping, dithering, and the
-- image and imagetable methods Playbit leaves as errors.

local warn = require("shim.warn")
local compat = require("shim.compat")

local gfx = playdate.graphics
local pbg = playbit.graphics

local module = {}

-- Every Playbit primitive follows the same dance: switch the shader to the
-- pattern mode, draw, then put the image draw mode back. Anything new has to
-- do it too or the shape comes out the wrong color.
local function withPattern(fn, ...)
  pbg.shader:send("mode", 8)
  fn(...)
  pbg.updateContext()
  gfx.setImageDrawMode(pbg.drawMode)
end

-- Drawing into an image --------------------------------------------------------
--
-- pushContext points the drawing commands at an image instead of the screen.
-- Playbit does that by drawing into a canvas and then, after every single
-- drawing call, reading the canvas back off the graphics card into an
-- ImageData and copying it into the image's texture.
--
-- Reading pixels back off the card is the one thing WebGL 1 will not do here.
-- In the browser it fails with
--
--   GL_INVALID_OPERATION: glReadPixelsRobustANGLE: Invalid format and type
--   combination
--
-- followed by Love's "Pixel formats must match", and the game dies at the
-- first image it draws into. That is every sprite built from a drawn image.
--
-- The fix is to never read back. A canvas is drawable everywhere a texture is,
-- so once an image has been drawn into, the canvas simply becomes the image.
-- Nothing has to be copied anywhere.

-- Marker for pushContext() with no image, which saves state without changing
-- where the drawing goes.
local SCREEN_CONTEXT = {}

-- Turn an image into its canvas, once, keeping whatever it held before.
local function promoteToCanvas(image)
  if image._canvas then
    return
  end

  local width, height = image:getSize()
  local canvas = love.graphics.newCanvas(width, height)

  local previousTarget = love.graphics.getCanvas()
  local previousShader = love.graphics.getShader()
  local scissorX, scissorY, scissorWidth, scissorHeight = love.graphics.getScissor()
  local r, g, b, a = love.graphics.getColor()

  love.graphics.setCanvas(canvas)
  love.graphics.setScissor()
  -- No shader and no transform: copy the old pixels across exactly as they
  -- were, wherever this was called from.
  love.graphics.setShader()
  love.graphics.push()
  love.graphics.origin()
  love.graphics.setColor(1, 1, 1, 1)
  if image.data then
    love.graphics.draw(image.data, 0, 0)
  end
  love.graphics.pop()

  love.graphics.setColor(r, g, b, a)
  love.graphics.setShader(previousShader)
  love.graphics.setScissor(scissorX, scissorY, scissorWidth, scissorHeight)
  love.graphics.setCanvas(previousTarget)

  image._canvas = canvas
  image.data = canvas
end

function gfx.pushContext(image)
  local stack = pbg.contextStack
  if image == nil then
    stack[#stack + 1] = SCREEN_CONTEXT
    return
  end
  promoteToCanvas(image)
  stack[#stack + 1] = image
  love.graphics.setCanvas(image._canvas)
end

function gfx.popContext()
  local stack = pbg.contextStack
  if #stack == 0 then
    warn.note("popContext() was called with nothing pushed")
    return
  end
  table.remove(stack)
  -- Back to the innermost image still on the stack, or the screen.
  for i = #stack, 1, -1 do
    if stack[i] ~= SCREEN_CONTEXT then
      love.graphics.setCanvas(stack[i]._canvas)
      return
    end
  end
  love.graphics.setCanvas(pbg.canvas)
end

-- Playbit calls this at the end of every drawing command to copy the canvas
-- back into the image. There is nothing left to copy.
function pbg.updateContext() end

-- Draw modes ------------------------------------------------------------------

-- Playbit's setImageDrawMode raises an error for the three modes its shader
-- does not implement. Warn and fall back to copy instead.
local realSetImageDrawMode = gfx.setImageDrawMode
local unsupportedModes = {
  [gfx.kDrawModeXOR] = "XOR",
  [gfx.kDrawModeNXOR] = "NXOR",
  [gfx.kDrawModeBlackTransparent] = "blackTransparent",
  XOR = "XOR",
  NXOR = "NXOR",
  blackTransparent = "blackTransparent",
}

function gfx.setImageDrawMode(mode)
  local bad = unsupportedModes[mode]
  if bad then
    warn.once("image draw mode '" .. bad .. "'")
    pbg.drawMode = mode
    pbg.shader:send("mode", 0)
    return
  end
  realSetImageDrawMode(mode)
end

function gfx.getImageDrawMode()
  return pbg.drawMode
end

-- Shapes ----------------------------------------------------------------------

-- Love rounds corners a little differently from the Playdate, so a round rect
-- here is close but not pixel identical to hardware.
function gfx.drawRoundRect(x, y, width, height, radius)
  if type(x) == "table" then
    x, y, width, height, radius = x.x, x.y, x.width, x.height, y
  end
  withPattern(love.graphics.rectangle, "line", x, y, width, height, radius, radius)
end

function gfx.fillRoundRect(x, y, width, height, radius)
  if type(x) == "table" then
    x, y, width, height, radius = x.x, x.y, x.width, x.height, y
  end
  withPattern(love.graphics.rectangle, "fill", x, y, width, height, radius, radius)
end

function gfx.drawTriangle(x1, y1, x2, y2, x3, y3)
  withPattern(love.graphics.polygon, "line", x1, y1, x2, y2, x3, y3)
end

function gfx.fillTriangle(x1, y1, x2, y2, x3, y3)
  withPattern(love.graphics.polygon, "fill", x1, y1, x2, y2, x3, y3)
end

-- Accepts a playdate.geometry.polygon or a flat list of coordinates.
local function polygonPoints(...)
  local first = select(1, ...)
  if type(first) == "table" then
    if first._points then
      return first._points
    end
    return first
  end
  return { ... }
end

function gfx.drawPolygon(...)
  local points = polygonPoints(...)
  if #points < 6 then
    return
  end
  withPattern(love.graphics.polygon, "line", points)
end

function gfx.fillPolygon(...)
  local points = polygonPoints(...)
  if #points < 6 then
    return
  end
  withPattern(love.graphics.polygon, "fill", points)
end

function gfx.drawEllipseInRect(x, y, width, height)
  withPattern(love.graphics.ellipse, "line", x + width * 0.5, y + height * 0.5, width * 0.5, height * 0.5)
end

function gfx.fillEllipseInRect(x, y, width, height)
  withPattern(love.graphics.ellipse, "fill", x + width * 0.5, y + height * 0.5, width * 0.5, height * 0.5)
end

function gfx.drawCircleInRect(x, y, width, height)
  local r = math.min(width, height) * 0.5
  gfx.drawCircleAtPoint(x + width * 0.5, y + height * 0.5, r)
end

function gfx.fillCircleInRect(x, y, width, height)
  local r = math.min(width, height) * 0.5
  gfx.fillCircleAtPoint(x + width * 0.5, y + height * 0.5, r)
end

-- Clipping ---------------------------------------------------------------------

local clipRect = nil

function gfx.setClipRect(x, y, width, height)
  if type(x) == "table" then
    x, y, width, height = x.x, x.y, x.width, x.height
  end
  clipRect = { x = x, y = y, width = width, height = height }
  -- The scissor is in canvas pixels, so it has to include the draw offset.
  love.graphics.setScissor(x + pbg.drawOffset.x, y + pbg.drawOffset.y, width, height)
end

function gfx.getClipRect()
  if not clipRect then
    return 0, 0, 400, 240
  end
  return clipRect.x, clipRect.y, clipRect.width, clipRect.height
end

function gfx.clearClipRect()
  clipRect = nil
  love.graphics.setScissor()
end

gfx.setScreenClipRect = gfx.setClipRect
gfx.clearScreenClipRect = gfx.clearClipRect
gfx.getScreenClipRect = gfx.getClipRect

-- Strokes and dithering ----------------------------------------------------------

gfx.kStrokeCentered = 0
gfx.kStrokeOutside = 1
gfx.kStrokeInside = 2

local strokeLocation = gfx.kStrokeCentered

function gfx.setStrokeLocation(location)
  strokeLocation = location
  if location ~= gfx.kStrokeCentered then
    warn.note("setStrokeLocation() is ignored here; lines are always centered on the path")
  end
end

function gfx.getStrokeLocation()
  return strokeLocation
end

gfx.kLineCapStyleButt = 0
gfx.kLineCapStyleSquare = 1
gfx.kLineCapStyleRound = 2

function gfx.setLineCapStyle() end

gfx.image.kDitherTypeNone = 0
gfx.image.kDitherTypeDiagonalLine = 1
gfx.image.kDitherTypeVerticalLine = 2
gfx.image.kDitherTypeHorizontalLine = 3
gfx.image.kDitherTypeScreen = 4
gfx.image.kDitherTypeBayer2x2 = 5
gfx.image.kDitherTypeBayer4x4 = 6
gfx.image.kDitherTypeBayer8x8 = 7
gfx.image.kDitherTypeFloydSteinberg = 8
gfx.image.kDitherTypeBurkes = 9
gfx.image.kDitherTypeAtkinson = 10

-- Standard 8x8 ordered dither matrix, values 0 to 63.
local bayer8 = {
  { 0, 32, 8, 40, 2, 34, 10, 42 },
  { 48, 16, 56, 24, 50, 18, 58, 26 },
  { 12, 44, 4, 36, 14, 46, 6, 38 },
  { 60, 28, 52, 20, 62, 30, 54, 22 },
  { 3, 35, 11, 43, 1, 33, 9, 41 },
  { 51, 19, 59, 27, 49, 17, 57, 25 },
  { 15, 47, 7, 39, 13, 45, 5, 37 },
  { 63, 31, 55, 23, 61, 29, 53, 21 },
}

-- On hardware the off pixels of a dither are see-through. Here they are
-- painted in the other color, because Playbit's pattern shader has no
-- transparent case. A 50% dither over a white background looks right; over
-- artwork it does not.
function gfx.setDitherPattern(alpha, ditherType)
  warn.note("setDitherPattern() paints the off pixels white here, it does not let the background through")
  local threshold = (1 - alpha) * 64
  local rows = {}
  for y = 1, 8 do
    local byte = 0
    for x = 1, 8 do
      if bayer8[y][x] < threshold then
        byte = byte + math.floor(2 ^ (8 - x))
      end
    end
    rows[y] = byte
  end
  if pbg.drawColorIndex == 1 then
    -- Drawing in white: invert, since 1 bits paint black.
    for y = 1, 8 do
      rows[y] = 255 - rows[y]
    end
  end
  gfx.setPattern(rows)
end

-- Focus is the same idea as a context, under the older SDK name.
gfx.lockFocus = gfx.pushContext
gfx.unlockFocus = gfx.popContext

warn.fill("playdate.graphics.", gfx, {
  "checkAlphaCollision", "imageWithText", "getTextSizeForMaxWidth",
  "drawLocalizedText", "getLocalizedText", "drawLocalizedTextAligned",
  "drawLocalizedTextInRect", "perlin", "perlinArray",
})

-- Images -------------------------------------------------------------------------

-- Playbit writes its instance metatable to module.__index, so this is the
-- table every image's methods actually live on.
local imageMeta = gfx.image.__index
local imagetableMeta = gfx.imagetable.__index

-- Playbit appends ".png" to every path, so a path that already ends in .png
-- turns into "thing.png.png" and the load fails with a Love error that says
-- nothing useful. Strip it, and check the file is there first.
local realImageNew = gfx.image.new

function gfx.image.new(widthOrPath, height, bgcolor)
  if type(widthOrPath) == "string" then
    local path = string.gsub(widthOrPath, "%.png$", "")
    if not compat.fileExists(path .. ".png") then
      error("playdate shim: no image file at " .. path .. ".png", 2)
    end
    return realImageNew(path)
  end
  return realImageNew(widthOrPath, height, bgcolor)
end

function imageMeta:copy()
  local w, h = self:getSize()
  local out = gfx.image.new(w, h)
  gfx.pushContext(out)
  self:draw(0, 0)
  gfx.popContext()
  return out
end

function imageMeta:clear(color)
  gfx.pushContext(self)
  gfx.clear(color)
  gfx.popContext()
end

function imageMeta:drawCentered(x, y, flip)
  local w, h = self:getSize()
  self:draw(x - w * 0.5, y - h * 0.5, flip)
end

function imageMeta:drawAnchored(x, y, ax, ay, flip)
  local w, h = self:getSize()
  self:draw(x - w * ax, y - h * ay, flip)
end

-- Playbit's drawRotated refuses a scale; this one takes it.
local realDrawRotated = imageMeta.drawRotated

function imageMeta:drawRotated(x, y, angle, scale, yscale)
  if not scale then
    return realDrawRotated(self, x, y, angle)
  end
  yscale = yscale or scale
  local r, g, b = love.graphics.getColor()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.push()
  local w = math.floor(self.data:getWidth() * 0.5)
  local h = math.floor(self.data:getHeight() * 0.5)
  love.graphics.translate(x, y)
  love.graphics.rotate(math.rad(angle))
  love.graphics.scale(scale, yscale)
  love.graphics.draw(self.data, -w, -h)
  love.graphics.pop()
  love.graphics.setColor(r, g, b, 1)
  pbg.updateContext()
end

function imageMeta:drawTiled(x, y, width, height, flip)
  local w, h = self:getSize()
  if w < 1 or h < 1 then
    return
  end
  local dy = 0
  while dy < height do
    local dx = 0
    while dx < width do
      self:draw(x + dx, y + dy, flip)
      dx = dx + w
    end
    dy = dy + h
  end
end

function imageMeta:drawFaded(x, y, alpha, ditherType)
  warn.note("image:drawFaded() draws at full strength here")
  self:draw(x, y)
end

function imageMeta:getMaskImage()
  warn.once("image:getMaskImage()")
  return nil
end

function imageMeta:hasMask()
  return false
end

function imageMeta:setMaskImage()
  warn.note("image:setMaskImage() does nothing here; Playbit has no mask support")
end

function imageMeta:addMask()
  warn.once("image:addMask()")
end

function imageMeta:removeMask() end
function imageMeta:clearMask() end

function imageMeta:setInverted(flag)
  warn.once("image:setInverted()")
end

function imageMeta:invertedImage()
  warn.once("image:invertedImage()")
  return self
end

function imageMeta:scaledImage(scale, yscale)
  yscale = yscale or scale
  local w, h = self:getSize()
  local out = gfx.image.new(math.floor(w * scale), math.floor(h * yscale))
  gfx.pushContext(out)
  self:drawScaled(0, 0, scale, yscale)
  gfx.popContext()
  return out
end

function imageMeta:rotatedImage(angle)
  local w, h = self:getSize()
  local size = math.ceil(math.sqrt(w * w + h * h))
  local out = gfx.image.new(size, size)
  gfx.pushContext(out)
  self:drawRotated(size * 0.5, size * 0.5, angle)
  gfx.popContext()
  return out
end

-- Reading one pixel back means reading the graphics card back, which WebGL 1
-- will not do. Nothing here can answer it.
function imageMeta:sample(x, y)
  warn.note("image:sample() cannot read pixels back in the browser, it returns black")
  return gfx.kColorBlack
end

-- Replaces the image's contents from a file. Loading a texture is fine; the
-- old canvas, if there was one, is dropped.
function imageMeta:load(path)
  path = string.gsub(path, "%.png$", "")
  if not compat.fileExists(path .. ".png") then
    warn.note("image:load() found no file at " .. path .. ".png")
    return false
  end
  self.data = love.graphics.newImage(path .. ".png")
  self._canvas = nil
  return true
end

function gfx.image.imageSizeAtPath(path)
  path = string.gsub(path, "%.png$", "")
  if not compat.fileExists(path .. ".png") then
    return nil
  end
  local data = love.image.newImageData(path .. ".png")
  return data:getWidth(), data:getHeight()
end

-- Imagetables ----------------------------------------------------------------------

-- Playbit only reads "name-table-W-H.png" atlases. The SDK also accepts a
-- numbered sequence, "name-table-1.png", "name-table-2.png", and so on, which
-- is what you get by exporting frames one at a time.
local realImagetableNew = gfx.imagetable.new

local function sequenceFrames(path)
  local frames = {}
  local n = 1
  while true do
    local candidate = path .. "-table-" .. n .. ".png"
    if not compat.fileExists(candidate) then
      break
    end
    frames[n] = gfx.image.new(candidate)
    n = n + 1
  end
  return frames
end

function gfx.imagetable.new(path, cellsWide, cellSize)
  if type(path) == "number" then
    -- new(count) makes an empty table you fill with setImage.
    local it = setmetatable({}, imagetableMeta)
    it._images = {}
    it.length = path
    return it
  end

  path = string.gsub(path, "%.png$", "")

  local frames = sequenceFrames(path)
  if #frames > 0 then
    local it = setmetatable({}, imagetableMeta)
    it._images = frames
    it.length = #frames
    it._rows = #frames
    it._columns = 1
    local w, h = frames[1]:getSize()
    it._frameWidth = w
    it._frameHeight = h
    return it
  end

  local ok, result = pcall(realImagetableNew, path, cellsWide, cellSize)
  if not ok then
    error("playdate shim: could not load imagetable '" .. path ..
      "'. Expected " .. path .. "-table-16-16.png or " .. path .. "-table-1.png", 2)
  end
  return result
end

function imagetableMeta:setImage(n, image)
  self._images[n] = image
  if n > self.length then
    self.length = n
  end
end

function imagetableMeta:getLength()
  return self.length
end

function imagetableMeta:drawImage(n, x, y, flip)
  local image = self._images[n]
  if image then
    image:draw(x, y, flip)
  end
end

-- it:getImage(n) is the portable spelling. it[n] also works here, but #it
-- does not: Lua 5.1 ignores __len on tables, and love.js is Lua 5.1.
local metaIndex = imagetableMeta.__index
imagetableMeta.__index = function(t, key)
  if type(key) == "number" then
    return rawget(t, "_images")[key]
  end
  if type(metaIndex) == "function" then
    return metaIndex(t, key)
  end
  return metaIndex[key]
end
imagetableMeta.__len = function(t)
  return t.length
end

module.imageMeta = imageMeta
module.imagetableMeta = imagetableMeta
module.withPattern = withPattern

return module
