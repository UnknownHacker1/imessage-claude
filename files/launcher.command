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
while true; do
  if running; then echo "Already running in another window. This one can be closed."; exit 0; fi
  # caffeinate -i keeps the Mac from idle-sleeping while Claude is listening.
  caffeinate -i claude --channels plugin:imessage@claude-plugins-official
  echo
  echo "Claude stopped. Restarting in 10 seconds (close this window to stop for good)."
  sleep 10
done
