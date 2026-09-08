#!/bin/bash
# PostToolUse hook — auto-stages files after Claude edits them.
#
# HOW IT WORKS
# Fires after every Edit, Write, or NotebookEdit tool call. Reads the file path
# from the tool input JSON and runs `git add` on it. The file is staged immediately,
# not at commit time — so session-end.sh picks up a clean staged diff.
#
# WHY THIS IS VALUABLE
# Without this, session-end.sh has to `git add -A` and may catch unintended files.
# With this, only files Claude actually touched get staged. Safer, cleaner history.
#
# INSTALL
# Configure as PostToolUse hook for Edit, Write, NotebookEdit tools.
# See README for settings.json configuration.

input=$(cat)
echo "$input" | python3 -c "
import sys, json, subprocess, os

try:
    data = json.load(sys.stdin)
    fp = data.get('tool_input', {}).get('file_path', '')

    if not fp or not os.path.exists(fp):
        sys.exit(0)

    dr = os.path.dirname(fp) or '.'

    check = subprocess.run(
        ['git', '-C', dr, 'rev-parse', '--is-inside-work-tree'],
        capture_output=True
    )
    if check.returncode != 0:
        sys.exit(0)

    subprocess.run(['git', '-C', dr, 'add', fp], capture_output=True)
    print(f'[hook] Auto-staged: {fp}')

except Exception:
    pass  # Never block Claude
"
