#!/bin/bash
# UserPromptSubmit hook — detects session intent and injects routing context.
#
# HOW IT WORKS
# Fires on every message. Reads the user's prompt from stdin JSON, pattern-matches
# intent categories, and outputs a routing reminder when a match is found.
# Outputs nothing when no match — zero cost on unrelated messages.
#
# WHY THIS IS VALUABLE
# Without routing, the assistant either loads everything (slow, expensive) or
# guesses what context to load (unreliable). This hook makes the routing table
# in your CLAUDE.md explicit and automatic — no prompting needed.
#
# CUSTOMIZE
# Replace the routing patterns and ROUTING messages below with your domain's
# actual categories, file paths, and agent names. The pattern is the template;
# the content is yours.
#
# INSTALL
# See README — configure as UserPromptSubmit hook in ~/.claude/settings.json

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('prompt', ''))
except:
    print('')
" 2>/dev/null)

if [ -z "$PROMPT" ]; then
  exit 0
fi

P=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# ── STRATEGY / METRICS ────────────────────────────────────────────────────────
# Matches: anything involving business performance, revenue, or KPI review
if echo "$P" | grep -qE "strategy|roas|revenue review|monthly review|business review|how.*performing|metrics|kpi"; then
  echo "ROUTING → Strategy/metrics: read state/STATE.md before analysis."
  exit 0
fi

# ── CREATIVE / CONTENT ────────────────────────────────────────────────────────
# Matches: creative briefs, ad copy, content generation
if echo "$P" | grep -qE "creative|ad brief|content|copy|hook|headline|campaign brief"; then
  echo "ROUTING → Creative: read wiki/creative-brief.md first."
  exit 0
fi

# ── CUSTOMER RESEARCH ─────────────────────────────────────────────────────────
# Matches: anything involving customers, buyers, personas, voice-of-customer
if echo "$P" | grep -qE "customer|buyer|persona|voc|voice of customer|who.*buy|audience"; then
  echo "ROUTING → Customer research: read wiki/customer.md first."
  exit 0
fi

# ── DATA PROCESSING / COMPILE ─────────────────────────────────────────────────
# Matches: requests to process new data and update the WIKI
if echo "$P" | grep -qE "process.*data|compile|update.*wiki|new.*export|monthly.*data"; then
  echo "ROUTING → Data compile: follow compile-loop.md. Steps: read RAW → diff against WIKI → rewrite WIKI → update STATE."
  exit 0
fi

# ── COMPETITOR INTEL ──────────────────────────────────────────────────────────
# Matches: competitor research, rival analysis
if echo "$P" | grep -qE "competitor|rival|what.*others doing|market.*landscape"; then
  echo "ROUTING → Competitor intel: read wiki/competitors.md first."
  exit 0
fi

# ── VAULT CAPTURE ─────────────────────────────────────────────────────────────
# Matches: think: / vault: / note: prefixes → save to raw/thinking/
if echo "$P" | grep -qE "^vault:|^think:|^note:"; then
  echo "ROUTING → Vault capture: strip prefix → save to raw/thinking/YYYY-MM-DD-[slug].md → reply 'Saved ✓'"
  exit 0
fi

exit 0
