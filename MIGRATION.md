# MIGRATION.md — fresh-clone / Linux rebuild notes

Written 2026-09-21 during the Windows-to-Ubuntu migration pass. This repo is
the **class starters catalog** — a grab-bag of extra starting points
(`pygame`, `love`, `playdate`, `web-canvas`, `terminal-python`, `hunt`,
`madlibs`, `showdown`) that students pull one at a time into their own
`trillium-starter`-based Codespace with `get.sh` (installed as the `get`
command on first use). It has no `.devcontainer` of its own — it relies on
being copied into a Codespace already running the toolchain declared in the
sibling `trillium-starter` repo (Python 3.12 + Node LTS + pygame/pygbag).

## Clone

```
git clone https://github.com/ryannorris-trillium/trillium-starters.git
```

Repo is **public** (verified via unauthenticated `curl` returning HTTP 200),
so cloning needs no credentials. Students never clone it directly — `get.sh`
fetches it as a tarball of `main` (`archive/refs/heads/main.tar.gz`).

## Credential note (push only)

Remote is `https://ryannorris-trillium@github.com/...` — same school GitHub
account as `trillium-starter` (`ryannorris-trillium`, not personal
`ryannorris14`). **On the new Ubuntu machine there is no credential helper
entry for `ryannorris-trillium` yet** — set up `gh auth login` as that account
(or a stored PAT) before pushing to this repo or `trillium-starter`. No
secret values are recorded in this migration pass.

## Toolchain / runtimes referenced by the starters

- **Python 3.12** (matches the template's devcontainer pin) — used by
  `hunt/`, `madlibs/`, `terminal-python/`, `showdown/`, and as the pygbag
  build tool for `pygame/`.
- **Node.js** — every browser-based starter (`pygame`, `love`, `playdate`,
  `web-canvas`) shells out to `npx --yes serve` and/or `npx --yes love.js` at
  runtime. No `package.json`/lockfile anywhere in this repo — npx fetches
  packages on demand each run, so a fresh machine needs internet access at
  first run of any of these scripts, not a pre-install step.
- **`playdate/` (heaviest toolchain):**
  - `lua5.4` and `zip` (apt-installed on demand by `dev-web.sh` if missing).
  - Playbit (`GamesRightMeow/playbit`) is git-cloned into `playdate/playbit/`
    on first run, pinned to commit `1b66259e093f3f2612414f61b5810be29989e7b8`
    in `dev-web.sh` — bump deliberately, not accidentally.
  - `npx --yes love.js` converts the packaged `.love` to a browser build.
  - Optional real-hardware path (`setup-sdk.sh` / `build-device.sh`) downloads
    Panic's Playdate SDK tarball for Linux and needs
    `libpng16-16 zlib1g libstdc++6` (compiler) or additionally
    `libgtk-3-0 libwebkit2gtk-4.1-0 libunwind8 libudev1 libxkbcommon0 libx11-6
    libgl1` (`--with-simulator`, desktop-only).
- **`love/`** needs only `zip` + `npx love.js` + `npx serve` (no extra deps).
- **`showdown/`** is plain Python + `unittest`, no external packages.

## Verification after a fresh clone/rebuild

1. `git log --oneline -5` on `main` should show `78f804c` at HEAD (or later);
   branch `playdate-menu-wip` should show `aad67d9` (paused WIP, see below).
2. `git status --short --ignored` — expect exactly one ignored entry,
   `playdate/build/__pycache__/`. Nothing else should be untracked.
3. Smoke-test a couple of starters from inside a Codespace built from
   `trillium-starter`: `get pygame` then `bash pygame/dev.sh`; `get love` then
   `bash love/build.sh`; `get playdate` then `bash playdate/dev-web.sh`
   (slowest — clones Playbit and apt-installs `lua5.4`/`zip` on first run).
4. `showdown`: `cd showdown && python3 -m unittest -v` — some tests are
   *expected* to fail (that's the point of the exercise); confirm the test
   runner itself works.
5. `git ls-files --eol` — every tracked file's git blob is `i/lf` (LF), which
   is what matters for a Linux checkout; this held true for every `.sh`,
   `.py`, and `.lua` file at scan time even though several show `w/crlf` on
   this Windows checkout (that's local `core.autocrlf` conversion on
   Ryan's Windows box, not a repo problem — a Linux clone will check out LF).

## Known issues / things needing Ryan's attention

- **`showdown/__pycache__/*.pyc` files are committed to git** (three `.pyc`
  files, compiled under Python 3.14 despite the class pin being 3.12). There
  is no root-level `.gitignore` in this repo (only `playdate/.gitignore`
  exists) so nothing stops this from happening again. Recommend adding a root
  `.gitignore` with `__pycache__/` and `*.pyc`, and removing the three
  committed `.pyc` files, in a future housekeeping pass — left untouched here
  since it's pre-existing tracked content, not an uncommitted change.
- **Branch `playdate-menu-wip`** (pushed, `aad67d9`, 1 commit ahead of
  `main`): untested edge-triggered A/B button handling + system menu item
  work, paused 2026-09-16 per Ryan's decision (Hazel moved to her own
  computer + the real SDK, so the browser emulator work was no longer
  urgent). Known open bugs if resumed: A/S buttons do nothing in
  `examples/sprites`-style Level 1-1 ports, and the `M` system menu draws
  offset with no visible items (needs an origin/offset reset). Full detail in
  the trillium-physics repo's agent memory:
  `.claude/agent-memory/project_cs_demo_codespace.md`.
- No CLAUDE.md or Claude agent-memory directory exists in this repo itself.

## Cross-reference

Sibling repo `trillium-starter` (separate remote, separate manifest) is the
per-student template these starters get copied into. Broader CS-class context
(demo codespace is a *third*, separate repo, `ryannorris-trillium/trillium-test`,
not either of these) and the full love.js/Lua-in-browser constraint list live
in the trillium-physics repo's agent memory:
`.claude/agent-memory/project_cs_demo_codespace.md` and
`.claude/agent-memory/reference_browser_lua_limits.md`.
