-- playdate.geometry gaps: the polygon and rect questions Playbit raises an
-- error for, and the `polygon * transform` shorthand the SDK examples use.

local geom = playdate.geometry
local module = {}

-- Polygons -------------------------------------------------------------------

local polygonMeta = geom.polygon.__index
local rectMeta = geom.rect.__index
local vectorMeta = geom.vector2D.__index
local segmentMeta = geom.lineSegment.__index
local transformMeta = geom.affineTransform.__index

-- `polygon * transform` is how the SDK spells "move every point of this shape".
-- Playbit has the work in transformedPolygon and only leaves the operator out.
polygonMeta.__mul = function(a, b)
  -- Either way round: the SDK accepts transform * polygon as well.
  if a._type == "polygon" then
    return b:transformedPolygon(a)
  end
  return a:transformedPolygon(b)
end

-- The smallest axis aligned box the polygon fits in, as x, y, width, height.
function polygonMeta:getBounds()
  local pts = self._points
  if #pts < 2 then
    return 0, 0, 0, 0
  end
  local minX, minY = pts[1], pts[2]
  local maxX, maxY = minX, minY
  for i = 3, #pts, 2 do
    local x, y = pts[i], pts[i + 1]
    if x < minX then minX = x end
    if x > maxX then maxX = x end
    if y < minY then minY = y end
    if y > maxY then maxY = y end
  end
  return minX, minY, maxX - minX, maxY - minY
end

-- Even-odd ray casting: count the edges a ray to the right crosses. An odd
-- count means the point is inside. The SDK's non-zero winding fill rule is
-- not offered; for the simple shapes games use they agree.
function polygonMeta:containsPoint(x, y, fillRule)
  if type(x) == "table" then
    fillRule = y
    x, y = x.x, x.y
  end
  local pts = self._points
  local count = #pts / 2
  if count < 3 then
    return false
  end
  local inside = false
  local j = count
  for i = 1, count do
    local xi, yi = pts[i * 2 - 1], pts[i * 2]
    local xj, yj = pts[j * 2 - 1], pts[j * 2]
    if (yi > y) ~= (yj > y) then
      local cross = (xj - xi) * (y - yi) / (yj - yi) + xi
      if x < cross then
        inside = not inside
      end
    end
    j = i
  end
  return inside
end

-- Where two line segments cross, or nil. Shared by everything below.
local function segmentsCross(x1, y1, x2, y2, x3, y3, x4, y4)
  local d = (x2 - x1) * (y4 - y3) - (y2 - y1) * (x4 - x3)
  if d == 0 then
    return nil
  end
  local t = ((x3 - x1) * (y4 - y3) - (y3 - y1) * (x4 - x3)) / d
  local u = ((x3 - x1) * (y2 - y1) - (y3 - y1) * (x2 - x1)) / d
  if t < 0 or t > 1 or u < 0 or u > 1 then
    return nil
  end
  return x1 + t * (x2 - x1), y1 + t * (y2 - y1)
end

module.segmentsCross = segmentsCross

-- Walk the polygon's edges, in order, collecting every crossing.
local function polygonEdges(poly)
  local pts = poly._points
  local count = #pts / 2
  local edges = {}
  for i = 1, count - 1 do
    edges[#edges + 1] = { pts[i * 2 - 1], pts[i * 2], pts[i * 2 + 1], pts[i * 2 + 2] }
  end
  if poly._closed and count > 2 then
    edges[#edges + 1] = { pts[count * 2 - 1], pts[count * 2], pts[1], pts[2] }
  end
  return edges
end

function polygonMeta:intersects(other)
  local mine = polygonEdges(self)
  local theirs = polygonEdges(other)
  for i = 1, #mine do
    for j = 1, #theirs do
      local a, b = mine[i], theirs[j]
      if segmentsCross(a[1], a[2], a[3], a[4], b[1], b[2], b[3], b[4]) then
        return true
      end
    end
  end
  return false
end

-- Rects ----------------------------------------------------------------------

function rectMeta:intersection(other)
  local x = math.max(self.x, other.x)
  local y = math.max(self.y, other.y)
  local right = math.min(self.x + self.width, other.x + other.width)
  local bottom = math.min(self.y + self.height, other.y + other.height)
  if right < x then right = x end
  if bottom < y then bottom = y end
  return geom.rect.new(x, y, right - x, bottom - y)
end

function rectMeta:containsRect(r, y, width, height)
  if type(r) == "number" then
    r = geom.rect.new(r, y, width, height)
  end
  return r.x >= self.x
    and r.y >= self.y
    and r.x + r.width <= self.x + self.width
    and r.y + r.height <= self.y + self.height
end

-- Mirror this rect inside another, the way a sprite's collide rect flips when
-- the sprite's image does.
function rectMeta:flipRelativeToRect(r, flip)
  if flip == geom.kUnflipped or flip == nil then
    return
  end
  local flipX = flip == geom.kFlippedX or flip == geom.kFlippedXY
  local flipY = flip == geom.kFlippedY or flip == geom.kFlippedXY
  if flipX then
    self.x = r.x + r.width - (self.x - r.x) - self.width
  end
  if flipY then
    self.y = r.y + r.height - (self.y - r.y) - self.height
  end
end

-- Vectors ---------------------------------------------------------------------

function vectorMeta:projectAlong(v)
  local len = v.dx * v.dx + v.dy * v.dy
  if len == 0 then
    self.dx, self.dy = 0, 0
    return
  end
  local scale = (self.dx * v.dx + self.dy * v.dy) / len
  self.dx, self.dy = v.dx * scale, v.dy * scale
end

function vectorMeta:projectedAlong(v)
  local out = geom.vector2D.new(self.dx, self.dy)
  out:projectAlong(v)
  return out
end

-- Degrees, to match the rest of the SDK.
function vectorMeta:angleBetween(v)
  local a = math.sqrt(self.dx * self.dx + self.dy * self.dy)
  local b = math.sqrt(v.dx * v.dx + v.dy * v.dy)
  if a == 0 or b == 0 then
    return 0
  end
  local cos = (self.dx * v.dx + self.dy * v.dy) / (a * b)
  if cos > 1 then cos = 1 end
  if cos < -1 then cos = -1 end
  return math.deg(math.acos(cos))
end

-- A vector2D holds dx and dy, and hardware answers to x and y as well. SDK
-- code uses both spellings, sometimes in the same file, so both work here.
local vectorMethods = vectorMeta

vectorMeta.__index = function(vector, key)
  if key == "x" then
    return rawget(vector, "dx")
  end
  if key == "y" then
    return rawget(vector, "dy")
  end
  return vectorMethods[key]
end

vectorMeta.__newindex = function(vector, key, value)
  if key == "x" then
    rawset(vector, "dx", value)
  elseif key == "y" then
    rawset(vector, "dy", value)
  else
    rawset(vector, key, value)
  end
end

-- Line segments ----------------------------------------------------------------

function geom.lineSegment.fast_intersection(x1, y1, x2, y2, x3, y3, x4, y4)
  local x, y = segmentsCross(x1, y1, x2, y2, x3, y3, x4, y4)
  if not x then
    return 0, 0
  end
  return x, y
end

function segmentMeta:intersectsLineSegment(other)
  local x, y = segmentsCross(self.x1, self.y1, self.x2, self.y2,
    other.x1, other.y1, other.x2, other.y2)
  if not x then
    return false
  end
  return true, geom.point.new(x, y)
end

function segmentMeta:intersectsPolygon(poly)
  local edges = polygonEdges(poly)
  local points = {}
  for i = 1, #edges do
    local e = edges[i]
    local x, y = segmentsCross(self.x1, self.y1, self.x2, self.y2, e[1], e[2], e[3], e[4])
    if x then
      points[#points + 1] = geom.point.new(x, y)
    end
  end
  return #points > 0, points
end

function segmentMeta:intersectsRect(r)
  local x, y, w, h = r.x, r.y, r.width, r.height
  local edges = {
    { x, y, x + w, y }, { x + w, y, x + w, y + h },
    { x + w, y + h, x, y + h }, { x, y + h, x, y },
  }
  for i = 1, #edges do
    local e = edges[i]
    if segmentsCross(self.x1, self.y1, self.x2, self.y2, e[1], e[2], e[3], e[4]) then
      return true
    end
  end
  return false
end

-- Transforms ---------------------------------------------------------------------

-- A rotated rectangle is not a rectangle, so this is the box around the
-- rotated corners, which is what the SDK gives back too.
function transformMeta:transformAABB(r)
  local corners = {
    { r.x, r.y }, { r.x + r.width, r.y },
    { r.x + r.width, r.y + r.height }, { r.x, r.y + r.height },
  }
  local minX, minY, maxX, maxY
  for i = 1, 4 do
    local x, y = self:transformXY(corners[i][1], corners[i][2])
    if not minX or x < minX then minX = x end
    if not maxX or x > maxX then maxX = x end
    if not minY or y < minY then minY = y end
    if not maxY or y > maxY then maxY = y end
  end
  r.x, r.y, r.width, r.height = minX, minY, maxX - minX, maxY - minY
end

return module
