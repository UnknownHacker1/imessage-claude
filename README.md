# Claude + iMessage + Composio

Your texts, your Claude, and your Composio apps, working together on your Mac.

- **In the Claude app:** "summarize my unread texts", "text Sarah I'm running 5 late".
- **From your iPhone:** text yourself "what's on my calendar tomorrow?" and Claude texts back.
- **Inside Composio:** iMessage shows up as one of your Composio apps (read, search, and send texts, look up contacts).

## Setup: give this page to Claude

1. Open the **Claude** app on your Mac and click **Code** at the top. Pick any folder (your home folder is fine).
2. Paste this and press Enter:

   ```text
   Set up iMessage + Composio for me: https://github.com/UnknownHacker1/imessage-claude
   ```

3. When Claude asks to run its helper, click **Always allow**.

Claude does the installing and checking. Here is everything **you** will be asked to do, so nothing surprises you (about 5 minutes total):

| # | You do | Why |
|---|---|---|
| 1 | In the Settings window that pops up, turn **ON** the switches for **Claude** and **Terminal** | macOS only lets apps read your texts with your OK |
| 2 | Click **OK** when asked to let Claude / Terminal control Messages | So they can send texts |
| 3 | From your iPhone, text **yourself**: hi | Creates the chat where you'll text Claude |
| 4 | Log in to Claude in the browser window that opens | For the phone assistant |
| 5 | In the Claude app: **Settings** > **Extensions** > search **iMessage** > **Install** | Texts inside normal Claude chats |
| 6 | Only if Claude says Composio isn't connected: paste one link on the page it opens | You probably already have it |
| 7 | Text yourself: **hi Claude, what can you do?** | Test. Claude texts back |
| 8 | Sign up for free at ngrok (the **Google** button), click **Copy** next to your authtoken, tell Claude "copied" | Gives your Mac a private address Composio can reach |
| 9 | On the Composio page that opens: name it **iMessage**, **Cmd+V** in the URL box, click **Add** | Adds iMessage as a Composio app |

Each step checks itself, so you never have to come back and say "done" (except "copied" in step 8). If something breaks, Claude fixes it.

No Code tab? Open **Terminal** (Cmd+Space, type Terminal, Enter), paste this, press Enter. You get the same Claude setup:

```bash
curl -fsSL https://raw.githubusercontent.com/UnknownHacker1/imessage-claude/main/go.sh | bash
```

## Good to know

- Your Mac does the work, so it has to be **on and awake** for texting Claude from your phone and for iMessage in Composio. Keep the **Claude iMessage** window open (minimized is fine). It reopens by itself when you log in.
- Only you can text Claude: your own number, in your text-yourself chat. Other people's texts are ignored.
- Claude asks before sending a text or email to anyone else.
- The Composio address is private, and only Composio has it. To shut it off, tell Claude "turn off iMessage in Composio".
- Anything broken later? Tell Claude (Code tab): "fix my iMessage setup".

---

## For Claude

This repo is a Claude Code skill. If you were asked to set it up, install it without git, then follow `SKILL.md`:

```bash
mkdir -p ~/.claude/skills/imessage-composio && curl -fsSL https://codeload.github.com/UnknownHacker1/imessage-claude/tar.gz/refs/heads/main | tar -xz --strip-components 1 -C ~/.claude/skills/imessage-composio
```

Then read `~/.claude/skills/imessage-composio/SKILL.md` and do what it says, starting at step 0. You need shell access on this Mac (the Claude app's Code tab or Claude Code). A regular chat or Cowork can't do this.
