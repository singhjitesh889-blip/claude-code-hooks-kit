# claude-code-hooks-kit

The architecture in [claude-code-knowledge-architecture](https://github.com/singhjitesh889-blip/claude-code-knowledge-architecture)
is an idea. This repo is the idea *running*. Nine shell hooks turn "the
assistant should have context" into "the assistant always has context,
automatically, without me remembering to paste anything."

---

## The Pattern That Matters Most

**Session-start injects state. Every prompt gets routed. Session-end commits.**

When you open a session, a hook reads your STATE layer and hands the assistant
the current picture before you type a word. When you submit a prompt, another
hook reads the intent and injects only the relevant routing context. When
you're done, a hook commits the diff.

The subtle ones earn their keep quietest: `pre-compact` and `post-compact`
snapshot the working session before context compression and restore it after —
so the assistant doesn't restart cold mid-task. `auto-claude-md` scaffolds a
project memory file the moment a new repo appears.

Each hook is independent, commented, and safe to copy one at a time.

> **2026-09-08 correctness fix:** four hooks (`auto-git-add.sh`, `auto-claude-md.sh`,
> `pre-compact.sh`, `post-compact.sh`) used a `python3 - <<'EOF'` heredoc pattern that
> silently ate their own stdin — Claude Code's hook JSON never reached `json.load()`,
> so these ran, did nothing, and exited clean every single time since this repo was
> first published. No error, no signal — the exact failure mode this whole kit exists
> to prevent, sitting undetected in its own automation layer. Fixed by separating stdin
> capture from script-source loading; all four are now tested end-to-end against real
> hook input before every commit that touches them. Verification, not vibes — including
> here.

---

## The Hooks

| Hook | Event | What It Does |
|------|-------|--------------|
| `session-start.sh` | SessionStart | Injects STATE freshness, compile health, routing reminders |
| `user-prompt-submit.sh` | UserPromptSubmit | Detects intent, injects routing context for that domain |
| `auto-git-add.sh` | PostToolUse (Edit/Write) | Stages files immediately after Claude edits them |
| `auto-claude-md.sh` | PostToolUse (Edit/Write) | Creates CLAUDE.md in repos that don't have one |
| `pre-tool-use-guard.sh` | PreToolUse (Bash) | Blocks force-push, hard reset, `rm -rf` and similar unless explicitly bypassed |
| `subagent-verify.sh` | PostToolUse (Task) | Checks a subagent's claimed deliverable actually exists on disk |
| `pre-compact.sh` | PreCompact | Saves session snapshot (files modified, last commands, next steps) |
| `post-compact.sh` | PostCompact | Injects snapshot back into fresh context after compaction |
| `session-end.sh` | Stop | Auto-commits all changes; pushes when critical files change |

---

## Install

```bash
git clone https://github.com/singhjitesh889-blip/claude-code-hooks-kit.git
cd claude-code-hooks-kit
./install.sh
```

That copies all 9 hooks to `~/.claude/hooks/` and writes (or warns about) `settings.json`.

**Or install without cloning:**
```bash
curl -sSL https://raw.githubusercontent.com/singhjitesh889-blip/claude-code-hooks-kit/main/install.sh | bash
```

> Note: the curl path runs from a temp clone — it needs git installed.

---

### Manual install

If you prefer step-by-step:

```bash
mkdir -p ~/.claude/hooks
cp hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
```

Then merge `settings.json` into `~/.claude/settings.json`. If you don't have one yet:
```bash
cp settings.json ~/.claude/settings.json
```

If you already have a settings.json, merge the `hooks` block manually.

### Step 3 — Configure `session-start.sh`

Edit `~/.claude/hooks/session-start.sh` and set:

```bash
PROJECT_ROOT="/path/to/your/project"   # your workspace root
STATE_FILE="$PROJECT_ROOT/state/STATE.md"
```

Or set them as environment variables so the hook works across multiple projects:

```bash
export PROJECT_ROOT="$HOME/Desktop/my-project"
export STATE_FILE="$PROJECT_ROOT/state/STATE.md"
```

### Step 4 — Configure `session-end.sh`

Edit `PUSH_WORTHY_PATTERN` to match the files in your project that should
trigger a GitHub push when changed:

```bash
PUSH_WORTHY_PATTERN="^state/|^wiki/|^outputs/"
```

### Step 5 — Customize `user-prompt-submit.sh`

Replace the routing patterns with your domain's actual categories. The
template has generic examples — replace them with your real file paths,
skill names, and agent names.

---

## How the Hooks Fit the Architecture

```
SessionStart → session-start.sh
  Reads STATE.md → injects freshness + routing before first message

UserPromptSubmit → user-prompt-submit.sh
  Reads prompt → detects intent → injects domain routing hint

PostToolUse (Edit/Write) → auto-git-add.sh + auto-claude-md.sh
  Stages the edited file → creates CLAUDE.md if missing

PreToolUse (Bash) → pre-tool-use-guard.sh
  Reads the command → blocks force-push/hard-reset/rm -rf unless ALLOW_DESTRUCTIVE=1

PostToolUse (Task) → subagent-verify.sh
  Reads the subagent's reported result → checks any claimed file path exists

PreCompact → pre-compact.sh
  Scans transcript → extracts in-progress files + commands + next steps
  Saves snapshot to ~/.claude/sessions/{session_id}-snapshot.md

PostCompact → post-compact.sh
  Reads snapshot → injects into fresh context
  Deletes temp file

Stop → session-end.sh
  Stages + commits all changes → pushes when push-worthy files changed
```

---

## Notes

**pre/post-compact are a pair.** If you use one, use both. Pre without post
saves a snapshot nobody reads. Post without pre injects nothing.

**session-end uses `git add -A`.** If you're in a repo with sensitive files,
add a `.gitignore` before enabling this hook. It stages everything in the repo.

**user-prompt-submit outputs nothing when no pattern matches.** Zero cost on
messages that don't need routing. The hook is designed to be silent by default.

**These hooks work together with the knowledge architecture.** The hooks are the
automation layer; the architecture is the content layer. The STATE.md and WIKI
files that session-start and user-prompt-submit reference need to exist in your
project. See [claude-code-knowledge-architecture](https://github.com/singhjitesh889-blip/claude-code-knowledge-architecture)
for how to set those up.
