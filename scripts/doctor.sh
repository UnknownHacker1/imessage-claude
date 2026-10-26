#!/bin/bash
# Helper for the imessage-composio skill. Claude runs:  bash ~/.claude/skills/imessage-composio/scripts/doctor.sh <command>
# Every command prints short "key=value" lines for Claude to read.
#   status                 every check at once (fast; skips composio)
#   install                start background installs (Claude Code, Bun, iMessage plugin, Claude app if missing)
#   wait <check...> [-t N] wait until all named checks pass (default 100s), e.g.  wait fda self_chat ext
#   check <check>          one check (e.g. composio, which is slow)
#   open <fda|automation|connectors|login>
#   messages-access        ask macOS to let this app control Messages (popup), then report
#   partb                  write and start the "text Claude from your iPhone" session
#   test-start             mark the time before the phone test (then: wait reply)
#   node-path              real path of node, for the Full Disk Access fallback

SKILL="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$HOME/imessage-claude"
STATE="$RUN/.state"
HOME_DIR="$RUN/home"
DB="$HOME/Library/Messages/chat.db"
TCCDB="/Library/Application Support/com.apple.TCC/TCC.db"
EXT_DIR="$HOME/Library/Application Support/Claude/Claude Extensions"
COMPOSIO_URL="https://connect.composio.dev/mcp"
AGENT_LABEL="com.imessage-claude.launcher"
AGENT_PLIST="$HOME/Library/LaunchAgents/$AGENT_LABEL.plist"
LAUNCHER="$RUN/Claude iMessage.command"
CHANNEL="plugin:imessage@claude-plugins-official"
export PATH="$HOME/.local/bin:$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
mkdir -p "$STATE"

# Full Disk Access state for a bundle id. Passes when ON, and also when this process
# can't read the TCC database (then we can't tell, so we don't block on it).
tcc_ok() {
  local v
  sqlite3 "$TCCDB" "SELECT 1 FROM access LIMIT 1" >/dev/null 2>&1 || return 0
  v=$(sqlite3 "$TCCDB" "SELECT auth_value FROM access WHERE service='kTCCServiceSystemPolicyAllFiles' AND client='$1'" 2>/dev/null)
  [ "$v" = "2" ]
}
claude_id() { defaults read /Applications/Claude.app/Contents/Info CFBundleIdentifier 2>/dev/null; }
SELF_SQL="SELECT COUNT(*) FROM chat c JOIN chat_handle_join j ON j.chat_id=c.ROWID JOIN handle h ON h.ROWID=j.handle_id WHERE c.style=45 AND LOWER(h.id) IN (SELECT DISTINCT LOWER(CASE WHEN account GLOB '[A-Za-z]:*' THEN substr(account,3) ELSE account END) FROM message WHERE is_from_me=1 AND account IS NOT NULL AND account!='')"
engine_status() { cat "$STATE/engine.status" 2>/dev/null; }
job_alive() { local p; p=$(cat "$STATE/$1.pid" 2>/dev/null); [ -n "$p" ] && kill -0 "$p" 2>/dev/null; }
start_job() { job_alive "$1" && return; echo running > "$STATE/$1.status"; nohup bash "$SKILL/scripts/$1.sh" > "$STATE/$1.log" 2>&1 & }
composio_line() { claude mcp list 2>/dev/null | grep -i composio | head -1; }

# --- checks: each returns 0 when done -------------------------------------
c_mac()          { [ "$(uname)" = "Darwin" ]; }
c_messages()     { [ -d "$HOME/Library/Messages" ]; }
c_read()         { sqlite3 "$DB" "SELECT 1 FROM message LIMIT 1" >/dev/null 2>&1; }
c_terminal_fda() { c_read && tcc_ok com.apple.Terminal; }
c_claude_fda()   { c_read && [ -n "$(claude_id)" ] && tcc_ok "$(claude_id)"; }
c_fda()          { c_read && c_terminal_fda && c_claude_fda; }
c_app()          { [ -d /Applications/Claude.app ]; }
c_ext()          { ls "$EXT_DIR" 2>/dev/null | grep -qi imessage; }
c_cli()          { command -v claude >/dev/null 2>&1; }
c_login()        { c_cli && claude auth status 2>/dev/null | grep -q '"authMethod": *"claude.ai"'; }
c_engine()       { [ "$(engine_status)" = "ok" ]; }
c_self_chat()    { [ "$(sqlite3 "$DB" "$SELF_SQL" 2>/dev/null)" -gt 0 ] 2>/dev/null; }
c_composio()     { composio_line | grep -qiE "✔|- connected"; }
c_partb()        { [ -f "$AGENT_PLIST" ] && pgrep -f "channels $CHANNEL" >/dev/null; }
c_reply() {
  local since; since=$(cat "$STATE/since" 2>/dev/null); [ -n "$since" ] || return 1
  [ "$(sqlite3 "$DB" "SELECT COUNT(*) FROM message WHERE is_from_me=1 AND date>$since AND (instr(text,'Sent by Claude')>0 OR instr(attributedBody,CAST('Sent by Claude' AS BLOB))>0)" 2>/dev/null)" -gt 0 ] 2>/dev/null
}
run_check() { type "c_$1" >/dev/null 2>&1 || { echo "error=unknown check $1"; return 2; }; "c_$1"; }
yn() { if run_check "$1"; then echo "$1=ok"; else echo "$1=missing"; fi; }

ext_version() { cat "$EXT_DIR"/*[iI][mM]essage*/manifest.json 2>/dev/null | grep -m1 '"version"' | sed 's/[^0-9.]//g'; }

case "$1" in
status)
  for c in mac messages read terminal_fda claude_fda app ext cli login self_chat partb; do yn "$c"; done
  echo "engine=$(engine_status)"
  [ -n "$(ext_version)" ] && echo "ext_version=$(ext_version)"
  echo "running_in=${TERM_PROGRAM:-claude-app}"
  ;;
install)
  c_mac || { echo "error=not a Mac"; exit 1; }
  start_job engine
  c_app || start_job desktop
  echo "install=started"
  ;;
check)
  yn "$2"
  [ "$2" = "composio" ] && echo "composio_line=$(composio_line)"
  ;;
wait)
  shift; T=100; CHECKS=""
  while [ -n "$1" ]; do if [ "$1" = "-t" ]; then T="$2"; shift; else CHECKS="$CHECKS $1"; fi; shift; done
  for c in $CHECKS; do type "c_$c" >/dev/null 2>&1 || { echo "error=unknown check $c"; exit 2; }; done
  t=0
  while :; do
    missing=""
    for c in $CHECKS; do run_check "$c" >/dev/null 2>&1 || missing="$missing $c"; done
    [ -z "$missing" ] && { echo "wait=ok"; exit 0; }
    case "$missing" in *engine*) job_alive engine || c_engine || start_job engine;; esac
    [ "$t" -ge "$T" ] && { echo "wait=timeout"; echo "missing=${missing# }"; echo "engine=$(engine_status)"; exit 1; }
    sleep 2; t=$((t+2))
  done
  ;;
open)
  case "$2" in
    fda)        open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" ;;
    automation) open "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation" ;;
    connectors) echo "$COMPOSIO_URL" | pbcopy; open "https://claude.ai/customize/connectors"; echo "clipboard=$COMPOSIO_URL" ;;
    login)      cp "$SKILL/files/login.command" "$RUN/Log in to Claude.command"; chmod +x "$RUN/Log in to Claude.command"
                open -a Terminal "$RUN/Log in to Claude.command" ;;
    *)          echo "error=open what? fda|automation|connectors|login"; exit 1 ;;
  esac
  echo "opened=$2"
  ;;
messages-access)
  if osascript -e 'tell application "Messages" to get name' >/dev/null 2>&1; then echo "messages_access=ok"
  else echo "messages_access=denied"; fi
  ;;
partb)
  for c in engine login self_chat terminal_fda; do run_check "$c" || { echo "partb=blocked"; echo "missing=$c"; exit 1; }; done
  NAME=$(composio_line | sed 's/: .*//')
  RULE="mcp__$(echo "${NAME:-composio}" | sed 's/[^A-Za-z0-9_-]/_/g')"
  # Also allow the other usual name, in case Composio gets re-added differently later.
  ALT_RULE="mcp__composio"; [ "$RULE" = "mcp__composio" ] && ALT_RULE="mcp__claude_ai_Composio"
  mkdir -p "$HOME_DIR/.claude"
  cp "$SKILL/files/CLAUDE.md" "$HOME_DIR/CLAUDE.md"
  cat > "$HOME_DIR/.claude/settings.json" <<EOF
{
  "permissions": {
    "allow": [
      "mcp__plugin_imessage_imessage__reply",
      "mcp__plugin_imessage_imessage__chat_messages",
      "$RULE",
      "$ALT_RULE",
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
fs.writeFileSync(f, JSON.stringify(j, null, 2));' || { echo "partb=failed"; echo "error=could not update ~/.claude.json"; exit 1; }
  cp "$SKILL/files/launcher.command" "$LAUNCHER"; chmod +x "$LAUNCHER"
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
  # (Re)load the login item. Loading it opens the "Claude iMessage" window right away.
  launchctl bootout "gui/$(id -u)/$AGENT_LABEL" >/dev/null 2>&1
  pkill -f "Claude iMessage.command" >/dev/null 2>&1
  pkill -f "channels $CHANNEL" >/dev/null 2>&1
  sleep 1
  launchctl bootstrap "gui/$(id -u)" "$AGENT_PLIST" >/dev/null 2>&1 || open -a Terminal "$LAUNCHER"
  echo "composio_rule=$RULE"
  echo "partb=started"
  ;;
test-start)
  echo $(( ($(date +%s) - 978307200) * 1000000000 )) > "$STATE/since"   # Apple clock: ns since 2001
  echo "test=started"
  ;;
node-path)
  n=$(command -v node 2>/dev/null); [ -n "$n" ] && echo "node=$(readlink -f "$n" 2>/dev/null || echo "$n")" || echo "node=none"
  ;;
*)
  sed -n '2,13p' "$0"
  ;;
esac
