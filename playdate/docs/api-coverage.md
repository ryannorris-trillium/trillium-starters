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

## The short version

| Area | State in the browser |
|------|----------------------|
| Drawing shapes and text | Works |
| Images | Works, no masks |
| Imagetables | Works |
| **Sprites and collisions** | **Works, added by the shim** |
| Animators, loops, blinkers | Works |
| Timers and frame timers | Works, replaced by the shim |
| Sound: players and a synth | Works, no effects or sequences |
| Buttons and crank | Works |
| Accelerometer | Always reports the device lying flat |
| Crank indicator | Works, drawn differently |
| gridview | Not available |
| Datastore and files | Works, saved in the browser |
| Display | Works |
| System menu | Works, press `M` |
| Geometry | Works |
| Pathfinder | Not available |
| json | Works |
| Tilemaps | Not available |

## Two things that are different everywhere

**Frame rate.** A Playdate runs at 30 frames a second. A browser tab draws at
whatever the screen does, usually 60. The shim skips the extra frames so a game
plays at the same speed in both places. `playdate.display.setRefreshRate(0)`
turns that off and lets it run flat out.

**Saved files.** `playdate.datastore` and `playdate.file` write into the
browser's storage for the page. That is not the same as a memory card. Closing
the tab, clearing site data, or opening the game from a different address can
lose it. On hardware the save is permanent.

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
| `image.new(width, height)`, `image.new(path)`, `draw` with flip and a source rect, `drawScaled`, `drawRotated`, `getSize` | A path with or without `.png`, and a message naming the file when it is not there; `copy`, `clear`, `drawCentered`, `drawAnchored`, `drawTiled`, `drawRotated` with a scale, `scaledImage`, `rotatedImage`, `imageSizeAtPath` | Masks: `setMaskImage`, `addMask`, `getMaskImage`, `clearMask` warn and do nothing. `drawFaded` draws at full strength. `drawBlurred`, `blendWithImage`, `drawSampled`, `sample`, `setInverted`, `invertedImage`, `vcrPauseFilterImage`. |

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
| One built in font, `font.new` for its own `.fnt` format, `drawText`, `drawTextAligned`, `drawTextInRect`, `getTextSize`, `setFont`, `getFont`, `getSystemFont` | nothing | Font families, tracking, leading adjustment, `getGlyph`, and the width, height, wrap mode and alignment arguments to `drawText`: passing them raises an error from Playbit. Use `drawTextInRect` or `drawTextAligned` instead. |

### Sound

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| `sampleplayer` and `fileplayer`, `.wav` only | Any file Love can read (`.wav`, `.ogg`, `.mp3`), with or without the extension in the path; `play(0)` to loop; `stop`, `pause`, `isPlaying`, `setVolume`, `getVolume`, `setRate`, `getLength`, `copy`, `setOffset`; a silent stand in plus one warning when the file is missing; `sound.sample`; `sound.synth` with sine, square, sawtooth, triangle and noise, `playNote` taking a frequency, a MIDI number or a name like `"C4"`, `playMIDINote`, `stop`, `isPlaying`, `setVolume`, `setWaveform` | A repeat count above 1 plays once. ADSR and envelope settings are accepted and ignored. Channels, effects (bitcrusher, ringmod, filters, overdrive, delay lines), sequences, tracks, instruments, LFOs, control signals, and microphone input. |

The synth builds the waveform sample by sample the first time it plays a note
and keeps it, so the same note is cheap after that.

### Input, crank, accelerometer

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| `buttonIsPressed`, `buttonJustPressed`, `buttonJustReleased`, `getButtonState`, the `keyPressed` and `keyReleased` callbacks, `getCrankPosition`, `getCrankChange`, `isCrankDocked` | `getCrankTicks`, and `startAccelerometer`, `stopAccelerometer`, `readAccelerometer`, `accelerometerIsRunning`, `getDeviceOrientation`, `getPitchAndRoll` | A real accelerometer. `readAccelerometer` always returns `0, 0, 1`, which is the device lying flat and face up. |

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
| `datastore.write`, `datastore.read`, `datastore.delete`. `json.decode`, `json.decodeFile`. `file.load`, `file.open` with `read`, `readline`, `write`, `close`, `file.getSize` | `datastore.write` now accepts the pretty print argument instead of raising. `json.encode`, `json.encodePretty`, `json.encodeToFile`. `file.exists`, `file.isdir`, `file.mkdir`, `file.delete`, `file.listFiles`, `file.getType`, `file.modtime`, `file.rename` | `datastore.writeImage`, `datastore.readImage`, `file:seek`, `file:tell`, `file.run`. |

### Geometry

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| `point`, `size`, `rect`, `vector2D`, `lineSegment`, `polygon`, `arc`, `affineTransform`, `distanceToPoint`, `squaredDistanceToPoint` | nothing | `rect:containsRect`, `rect:flipRelativeToRect`, `polygon:containsPoint`, `polygon:getBounds`, `polygon:intersects`, the `lineSegment` intersection tests, `vector2D:projectAlong`, `vector2D:angleBetween`, `affineTransform:transformAABB`. |

### Display

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| nothing, there is no `playdate.display` | `getWidth`, `getHeight`, `getSize`, `getRect`, `setRefreshRate`, `getRefreshRate`, `setInverted`, `getInverted`, `setOffset`, `getOffset`, `flush`. `setRefreshRate` really does hold the game to that many frames a second, and `setInverted` really does swap the two colors | `setScale` is stored and ignored: the browser always draws at 1x. `setMosaic`, `setFlipped`, `loadImage`. |

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
| `tilemap.new`, `setImageTable`, `setSize`, `setTileAtPosition`, `getTileAtPosition`, `setTiles`, `getTileSize`, `getSize`, `getPixelSize` | nothing | `tilemap:draw`, `tilemap:drawIgnoringOffset`, `tilemap:getTiles` and `tilemap:getCollisionRects` all raise an error, which leaves tilemaps unusable. Draw tiles with a loop of `image:draw` instead. `playdate.pathfinder` warns and returns nil. |

### Odds and ends

| Playbit has | The shim adds | Not available in the browser |
|---|---|---|
| `getTime`, `getSecondsSinceEpoch`, `getCurrentTimeMilliseconds`, `playdate.string`, `playdate.metadata`, the `class` and `Object` system | `getElapsedTime`, `resetElapsedTime`, `getFPS`, `drawFPS`, `isSimulator`, `getReduceFlashing`, `getFlipped`, `getSystemLanguage`, `getPowerStatus`, `getBatteryPercentage`, `apiVersion`, `printTable`, `where`, `playdate.math.lerp`, `playdate.math.clamp`, and no-ops for `wait`, `stop`, `start`, `setAutoLockDisabled`, `setCollectsGarbage` and friends. Every `import("CoreLibs/...")` path now resolves, including `sprites`, `ui`, `math`, `animator`, `easing`, `keyboard`, `nineslice` and `qrcode`, so an import can no longer blank the screen before the game starts | `playdate.keyboard`, `playdate.nineSlice`, `generateQRCode`, `playdate.restart`, `playdate.getStats`. |

## Checking it yourself

The shim has tests that run without a browser:

```
bash playdate/build/test/check.sh
```

That builds the web version, checks every shim file is Lua 5.1 (love.js runs
plain 5.1, so anything newer is a blank blue screen), parses every file, runs
the shim tests, and then runs the real game for sixty frames.
