---
name: imessage-composio
description: Set up, test, or fix Claude reading and sending the user's iMessages on this Mac next to their Composio apps. Covers the Claude app's iMessage extension, texting Claude from an iPhone (Claude Code iMessage channel), and iMessage as a custom app inside Composio. Use when the user asks to install or set up iMessage, Composio + iMessage, "text Claude from my phone", this repo (imessage-claude), or says texting Claude stopped working.
---

# Set up iMessage + Composio

You are setting this up for a busy, non-technical person who hates waiting. You do all the work. They only do what macOS forces a human to do: flip switches, click popups, log in, text themselves. Run everything through one helper so they can approve it once:

```bash
D="bash ~/.claude/skills/imessage-composio/scripts/doctor.sh"   # every call: $D <command>
```

**End result**
- **Part A:** in the Claude app, any regular chat can read and send their texts ("Read and Send iMessages" extension by Anthropic) and use Composio.
- **Part B:** they text themselves from their iPhone, and Claude on this Mac answers in that chat, with Composio. This is a Claude Code session with the official `imessage@claude-plugins-official` channel plugin, in a Terminal window called "Claude iMessage" that reopens at every login.
- **Composio** is a claude.ai custom connector (`https://connect.composio.dev/mcp`), so it shows up in both.
- **Part C:** iMessage becomes an app inside their Composio account, with tools to read, search, and send texts and look up contacts. Composio has no iMessage app and can't reach a Mac on its own. So a small server (`scripts/bridge.ts`) runs in the same "Claude iMessage" window, ngrok gives it a fixed public address, and a long random secret in the URL is the key. Composio stores that URL as a custom app. The only new account is a free ngrok one.

## How to talk to them
- Short messages. **Bold** exactly what to click. Never ask them to type a command.
- Give every action that can happen in parallel in **one** message (max 3), numbered. Then wait on all of them with one `wait` call.
- While they click, you wait with `$D wait ...` (it polls for up to 100s). On `wait=timeout`, run it again. After two timeouts, send one short nudge about what's still `missing`.
- Never say "done" for something a check hasn't confirmed.
- No em dashes.

## 0. Preflight
1. You must be able to run shell commands on **this Mac** (the Claude app's **Code** tab, or Claude Code in Terminal). If you're in a regular chat or Cowork, reply only this and stop: *"I need to run this from the Code tab: at the top of the Claude app click **Code**, choose any folder (your home folder is fine), and paste your message again."*
2. If `~/.claude/skills/imessage-composio/scripts/doctor.sh` doesn't exist yet, install the skill (no git; plain git can pop up Apple's slow developer-tools installer):
   ```bash
   mkdir -p ~/.claude/skills/imessage-composio && curl -fsSL https://codeload.github.com/UnknownHacker1/imessage-claude/tar.gz/refs/heads/main | tar -xz --strip-components 1 -C ~/.claude/skills/imessage-composio
   ```
3. Run `$D install` (starts Claude Code, Bun, the plugin and, if missing, the Claude app installing in the background), then `$D status`.
4. Tell them in one line: about 3 minutes, a few clicks, and that you'll run one helper many times, so they should pick **Always allow** if Claude asks permission for it.

Skip any step below whose checks already pass in `status`. The whole flow is safe to rerun.

## 1. Permissions (one Settings visit)
If `read`, `terminal_fda` or `claude_fda` is missing:
- If `messages=missing`, first: `open -a Messages`, and ask them to sign in with the same Apple ID as their iPhone. `$D wait messages`.
- `$D open fda`, then tell them: *In the window that opened (Full Disk Access), turn ON **Claude** and **Terminal**. Missing from the list? Click **+**, pick it from Applications (Terminal is in Applications > Utilities). If macOS offers to quit Claude, click **Later**.*
- `$D wait fda`. `read` checks this process. When running in the Claude app that's Claude's access, in Terminal it's Terminal's. If Claude's switch is ON but `read` is still missing after two waits, the app needs a restart: tell them to quit Claude (**Cmd+Q**), reopen it, open this same chat and say **continue**. In Terminal: quit Terminal, reopen, run `claude -c`.

Then `$D messages-access`. Before running it, tell them: *if a popup asks to let Claude control Messages, click **OK***. If it prints `denied`: `$D open automation`, and ask them to turn ON **Messages** under **Claude**, then rerun it.

## 2. Parallel clicks (one message)
Send only the items that are missing, numbered, in one message:
1. `self_chat` missing: *On your iPhone, text **yourself** (your own number): hi*
2. `login` missing: run `$D open login` first. Then: *In the Terminal window that opened, log in to Claude in the browser, and click **OK** if asked to let Terminal control Messages.* (That login is for the always-on phone assistant. Claude Code installs in the background, and the window waits for it.)
3. `ext` missing: *In the Claude app: **Settings** (Cmd+,) > **Extensions** > **Browse extensions**, search **iMessage**, install **Read and Send iMessages** (by Anthropic).*

Then `$D wait self_chat login ext` (only the ones you asked for).
- `self_chat` stuck: Messages on this Mac must use the same Apple ID as the phone, with **Messages in iCloud** ON (Messages > Settings > iMessage).
- `ext_version` below 0.1.11: ask them to update it in Settings > Extensions.
- `app=missing` (no Claude app): the background job installs it; `$D wait app`. If it times out twice, have them download it from https://claude.ai/download.

## 3. Composio
If you already have Composio tools in this session, it's connected at claude.ai. Otherwise check `$D check composio` (needs `login`).
If it's missing: run `$D open connectors` (copies the URL), then tell them: *On the page that opened: click **+** > **Add custom connector**. Name **Composio**, URL **Cmd+V**, click **Add**, then **Connect** and sign in.* Then `$D wait composio -t 100` (it can take a minute to sync).
- Line present but not connected: `claude mcp login "<name before the colon in composio_line>"`. That opens a browser, so tell them to sign in.
- Never appears after 3 waits (for example, a Team plan where only Owners add connectors): `claude mcp add --scope user --transport http composio https://connect.composio.dev/mcp`, then `claude mcp login composio`.

## 4. Part B: start it and test it
1. `$D wait engine -t 100`. On `engine=clt`, tell them: *a popup wants to install Apple's command line developer tools; click **Install** (one time, a few minutes)*, and keep waiting. On `engine=fail:...`, read `~/imessage-claude/.state/engine.log` and fix it.
2. `$D partb`. If it prints `blocked`, fix what's in `missing` first.
3. Tell them: *A Terminal window called **Claude iMessage** opened. Leave it open (minimizing is fine).* Then `$D wait partb -t 60`.
4. Run `sleep 8` (the connector loads), then `$D test-start`. Tell them: *On your iPhone, text yourself: **hi Claude, what can you do?***
5. `$D wait reply`. On a timeout, ask if they got a reply. If not, read FIX.md (Part B section) and diagnose. Ask them for a screenshot of the Claude iMessage window if you need its error.

## 5. Part C: iMessage inside Composio
Needs `engine` and `terminal_fda` (done above).
1. `$D bridge-install` (downloads ngrok in a few seconds). If it prints `ngrok_auth=missing`:
   - `open https://dashboard.ngrok.com/signup`, then tell them: *Sign up for a free ngrok account (the **Google** button is fastest). On the page you land on, click **Copy** next to **Your Authtoken**. Then tell me "copied".*
   - When they say copied: `$D ngrok-token`. On `not_on_clipboard`, `open https://dashboard.ngrok.com/get-started/your-authtoken` and ask them to click **Copy** again. Never print or repeat the token.
2. `$D bridge-on`, then `$D wait bridge tunnel -t 60`. On a timeout, read `~/imessage-claude/.state/ngrok.log` and `bridge.log`.
3. `$D open-composio-app`. It copies the private URL (never print it) and opens Composio's "add custom MCP" page. Tell them: *On the Composio page (log in if asked): name it **iMessage**, click the URL box, press **Cmd+V**. If it asks about authentication, pick **None** / no auth. Then click **Add** (or **Connect**).*
4. `$D wait composio_app -t 100`: Composio calls the Mac to load the tools. Two timeouts: ask them what the page shows, then rerun `$D open-composio-app` if the URL didn't stick.
5. If you have Composio tools in this session, prove it end to end. Call `COMPOSIO_SEARCH_TOOLS` with use_case "read my recent iMessages" (retry with `search_strategy: "tool_search"`). Then run the iMessage app's recent-messages tool with `limit: 1` through `COMPOSIO_MULTI_EXECUTE_TOOL`. Say only that it worked; don't show the message. Composio notes that custom apps can be missing from its search for a while, so if search can't find it, step 4 passing is enough.
- Turn it off: `$D bridge-off`, and ask them to delete the iMessage app in Composio.
- Anyone with the URL can read and send their texts while the window is open. Never print it or paste it anywhere except Composio's form.

## 6. Part A quick test
`echo "Read my last 3 iMessages and tell me who sent them." | pbcopy`, then tell them: *Open a **new regular chat** (not Cowork), press **Cmd+V**, Enter, and click **Allow** on popups. Did it show your texts?*
If not: `$D node-path`. If it prints a path, copy it with pbcopy, `$D open fda`, and tell them: *Click **+**, press **Cmd+Shift+G**, **Cmd+V**, Enter, **Open***. Then they quit and reopen Claude and test again. Otherwise follow FIX.md (Part A section).

## 7. Wrap up (one short message)
- Claude app: "summarize my unread texts", "text Sarah I'm 5 min late".
- iPhone: text yourself anything, like "what's on my calendar tomorrow?". When Claude needs an OK it texts a code; reply exactly `yes abcde`.
- Composio works in both. Apps they connect at composio.dev show up on their own.
- iMessage is now an app in their Composio too. Anything that uses their Composio can read and send texts while the Mac is awake.
- Keep the Claude iMessage window open (minimized is fine) and the Mac awake. It runs the phone assistant and iMessage for Composio, and it reopens at login.
- If something breaks, they can tell any Claude Code chat "fix my iMessage setup" and this skill runs again.

## Rules
- Read texts only to test; never print the content of their texts unless they asked.
- Send texts only to their own self-chat, and only for the test.
- Never write to `~/Library/Messages`, never `sudo`, and never edit TCC databases. Switches are theirs to flip.
- Never use `--dangerously-skip-permissions`. Part B relays permission prompts to their phone on purpose.
- Stop Part B: `bash ~/.claude/skills/imessage-composio/scripts/uninstall.sh`.
- Known problems and fixes: `FIX.md` in this folder.
