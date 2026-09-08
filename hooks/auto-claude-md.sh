#!/bin/bash
# PostToolUse hook — creates CLAUDE.md when Claude edits a repo that doesn't have one.
#
# HOW IT WORKS
# Fires after Edit/Write/NotebookEdit. Finds the git root for the edited file.
# If no CLAUDE.md exists at the root, creates one from a template that detects
# the stack from package.json and requirements.txt. Auto-stages the new file.
#
# WHY THIS IS VALUABLE
# Every repo that Claude touches gets project memory — automatically. Without this,
# you create CLAUDE.md manually (or forget to). With this, it's there the first
# time Claude edits any file.
#
# INSTALL
# Configure as PostToolUse hook for Edit, Write, NotebookEdit tools.
# See README for settings.json configuration.

input=$(cat)
echo "$input" | python3 -c "
import sys, json, subprocess, os
from datetime import date

try:
    data = json.load(sys.stdin)
    fp = data.get('tool_input', {}).get('file_path', '')

    if not fp or not os.path.exists(fp):
        sys.exit(0)

    result = subprocess.run(
        ['git', '-C', os.path.dirname(fp), 'rev-parse', '--show-toplevel'],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        sys.exit(0)

    repo_root = result.stdout.strip()
    claude_md_path = os.path.join(repo_root, 'CLAUDE.md')

    if os.path.exists(claude_md_path):
        sys.exit(0)

    stack_hints = []
    pkg_json = os.path.join(repo_root, 'package.json')
    if os.path.exists(pkg_json):
        with open(pkg_json) as f:
            content = f.read()
        if 'next' in content:
            stack_hints.append('Next.js')
        if 'typescript' in content or '\"ts\"' in content:
            stack_hints.append('TypeScript')
        if 'tailwind' in content:
            stack_hints.append('Tailwind CSS')
    if os.path.exists(os.path.join(repo_root, 'requirements.txt')):
        stack_hints.append('Python')

    stack_str = ' + '.join(stack_hints) if stack_hints else 'Unknown'
    repo_name = os.path.basename(repo_root)

    template = f'''# {repo_name} — CLAUDE.md

## Project Overview
<!-- Describe what this project does and who uses it -->

## Stack
{stack_str}

## Key Files
| File | Purpose |
|------|---------|
| | |

## Environment Variables
| Variable | Where set | Purpose |
|----------|-----------|---------|
| | | |

## Deploy Flow
<!-- How to deploy changes -->

## Known Issues / Decisions
<!-- Important architectural decisions and known bugs -->

---
*Auto-created by claude-code-hooks-kit on {date.today()}. Update as the project evolves.*
'''

    with open(claude_md_path, 'w') as f:
        f.write(template)

    subprocess.run(['git', '-C', repo_root, 'add', claude_md_path], capture_output=True)
    print(f'[hook] Created CLAUDE.md in {repo_root}')

except Exception:
    pass  # Never block Claude
"
