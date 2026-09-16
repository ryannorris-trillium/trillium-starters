-- Playdate Lua has +=, -=, *= and /=. Plain Lua does not.
--
-- The Playdate runs a Lua with four extra operators. Almost every example
-- Panic ships uses them:
--
--   score += 1
--   self.dx *= friction
--
-- Love2d runs ordinary Lua, where those are a syntax error, so the browser
-- build rewrites them on the way through:
--
--   score = score + (1)
--   self.dx = self.dx * (friction)
--
-- The device build does not do this. There the operators are real.
--
-- Wiring: build/web.lua hands rewrite() to LuaPreprocess as onAfterMeta, so
-- every Lua file in the browser build goes through it after the preprocessor
-- and before the file is written and checked.

local module = {}

local OPS = { ["+="] = "+", ["-="] = "-", ["*="] = "*", ["/="] = "/" }

-- What each byte of the file is: code, a string, or a comment. Strings and
-- comments are skipped when looking for an operator, and a comment ends the
-- expression that follows one.
local CODE, STRING, COMMENT = 0, 1, 2

local function classify(text)
  local kind = {}
  local i = 1
  local n = #text

  local function mark(from, to, what)
    for k = from, to do
      kind[k] = what
    end
  end

  while i <= n do
    local c = string.sub(text, i, i)
    local longOpen = string.match(text, "^%[(=*)%[", i)
    local commentLongOpen = string.match(text, "^%-%-%[(=*)%[", i)

    if commentLongOpen then
      local _, close = string.find(text, "]" .. commentLongOpen .. "]", i, true)
      close = close or n
      mark(i, close, COMMENT)
      i = close + 1
    elseif string.sub(text, i, i + 1) == "--" then
      local stop = string.find(text, "\n", i, true)
      stop = (stop and stop - 1) or n
      mark(i, stop, COMMENT)
      i = stop + 1
    elseif longOpen then
      local _, close = string.find(text, "]" .. longOpen .. "]", i, true)
      close = close or n
      mark(i, close, STRING)
      i = close + 1
    elseif c == '"' or c == "'" then
      local j = i + 1
      while j <= n do
        local d = string.sub(text, j, j)
        if d == "\\" then
          j = j + 2
        elseif d == c or d == "\n" then
          j = j + 1
          break
        else
          j = j + 1
        end
      end
      mark(i, math.min(j - 1, n), STRING)
      i = j
    else
      kind[i] = CODE
      i = i + 1
    end
  end

  return kind
end

-- Walking backwards from the operator, collect the thing being assigned to.
-- An lvalue is a name, optionally followed by any number of `.name` and
-- `[expression]`: `score`, `self.dx`, `tiles[i + 1].weight`.
local function lvalueStart(text, kind, from)
  local i = from
  while i >= 1 and string.match(string.sub(text, i, i), "%s") do
    i = i - 1
  end

  while true do
    local c = string.sub(text, i, i)

    if c == "]" then
      local depth = 0
      while i >= 1 do
        local d = string.sub(text, i, i)
        if kind[i] == CODE then
          if d == "]" then
            depth = depth + 1
          elseif d == "[" then
            depth = depth - 1
            if depth == 0 then
              break
            end
          end
        end
        i = i - 1
      end
      if i < 1 then
        return nil
      end
      i = i - 1
    elseif string.match(c, "[%w_]") then
      while i >= 1 and string.match(string.sub(text, i, i), "[%w_]") do
        i = i - 1
      end
      -- A name reached from the left end of the chain is the whole lvalue,
      -- unless a dot puts another link in front of it.
      local p = i
      while p >= 1 and string.match(string.sub(text, p, p), "%s") do
        p = p - 1
      end
      if string.sub(text, p, p) == "." and string.sub(text, p - 1, p - 1) ~= "." then
        i = p - 1
      else
        return i + 1
      end
    else
      return nil
    end

    while i >= 1 and string.match(string.sub(text, i, i), "%s") do
      i = i - 1
    end
  end
end

-- Keywords that cannot continue an expression, so seeing one outside any
-- bracket means the value being assigned has ended.
local STOPWORDS = {
  ["end"] = true, ["then"] = true, ["do"] = true, ["else"] = true,
  ["elseif"] = true, ["until"] = true, ["return"] = true, ["local"] = true,
  ["if"] = true, ["while"] = true, ["for"] = true, ["repeat"] = true,
  ["break"] = true,
}

-- Trailing characters that mean the expression is unfinished, so a line
-- break after one of them is a continuation rather than the end.
local function continues(text, kind, last)
  if not last then
    return true
  end
  local c = string.sub(text, last, last)
  if string.find("+-*/%^#<>=~,.([{", c, 1, true) then
    return true
  end
  local word = string.match(string.sub(text, 1, last), "([%a_][%w_]*)$")
  return word == "and" or word == "or" or word == "not"
end

-- Where the value being assigned ends. Brackets are followed so that
-- `f(a, b)` and `{1, 2}` stay in one piece.
local function valueEnd(text, kind, from)
  local n = #text
  local depth = 0
  local last = nil
  local i = from

  while i <= n do
    local c = string.sub(text, i, i)
    if kind[i] == COMMENT then
      if depth <= 0 then
        return last
      end
      i = i + 1
    elseif kind[i] == STRING then
      last = i
      i = i + 1
    elseif c == "(" or c == "[" or c == "{" then
      depth = depth + 1
      last = i
      i = i + 1
    elseif c == ")" or c == "]" or c == "}" then
      depth = depth - 1
      if depth < 0 then
        return last
      end
      last = i
      i = i + 1
    elseif c == ";" and depth <= 0 then
      return last
    elseif c == "\n" and depth <= 0 and not continues(text, kind, last) then
      return last
    elseif string.match(c, "%s") then
      i = i + 1
    else
      local word = string.match(text, "^[%a_][%w_]*", i)
      if word and depth <= 0 and STOPWORDS[word] then
        return last
      end
      if word then
        last = i + #word - 1
        i = i + #word
      else
        last = i
        i = i + 1
      end
    end
  end

  return last
end

-- Rewrite every compound assignment in a chunk of Lua. Returns the new text.
function module.rewrite(text)
  if not (string.find(text, "+=", 1, true) or string.find(text, "-=", 1, true)
    or string.find(text, "*=", 1, true) or string.find(text, "/=", 1, true)) then
    return text
  end

  local kind = classify(text)
  local out = {}
  local copiedTo = 0
  local i = 1
  local n = #text

  while i < n do
    local pair = string.sub(text, i, i + 1)
    local op = OPS[pair]
    -- `a /= b` is an operator; the `=` of `a == b` or `a ~= b` is not, and
    -- neither is anything inside a string or a comment.
    if op and kind[i] == CODE and kind[i + 1] == CODE
      and string.sub(text, i + 2, i + 2) ~= "=" then
      local startOfName = lvalueStart(text, kind, i - 1)
      local stop = valueEnd(text, kind, i + 2)
      if startOfName and stop then
        local name = string.sub(text, startOfName, i - 1)
        name = string.gsub(name, "%s+$", "")
        local value = string.sub(text, i + 2, stop)
        value = string.gsub(value, "^%s+", "")
        out[#out + 1] = string.sub(text, copiedTo + 1, startOfName - 1)
        out[#out + 1] = name .. " = " .. name .. " " .. op .. " (" .. value .. ")"
        copiedTo = stop
        i = stop + 1
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end

  out[#out + 1] = string.sub(text, copiedTo + 1)
  return table.concat(out)
end

-- The file processor build/web.lua uses in place of build.luaProcessor:
-- LuaPreprocess as usual, with rewrite() on the way out.
function module.luaProcessor(input, output)
  local pp = require("playbit.LuaPreprocess.preprocess")
  local fs = require("playbit.tools.filesystem")
  fs.createFolderIfNeeded(output)
  local settings = {
    pathIn = input,
    pathOut = output,
    onAfterMeta = module.rewrite,
  }
  if not enableAssert then
    settings.release = true
  end
  pp.processFile(settings)
end

return module
