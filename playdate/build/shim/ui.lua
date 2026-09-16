-- playdate.display, playdate.ui.crankIndicator, the system menu, and the
-- json and datastore gaps. None of these exist in Playbit, or they exist as
-- errors.

local warn = require("shim.warn")

local gfx = playdate.graphics
local pbg = playbit.graphics

local module = {}

local SCREEN_WIDTH = 400
local SCREEN_HEIGHT = 240

-- Display -------------------------------------------------------------------

local display = {}
playdate.display = display
package.loaded["playdate.display"] = display

local refreshRate = 30
local inverted = false
local displayScale = 1

function display.getWidth()
  return SCREEN_WIDTH
end

function display.getHeight()
  return SCREEN_HEIGHT
end

function display.getSize()
  return SCREEN_WIDTH, SCREEN_HEIGHT
end

function display.getRect()
  return playdate.geometry.rect.new(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
end

-- The real hardware runs at 30 frames a second. A browser tab runs at 60, so
-- without this a game plays at double speed here and normal speed on the
-- device. shim/post.lua reads this number and skips frames to match. 0 means
-- "as fast as the browser will go", same as the SDK.
function display.setRefreshRate(rate)
  refreshRate = rate
end

function display.getRefreshRate()
  return refreshRate
end

-- Swapping the two colors Playbit paints with is a real inversion, not a stub.
function display.setInverted(flag)
  inverted = flag
  if flag then
    pbg.setColors(pbg.COLOR_BLACK, pbg.COLOR_WHITE)
  else
    pbg.setColors(pbg.COLOR_WHITE, pbg.COLOR_BLACK)
  end
end

function display.getInverted()
  return inverted
end

function display.setOffset(x, y)
  gfx.setDrawOffset(x, y)
end

function display.getOffset()
  return gfx.getDrawOffset()
end

function display.setScale(scale)
  displayScale = scale
  warn.note("display.setScale() is ignored here; the browser always draws at 1x")
end

function display.getScale()
  return displayScale
end

function display.flush() end

warn.fill("playdate.display.", display, {
  "setMosaic", "getMosaic", "setFlipped", "loadImage",
})

-- Crank indicator --------------------------------------------------------------

local crankIndicator = {}
playdate.ui.crankIndicator = crankIndicator

crankIndicator.clockwise = true
crankIndicator.startTime = 0
crankIndicator._running = false

function crankIndicator:start()
  self._running = true
  self.startTime = playdate.getCurrentTimeMilliseconds()
end

function crankIndicator:resetAnimation()
  self.startTime = playdate.getCurrentTimeMilliseconds()
end

function crankIndicator:getBounds()
  return playdate.geometry.rect.new(SCREEN_WIDTH - 96, SCREEN_HEIGHT - 64, 88, 56)
end

-- A bubble with a turning handle and the word "crank". Not the hardware
-- animation, but it says the same thing.
function crankIndicator:draw(xOffset, yOffset)
  xOffset = xOffset or 0
  yOffset = yOffset or 0

  local x = SCREEN_WIDTH - 96 + xOffset
  local y = SCREEN_HEIGHT - 64 + yOffset
  local width = 88
  local height = 56

  local previousMode = gfx.getImageDrawMode()

  gfx.setColor(gfx.kColorWhite)
  gfx.fillRoundRect(x, y, width, height, 6)
  gfx.setColor(gfx.kColorBlack)
  gfx.drawRoundRect(x, y, width, height, 6)

  local cx = x + 24
  local cy = y + 26
  local radius = 14
  gfx.drawCircleAtPoint(cx, cy, radius)

  local elapsed = playdate.getCurrentTimeMilliseconds() - self.startTime
  local turn = (elapsed / 1200) * 2 * math.pi
  if not self.clockwise then
    turn = -turn
  end
  local hx = cx + math.sin(turn) * radius
  local hy = cy - math.cos(turn) * radius
  gfx.drawLine(cx, cy, hx, hy)
  gfx.fillCircleAtPoint(hx, hy, 3)

  gfx.setImageDrawMode(gfx.kDrawModeCopy)
  gfx.drawText("crank", x + 44, y + 19)
  gfx.setImageDrawMode(previousMode)
end

function crankIndicator:update(xOffset, yOffset)
  if not self._running then
    self:start()
  end
  self:draw(xOffset, yOffset)
end

-- System menu ---------------------------------------------------------------------

local menu = {}
local menuItems = {}
local menuOpen = false
local menuSelection = 1

local itemMeta = {}
itemMeta.__index = itemMeta

function itemMeta:getTitle()
  return self.title
end

function itemMeta:setTitle(title)
  self.title = title
end

function itemMeta:getValue()
  return self.value
end

function itemMeta:setValue(value)
  self.value = value
end

function itemMeta:remove()
  menu:removeMenuItem(self)
end

-- What pressing A does, which depends on the kind of item.
function itemMeta:_activate()
  if self.kind == "checkmark" then
    self.value = not self.value
    if self.callback then
      self.callback(self.value)
    end
  elseif self.kind == "options" then
    local index = 1
    for i = 1, #self.options do
      if self.options[i] == self.value then
        index = i
        break
      end
    end
    index = index + 1
    if index > #self.options then
      index = 1
    end
    self.value = self.options[index]
    if self.callback then
      self.callback(self.value)
    end
  else
    if self.callback then
      self.callback()
    end
  end
end

function itemMeta:_displayText()
  if self.kind == "checkmark" then
    if self.value then
      return self.title .. ": on"
    end
    return self.title .. ": off"
  elseif self.kind == "options" then
    return self.title .. ": " .. tostring(self.value)
  end
  return self.title
end

local function addItem(kind, title, value, callback, options)
  local item = setmetatable({}, itemMeta)
  item.kind = kind
  item.title = title
  item.value = value
  item.callback = callback
  item.options = options
  menuItems[#menuItems + 1] = item
  return item
end

function menu:addMenuItem(title, callback)
  return addItem("action", title, nil, callback)
end

function menu:addCheckmarkMenuItem(title, initialValue, callback)
  if type(initialValue) == "function" then
    callback = initialValue
    initialValue = false
  end
  return addItem("checkmark", title, initialValue or false, callback)
end

function menu:addOptionsMenuItem(title, options, initialValue, callback)
  if type(initialValue) == "function" then
    callback = initialValue
    initialValue = options[1]
  end
  return addItem("options", title, initialValue or options[1], callback, options)
end

function menu:removeMenuItem(item)
  for i = 1, #menuItems do
    if menuItems[i] == item then
      table.remove(menuItems, i)
      break
    end
  end
  if menuSelection > #menuItems then
    menuSelection = math.max(1, #menuItems)
  end
end

function menu:removeAllMenuItems()
  menuItems = {}
  menuSelection = 1
end

function menu:getMenuItems()
  return menuItems
end

function playdate.getSystemMenu()
  return menu
end

function playdate.setMenuImage(image, xOffset)
  warn.note("playdate.setMenuImage() is ignored here; the browser menu is text only")
end

module.menu = menu

function module.menuIsOpen()
  return menuOpen
end

-- M opens and closes the menu, up and down move, A chooses, B closes. The game
-- stops while it is open, which is what the hardware does.
function module.menuKey(key)
  if key == "m" then
    menuOpen = not menuOpen
    if menuOpen and #menuItems == 0 then
      print("playdate shim: the menu is empty. Add items with playdate.getSystemMenu()")
    end
    -- The menu is the browser's nearest thing to the hardware pause, so the
    -- game is told the same way.
    if menuOpen then
      require("shim.input").pause()
    else
      require("shim.input").resume()
    end
    return true
  end
  if not menuOpen then
    return false
  end
  if key == "up" then
    menuSelection = menuSelection - 1
    if menuSelection < 1 then
      menuSelection = math.max(1, #menuItems)
    end
  elseif key == "down" then
    menuSelection = menuSelection + 1
    if menuSelection > #menuItems then
      menuSelection = 1
    end
  elseif key == "s" or key == "return" then
    local item = menuItems[menuSelection]
    if item then
      item:_activate()
    end
  elseif key == "a" or key == "escape" then
    menuOpen = false
    require("shim.input").resume()
  end
  return true
end

function module.drawMenu()
  if not menuOpen then
    return
  end

  local x, y = 90, 24
  local width, height = 280, 192
  local previousMode = gfx.getImageDrawMode()

  gfx.setColor(gfx.kColorWhite)
  gfx.fillRect(x, y, width, height)
  gfx.setColor(gfx.kColorBlack)
  gfx.drawRect(x, y, width, height)
  gfx.drawLine(x, y + 26, x + width, y + 26)

  gfx.setImageDrawMode(gfx.kDrawModeCopy)
  gfx.drawText("Menu", x + 10, y + 6)

  if #menuItems == 0 then
    gfx.drawText("no items", x + 10, y + 36)
  end

  for i = 1, #menuItems do
    local rowY = y + 26 + (i - 1) * 22
    if i == menuSelection then
      gfx.setColor(gfx.kColorBlack)
      gfx.fillRect(x + 1, rowY + 2, width - 2, 22)
      gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    else
      gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
    gfx.drawText(menuItems[i]:_displayText(), x + 10, rowY + 6)
  end

  gfx.setImageDrawMode(gfx.kDrawModeCopy)
  gfx.drawText("M closes", x + 10, y + height - 22)
  gfx.setImageDrawMode(previousMode)
end

-- json and datastore ------------------------------------------------------------

local jsonParser = require("json.json")

function json.encode(value)
  return jsonParser.encode(value)
end

function json.encodePretty(value)
  return jsonParser.encode(value)
end

function json.encodeToFile(path, pretty, value)
  if type(pretty) == "table" then
    value = pretty
  end
  love.filesystem.write(path, jsonParser.encode(value))
end

-- Playbit's write refuses prettyPrint rather than ignoring it, which turns a
-- harmless third argument into a crash.
function playdate.datastore.write(value, filename, prettyPrint)
  filename = (filename or "data") .. ".json"
  love.filesystem.write(filename, jsonParser.encode(value))
end

-- Playbit's read asks LOVE for the file and lets a missing one fail; in the
-- browser that failure is logged to the console ("Could not open file ...
-- Does not exist."). A save that is not there yet is normal, so check first.
function playdate.datastore.read(filename)
  filename = (filename or "data") .. ".json"
  if love.filesystem.getInfo and not love.filesystem.getInfo(filename) then
    return nil
  end
  local str = love.filesystem.read(filename)
  if str == nil then return nil end
  return jsonParser.decode(str)
end

-- Saving an image means encoding its pixels, which means reading them back off
-- the graphics card, which WebGL 1 will not do.
warn.fill("playdate.datastore.", playdate.datastore, { "writeImage", "readImage" })

return module
