# Pygame in the browser

1. In the terminal:  `bash pygame/dev.sh`
   It builds the game, starts the server on port 3000, and rebuilds every time you save.
2. In the **Ports** tab, right-click port 3000 → **Port Visibility** → **Public** (once).
3. Click the globe icon on port 3000 to open the game in a tab. Arrow keys move the circle.
4. Edit `main.py`, save, wait for "built" in the terminal, refresh the tab. Ctrl+C stops everything.

Debugging: keep this terminal next to the game tab. While `dev.sh` runs, your
`print()` lines and every error show up here. When the game crashes, the game
screen shows the file, the line, and the error instead of freezing. If the game
gets stuck in a loop, this terminal says so. That needs two lines in `main.py`,
already in this starter:

    import crashscreen
    asyncio.run(crashscreen.guard(main))    # the last line

Startup errors (a typo that stops the game before it opens) show up with
`SDL_VIDEODRIVER=dummy python3 pygame/main.py`.

Porting a game you already have: put your files in this folder, rename the
entry file to `main.py`, make the loop `async def main()` and add
`await asyncio.sleep(0)` inside the loop (see this file). That is the whole
change. Everything the game loads (images, sounds) must live inside the folder.

Manual version of what dev.sh does:  `pygbag --build pygame`, then
`npx --yes serve --listen 3000 pygame/build/web` in a second terminal.
