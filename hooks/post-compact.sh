#!/bin/bash
# PostCompact hook — injects the pre-compact snapshot back into fresh context.
#
# HOW IT WORKS
# Fires immediately after context compaction. Reads the snapshot written by
# pre-compact.sh and outputs it to stdout — Claude Code injects it as
# additionalContext before the next message. Then deletes the snapshot (temp file).
#
# INSTALL
# Configure as PostCompact hook in ~/.claude/settings.json (no tool filter needed).
# Must be used together with pre-compact.sh — they work as a pair.

input=$(cat)
SCRIPT=$(cat <<'PYEOF'
import sys, json, os
from pathlib import Path

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

session_id = data.get("session_id", "")
if not session_id:
    sys.exit(0)

snapshot_path = Path.home() / ".claude" / "sessions" / f"{session_id}-snapshot.md"

if not snapshot_path.exists():
    sys.exit(0)

content = snapshot_path.read_text().strip()
if not content:
    snapshot_path.unlink(missing_ok=True)
    sys.exit(0)

print("## Context Restored After Compaction")
print(content)
print("")
print("*(Compaction occurred — context above shows what was in progress. Continue from here.)*")

snapshot_path.unlink(missing_ok=True)
PYEOF
)
echo "$input" | python3 -c "$SCRIPT"
