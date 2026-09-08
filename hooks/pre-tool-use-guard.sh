#!/bin/bash
# PreToolUse hook — blocks a short list of genuinely destructive shell commands
# before they run, unless explicitly bypassed.
#
# HOW IT WORKS
# Fires before every Bash tool call. Reads the command from the tool input
# JSON and checks it against a small set of patterns that are hard or
# impossible to undo: force-push, hard reset, recursive force-delete, and
# forced clean. If it matches, the hook exits 2 — Claude Code treats that as
# a block and shows the assistant the stderr message instead of running the
# command.
#
# BYPASS
# Set ALLOW_DESTRUCTIVE=1 in the environment before invoking Claude Code for
# a genuinely scripted/CI context where these commands are expected. This is
# not meant to be set casually in an interactive terminal — if you find
# yourself setting it out of friction rather than intent, that's the guard
# doing its job.
#
# INSTALL
# Configure as a PreToolUse hook matching "Bash". See README for
# settings.json configuration.

if [ "$ALLOW_DESTRUCTIVE" = "1" ]; then
    exit 0
fi

input=$(cat)
command=$(echo "$input" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null)

if [ -z "$command" ]; then
    exit 0
fi

DANGEROUS_PATTERNS=(
    'rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*f'   # rm -rf, rm -fr, rm -Rf, etc.
    'git[[:space:]]+push[[:space:]]+.*(--force|(-f)([[:space:]]|$))'
    'git[[:space:]]+reset[[:space:]]+--hard'
    'git[[:space:]]+clean[[:space:]]+.*-[a-zA-Z]*f'
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$command" | grep -qE "$pattern"; then
        echo "🚫 DESTRUCTIVE COMMAND GUARD: blocked a command matching a hard-to-reverse pattern." >&2
        echo "   Command: $command" >&2
        echo "   If this is genuinely intended, confirm with the user first, or set" >&2
        echo "   ALLOW_DESTRUCTIVE=1 for a scripted context where this is expected." >&2
        exit 2
    fi
done

exit 0
