#!/usr/bin/env bash
# Optional. Downloads Panic's Playdate SDK so you can build a real .pdx.
#   bash playdate/setup-sdk.sh                   # just the compiler (pdc)
#   bash playdate/setup-sdk.sh --with-simulator  # also the desktop Simulator
set -e
cd "$(dirname "$0")"

SDK="$HOME/PlaydateSDK"
WITH_SIM=0
[ "${1:-}" = "--with-simulator" ] && WITH_SIM=1

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

# Only the compiler is needed to make a .pdx you can put on a real Playdate.
# These three are almost always present already, so this usually installs
# nothing and skips the slow apt update.
need_pdc="libpng16-16 zlib1g libstdc++6"
# The Simulator is a desktop program and drags in GTK and WebKit, which is a
# few hundred megabytes. Only --with-simulator asks for them.
need_sim="libgtk-3-0 libwebkit2gtk-4.1-0 libunwind8 libudev1 libxkbcommon0 libx11-6 libgl1"

wanted="$need_pdc"
[ "$WITH_SIM" = 1 ] && wanted="$wanted $need_sim"

missing=""
for p in $wanted; do
  dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "^install ok installed$" || missing="$missing $p"
done

if [ -n "$missing" ]; then
  echo "Installing:$missing"
  sudo apt-get update -qq
  # shellcheck disable=SC2086
  sudo apt-get install -y -qq $missing || echo "Some packages would not install. Keep going and see what ldd says below."
else
  echo "All needed libraries are already installed."
fi

# The real check: ask the compiler binary itself what it is still missing.
if ldd "$SDK/bin/pdc" 2>/dev/null | grep -q "not found"; then
  echo
  echo "pdc is still missing these libraries:"
  ldd "$SDK/bin/pdc" | grep "not found" | sed 's/^/  /'
  echo "Tell Ryan what this says."
  exit 1
fi
echo "pdc has every library it needs."

# pdc reads this to find the SDK.
if ! grep -q PLAYDATE_SDK_PATH "$HOME/.bashrc" 2>/dev/null; then
  echo "export PLAYDATE_SDK_PATH=\$HOME/PlaydateSDK" >> "$HOME/.bashrc"
  echo "export PATH=\"\$HOME/PlaydateSDK/bin:\$PATH\"" >> "$HOME/.bashrc"
fi

echo
echo "Done. Now run: bash playdate/build-device.sh"
