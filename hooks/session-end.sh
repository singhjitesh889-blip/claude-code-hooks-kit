#!/bin/bash
# Stop hook — auto-commits all changes at session end. Optionally pushes.
#
# HOW IT WORKS
# Fires when the Claude Code session ends (Stop event). Stages and commits all
# changes with a structured commit message. Pushes to GitHub only when files
# matching PUSH_WORTHY_PATTERN change — avoid unnecessary pushes for drafts.
#
# WHY THIS IS VALUABLE
# Never lose work from a session. Every session produces a commit automatically,
# even if you forget to commit manually. Push-worthy detection means critical
# files get to GitHub without pushing everything, every time.
#
# CONFIGURE
# - PROJECT_ROOT: your workspace root
# - PUSH_WORTHY_PATTERN: regex of files that should trigger a push when changed
#   Example: "^state/|^wiki/|^reports/" pushes when core knowledge files change
#
# INSTALL
# See README — configure as Stop hook in ~/.claude/settings.json

PROJECT_ROOT="${PROJECT_ROOT:-$HOME/Desktop/my-project}"
PUSH_WORTHY_PATTERN="${PUSH_WORTHY_PATTERN:-^state/|^wiki/|^outputs/}"
PUSH_LOG="$HOME/.claude/sessions/push-failures.log"
TODAY=$(date +%Y-%m-%d)
NOW=$(date +%H:%M)

cd "$PROJECT_ROOT" || exit 0

git rev-parse --is-inside-work-tree &>/dev/null || exit 0

if ! (git diff --quiet && git diff --staged --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]); then
    git add -A

    FILE_COUNT=$(git diff --staged --name-only | wc -l | tr -d ' ')
    CHANGED=$(git diff --staged --name-only | head -5 | tr '\n' ', ' | sed 's/,$//')

    git commit -m "session $TODAY $NOW — $FILE_COUNT files ($CHANGED)" -q

    # Push only when push-worthy files changed
    PUSH_WORTHY=$(git diff HEAD~1 --name-only 2>/dev/null | grep -E "$PUSH_WORTHY_PATTERN")

    if [ -n "$PUSH_WORTHY" ]; then
        git push origin main -q 2>/dev/null || \
            echo "[$TODAY $NOW] push failed" >> "$PUSH_LOG"
    fi
fi

exit 0
