#!/bin/bash
# SessionStart hook — injects project state into every Claude Code session.
#
# HOW IT WORKS
# Claude Code fires this on session open. Output goes to stdout and gets
# injected as additionalContext before the first message. The assistant
# reads it automatically — you don't paste anything.
#
# CONFIGURE
# Set PROJECT_ROOT to your workspace root and STATE_FILE to your STATE.md path.
# Edit the ROUTING section at the bottom to match your domain.
#
# INSTALL
# See ~/.claude/settings.json hooks configuration in the repo README.

PROJECT_ROOT="${PROJECT_ROOT:-$HOME/Desktop/my-project}"
STATE_FILE="${STATE_FILE:-$PROJECT_ROOT/state/STATE.md}"
PUSH_LOG="$HOME/.claude/sessions/push-failures.log"
TODAY=$(date +%Y-%m-%d)

echo "# Session Context — $TODAY"
echo ""

# ── 1. PUSH FAILURE ALERT ──────────────────────────────────────────────────────
# Surfaces recent push failures so they don't silently accumulate.
if [ -f "$PUSH_LOG" ]; then
    RECENT=$(awk -v d="$(date -d '2 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-2d '+%Y-%m-%d')" '$0 >= d' "$PUSH_LOG" 2>/dev/null | tail -3)
    if [ -n "$RECENT" ]; then
        echo "⚠️ RECENT PUSH FAILURES (check GitHub sync):"
        echo "$RECENT"
        echo ""
    fi
fi

# ── 2. STATE FRESHNESS CHECK ───────────────────────────────────────────────────
# Reads last_updated from STATE.md and warns when stale.
# Adjust the staleness threshold (default: 7 days) to your cycle.
STALENESS_DAYS="${STATE_STALENESS_DAYS:-7}"

if [ -f "$STATE_FILE" ]; then
    LAST_UPDATED=$(grep -m1 "last_updated:" "$STATE_FILE" | awk '{print $2}' | tr -d '"')
    if [ -n "$LAST_UPDATED" ]; then
        STATE_AGE=$(( ( $(date +%s) - $(date -j -f "%Y-%m-%d" "$LAST_UPDATED" +%s 2>/dev/null || date -d "$LAST_UPDATED" +%s 2>/dev/null) ) / 86400 ))
        echo "## Project State"
        if [ "$STATE_AGE" -gt "$STALENESS_DAYS" ]; then
            echo "⚠️  STATE.md last updated: $LAST_UPDATED (${STATE_AGE}d ago) — update before strategy work."
        else
            echo "✅ STATE.md last updated: $LAST_UPDATED (${STATE_AGE}d ago)"
        fi
        echo ""
    fi
fi

# ── 3. COMPILE LOOP HEALTH ─────────────────────────────────────────────────────
# Checks your compile-log.md to surface how long since last compile.
# Optional — remove this block if you don't use the compile loop.
COMPILE_LOG="${COMPILE_LOG:-$PROJECT_ROOT/compile-log.md}"
COMPILE_AMBER="${COMPILE_AMBER_DAYS:-28}"
COMPILE_RED="${COMPILE_RED_DAYS:-35}"

if [ -f "$COMPILE_LOG" ]; then
    LAST_COMPILE=$(grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' "$COMPILE_LOG" | sort -r | head -1)
    if [ -n "$LAST_COMPILE" ]; then
        COMPILE_AGE=$(( ( $(date +%s) - $(date -j -f "%Y-%m-%d" "$LAST_COMPILE" +%s 2>/dev/null || date -d "$LAST_COMPILE" +%s 2>/dev/null) ) / 86400 ))
        if [ "$COMPILE_AGE" -gt "$COMPILE_RED" ]; then
            echo "🔴 COMPILE overdue — last run ${COMPILE_AGE}d ago. Run compile loop before wiki-dependent work."
            echo ""
        elif [ "$COMPILE_AGE" -gt "$COMPILE_AMBER" ]; then
            echo "⚠️  COMPILE ${COMPILE_AGE}d ago — consider running soon."
            echo ""
        fi
    fi
fi

# ── 4. ROUTING REMINDERS ───────────────────────────────────────────────────────
# Customize these to match your project's context router in CLAUDE.md.
# Remove any lines that don't apply to your domain.
echo "## Quick Routing"
echo "- Strategy / metrics → read state/STATE.md first"
echo "- Creative / content → read wiki/creative-brief.md"
echo "- Customer research → read wiki/customer.md"
echo "- Competitor intel → read wiki/competitors.md"
echo "- Dev work → read that project's CLAUDE.md"
