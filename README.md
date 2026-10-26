# Claude + iMessage + Composio

Lets Claude read and send your iMessages, next to all your Composio apps.

- **In the Claude app:** "summarize my unread texts", "text Sarah I'm running 5 late".
- **From your iPhone:** text yourself "what's on my calendar tomorrow?" and Claude texts back.

## Setup (about 3 minutes, Mac only)

**1.** Press **Cmd + Space**, type **Terminal**, press **Enter**.

**2.** Paste this line and press **Enter**:

```bash
curl -fsSL https://raw.githubusercontent.com/UnknownHacker1/imessage-claude/main/go.sh | bash
```

**3.** Do what the yellow 👉 lines say. That's it.

Everything installs in the background while you click. You'll be asked to:
flip 2 switches in System Settings, text yourself "hi" from your iPhone, log in to Claude, add Composio (copy and paste, already on your clipboard), and install the iMessage extension in the Claude app. Each step checks itself, and if one fails, Claude offers to fix it for you.

## Using it

| Where | How |
|---|---|
| Claude app | Start a **regular** chat (not Cowork) and ask about your texts. Composio apps work in the same chat. |
| iPhone | Text **yourself**. Claude answers in that same chat. If it needs your OK for something, it texts you a code. Reply exactly `yes abcde` (or `no abcde`). |

Before Claude sends an email or a text to someone else, it texts you a summary and waits for your "yes".

For texting from your iPhone, the Mac has to be on and awake, with the **Claude iMessage** window open (minimized is fine). It starts by itself when you log in.

## Questions

**Something stopped working?** Paste this in Terminal: `bash ~/imessage-claude/setup.sh` (finished steps are skipped).

**Turn off texting from the phone?** `bash ~/imessage-claude/uninstall.sh`

**Who can text Claude?** Only you, from your own number, in your text-yourself chat. Texts from anyone else are ignored.

**Does it change my texts?** No. It only reads them, and sends texts when you ask.
