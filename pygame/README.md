# Pygame in the browser

1. In the terminal, build it:  `pygbag --build pygame`
2. Serve the build:  `npx --yes serve -l 3000 pygame/build/web`
3. In the **Ports** tab, right-click port 3000 → **Port Visibility** → **Public**
   (one time; a private port blocks the game file from loading).
4. Click the globe icon on port 3000 to open it in a tab. Arrow keys move the circle.
5. Edit `main.py`, save, rerun step 1, refresh the tab. Ctrl+C stops the server.

Porting a game you already have: put your files in a folder, rename the
entry file to `main.py`, make the loop `async def main()` and add
`await asyncio.sleep(0)` inside the loop (see this file). That is the whole
change. Everything the game loads (images, sounds) must live inside the folder.

Why not `pygbag --port 3000` directly? Its test server rewrites the runtime
URLs to `localhost`, which a codespace tab cannot reach. Building then serving
the folder avoids that.
