# Pygame in the browser

1. In the terminal:  `bash pygame/dev.sh`
   It builds the game, starts the server on port 3000, and rebuilds every time you save.
2. In the **Ports** tab, right-click port 3000 → **Port Visibility** → **Public** (once).
3. Click the globe icon on port 3000 to open the game in a tab. Arrow keys move the circle.
4. Edit `main.py`, save, wait for "built" in the terminal, refresh the tab. Ctrl+C stops everything.

Debugging: run the game with no window right in the terminal,
`SDL_VIDEODRIVER=dummy python3 pygame/main.py`, and read your `print()` lines
and error messages there. Build for the browser to check how it feels.

Porting a game you already have: put your files in this folder, rename the
entry file to `main.py`, make the loop `async def main()` and add
`await asyncio.sleep(0)` inside the loop (see this file). That is the whole
change. Everything the game loads (images, sounds) must live inside the folder.

Manual version of what dev.sh does:  `pygbag --build pygame`, then
`npx --yes serve --listen 3000 pygame/build/web` in a second terminal.
