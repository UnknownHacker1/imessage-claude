#!/bin/bash
# Opened by the setup skill: logs Claude Code in and lets Terminal send texts.
export PATH="$HOME/.local/bin:$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
unset ANTHROPIC_API_KEY
clear
echo "Claude setup"
echo
until command -v claude >/dev/null 2>&1; do echo "Installing Claude Code, one moment..."; sleep 3; done
if ! claude auth status >/dev/null 2>&1; then
  echo "A browser window opens. Log in with your Claude account."
  claude auth login
fi
echo
echo "If a popup asks to let Terminal control Messages, click OK."
osascript -e 'tell application "Messages" to get name' >/dev/null 2>&1
echo
echo "All set. You can close this window and go back to the Claude app."
