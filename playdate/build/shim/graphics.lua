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

-- Keeping canvases alive across the first frame ---------------------------------
--
-- A canvas lives only on the graphics card. Love throws every canvas away and
-- makes it again, empty, whenever the window mode is set, because that can
-- rebuild the whole graphics context. In a browser it always does.
--
-- Playbit's header reads the window size once, while it is loading, and then
-- compares it every frame:
--
--   local windowWidth, windowHeight = playbit.graphics.getWindowSize()
--   function love.draw()
--     ... if windowWidth ~= newWindowWidth ... love.window.updateMode(...)
--
-- The game asks for its window size on the line after the header, so that
-- reading is always the stale one, and the first frame always calls
-- updateMode. Anything the game drew into an image while it was loading was
-- wiped before it was ever seen: sprites built from drawn images came out
-- blank, and only artwork made inside a frame survived.
--
-- Nothing here needs that resize. Two changes make it stop:
--   1. Playbit's stored window size starts as the size of the window that
--      conf.lua actually made, instead of Playbit's own 400 by 240 guess.
--   2. A window mode change that asks for the mode the window is already in
--      does nothing, rather than rebuilding the context to no purpose.
-- And a game that really does want a different size gets it immediately, while
-- it is still loading, so the rebuild happens before any image exists.

local canvasesExist = false

local realUpdateMode = love.window.updateMode

function love.window.updateMode(width, height, flags)
  local currentWidth, currentHeight, currentFlags = love.window.getMode()
  local wantsFullscreen = false
  if flags and flags.fullscreen then
    wantsFullscreen = true
  end
  local isFullscreen = false
  if currentFlags and currentFlags.fullscreen then
    isFullscreen = true
  end
  if currentWidth == width and currentHeight == height and isFullscreen == wantsFullscreen then
    return true
  end
  if canvasesExist then
    warn.note("changing the window size empties every image you have drawn into")
  end
  return realUpdateMode(width, height, flags)
end

-- Start from the window conf.lua actually made.
pbg.setWindowSize(love.graphics.getWidth(), love.graphics.getHeight())

local realSetWindowSize = pbg.setWindowSize

function pbg.setWindowSize(width, height)
  realSetWindowSize(width, height)
  -- Resize now rather than on the first frame, so that a game asking for a
  -- different window still gets one, and still gets it before it has drawn
  -- anything into an image.
  local currentWidth, currentHeight, flags = love.window.getMode()
  if currentWidth ~= width or currentHeight ~= height then
    love.window.updateMode(width, height, flags)
  end
end

-- The Playdate screen is 400 by 240, which is a postage stamp on a laptop, so
-- the browser build draws it at double size. This happens while the game is
-- still loading, before any artwork exists, which is the one moment a resize
-- costs nothing. A game that wants some other size sets it for itself.
pbg.setCanvasScale(2)
pbg.setWindowSize(400 * 2, 240 * 2)

-- WebGL 1 does not allow a shader setting to carry a starting value, so
-- dev-web.sh strips the two colours' initialisers out of Playbit's shader.
-- Send them here instead, once, before anything is drawn. Leaving them unsent
-- would paint the whole screen in transparent black; hard-coding them into the
-- shader instead would be simpler, but then display.setInverted, which swaps
-- them, would have nothing to swap.
pbg.setColors(pbg.COLOR_WHITE, pbg.COLOR_BLACK)

-- The screen the game starts on ------------------------------------------------
--
-- Playbit clears the screen once, on its first frame, with
--
--   local c = playbit.graphics.lastClearColor
--   love.graphics.clear(c.r, c.g, c.b, 1)
--
-- but its two colours are lists, `{ r, g, b, a }`, so `c.r` is nil and the
-- clear is always plain black. A game that fills the screen once at the start
-- and then leaves the sprite system to repaint only what moves ends up with
-- its background in one black and every erased rectangle in another, and every
-- sprite drags a visible trail behind it.
--
-- Two fixes. Give the colours r, g, b names as well, so that first clear is a
-- real colour; and let setBackgroundColor choose it, which is the colour the
-- Playdate's own screen starts at.
local function nameChannels(color)
  color.r, color.g, color.b, color.a = color[1], color[2], color[3], color[4]
  return color
end

nameChannels(pbg.COLOR_WHITE)
nameChannels(pbg.COLOR_BLACK)

local realSetBackgroundColor = gfx.setBackgroundColor

function gfx.setBackgroundColor(color)
  realSetBackgroundColor(color)
  pbg.lastClearColor = pbg.backgroundColor
end

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
  canvasesExist = true
end

-- Whatever was the render target before the outermost push. During a frame
-- that is Playbit's screen canvas; while the game is still loading it is
-- nothing at all, and it must go back to nothing, because LOVE refuses to
-- run its event loop while a canvas is left active ("love.event.pump cannot
-- be called while a Canvas is active").
local baseTarget = nil
local baseShader = nil

function gfx.pushContext(image)
  local stack = pbg.contextStack
  if #stack == 0 then
    baseTarget = love.graphics.getCanvas()
    -- Playbit decides black versus white inside its shader, from the pattern
    -- and mode uniforms it sends before every shape. Inside a frame that
    -- shader is already active. While the game is still loading it is not,
    -- and in the browser a uniform sent to an inactive shader is dropped
    -- ("uniform1iv: location is not from the associated program"), so every
    -- shape drawn into an image at load time came out white. Activate it.
    baseShader = love.graphics.getShader()
    love.graphics.setShader(pbg.shader)
  end
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
  -- Back to the innermost image still on the stack, or whatever was the
  -- target before the first push.
  for i = #stack, 1, -1 do
    if stack[i] ~= SCREEN_CONTEXT then
      love.graphics.setCanvas(stack[i]._canvas)
      return
    end
  end
  love.graphics.setCanvas(baseTarget)
  love.graphics.setShader(baseShader)
  baseTarget = nil
  baseShader = nil
end

-- Playbit calls this at the end of every drawing command to copy the canvas
-- back into the image. There is nothing left to copy.
function pbg.updateContext() end

-- Colors -----------------------------------------------------------------------
--
-- Playbit knows black and white and stops there, so gfx.kColorClear and
-- gfx.kColorXOR are both nil. That is worse than missing: SDK code writes
--
--   elseif self.strokeColor == gfx.kColorClear then -- don't draw
--
-- and a stroke colour that was never set is nil too, so the test passes and
-- the shape silently disappears. The numbers are the SDK's own.
gfx.kColorBlack = 0
gfx.kColorWhite = 1
gfx.kColorClear = 2
gfx.kColorXOR = 3

local realSetColor = gfx.setColor

function gfx.setColor(color)
  if color == gfx.kColorClear then
    -- Nothing here can leave a hole in the screen, so clear paints in the
    -- background colour, which looks the same anywhere but inside an image.
    warn.note("the colour 'clear' paints the background colour here, it does not punch a hole")
    return realSetColor(pbg.backgroundColorIndex)
  end
  if color == gfx.kColorXOR then
    warn.once("the colour 'XOR'")
    return realSetColor(gfx.kColorWhite)
  end
  return realSetColor(color)
end

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

-- Shapes written by hand often repeat the first point at the end to close the
-- loop, and Love's polygon outline cannot cope with a segment of zero length:
-- the corner has no direction, so the mitre it builds there shoots off the
-- screen as a long black wedge. Dropping the repeats is enough.
local function withoutRepeats(points)
  local out = { points[1], points[2] }
  for i = 3, #points - 1, 2 do
    local x, y = points[i], points[i + 1]
    if x ~= out[#out - 1] or y ~= out[#out] then
      out[#out + 1] = x
      out[#out + 1] = y
    end
  end
  if #out >= 6 and out[1] == out[#out - 1] and out[2] == out[#out] then
    out[#out] = nil
    out[#out] = nil
  end
  return out
end

-- The Playdate joins the points it is given and stops; it closes the shape
-- only for a polygon that was closed with close(). Drawing the segments one
-- at a time says exactly that, and has no corners to mitre.
function gfx.drawPolygon(...)
  local points = polygonPoints(...)
  if #points < 6 then
    return
  end
  local closed = false
  local first = select(1, ...)
  if type(first) == "table" and first._closed then
    closed = true
  end
  if points[1] == points[#points - 1] and points[2] == points[#points] then
    closed = true
  end
  points = withoutRepeats(points)
  withPattern(function()
    for i = 1, #points - 3, 2 do
      love.graphics.line(points[i], points[i + 1], points[i + 2], points[i + 3])
    end
    if closed and #points >= 6 then
      love.graphics.line(points[#points - 1], points[#points], points[1], points[2])
    end
  end)
end

function gfx.fillPolygon(...)
  local points = withoutRepeats(polygonPoints(...))
  if #points < 6 then
    return
  end
  -- Love triangulates a fill and gives up on a shape that crosses itself.
  -- The Playdate just fills it, so fall back to the outline rather than
  -- stopping the game.
  local ok = pcall(withPattern, love.graphics.polygon, "fill", points)
  if not ok then
    warn.once("filling a polygon that crosses itself")
    gfx.drawPolygon(points)
  end
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

-- Do the solid parts of two images actually touch, or only their rectangles?
-- Both images have to have come from a file: an image drawn into with
-- pushContext lives on the graphics card, and nothing here can read it back.
function gfx.checkAlphaCollision(image1, x1, y1, flip1, image2, x2, y2, flip2)
  if not (module.pixelData(image1) and module.pixelData(image2)) then
    warn.note("checkAlphaCollision() can only read images loaded from a file, so this one counts as a hit")
    return true
  end

  local w1, h1 = image1:getSize()
  local w2, h2 = image2:getSize()
  local left = math.max(x1, x2)
  local top = math.max(y1, y2)
  local right = math.min(x1 + w1, x2 + w2)
  local bottom = math.min(y1 + h1, y2 + h2)

  for y = math.floor(top), math.ceil(bottom) - 1 do
    for x = math.floor(left), math.ceil(right) - 1 do
      if module.isOpaqueAt(image1, x - x1, y - y1, flip1)
        and module.isOpaqueAt(image2, x - x2, y - y2, flip2) then
        return true
      end
    end
  end
  return false
end

warn.fill("playdate.graphics.", gfx, {
  "imageWithText", "getTextSizeForMaxWidth",
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
    local image = realImageNew(path)
    -- Where the pixels came from, so alphaCollision can read them back off
    -- the disk rather than off the graphics card, which is impossible here.
    image._pixelPath = path .. ".png"
    image._pixelX = 0
    image._pixelY = 0
    return image
  end
  return realImageNew(widthOrPath, height, bgcolor)
end

-- Pixel data, read once per file and kept. This is the processor's copy of
-- the image, not the graphics card's, so reading it is allowed.
local pixelCache = {}

function module.pixelData(image)
  if not image or not image._pixelPath then
    return nil
  end
  local data = pixelCache[image._pixelPath]
  if data == nil then
    local ok, loaded = pcall(love.image.newImageData, image._pixelPath)
    data = ok and loaded or false
    pixelCache[image._pixelPath] = data
  end
  if not data then
    return nil
  end
  return data
end

-- Is this pixel of the image solid? x and y count from the image's top left,
-- and flip mirrors them the way the sprite is drawn.
function module.isOpaqueAt(image, x, y, flip)
  local data = module.pixelData(image)
  if not data then
    return nil
  end
  local width, height = image:getSize()
  if flip == gfx.kImageFlippedX or flip == gfx.kImageFlippedXY then
    x = width - 1 - x
  end
  if flip == gfx.kImageFlippedY or flip == gfx.kImageFlippedXY then
    y = height - 1 - y
  end
  if x < 0 or y < 0 or x >= width or y >= height then
    return false
  end
  local _, _, _, alpha = data:getPixel(x + image._pixelX, y + image._pixelY)
  return alpha > 0
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

-- SDK code reads image.width and image.height as plain properties as often as
-- it calls getSize(). Playbit has only the call.
local imageMethods = imageMeta

imageMeta.__index = function(image, key)
  if key == "width" then
    return image.data and image.data:getWidth() or 0
  end
  if key == "height" then
    return image.data and image.data:getHeight() or 0
  end
  return imageMethods[key]
end

-- Imagetables ----------------------------------------------------------------------

-- Playbit only reads "name-table-W-H.png" atlases. The SDK also accepts a
-- numbered sequence, "name-table-1.png", "name-table-2.png", and so on, which
-- is what you get by exporting frames one at a time.
-- Playbit reads a `name-table-16-16.png` sheet by copying every pixel of
-- every cell one at a time, in Lua. For the sheets a real game ships, a
-- tileset or a font, that is tens of thousands of calls and a visible pause on
-- loading. ImageData:paste does the same copy in one step.
--
-- Each frame also remembers which part of which file it came from, so
-- alphaCollision can look its pixels up later.
local function findSheet(path)
  local folder, name = string.match(path, "^(.*)/([^/]+)$")
  if not folder then
    folder, name = "", path
  end
  local pattern = "^" .. string.gsub(name, "([^%w])", "%%%1") ..
    "%-table%-(%d+)%-(%d+)%.png$"
  local items = love.filesystem.getDirectoryItems(folder)
  for i = 1, #items do
    local width, height = string.match(items[i], pattern)
    if width then
      local full = items[i]
      if folder ~= "" then
        full = folder .. "/" .. full
      end
      return full, tonumber(width), tonumber(height)
    end
  end
  return nil
end

local function loadGrid(path)
  local sheetPath, frameWidth, frameHeight = findSheet(path)
  if not sheetPath or frameWidth < 1 or frameHeight < 1 then
    return nil
  end

  local sheet = love.image.newImageData(sheetPath)
  local columns = math.floor(sheet:getWidth() / frameWidth)
  local rows = math.floor(sheet:getHeight() / frameHeight)

  local images = {}
  for row = 0, rows - 1 do
    for column = 0, columns - 1 do
      local cellX = column * frameWidth
      local cellY = row * frameHeight
      local data = love.image.newImageData(frameWidth, frameHeight)
      data:paste(sheet, 0, 0, cellX, cellY, frameWidth, frameHeight)
      local frame = gfx.image.new(frameWidth, frameHeight)
      frame.data:replacePixels(data)
      frame._pixelPath = sheetPath
      frame._pixelX = cellX
      frame._pixelY = cellY
      images[#images + 1] = frame
    end
  end

  local it = setmetatable({}, imagetableMeta)
  it._images = images
  it.length = #images
  it._rows = rows
  it._columns = columns
  it._width = sheet:getWidth()
  it._height = sheet:getHeight()
  it._frameWidth = frameWidth
  it._frameHeight = frameHeight
  return it
end

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

  local it = loadGrid(path)
  if it then
    return it
  end
  error("playdate shim: could not load imagetable '" .. path ..
    "'. Expected " .. path .. "-table-16-16.png or " .. path .. "-table-1.png", 2)
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
