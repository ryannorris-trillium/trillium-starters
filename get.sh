#!/usr/bin/env bash
# Copy one starter from the class starters repo into the current repository.
#   bash <(curl -s https://raw.githubusercontent.com/ryannorris-trillium/trillium-starters/main/get.sh) love
# Available: hunt · love · pygame · web-canvas · terminal-python
set -e
name="${1:-}"
if [ -z "$name" ]; then
  echo "Which starter? hunt  terminal-python  pygame  web-canvas  love"
  read -r -p "Type one and press Enter: " name < /dev/tty
fi
repo="https://github.com/ryannorris-trillium/trillium-starters"
update=0
if [ -e "$name" ]; then update=1; echo "Folder '$name' already exists — adding any new starter files, keeping yours."; fi
tmp="$(mktemp -d)"
curl -sL "$repo/archive/refs/heads/main.tar.gz" | tar -xz -C "$tmp"
src="$tmp/trillium-starters-main/$name"
if [ ! -d "$src" ]; then echo "No starter called '$name'. Available:"; ls "$tmp/trillium-starters-main" | grep -v -E '^(get.sh|README.md)$'; exit 1; fi
if [ "$update" = 1 ]; then
  added=0
  while IFS= read -r -d '' f; do
    rel="${f#$src/}"
    if [ ! -e "$name/$rel" ]; then mkdir -p "$(dirname "$name/$rel")"; cp "$f" "$name/$rel"; echo "  added $name/$rel"; added=$((added+1)); fi
  done < <(find "$src" -type f -print0)
  [ "$added" = 0 ] && echo "  nothing new — your $name/ already has every starter file."
else
  cp -r "$src" "./$name"
  echo "Added ./$name — open $name/README.md for how to run it."
fi
rm -rf "$tmp"
