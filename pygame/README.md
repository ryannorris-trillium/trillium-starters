# Pygame in the browser

1. In the terminal: `pygbag --port 3000 pygame`
2. When the "port 3000" notification appears, click **Open in Browser**.
3. Arrow keys move the circle. Edit `main.py`, save, and refresh the tab.

Porting a game you already have: put your files in a folder, rename the
entry file to `main.py`, make the loop `async def main()` and add
`await asyncio.sleep(0)` inside the loop (see this file). That is the whole
change. `pygbag` needs everything the game loads (images, sounds) to live
inside the folder you give it.
