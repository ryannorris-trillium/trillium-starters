# Playdate (Lua) in the browser

Real Playdate code, written the way the Playdate SDK wants it, running in a
browser tab. One file to edit: `source/main.lua`.

1. In the terminal: `bash playdate/dev-web.sh`
   The first run downloads a few things and takes a minute or two.
2. When the "port 3000" notification appears, click **Open in Browser**.
3. Arrow keys move the circle. Touch the square to score. Hold `,` and `.` to
   turn the crank, which swings the needle. `Q` and `E` do the same thing.

Edit `source/main.lua`, save, press Ctrl+C in the terminal, run
`bash playdate/dev-web.sh` again, refresh the tab.

If the tab opens but nothing loads: in the **Ports** tab, right-click port 3000
→ **Port Visibility** → **Public**, then refresh.

If you get a blue error screen instead of the game, the message on it is a real
Lua error. Read the top line, fix `source/main.lua`, run the script again.

## What you are actually writing

`source/main.lua` is Playdate Lua. `playdate.update()` runs once per frame,
`playdate.graphics` draws, `playdate.buttonIsPressed` reads the d-pad, and
`playdate.getCrankPosition()` reads the crank. The same file compiles for a real
Playdate, which is what `build-device.sh` below does.

The screen is 400 by 240 pixels and every pixel is black or white. No greys, no
color. That constraint is the whole point of the machine.

The browser version runs on [Playbit](https://github.com/GamesRightMeow/playbit),
which rewrites the Playdate API on top of Love2D so it can run anywhere. Playbit
covers drawing, buttons, the crank, images, and fonts. It does not cover
sprites, so `playdate.graphics.sprite` will not work here. Draw with shapes.

A real Playdate has a crank on its side. A Chromebook does not, so the block at
the bottom of `source/main.lua` turns `,` and `.` into crank rotation for the
browser. That block is marked `!if LOVE2D`, which means the build system deletes
it when it compiles for the real hardware.

## Make it yours

Do one step, run it, then do the next. If it breaks, read the last line of the
error in the terminal.

### Step 1. Change the shapes

`fillCircleAtPoint(x, y, radius)` draws the player and `fillRect(x, y, w, h)`
draws the target. Swap them. Try `drawCircleAtPoint` and `drawRect` for outlines
instead of solid shapes. Change `player.r` and `target.size`.

### Step 2. Add a second target

Copy the `target` table into a `target2` table with different starting numbers,
copy the distance check, and draw it. Two squares, two ways to score.

### Step 3. Steer with the crank

Right now the crank only turns the needle. Make it steer instead: use `angle` to
move the player forward every frame while the A button is held.

```lua
if playdate.buttonIsPressed(playdate.kButtonA) then
  player.x = player.x + math.sin(angle) * speed
  player.y = player.y - math.cos(angle) * speed
end
```

In the browser the A button is the `s` key and B is the `a` key.

### Step 4. Add a timer

Count frames in a variable, add one each `playdate.update()`, and draw
`30 - math.floor(frames / 30)` in the corner as seconds left. The Playdate runs
at 30 frames per second. When it hits zero, stop adding to the score.

Then commit: Source Control, message `playdate game`, Commit, Sync Changes.

## Optional: put it on a real Playdate

You do not need a Playdate for any of the above. If Ryan has one in the room:

```
bash playdate/setup-sdk.sh      # once, downloads Panic's SDK
bash playdate/build-device.sh   # makes the file the Playdate wants
```

`setup-sdk.sh` prints Panic's SDK license and waits for you to accept it. It
installs only the compiler, which is a small download. Add `--with-simulator`
if you also want the desktop Simulator, which is much bigger.

`build-device.sh` compiles `source/main.lua` into `playdate/game.pdx` and then
packs that into `playdate/dist/<your-repo-name>.pdx.zip`. That zip is the file
you upload.

Sign in at [play.date](https://play.date), go to your Account page, then
**Sideload**, and upload the zip. On the Playdate, open **Game Library** and
refresh the list. On older Playdate system software it is **Settings** then
**Games** instead.

### From a school Chromebook

A school Chromebook blocks downloads, so you cannot save the zip out of the
codespace. Send it through Google Drive instead.

1. Build it: `bash playdate/build-device.sh`
2. Commit and sync the zip. The script prints the exact command, and Source
   Control works too: stage `playdate/dist`, Commit, Sync Changes.
3. Wait up to five minutes. A program on Ryan's computer watches your
   repository and copies the zip into a Drive folder shared with you.
4. Go to [play.date](https://play.date), sign in, then **Account** then
   **Sideload**.
5. Click the upload box. In the ChromeOS file picker, choose **Google Drive**
   in the left column, then **Shared with me**. The folder Ryan shared is in
   there, named either **Playdate builds** with your name inside it, or just
   your name. Open it and pick the `.pdx.zip`. If two zips are there, take the
   newest one. Ignore `latest.txt`, which only says when the zip arrived.
   Drive files can be picked for upload without downloading them, which is why
   this works.
6. On the Playdate, open **Game Library** and refresh the list. Your game
   appears under the name in `source/metadata.json`. On older Playdate system
   software the path is **Settings** then **Games** instead.

If step 5 shows no Drive option in the picker, tell Ryan. It means the folder
has not been shared with your school account yet.

For Ryan: share `Playdate builds/<Student>` in Drive with that student's school
account once, before they try this.

## Optional: the official simulator

Panic ships a Simulator that draws the real hardware around your game. It is a
desktop program, and a normal codespace has no desktop, so this needs a
different codespace.

1. On the repository page: **Code** → **Codespaces** → the **...** menu →
   **New with options...** → set **Dev container configuration** to
   **Trillium CS Starter (with desktop)** → **Create codespace**. An existing
   codespace cannot be switched over, so this has to be a new one.
2. In the **Ports** tab, set port **6080** to **Public**.
3. Open port 6080 in the browser. The password is `vscode`.
4. In the terminal: `bash playdate/setup-sdk.sh` then
   `bash playdate/build-device.sh`. The Simulator opens on the desktop tab.

In the Simulator, arrow keys are the d-pad, and the **Controls** menu lists the
key layouts for the A and B buttons. The crank is a control in the device panel
next to the screen; turn on **View** → **Show Accelerometer & Crank** if you do
not see it, then drag it with the mouse.
