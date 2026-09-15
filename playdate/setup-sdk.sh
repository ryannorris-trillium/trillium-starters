#!/usr/bin/env bash
# Optional. Downloads Panic's Playdate SDK so you can build a real .pdx and run
# the official Simulator.  bash playdate/setup-sdk.sh
set -e
cd "$(dirname "$0")"

SDK="$HOME/PlaydateSDK"

if [ ! -x "$SDK/bin/pdc" ]; then
  echo "The Playdate SDK is Panic's software, under this license:"
  echo "  https://play.date/dev/sdk-license/"
  echo "Downloading it means you accept that license."
  read -r -p "Press Enter to accept and download, or Ctrl+C to stop: " _ < /dev/tty
  tmp="$(mktemp -d)"
  curl -L --progress-bar -o "$tmp/sdk.tar.gz" \
    https://download.panic.com/playdate_sdk/Linux/PlaydateSDK-latest.tar.gz
  mkdir -p "$SDK"
  tar -xzf "$tmp/sdk.tar.gz" -C "$SDK" --strip-components=1
  rm -rf "$tmp"
  echo "SDK installed in $SDK"
else
  echo "SDK already in $SDK"
fi

# Libraries the Simulator binary asks for. This list is the NEEDED entries in
# PlaydateSDK/bin/PlaydateSimulator, not a guess.
sudo apt-get update -qq
sudo apt-get install -y -qq \
  libgtk-3-0 libwebkit2gtk-4.1-0 libpng16-16 libunwind8 \
  libudev1 libxkbcommon0 libx11-6 libgl1

# pdc reads this to find the SDK.
if ! grep -q PLAYDATE_SDK_PATH "$HOME/.bashrc" 2>/dev/null; then
  echo "export PLAYDATE_SDK_PATH=\$HOME/PlaydateSDK" >> "$HOME/.bashrc"
  echo "export PATH=\"\$HOME/PlaydateSDK/bin:\$PATH\"" >> "$HOME/.bashrc"
fi

echo
echo "Done. Now run: bash playdate/build-device.sh"
