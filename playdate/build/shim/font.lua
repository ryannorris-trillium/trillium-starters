-- Playdate .fnt fonts.
--
-- A Playdate font is two files: an image with every glyph in a grid, named
-- `name-table-14-14.png` for a 14 by 14 cell, and a plain text `name.fnt`
-- listing the glyphs in the order they appear in that grid together with how
-- far the pen moves after each one:
--
--   tracking=1
--   space  14
--   !      6
--   "      9
--
-- A line with two characters and a number is a kerning pair, a nudge applied
-- when those two letters meet.
--
-- Playbit hands the .fnt straight to Love, which reads a different format
-- entirely and answers "Invalid font file". Its build script can convert one
-- to the other, but only for fonts carrying two extra keys Playbit invented,
-- which no font from the SDK has. So the browser build copies .fnt files
-- across untouched and this reads the real format, at run time, where the
-- size of the image can simply be asked for.
--
-- Glyphs are drawn as pieces of the image, one per character, which is what
-- the hardware does: the image draw mode applies, so setImageDrawMode with
-- fillWhite gives white text in the usual way.

local warn = require("shim.warn")
local compat = require("shim.compat")

local gfx = playdate.graphics
local pbg = playbit.graphics

local module = {}

local capsMeta = {}
capsMeta.__index = capsMeta

-- Reading the file ------------------------------------------------------------

-- Lua 5.1 has no utf8 library, and a .fnt names its glyphs as characters, so
-- a line has to be measured in characters rather than bytes: one character is
-- a glyph, two are a kerning pair.
local function codepoints(text)
  local out = {}
  local i = 1
  local n = #text
  while i <= n do
    local b = string.byte(text, i)
    local value, length
    if b < 0x80 then
      value, length = b, 1
    elseif b < 0xC0 then
      -- A stray continuation byte. Take it as it is rather than guessing.
      value, length = b, 1
    elseif b < 0xE0 then
      value, length = b - 0xC0, 2
    elseif b < 0xF0 then
      value, length = b - 0xE0, 3
    else
      value, length = b - 0xF0, 4
    end
    for k = 1, length - 1 do
      local continuation = string.byte(text, i + k)
      if not continuation then
        break
      end
      value = value * 64 + (continuation - 0x80)
    end
    out[#out + 1] = value
    i = i + length
  end
  return out
end

module.codepoints = codepoints

-- Pulls a .fnt apart. Returns the tracking, the glyphs in file order (each
-- with its character and its width), and the kerning pairs.
function module.parse(text)
  local font = { tracking = 0, glyphs = {}, kerning = {} }

  for line in string.gmatch(text .. "\n", "(.-)\r?\n") do
    local tracking = string.match(line, "^tracking%s*=%s*(%-?%d+)")
    if tracking then
      font.tracking = tonumber(tracking)
    elseif string.sub(line, 1, 2) == "--" then
      -- A comment, or Playbit's own playbit_width and playbit_height keys.
    elseif string.match(line, "^playbit_") then
      -- Playbit adds these because its converter cannot measure a png.
    else
      local name, width = string.match(line, "^(%S+)%s+(%-?%d+)%s*$")
      if name then
        width = tonumber(width)
        if name == "space" then
          font.glyphs[#font.glyphs + 1] = { code = 32, width = width }
        else
          local codes = codepoints(name)
          if #codes == 1 then
            font.glyphs[#font.glyphs + 1] = { code = codes[1], width = width }
          elseif #codes == 2 then
            font.kerning[codes[1] .. ":" .. codes[2]] = width
          end
        end
      end
    end
  end

  return font
end

-- `Score/Roobert-24-Medium-Numerals` has to find
-- `Score/Roobert-24-Medium-Numerals-table-36-36.png` without knowing the cell
-- size, so the folder is listed and the name matched.
function module.findAtlas(path)
  local folder, name = string.match(path, "^(.*)/([^/]+)$")
  if not folder then
    folder, name = "", path
  end
  local items = love.filesystem.getDirectoryItems(folder)
  local pattern = "^" .. string.gsub(name, "([^%w])", "%%%1") ..
    "%-table%-(%d+)%-(%d+)%.png$"
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

-- Building one ------------------------------------------------------------------

-- Playbit's love.draw sets the Love font every frame from font.data, so a font
-- object has to carry something Love accepts even though none of the drawing
-- here goes through it. One shared placeholder is enough.
local placeholder = nil

local function placeholderFont()
  if not placeholder then
    placeholder = love.graphics.newFont(8)
  end
  return placeholder
end

function module.newCapsFont(path)
  local text, size = love.filesystem.read(path .. ".fnt")
  if not text or size == 0 then
    return nil, "no .fnt file at " .. path .. ".fnt"
  end

  local atlasPath, cellWidth, cellHeight = module.findAtlas(path)
  if not atlasPath then
    return nil, "found " .. path .. ".fnt but no " .. path .. "-table-W-H.png beside it"
  end

  local parsed = module.parse(text)
  local image = love.graphics.newImage(atlasPath)
  local columns = math.floor(image:getWidth() / cellWidth)
  if columns < 1 then
    columns = 1
  end

  local font = setmetatable({}, capsMeta)
  font.data = placeholderFont()
  font.image = image
  font.cellWidth = cellWidth
  font.cellHeight = cellHeight
  font.tracking = parsed.tracking
  font.kerning = parsed.kerning
  font.leading = 0
  font.glyphs = {}

  for i = 1, #parsed.glyphs do
    local glyph = parsed.glyphs[i]
    local cell = i - 1
    font.glyphs[glyph.code] = {
      width = glyph.width,
      quad = love.graphics.newQuad(
        (cell % columns) * cellWidth,
        math.floor(cell / columns) * cellHeight,
        cellWidth, cellHeight,
        image:getWidth(), image:getHeight()),
    }
  end

  return font
end

-- Measuring and drawing ------------------------------------------------------------

function capsMeta:getHeight()
  return self.cellHeight
end

function capsMeta:getLeading()
  return self.leading
end

function capsMeta:setLeading(pixels)
  self.leading = pixels or 0
end

function capsMeta:setTracking(pixels)
  self.tracking = pixels or 0
end

function capsMeta:getTracking()
  return self.tracking
end

function capsMeta:getGlyph(character)
  local codes = codepoints(character)
  local glyph = self.glyphs[codes[1]]
  if not glyph then
    return nil
  end
  return glyph.width
end

-- One line's width, in pixels.
function capsMeta:_lineWidth(codes)
  local width = 0
  for i = 1, #codes do
    local glyph = self.glyphs[codes[i]]
    if glyph then
      width = width + glyph.width + self.tracking
      local pair = self.kerning[codes[i] .. ":" .. (codes[i + 1] or 0)]
      if pair then
        width = width + pair
      end
    end
  end
  return width
end

function capsMeta:getTextWidth(text)
  local widest = 0
  for line in string.gmatch(tostring(text) .. "\n", "(.-)\n") do
    local width = self:_lineWidth(codepoints(line))
    if width > widest then
      widest = width
    end
  end
  return widest
end

function capsMeta:_drawLine(codes, x, y)
  local r, g, b = love.graphics.getColor()
  love.graphics.setColor(1, 1, 1, 1)
  for i = 1, #codes do
    local glyph = self.glyphs[codes[i]]
    if glyph then
      love.graphics.draw(self.image, glyph.quad, x, y)
      x = x + glyph.width + self.tracking
      local pair = self.kerning[codes[i] .. ":" .. (codes[i + 1] or 0)]
      if pair then
        x = x + pair
      end
    end
  end
  love.graphics.setColor(r, g, b, 1)
  pbg.updateContext()
end

function capsMeta:drawText(text, x, y)
  local lineHeight = self.cellHeight + self.leading
  local lines = 0
  local widest = 0
  for line in string.gmatch(tostring(text) .. "\n", "(.-)\n") do
    local codes = codepoints(line)
    self:_drawLine(codes, x, y + lines * lineHeight)
    local width = self:_lineWidth(codes)
    if width > widest then
      widest = width
    end
    lines = lines + 1
  end
  return widest, lines * lineHeight
end

-- 0 left, 1 right, 2 centre, the same numbers the SDK uses.
function capsMeta:drawTextAligned(text, x, y, alignment, leadingAdjustment)
  local lineHeight = self.cellHeight + self.leading + (leadingAdjustment or 0)
  local lines = 0
  for line in string.gmatch(tostring(text) .. "\n", "(.-)\n") do
    local codes = codepoints(line)
    local width = self:_lineWidth(codes)
    local left = x
    if alignment == 1 then
      left = x - width
    elseif alignment == 2 then
      left = x - width * 0.5
    end
    self:_drawLine(codes, left, y + lines * lineHeight)
    lines = lines + 1
  end
end

-- Loading --------------------------------------------------------------------------

local playbitFontMeta = gfx.font.__index
local realFontNew = gfx.font.new

-- Playbit's own converted fonts stay on Playbit's path: its wrapping and
-- truncation code is generic, so borrow it rather than writing it twice.
capsMeta._drawTextInRect = playbitFontMeta._drawTextInRect

function gfx.font.new(path)
  path = string.gsub(path, "%.fnt$", "")
  if not compat.fileExists(path .. ".fnt") then
    warn.note("there is no font at " .. path .. ".fnt")
    return nil
  end

  -- A file starting with `info` is the format Love reads, which is what
  -- Playbit's build script turns its own fonts into. Everything else is a
  -- Playdate .fnt.
  local head = love.filesystem.read(path .. ".fnt", 8)
  if head and string.sub(head, 1, 5) == "info " then
    return realFontNew(path)
  end

  local font, message = module.newCapsFont(path)
  if not font then
    warn.note("could not read the font " .. path .. ": " .. message)
    return nil
  end
  return font
end

-- Playbit's setFont hands font.data to Love. A font read here draws its own
-- glyphs and has nothing Love wants, so keep Love out of it.
function gfx.setFont(font, variant)
  if font == nil then
    return
  end
  pbg.activeFont = font
  if font.data then
    love.graphics.setFont(font.data)
  end
end

function gfx.getFont(variant)
  return pbg.activeFont or pbg.fallbackFont
end

function gfx.getSystemFont(variant)
  return pbg.fallbackFont
end

function gfx.setFontTracking(pixels)
  local font = pbg.activeFont or pbg.fallbackFont
  if font and font.setTracking then
    font:setTracking(pixels)
  end
end

-- A family is one font per weight. Nothing here has more than one, so the
-- first path given is used for all of them.
function gfx.font.newFamily(paths)
  warn.note("font families all come out in one weight here")
  local first = nil
  if type(paths) == "table" then
    for _, path in pairs(paths) do
      first = first or path
    end
  else
    first = paths
  end
  if not first then
    return nil
  end
  local font = gfx.font.new(first)
  return { normal = font, bold = font, italic = font }
end

function gfx.setFontFamily(family)
  if type(family) == "table" then
    gfx.setFont(family.normal or family[1])
  end
end

return module
