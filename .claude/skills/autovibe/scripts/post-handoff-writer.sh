#!/usr/bin/env bash
# autovibe/post-handoff-writer.sh — Pillar B' chain-handoff writer
#
# Closes the "chats lose context across handoff" gap from the 2026-04-30
# Agentic OS Architecture proposal. Council session reframed Pillar B from
# "auto-spawn fresh chats" to "write the next continuation reliably; spawn
# is opt-in v2".
#
# WHAT THIS DOES
# After autovibe Phase 4 (post-ship documentation) completes, this writer
# produces a structural draft continuation at:
#   continuations/AUTOVIBE-{SESSION_TS}-{SLUG}-DRAFT.md
#
# The next chat reads this file and uses it as a starting point for its
# own work. The "DRAFT" suffix signals "verify before proceeding" — the
# next chat is expected to validate the auto-generated claims against
# live state (per Edge Case Finder edge 6: autovibe-success-with-silent-
# regressions failure mode).
#
# WHY NOT INVOKE master-continuation-prompt SKILL DIRECTLY
# The skill requires conversation context (Skill tool); this is a shell
# script invoked from post-ship.sh. The skill can be invoked by the
# autovibe orchestrator at the chat level — that is a v2 enhancement
# tracked separately. This writer produces the structural skeleton; the
# skill (when invoked) produces the rich narrative continuation.
#
# IDEMPOTENCY
# Filename uses the autovibe session's started_at timestamp. Same session
# re-running post-ship → same filename → existence check (Edge Case
# Finder M-4) skips rather than overwriting. Hand-written continuations
# at unrelated paths are never touched.
#
# HEARTBEAT (Reliability Engineer non-shippable flag)
# Always emits "Continuation written to: <path>" or "Continuation skipped:
# <reason>" to stdout. Missing line = writer didn't run.
#
# SELF-TEST: bash <this script> --self-test
# Exit codes: 0 always (writer is opportunistic — failures log to stderr).

set -uo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# ---------------------------------------------------------------------------
# Configuration (resolved per-invocation so tests + caller-changed
# CLAUDE_PROJECT_DIR are respected)
# ---------------------------------------------------------------------------

resolve_paths() {
  REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  AV_STATE="${REPO_ROOT}/.claude/autovibe-state.json"
  SHIP_STATE="${REPO_ROOT}/.claude/ship-state.json"
  CONTINUATIONS_DIR="${REPO_ROOT}/continuations"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

read_json_field() {
  # _read: safe jq with empty-string fallback. Mirrors post-ship.sh pattern.
  local file="$1"
  local path="$2"
  if [ ! -f "$file" ]; then
    echo ""
    return
  fi
  jq -r "$path // empty" "$file" 2>/dev/null || echo ""
}

slugify() {
  # Convert "ROADMAP item: CM.34 Analysis tab" → "roadmap-cm-34-analysis-tab"
  echo "$1" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9]+/-/g' |
    sed -E 's/^-+|-+$//g' |
    head -c 60
}

ts_to_filename() {
  # ISO 8601 → filename-friendly: 2026-04-30T11:30:00Z → 2026-04-30-1130
  local iso="$1"
  if [ -z "$iso" ]; then
    date -u +%Y-%m-%d-%H%M
    return
  fi
  echo "$iso" | sed -E 's/T([0-9]{2}):([0-9]{2}).*/-\1\2/' | head -c 16
}

# ---------------------------------------------------------------------------
# Continuation skeleton builder
# ---------------------------------------------------------------------------

build_skeleton() {
  local session_ts="$1"
  local intent="$2"
  local commit_sha="$3"
  local pr_number="$4"
  local elapsed="$5"
  local ship_signal="$6"

  cat <<EOF
<!-- impl_status: pending -->
<!-- impl_session: AUTOVIBE-${session_ts} -->
<!-- impl_completed_date: -->
<!-- generator: post-handoff-writer.sh -->
<!-- DRAFT — verify all claims below against live state before acting -->

# Auto-generated handoff continuation (DRAFT)

**Session timestamp**: ${session_ts:-<unknown>}
**Source**: autovibe Phase 4 — post-handoff-writer.sh
**Status**: DRAFT — auto-generated, verify before proceeding

---

## ⚠ Verification gate (do FIRST)

The next chat MUST validate these auto-generated claims before acting on
them. Edge Case Finder edge 6 (autovibe-succeeds-with-silent-regressions)
is a real failure mode — the writer cannot tell whether the work shipped
correctly, only that autovibe exited.

\`\`\`bash
# 1. Verify the cited PR actually merged + checks were green
gh pr view ${pr_number:-<N>} --json state,mergeCommit,statusCheckRollup
# Expect: state=MERGED, statusCheckRollup all SUCCESS or playwright-flake-only

# 2. Verify the cited commit landed on main
git log --oneline origin/main | grep ${commit_sha:-<sha>}

# 3. Confirm canary green (your project specific)
# Run any pipeline canary check the repo has
\`\`\`

If any check fails, STOP — the autovibe run may have shipped silent
regressions. Investigate before continuing.

---

## What the previous session shipped (claimed)

| Field | Value |
|---|---|
| Intent | ${intent:-<unknown>} |
| Commit SHA | ${commit_sha:-<unknown>} |
| PR number | ${pr_number:-<unknown>} |
| Ship signal | ${ship_signal:-clean} |
| Elapsed | ${elapsed:-<unknown>} |

---

## Suggested next scope

(Auto-generator does not infer next scope — that is a human/master-cont
skill responsibility. Replace this section with the actual next-scope
plan, derived from ROADMAP NOW + recent council decisions + capacity.)

Common candidates the next chat may consider:
- The next item in the same ROADMAP track that just shipped
- A follow-up gap surfaced by the previous session's code-council (search
  recent council/ outputs)
- An untracked item from MEMORY.md "In-Flight Work" index

---

## Files this session may have touched

(Run \`git show ${commit_sha:-<sha>} --stat\` to enumerate. Auto-generator
does not embed the diff here — it would inflate the continuation and go
stale on amend.)

---

## Next steps for the next chat

1. Run the verification gate above. If any check fails, halt.
2. Read this draft fully. Replace placeholders (\`<unknown>\`,
   "Suggested next scope") with concrete content.
3. Either rename this file to a proper master continuation
   (\`{SCOPE}-MASTER-CONTINUATION-{DATE}.md\`) once enriched, or delete it
   if not useful.
4. Begin work per the verified scope.

---

## Pocock skill composition (Spec 22 — adopted 2026-05-02)

The autovibe planned mode auto-invokes Pocock skills at specific phases:
- Phase 3a: \`pocock-grill-with-docs\` (laser-precision signal OR no CONTEXT.md)
- Phase 8a: \`pocock-improve-codebase-architecture\` (refactor classification)
- Phase 8b: \`tdd-design-companion\` rule (when test files written)
- Phase 8c: \`pocock-diagnose\` (test fail / runtime err / perf regression)
- Status output: \`caveman\` (passive, AUTOVIBE_FORMAT=json)

Next chat: if continuing the SAME work scope, invoke the same skills explicitly
to maintain composition. If continuing a NEW scope, the skills auto-fire per
\`.claude/skills/autovibe/modes/planned.md\` triggers.

NewClaw dispatch composition: see
\`agency/orchestration/newclaw-pocock-skill-dispatch.md\` for the
session_type → skill map (used when NewClaw kernel dispatches coding sessions).

## Generator notes

- Filename pattern: \`AUTOVIBE-{SESSION_TS}-{SLUG}-DRAFT.md\` — naturally
  idempotent (same session ID → same filename). Re-running post-handoff-
  writer on the same session is a no-op (existence check).
- For a richer narrative continuation, invoke the
  \`master-continuation-prompt\` skill from the next chat (the structural
  skeleton above is intentionally minimal).
EOF
}

# ---------------------------------------------------------------------------
# Main writer
# ---------------------------------------------------------------------------

write_continuation() {
  resolve_paths
  local session_ts intent commit_sha pr_number elapsed ship_signal
  session_ts=$(read_json_field "$AV_STATE" '.started_at')
  intent=$(read_json_field "$AV_STATE" '.intent')
  commit_sha=$(read_json_field "$SHIP_STATE" '.commit_sha')
  pr_number=$(read_json_field "$SHIP_STATE" '.pr_number')
  elapsed=$(read_json_field "$AV_STATE" '.elapsed')
  ship_signal="${SHIP_SIGNAL:-clean}"

  if [ ! -d "$CONTINUATIONS_DIR" ]; then
    echo "Continuation skipped: continuations/ dir does not exist at ${CONTINUATIONS_DIR}" >&2
    return 0
  fi

  local ts_part slug filename target master_target
  ts_part=$(ts_to_filename "$session_ts")
  slug=$(slugify "${intent:-autovibe-session}")
  filename="AUTOVIBE-${ts_part}-${slug}-DRAFT.md"
  target="${CONTINUATIONS_DIR}/${filename}"
  master_target="${CONTINUATIONS_DIR}/AUTOVIBE-${ts_part}-${slug}-MASTER.md"

  # Spec 25 Pillar C′ — MASTER supersedes DRAFT (added 2026-05-08).
  # If autovibe Phase 4.7 wrote a rich MASTER continuation at the canonical
  # path, the structural DRAFT skeleton is redundant — skip it. The rich
  # version contains everything the DRAFT would have plus 12-section depth.
  # Graceful degradation preserved: if Phase 4.7 didn't run / failed / timed
  # out, MASTER does not exist, this branch falls through to DRAFT write.
  if [ -f "$master_target" ]; then
    local master_size
    master_size=$(wc -c <"$master_target" 2>/dev/null | tr -d ' ')
    if [ -n "$master_size" ] && [ "$master_size" -gt 100 ]; then
      echo "Continuation skipped: rich MASTER continuation already written at ${master_target} (Phase 4.7 succeeded)"
      return 0
    else
      # MASTER file exists but suspiciously small (<100 bytes) — likely
      # truncated mid-write (EC-2 partial-write edge case). Don't trust it;
      # write DRAFT as recovery fallback. Preserve the suspicious MASTER
      # for human inspection (don't auto-delete).
      echo "Continuation: MASTER file exists at ${master_target} but size ${master_size}B suspicious — writing DRAFT as recovery fallback" >&2
    fi
  fi

  # Idempotency / existence check (Edge Case Finder M-4):
  # if the same-named file already exists, do NOT overwrite. Same-named
  # implies same session_ts + same intent slug → same scope. The user may
  # have hand-edited it.
  if [ -f "$target" ]; then
    echo "Continuation skipped: ${target} already exists (idempotent re-run or hand-edited file present)"
    return 0
  fi

  build_skeleton "$session_ts" "$intent" "$commit_sha" "$pr_number" "$elapsed" "$ship_signal" >"$target"
  echo "Continuation written to: ${target}"
  return 0
}

# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------

run_self_test() {
  local pass=0
  local fail=0
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" EXIT

  echo "post-handoff-writer self-test"
  echo "==============================="

  check() {
    local name="$1"
    local cond="$2"
    if [ "$cond" = "true" ]; then
      echo "  PASS  $name"
      pass=$((pass + 1))
    else
      echo "  FAIL  $name"
      fail=$((fail + 1))
    fi
  }

  # Set up synthetic project root
  mkdir -p "$tmpdir/.claude" "$tmpdir/continuations"
  cat >"$tmpdir/.claude/autovibe-state.json" <<'EOF'
{
  "started_at": "2026-04-30T11:30:00Z",
  "intent": "Pillar B: chain-handoff writer",
  "elapsed": "PT45M"
}
EOF
  cat >"$tmpdir/.claude/ship-state.json" <<'EOF'
{
  "commit_sha": "abc1234567890",
  "pr_number": "999"
}
EOF

  # Run with synthetic root
  CLAUDE_PROJECT_DIR="$tmpdir" SHIP_SIGNAL="clean" \
    out=$(write_continuation 2>&1)

  # T1 — output includes "Continuation written to:"
  if [[ "$out" == *"Continuation written to:"* ]]; then
    check "T1 output includes 'Continuation written to:' (heartbeat)" true
  else
    check "T1 output includes 'Continuation written to:' (heartbeat)" false
  fi

  # T2 — file actually written at expected path
  local expected="$tmpdir/continuations/AUTOVIBE-2026-04-30-1130-pillar-b-chain-handoff-writer-DRAFT.md"
  if [ -f "$expected" ]; then
    check "T2 file written at timestamp+slug-derived path" true
  else
    check "T2 file written at timestamp+slug-derived path (expected: $expected)" false
  fi

  # T3 — idempotency: re-run, expect "skipped" message
  CLAUDE_PROJECT_DIR="$tmpdir" SHIP_SIGNAL="clean" \
    out2=$(write_continuation 2>&1)
  if [[ "$out2" == *"Continuation skipped:"* ]] && [[ "$out2" == *"already exists"* ]]; then
    check "T3 idempotency: re-run skips with explicit message" true
  else
    check "T3 idempotency: re-run skips with explicit message" false
  fi

  # T4 — file content includes verification gate
  if [ -f "$expected" ] && grep -q "Verification gate" "$expected"; then
    check "T4 skeleton includes verification gate (Edge Case Finder edge 6 mitigation)" true
  else
    check "T4 skeleton includes verification gate" false
  fi

  # T5 — file content includes the cited PR number
  if [ -f "$expected" ] && grep -q "999" "$expected"; then
    check "T5 skeleton cites PR number from ship-state.json" true
  else
    check "T5 skeleton cites PR number from ship-state.json" false
  fi

  # T6 — file content uses session_ts from autovibe-state.json (not current date)
  if [ -f "$expected" ] && grep -q "2026-04-30T11:30:00Z" "$expected"; then
    check "T6 skeleton uses session_ts (not current date) — Edge Case Finder edge 10" true
  else
    check "T6 skeleton uses session_ts (not current date)" false
  fi

  # T7 — missing state files: graceful skip without crash
  rm -rf "$tmpdir/.claude" "$tmpdir/continuations"
  mkdir -p "$tmpdir/continuations"
  CLAUDE_PROJECT_DIR="$tmpdir" SHIP_SIGNAL="clean" \
    out3=$(write_continuation 2>&1)
  if [[ "$out3" == *"Continuation written to:"* ]] || [[ "$out3" == *"Continuation skipped:"* ]]; then
    # Missing state files leave fields empty but writer doesn't crash; it
    # writes a continuation with <unknown> placeholders.
    check "T7 missing state files: graceful, no crash" true
  else
    check "T7 missing state files: graceful, no crash (got: $out3)" false
  fi

  # T8 — missing continuations/ dir: skip with explicit reason
  rm -rf "$tmpdir/continuations"
  CLAUDE_PROJECT_DIR="$tmpdir" SHIP_SIGNAL="clean" \
    out4=$(write_continuation 2>&1)
  if [[ "$out4" == *"continuations/ dir does not exist"* ]]; then
    check "T8 missing continuations/ dir: explicit skip message" true
  else
    check "T8 missing continuations/ dir: explicit skip message (got: $out4)" false
  fi

  # T9 (Spec 25 Pillar C′) — MASTER existence supersedes DRAFT write
  rm -rf "$tmpdir/.claude" "$tmpdir/continuations"
  mkdir -p "$tmpdir/.claude" "$tmpdir/continuations"
  cat >"$tmpdir/.claude/autovibe-state.json" <<'EOF'
{
  "started_at": "2026-04-30T11:30:00Z",
  "intent": "Pillar B chain-handoff writer",
  "elapsed": "PT45M"
}
EOF
  cat >"$tmpdir/.claude/ship-state.json" <<'EOF'
{
  "commit_sha": "abc1234567890",
  "pr_number": "999"
}
EOF
  # Write a "rich" MASTER file (>100 bytes) at the canonical path
  local master_path="$tmpdir/continuations/AUTOVIBE-2026-04-30-1130-pillar-b-chain-handoff-writer-MASTER.md"
  printf 'rich master continuation %s\n' "$(printf 'x%.0s' {1..200})" > "$master_path"
  CLAUDE_PROJECT_DIR="$tmpdir" SHIP_SIGNAL="clean" \
    out_t9=$(write_continuation 2>&1)
  if [[ "$out_t9" == *"rich MASTER continuation already written"* ]] && \
     [[ "$out_t9" != *"Continuation written to:"* ]]; then
    check "T9 MASTER existence supersedes DRAFT (Phase 4.7 succeeded)" true
  else
    check "T9 MASTER existence supersedes DRAFT (got: $out_t9)" false
  fi

  # T10 (Spec 25 Pillar C′) — suspiciously-small MASTER triggers DRAFT recovery
  # Replace MASTER with truncated stub (<100 bytes — partial-write simulation)
  printf 'partial' > "$master_path"  # 7 bytes — simulates EC-2 partial write
  CLAUDE_PROJECT_DIR="$tmpdir" SHIP_SIGNAL="clean" \
    out_t10=$(write_continuation 2>&1)
  if [[ "$out_t10" == *"size"*"suspicious"* ]] && [[ "$out_t10" == *"Continuation written to:"* ]]; then
    check "T10 truncated MASTER triggers DRAFT recovery fallback" true
  else
    check "T10 truncated MASTER triggers DRAFT recovery fallback (got: $out_t10)" false
  fi
  rm -f "$master_path"

  echo "==============================="
  if [ "$fail" -eq 0 ]; then
    echo "post-handoff-writer self-test: ALL PASS ($pass/$((pass + fail)))"
    exit 0
  else
    echo "post-handoff-writer self-test: $fail FAILURES ($pass/$((pass + fail)))" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if [[ "${1:-}" == "--self-test" ]]; then
  run_self_test
fi

# Args (mirrors post-ship.sh contract):
#   $1 = ship_exit_code (informational, not strictly required)
#   $2 = ship_signal    (clean | rollback | admin_merge | smoke_unverifiable)
SHIP_EXIT="${1:-}"
SHIP_SIGNAL="${2:-clean}"

write_continuation
exit 0
