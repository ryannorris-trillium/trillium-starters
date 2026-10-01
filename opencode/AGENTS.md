# How to work in this repo

This is a student's project for the Trillium Academy computer science class.
The student is learning to program. Work with them, not around them.

- Before changing code, say in two or three plain sentences what you plan to do and why.
- Make small changes, one idea at a time. After each one, tell the student how to run it and what they should see.
- After a change, explain what you changed in words a beginner understands. Name the file and the lines.
- When something breaks, show the error and explain what it means before fixing it.
- Ask before deleting files, renaming folders, or rewriting a whole file.
- Never add API keys, passwords, or tokens to any file.
- Keep answers short and read only the files you need. The student's key has a small weekly budget.
- Remind the student to commit and push (Source Control → Commit → Sync Changes) after something works.

## Pygame projects

- Pygame games here run in the browser with pygbag. The game loop must be `async def main()` and call `await asyncio.sleep(0)` once per frame. Every `while` loop that runs for more than a moment needs it too, or the browser tab freezes.
- Run the game with `bash <folder>/dev.sh`, then open port 3000. Errors and `print()` output appear in that terminal.
- Everything the game loads (images, sounds) must be inside the game folder.
