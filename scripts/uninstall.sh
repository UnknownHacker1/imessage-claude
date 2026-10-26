#!/bin/bash
# Turns off Part B (texting Claude from the iPhone). Leaves your texts and the Claude app alone.
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
launchctl bootout "gui/$(id -u)/com.imessage-claude.launcher" >/dev/null 2>&1
rm -f "$HOME/Library/LaunchAgents/com.imessage-claude.launcher.plist"
pkill -f "Claude iMessage.command" >/dev/null 2>&1
pkill -f "channels plugin:imessage@claude-plugins-official" >/dev/null 2>&1
claude plugin uninstall imessage@claude-plugins-official >/dev/null 2>&1
echo "Done. Texting Claude from your phone is off."
echo "To also remove Part A: Claude app > Settings > Extensions > iMessage > Uninstall."
echo "To set it up again, tell Claude (Code tab): set up my iMessage again"
