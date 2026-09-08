#!/usr/bin/env bash
# Build the game, serve it on port 3000, then rebuild automatically every time a
# file in this folder changes. You only refresh the browser tab.
#   bash pygame/dev.sh        (Ctrl+C stops both the watcher and the server)
set -u
cd "$(dirname "$0")"
folder="$(basename "$PWD")"
cd ..

build() { pygbag --build "$folder" >/tmp/pygbag-build.log 2>&1 && echo "built $(date +%H:%M:%S) — refresh the tab" || { echo "build failed:"; tail -20 /tmp/pygbag-build.log; }; }
snapshot() { find "$folder" -path "$folder/build" -prune -o -type f \( -name '*.py' -o -name '*.png' -o -name '*.jpg' -o -name '*.wav' -o -name '*.ogg' -o -name '*.txt' -o -name '*.json' \) -print0 | xargs -0 md5sum 2>/dev/null | md5sum; }

build
npx --yes serve --listen 3000 "$folder/build/web" >/tmp/serve.log 2>&1 &
server=$!
trap 'kill $server 2>/dev/null; exit 0' INT TERM
echo "serving on port 3000 (Ports tab → right-click 3000 → Port Visibility → Public, then open it)"
echo "watching $folder/ for changes…"
last="$(snapshot)"
while kill -0 $server 2>/dev/null; do
  sleep 2
  now="$(snapshot)"
  if [ "$now" != "$last" ]; then last="$now"; build; fi
done
