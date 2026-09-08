#!/usr/bin/env bash
# Package this folder as a .love file, convert it to a web build with love.js,
# and serve it on port 3000. Run from inside the love/ folder:  bash build.sh
set -e
cd "$(dirname "$0")"
command -v zip >/dev/null || sudo apt-get install -y -q zip >/dev/null
rm -f game.love && zip -9 -r -q game.love . -x 'build.sh' 'web/*' 'game.love' 'README.md'
rm -rf web
npx --yes love.js -c -t "Trillium LÖVE" game.love web
echo "Serving on port 3000 — open it in the browser (Ctrl+C to stop)."
npx --yes serve --listen 3000 web
