# Claude + iMessage + Composio

Claude reads and sends your iMessages, next to all your Composio apps.

- **In the Claude app:** "summarize my unread texts", "text Sarah I'm running 5 late".
- **From your iPhone:** text yourself "what's on my calendar tomorrow?" and Claude texts back.

## Setup: give this page to Claude

1. Open the **Claude** app on your Mac and click **Code** at the top. Pick any folder (your home folder is fine).
2. Paste this and press Enter:

   ```text
   Set up iMessage + Composio for me: https://github.com/UnknownHacker1/imessage-claude
   ```

3. Claude does the rest. It only stops you for things macOS makes a human click (2 switches, a popup or two, a login, texting yourself "hi"). About 3 minutes.

No Code tab? Open **Terminal** (Cmd+Space, type Terminal, Enter), paste this line, and press Enter. It installs the same thing and hands you to Claude:

```bash
curl -fsSL https://raw.githubusercontent.com/UnknownHacker1/imessage-claude/main/go.sh | bash
```

Later, if anything stops working, tell Claude (Code tab) "fix my iMessage setup".

---

## For Claude

This repo is a Claude Code skill. If you were asked to set it up, install it without git, then follow `SKILL.md`:

```bash
mkdir -p ~/.claude/skills/imessage-composio && curl -fsSL https://codeload.github.com/UnknownHacker1/imessage-claude/tar.gz/refs/heads/main | tar -xz --strip-components 1 -C ~/.claude/skills/imessage-composio
```

Then read `~/.claude/skills/imessage-composio/SKILL.md` and do what it says, starting at step 0. You need shell access on this Mac (the Claude app's Code tab or Claude Code). A regular chat or Cowork can't do this.
