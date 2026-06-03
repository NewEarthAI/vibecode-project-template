#!/bin/bash
# .claude/skills/autovibe/scripts/newvibe-dispatch-lib.sh
#
# NewVibe autofire — shared dispatch library. SOURCED by the two hook entry
# points (newvibe-autofire-stop.sh, newvibe-precompact-handoff.sh). It is the
# shell-enforced replacement for the conversational SKILL.md Phase 4.6/4.8 prose
# (Gate A fix, 2026-05-17). The Phase 4.8 dispatch is transcribed here so it can
# never be silently dropped on a long session.
#
# Public entry point:
#   nv_autofire <canonical_continuation_path> <trigger>   trigger = stop|precompact
#
# Helpers also used by the hooks:
#   nv_resolve_paths            sets NV_* path globals
#   nv_detect_ship_completion   Stop-hook completion signal -> echoes path / rc
#   nv_find_latest_continuation echoes newest AUTOVIBE-*-MASTER.md
#
# Self-test (hermetic — no n8n, no real verifier needed):
#   newvibe-dispatch-lib.sh --self-test
#
# Safety model — three independent fail-closed layers, every gate skips on doubt:
#   1. kill-switch  (AUTOVIBE_AUTOFIRE env)
#   2. runaway cap  (newvibe-chain-guard.sh, depth <= 5)
#   3. arm flag     (.claude/.newvibe-autofire-armed) — SINGLE-FIRE: the flag is
#                    consumed after each real dispatch, so every real autofire
#                    is a fresh, deliberate operator decision, at ANY hour.
# Plus verifier PASS, sha256 TOCTOU re-check, mkdir lock, destructive scan, and
# a dispatch-once dedup that protects BOTH hooks.
#
# Dispatch only happens when ARMED. Unarmed (the default) or NEWVIBE_DRYRUN=1 =>
# every gate runs, a "would-dispatch" entry is logged, but nothing is curled.
#
# 2026-05-17: the SAST daytime gate (inherited A10) was removed — a clock is a
# poor proxy for "an operator is supervising", redundant with the arm flag, and
# wrong for a 24/7 operator. The single-fire arm flag IS the supervision signal.
#
# Code-council 2026-05-17 (council/code-reviews/2026-05-17-newvibe-gate-a-hooks.md)
# fixes folded in: plain-append log (no silent mv), dispatch logged immediately
# after HTTP 200 (no double-dispatch window), the synchronous 90s poll removed
# (a Stop hook must never block — outcome is verified by the autofired session's
# own logging + the A11 manual check), nv_autofire dedup for both hooks,
# EXIT-trapped lock, single-pass ship-state read, conservative dedup-fail.

set -uo pipefail

# ── Constants ───────────────────────────────────────────────────────────────
# [ORG-SPECIFIC] — the n8n SSH-Execute substrate. Replace all three with your
# own values before arming autofire. See references/newvibe-integration-guide.md §7.
NV_N8N_HOST="{{N8N_HOST}}"                     # e.g. https://n8n.your-org.example
NV_WEBHOOK_PATH="{{N8N_WEBHOOK_PATH}}"         # e.g. /webhook/ssh-execute
NV_WORKFLOW_ID="{{N8N_WORKFLOW_ID}}"           # the SSH-Execute workflow id (heartbeats)
NV_SIGNAL_WINDOW_MIN=20                        # ship-state.json freshness
NV_LOCK_TTL_SEC=120
NV_DESTRUCTIVE_RE='(delete|drop table|destroy|rm -rf|force.push|--no-verify|truncate)'
# Real-dispatch outcomes only. A 'would-dispatch' dry-run did NOTHING, so it must
# not dedup a later real dispatch — including it silently skipped the first armed
# dispatch (CA-1, council 2026-05-18).
NV_DISPATCHED_STATUS_RE='^(autofire-dispatched|autofire-ssh-failed|autofire-status-unknown)$'

# ── nv_resolve_paths: locate the repo + set NV_* path globals ───────────────
# Honours NEWVIBE_ROOT_OVERRIDE (the hooks pass it to skip source-time
# subshells; the self-test uses it for the sandbox). NV_LIB_DIR is computed
# exactly once — it must point at this script's own dir to find its siblings.
nv_resolve_paths() {
  NV_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -n "${NEWVIBE_ROOT_OVERRIDE:-}" ]; then
    NV_PROJECT_ROOT="$NEWVIBE_ROOT_OVERRIDE"
  else
    # lib lives at .claude/skills/autovibe/scripts/ -> root is four up.
    NV_PROJECT_ROOT="$(cd "$NV_LIB_DIR/../../../.." && pwd)"
  fi
  NV_LOG_FILE="$NV_PROJECT_ROOT/.claude/phase47-log.jsonl"
  NV_SHIP_STATE="$NV_PROJECT_ROOT/.claude/ship-state.json"
  NV_AV_STATE="$NV_PROJECT_ROOT/.claude/autovibe-state.json"
  NV_ARM_FLAG="$NV_PROJECT_ROOT/.claude/.newvibe-autofire-armed"
  NV_CONT_DIR="$NV_PROJECT_ROOT/continuations"
  NV_LOCK_DIR="$NV_PROJECT_ROOT/.claude/skills/autovibe/.autofire-lock"
  NV_CHAIN_GUARD="$NV_LIB_DIR/newvibe-chain-guard.sh"
  NV_VERIFIER="$NV_LIB_DIR/verify-continuation.sh"
  NV_HANDOFF_WRITER="$NV_LIB_DIR/post-handoff-writer.sh"
}

# ── nv_heartbeat: visible chat line ─────────────────────────────────────────
nv_heartbeat() { echo "$1"; }

# ── nv_iso_to_epoch: parse YYYY-MM-DDTHH:MM:SSZ -> epoch (0 on failure) ──────
nv_iso_to_epoch() {
  local iso="$1" e=0
  { [ -z "$iso" ] || [ "$iso" = "null" ]; } && { echo 0; return; }
  e=$(date -u -d "$iso" +%s 2>/dev/null) \
    || e=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null) \
    || e=0
  echo "${e:-0}"
}

# ── nv_int: normalise a value to a safe integer (per shell-portability.md) ──
nv_int() { local n; n=$(printf '%s' "${1:-}" | tr -dc '0-9' | head -c 12); echo "${n:-0}"; }

# ── nv_append_log: append one JSONL entry ───────────────────────────────────
# Plain `printf >> file` — a single line-sized write is atomic on local FS, so
# this needs no temp-file+mv (the old mv had a silent-failure path, and the
# old cat-the-whole-file pattern was O(n) per write — code-council 2026-05-17).
# Args: $1 status, $2 trigger, $3 chain_depth, $4 extra-json-object (default {})
nv_append_log() {
  local status="$1" trigger="$2" depth="${3:-0}" extra="${4:-{\}}"
  depth=$(nv_int "$depth")
  local line
  line=$(jq -nc \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg slug "${NV_SLUG:-unknown}" \
    --arg status "$status" \
    --arg trigger "$trigger" \
    --argjson depth "$depth" \
    --argjson extra "$extra" \
    '{ts:$ts, slug:$slug, status:$status, trigger:$trigger, chain_depth:$depth,
      infra:"ssh-execute", routine_id:null} + $extra' 2>/dev/null)
  if [ -z "$line" ]; then
    echo "[newvibe] WARNING: phase47-log entry build failed (status=$status)" >&2
    return 1
  fi
  if ! printf '%s\n' "$line" >> "$NV_LOG_FILE" 2>/dev/null; then
    echo "[newvibe] WARNING: phase47-log append FAILED (status=$status — entry lost)" >&2
    return 1
  fi
  return 0
}

# ── nv_already_dispatched: dispatch-once dedup, conservative-fail ───────────
# Returns 0 (yes, already handled) if the log has a dispatch-class entry for
# this continuation path. A jq/parse failure also returns 0 — conservative:
# better to skip a dispatch than to double-fire (mirrors the chain guard).
nv_already_dispatched() {
  local path="$1"
  [ -f "$NV_LOG_FILE" ] || return 1
  local seen jq_rc
  seen=$(jq -rs --arg p "$path" --arg re "$NV_DISPATCHED_STATUS_RE" '
    [ .[] | select((.canonical_path // "") == $p)
          | select((.status // "") | test($re)) ] | length' \
    "$NV_LOG_FILE" 2>/dev/null)
  jq_rc=$?
  [ "$jq_rc" -eq 0 ] || return 0          # parse failure -> treat as already dispatched
  seen=$(nv_int "$seen")
  [ "$seen" -gt 0 ]
}

# ── nv_detect_slug: repo path -> n8n REPO_MAP slug ──────────────────────────
# Source of truth: your n8n SSH-Execute workflow's REPO_MAP (integration guide §5).
nv_detect_slug() {
  if [ -n "${NEWVIBE_PROJECT_SLUG:-}" ]; then echo "$NEWVIBE_PROJECT_SLUG"; return; fi
  local root="${1:-$NV_PROJECT_ROOT}" user
  user=$(id -un 2>/dev/null || whoami 2>/dev/null || echo "")
  # [ORG-SPECIFIC] REPO_MAP — the arms below are a worked example. Replace them
  # with your own repo-path -> slug mapping; each echoed slug must match a key
  # in your n8n workflow's REPO_MAP, and the self-test's T9 path + fixtures
  # should be updated to match. See references/newvibe-integration-guide.md §5.
  # Simplest bypass: export NEWVIBE_PROJECT_SLUG to skip path detection entirely.
  case "$root" in
    *example-app*)                           echo "example-app" ;;
    *example-client*)                        echo "example-client" ;;
    *)                                       echo "" ;;
  esac
}

# ── nv_kill_switch_disabled: AUTOVIBE_AUTOFIRE env check (A9) ────────────────
nv_kill_switch_disabled() {
  local v; v=$(printf '%s' "${AUTOVIBE_AUTOFIRE:-}" | tr '[:upper:]' '[:lower:]')
  case "$v" in 0|false|no|off|disabled) return 0 ;; *) return 1 ;; esac
}

# ── nv_armed: real dispatch only if the arm flag exists and not DRYRUN ──────
# The arm flag is SINGLE-FIRE — nv_dispatch_live consumes (rm) it after each
# real dispatch, so the operator re-arms deliberately for every real autofire.
nv_armed() {
  case "$(printf '%s' "${NEWVIBE_DRYRUN:-}" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on) return 1 ;;
  esac
  [ -f "$NV_ARM_FLAG" ]
}

# ── nv_find_latest_continuation: newest AUTOVIBE-*-MASTER.md by mtime ───────
nv_find_latest_continuation() {
  [ -d "$NV_CONT_DIR" ] || return 1
  local f
  f=$(ls -t "$NV_CONT_DIR"/AUTOVIBE-*-MASTER.md 2>/dev/null | head -1)
  { [ -n "$f" ] && [ -f "$f" ]; } || return 1
  echo "$f"
}

# ── nv_detect_ship_completion: the Stop-hook completion signal ──────────────
# Echoes the canonical continuation path + returns 0 ONLY when a clean ship
# genuinely completed and has not already been autofired. Any doubt -> rc 1
# (silent). This is the guard that stops the Stop hook firing every turn.
nv_detect_ship_completion() {
  [ -f "$NV_SHIP_STATE" ] || return 1

  # Single jq pass — read all four fields at once (was 4 separate jq spawns).
  local fields exit_code completed_at mode admin_merged
  fields=$(jq -r '[(.exit_code|tostring), (.completed_at // "null"),
                   (.mode // ""), (.admin_merged // false | tostring)] | join("\t")' \
           "$NV_SHIP_STATE" 2>/dev/null)
  [ -n "$fields" ] || return 1
  IFS=$'\t' read -r exit_code completed_at mode admin_merged <<< "$fields"

  [ "$exit_code" = "0" ]        || return 1   # non-zero / null -> not a clean ship
  [ "$mode" != "hotfix" ]       || return 1   # hotfix never autofires (SKILL.md cond 3)
  [ "$admin_merged" != "true" ] || return 1   # admin-merge != clean ship_signal

  { [ "$completed_at" != "null" ] && [ -n "$completed_at" ]; } || return 1
  local completed_epoch now_epoch age_min
  completed_epoch=$(nv_iso_to_epoch "$completed_at")
  [ "$completed_epoch" -gt 0 ] || return 1
  now_epoch=$(date -u +%s)
  age_min=$(( (now_epoch - completed_epoch) / 60 ))           # negative if future-dated
  { [ "$age_min" -ge 0 ] && [ "$age_min" -le "$NV_SIGNAL_WINDOW_MIN" ]; } || return 1

  local cont
  cont=$(nv_find_latest_continuation) || return 1
  local cont_epoch
  cont_epoch=$(stat -f %m "$cont" 2>/dev/null || stat -c %Y "$cont" 2>/dev/null || echo 0)
  cont_epoch=$(nv_int "$cont_epoch")
  [ "$cont_epoch" -ge "$completed_epoch" ] || return 1   # continuation written at/after the ship

  nv_already_dispatched "$cont" && return 1              # dispatch-once dedup

  echo "$cont"
  return 0
}

# ── nv_resolve_intent: best-effort intent string for the destructive scan ───
nv_resolve_intent() {
  local intent=""
  [ -f "$NV_AV_STATE" ] && intent=$(jq -r '.intent // ""' "$NV_AV_STATE" 2>/dev/null)
  [ -z "$intent" ] && intent=$(git -C "$NV_PROJECT_ROOT" log -1 --format=%s 2>/dev/null || echo "")
  echo "$intent"
}

# ── nv_read_goal_id: extract goal_id from a continuation file frontmatter ───
# Looks for the canonical HTML-comment marker: `<!-- goal_id: <slug> -->`
# Echoes the slug if present, empty string otherwise. NEVER fails — the
# autonomous spawn must not depend on goal-ledger presence (advisory only).
#
# Slug grammar mirrors goals.sh _validate_id EXACTLY: [a-z0-9-]+ (lowercase
# + digits + hyphen; NO underscore). Whitespace around the marker is
# whitespace-exact: a single space after the colon and before the closing
# `-->`. The marker is authored by code (master-continuation §5C), so a
# strict regex is acceptable — the emitter and this extractor co-evolve.
nv_read_goal_id() {
  local file="${1:-}"
  [ -f "$file" ] || { echo ""; return 0; }
  local id
  # Per Edge Case Finder Scenario 7 (council 2026-05-19): scope the search to
  # the HTML-comment frontmatter region — the leading block above the first
  # `# ` Markdown heading — so a documentation example like
  # `<!-- goal_id: example -->` written inside body prose is NOT mis-read as a
  # real ledger link. The marker is authored by code (master-continuation §5C)
  # and always sits in the frontmatter, never below the first heading.
  id=$(awk '/^# /{exit} /<!-- goal_id: [a-z0-9-]+ -->/{
            match($0,/<!-- goal_id: [a-z0-9-]+ -->/);
            print substr($0,RSTART,RLENGTH); exit
          }' "$file" 2>/dev/null \
       | sed 's/^<!-- goal_id: //; s/ -->$//')
  echo "${id:-}"
}

# ── nv_goal_status: classify the goal_id against the local ledger ───────────
# Outputs one of: active | achieved | abandoned | paused | missing | corrupt
#                  | no-helper | no-id
# Never fails. Pure read; takes no lock; cannot affect the ledger.
nv_goal_status() {
  local id="${1:-}"
  [ -z "$id" ] && { echo "no-id"; return 0; }
  local helper="$NV_PROJECT_ROOT/.claude/skills/_shared/goals.sh"
  [ -f "$helper" ] || { echo "no-helper"; return 0; }
  local goals_dir="$NV_PROJECT_ROOT/.claude/goals"
  local file="$goals_dir/goal-${id}.md"
  [ -f "$file" ] || { echo "missing"; return 0; }
  # Reader runs goals.sh in a subshell — never inherits our trap, never holds
  # the ledger lock (read is lock-free per spec §4).
  # $(...) is command substitution (NOT a pipe), so $? correctly reflects the
  # helper's exit code — no mktemp dance needed. head -1 caps multi-line
  # output defensively. Local variable named goal_st (not status) to avoid
  # zsh's read-only `status` builtin should this lib ever be sourced into zsh
  # (per shell-portability.md §5 — namespace your locals).
  local goal_st goal_st_rc
  goal_st=$(bash "$helper" read "$id" status 2>/dev/null | head -1)
  goal_st_rc=${PIPESTATUS[0]}
  # Corrupt: cmd_read returns non-zero OR emits empty/CORRUPT.
  if [ "$goal_st_rc" -ne 0 ] || [ -z "$goal_st" ] || [ "$goal_st" = "CORRUPT" ]; then
    echo "corrupt"
    return 0
  fi
  # Normalise to the FROZEN status set; anything else is treated as corrupt.
  case "$goal_st" in
    active|achieved|abandoned|paused) echo "$goal_st" ;;
    *) echo "corrupt" ;;
  esac
}

# ── nv_autofire: the gated dispatch — the single entry both hooks use ───────
# Args: $1 canonical continuation path, $2 trigger (stop|precompact)
nv_autofire() {
  local canonical_path="$1" trigger="${2:-stop}"
  NV_SLUG=$(nv_detect_slug "$NV_PROJECT_ROOT")

  if [ -z "$NV_SLUG" ]; then
    nv_append_log autofire-skipped "$trigger" 0 '{"skip_reason":"slug-undetected"}'
    nv_heartbeat "⏭️ NewVibe autofire skipped — project slug not detected for $NV_PROJECT_ROOT"
    return 0
  fi

  # Dispatch-once dedup — protects BOTH hooks (the PreCompact path does not go
  # through nv_detect_ship_completion). Silent: a stale re-trigger is not news.
  if nv_already_dispatched "$canonical_path"; then
    return 0
  fi

  # Gate 1 — kill-switch (A9, checked in the caller session, never the autofired one)
  if nv_kill_switch_disabled; then
    nv_append_log autofire-skipped "$trigger" 0 '{"skip_reason":"kill-switch"}'
    nv_heartbeat "⏸️ NewVibe autofire SKIPPED — kill-switch active (AUTOVIBE_AUTOFIRE=${AUTOVIBE_AUTOFIRE:-}). To re-enable: unset AUTOVIBE_AUTOFIRE"
    return 0
  fi

  # Gate 2 — runaway cap (D1). Refuse before anything else expensive runs.
  local guard_out guard_rc depth
  guard_out=$(bash "$NV_CHAIN_GUARD" "$NV_SLUG" "$NV_LOG_FILE" 2>/dev/null); guard_rc=$?
  depth=$(nv_int "${guard_out#depth=}")
  if [ "$guard_rc" -ne 0 ]; then
    nv_append_log autofire-skipped "$trigger" "$depth" '{"skip_reason":"chain-depth-exceeded"}'
    nv_heartbeat "🛑 NewVibe autofire REFUSED — runaway cap: chain depth $depth exceeds 5. A self-spawning loop was stopped. Inspect .claude/phase47-log.jsonl"
    return 0
  fi

  # Gate 3 — verifier PASS + sha256 capture (direct-redirect rc, shell-portability.md rule 1).
  # The verifier ALSO scans the continuation body for destructive keywords (exit 6) — so the
  # body is covered here; Gate 7 below is the secondary scan of the intent string.
  local verify_log verify_rc expected_sha
  verify_log=$(mktemp)
  bash "$NV_VERIFIER" "$canonical_path" > "$verify_log" 2>&1
  verify_rc=$?
  if [ "$verify_rc" -ne 0 ]; then
    nv_append_log autofire-skipped "$trigger" "$depth" \
      "$(jq -nc --arg r "verifier-exit-$verify_rc" --arg p "$canonical_path" '{skip_reason:$r, canonical_path:$p}')"
    nv_heartbeat "⏭️ NewVibe autofire skipped — continuation verifier exit $verify_rc ($canonical_path)"
    rm -f "$verify_log"; return 0
  fi
  expected_sha=$(grep -oE 'sha256=[0-9a-f]{64}' "$verify_log" | head -1 | cut -d= -f2)
  rm -f "$verify_log"
  if [ -z "$expected_sha" ]; then
    nv_append_log autofire-skipped "$trigger" "$depth" \
      "$(jq -nc --arg p "$canonical_path" '{skip_reason:"verifier-sha-missing", canonical_path:$p}')"
    nv_heartbeat "⏭️ NewVibe autofire skipped — verifier emitted no sha256"
    return 0
  fi

  # Gate 4 — extract target branch (A8; broadened awk per SKILL.md v3 / Gate B fix)
  local target_branch
  target_branch=$(awk '/^## .*Current[[:space:]]+Branch[[:space:]]*$/{flag=1; next} flag && /^[a-zA-Z0-9_.\/-]+$/{print; exit}' "$canonical_path")
  if [ -z "$target_branch" ]; then
    nv_append_log autofire-skipped "$trigger" "$depth" \
      "$(jq -nc --arg p "$canonical_path" '{skip_reason:"branch-extract-failed", canonical_path:$p}')"
    nv_heartbeat "⏭️ NewVibe autofire skipped — no Current Branch section in $canonical_path"
    return 0
  fi

  # Gate 5 — mkdir lock (A3, 120s TTL). EXIT-trapped so a SIGTERM/SIGKILL mid-dispatch
  # still releases the lock (RETURN would not — code-council 2026-05-17).
  if ! mkdir "$NV_LOCK_DIR" 2>/dev/null; then
    local lock_age
    lock_age=$(( $(date +%s) - $(stat -f %m "$NV_LOCK_DIR" 2>/dev/null || stat -c %Y "$NV_LOCK_DIR" 2>/dev/null || echo 0) ))
    if [ "$lock_age" -lt "$NV_LOCK_TTL_SEC" ]; then
      nv_append_log autofire-skipped "$trigger" "$depth" '{"skip_reason":"concurrent-dispatch-lock-held"}'
      nv_heartbeat "⏭️ NewVibe autofire skipped — another dispatch holds the lock"
      return 0
    fi
    # stale lock — break it, but if the re-mkdir loses a race, skip rather than run unlocked
    if ! { rm -rf "$NV_LOCK_DIR" && mkdir "$NV_LOCK_DIR"; } 2>/dev/null; then
      nv_append_log autofire-skipped "$trigger" "$depth" '{"skip_reason":"stale-lock-break-failed"}'
      nv_heartbeat "⏭️ NewVibe autofire skipped — could not acquire lock after stale break"
      return 0
    fi
  fi
  trap 'rm -rf "$NV_LOCK_DIR"' EXIT INT TERM

  # Gate 6 — sha256 TOCTOU re-check (A2)
  local actual_sha
  actual_sha=$(shasum -a 256 "$canonical_path" 2>/dev/null | awk '{print $1}')
  if [ "$expected_sha" != "$actual_sha" ]; then
    nv_append_log autofire-skipped "$trigger" "$depth" '{"skip_reason":"sha256-drift-since-verify"}'
    nv_heartbeat "⏭️ NewVibe autofire skipped — continuation changed between verify and dispatch"
    return 0
  fi

  # Gate 7 — destructive-intent scan (secondary to the verifier's body scan in Gate 3)
  local intent
  intent=$(nv_resolve_intent)
  if [ -n "$intent" ] && printf '%s' "$intent" | grep -qiE "$NV_DESTRUCTIVE_RE"; then
    nv_append_log autofire-skipped "$trigger" "$depth" '{"skip_reason":"destructive-intent"}'
    nv_heartbeat "⏭️ NewVibe autofire skipped — destructive keyword in intent"
    return 0
  fi

  # Gate 8 — goal-ledger read step (Session 4, Goal-Ledger Build Programme).
  # ADVISORY ONLY. This gate is the autonomous substrate's eyes-on-the-ledger.
  # It NEVER blocks — per Decision Criteria §4 row 1: "absence of ledger ≠
  # failure; log + proceed". The goal record is created at master-continuation
  # §5C time via bare `goals.sh new` (the unguarded legacy path; §5C has not
  # yet been migrated to spawn-check — Session 5+ work). Re-running new OR
  # spawn-check here would risk double-creating against an already-existing
  # id. The hook's job is to: (a) make the autonomous spawn ledger-aware in
  # phase47-log.jsonl, and (b) surface stale / missing / corrupt linkage to
  # the operator via heartbeat-style stderr.
  # NOTE: exit codes 10 (WARN) / 11 (BLOCK) from goals.sh do NOT fire here —
  # those come from spawn-check at goal-creation time, not from this read.
  local goal_id goal_status goal_extra
  goal_id=$(nv_read_goal_id "$canonical_path")
  goal_status=$(nv_goal_status "$goal_id")
  # Pre-build the extra-json with its own rc check, mirroring the dispatch
  # body construction below. If jq fails the substitution returns "", and
  # nv_append_log's "${4:-{\}}" default kicks in only on UNSET (not empty) —
  # so an empty 4th arg would trip --argjson on '' and lose the audit row.
  # Fallback to a sentinel so the row still lands, distinguishable from a
  # real outcome (code-council Session 4, Silent Failure Hunter CRITICAL).
  goal_extra=$(jq -nc --arg gid "${goal_id:-}" --arg s "$goal_status" --arg p "$canonical_path" \
       '{linkage_status:$s, goal_id:$gid, canonical_path:$p}' 2>/dev/null)
  [ -z "$goal_extra" ] && goal_extra='{"linkage_status":"log-build-failed","goal_id":"","canonical_path":""}'
  nv_append_log goal-ledger-read "$trigger" "$depth" "$goal_extra"
  case "$goal_status" in
    active)
      echo "ℹ️ NewVibe: dispatching against active ledger goal $goal_id" >&2 ;;
    achieved|abandoned|paused)
      echo "ℹ️ NewVibe: ledger goal $goal_id is $goal_status — proceeding (next chain's §5C handshake reconciles)" >&2 ;;
    missing)
      echo "⚠️ NewVibe: continuation references goal_id $goal_id but no ledger record on disk — proceeding without linkage" >&2 ;;
    corrupt)
      echo "⚠️ NewVibe: ledger goal $goal_id is unreadable / corrupt — proceeding without linkage" >&2 ;;
    no-helper)
      echo "ℹ️ NewVibe: goals.sh helper not installed in this repo — autonomous spawn without ledger linkage" >&2 ;;
    no-id)
      echo "ℹ️ NewVibe: no goal_id in continuation frontmatter — autonomous spawn without ledger linkage" >&2 ;;
  esac

  # ── Dispatch ──────────────────────────────────────────────────────────────
  if ! nv_armed; then
    # Unarmed (default) or NEWVIBE_DRYRUN — every gate passed, but no real curl.
    nv_append_log would-dispatch "$trigger" "$depth" \
      "$(jq -nc --arg p "$canonical_path" --arg b "$target_branch" --arg s "$expected_sha" \
        '{skip_reason:"not-armed", canonical_path:$p, target_branch:$b, sha256:$s, heartbeat_tier:"DRYRUN"}')"
    nv_heartbeat "🧪 NewVibe autofire DRY-RUN (not armed) — all gates passed, would dispatch:
   slug=$NV_SLUG  branch=$target_branch  depth=$depth
   continuation=$canonical_path
   To arm one real dispatch: touch $NV_ARM_FLAG  (single-fire — consumed on use)"
    return 0
  fi

  nv_dispatch_live "$canonical_path" "$target_branch" "$expected_sha" "$depth" "$trigger"
}

# ── nv_dispatch_live: the real curl (armed path only) ───────────────────────
# Restructured per code-council 2026-05-17: the JSON body is built as a
# separate rc-checked step; the dispatch is logged IMMEDIATELY after HTTP 200
# (so a crash cannot open a double-dispatch window); the old synchronous 90s
# n8n poll is removed (a Stop hook must never block). The single-fire arm flag
# is consumed on a successful dispatch so the next autofire is a fresh decision.
nv_dispatch_live() {
  local canonical_path="$1" target_branch="$2" expected_sha="$3" depth="$4" trigger="$5"

  # Gate L1 — unfilled placeholder pre-check (Edge Case Finder Scenario 1,
  # council 2026-05-19). The template ships {{N8N_HOST}}/{{N8N_WEBHOOK_PATH}}/
  # {{N8N_WORKFLOW_ID}} as placeholders. An armed receiver that fires this path
  # without replacing them would curl a literal `{{N8N_HOST}}{{N8N_WEBHOOK_PATH}}`
  # — fail-loud per-attempt (15s curl timeout) but the failure accumulates as
  # `webhook-dispatch-failed-rc-*` rows the operator must grep to find. Loud
  # AND actionable beats loud BUT silent-in-aggregate: refuse here with a
  # human-readable heartbeat naming the integration guide §7.0.
  if printf '%s%s%s' "$NV_N8N_HOST" "$NV_WEBHOOK_PATH" "$NV_WORKFLOW_ID" \
       | grep -qF '{{'; then
    nv_append_log autofire-skipped "$trigger" "$depth" \
      '{"skip_reason":"unfilled-placeholders","resolution":"replace NV_N8N_HOST + NV_WEBHOOK_PATH + NV_WORKFLOW_ID in newvibe-dispatch-lib.sh per newvibe-integration-guide.md §7.0"}'
    nv_heartbeat "🛑 NewVibe autofire REFUSED — the dispatch constants still carry {{...}} placeholders. Replace NV_N8N_HOST + NV_WEBHOOK_PATH + NV_WORKFLOW_ID in newvibe-dispatch-lib.sh (lines 49-51) per newvibe-integration-guide.md §7.0 before arming."
    return 0
  fi

  local hyper_micro
  hyper_micro=$(cat <<EOF
You are resuming work from a master continuation file authored by NewVibe (autovibe Phase 4.7).

Read this file FIRST: ${canonical_path}

The verifier has already passed (>= 8 sections, >= 500B, no destructive keywords,
slug unique, sha256 matches dispatch-time hash, Current Branch section present).

You are on branch ${target_branch} (already checked out by the dispatcher).

Resume from the "Next steps" / "What's left" section. You have the full local
environment: skills, hooks, MCP servers, project rules, project memory. Use them.

If anything in the file references state that no longer holds (e.g. a PR has since
merged and the file claims it is still open), correct course and proceed.
EOF
)

  # Build the JSON body first, with its own rc check — `curl -d "$(jq ...)"`
  # would mask a jq failure ($? captures curl, not jq).
  local dispatch_body
  dispatch_body=$(jq -n \
    --arg slug "$NV_SLUG" \
    --arg prompt "$hyper_micro" \
    --arg path "$canonical_path" \
    --arg branch "$target_branch" \
    --arg sha "$expected_sha" \
    '{project_slug:$slug, prompt:$prompt, action_type:"autofire_continuation",
      session_id:$path, target_branch:$branch, expected_sha256:$sha}' 2>/dev/null)
  if [ -z "$dispatch_body" ]; then
    nv_append_log autofire-skipped "$trigger" "$depth" '{"skip_reason":"body-serialisation-failed"}'
    nv_heartbeat "🛑 NewVibe autofire — failed to build the dispatch JSON body"
    return 0
  fi

  local dispatch_out dispatch_rc http_code
  dispatch_out=$(curl -sS -m 15 -X POST "${NV_N8N_HOST}${NV_WEBHOOK_PATH}" \
    -H "Content-Type: application/json" \
    -w "\n__HTTP_CODE__:%{http_code}" \
    -d "$dispatch_body")
  dispatch_rc=$?
  http_code=$(printf '%s' "$dispatch_out" | grep -oE '__HTTP_CODE__:[0-9]+' | cut -d: -f2)

  if [ "$dispatch_rc" -ne 0 ]; then
    nv_append_log autofire-skipped "$trigger" "$depth" \
      "$(jq -nc --arg r "webhook-dispatch-failed-rc-$dispatch_rc" '{skip_reason:$r}')"
    nv_heartbeat "🛑 NewVibe autofire — webhook curl failed (rc=$dispatch_rc)"
    return 0
  fi
  if [ "$http_code" != "200" ]; then
    nv_append_log autofire-skipped "$trigger" "$depth" \
      "$(jq -nc --arg r "webhook-http-${http_code}" '{skip_reason:$r}')"
    nv_heartbeat "🛑 NewVibe autofire — webhook returned HTTP ${http_code}"
    return 0
  fi

  # HTTP 200 — record the dispatch IMMEDIATELY. This entry is what the
  # dispatch-once dedup and the runaway cap read; writing it now (not after a
  # poll) closes the crash-window that could re-fire the same continuation.
  # The TARGET machine is decided by the n8n REPO_MAP keyed on slug — the
  # dispatching session cannot know it, so it is not logged (the `slug` field
  # already identifies the dispatching repo). Portable across every adopter.
  nv_append_log autofire-dispatched "$trigger" "$depth" \
    "$(jq -nc --arg p "$canonical_path" --arg b "$target_branch" --arg s "$expected_sha" \
       '{canonical_path:$p, target_branch:$b, sha256:$s, heartbeat_tier:"DISPATCHED"}')"

  # Single-fire: consume the arm flag so the next real autofire needs a fresh,
  # deliberate re-arm (the supervised trust-building primitive — clock-free).
  rm -f "$NV_ARM_FLAG"

  nv_heartbeat "🚀 NewVibe autofire DISPATCHED — slug=$NV_SLUG branch=$target_branch depth=$depth
   continuation=$canonical_path
   A fresh session is launching on the target Mac via SSH-Execute. Verify it did real
   work (A11 check): inspect the resulting commits/PR, or the n8n executions for
   workflow ${NV_WORKFLOW_ID} at ${NV_N8N_HOST}.
   Arm flag consumed (single-fire) — re-arm with: touch $NV_ARM_FLAG"
  return 0
}

# ── Self-test (hermetic) ────────────────────────────────────────────────────
nv_self_test() {
  local tmp pass=0 fail=0
  tmp=$(mktemp -d)
  mkdir -p "$tmp/.claude/skills/autovibe" "$tmp/continuations"

  # Sandbox + forced slug (a temp-dir path matches no REPO_MAP pattern).
  export NEWVIBE_ROOT_OVERRIDE="$tmp"
  export NEWVIBE_PROJECT_SLUG="example-app"

  local NOW_ISO NOW_EPOCH
  NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  NOW_EPOCH=$(date -u +%s)

  _ship_state() {  # exit_code completed_at mode admin_merged
    jq -nc --argjson ec "$1" --arg ca "$2" --arg m "$3" --argjson am "$4" \
      '{pr_number:1, commit_sha:"abc", exit_code:$ec, completed_at:$ca, mode:$m, admin_merged:$am}'
  }
  _make_cont() { printf '# AUTOVIBE master\n\nsection padding %s\n' "$(head -c 600 < /dev/zero | tr '\0' x)" > "$1"; }

  _result() {  # label expected_substring actual
    if printf '%s' "$3" | grep -q "$2"; then echo "  PASS  $1"; pass=$((pass+1))
    else echo "  FAIL  $1 — expected '$2', got: $(printf '%s' "$3" | head -1)"; fail=$((fail+1)); fi
  }

  echo "newvibe-dispatch-lib self-test"
  echo "================================"
  nv_resolve_paths   # re-resolve against the sandbox

  # T1 — no ship-state.json -> no completion signal
  rm -f "$NV_SHIP_STATE"
  nv_detect_ship_completion >/dev/null 2>&1
  _result "T1 absent ship-state -> no signal" "rc1" "$([ $? -ne 0 ] && echo rc1 || echo rc0)"

  # T2 — clean ship + fresh continuation -> signal detected
  _ship_state 0 "$NOW_ISO" "pr" false > "$NV_SHIP_STATE"
  _make_cont "$NV_CONT_DIR/AUTOVIBE-2026-05-17-1200-test-MASTER.md"
  local out rc
  out=$(nv_detect_ship_completion 2>/dev/null); rc=$?
  _result "T2 clean ship + continuation -> signal" "AUTOVIBE-2026-05-17-1200-test-MASTER" "$([ $rc -eq 0 ] && echo "$out" || echo NONE)"

  # T3 — exit_code != 0 -> no signal
  _ship_state 4 "$NOW_ISO" "pr" false > "$NV_SHIP_STATE"
  nv_detect_ship_completion >/dev/null 2>&1
  _result "T3 exit_code 4 -> no signal" "rc1" "$([ $? -ne 0 ] && echo rc1 || echo rc0)"

  # T3b — exit_code literally null -> no signal
  printf '{"pr_number":1,"exit_code":null,"completed_at":"%s","mode":"pr","admin_merged":false}\n' "$NOW_ISO" > "$NV_SHIP_STATE"
  nv_detect_ship_completion >/dev/null 2>&1
  _result "T3b exit_code null -> no signal" "rc1" "$([ $? -ne 0 ] && echo rc1 || echo rc0)"

  # T4 — hotfix mode -> no signal
  _ship_state 0 "$NOW_ISO" "hotfix" false > "$NV_SHIP_STATE"
  nv_detect_ship_completion >/dev/null 2>&1
  _result "T4 hotfix mode -> no signal" "rc1" "$([ $? -ne 0 ] && echo rc1 || echo rc0)"

  # T5 — stale completed_at -> no signal
  local OLD_ISO; OLD_ISO=$(date -u -r $((NOW_EPOCH - 7200)) +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
                            || date -u -d @$((NOW_EPOCH - 7200)) +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
  _ship_state 0 "$OLD_ISO" "pr" false > "$NV_SHIP_STATE"
  nv_detect_ship_completion >/dev/null 2>&1
  _result "T5 stale ship (2h old) -> no signal" "rc1" "$([ $? -ne 0 ] && echo rc1 || echo rc0)"

  # T5b — future-dated completed_at (clock skew) -> no signal
  local FUTURE_ISO; FUTURE_ISO=$(date -u -r $((NOW_EPOCH + 600)) +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
                            || date -u -d @$((NOW_EPOCH + 600)) +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
  _ship_state 0 "$FUTURE_ISO" "pr" false > "$NV_SHIP_STATE"
  nv_detect_ship_completion >/dev/null 2>&1
  _result "T5b future-dated ship (clock skew) -> no signal" "rc1" "$([ $? -ne 0 ] && echo rc1 || echo rc0)"

  # T6 — dedup: already-logged continuation -> no signal. Fixture uses a REAL
  # dispatch status (CA-1: a 'would-dispatch' dry-run no longer dedups).
  _ship_state 0 "$NOW_ISO" "pr" false > "$NV_SHIP_STATE"
  jq -nc --arg p "$NV_CONT_DIR/AUTOVIBE-2026-05-17-1200-test-MASTER.md" \
    '{ts:"x", slug:"example-app", status:"autofire-dispatched", canonical_path:$p}' > "$NV_LOG_FILE"
  nv_detect_ship_completion >/dev/null 2>&1
  _result "T6 already-dispatched continuation -> no signal" "rc1" "$([ $? -ne 0 ] && echo rc1 || echo rc0)"
  rm -f "$NV_LOG_FILE"

  # T7 — kill-switch gate
  out=$(AUTOVIBE_AUTOFIRE=0 nv_autofire "$NV_CONT_DIR/AUTOVIBE-2026-05-17-1200-test-MASTER.md" stop 2>&1)
  _result "T7 kill-switch -> skip" "kill-switch" "$out"
  rm -f "$NV_LOG_FILE"

  # T8 — runaway cap gate (synthetic depth-5 log)
  { for d in 1 2 3 4 5; do
      jq -nc --arg ts "$NOW_ISO" --argjson d "$d" \
        '{ts:$ts, slug:"example-app", status:"autofire-dispatched", chain_depth:$d}'
    done; } > "$NV_LOG_FILE"
  out=$(nv_autofire "$NV_CONT_DIR/AUTOVIBE-2026-05-17-1200-test-MASTER.md" stop 2>&1)
  _result "T8 depth-5 chain -> runaway REFUSE" "runaway cap" "$out"
  rm -f "$NV_LOG_FILE"

  # T9 — slug detection for the agency repo
  _result "T9 slug detection" "example-app" \
    "$(NEWVIBE_PROJECT_SLUG= nv_detect_slug '/home/dev/example-app')"

  # T10 — dedup gate inside nv_autofire (protects the PreCompact path)
  local cpath="$NV_CONT_DIR/AUTOVIBE-2026-05-17-1200-test-MASTER.md"
  jq -nc --arg p "$cpath" \
    '{ts:"x", slug:"example-app", status:"autofire-dispatched", canonical_path:$p, chain_depth:1}' > "$NV_LOG_FILE"
  out=$(nv_autofire "$cpath" precompact 2>&1)
  if [ -z "$(printf '%s' "$out" | tr -d '[:space:]')" ]; then
    echo "  PASS  T10 already-dispatched -> nv_autofire silent no-op"; pass=$((pass+1))
  else
    echo "  FAIL  T10 already-dispatched — expected silent no-op, got: $out"; fail=$((fail+1))
  fi
  rm -f "$NV_LOG_FILE"

  # T11 — would-dispatch happy path: all gates pass, unarmed -> would-dispatch.
  # Uses a stub verifier emitting a PASS line with the continuation's real sha256.
  local vstub="$tmp/.claude/skills/autovibe/stub-verifier.sh"
  printf '#!/bin/bash\nsha=$(shasum -a 256 "$1" | awk "{print \\$1}")\necho "[PASS] stub sha256=$sha"\nexit 0\n' > "$vstub"
  chmod +x "$vstub"
  local cont11="$NV_CONT_DIR/AUTOVIBE-2026-05-17-1300-t11-MASTER.md"
  printf '# T11\n\n## 1. Current Branch\nmain\n\npad %s\n' "$(head -c 600 </dev/zero|tr "\0" x)" > "$cont11"
  out=$(NV_VERIFIER="$vstub" nv_autofire "$cont11" stop 2>&1)
  _result "T11 all gates pass, unarmed -> would-dispatch" "would dispatch" "$out"
  _result "T11  branch extracted = main" "branch=main" "$out"
  rm -f "$NV_LOG_FILE"

  # T12 — arm-flag detection: nv_armed true with the flag, false without.
  rm -f "$NV_ARM_FLAG"
  if nv_armed; then echo "  FAIL  T12 nv_armed true with no flag"; fail=$((fail+1))
  else echo "  PASS  T12 nv_armed false without arm flag"; pass=$((pass+1)); fi
  touch "$NV_ARM_FLAG"
  if nv_armed; then echo "  PASS  T12 nv_armed true with arm flag"; pass=$((pass+1))
  else echo "  FAIL  T12 nv_armed false with arm flag present"; fail=$((fail+1)); fi
  if NEWVIBE_DRYRUN=1 nv_armed; then echo "  FAIL  T12 NEWVIBE_DRYRUN did not override the arm flag"; fail=$((fail+1))
  else echo "  PASS  T12 NEWVIBE_DRYRUN=1 overrides the arm flag"; pass=$((pass+1)); fi
  rm -f "$NV_ARM_FLAG"

  # T13 — Gate 8: nv_read_goal_id extracts the goal_id marker
  local cont_with_id="$NV_CONT_DIR/AUTOVIBE-2026-05-19-with-goal-MASTER.md"
  {
    printf '<!-- goal_id: goal-test-abc123 -->\n# T13\n\n## 1. Current Branch\nmain\n\npad %s\n' \
      "$(head -c 600 </dev/zero|tr "\0" x)"
  } > "$cont_with_id"
  local extracted
  extracted=$(nv_read_goal_id "$cont_with_id")
  _result "T13 nv_read_goal_id extracts valid id" "goal-test-abc123" "$extracted"
  # T13b — no marker -> empty
  extracted=$(nv_read_goal_id "$NV_CONT_DIR/AUTOVIBE-2026-05-17-1300-t11-MASTER.md")
  if [ -z "$extracted" ]; then echo "  PASS  T13b no goal_id marker -> empty"; pass=$((pass+1))
  else echo "  FAIL  T13b expected empty, got '$extracted'"; fail=$((fail+1)); fi
  # T13c — file absent -> empty (must never throw)
  extracted=$(nv_read_goal_id "$tmp/does-not-exist.md")
  if [ -z "$extracted" ]; then echo "  PASS  T13c absent file -> empty"; pass=$((pass+1))
  else echo "  FAIL  T13c expected empty, got '$extracted'"; fail=$((fail+1)); fi

  # T14 — Gate 8: nv_goal_status classifies the four legitimate states
  # T14a — no id -> no-id
  _result "T14a empty id -> no-id" "no-id" "$(nv_goal_status "")"
  # T14b — helper absent -> no-helper (sandbox has no .claude/skills/_shared/goals.sh)
  _result "T14b helper absent -> no-helper" "no-helper" "$(nv_goal_status "goal-test-xyz")"
  # T14c — helper present + record absent -> missing
  mkdir -p "$tmp/.claude/skills/_shared" "$tmp/.claude/goals"
  # Stub helper that mimics the read/status contract: prints status on stdout.
  cat > "$tmp/.claude/skills/_shared/goals.sh" <<'STUB'
#!/bin/bash
# Stub goals.sh for hermetic self-test. Implements just `read <id> status`.
if [ "$1" = "read" ] && [ "$3" = "status" ]; then
  f="$(dirname "$0")/../../goals/goal-$2.md"
  [ -f "$f" ] || exit 1
  grep -m1 -oE '^status:[[:space:]]+[a-z]+' "$f" | awk '{print $2}'
  exit 0
fi
exit 2
STUB
  chmod +x "$tmp/.claude/skills/_shared/goals.sh"
  _result "T14c helper present, no record -> missing" "missing" "$(nv_goal_status "goal-test-missing")"
  # T14d — record with status: active -> active.
  # NOTE: goals.sh _goal_file() ALWAYS prepends "goal-" to the id when computing
  # the on-disk file. So an id of "test-active" maps to goal-test-active.md.
  # nv_goal_status mirrors this convention; we pass the bare id here.
  cat > "$tmp/.claude/goals/goal-test-active.md" <<'REC'
---
goal_id: test-active
status: active
---
REC
  _result "T14d active record -> active" "active" "$(nv_goal_status "test-active")"
  # T14e — record with status: achieved -> achieved
  cat > "$tmp/.claude/goals/goal-test-done.md" <<'REC'
---
goal_id: test-done
status: achieved
---
REC
  _result "T14e achieved record -> achieved" "achieved" "$(nv_goal_status "test-done")"
  # T14f — record present but helper returns nothing -> corrupt
  cat > "$tmp/.claude/goals/goal-test-corrupt.md" <<'REC'
not a valid record
REC
  _result "T14f unreadable record -> corrupt" "corrupt" "$(nv_goal_status "test-corrupt")"
  # T14g — abandoned record -> abandoned (FROZEN schema state set per spec §4)
  cat > "$tmp/.claude/goals/goal-test-aban.md" <<'REC'
---
goal_id: test-aban
status: abandoned
---
REC
  _result "T14g abandoned record -> abandoned" "abandoned" "$(nv_goal_status "test-aban")"
  # T14h — paused record -> paused (FROZEN schema state set per spec §4)
  cat > "$tmp/.claude/goals/goal-test-paused.md" <<'REC'
---
goal_id: test-paused
status: paused
---
REC
  _result "T14h paused record -> paused" "paused" "$(nv_goal_status "test-paused")"

  # T15 — Gate 8 inside nv_autofire: phase47-log gains a goal-ledger-read entry
  # alongside the existing would-dispatch entry. Re-arm the verifier stub from T11.
  local cont15="$NV_CONT_DIR/AUTOVIBE-2026-05-19-1300-t15-MASTER.md"
  {
    printf '<!-- goal_id: test-active -->\n# T15\n\n## 1. Current Branch\nmain\n\npad %s\n' \
      "$(head -c 600 </dev/zero|tr "\0" x)"
  } > "$cont15"
  rm -f "$NV_LOG_FILE"
  out=$(NV_VERIFIER="$vstub" nv_autofire "$cont15" stop 2>&1)
  if [ -f "$NV_LOG_FILE" ] \
     && grep -q '"status":"goal-ledger-read"' "$NV_LOG_FILE" \
     && grep -q '"linkage_status":"active"' "$NV_LOG_FILE"; then
    echo "  PASS  T15 nv_autofire logs goal-ledger-read with active linkage"; pass=$((pass+1))
  else
    echo "  FAIL  T15 expected goal-ledger-read+active in phase47-log; got: $(cat "$NV_LOG_FILE" 2>/dev/null | head -5)"
    fail=$((fail+1))
  fi
  # T15b — Gate 8 NEVER blocks dispatch: would-dispatch must still appear
  if printf '%s' "$out" | grep -q "would dispatch"; then
    echo "  PASS  T15b Gate 8 does not block dispatch (would-dispatch still fires)"; pass=$((pass+1))
  else
    echo "  FAIL  T15b expected would-dispatch despite Gate 8"; fail=$((fail+1))
  fi
  rm -f "$NV_LOG_FILE"

  rm -rf "$tmp"
  unset NEWVIBE_ROOT_OVERRIDE NEWVIBE_PROJECT_SLUG
  local total=$(( pass + fail ))
  echo "================================"
  if [ "$fail" -eq 0 ]; then
    echo "newvibe-dispatch-lib self-test: ALL PASS ($pass/$total)"; return 0
  fi
  echo "newvibe-dispatch-lib self-test: $fail FAILED ($pass/$total)"; return 1
}

# ── Entry point: run self-test if executed directly; else just define ───────
nv_resolve_paths
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "${1:-}" in
    --self-test) nv_self_test; exit $? ;;
    *) echo "newvibe-dispatch-lib.sh is a sourced library. Use --self-test to test it." >&2; exit 2 ;;
  esac
fi
