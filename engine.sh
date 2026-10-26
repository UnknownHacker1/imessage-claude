#!/bin/bash
# Background installs, started by setup.sh with nohup so they keep going if Terminal restarts:
# Claude Code, Bun, and the iMessage plugin. Progress goes to .state/engine.status:
#   running | clt (waiting for Apple's developer tools) | ok | fail:<reason>
STATE="$HOME/imessage-claude/.state"
mkdir -p "$STATE"
echo $$ > "$STATE/engine.pid"
export PATH="$HOME/.local/bin:$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
say() { echo "$1" > "$STATE/engine.status"; }
say running

if command -v claude >/dev/null 2>&1; then
  claude update >/dev/null 2>&1   # channels need a recent Claude Code
else
  curl -fsSL https://claude.ai/install.sh | bash
  command -v claude >/dev/null 2>&1 || { say "fail:Claude Code did not install"; exit 1; }
fi

if ! command -v bun >/dev/null 2>&1; then
  curl -fsSL https://bun.sh/install | bash
  command -v bun >/dev/null 2>&1 || { say "fail:Bun did not install"; exit 1; }
fi

plugin_ok() { claude plugin list 2>/dev/null | grep -qi 'imessage@claude-plugins-official'; }
try_install() {
  claude plugin marketplace add anthropics/claude-plugins-official
  claude plugin install imessage@claude-plugins-official --scope user
  plugin_ok
}
if ! plugin_ok && ! try_install; then
  # Plugins are fetched with git. A Mac without Apple's command line tools has no real git.
  if xcode-select -p >/dev/null 2>&1; then say "fail:The iMessage plugin did not install"; exit 1; fi
  say clt
  xcode-select --install >/dev/null 2>&1
  until xcode-select -p >/dev/null 2>&1; do sleep 5; done
  say running
  try_install || { say "fail:The iMessage plugin did not install"; exit 1; }
fi
say ok
