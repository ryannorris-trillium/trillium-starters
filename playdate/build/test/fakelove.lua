-- A stand-in for Love2d, enough of it to load Playbit and the shim outside a
-- browser and check what they do. Every call that would draw or make a noise
-- is recorded instead.
--
-- This is a test fixture. It is not shipped in the game.

local fake = {}

local log = {}
fake.log = log

local function record(name, ...)
  log[#log + 1] = { name = name, args = { ... } }
end

fake.record = record

function fake.clearLog()
  for i = #log, 1, -1 do
    log[i] = nil
  end
end

-- A clock the tests can wind forward.
local clock = 0

function fake.setTime(seconds)
  clock = seconds
end

function fake.advance(seconds)
  clock = clock + seconds
end

-- An in-memory disk. Preload files by putting them in here.
local files = {}
fake.files = files

local love = {}

-- graphics -------------------------------------------------------------------

-- The window, and every canvas made against it. Setting the window mode
-- rebuilds the graphics context in a browser, which empties every canvas, so
-- the canvases here remember when that has happened to them.
local mode = { width = 800, height = 480, flags = { fullscreen = false, x = 100, y = 100 } }
local canvases = {}

-- Canvases refuse to be read back, the way WebGL 1 refuses in the browser.
-- Anything that tries fails here with the same message Ryan saw in the tab.
local function newCanvasObject(width, height)
  local canvas = {}
  canvas.isCanvas = true
  canvases[#canvases + 1] = canvas
  canvas.width = width or 400
  canvas.height = height or 240
  record("newCanvas", canvas.width, canvas.height)
  function canvas:getWidth() return self.width end
  function canvas:getHeight() return self.height end
  function canvas:setFilter() end
  function canvas:newImageData()
    record("canvas.newImageData")
    error("Pixel formats must match. (GL_INVALID_OPERATION: " ..
      "glReadPixelsRobustANGLE: Invalid format and type combination)", 2)
  end
  return canvas
end

function fake.newImageData(width, height)
  local data = {}
  data.width = width
  data.height = height
  function data:getWidth() return self.width end
  function data:getHeight() return self.height end
  function data:getPixel() return 0, 0, 0, 1 end
  function data:setPixel() end
  function data:replacePixels() end
  return data
end

local function newImageObject(width, height)
  local image = {}
  image.width = width or 8
  image.height = height or 8
  function image:getWidth() return self.width end
  function image:getHeight() return self.height end
  function image:replacePixels() end
  function image:setFilter() end
  return image
end

local color = { 1, 1, 1, 1 }
local currentCanvas = nil
local currentShader = nil
local currentScissor = nil

love.graphics = {
  newShader = function()
    return { send = function(self, ...) record("shader.send", ...) end }
  end,
  newCanvas = function(w, h) return newCanvasObject(w, h) end,
  newImage = function(source)
    if type(source) == "table" then
      return newImageObject(source.width, source.height)
    end
    local entry = files[source]
    if type(entry) == "table" then
      return newImageObject(entry.width, entry.height)
    end
    return newImageObject(8, 8)
  end,
  newQuad = function()
    return { setViewport = function() end }
  end,
  setDefaultFilter = function() end,
  setLineWidth = function() end,
  getLineWidth = function() return 1 end,
  setLineStyle = function() end,
  setColor = function(r, g, b, a) color = { r, g, b, a } end,
  getColor = function() return color[1], color[2], color[3], color[4] end,
  setFont = function() end,
  setCanvas = function(canvas) currentCanvas = canvas end,
  getCanvas = function() return currentCanvas end,
  setShader = function(shader) currentShader = shader end,
  getShader = function() return currentShader end,
  setScissor = function(...)
    record("setScissor", ...)
    currentScissor = { ... }
  end,
  getScissor = function()
    if not currentScissor or currentScissor[1] == nil then
      return nil
    end
    return currentScissor[1], currentScissor[2], currentScissor[3], currentScissor[4]
  end,
  origin = function() record("origin") end,
  clear = function(...) record("clear", ...) end,
  push = function() record("push") end,
  pop = function() record("pop") end,
  translate = function(x, y) record("translate", x, y) end,
  rotate = function(a) record("rotate", a) end,
  scale = function(x, y) record("scale", x, y) end,
  rectangle = function(...) record("rectangle", ...) end,
  circle = function(...) record("circle", ...) end,
  ellipse = function(...) record("ellipse", ...) end,
  polygon = function(...) record("polygon", ...) end,
  line = function(...) record("line", ...) end,
  points = function(...) record("points", ...) end,
  arc = function(...) record("arc", ...) end,
  draw = function(...) record("draw", ...) end,
  print = function(...) record("print", ...) end,
  getWidth = function() return mode.width end,
  getHeight = function() return mode.height end,
  getDimensions = function() return mode.width, mode.height end,
}

-- image ----------------------------------------------------------------------

love.image = {
  newImageData = function(a, b)
    if type(a) == "string" then
      local entry = files[a]
      if type(entry) == "table" then
        return fake.newImageData(entry.width, entry.height)
      end
      return fake.newImageData(8, 8)
    end
    return fake.newImageData(a, b)
  end,
}

-- audio ----------------------------------------------------------------------

local function newSourceObject(name)
  local source = { name = name, playing = false, volume = 1, pitch = 1, looping = false }
  function source:play() self.playing = true; record("audio.play", self.name) end
  function source:stop() self.playing = false end
  function source:pause() self.playing = false end
  function source:isPlaying() return self.playing end
  function source:setVolume(v) self.volume = v end
  function source:getVolume() return self.volume end
  function source:setPitch(p) self.pitch = p end
  function source:getPitch() return self.pitch end
  function source:setLooping(l) self.looping = l end
  function source:getDuration() return 1 end
  function source:seek() end
  function source:tell() return 0 end
  function source:clone() return newSourceObject(self.name) end
  return source
end

love.audio = {
  newSource = function(source)
    if type(source) == "table" then
      return newSourceObject("sounddata")
    end
    return newSourceObject(source)
  end,
}

love.sound = {
  newSoundData = function(a, rate, bits, channels)
    local data = { count = type(a) == "number" and a or 0, rate = rate or 44100 }
    data.samples = 0
    function data:setSample() self.samples = self.samples + 1 end
    function data:getSample() return 0 end
    function data:getDuration() return self.count / (self.rate or 44100) end
    function data:getSampleRate() return self.rate or 44100 end
    return data
  end,
}

-- filesystem -------------------------------------------------------------------

love.filesystem = {
  read = function(path)
    local entry = files[path]
    if type(entry) == "string" then
      return entry, #entry
    end
    return nil
  end,
  write = function(path, contents)
    files[path] = contents
    return true
  end,
  remove = function(path)
    files[path] = nil
    return true
  end,
  createDirectory = function(path)
    files[path] = { directory = true }
    return true
  end,
  getInfo = function(path)
    if files[path] == nil then
      return nil
    end
    return { type = "file" }
  end,
  getDirectoryItems = function(folder)
    local out = {}
    for path in pairs(files) do
      if folder == "" or folder == "/" then
        if not string.find(path, "/") then
          out[#out + 1] = path
        end
      else
        local prefix = folder .. "/"
        if string.sub(path, 1, #prefix) == prefix then
          out[#out + 1] = string.sub(path, #prefix + 1)
        end
      end
    end
    table.sort(out)
    return out
  end,
}

-- the rest ------------------------------------------------------------------------

love.keyboard = {
  isDown = function() return false end,
}

love.timer = {
  getTime = function() return clock end,
  getFPS = function() return 30 end,
  getDelta = function() return 1 / 30 end,
}

love.window = {
  getMode = function() return mode.width, mode.height, mode.flags end,
  updateMode = function(width, height, flags)
    record("updateMode", width, height)
    mode.width = width
    mode.height = height
    mode.flags = flags or mode.flags
    -- What the browser does: the context is rebuilt and every canvas comes
    -- back blank.
    for i = 1, #canvases do
      canvases[i].wiped = true
    end
    return true
  end,
}

love.math = {
  random = math.random,
}

fake.love = love

function fake.install()
  _G.love = love
  return love
end

return fake
