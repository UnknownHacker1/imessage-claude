# Fixes for known problems

Helper: `D="bash ~/.claude/skills/imessage-composio/scripts/doctor.sh"`. `$D status` shows every check. `$D partb` rewrites and restarts the phone assistant. Background install log: `~/imessage-claude/.state/engine.log`.

## Part B (texting Claude from the iPhone)

**No reply at all.** Look at the "Claude iMessage" Terminal window first.
- `cannot read .../chat.db` or `authorization denied`: Terminal lacks Full Disk Access. System Settings > Privacy & Security > Full Disk Access > Terminal ON, then quit Terminal (Cmd+Q) and reopen. Open the pane with `open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"`.
- `self-chat addresses: (none)`: the owner has never texted themselves on this Apple ID. Have them text themselves "hi" from the iPhone, then restart the window (close it, then `open -a Terminal ~/imessage-claude/"Claude iMessage.command"`).
- `bun: command not found` or the plugin's MCP server fails: `curl -fsSL https://bun.sh/install | bash`, and make sure the launcher's PATH has `~/.bun/bin`.
- Channels not available / disabled by the organization: on Claude Team or Enterprise plans an Owner must turn on Organization settings > Claude Code > Channels at claude.ai. Pro and Max plans don't need this. Tell the owner exactly that; you can't fix it from here.
- Not logged in, or logged in with an API key: `claude auth login` with the claude.ai account. Channels and claude.ai connectors need a claude.ai login.
- Messages arrive from the phone but sends fail with `-1743` / "Not authorized to send Apple events": System Settings > Privacy & Security > Automation > Terminal > Messages ON. If Terminal is not listed or the popup was denied before: `tccutil reset AppleEvents com.apple.Terminal`, then run `osascript -e 'tell application "Messages" to get name'` and have the owner click OK.
- Texts only come in when they're iMessage (blue). Green SMS is ignored on purpose (`IMESSAGE_ALLOW_SMS`), since SMS senders can be faked.
- Two windows both answering: `pkill -f "Claude iMessage.command"; pkill -f "channels plugin:imessage"`, then open the launcher once.
- Replies end with "Sent by Claude". That's the plugin default. To drop it, add `export IMESSAGE_APPEND_SIGNATURE=false` near the top of `~/imessage-claude/Claude iMessage.command`.
- Claude keeps asking permission by text for Composio: the allow rule in `~/imessage-claude/home/.claude/settings.json` doesn't match the connector's server name. Run `claude mcp list`, take the Composio server name, replace every character that isn't a letter, digit, `_` or `-` with `_`, and allow `mcp__<that>`. For example `claude.ai Composio` becomes `mcp__claude_ai_Composio`.
- Plugin docs: `~/.claude/plugins/` (search for `imessage`), files `README.md` and `ACCESS.md`.

## Part A (Claude desktop app)
- Extension installed but reads fail: Full Disk Access for Claude.app, then fully quit Claude (Cmd+Q) and reopen. Known issue (anthropics/claude-code#21737): on some Macs the extension runs under the system `node`, which also needs Full Disk Access. Find it with `command -v node` and `readlink -f`, then in the Full Disk Access list click +, press Cmd+Shift+G, paste the path, Open.
- Works in a normal chat but not in Cowork: known (anthropics/claude-code#39603). Cowork runs in a VM that can't see chat.db. Use a regular chat.
- Contacts or Automation popup was denied: `tccutil reset AddressBook com.anthropic.claudefordesktop` and `tccutil reset AppleEvents com.anthropic.claudefordesktop` (check the bundle id with `defaults read /Applications/Claude.app/Contents/Info CFBundleIdentifier`), restart Claude, ask again, click Allow.
- Extension older than v0.1.11: update it in Claude > Settings > Extensions (0.1.11 fixed a read bug, anthropics/claude-code#32999).
- Logs: `~/Library/Logs/Claude/` (files starting with `mcp`).

## Composio
- Not in `claude mcp list`: add it at https://claude.ai/customize/connectors: + > Add custom connector, URL `https://connect.composio.dev/mcp`, then Connect. On Team or Enterprise plans only an Owner can add custom connectors; if so, say that to the owner.
- Shows "Needs authentication": `claude mcp login "<name from claude mcp list>"`.
- Fallback when claude.ai connectors don't load into Claude Code: `claude mcp add --scope user --transport http composio https://connect.composio.dev/mcp` then `claude mcp login composio`. The allow rule `mcp__composio` is already in the Part B settings.
