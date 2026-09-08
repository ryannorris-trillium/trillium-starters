# LÖVE (Lua) in the browser

1. In the terminal: `bash love/build.sh`
2. When the "port 3000" notification appears, click **Open in Browser**.
3. Arrow keys move the circle. Edit `main.lua`, save, rerun `bash love/build.sh`, refresh the tab.

`main.lua` is ordinary LÖVE: `love.update(dt)` and `love.draw()`. The build
script zips the folder into `game.love`, converts it with `love.js`, and
serves the result. Balatro mods are written in this same language for this
same engine, so this is the place to practice before touching a real mod.

If the tab opens but nothing loads: in the **Ports** tab, right-click port 3000 → **Port Visibility** → **Public**, then refresh. A private port blocks the page's own file requests.
