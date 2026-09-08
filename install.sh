#!/usr/bin/env bash
set -e

HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo ""
echo "claude-code-hooks-kit installer"
echo "================================"
echo ""

# 1 — hooks
mkdir -p "$HOOKS_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/hooks/"*.sh "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/"*.sh

echo "✓ 9 hooks copied to $HOOKS_DIR"

# 2 — settings.json
if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  cp "$SCRIPT_DIR/settings.json" "$SETTINGS_FILE"
  echo "✓ settings.json written to $SETTINGS_FILE"
else
  echo ""
  echo "  settings.json already exists at $SETTINGS_FILE"
  echo "  Merge the 'hooks' block from $SCRIPT_DIR/settings.json manually."
  echo "  (Don't overwrite — you'll lose your existing config.)"
fi

# 3 — next steps
echo ""
echo "Next: configure the two hooks for your project"
echo ""
echo "  session-start.sh — set your workspace path:"
echo "    Edit $HOOKS_DIR/session-start.sh"
echo "    Set PROJECT_ROOT and STATE_FILE near the top"
echo ""
echo "  session-end.sh — set which files trigger a git push:"
echo "    Edit $HOOKS_DIR/session-end.sh"
echo "    Set PUSH_WORTHY_PATTERN to match your critical files"
echo ""
echo "Full setup guide: https://github.com/singhjitesh889-blip/claude-code-hooks-kit"
echo ""
