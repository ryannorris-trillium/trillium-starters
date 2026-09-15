#!/usr/bin/env bash
# Optional. Compiles the same source/ into game.pdx, the format a real Playdate
# and the official Simulator read, then zips it into playdate/dist/ so you can
# commit it.  bash playdate/build-device.sh
set -e
cd "$(dirname "$0")"

SDK="${PLAYDATE_SDK_PATH:-$HOME/PlaydateSDK}"
if [ ! -x "$SDK/bin/pdc" ]; then
  echo "No Playdate SDK found. Run: bash playdate/setup-sdk.sh"
  exit 1
fi
if [ ! -d playbit ]; then
  echo "Run bash playdate/dev-web.sh first. It downloads Playbit and Lua."
  exit 1
fi
export PLAYDATE_SDK_PATH="$SDK"

# source/ -> _pdx/ (plain Playdate Lua), then _pdx/ -> game.pdx
lua5.4 build/device.lua
rm -rf game.pdx
"$SDK/bin/pdc" _pdx game.pdx
echo "Built playdate/game.pdx"

# Name the zip after the repository so every student's file is distinct in the
# shared Drive folder. Same name every build, so it overwrites cleanly.
repo="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo game)")"
repo="$(printf '%s' "$repo" | tr -c 'A-Za-z0-9._-' '-')"
[ -n "$repo" ] || repo=game
zip_path="dist/$repo.pdx.zip"

mkdir -p dist
rm -f "$zip_path"
if command -v zip >/dev/null 2>&1; then
  zip -q -r "$zip_path" game.pdx
else
  python3 -c "import shutil,sys; shutil.make_archive(sys.argv[1][:-4], 'zip', '.', 'game.pdx')" "$zip_path"
fi
echo "Packed playdate/$zip_path"

# Some repositories ignore any folder called dist/. If this one does, the file
# will not commit unless it is forced in, so say so instead of failing quietly.
forced=""
if git -C . check-ignore -q "$zip_path" 2>/dev/null; then forced="-f "; fi

echo
echo "Next, put it in your repository:"
echo "  git add ${forced}playdate/dist && git commit -m \"playdate build\" && git push"
echo "or use Source Control: stage playdate/dist, Commit, then Sync Changes."
echo "Then see the Chromebook section of playdate/README.md."

if [ -n "$DISPLAY" ] && [ -x "$SDK/bin/PlaydateSimulator" ]; then
  "$SDK/bin/PlaydateSimulator" game.pdx &
  echo "Opened the Simulator. Look at the desktop tab on port 6080."
elif [ -n "$DISPLAY" ]; then
  echo "No Simulator binary. Run: bash playdate/setup-sdk.sh --with-simulator"
else
  echo "No desktop here, so the Simulator cannot open. See README.md,"
  echo "the section about the desktop codespace."
fi
