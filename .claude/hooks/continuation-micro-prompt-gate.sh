#!/bin/bash
# .claude/hooks/continuation-micro-prompt-gate.sh
#
# StopHook — when a continuation file was authored THIS session by ANY path
# (master-continuation-prompt skill, autovibe Phase 4.7, OR hand-authored), this
# gate ensures the session did not end without surfacing a paste-ready MICRO
# prompt in chat for the operator to fire a fresh session.
#
# WHY THIS EXISTS (2026-06-28): the master-continuation-prompt skill mandates the
# micro prompt (its Step 4.5 + exit checklist) — but a continuation HAND-AUTHORED
# during an /autovibe flow (or written directly with the Write tool) bypasses the
# skill entirely, so the mandatory step never runs and the operator is left with a
# saved continuation but no trigger to paste. Operator 2026-06-28: "u r meant to
# give me micro prompts with my continuations … prevent that from ever happening
# again." Per the decide-dont-menu doctrine (structural gate over
# band-aid on recurring incidents): a passive rule with no executing step does not
# prevent recurrence; this hook is the executing step.
#
# DESIGN (hook-efficiency.md triple-gate + block-ONCE, self-resolving):
#   Gate 1 — a NON-AUTO continuation .md modified in the last 6h exists.
#   Gate 2 — this session has not already been nudged for it (per-marker).
#   Gate 3 — no micro-prompt signature in the transcript.
#   → emit decision:block ONCE with a reason instructing the model to surface the
#     micro prompt. Once the model emits it, the transcript carries the signature
#     and a re-fire passes; the marker also prevents a second block (fail-open
#     after one nudge so a regex-miss can never trap the session).
#
# SAFETY: always exits 0 on its own errors (fail-open). Reads only; writes only a
# /tmp marker. Never commits/pushes/mutates the repo.
#
# Kill-switch (hook-profile-gating.md): HOOK_CONTINUATION_MICRO_PROMPT_GATE=0

set -uo pipefail

HOOK_DISABLE_VAL="$(printf '%s' "${HOOK_CONTINUATION_MICRO_PROMPT_GATE:-}" | tr '[:upper:]' '[:lower:]')"
case "$HOOK_DISABLE_VAL" in
  0|false|no|off|disabled)
    echo "continuation-micro-prompt-gate: DISABLED via HOOK_CONTINUATION_MICRO_PROMPT_GATE=${HOOK_CONTINUATION_MICRO_PROMPT_GATE} — unset or set to 1/true/yes/enabled to re-enable" >&2
    exit 0
    ;;
esac

# ── Read Stop payload from stdin (transcript_path) ───────────────────────────
STDIN="$(cat 2>/dev/null || echo '')"
TRANSCRIPT_PATH="$(printf '%s' "$STDIN" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"
CONTINUATIONS_DIR="$PROJECT_ROOT/continuations"
[ -z "$PROJECT_ROOT" ] && exit 0
[ ! -d "$CONTINUATIONS_DIR" ] && exit 0

# ── Gate 1: a continuation ACTUALLY authored this session ────────────────────
# Exclude auto-generated stubs: -AUTO- (session-end-continuation-gate.sh) and
# -DRAFT (post-handoff-writer.sh) — both carry their own pickup protocol and are
# not operator-fired micro prompts.
#
# mtime alone is UNRELIABLE: a `git worktree add`/checkout or an artefact-sync
# bumps the mtime of OLD continuations that were NOT authored this session
# (false-positive precedent 2026-06-28: a 2026-06-24 DRAFT fired the gate after a
# worktree checkout bumped its mtime). So a recent-mtime candidate must ALSO be
# git-confirmed as authored/edited this session: uncommitted in the working tree
# (the core "authored but no micro-prompt yet" gap) OR committed within the 6h
# window. A clean, long-committed file with a merely-bumped mtime is skipped.
RECENT_CONT=""
while IFS= read -r _f; do
  [ -z "$_f" ] && continue
  if [ -n "$(git -C "$PROJECT_ROOT" status --porcelain -- "$_f" 2>/dev/null)" ]; then RECENT_CONT="$_f"; break; fi
  if [ -n "$(git -C "$PROJECT_ROOT" log -1 --since='6 hours ago' --format=%h -- "$_f" 2>/dev/null)" ]; then RECENT_CONT="$_f"; break; fi
done <<EOF
$(find "$CONTINUATIONS_DIR" -maxdepth 1 -type f -name '*.md' -mmin -360 2>/dev/null | grep -v -- '-AUTO-' | grep -v -- '-DRAFT')
EOF
[ -z "$RECENT_CONT" ] && exit 0
CONT_BASE="$(basename "$RECENT_CONT")"

# ── Gate 2: not already nudged this session for this continuation ────────────
MARKER_DIR="${TMPDIR:-/tmp}/bb-continuation-microprompt-gate"
mkdir -p "$MARKER_DIR" 2>/dev/null || true
# Key the marker on the continuation filename (stable across re-fires this session).
MARKER_KEY="$(printf '%s' "$CONT_BASE" | tr -dc 'A-Za-z0-9' | tail -c 60)"
MARKER="$MARKER_DIR/${MARKER_KEY}.nudged"
[ -f "$MARKER" ] && exit 0

# ── Gate 3: micro-prompt signature already in the transcript? ────────────────
# Signature = the transcript mentions the continuation filename AND a fire verb
# (/autovibe, /execute, /Master-Continuation, "paste into", "micro prompt").
# Both present ⇒ the operator was handed a paste-ready trigger ⇒ pass.
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  if grep -qF "$CONT_BASE" "$TRANSCRIPT_PATH" 2>/dev/null \
     && grep -qiE '/autovibe|/execute|/master-continuation|paste into|micro[ -]?prompt' "$TRANSCRIPT_PATH" 2>/dev/null; then
    exit 0
  fi
fi

# ── Block ONCE: instruct the model to surface the micro prompt ───────────────
: > "$MARKER" 2>/dev/null || true   # fail-open after this single nudge

REASON="A continuation was authored this session (${CONT_BASE}) but no paste-ready MICRO prompt was surfaced in chat. Per .claude/rules/continuation-micro-prompt-surfacing.md: every continuation MUST be accompanied by a fenced, copyable micro prompt the operator can paste into a fresh chat to fire it (file reference + 2-3 sentences of next-step). Emit that micro prompt now, then finish."

# Stop-hook block contract: JSON on stdout with decision=block re-prompts the model.
printf '{"decision":"block","reason":"%s"}\n' "$(printf '%s' "$REASON" | sed 's/\\/\\\\/g; s/"/\\"/g')"
exit 0
