# imessage-claude: notes for Claude

You were opened here because `setup.sh` failed on the owner's Mac. Your job: find out why, fix it on this Mac, then run `./setup.sh` again until it finishes. The owner is not technical and is busy. Do the work yourself, explain in one or two plain sentences, and only ask them to click something when macOS requires a human (privacy switches, logins, popups). When you do, say exactly where to click.

## What gets set up
1. **Claude Code** (`~/.local/bin/claude`), logged in with a claude.ai account (`claude auth status` exits 0, `authMethod` is `claude.ai`).
2. **Bun** (`~/.bun/bin/bun`). The iMessage plugin's MCP server is `bun server.ts`.
3. **Plugin** `imessage@claude-plugins-official` (user scope). Reads `~/Library/Messages/chat.db` with SQLite, sends with `osascript`. State in `~/.claude/channels/imessage/`.
4. **Full Disk Access for Terminal** (test: `sqlite3 ~/Library/Messages/chat.db "select 1 from message limit 1"`), and **Automation: Terminal > Messages** (test: `osascript -e 'tell application "Messages" to get name'`).
5. **Self-chat**: the owner must have texted themselves at least once, or the plugin can't find their address and permission texts go nowhere.
6. **Composio** as a claude.ai custom connector, URL `https://connect.composio.dev/mcp`. claude.ai connectors show up in Claude Code automatically; check with `claude mcp list`.
7. **Part A**: Claude desktop app + the "Read and Send iMessages" extension (`ant.dir.ant.anthropic.imessage`, needs v0.1.11+) + Full Disk Access for Claude.app.
8. **Part B**: `~/imessage-claude/home` (persona `CLAUDE.md`, `.claude/settings.json` allow list), `~/imessage-claude/Claude iMessage.command` (runs `claude --channels plugin:imessage@claude-plugins-official` in a loop), and LaunchAgent `~/Library/LaunchAgents/com.imessage-claude.launcher.plist` that opens it in Terminal at login.

Known problems and fixes are in `FIX.md`. Read it first.

## Rules
- Never write to or delete anything in `~/Library/Messages`. Read only.
- Never send a text to anyone except the owner's own self-chat, and only to test.
- Don't turn off macOS security features or use `sudo` to edit TCC databases. Privacy switches are flipped by the owner in System Settings.
- Don't use `--dangerously-skip-permissions` in the launcher. Permission prompts are relayed to the owner's phone on purpose.
