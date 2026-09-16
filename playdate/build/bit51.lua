-- Browser only. love.js runs plain Lua 5.1, which has no `bit` library
-- (LuaJIT and the real Playdate both have one). Playbit uses bit.lshift and
-- bit.band to expand dither patterns, and build/shim uses bit.bor for sprite
-- collision groups, so this provides those four in plain arithmetic. Prepended
-- to main.lua by dev-web.sh, before anything else runs.
if not bit then
  bit = {}
  function bit.lshift(x, n)
    return math.floor(x * 2 ^ n) % 4294967296
  end
  function bit.rshift(x, n)
    return math.floor(x / 2 ^ n)
  end
  function bit.band(a, b)
    local result, place = 0, 1
    while a > 0 and b > 0 do
      if a % 2 == 1 and b % 2 == 1 then result = result + place end
      a = math.floor(a / 2)
      b = math.floor(b / 2)
      place = place * 2
    end
    return result
  end
  function bit.bor(a, b)
    local result, place = 0, 1
    while a > 0 or b > 0 do
      if a % 2 == 1 or b % 2 == 1 then result = result + place end
      a = math.floor(a / 2)
      b = math.floor(b / 2)
      place = place * 2
    end
    return result
  end
end
