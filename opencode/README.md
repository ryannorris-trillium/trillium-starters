# opencode: an AI coding partner in your terminal

opencode reads your project, answers questions about it, and can edit files for
you. You sign in with your own GitHub account. There is no key to paste.

## Set it up (once per codespace)

1. In the terminal, from your repo folder:  `bash opencode/setup.sh`
2. Open a **new** terminal: click the **+** in the terminal panel.
3. Type `opencode` and press Enter.
4. Type `/connect` and press Enter. Pick **GitHub Copilot**.
5. It shows a code like `8F43-6FCF`. Open **github.com/login/device** in a new tab,
   sign in, and type the code.
6. Back in opencode, type `/models` and pick a model. If one says it needs a
   higher plan, pick a different one.

## Using it

- Type what you want in plain words, then press Enter. Be specific:
  "In pygame/main.py, make the player stop at the edge of the screen."
- **Tab** switches between **Plan** and **Build**. Plan only reads and talks.
  Build can change your files. Start in Plan, agree on the idea, then switch to Build.
- Run your program after every change and check it does what you asked.
- Commit when something works: **Source Control → Commit → Sync Changes**.
- **Ctrl+C** twice, or `/exit`, closes opencode.

## Limits

opencode uses your GitHub Copilot allowance. The free Copilot plan only covers a
small number of requests each month. Students can get Copilot Pro free through
GitHub Education (education.github.com), which gives much more.

`AGENTS.md` in your repo tells opencode how to work with you. You can add your own
lines to it, like what your project is and what you have built so far.
