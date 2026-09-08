#!/bin/bash
# PostToolUse hook — checks that a deliverable a subagent claims to have
# created actually exists on disk before the parent session trusts it.
#
# HOW IT WORKS
# Fires after every Task (subagent dispatch) tool call. Scans the subagent's
# reported result for common "created/wrote/saved to <path>" phrasing,
# extracts each candidate file path, and checks it exists. If a claimed path
# is missing, it prints a warning as additionalContext — this does not block,
# because the pattern-match is best-effort and false positives are possible.
# The point isn't to police every subagent report; it's to catch the specific,
# recurring failure where a subagent describes work it didn't actually do.
#
# THIS IS THE VERIFIER-GATE PATTERN, WIRED INTO THE HARNESS ITSELF
# See https://github.com/singhjitesh889-blip/verifier-gate-pattern for the
# same idea in isolation: a producer's claim is not the same thing as a
# checked fact.
#
# INSTALL
# Configure as a PostToolUse hook matching "Task". See README for
# settings.json configuration.

input=$(cat)
echo "$input" | python3 -c "
import sys, json, os, re

try:
    data = json.load(sys.stdin)
    result = data.get('tool_response', '')
    if isinstance(result, dict):
        result = json.dumps(result)
    if not isinstance(result, str) or not result:
        sys.exit(0)

    patterns = [
        r'(?:created|wrote|saved|written)\s+(?:file\s+)?(?:at|to)\s+[\`\"]?([^\s\`\"]+\.[a-zA-Z0-9]+)',
        r'File created(?:\s+successfully)? at\s+[\`\"]?([^\s\`\"]+\.[a-zA-Z0-9]+)',
    ]

    claimed_paths = set()
    for pattern in patterns:
        for match in re.finditer(pattern, result, re.IGNORECASE):
            claimed_paths.add(match.group(1))

    missing = [p for p in claimed_paths if not os.path.exists(p)]

    if missing:
        print('[subagent-verify] claimed deliverable(s) not found on disk:')
        for p in missing:
            print(f'  - {p}')
        print('Treat this subagent report as unverified until confirmed.')

except Exception:
    pass  # Never block Claude — this is advisory, not enforcement.
"
