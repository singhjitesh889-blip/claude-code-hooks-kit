#!/bin/bash
# PreCompact hook — saves a compressed session snapshot before context is pruned.
#
# HOW IT WORKS
# Fires when Claude Code is about to compact (compress) the conversation context.
# Reads the session transcript, extracts: files modified, recent bash commands,
# and key activity lines (forward-looking todo/next lines prioritized).
# Saves a ~300-token snapshot to ~/.claude/sessions/{session_id}-snapshot.md.
# PostCompact picks it up and injects it into the fresh context window.
#
# WHY THIS IS VALUABLE
# Without this, compaction loses all in-progress context — Claude restarts cold
# mid-task. With pre/post-compact, the assistant knows what files it was editing,
# what commands it just ran, and what was next.
#
# INSTALL
# Configure as PreCompact hook in ~/.claude/settings.json (no tool filter needed).

input=$(cat)
SCRIPT=$(cat <<'PYEOF'
import sys, json, os
from datetime import datetime
from pathlib import Path

def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    session_id   = data.get("session_id", "")
    transcript   = data.get("transcript_path", "")
    cwd          = data.get("cwd", "")
    trigger      = data.get("trigger", "auto")

    if not session_id:
        sys.exit(0)

    if not transcript or not os.path.exists(transcript):
        sys.exit(0)

    sessions_dir = Path.home() / ".claude" / "sessions"
    sessions_dir.mkdir(exist_ok=True)

    # Clean up stale snapshots older than 24h
    cutoff = datetime.now().timestamp() - 86400
    for stale in sessions_dir.glob("*-snapshot.md"):
        try:
            if stale.stat().st_mtime < cutoff:
                stale.unlink()
        except Exception:
            pass

    files_modified = []
    bash_recent    = []
    key_activity   = []

    PRIORITY_WORDS  = ("next:", "todo:", "pending:", "open:", "→", "blocked:")
    ACTION_WORDS    = ("built", "created", "fixed", "updated", "added", "removed",
                       "decided", "completed", "saved", "deployed", "wired")

    try:
        with open(transcript, encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
    except Exception:
        sys.exit(0)

    for raw in lines:
        raw = raw.strip()
        if not raw:
            continue
        try:
            entry = json.loads(raw)
        except Exception:
            continue

        msg     = entry.get("message", {})
        content = msg.get("content", [])

        if not isinstance(content, list):
            continue

        for block in content:
            if not isinstance(block, dict):
                continue

            btype = block.get("type", "")

            if btype == "tool_use":
                name = block.get("name", "")
                inp  = block.get("input", {})

                if name in ("Edit", "Write", "NotebookEdit"):
                    fp = inp.get("file_path", "")
                    if fp and fp not in files_modified:
                        files_modified.append(fp)

                elif name == "Bash":
                    cmd = inp.get("command", "")
                    if cmd:
                        bash_recent.append(cmd[:80].replace("\n", " "))

            elif btype == "text" and msg.get("role") == "assistant":
                text  = block.get("text", "")
                lower = text.lower()
                all_kw = PRIORITY_WORDS + ACTION_WORDS
                if any(kw in lower for kw in all_kw):
                    for line in text.splitlines():
                        ls = line.strip()
                        if ls and any(kw in ls.lower() for kw in PRIORITY_WORDS):
                            key_activity.append(ls[:120])
                            break
                    else:
                        for line in text.splitlines():
                            ls = line.strip()
                            if ls and any(kw in ls.lower() for kw in ACTION_WORDS):
                                key_activity.append(ls[:120])
                                break

    now  = datetime.now()
    home = str(Path.home())

    out  = [f"# Session Snapshot — {now.strftime('%Y-%m-%d %H:%M')}"]
    out += [f"Compaction: {trigger} | Project: {os.path.basename(cwd)}", ""]

    if files_modified:
        out.append("## Files In-Progress")
        for fp in files_modified[-8:]:
            out.append(f"- {fp.replace(home, '~')}")
        out.append("")

    if key_activity:
        out.append("## Recent Activity")
        for line in key_activity[-5:]:
            out.append(f"- {line}")
        out.append("")

    if bash_recent:
        out.append("## Last Commands")
        for cmd in bash_recent[-3:]:
            out.append(f"  $ {cmd}")
        out.append("")

    out.append("*(Resume: check in-progress files above before continuing.)*")

    snapshot = "\n".join(out)
    (sessions_dir / f"{session_id}-snapshot.md").write_text(snapshot)

main()
PYEOF
)
echo "$input" | python3 -c "$SCRIPT"
