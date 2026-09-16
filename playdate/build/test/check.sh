#!/usr/bin/env bash
# Everything that can be checked without a browser.
#   bash playdate/build/test/check.sh
#
# Builds the web version, then: Lua 5.1 audit, parse check, shim tests,
# and a run of the real game for sixty frames.
set -e
cd "$(dirname "$0")/../.."

LUA=${LUA:-lua5.4}
LUAC=${LUAC:-luac5.4}

echo "== Lua 5.1 audit =="
python3 build/test/lua51-audit.py build/shim build/entry.lua

echo
echo "== build =="
$LUA build/web.lua
python3 build/lua51-continue.py _web

echo
echo "== parse check =="
if command -v "$LUAC" >/dev/null; then
  find _web -name '*.lua' -print0 | xargs -0 "$LUAC" -p
  echo "every file in _web parses"
else
  echo "skipped, $LUAC not installed"
fi

echo
echo "== shim tests =="
$LUA build/test/run.lua _web

echo
echo "== game smoke test =="
$LUA build/test/smoke.lua _web
