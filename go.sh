#!/bin/bash
# Terminal route for people without the Claude app's Code tab:
#   curl -fsSL https://raw.githubusercontent.com/UnknownHacker1/imessage-claude/main/go.sh | bash
# Installs the skill and Claude Code, then starts Claude on the setup skill.

REPO="UnknownHacker1/imessage-claude"
SKILL="$HOME/.claude/skills/imessage-composio"
export PATH="$HOME/.local/bin:$PATH"

echo "Getting things ready..."
mkdir -p "$SKILL"
curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/main" | tar -xz --strip-components 1 -C "$SKILL" || { echo "Download failed. Check your internet and paste the line again."; exit 1; }
bash "$SKILL/scripts/doctor.sh" install >/dev/null

if ! command -v claude >/dev/null 2>&1; then
  echo "Installing Claude Code (about 20 seconds)..."
  t=0   # the install job above puts it in ~/.local/bin
  until command -v claude >/dev/null 2>&1; do
    sleep 2; t=$((t+2))
    [ $t -ge 180 ] && { echo "Claude Code didn't install. Log: ~/imessage-claude/.state/engine.log"; exit 1; }
  done
fi
grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"

cd "$HOME" || exit 1
exec claude "Set up iMessage + Composio for me with the imessage-composio skill." < /dev/tty
