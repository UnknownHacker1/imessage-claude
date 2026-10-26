#!/bin/bash
# "Claude iMessage" window, opened at login by ~/Library/LaunchAgents/com.imessage-claude.launcher.plist.
# Runs whichever parts are set up:
#   - iMessage in Composio: scripts/bridge.ts behind an ngrok tunnel
#   - Claude Code listening to your text-yourself chat (answers your texts)
# Both read your texts, which is why they run in Terminal (it has Full Disk Access).
export PATH="$HOME/.local/bin:$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
unset ANTHROPIC_API_KEY   # use the claude.ai login (channels and connectors need it)
RUN="$HOME/imessage-claude"
STATE="$RUN/.state"
SKILL="$HOME/.claude/skills/imessage-composio"
CHANNEL="plugin:imessage@claude-plugins-official"
mkdir -p "$STATE"

# One window at a time.
OLD=$(cat "$STATE/launcher.pid" 2>/dev/null)
if [ -n "$OLD" ] && [ "$OLD" != "$$" ] && kill -0 "$OLD" 2>/dev/null; then
  echo "Already running in another window. This one can be closed."; exit 0
fi
echo $$ > "$STATE/launcher.pid"
cleanup() { pkill -f "$SKILL/scripts/bridge.ts" >/dev/null 2>&1; pkill -f "$RUN/bin/ngrok" >/dev/null 2>&1; }
trap 'cleanup; exit' HUP INT TERM
trap cleanup EXIT
caffeinate -i -w $$ &   # keep the Mac from idle-sleeping while this window is open

clear
echo "Claude iMessage"
echo "Keep this window open (minimizing is fine). Close it to stop."
echo
if ! sqlite3 "$HOME/Library/Messages/chat.db" "SELECT 1 FROM message LIMIT 1" >/dev/null 2>&1; then
  echo "Terminal can't read your texts yet. System Settings > Privacy & Security > Full Disk Access:"
  echo "turn ON Terminal, then quit Terminal (Cmd+Q) and ask Claude to start this again."
fi
osascript -e 'tell application "Messages" to get name' >/dev/null 2>&1   # Messages permission popup, if never answered

if [ -f "$STATE/bridge.enabled" ]; then
  ( while :; do bun "$SKILL/scripts/bridge.ts" >> "$STATE/bridge.log" 2>&1; sleep 5; done ) &
  ( while :; do
      URL=$(cat "$STATE/ngrok.url" 2>/dev/null)
      "$RUN/bin/ngrok" http 127.0.0.1:8787 ${URL:+--url "$URL"} --log stdout > "$STATE/ngrok.log" 2>&1
      sleep 5
    done ) &
  echo "iMessage in Composio: on"
fi

if [ ! -f "$RUN/home/CLAUDE.md" ]; then
  wait; exit 0
fi
echo "Texting Claude from your iPhone: on (text yourself and Claude answers)"
echo
cd "$RUN/home" || exit 1
claude auth status >/dev/null 2>&1 || claude auth login
while true; do
  claude --channels "$CHANNEL"
  echo
  echo "Claude stopped. Restarting in 10 seconds (close this window to stop for good)."
  sleep 10
done
