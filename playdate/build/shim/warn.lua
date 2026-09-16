-- One console line per missing function, the first time it is called.
--
-- The rule for the whole shim: never stop the game for something the browser
-- cannot do. Say why, once, and keep running. A game that limps is easier to
-- debug than a blue screen.

local module = {}

local unpack = unpack or table.unpack

local warned = {}
local order = {}

-- For a function the browser simply does not have.
function module.once(name)
  if warned[name] then
    return
  end
  warned[name] = true
  order[#order + 1] = name
  print("playdate shim: " .. name .. " is not available in the browser")
end

-- For something that does run, but not the way the hardware would, where the
-- explanation is the point.
function module.note(message)
  if warned[message] then
    return
  end
  warned[message] = true
  order[#order + 1] = message
  print("playdate shim: " .. message)
end

-- Returns a function that warns once, then returns the values given here.
function module.stub(name, ...)
  local values = { ... }
  local count = select("#", ...)
  return function()
    module.once(name)
    if count == 0 then
      return nil
    end
    return unpack(values, 1, count)
  end
end

-- Puts a warning stub at every name in the list. Used for the corners of the
-- SDK that have no browser equivalent at all, and for the Playbit functions
-- that raise an error instead of returning.
function module.fill(prefix, target, names)
  for i = 1, #names do
    target[names[i]] = module.stub(prefix .. names[i] .. "()")
  end
end

-- Same, but only where nothing is defined yet.
function module.fillMissing(prefix, target, names)
  for i = 1, #names do
    if target[names[i]] == nil then
      target[names[i]] = module.stub(prefix .. names[i] .. "()")
    end
  end
end

function module.warnedList()
  return order
end

return module
