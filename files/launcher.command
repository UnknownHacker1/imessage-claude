#!/bin/bash
# "Claude iMessage" window: Claude Code listening to your text-yourself chat.
# Opened at login by ~/Library/LaunchAgents/com.imessage-claude.launcher.plist.
export PATH="$HOME/.local/bin:$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
unset ANTHROPIC_API_KEY   # use the claude.ai login (channels and connectors need it)
cd "$HOME/imessage-claude/home" || exit 1
running() { pgrep -f "channels plugin:imessage@claude-plugins-official" >/dev/null; }

clear
echo "Claude iMessage"
echo "Claude answers when you text yourself from your iPhone."
echo "Keep this window open (minimizing is fine). Close it to stop."
echo
if ! sqlite3 "$HOME/Library/Messages/chat.db" "SELECT 1 FROM message LIMIT 1" >/dev/null 2>&1; then
  echo "Terminal can't read your texts yet. System Settings > Privacy & Security > Full Disk Access:"
  echo "turn ON Terminal, then quit Terminal (Cmd+Q) and ask Claude to start this again."
fi
claude auth status >/dev/null 2>&1 || claude auth login
osascript -e 'tell application "Messages" to get name' >/dev/null 2>&1   # Messages permission popup, if never answered
while true; do
  if running; then echo "Already running in another window. This one can be closed."; exit 0; fi
  # caffeinate -i keeps the Mac from idle-sleeping while Claude is listening.
  caffeinate -i claude --channels plugin:imessage@claude-plugins-official
  echo
  echo "Claude stopped. Restarting in 10 seconds (close this window to stop for good)."
  sleep 10
done
