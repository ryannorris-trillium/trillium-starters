# opencode: an AI coding partner in your terminal

opencode reads your project, answers questions about it, and can edit files for
you. Ryan gives you a key that pays for it. The key has a small budget that
refills, so use it for real questions, not chit-chat.

## Set it up (once per codespace)

1. In the terminal, from your repo folder:  `bash opencode/setup.sh`
2. Open a **new** terminal: click the **+** in the terminal panel.
3. Type `opencode` and press Enter.
4. Type `/connect` and press Enter. Type `openrouter` and pick **OpenRouter**.
5. Paste the key Ryan gave you (it starts with `sk-or-`) and press Enter.

That's it. The model is already chosen for you in `opencode.json`.

**Your key is private.** Never paste it into a file, a commit, or a chat with
someone else. opencode keeps it outside your repo, so committing is safe.

## Using it

- Type what you want in plain words, then press Enter. Be specific:
  "In pygame/main.py, make the player stop at the edge of the screen."
- **Tab** switches between **Plan** and **Build**. Plan only reads and talks.
  Build can change your files. Start in Plan, agree on the idea, then switch to Build.
- Run your program after every change and check it does what you asked.
- Commit when something works: **Source Control → Commit → Sync Changes**.
- `/new` starts a fresh conversation. Do this when you switch tasks. Long
  conversations use up your budget faster.
- **Ctrl+C** twice, or `/exit`, closes opencode.

## If it stops answering

If opencode says your key is out of credit, your budget for the week is used up.
Tell Ryan, or wait for it to refill.

`AGENTS.md` in your repo tells opencode how to work with you. You can add your own
lines to it, like what your project is and what you have built so far.
