#!/usr/bin/env bash
# Installs opencode in this codespace and puts the class AGENTS.md in your repo.
#   bash opencode/setup.sh
set -e
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(git -C "$here" rev-parse --show-toplevel 2>/dev/null || dirname "$here")"

if command -v opencode >/dev/null 2>&1 || [ -x "$HOME/.opencode/bin/opencode" ]; then
  echo "opencode is already installed."
else
  echo "Installing opencode (about 30 seconds)…"
  curl -fsSL https://opencode.ai/install | bash >/tmp/opencode-install.log 2>&1 || { echo "Install failed:"; tail -20 /tmp/opencode-install.log; exit 1; }
fi
case ":$PATH:" in *":$HOME/.opencode/bin:"*) ;; *)
  grep -q '.opencode/bin' "$HOME/.bashrc" 2>/dev/null || echo 'export PATH="$HOME/.opencode/bin:$PATH"' >> "$HOME/.bashrc";;
esac

if [ -e "$repo/AGENTS.md" ]; then
  echo "Your repo already has an AGENTS.md. Leaving it alone."
else
  cp "$here/AGENTS.md" "$repo/AGENTS.md"
  echo "Added AGENTS.md to $repo (opencode reads it every time it starts)."
fi

echo
echo "Done. Open a NEW terminal (the + in the terminal panel), then:"
echo "  1. cd $repo"
echo "  2. opencode"
echo "  3. Type /connect, pick GitHub Copilot, and follow the code it shows you."
echo "The full steps are in opencode/README.md."
