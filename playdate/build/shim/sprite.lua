-- playdate.graphics.sprite. Playbit has none of this.
--
-- A sprite is a position, a size, a z index, and something to draw. The
-- display list keeps them in z order and draws them for you. Collisions are
-- axis aligned boxes, resolved one axis at a time, which is the simplest thing
-- that gets slide, freeze, overlap and bounce right for rectangles.
--
-- Coordinates match the SDK: a sprite's x and y are its center point by
-- default, its bounds are the rectangle it occupies, and a collide rect is
-- measured from the top left of those bounds.

local warn = require("shim.warn")

local gfx = playdate.graphics
local pbg = playbit.graphics

local SCREEN_WIDTH = 400
local SCREEN_HEIGHT = 240

-- Built with Playbit's class() so that class("Player").extends(gfx.sprite)
-- works the way every SDK example writes it.
class("sprite", nil, gfx).extends()

local sprite = gfx.sprite

sprite.kCollisionTypeSlide = 0
sprite.kCollisionTypeFreeze = 1
sprite.kCollisionTypeOverlap = 2
sprite.kCollisionTypeBounce = 3

local displayList = {}
local eraseQueue = {}
local backgroundCallback = nil
local addCounter = 0

-- Bitmask helpers. bit comes from build/bit51.lua, prepended to main.lua,
-- because love.js is plain Lua 5.1 and has no bitwise operators.
local function toMask(value)
  if value == nil then
    return 0
  end
  if type(value) == "number" then
    return value
  end
  local mask = 0
  for i = 1, #value do
    mask = bit.bor(mask, bit.lshift(1, value[i] - 1))
  end
  return mask
end

local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
  return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

-- Construction -----------------------------------------------------------------

function sprite:init(image)
  self._isSprite = true
  self.x = 0
  self.y = 0
  self.width = 0
  self.height = 0
  self.centerX = 0.5
  self.centerY = 0.5
  self.zIndex = 0
  self.visible = true
  self.image = nil
  self.imageFlip = gfx.kImageUnflipped
  self.scaleX = 1
  self.scaleY = 1
  self.tag = 0
  self.groupMask = 0
  self.collidesWithGroupsMask = 0
  self.collideRect = nil
  self.updatesEnabled = true
  self.collisionsEnabled = true
  self.opaque = false
  self.ignoresDrawOffset = false
  self._inDisplayList = false
  self._order = 0
  self._lastBounds = nil
  if image then
    self:setImage(image)
  end
end

function sprite.new(image)
  -- Plenty of SDK code writes gfx.sprite:new(), with a colon, which hands the
  -- class itself in where the image goes. Hardware ignores an argument that
  -- is not an image, so this does too.
  if image == sprite then
    image = nil
  end
  return sprite(image)
end

-- Position and size ---------------------------------------------------------------

function sprite:setImage(image, flip, scale, yscale)
  self.image = image
  if image then
    local w, h = image:getSize()
    self.width = w
    self.height = h
  end
  if flip then
    self.imageFlip = flip
  end
  if scale then
    self.scaleX = scale
    self.scaleY = yscale or scale
  end
end

function sprite:getImage()
  return self.image
end

function sprite:setSize(width, height)
  self.width = width
  self.height = height
end

function sprite:getSize()
  return self.width, self.height
end

function sprite:setCenter(cx, cy)
  self.centerX = cx
  self.centerY = cy
end

function sprite:getCenter()
  return self.centerX, self.centerY
end

function sprite:moveTo(x, y)
  self.x = x
  self.y = y
end

function sprite:moveBy(dx, dy)
  self.x = self.x + dx
  self.y = self.y + dy
end

function sprite:getPosition()
  return self.x, self.y
end

function sprite:getBounds()
  return self.x - self.centerX * self.width,
    self.y - self.centerY * self.height,
    self.width,
    self.height
end

function sprite:getBoundsRect()
  local x, y, w, h = self:getBounds()
  return playdate.geometry.rect.new(x, y, w, h)
end

function sprite:setBounds(x, y, width, height)
  if type(x) == "table" then
    x, y, width, height = x.x, x.y, x.width, x.height
  end
  self.width = width
  self.height = height
  self.x = x + self.centerX * width
  self.y = y + self.centerY * height
end

function sprite:setZIndex(z)
  self.zIndex = z
end

function sprite:getZIndex()
  return self.zIndex
end

function sprite:setVisible(flag)
  self.visible = flag
end

function sprite:isVisible()
  return self.visible
end

function sprite:setTag(tag)
  self.tag = tag
end

function sprite:getTag()
  return self.tag
end

function sprite:setImageFlip(flip)
  self.imageFlip = flip
end

function sprite:getImageFlip()
  return self.imageFlip
end

function sprite:setScale(scale, yscale)
  self.scaleX = scale
  self.scaleY = yscale or scale
end

function sprite:setOpaque(flag)
  self.opaque = flag
end

function sprite:setUpdatesEnabled(flag)
  self.updatesEnabled = flag
end

function sprite:updatesEnabledFlag()
  return self.updatesEnabled
end

function sprite:setIgnoresDrawOffset(flag)
  self.ignoresDrawOffset = flag
end

-- Every frame redraws everything here, so there is nothing to mark.
function sprite:markDirty() end
function sprite:setRedrawsOnImageChange() end
function sprite:setClipRect() end
function sprite:clearClipRect() end

function sprite:setRotation(angle)
  warn.note("sprite:setRotation() does nothing here; rotate the image yourself with image:drawRotated()")
end

-- Display list ----------------------------------------------------------------------

function sprite:add()
  if self._inDisplayList then
    return
  end
  addCounter = addCounter + 1
  self._order = addCounter
  self._inDisplayList = true
  displayList[#displayList + 1] = self
end

function sprite:remove()
  if not self._inDisplayList then
    return
  end
  self._inDisplayList = false
  for i = 1, #displayList do
    if displayList[i] == self then
      table.remove(displayList, i)
      break
    end
  end
  if self._lastBounds then
    eraseQueue[#eraseQueue + 1] = self._lastBounds
    self._lastBounds = nil
  end
end

function sprite.addSprite(s)
  s:add()
end

function sprite.removeSprite(s)
  s:remove()
end

function sprite.removeAll()
  for i = #displayList, 1, -1 do
    displayList[i]:remove()
  end
end

function sprite.removeSprites(list)
  for i = 1, #list do
    list[i]:remove()
  end
end

function sprite.getAllSprites()
  local out = {}
  for i = 1, #displayList do
    out[i] = displayList[i]
  end
  return out
end

function sprite.spriteCount()
  return #displayList
end

function sprite.performOnAllSprites(fn)
  for i = #displayList, 1, -1 do
    fn(displayList[i])
  end
end

function sprite.setBackgroundDrawingCallback(fn)
  backgroundCallback = fn
end

function sprite.redrawBackground() end
function sprite.setAlwaysRedraw() end
function sprite.addDirtyRect(x, y, width, height)
  eraseQueue[#eraseQueue + 1] = { x = x, y = y, width = width, height = height }
end

-- Collision boxes ------------------------------------------------------------------

function sprite:setCollideRect(x, y, width, height)
  if type(x) == "table" then
    x, y, width, height = x.x, x.y, x.width, x.height
  end
  self.collideRect = { x = x, y = y, width = width, height = height }
end

function sprite:getCollideRect()
  if not self.collideRect then
    return nil
  end
  local r = self.collideRect
  return playdate.geometry.rect.new(r.x, r.y, r.width, r.height)
end

function sprite:getCollideBounds()
  return self:getCollideRect()
end

function sprite:clearCollideRect()
  self.collideRect = nil
end

-- The collide rect in screen coordinates.
function sprite:_worldCollideRect()
  local bx, by = self:getBounds()
  local r = self.collideRect
  return bx + r.x, by + r.y, r.width, r.height
end

function sprite:setGroups(groups)
  self.groupMask = toMask(groups)
end

function sprite:setCollidesWithGroups(groups)
  self.collidesWithGroupsMask = toMask(groups)
end

function sprite:setGroupMask(mask)
  self.groupMask = mask
end

function sprite:getGroupMask()
  return self.groupMask
end

function sprite:setCollidesWithGroupsMask(mask)
  self.collidesWithGroupsMask = mask
end

function sprite:getCollidesWithGroupsMask()
  return self.collidesWithGroupsMask
end

function sprite:resetGroupMask()
  self.groupMask = 0
end

function sprite:resetCollidesWithGroupsMask()
  self.collidesWithGroupsMask = 0
end

function sprite:setCollisionsEnabled(flag)
  self.collisionsEnabled = flag
end

-- Default response. Override this method, or pass a constant to
-- setCollisionResponse, to change what happens on contact.
function sprite:collisionResponse(other)
  return sprite.kCollisionTypeFreeze
end

function sprite:setCollisionResponse(response)
  if type(response) == "function" then
    self.collisionResponse = response
  else
    self.collisionResponse = function()
      return response
    end
  end
end

-- Queries -------------------------------------------------------------------------

local function collisionCandidates(self)
  local out = {}
  for i = 1, #displayList do
    local other = displayList[i]
    if other ~= self and other.collideRect and other.collisionsEnabled then
      -- A mask of 0 means "everything", which is how the SDK starts out.
      if self.collidesWithGroupsMask == 0
        or bit.band(self.collidesWithGroupsMask, other.groupMask) ~= 0 then
        out[#out + 1] = other
      end
    end
  end
  return out
end

function sprite:overlappingSprites()
  local out = {}
  if not self.collideRect then
    return out
  end
  local ax, ay, aw, ah = self:_worldCollideRect()
  local others = collisionCandidates(self)
  for i = 1, #others do
    local bx, by, bw, bh = others[i]:_worldCollideRect()
    if rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh) then
      out[#out + 1] = others[i]
    end
  end
  return out
end

function sprite.allOverlappingSprites()
  local out = {}
  for i = 1, #displayList do
    local s = displayList[i]
    if s.collideRect then
      local hits = s:overlappingSprites()
      for j = 1, #hits do
        out[#out + 1] = { s, hits[j] }
      end
    end
  end
  return out
end

function sprite.querySpritesInRect(x, y, width, height)
  local out = {}
  for i = 1, #displayList do
    local s = displayList[i]
    local bx, by, bw, bh = s:getBounds()
    if rectsOverlap(x, y, width, height, bx, by, bw, bh) then
      out[#out + 1] = s
    end
  end
  return out
end

function sprite.querySpritesAtPoint(x, y)
  return sprite.querySpritesInRect(x, y, 1, 1)
end

function sprite.querySpritesAlongLine(x1, y1, x2, y2)
  local x = math.min(x1, x2)
  local y = math.min(y1, y2)
  return sprite.querySpritesInRect(x, y, math.abs(x2 - x1) + 1, math.abs(y2 - y1) + 1)
end

-- Movement with collisions -------------------------------------------------------

-- One axis at a time. Move to where you asked, see what you are now inside of,
-- then back out along that axis to the point of contact. Doing x and y
-- separately is what makes sliding along a wall fall out for free: the axis
-- that hit gets stopped, the axis that did not keeps going.
local function axisPass(self, others, collisions, seen, axis, from, to)
  local delta = to - from
  if axis == "x" then
    self.x = to
  else
    self.y = to
  end

  local rx, ry, rw, rh = self:_worldCollideRect()
  -- Distance from the sprite's position to the near edge of its collide rect.
  local offset
  local size
  if axis == "x" then
    offset = rx - self.x
    size = rw
  else
    offset = ry - self.y
    size = rh
  end

  -- Test the whole path, not just where it landed. A sprite moving 150 pixels
  -- in one frame would otherwise step straight over a coin without noticing.
  local sx, sy, sw, sh = rx, ry, rw, rh
  if axis == "x" then
    sx = math.min(rx, rx - delta)
    sw = rw + math.abs(delta)
  else
    sy = math.min(ry, ry - delta)
    sh = rh + math.abs(delta)
  end

  local blocker = nil
  local blockerResponse = nil
  local blockerContact = nil
  local hits = {}

  for i = 1, #others do
    local other = others[i]
    local ox, oy, ow, oh = other:_worldCollideRect()
    if rectsOverlap(sx, sy, sw, sh, ox, oy, ow, oh) then
      local response = self:collisionResponse(other)
      hits[#hits + 1] = { other = other, response = response,
        ox = ox, oy = oy, ow = ow, oh = oh }
      if response ~= sprite.kCollisionTypeOverlap and delta ~= 0 then
        local contact
        if axis == "x" then
          if delta > 0 then
            contact = ox - size - offset
          else
            contact = ox + ow - offset
          end
        else
          if delta > 0 then
            contact = oy - size - offset
          else
            contact = oy + oh - offset
          end
        end
        -- Keep the contact that stops the sprite soonest.
        if blockerContact == nil
          or (delta > 0 and contact < blockerContact)
          or (delta < 0 and contact > blockerContact) then
          blockerContact = contact
          blocker = other
          blockerResponse = response
        end
      end
    end
  end

  local resolved = to
  local frozen = false
  if blocker then
    -- Already inside something before the move started: stay put rather than
    -- shoving the sprite backwards out of it.
    if (delta > 0 and blockerContact < from) or (delta < 0 and blockerContact > from) then
      blockerContact = from
    end
    if blockerResponse == sprite.kCollisionTypeBounce then
      resolved = blockerContact - (to - blockerContact)
    else
      resolved = blockerContact
      if blockerResponse == sprite.kCollisionTypeFreeze then
        frozen = true
      end
    end
  end

  for i = 1, #hits do
    local hit = hits[i]
    if not seen[hit.other] then
      seen[hit.other] = true
      local normalX, normalY = 0, 0
      if hit.other == blocker then
        if axis == "x" then
          normalX = delta > 0 and -1 or 1
        else
          normalY = delta > 0 and -1 or 1
        end
      end
      local ti = 0
      if delta ~= 0 then
        ti = (resolved - from) / delta
      end
      collisions[#collisions + 1] = {
        sprite = self,
        other = hit.other,
        type = hit.response,
        overlaps = hit.response == sprite.kCollisionTypeOverlap,
        ti = ti,
        move = { x = 0, y = 0 },
        normal = { x = normalX, y = normalY },
        touch = { x = self.x, y = self.y },
        spriteRect = playdate.geometry.rect.new(rx, ry, rw, rh),
        otherRect = playdate.geometry.rect.new(hit.ox, hit.oy, hit.ow, hit.oh),
        otherCollideRect = playdate.geometry.rect.new(hit.ox, hit.oy, hit.ow, hit.oh),
        x = self.x,
        y = self.y,
      }
    end
  end

  if axis == "x" then
    self.x = resolved
  else
    self.y = resolved
  end
  return frozen
end

function sprite:moveWithCollisions(goalX, goalY)
  if type(goalX) == "table" then
    goalX, goalY = goalX.x, goalX.y
  end

  local collisions = {}
  if not self.collideRect or not self.collisionsEnabled then
    self:moveTo(goalX, goalY)
    return self.x, self.y, collisions, 0
  end

  local startX, startY = self.x, self.y
  local others = collisionCandidates(self)
  local seen = {}

  local frozen = axisPass(self, others, collisions, seen, "x", startX, goalX)
  if frozen then
    -- Freeze means stop at the point of contact, so the other axis does not
    -- get its move either.
    self.y = startY
  else
    axisPass(self, others, collisions, seen, "y", startY, goalY)
  end

  local moveX = goalX - startX
  local moveY = goalY - startY
  for i = 1, #collisions do
    collisions[i].move.x = moveX
    collisions[i].move.y = moveY
    collisions[i].touch.x = self.x
    collisions[i].touch.y = self.y
  end

  return self.x, self.y, collisions, #collisions
end

-- Same answer, without actually moving.
function sprite:checkCollisions(goalX, goalY)
  local startX, startY = self.x, self.y
  local ax, ay, collisions, count = self:moveWithCollisions(goalX, goalY)
  self.x = startX
  self.y = startY
  return ax, ay, collisions, count
end

-- Do the two sprites' pictures really touch? The collide rects say the boxes
-- overlap; this says whether any solid pixel does.
function sprite:alphaCollision(other)
  if not (self.image and other and other.image) then
    return true
  end
  local x1, y1 = self:getBounds()
  local x2, y2 = other:getBounds()
  return gfx.checkAlphaCollision(
    self.image, x1, y1, self.imageFlip,
    other.image, x2, y2, other.imageFlip)
end

-- Drawing ----------------------------------------------------------------------------

-- The default. Sprites with an image draw the image; sprites that override
-- this draw whatever they like, with 0,0 at their top left corner.
function sprite:draw(x, y, width, height) end

local function drawOne(s)
  local bx, by = s:getBounds()
  bx = math.floor(bx)
  by = math.floor(by)
  if s.draw ~= sprite.draw then
    if s.width <= 0 or s.height <= 0 then
      return
    end
    -- Hardware clips a sprite's own drawing to its bounds. Without that,
    -- anything drawn a pixel outside them is never erased again, and a moving
    -- sprite paints a trail across the screen that never goes away.
    local clipX, clipY, clipWidth, clipHeight = love.graphics.getScissor()
    love.graphics.push()
    love.graphics.translate(bx, by)
    love.graphics.setScissor(bx + pbg.drawOffset.x, by + pbg.drawOffset.y, s.width, s.height)
    s:draw(0, 0, s.width, s.height)
    love.graphics.setScissor(clipX, clipY, clipWidth, clipHeight)
    love.graphics.pop()
  elseif s.image then
    if s.scaleX ~= 1 or s.scaleY ~= 1 then
      s.image:drawScaled(bx, by, s.scaleX, s.scaleY)
    else
      s.image:draw(bx, by, s.imageFlip)
    end
  end
end

local function eraseRects(rects)
  if #rects == 0 then
    return
  end
  local previousColor = pbg.drawColorIndex
  local previousPattern = pbg.drawPattern
  gfx.setColor(pbg.backgroundColorIndex)
  for i = 1, #rects do
    local r = rects[i]
    gfx.fillRect(r.x, r.y, r.width, r.height)
  end
  gfx.setColor(previousColor)
  gfx.setPattern(previousPattern)
end

-- Two passes, because erasing sprite B's old position after drawing sprite A
-- would punch a hole in A.
function sprite.redraw()
  if backgroundCallback then
    backgroundCallback(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
  else
    local rects = {}
    for i = 1, #eraseQueue do
      rects[#rects + 1] = eraseQueue[i]
    end
    for i = 1, #displayList do
      local s = displayList[i]
      if s._lastBounds then
        rects[#rects + 1] = s._lastBounds
      end
      local bx, by, bw, bh = s:getBounds()
      rects[#rects + 1] = { x = math.floor(bx), y = math.floor(by), width = bw, height = bh }
    end
    eraseRects(rects)
  end
  eraseQueue = {}

  local order = {}
  for i = 1, #displayList do
    order[i] = displayList[i]
  end
  table.sort(order, function(a, b)
    if a.zIndex == b.zIndex then
      return a._order < b._order
    end
    return a.zIndex < b.zIndex
  end)

  for i = 1, #order do
    local s = order[i]
    local bx, by, bw, bh = s:getBounds()
    s._lastBounds = { x = math.floor(bx), y = math.floor(by), width = bw, height = bh }
    if s.visible then
      drawOne(s)
    end
  end
end

-- gfx.sprite.update() updates then draws the whole display list. A sprite that
-- does not define its own update() inherits this one, so calling it with a
-- sprite as self has to mean "this sprite has nothing to do".
function sprite.update(maybeSelf)
  if type(maybeSelf) == "table" and rawget(maybeSelf, "_isSprite") then
    return
  end

  local snapshot = {}
  for i = 1, #displayList do
    snapshot[i] = displayList[i]
  end
  for i = 1, #snapshot do
    local s = snapshot[i]
    if s._inDisplayList and s.updatesEnabled and s.update ~= sprite.update then
      s:update()
    end
  end

  sprite.redraw()
end

-- A box that blocks things and draws nothing. Walls, usually.
function sprite.addEmptyCollisionSprite(x, y, width, height)
  if type(x) == "table" then
    x, y, width, height = x.x, x.y, x.width, x.height
  end
  local s = sprite.new()
  s:setCenter(0, 0)
  s:setSize(width, height)
  s:moveTo(x, y)
  s:setCollideRect(0, 0, width, height)
  s:add()
  return s
end

warn.fill("playdate.graphics.sprite.", sprite, {
  "addWallSprites", "setTilemap", "setStencil",
})

return sprite
