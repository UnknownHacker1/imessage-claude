#!/bin/bash
# Sets up Claude + iMessage + Composio on this Mac.
#   Part A: the Claude desktop app reads and sends your texts (iMessage extension).
#   Part B: text yourself from your iPhone, Claude on this Mac answers (Claude Code channel).
# Installs run in the background while you click through the few things macOS makes you click.
# Safe to run again any time: finished steps are skipped in a second.

DIR="$HOME/imessage-claude"
STATE="$DIR/.state"
HOME_DIR="$DIR/home"
DB="$HOME/Library/Messages/chat.db"
TCCDB="/Library/Application Support/com.apple.TCC/TCC.db"
EXT_DIR="$HOME/Library/Application Support/Claude/Claude Extensions"
COMPOSIO_URL="https://connect.composio.dev/mcp"
AGENT_LABEL="com.imessage-claude.launcher"
AGENT_PLIST="$HOME/Library/LaunchAgents/$AGENT_LABEL.plist"
LAUNCHER="$DIR/Claude iMessage.command"
CHANNEL="plugin:imessage@claude-plugins-official"
RERUN="bash ~/imessage-claude/setup.sh"
TEST_PROMPT="Read my last 3 iMessages and tell me who sent them."
export PATH="$HOME/.local/bin:$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
mkdir -p "$STATE"

B=$(tput bold 2>/dev/null); N=$(tput sgr0 2>/dev/null)
G=$(tput setaf 2 2>/dev/null); Y=$(tput setaf 3 2>/dev/null)
R=$(tput setaf 1 2>/dev/null); C=$(tput setaf 6 2>/dev/null)
TOTAL=7; STEP=0

step()  { STEP=$((STEP+1)); echo; echo "${B}${C}[$STEP/$TOTAL] $1${N}"; }
ok()    { echo "  ${G}✓ $1${N}"; }
todo()  { echo "  ${Y}${B}👉 $1${N}"; }
note()  { echo "     $1"; }
enter() { printf "  ${B}Press Enter when done.${N} "; read -r _; }
yesno() { local a; printf "  ${B}%s (y/n)${N} " "$1"; read -r a; case "$a" in y|Y|yes|Yes|YES) return 0;; *) return 1;; esac; }

# wait_until CHECK MESSAGE [TIMEOUT_SECONDS] [HINT]: re-checks every second.
# Shows HINT after 20 seconds. Returns 1 if TIMEOUT passes (0 = wait forever).
wait_until() {
  local t=0 max="${3:-0}"
  printf "  %s" "$2"
  until eval "$1" >/dev/null 2>&1; do
    sleep 1; t=$((t+1))
    [ $((t % 3)) -eq 0 ] && printf "."
    if [ "$t" -eq 20 ] && [ -n "$4" ]; then echo; note "$4"; printf "  Still waiting"; fi
    if [ "$max" -gt 0 ] && [ "$t" -ge "$max" ]; then echo; return 1; fi
  done
  echo
}

fixit() {
  echo; echo "  ${R}${B}✗ $1${N}"
  if command -v claude >/dev/null 2>&1 && claude auth status >/dev/null 2>&1; then
    echo "  ${B}Press Enter and Claude will fix it for you.${N} (Ctrl+C to stop)"
    read -r _
    cd "$DIR" && exec claude "Setup failed at this step: $1. Read CLAUDE.md and FIX.md, figure out what is wrong on this Mac, fix it, then run ./setup.sh again to confirm everything passes."
  fi
  echo "  Take a screenshot of this window and send it to whoever sent you the link."
  exit 1
}

# Background jobs (engine.sh, desktop.sh). nohup keeps them alive if Terminal restarts.
job_alive()  { local p; p=$(cat "$STATE/$1.pid" 2>/dev/null); [ -n "$p" ] && kill -0 "$p" 2>/dev/null; }
job_status() { cat "$STATE/$1.status" 2>/dev/null; }
start_job()  { job_alive "$1" && return; echo running > "$STATE/$1.status"; nohup bash "$DIR/$1.sh" > "$STATE/$1.log" 2>&1 & }
wait_job() {
  local s shown=""
  case "$(job_status "$1")" in ok|fail*) return;; esac
  printf "  %s" "$2"
  while :; do
    s=$(job_status "$1")
    case "$s" in ok|fail*) break;; esac
    if [ "$s" = clt ] && [ -z "$shown" ]; then
      shown=1; echo
      todo "A popup asks to install Apple's 'command line developer tools'. Click Install (one time, a few minutes)."
      printf "  Waiting for it to finish"
    fi
    job_alive "$1" || start_job "$1"
    printf "."; sleep 2
  done
  echo
}

can_read_db() { sqlite3 "$DB" "SELECT 1 FROM message LIMIT 1" >/dev/null 2>&1; }
can_control_messages() { osascript -e 'tell application "Messages" to get name' >/dev/null 2>&1; }
# Prints 2 when Full Disk Access is ON for a bundle id. Works once Terminal itself has it.
fda_state() { sqlite3 "$TCCDB" "SELECT auth_value FROM access WHERE service='kTCCServiceSystemPolicyAllFiles' AND client='$1'" 2>/dev/null; }
# A chat with yourself (same check the iMessage plugin uses to find where to text you).
SELF_SQL="SELECT COUNT(*) FROM chat c JOIN chat_handle_join j ON j.chat_id=c.ROWID JOIN handle h ON h.ROWID=j.handle_id WHERE c.style=45 AND LOWER(h.id) IN (SELECT DISTINCT LOWER(CASE WHEN account GLOB '[A-Za-z]:*' THEN substr(account,3) ELSE account END) FROM message WHERE is_from_me=1 AND account IS NOT NULL AND account!='')"
has_self_chat() { [ "$(sqlite3 "$DB" "$SELF_SQL" 2>/dev/null)" -gt 0 ] 2>/dev/null; }
logged_in() { claude auth status >/dev/null 2>&1; }
composio_line() { claude mcp list 2>/dev/null | grep -i composio | head -1; }
composio_ok() { composio_line | grep -qiE "✔|- connected"; }
has_ext() { ls "$EXT_DIR" 2>/dev/null | grep -qi imessage; }
channel_up() { pgrep -f "channels $CHANNEL" >/dev/null; }
ver_ge() { awk -v a="$1" -v b="$2" 'BEGIN{split(a,x,".");split(b,y,".");for(i=1;i<=3;i++){if(x[i]+0>y[i]+0)exit 0;if(x[i]+0<y[i]+0)exit 1}exit 0}'; }
restart_claude_app() { osascript -e 'quit app "Claude"' >/dev/null 2>&1; sleep 2; open -a Claude; }

clear
echo "${B}Claude + iMessage + Composio setup${N}"
echo "About 3 minutes. Only do what the ${Y}${B}👉 yellow lines${N} say. Everything else is automatic."
echo "If anything breaks, Claude offers to fix it for you."

# ---------------------------------------------------------------------------
step "Checking this Mac"
[ "$(uname)" = "Darwin" ] || { echo "  This only works on a Mac."; exit 1; }
if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
  echo "$RERUN" | pbcopy
  open -a Terminal
  todo "Please use the Terminal app (it just opened). Click into it, press Cmd+V, then Enter."
  exit 0
fi
start_job engine    # Claude Code, Bun, iMessage plugin
start_job desktop   # Claude desktop app
ok "Mac and Terminal (installing the rest in the background)"

# ---------------------------------------------------------------------------
step "Let Terminal read and send your texts"
if [ ! -d "$HOME/Library/Messages" ]; then
  open -a Messages
  todo "Messages opened. Sign in with your Apple ID (the same one as your iPhone)."
  wait_until '[ -d "$HOME/Library/Messages" ]' "Waiting for Messages"
fi
if ! can_read_db; then
  echo "$RERUN" | pbcopy
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
  todo "In the Settings window that opened, turn ON the switch next to ${B}Terminal${N}${Y}${B}."
  note "Not in the list? Click +, go to Applications > Utilities, pick Terminal."
  note "If macOS says Terminal must quit: click ${B}Quit & Reopen${N} (and ${B}Terminate${N} if asked), then ${B}Cmd+V${N}, ${B}Enter${N}."
  wait_until can_read_db "Waiting for the switch" 0 "Switch already ON? Quit Terminal (Cmd+Q), open it again, press Cmd+V, Enter."
fi
todo "If a popup asks to let Terminal control Messages, click ${B}OK${N}${Y}${B}."
if ! can_control_messages; then
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
  todo "In Settings (Automation): open Terminal, turn ON Messages."
  wait_until can_control_messages "Waiting for the switch"
fi
ok "Terminal can read and send texts"

# ---------------------------------------------------------------------------
step "Your text-yourself chat"
if ! has_self_chat; then
  todo "On your iPhone, text ${B}yourself${N}${Y}${B} (your own number): hi"
  wait_until has_self_chat "Waiting for it to reach this Mac" 0 "Not arriving? On this Mac open Messages > Settings > iMessage: same Apple ID as the phone, and 'Enable Messages in iCloud' ON."
fi
ok "Found your chat with yourself (that's where you'll text Claude)"

# ---------------------------------------------------------------------------
step "Claude login"
wait_until 'command -v claude' "Installing Claude Code" 240 || { wait_job engine "Still installing"; fixit "Claude Code did not install ($(job_status engine))"; }
if ! logged_in; then
  todo "A browser window opens. Log in with your Claude account, then come back here."
  claude auth login
  logged_in || fixit "Claude login did not finish"
fi
if ! claude auth status 2>/dev/null | grep -q '"authMethod": *"claude.ai"'; then
  echo "  ${Y}Heads up: this isn't a claude.ai login, so Composio and texting Claude may not work. Run: claude auth login${N}"
fi
grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
ok "Logged in to Claude"

# ---------------------------------------------------------------------------
step "Composio"
LINE=$(composio_line)
if [ -z "$LINE" ]; then
  echo "$COMPOSIO_URL" | pbcopy
  open "https://claude.ai/customize/connectors"
  todo "On the Claude page that opened: click ${B}+${N}${Y}${B}, then ${B}Add custom connector${N}${Y}${B}."
  note "Name: ${B}Composio${N}   URL: ${B}Cmd+V${N} (already copied)   then ${B}Add${N}, then ${B}Connect${N} and sign in."
  if ! wait_until '[ -n "$(composio_line)" ]' "Waiting for Composio" 150 "Done but nothing yet? It can take a minute to sync."; then
    note "Adding it straight to Claude Code instead..."
    claude mcp add --scope user --transport http composio "$COMPOSIO_URL" >/dev/null 2>&1
  fi
  LINE=$(composio_line)
fi
COMPOSIO_NAME=$(echo "$LINE" | sed 's/: .*//')
[ -n "$COMPOSIO_NAME" ] || fixit "Composio did not show up in Claude"
if ! composio_ok; then
  todo "A browser window opens. Sign in to Composio and click Allow."
  claude mcp login "$COMPOSIO_NAME"
  composio_ok || fixit "Composio is added but not connected ($COMPOSIO_NAME)"
fi
COMPOSIO_RULE="mcp__$(echo "$COMPOSIO_NAME" | sed 's/[^A-Za-z0-9_-]/_/g')"
ok "Composio connected"

# ---------------------------------------------------------------------------
step "Part A: your texts inside the Claude app"
CLAUDE_ID=$(defaults read /Applications/Claude.app/Contents/Info CFBundleIdentifier 2>/dev/null)
if [ -f "$STATE/partA.ok" ] && has_ext && [ "$(fda_state "$CLAUDE_ID")" = "2" ]; then
  ok "Already working (skipping the test)"
else
  wait_job desktop "Installing the Claude app"
  if [ ! -d /Applications/Claude.app ]; then
    open "https://claude.ai/download"
    todo "Download the Claude app, open the file, drag Claude into Applications."
    wait_until '[ -d /Applications/Claude.app ]' "Waiting for the Claude app"
  fi
  CLAUDE_ID=$(defaults read /Applications/Claude.app/Contents/Info CFBundleIdentifier 2>/dev/null)
  if ! has_ext; then
    open -a Claude
    todo "In the Claude app (log in if asked): ${B}Settings${N}${Y}${B} (Cmd+,) > ${B}Extensions${N}${Y}${B} > ${B}Browse extensions${N}${Y}${B}."
    note "Search ${B}iMessage${N}, pick 'Read and Send iMessages' (by Anthropic), click ${B}Install${N}."
    wait_until has_ext "Waiting for the extension" 0 "Can't find it? Update the app first: Claude menu > Check for Updates."
  fi
  EXT_VER=$(cat "$EXT_DIR"/*[iI][mM]essage*/manifest.json 2>/dev/null | grep -m1 '"version"' | sed 's/[^0-9.]//g')
  if [ -n "$EXT_VER" ] && ! ver_ge "$EXT_VER" "0.1.11"; then
    todo "The iMessage extension is out of date (v$EXT_VER). Claude > Settings > Extensions > iMessage > Update."
    enter
  fi
  if [ "$(fda_state "$CLAUDE_ID")" != "2" ]; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    todo "Same Full Disk Access window: turn ON the switch next to ${B}Claude${N}${Y}${B}."
    note "Not in the list? Click +, go to Applications, pick Claude."
    if sqlite3 "$TCCDB" "SELECT 1 FROM access LIMIT 1" >/dev/null 2>&1; then
      wait_until '[ "$(fda_state "$CLAUDE_ID")" = "2" ]' "Waiting for the switch"
    else
      enter
    fi
    restart_claude_app
  fi
  echo "$TEST_PROMPT" | pbcopy
  todo "Test: in the Claude app start a ${B}new regular chat${N}${Y}${B} (not Cowork), press ${B}Cmd+V${N}${Y}${B}, Enter. Click Allow on popups."
  if ! yesno "Did Claude show your texts?"; then
    NODE=$(command -v node 2>/dev/null)
    [ -n "$NODE" ] || fixit "The Claude app can't read iMessages"
    NODE_REAL=$(readlink -f "$NODE" 2>/dev/null || echo "$NODE")
    echo "$NODE_REAL" | pbcopy
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    todo "One more switch. In Full Disk Access click ${B}+${N}${Y}${B}, press ${B}Cmd+Shift+G${N}${Y}${B}, ${B}Cmd+V${N}${Y}${B}, Enter, then ${B}Open${N}${Y}${B}."
    note "(That adds 'node', which the extension uses on some Macs.)"
    enter
    restart_claude_app
    echo "$TEST_PROMPT" | pbcopy
    todo "Try again: new regular chat in the Claude app, Cmd+V, Enter."
    yesno "Did it work this time?" || fixit "The Claude app can't read iMessages"
  fi
  touch "$STATE/partA.ok"
  ok "Part A works"
fi

# ---------------------------------------------------------------------------
step "Part B: text Claude from your iPhone"
wait_job engine "Finishing the installs"
case "$(job_status engine)" in fail*) fixit "$(job_status engine | sed 's/^fail://') (log: $STATE/engine.log)";; esac
ok "Claude Code, Bun and the iMessage plugin are installed"

mkdir -p "$HOME_DIR/.claude"
cp "$DIR/files/CLAUDE.md" "$HOME_DIR/CLAUDE.md"
cat > "$HOME_DIR/.claude/settings.json" <<EOF
{
  "permissions": {
    "allow": [
      "mcp__plugin_imessage_imessage__reply",
      "mcp__plugin_imessage_imessage__chat_messages",
      "$COMPOSIO_RULE",
      "mcp__composio",
      "Read(~/Library/Messages/Attachments/**)",
      "WebSearch",
      "WebFetch"
    ]
  }
}
EOF
# Skip Claude Code's first-run screens for this folder (welcome, "do you trust this folder").
P="$HOME_DIR" bun -e '
const fs = require("fs"); const f = process.env.HOME + "/.claude.json"; let j = {};
try { j = JSON.parse(fs.readFileSync(f, "utf8")); } catch {}
j.hasCompletedOnboarding = true; j.projects = j.projects || {};
j.projects[process.env.P] = Object.assign({}, j.projects[process.env.P], { hasTrustDialogAccepted: true });
fs.writeFileSync(f, JSON.stringify(j, null, 2));' || fixit "Could not update ~/.claude.json"

cp "$DIR/files/launcher.command" "$LAUNCHER"
chmod +x "$LAUNCHER"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$AGENT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$AGENT_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string><string>-a</string><string>Terminal</string><string>$LAUNCHER</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF

if [ -f "$STATE/partB.ok" ] && channel_up; then
  ok "Already running (skipping the test)"
else
  # (Re)load the login item. Loading it also opens the 'Claude iMessage' window right now.
  launchctl bootout "gui/$(id -u)/$AGENT_LABEL" >/dev/null 2>&1
  pkill -f "Claude iMessage.command" >/dev/null 2>&1
  pkill -f "channels $CHANNEL" >/dev/null 2>&1
  sleep 1
  launchctl bootstrap "gui/$(id -u)" "$AGENT_PLIST" >/dev/null 2>&1 || open -a Terminal "$LAUNCHER"
  note "A Terminal window called 'Claude iMessage' opened. Leave it open (minimizing is fine)."
  note "If that window ever asks you something, press Enter."
  wait_until channel_up "Starting Claude" 60 || fixit "Claude did not start in the 'Claude iMessage' window (look there for the error)"
  sleep 8   # let the iMessage connector load
  # Apple's clock: nanoseconds since 2001-01-01.
  SINCE=$(( ($(date +%s) - 978307200) * 1000000000 ))
  REPLY_SQL="SELECT COUNT(*) FROM message WHERE is_from_me=1 AND date>$SINCE AND (instr(text,'Sent by Claude')>0 OR instr(attributedBody,CAST('Sent by Claude' AS BLOB))>0)"
  todo "On your iPhone, text yourself: ${B}hi Claude, what can you do?${N}"
  if ! wait_until '[ "$(sqlite3 "$DB" "$REPLY_SQL")" -gt 0 ]' "Waiting for Claude's reply" 120; then
    yesno "Did you get a reply on your phone?" || fixit "Texting Claude got no reply (check the 'Claude iMessage' window for errors)"
  fi
  touch "$STATE/partB.ok"
  ok "Part B works"
fi

# ---------------------------------------------------------------------------
echo
echo "${G}${B}All done. 🎉${N}"
echo
echo "  ${B}In the Claude app${N}   \"summarize my unread texts\", \"text Sarah I'm 5 min late\""
echo "  ${B}From your iPhone${N}    text yourself anything: \"what's on my calendar tomorrow?\""
echo "                      If Claude needs your OK it texts you a code. Reply exactly: yes abcde"
echo "  ${B}Composio${N}            works in both. Apps you connect at composio.dev show up automatically."
echo
echo "  Keep the 'Claude iMessage' window open (minimized is fine) and the Mac awake."
echo "  Something off later? Run:  $RERUN"
