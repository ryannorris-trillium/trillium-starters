#!/usr/bin/env bash
# Optional. Compiles the same source/ into game.pdx, the format a real Playdate
# and the official Simulator read.  bash playdate/build-device.sh
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

if [ -n "$DISPLAY" ]; then
  "$SDK/bin/PlaydateSimulator" game.pdx &
  echo "Opened the Simulator. Look at the desktop tab on port 6080."
else
  echo "No desktop here, so the Simulator cannot open. See README.md,"
  echo "the section about the desktop codespace."
fi
