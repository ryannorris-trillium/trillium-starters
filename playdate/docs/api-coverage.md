# What works in the browser

You write real Playdate code against the real SDK documentation:
[Inside Playdate](https://sdk.play.date/Inside%20Playdate.html). The same file
runs in a browser tab and, through `build-device.sh`, on the hardware.

The browser is not a Playdate. It gets there in two hops:

1. **[Playbit](https://github.com/GamesRightMeow/playbit)** rewrites part of the
   Playdate API on top of Love2d. It covers drawing, images, fonts, buttons and
   the crank, and it leaves a lot of the SDK as a function that raises an error.
2. **The shim** (`build/shim/`) fills the gaps. It is browser only. The device
   build never loads it, because on a real Playdate the real API is already
   there.

Where something cannot be done at all, the shim still has the function. Calling
it prints one line to the console and returns, so the game keeps running and
you can see why the thing you expected did not happen:

```
playdate shim: image:setMaskImage() does nothing here; Playbit has no mask support
```

If a feature behaves oddly, look here first, then at the console.

## What the build does to your file

Nothing in `source/` has to know it is going to a browser. The file you write
is the file that compiles for the hardware.

- **`+=`, `-=`, `*=` and `/=` work.** The Playdate runs a Lua with four extra
  operators that plain Lua does not have, so the browser build rewrites
  `score += 1` into `score = score + (1)` on the way through. See
  `build/ops.lua`. The device build leaves them alone; there they are real.
- **Everything under `source/` is packaged, folders and all.** A game split
  over several files with its own art builds the same way a one file game does:
  `import "Fish/fish"` and `gfx.image.new("images/bg")` resolve exactly as they
  do on the device.
- **`.fnt` fonts are copied across untouched** and read at run time, so a font
  exported from Caps works with no conversion step.
- **The browser draws at double size** (800 by 480), because a 400 by 240
  window is a postage stamp on a laptop. A game that wants something else calls
  `playbit.graphics.setCanvasScale` inside a `!if LOVE2D then` block, or
  `playdate.display.setScale`, which works here as it does on hardware.

## The short version

| Area | State in the browser |
|------|----------------------|
| Drawing shapes and text | Works |
| **Playdate `.fnt` fonts** | **Works, added by the shim** |
| Images | Works, no masks |
| Imagetables | Works |
| **Sprites and collisions** | **Works, added by the shim** |
| Animators, loops, blinkers | Works |
| Timers and frame timers | Works, replaced by the shim |
| Sound: players and a synth | Works, no effects or sequences |
| Buttons and crank | Works, including the callbacks |
| Accelerometer | Always reports the device lying flat |
| Crank indicator | Works, drawn differently |
| gridview | Not available |
| Datastore and files | Works, saved in the browser |
| Display | Works |
| System menu | Works, press `M` |
| Geometry | Works |
| Pathfinder | Not available |
| json | Works |
| **Tilemaps** | **Works, added by the shim** |

## Three things that are different everywhere

**Frame rate.** A Playdate runs at 30 frames a second. A browser tab draws at
whatever the screen does, usually 60. The shim skips the extra frames so a game
plays at the same speed in both places. `playdate.display.setRefreshRate(0)`
turns that off and lets it run flat out.

**Saved files.** `playdate.datastore` and `playdate.file` write into the
browser's storage for the page. That is not the same as a memory card. Closing
the tab, clearing site data, or opening the game from a different address can
lose it. On hardware the save is permanent.

**Pixels only go one way.** An image you have drawn into with `pushContext`
becomes a canvas on the graphics card. Drawing it, scaling it, copying it and
rotating it all work, because those all push pixels towards the card. Reading
them back off it does not: WebGL 1 in the browser refuses, with
`glReadPixelsRobustANGLE: Invalid format and type combination`. So
`image:sample`, `checkAlphaCollision`, `datastore.writeImage` and the mask
functions warn and return instead of answering. Images loaded from a `.png` are
read on the processor, not the card, so imagetables and everything else that
starts from a file are unaffected.

## Area by area

### Graphics primitives

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| `clear`, `setColor` (black and white only), `setBackgroundColor`, `setPattern`, `drawLine`, `drawRect`, `fillRect`, `drawCircleAtPoint`, `fillCircleAtPoint`, `drawArc`, `drawPixel`, `setLineWidth`, `setDrawOffset`, `getDrawOffset`, `pushContext`, `popContext`, `setImageDrawMode` for copy, fillWhite, fillBlack, inverted, whiteTransparent | `drawRoundRect`, `fillRoundRect`, `drawTriangle`, `fillTriangle`, `drawPolygon`, `fillPolygon`, `drawEllipseInRect`, `fillEllipseInRect`, `drawCircleInRect`, `fillCircleInRect`, `setClipRect`, `getClipRect`, `clearClipRect` and the `ScreenClipRect` spellings, `setDitherPattern`, `setStrokeLocation`, `setLineCapStyle`, `getImageDrawMode`, `lockFocus`, `unlockFocus` | The `XOR`, `NXOR` and `blackTransparent` draw modes: the shader has no case for them, so they fall back to copy and warn once. `setDitherPattern` paints the off pixels white instead of letting the background through. `setStrokeLocation` is always centered. `checkAlphaCollision`, `imageWithText`, `getTextSizeForMaxWidth`, `perlin`, localized text. |

Round rect corners are Love's, not the Playdate's, so they are a pixel or two
different from hardware.

### Images

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| `image.new(width, height)`, `image.new(path)`, `draw` with flip and a source rect, `drawScaled`, `drawRotated`, `getSize` | A path with or without `.png`, and a message naming the file when it is not there; `copy`, `clear`, `load`, `drawCentered`, `drawAnchored`, `drawTiled`, `drawRotated` with a scale, `scaledImage`, `rotatedImage`, `imageSizeAtPath`. Also a rebuilt `pushContext` and `popContext`, see below | Masks: `setMaskImage`, `addMask`, `getMaskImage`, `clearMask` warn and do nothing. `sample` returns black. `drawFaded` draws at full strength. `drawBlurred`, `blendWithImage`, `drawSampled`, `setInverted`, `invertedImage`, `vcrPauseFilterImage`. |

**Drawing into an image.** `pushContext(image)` points the drawing commands at
an image instead of the screen, which is how you build artwork in code rather
than shipping a `.png`:

```lua
local ball = gfx.image.new(16, 16)
gfx.pushContext(ball)
  gfx.setColor(gfx.kColorBlack)
  gfx.fillCircleAtPoint(8, 8, 7)
gfx.popContext()
local sprite = gfx.sprite.new(ball)
```

Playbit does this by drawing into a canvas on the graphics card and then, after
every single drawing call, reading the whole canvas back to the processor and
copying it into the image. The browser cannot do the reading back part, so in
Playbit alone the first line of artwork you draw kills the game.

The shim drops the copy. The first time an image is pushed it becomes its
canvas, keeping whatever it already held, and stays that way. Everything that
uses an image keeps working because a canvas draws like any other texture.
Nesting still works, and `popContext` goes back to whatever was underneath.
`lockFocus` and `unlockFocus` are the same two functions under their older
names.

One thing to know about that. A canvas lives only on the graphics card, and the
browser throws every canvas away and makes it again, empty, whenever the window
mode is set. So changing the size of the browser window mid-game empties every
image you have drawn into. The shim keeps that from happening by itself: the
window is set once, at the moment the game asks for it, before any artwork has
been drawn, and a later request for the size the window is already in does
nothing. Artwork made in `playdate.update` was never at risk either way.

### Imagetables

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| `imagetable.new(path)` for a `name-table-16-16.png` grid, `getImage`, `drawImage`, `getLength`, `getSize` | Numbered sequences, `name-table-1.png` and up; `imagetable.new(count)` for an empty one; `setImage`; `table[n]` indexing; a readable error when neither file shape is found | `#imagetable`. Lua 5.1 in the browser ignores the length metamethod, so use `getLength()`. `imagetable:load`. |

### Sprites

Playbit has no sprites at all. Everything here is the shim.

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| nothing | `sprite.new`, `setImage`, `getImage`, `add`, `remove`, `addSprite`, `removeSprite`, `removeAll`, `removeSprites`, `getAllSprites`, `spriteCount`, `performOnAllSprites`, `moveTo`, `moveBy`, `getPosition`, `setCenter`, `getCenter`, `setBounds`, `getBounds`, `getBoundsRect`, `setSize`, `getSize`, `setZIndex`, `getZIndex`, `setVisible`, `isVisible`, `setTag`, `getTag`, `setImageFlip`, `setScale`, `setOpaque`, `setUpdatesEnabled`, `setCollisionsEnabled`, `setIgnoresDrawOffset`, `markDirty`, the `draw(x, y, width, height)` and `update()` overrides, `sprite.update()`, `sprite.redraw()`, `setBackgroundDrawingCallback`, `addDirtyRect`, `setAlwaysRedraw`, `setCollideRect`, `getCollideRect`, `clearCollideRect`, `setGroups`, `setCollidesWithGroups`, `setGroupMask`, `setCollidesWithGroupsMask`, `collisionResponse`, `setCollisionResponse`, `moveWithCollisions`, `checkCollisions`, `overlappingSprites`, `allOverlappingSprites`, `querySpritesInRect`, `querySpritesAtPoint`, `querySpritesAlongLine`, and `class("Thing").extends(gfx.sprite)` | `setRotation`, tilemap sprites, stencils. |

Coordinates match the SDK. A sprite's `x` and `y` are its center by default
(`setCenter(0.5, 0.5)`), its bounds are the rectangle it covers, and a collide
rect is measured from the top left of those bounds.

How the collisions differ from hardware:

- Boxes only. No pixel or polygon shapes.
- The move is resolved one axis at a time, x then y. Sliding along a wall comes
  out right. A diagonal move straight into an inside corner can land a pixel
  away from where hardware puts it.
- `kCollisionTypeFreeze` stops the sprite at the point of contact and gives up
  the rest of the move on both axes.
- `kCollisionTypeBounce` is a straight reflection of the leftover movement, with
  no energy lost.
- Each other sprite is reported once per `moveWithCollisions`, even if it blocks
  both axes.
- A collision entry has `sprite`, `other`, `type`, `overlaps`, `ti`, `move`,
  `normal`, `touch`, `spriteRect`, `otherRect`, `otherCollideRect`, `x` and `y`.
  Hardware fills in a few more.
- The whole screen is redrawn every frame instead of only the dirty parts, so
  `markDirty` and `setAlwaysRedraw` do nothing here. That is slower and easier
  to reason about. If there is no background drawing callback, the shim erases
  each sprite's old and new rectangle before drawing, which is close to what the
  dirty rectangle system does on hardware.

### Animation

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| `graphics.animation.loop`: `new`, `image`, `draw`, `setImageTable`, `isValid` | `graphics.animator`: `new` with numbers or points, `currentValue`, `valueAtTime`, `progress`, `ended`, `reset`, plus `repeatCount`, `reverses`, `easingAmplitude`, `easingPeriod`. `graphics.animation.blinker`: `new`, `start`, `startLoop`, `stop`, `remove`, `update`, `updateAll`, `stopAll`. All 41 `playdate.easingFunctions` load, which they did not before | Animators that follow a line, an arc or a polygon, and the multi part animator. They warn and fall back to a plain 0 to 1 number. |

### Timers

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| `timer.new` in both forms, eased values, `pause`, `start`, `reset`, `updateTimers`, `allTimers` | The shim replaces `playdate.timer` outright, because Playbit's `remove()` deleted a different timer from the list and `discardOnCompletion` inserted a nil. Same API, plus `performAfterDelay`, `keyRepeatTimer`, `keyRepeatTimerWithDelay`. `playdate.frameTimer` is added whole: every function in Playbit's version raised an error | nothing |

You still call `playdate.timer.updateTimers()` once per frame yourself, the same
as on hardware.

### Fonts and text

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| One built in font, `drawText`, `drawTextAligned`, `drawTextInRect`, `getTextSize`, `getFont` | **Real Playdate `.fnt` fonts**: `font.new(path)`, `setFont`, `getSystemFont`, `setFontTracking`, `font.newFamily`, and on a font `getTextWidth`, `getHeight`, `getGlyph`, `setTracking`, `setLeading`, `drawText`, `drawTextAligned`, `drawTextInRect`. Multi line text works | Bold and italic in one family: a family is loaded, but every weight is the same font. The `*bold*` and `_italic_` markup in a string is not applied. The width, height, wrap mode and alignment arguments to `drawText`: passing them raises an error from Playbit. Use `drawTextInRect` or `drawTextAligned` instead. |

A Playdate font is two files: an image with every glyph in a grid, named
`name-table-14-14.png`, and a plain text `name.fnt` listing the glyphs in the
order they appear in that grid with how far the pen moves after each one.
Playbit hands the `.fnt` straight to Love, which reads a different format and
answers "Invalid font file". The browser build copies `.fnt` files across
untouched and `build/shim/font.lua` reads the real format at run time. Glyphs
are drawn as pieces of the image, one per character, so `setImageDrawMode` with
`fillWhite` gives white text just as it does on hardware.

### Sound

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| `sampleplayer` and `fileplayer`, `.wav` only | Any file Love can read (`.wav`, `.ogg`, `.mp3`), with or without the extension in the path; `play(0)` to loop; `stop`, `pause`, `isPlaying`, `setVolume`, `getVolume`, `setRate`, `getLength`, `copy`, `setOffset`; a silent stand in plus one warning when the file is missing; `sound.sample`; `sound.synth` with sine, square, sawtooth, triangle and noise, `playNote` taking a frequency, a MIDI number or a name like `"C4"`, `playMIDINote`, `stop`, `isPlaying`, `setVolume`, `setWaveform`, and a real `setADSR` / `setAttack` / `setDecay` / `setSustain` / `setRelease` | A repeat count above 1 plays once. Channels, effects (bitcrusher, ringmod, filters, overdrive, delay lines), sequences, tracks, instruments, LFOs, control signals, and microphone input. |

The synth builds the waveform sample by sample the first time it plays a note
and keeps it, so the same note is cheap after that.

### Input, crank, accelerometer

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| `buttonIsPressed`, `buttonJustPressed`, `buttonJustReleased`, `getButtonState`, the `keyPressed` and `keyReleased` callbacks, `getCrankPosition`, `getCrankChange`, `isCrankDocked` | **The button callbacks**: `AButtonDown`, `AButtonHeld`, `AButtonUp`, the same three for B, and `upButtonDown` / `upButtonUp` and friends for the d-pad; `cranked`, `crankDocked`, `crankUndocked`, `gameWillPause`, `gameWillResume`; `playdate.inputHandlers.push` and `pop`; `getCrankTicks`, and `startAccelerometer`, `stopAccelerometer`, `readAccelerometer`, `accelerometerIsRunning`, `getDeviceOrientation`, `getPitchAndRoll` | A real accelerometer. `readAccelerometer` always returns `0, 0, 1`, which is the device lying flat and face up. |

A game can answer a button by name rather than asking every frame:

```lua
function playdate.AButtonDown() player:jump() end
```

Playbit records which buttons are down but calls none of these, so a game
written that way used to sit there doing nothing. `build/shim/input.lua` calls
them once a frame, just before `playdate.update`, which is where the hardware
calls them. `gameWillPause` fires when the system menu opens.

Arrow keys are the d-pad, `S` is A and `A` is B. The crank is the scroll wheel,
and the starter maps `,` and `.` (or `Q` and `E`) to it as well. Middle clicking
docks and undocks the crank, so `isCrankDocked` is false unless you do that.

### ui

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| nothing, both files raise errors | `ui.crankIndicator`: `start`, `update`, `draw`, `resetAnimation`, `getBounds`, `clockwise`. It draws a bubble with a turning handle and the word crank, not the hardware animation | `ui.gridview`. Every method still raises an error from Playbit. Build a list out of sprites or draw it yourself. |

### Datastore, files, json

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| `datastore.write`, `datastore.read`, `datastore.delete`. `json.decode`, `json.decodeFile`. `file.load`, `file.open` with `read`, `readline`, `write`, `close`, `file.getSize` | `datastore.write` now accepts the pretty print argument instead of raising. `json.encode`, `json.encodePretty`, `json.encodeToFile`. `file.exists`, `file.isdir`, `file.mkdir`, `file.delete`, `file.listFiles`, `file.getType`, `file.modtime`, `file.rename` | `datastore.writeImage` and `datastore.readImage`, which would have to read pixels back. `file:seek`, `file:tell`, `file.run`. |

### Geometry

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| `point`, `size`, `rect`, `vector2D`, `lineSegment`, `polygon`, `arc`, `affineTransform`, `distanceToPoint`, `squaredDistanceToPoint` | nothing | `rect:containsRect`, `rect:flipRelativeToRect`, `polygon:containsPoint`, `polygon:getBounds`, `polygon:intersects`, the `lineSegment` intersection tests, `vector2D:projectAlong`, `vector2D:angleBetween`, `affineTransform:transformAABB`. |

### Display

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| nothing, there is no `playdate.display` | `getWidth`, `getHeight`, `getSize`, `getRect`, `setRefreshRate`, `getRefreshRate`, `setInverted`, `getInverted`, `setOffset`, `getOffset`, `flush`. `setRefreshRate` really does hold the game to that many frames a second, and `setInverted` really does swap the two colors | `setMosaic`, `setFlipped`, `loadImage`. `setMosaic`, `setFlipped`, `loadImage`. |

### System menu

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| nothing | `playdate.getSystemMenu`, `addMenuItem`, `addCheckmarkMenuItem`, `addOptionsMenuItem`, `removeMenuItem`, `removeAllMenuItems`, `getMenuItems`, and on each item `setTitle`, `getTitle`, `setValue`, `getValue`, `remove` | `playdate.setMenuImage`. The browser menu is a text list. |

Press `M` to open it. Up and down move, `S` (the A button) chooses, `A` (the B
button) or `M` again closes. The game is paused while it is open, the same as on
hardware.

### Tilemaps and pathfinder

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| `tilemap.new`, `setImageTable` | `setSize` that keeps the grid, `setTileAtPosition` and `getTileAtPosition` that agree about which cell is which, `setTiles`, `getTiles`, `getSize`, `getTileSize`, `getPixelSize`, `draw` with a source rect, `drawIgnoringOffset`, `getCollisionRects`, `gfx.sprite.addWallSprites`, `sprite:setTilemap` and `getTilemap` | nothing |

Playbit had the shape of the class and little else: `draw` asserted,
`getCollisionRects` and `getTiles` raised errors, `setSize` threw the grid away,
and `setTileAtPosition` indexed the grid with x times y, so the tile at (2, 3)
and the tile at (3, 2) were the same slot.

`getCollisionRects(emptyIDs)` groups the solid tiles into as few rectangles as
will cover them and returns them **in tile coordinates**, one based, the same as
`setTileAtPosition`. `gfx.sprite.addWallSprites(tilemap, emptyIDs, xOffset,
yOffset)` turns those into invisible collision sprites in pixels, which is how a
level's floors and pipes become something to stand on without one sprite per
block.

`playdate.pathfinder` warns and returns nil.

### Odds and ends

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| `getTime`, `getSecondsSinceEpoch`, `getCurrentTimeMilliseconds`, `playdate.string`, `playdate.metadata`, the `class` and `Object` system | `getElapsedTime`, `resetElapsedTime`, `getFPS`, `drawFPS`, `isSimulator`, `getReduceFlashing`, `getFlipped`, `getSystemLanguage`, `getPowerStatus`, `getBatteryPercentage`, `apiVersion`, `printTable`, `where`, `playdate.math.lerp`, `playdate.math.clamp`, and no-ops for `wait`, `stop`, `start`, `setAutoLockDisabled`, `setCollectsGarbage` and friends. Every `import("CoreLibs/...")` path now resolves, including `sprites`, `ui`, `math`, `animator`, `easing`, `keyboard`, `nineslice` and `qrcode`, so an import can no longer blank the screen before the game starts | `playdate.keyboard`, `playdate.nineSlice`, `generateQRCode`, `playdate.restart`, `playdate.getStats`. |

## Tested against SDK examples

`setup-sdk.sh` installs the Playdate SDK at `~/PlaydateSDK`, and its
`Examples/` folder is a good measure of whether real Playdate code runs here:
it is what Panic ships, written against the real API, with no idea a browser
exists. Copy one into `source/` and build it:

```bash
rm -f playdate/source/main.lua
cp -r ~/PlaydateSDK/Examples/Asheteroids/Source/. playdate/source/
bash playdate/dev-web.sh
```

(Keep `source/conf.lua` and `source/metadata.json`; the examples do not have
them. `git checkout playdate/source` puts the starter's own game back.)

These are the ones that have been through the browser build, and what had to
change for them:

| Example | Status | What was missing |
|---|---|---|
| **Asheteroids** | Plays | Everything about it failed at first. The `+=` operators, which plain Lua does not have; `polygon * transform` and `polygon:getBounds`, which Playbit raises errors for; `gfx.kColorClear`, which was nil, so `if colour == kColorClear then don't draw` matched an unset colour and the asteroids were invisible; a polygon outline whose first and last point are the same, which Love's mitre turns into a black wedge across the screen; a sprite's drawing clipped to its own bounds, without which every asteroid left a permanent trail; and the button callbacks, without which the ship could not be steered. |
| **FlippyFish** | Plays | Playdate `.fnt` fonts for the score, which Playbit cannot read. `image.width` and `image.height` as properties. `sprite:alphaCollision`, which now reads the file the image came from. `display.setInverted`, which needed the shader's two colours to be settings again rather than constants. |
| **Level 1-1** | Plays | Tilemaps, which were unusable: it draws two of them, edits one while playing, and builds its walls out of a third. `gfx.sprite.addWallSprites`. A collision normal that survives being reported by the other axis, and a sprite pushed out of a floor it starts a pixel inside, without which the player could stand but never walk. `setIgnoresDrawOffset`, without which the score scrolled away with the camera. `moveWithCollisions` taking a point, and a vector2D answering to `x` and `y`. Its `.wav` sounds and its `playdate.file` level loading already worked. |
| **SpriteCollisionMasks** | Plays | A `collisionResponse` set to a constant rather than a function; `getCollideBounds` returning four numbers rather than a rect. (The masks in its name are group masks, not image masks, so nothing here is out of reach.) |
| **2020** | Does not run | Not the browser's fault: the example asks for `images/x/1` and ships `images/explosion/1`. It fails the same way on hardware. |

Nothing tried so far is impossible in principle. The things that genuinely
cannot work in a browser are the ones that need to read pixels back off the
graphics card, listed under *Pixels only go one way* above: an example built on
`image:getMaskImage`, `datastore.writeImage` or `image:sample` would run but
draw the wrong thing. `alphaCollision` and `checkAlphaCollision` dodge that by
reading the `.png` the image was loaded from, so they are exact for artwork that
came from a file and warn once, counting the hit, for artwork drawn in code.
Examples with C in them (`C_API/Examples`) cannot be built here at all.

The SDK examples are Panic's, under their own licence, so none of them are
committed here. Copy one in from `~/PlaydateSDK/Examples` when you want to try
it.

## Checking it yourself

The shim has tests that run without a browser:

```
bash playdate/build/test/check.sh
```

That builds the web version, checks every shim file is Lua 5.1 (love.js runs
plain 5.1, so anything newer is a blank blue screen), parses every file, runs
the shim tests, and then runs the real game for sixty frames.
