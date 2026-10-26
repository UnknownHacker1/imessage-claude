#!/bin/bash
# Background download + install of the Claude desktop app, started by setup.sh with nohup.
# Progress goes to .state/desktop.status: running | ok | fail:<reason>
STATE="$HOME/imessage-claude/.state"
mkdir -p "$STATE"
echo $$ > "$STATE/desktop.pid"
say() { echo "$1" > "$STATE/desktop.status"; }
say running

if [ -d /Applications/Claude.app ]; then say ok; exit 0; fi
DMG="$STATE/Claude.dmg"
rm -f "$DMG"
curl -fsSL -A "Mozilla/5.0 (Macintosh)" -o "$DMG" "https://claude.ai/api/desktop/darwin/universal/dmg/latest/redirect" || { say "fail:download"; exit 1; }
MNT=$(mktemp -d)
hdiutil attach "$DMG" -nobrowse -quiet -mountpoint "$MNT" || { say "fail:could not open the download"; exit 1; }
cp -R "$MNT/Claude.app" /Applications/
RC=$?
hdiutil detach "$MNT" -quiet >/dev/null 2>&1
rm -f "$DMG"
[ $RC -eq 0 ] && [ -d /Applications/Claude.app ] || { say "fail:could not copy into Applications"; exit 1; }
say ok
