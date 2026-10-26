#!/bin/bash
# One-line installer. Usage (paste in Terminal):
#   curl -fsSL https://raw.githubusercontent.com/UnknownHacker1/imessage-claude/main/go.sh | bash
# Downloads this repo to ~/imessage-claude (no git needed) and runs setup.sh.

REPO="UnknownHacker1/imessage-claude"
DIR="$HOME/imessage-claude"

echo "Downloading setup files..."
mkdir -p "$DIR"
if ! curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/main" | tar -xz --strip-components 1 -C "$DIR"; then
  echo "Download failed. Check your internet and paste the line again."
  exit 1
fi
chmod +x "$DIR"/*.sh 2>/dev/null

# Our stdin is this script (curl | bash), so hand setup the keyboard.
exec bash "$DIR/setup.sh" < /dev/tty
