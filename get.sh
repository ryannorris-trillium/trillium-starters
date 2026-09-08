#!/usr/bin/env bash
# Copy one starter from the class starters repo into the current repository.
#   bash <(curl -s https://raw.githubusercontent.com/ryannorris-trillium/trillium-starters/main/get.sh) love
# Available: love · pygame · web-canvas · terminal-python
set -e
name="${1:?usage: get.sh <starter-name>}"
repo="https://github.com/ryannorris-trillium/trillium-starters"
if [ -e "$name" ]; then echo "A folder named '$name' already exists here. Rename it first."; exit 1; fi
tmp="$(mktemp -d)"
curl -sL "$repo/archive/refs/heads/main.tar.gz" | tar -xz -C "$tmp"
src="$tmp/trillium-starters-main/$name"
if [ ! -d "$src" ]; then echo "No starter called '$name'. Available:"; ls "$tmp/trillium-starters-main" | grep -v -E '^(get.sh|README.md)$'; exit 1; fi
cp -r "$src" "./$name"
rm -rf "$tmp"
echo "Added ./$name — open $name/README.md for how to run it."
