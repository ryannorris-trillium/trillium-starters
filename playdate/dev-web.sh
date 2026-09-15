#!/usr/bin/env bash
# Build the Playdate game for the browser and serve it on port 3000.
#   bash playdate/dev-web.sh
set -e
cd "$(dirname "$0")"

# Pinned so everyone in the class gets the same version.
PLAYBIT_COMMIT=1b66259e093f3f2612414f61b5810be29989e7b8

# Tools: lua runs Playbit's build script, zip makes the .love file.
if ! command -v lua5.4 >/dev/null || ! command -v zip >/dev/null; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq lua5.4 zip
fi

# Playbit is the Playdate API rewritten in Love2D, plus the build system
# that strips the Playdate-only parts out of your code.
if [ ! -d playbit ]; then
  echo "Downloading Playbit (first run only)..."
  git clone -q https://github.com/GamesRightMeow/playbit.git playbit
  git -C playbit checkout -q "$PLAYBIT_COMMIT"
  git -C playbit submodule update -q --init --recursive
fi

# source/ -> _web/, a plain Love2D project
lua5.4 build/web.lua

# The browser runs plain Lua 5.1, which has no `goto`. Playbit uses
# `goto continue` in a few loops; this rewrites them into the Lua 5.1 form.
python3 build/lua51-continue.py _web

# Lua 5.1 in the browser also has no `bit` library; give Playbit the two
# functions it uses.
cat build/bit51.lua _web/main.lua > _web/main.lua.new && mv _web/main.lua.new _web/main.lua

# Love2D in a browser runs on WebGL 1, which is stricter than a desktop
# graphics card. Four edits keep Playbit's shader compiling there: drop the
# GLSL 3 line, drop the "f" on numbers like 0.45f, make the two colors
# constants instead of settable values, and compare floats to 0.0 not 0.
sed -i -e '/#pragma language glsl3/d' \
       -e 's/\([0-9]\)f\b/\1/g' \
       -e 's/^extern \(vec4 white = .*\)/const \1/' \
       -e 's/^extern \(vec4 black = .*\)/const \1/' \
       -e 's/\.a > 0)/.a > 0.0)/g' \
       -e 's/if (pattern\[x + y \* 8\] == 1) {/int idx = x + y * 8; int pv = 0; for (int i = 0; i < 64; i++) { if (i == idx) pv = pattern[i]; }\n    if (pv == 1) {/' \
       _web/playdate/shader
# The last edit matters most: WebGL 1 refuses "pattern[x + y * 8]" because a
# fragment shader may only index an array with a constant or a loop counter
# ("Index expression can only contain const or loop symbols"). Walking the
# array with a loop and picking the matching entry is the standard workaround.

# _web/ -> game.love -> web/, a page the browser can run
rm -f game.love
(cd _web && zip -9 -r -q ../game.love .)
rm -rf web
npx --yes love.js -c -t "Trillium Playdate" game.love web

echo "Serving on port 3000. Ctrl+C stops it."
npx --yes serve --listen 3000 web
