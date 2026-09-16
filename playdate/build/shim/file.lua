-- playdate.file. Playbit can open, read and write files, but everything that
-- asks a question about a path raises an error. love.filesystem answers all of
-- them, so these are one line each.
--
-- Note where the files go. Reading looks in the game itself first, then in the
-- browser's save area. Writing always goes to the save area, which the browser
-- keeps per site and may clear when the tab is closed.

local warn = require("shim.warn")
local compat = require("shim.compat")

local file = playdate.file

file.kFileRead = 3
file.kFileWrite = 4
file.kFileAppend = 8

function file.exists(path)
  return compat.fileExists(path)
end

function file.isdir(path)
  if not love.filesystem.getInfo then
    return false
  end
  local info = love.filesystem.getInfo(path)
  return info ~= nil and info.type == "directory"
end

function file.mkdir(path)
  return love.filesystem.createDirectory(path)
end

function file.delete(path, recursive)
  if recursive and file.isdir(path) then
    local items = love.filesystem.getDirectoryItems(path)
    for i = 1, #items do
      file.delete(path .. "/" .. items[i], true)
    end
  end
  return love.filesystem.remove(path)
end

function file.listFiles(path, showHidden)
  path = path or ""
  local items = love.filesystem.getDirectoryItems(path)
  local out = {}
  for i = 1, #items do
    local name = items[i]
    if showHidden or string.sub(name, 1, 1) ~= "." then
      local full = path
      if full ~= "" and string.sub(full, -1) ~= "/" then
        full = full .. "/"
      end
      if file.isdir(full .. name) then
        name = name .. "/"
      end
      out[#out + 1] = name
    end
  end
  return out
end

function file.getType(path)
  if file.isdir(path) then
    return "directory"
  end
  if compat.fileExists(path) then
    return "file"
  end
  return nil
end

function file.modtime(path)
  if not love.filesystem.getInfo then
    return nil
  end
  local info = love.filesystem.getInfo(path)
  if not info or not info.modtime then
    return nil
  end
  local date = os.date("*t", info.modtime)
  return {
    year = date.year,
    month = date.month,
    day = date.day,
    hour = date.hour,
    minute = date.min,
    second = date.sec,
  }
end

function file.rename(path, newPath)
  local contents = love.filesystem.read(path)
  if not contents then
    return false
  end
  love.filesystem.write(newPath, contents)
  love.filesystem.remove(path)
  return true
end

warn.fill("playdate.file.", file, { "run" })

return file
