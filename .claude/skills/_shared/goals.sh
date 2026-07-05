#!/usr/bin/env bash
# _shared/goals.sh — the goal-ledger per-thread read/write helper.
#
# Goal-Ledger Build Programme — Session 2 (Stage 2). Builds to the FROZEN schema in
# specs/12_GOAL_LEDGER_BUILD_PROGRAMME.md §4. Concurrency discipline mirrors
# autovibe/scripts/state.sh (atomic mkdir lock + jq -n -> mktemp -> mv; TTL 30m,
# 60m clock-skew bound) with one deliberate divergence: state.sh treats a held lock
# as a genuine error (one session = one lock), but the ledger's same-id ops during a
# handoff handshake are brief and expected to overlap, so _acquire RETRIES with bounded
# backoff before giving up — a held lock is transient here, not an error.
#
# Per-thread files — one .md per goal thread — so cross-thread ops never contend; the
# per-id lock serialises only same-id read-modify-write (set/achieve/close).
#
# Why jq, not yq/PyYAML: neither is installed on the target machine. This helper is the
# SOLE writer, so it controls the frontmatter format: every value is JSON-encoded (a
# JSON scalar/array/null). YAML 1.2 is a JSON superset, so the block is valid YAML AND
# the reader reconstructs the record with jq alone. The read path does NOT trust the
# file blindly — _validate_schema enforces exactly the 11 frozen keys + the status enum,
# so a hand-edited / partially-written / key-injected file is rejected as corrupt rather
# than silently accepted (code-council Session 2 findings).
#
# Usage:
#   goals.sh new <slug> <intended_end> <owning_artefact> [parent_goal_id] [declared_touches_json]
#                                              -> prints goal_id on stdout (UN-guarded — no collision check)
#   goals.sh read <goal_id> [field]            -> full JSON record, or one field (raw)
#   goals.sh set <goal_id> <field> <value>     -> atomic scalar update (schema-locked)
#   goals.sh set-list <goal_id> <field> <json-array>
#   goals.sh achieve <goal_id>                 -> -> achieved; REFUSES (exit 3) w/o roadmap_ref
#   goals.sh abandon <goal_id>                 -> -> abandoned (idempotent if closed)
#   goals.sh reap <prior_goal_id>              -> reaper entry point: idempotent abandon
#   goals.sh list [status]                     -> "<goal_id>\t<status>" lines; CORRUPT marked
#   --- Session 3 (Stage 3 collision detection + Stage 4 roadmap gate) -----------
#   goals.sh lineage <goal_id>                 -> JSON: self->root chain (cycle-guarded, depth-capped)
#   goals.sh check-collision <intended_end> [declared_touches_json] [parent_goal_id]
#                                              -> ADVISORY (lock-free) verdict: 0 clean | 10 warn | 11 block
#   goals.sh spawn-check <slug> <intended_end> <owning_artefact> [parent_goal_id] [declared_touches_json]
#                                              -> ATOMIC collision-check-THEN-create under the ledger-wide
#                                                 lock; prints goal_id on clean (exit 0); 10 warn / 11 block
#                                                 (NO entry created on 10/11). This is the guarded analogue
#                                                 of `new` — Session 4 wires the spawn path to call this.
#   goals.sh roadmap-gate "<proposed addition>" -> emits the 2-skill goal-triggered roadmap-addition gate
#
# Exit codes: 0 ok | 2 usage/bad-arg/invalid-id | 3 achieve-without-roadmap_ref (hard block)
#             4 not-found | 5 lock held (after retry) | 6 corrupt/jq-missing/write-failed
#             10 collision WARN (declared_touches overlap — defer to continuation-collision-safety.md)
#             11 collision BLOCK (contradictory intended_end — escalate to operator; no entry created)

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
GOALS_DIR="$PROJECT_DIR/.claude/goals"
TTL_MIN=30
FUTURE_TOLERANCE_MIN=60
LOCK_RETRIES=25          # ~5s ceiling (25 * 0.2s) before declaring the lock genuinely stuck
LOCK_SLEEP=0.2

# Schema-locked key set (FROZEN — specs/12 §4). Scalars + the three list fields.
SCALAR_KEYS="goal_id intended_end roadmap_ref parent_goal_id status owning_artefact created_at updated_at"
LIST_KEYS="constraints declared_touches actual_touches"
VALID_STATUS="active achieved abandoned paused"
# The exact 11 keys, as a jq array literal — single source of truth for _validate_schema.
SCHEMA_KEYS_JSON='["goal_id","intended_end","roadmap_ref","parent_goal_id","constraints","declared_touches","actual_touches","status","owning_artefact","created_at","updated_at"]'

ts_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
ts_epoch() { date -u +%s; }

if ! command -v jq >/dev/null 2>&1; then
  echo "goals.sh: jq not found in PATH — required dependency (brew install jq)" >&2
  exit 6
fi

# --- input validation -----------------------------------------------------------
# _validate_id: a goal_id is ALWAYS [a-z0-9-]+ (slug chars + hex suffix + hyphen).
# This is the single gate that closes the path-traversal class — every public
# subcommand calls it before any path is constructed from the id.
_validate_id() {
  case "${1:-}" in
    ''|*[!a-z0-9-]*)
      echo "goals.sh: invalid goal_id '${1:-}' (must be non-empty, [a-z0-9-] only)" >&2
      return 2;;
  esac
  return 0
}
_is_scalar_key() { case " $SCALAR_KEYS " in *" $1 "*) return 0;; esac; return 1; }
_is_list_key()   { case " $LIST_KEYS "   in *" $1 "*) return 0;; esac; return 1; }

_goal_file() { echo "$GOALS_DIR/goal-$1.md"; }
_lock_dir()  { echo "$GOALS_DIR/.lock-$1"; }

# --- per-id mkdir lock ----------------------------------------------------------
# Mirrors state.sh (atomic mkdir, symlink-TOCTOU guard, TTL, fail-closed on unreadable
# epoch) PLUS a bounded retry loop (see header rationale). Caller MUST _release.
_acquire() {
  local id="$1" lock attempt=0
  lock="$(_lock_dir "$id")"
  if [ -L "$lock" ]; then
    echo "goals.sh: $lock is a symlink — refusing (potential TOCTOU)" >&2
    return 6
  fi
  while [ "$attempt" -le "$LOCK_RETRIES" ]; do
    if mkdir "$lock" 2>/dev/null; then
      date -u +%s > "$lock/acquired_epoch" 2>/dev/null || true
      return 0
    fi
    # Held. Inspect age for a ONE-TIME stale takeover (only on the first sighting).
    if [ "$attempt" -eq 0 ]; then
      local acq now age
      acq="$(cat "$lock/acquired_epoch" 2>/dev/null || echo '')"
      now="$(ts_epoch)"
      if ! echo "$acq" | grep -qE '^[0-9]+$'; then
        # Epoch unreadable. FAIL CLOSED — a missing stamp may be a live holder
        # mid-write (its date>file write hasn't landed). Never take over on this.
        echo "goals.sh: lock $lock present, epoch unreadable — treating as fresh, not taking over" >&2
      elif [ "$acq" -gt "$((now + FUTURE_TOLERANCE_MIN * 60))" ]; then
        echo "goals.sh: lock $lock future-dated (clock skew) — refusing; inspect/rm manually" >&2
        return 5
      else
        age=$(( (now - acq) / 60 ))
        if [ "$age" -ge "$TTL_MIN" ]; then
          # Stale. Race-safe reclaim: rmdir (NOT rm -rf) the stale dir, then a single
          # mkdir. If another process reclaimed first our rmdir fails harmlessly and
          # our mkdir fails — we then fall through to the retry loop and re-read.
          rm -f "$lock/acquired_epoch" 2>/dev/null || true
          rmdir "$lock" 2>/dev/null || true
          if mkdir "$lock" 2>/dev/null; then
            date -u +%s > "$lock/acquired_epoch" 2>/dev/null || true
            echo "goals.sh: reclaimed stale lock for $id (age ${age}min)" >&2
            return 0
          fi
        fi
      fi
    fi
    attempt=$((attempt + 1))
    sleep "$LOCK_SLEEP" 2>/dev/null || sleep 1
  done
  echo "goals.sh: lock for goal '$id' still held after ${LOCK_RETRIES} retries — another op is stuck; inspect $lock" >&2
  return 5
}
_release() {
  local lock; lock="$(_lock_dir "$1")"
  # Containment guard (defence-in-depth atop _validate_id): never rm outside GOALS_DIR.
  case "$lock" in
    "$GOALS_DIR"/.lock-*) rm -rf "$lock" 2>/dev/null || true;;
    *) echo "goals.sh: _release: lock path '$lock' outside GOALS_DIR — refusing rm" >&2;;
  esac
}

# --- frontmatter render / parse / validate --------------------------------------
# _render_md <record-json>: full .md = YAML-fenced JSON-encoded frontmatter (frozen key
# order) + human-readable body. ONE jq invocation (perf: was 6).
_render_md() {
  local rec="$1"
  {
    printf -- '---\n'
    jq -rn --argjson r "$rec" --argjson order "$SCHEMA_KEYS_JSON" '
      ( $order[] | "\(.): \($r[.] | @json)" ),
      "---", "",
      "# Goal: \($r.goal_id)", "",
      "- **Intended end**: \($r.intended_end)",
      "- **Status**: \($r.status)",
      "- **Roadmap ref**: \($r.roadmap_ref // "(none)")",
      "- **Owning artefact**: \($r.owning_artefact)",
      "- **Parent goal**: \($r.parent_goal_id // "(root)")"
    '
    printf '\n_Managed by `.claude/skills/_shared/goals.sh` — do not hand-edit the frontmatter._\n'
  }
}

# _validate_schema: stdin = candidate record JSON. Pass (echo it) only if it has
# EXACTLY the 11 frozen keys and a valid status. Closes the multi-line-corruption
# and extra-key-injection findings: "parses as JSON" != "is a valid record".
_validate_schema() {
  jq -e --argjson order "$SCHEMA_KEYS_JSON" '
    if (type=="object")
       and ((keys_unsorted | sort) == ($order | sort))
       and ((.status) as $s | ["active","achieved","abandoned","paused"] | index($s) != null)
    then . else empty end' 2>/dev/null
}

# _parse_md <file>: reconstruct + schema-validate the record. Empty + non-zero on
# missing/corrupt/schema-violating.
_parse_md() {
  local file="$1" raw
  [ -f "$file" ] || return 4
  raw="$(awk 'BEGIN{f=0} /^---$/{f++; next} f==1{print} f>=2{exit}' "$file" \
    | sed 's/^\([a-z_][a-z0-9_]*\): /"\1": /' \
    | paste -sd, -)"
  [ -z "$raw" ] && return 6
  printf '{%s}' "$raw" | _validate_schema || return 6
}

_write_record() {
  # $1 = goal_id, $2 = record JSON. render -> mktemp -> mv (atomic). Lock held by caller.
  local id="$1" rec="$2" file tmp
  file="$(_goal_file "$id")"
  tmp="$(mktemp)" || { echo "goals.sh: mktemp failed" >&2; return 6; }
  if ! _render_md "$rec" > "$tmp" 2>/dev/null || [ ! -s "$tmp" ]; then
    rm -f "$tmp"; echo "goals.sh: render produced no output — write rejected" >&2; return 6
  fi
  if ! mv "$tmp" "$file"; then
    rm -f "$tmp"; echo "goals.sh: mv into '$file' failed — ledger NOT updated" >&2; return 6
  fi
}

_load_record() {
  # $1 = goal_id -> echoes record JSON; rc 4 not-found, 6 corrupt.
  local id="$1" file rc rec
  file="$(_goal_file "$id")"
  [ -f "$file" ] || return 4
  rec="$(_parse_md "$file")"; rc=$?
  [ "$rc" -ne 0 ] && return "$rc"
  [ -z "$rec" ] && return 6
  echo "$rec"
}

# --- subcommands ----------------------------------------------------------------
cmd_new() {
  local slug="${1:-}" intended_end="${2:-}" owning="${3:-}" parent="${4:-}" dtouches="${5:-[]}"
  if [ -z "$slug" ] || [ -z "$intended_end" ] || [ -z "$owning" ]; then
    echo "goals.sh new: need <slug> <intended_end> <owning_artefact> [parent_goal_id] [declared_touches_json]" >&2
    return 2
  fi
  echo "$dtouches" | jq -e 'type=="array"' >/dev/null 2>&1 || {
    echo "goals.sh new: declared_touches (arg 5) must be a JSON array; got '$dtouches'" >&2; return 2; }
  slug="$(printf '%s' "$slug" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-' | sed 's/^-*//;s/-*$//')"
  [ -z "$slug" ] && slug="goal"
  mkdir -p "$GOALS_DIR"

  local constraints='[]'
  if [ -n "$parent" ]; then
    _validate_id "$parent" || return 2
    local prec prc
    prec="$(_load_record "$parent")"; prc=$?
    if [ "$prc" -eq 0 ] && [ -n "$prec" ]; then
      constraints="$(echo "$prec" | jq -c '.constraints // []')"
    else
      echo "goals.sh new: parent_goal_id '$parent' not found/corrupt — recording null parent" >&2
      parent=""
    fi
  fi

  local suffix id file now rec tries=0
  while :; do
    suffix="$(openssl rand -hex 4 2>/dev/null || head -c4 /dev/urandom | xxd -p)"
    id="${slug}-${suffix}"
    if ! _validate_id "$id"; then
      tries=$((tries+1)); [ "$tries" -ge 5 ] && { echo "goals.sh new: could not generate a valid goal_id" >&2; return 6; }
      continue
    fi
    _acquire "$id" || return $?
    file="$(_goal_file "$id")"
    # Existence check INSIDE the lock (closes the check-then-create TOCTOU).
    if [ -e "$file" ]; then
      _release "$id"
      tries=$((tries+1)); [ "$tries" -ge 5 ] && { echo "goals.sh new: could not find a free goal_id" >&2; return 6; }
      continue
    fi
    break
  done

  now="$(ts_now)"
  rec="$(jq -n \
    --arg id "$id" --arg ie "$intended_end" --arg own "$owning" \
    --arg par "$parent" --arg now "$now" \
    --argjson cons "$constraints" --argjson dt "$dtouches" \
    '{goal_id:$id, intended_end:$ie, roadmap_ref:null,
      parent_goal_id:(if $par=="" then null else $par end),
      constraints:$cons, declared_touches:$dt, actual_touches:[],
      status:"active", owning_artefact:$own, created_at:$now, updated_at:$now}')"
  if ! _write_record "$id" "$rec"; then _release "$id"; return 6; fi
  _release "$id"
  echo "$id"
}

cmd_read() {
  local id="${1:-}" field="${2:-}" rec rc
  _validate_id "$id" || return $?
  rec="$(_load_record "$id")"; rc=$?
  if [ "$rc" -ne 0 ]; then echo "goals.sh read: goal '$id' not found ($rc)" >&2; return "$rc"; fi
  if [ -z "$field" ]; then echo "$rec" | jq .; else echo "$rec" | jq -r --arg f "$field" '.[$f]'; fi
}

cmd_set() {
  local id="${1:-}" field="${2:-}" value="${3:-}"
  _validate_id "$id" || return $?
  [ -z "$field" ] && { echo "goals.sh set: need <goal_id> <field> <value>" >&2; return 2; }
  _is_scalar_key "$field" || { echo "goals.sh set: '$field' is not a settable scalar field" >&2; return 2; }
  if [ "$field" = "goal_id" ] || [ "$field" = "created_at" ]; then
    echo "goals.sh set: '$field' is immutable" >&2; return 2
  fi
  if [ "$field" = "status" ]; then
    case " $VALID_STATUS " in *" $value "*) :;; *) echo "goals.sh set: invalid status '$value'" >&2; return 2;; esac
    # The roadmap_ref hard-block (spec §4 / council Q5) must NOT be bypassable via `set`.
    if [ "$value" = "achieved" ]; then
      echo "goals.sh set: refusing to set status=achieved via 'set' — use 'goals.sh achieve'" >&2
      echo "  (the 'achieve' path enforces the roadmap_ref hard-block; 'set' must not bypass it)" >&2
      return 3
    fi
  fi
  _acquire "$id" || return $?
  local rec rc out
  rec="$(_load_record "$id")"; rc=$?
  if [ "$rc" -ne 0 ]; then _release "$id"; echo "goals.sh set: '$id' not found/corrupt ($rc)" >&2; return "$rc"; fi
  out="$(echo "$rec" | jq -c --arg f "$field" --arg v "$value" --arg now "$(ts_now)" '.[$f]=$v | .updated_at=$now')"
  if ! _write_record "$id" "$out"; then _release "$id"; return 6; fi
  _release "$id"
}

cmd_set_list() {
  local id="${1:-}" field="${2:-}" json="${3:-}"
  _validate_id "$id" || return $?
  [ -z "$field" ] && { echo "goals.sh set-list: need <goal_id> <field> <json-array>" >&2; return 2; }
  _is_list_key "$field" || { echo "goals.sh set-list: '$field' is not a list field" >&2; return 2; }
  echo "$json" | jq -e 'type=="array"' >/dev/null 2>&1 || { echo "goals.sh set-list: value must be a JSON array" >&2; return 2; }
  _acquire "$id" || return $?
  local rec rc out
  rec="$(_load_record "$id")"; rc=$?
  if [ "$rc" -ne 0 ]; then _release "$id"; echo "goals.sh set-list: '$id' not found/corrupt ($rc)" >&2; return "$rc"; fi
  out="$(echo "$rec" | jq -c --arg f "$field" --argjson v "$json" --arg now "$(ts_now)" '.[$f]=$v | .updated_at=$now')"
  if ! _write_record "$id" "$out"; then _release "$id"; return 6; fi
  _release "$id"
}

cmd_achieve() {
  local id="${1:-}"
  _validate_id "$id" || return $?
  _acquire "$id" || return $?
  local rec rc cur rref
  rec="$(_load_record "$id")"; rc=$?
  if [ "$rc" -ne 0 ]; then _release "$id"; echo "goals.sh achieve: '$id' not found/corrupt ($rc)" >&2; return "$rc"; fi
  cur="$(echo "$rec" | jq -r '.status')"
  if [ "$cur" = "achieved" ] || [ "$cur" = "abandoned" ]; then
    _release "$id"; echo "goals.sh achieve: '$id' already $cur (no-op)" >&2; return 0
  fi
  rref="$(echo "$rec" | jq -r '.roadmap_ref // ""')"
  if [ -z "$rref" ] || [ "$rref" = "null" ]; then
    _release "$id"
    echo "goals.sh achieve: REFUSED — goal '$id' has no roadmap_ref. A goal may not reach" >&2
    echo "  status:achieved without a stable ROADMAP milestone ID (spec §4 / council Q5)." >&2
    echo "  Set one first:  goals.sh set $id roadmap_ref <milestone-id>" >&2
    return 3
  fi
  # actual_touches from git. Distinguish "no changes" from "git unavailable" so the
  # audit field is not silently conflated (Session 3's reconciliation reads it).
  local touches='[]' base
  if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    base="$(git -C "$PROJECT_DIR" merge-base HEAD origin/main 2>/dev/null \
          || git -C "$PROJECT_DIR" merge-base HEAD main 2>/dev/null || echo "")"
    if [ -n "$base" ]; then
      touches="$(git -C "$PROJECT_DIR" diff --name-only "$base"...HEAD 2>/dev/null | jq -Rsc 'split("\n")|map(select(length>0))')"
    fi
    if [ "$touches" = "[]" ]; then
      touches="$(git -C "$PROJECT_DIR" diff --name-only 2>/dev/null | jq -Rsc 'split("\n")|map(select(length>0))')"
    fi
  else
    echo "goals.sh achieve: not inside a git work tree — actual_touches recorded as [] (git-unavailable)" >&2
  fi
  [ -z "$touches" ] && touches='[]'
  local out
  out="$(echo "$rec" | jq -c --argjson t "$touches" --arg now "$(ts_now)" \
        '.status="achieved" | .actual_touches=$t | .updated_at=$now')"
  if ! _write_record "$id" "$out"; then _release "$id"; return 6; fi
  _release "$id"
  echo "goals.sh: goal '$id' -> achieved (${rref})" >&2
}

cmd_close() {
  # abandon + reap share this. Idempotent terminal transition. A present-but-CORRUPT
  # entry is NOT silently left active: it is salvaged to status:abandoned (with the
  # unparseable original moved aside) so the reaper's core guarantee — no dead thread
  # keeps an active goal — holds even on corruption.
  local id="${1:-}" target="$2"
  [ -z "$id" ] && { echo "goals.sh: empty goal_id — nothing to $target (no-op)" >&2; return 0; }
  _validate_id "$id" || return $?
  local file; file="$(_goal_file "$id")"
  [ -f "$file" ] || { echo "goals.sh: no ledger entry '$id' to $target (no-op)" >&2; return 0; }
  _acquire "$id" || return $?
  local rec rc cur out
  rec="$(_load_record "$id")"; rc=$?
  if [ "$rc" -eq 4 ]; then _release "$id"; echo "goals.sh: '$id' vanished — nothing to $target (no-op)" >&2; return 0; fi
  if [ "$rc" -ne 0 ]; then
    # Corrupt-but-present: salvage rather than leak a phantom active entry.
    local aside; aside="${file%.md}.corrupt-$(date -u +%Y%m%dT%H%M%SZ).md"
    mv "$file" "$aside" 2>/dev/null || true
    out="$(jq -n --arg id "$id" --arg s "$target" --arg now "$(ts_now)" --arg src "$aside" \
      '{goal_id:$id, intended_end:"(unrecoverable — original frontmatter corrupt)",
        roadmap_ref:null, parent_goal_id:null, constraints:[], declared_touches:[],
        actual_touches:[], status:$s, owning_artefact:$src, created_at:$now, updated_at:$now}')"
    if ! _write_record "$id" "$out"; then _release "$id"; echo "goals.sh: SALVAGE WRITE FAILED for '$id' — phantom may persist; inspect $aside" >&2; return 6; fi
    _release "$id"
    echo "goals.sh: '$id' was corrupt — salvaged to $target; original moved to $aside" >&2
    return 0
  fi
  cur="$(echo "$rec" | jq -r '.status')"
  case "$cur" in
    achieved|abandoned) _release "$id"; echo "goals.sh: '$id' already $cur (no-op)" >&2; return 0;;
  esac
  out="$(echo "$rec" | jq -c --arg s "$target" --arg now "$(ts_now)" '.status=$s | .updated_at=$now')"
  if ! _write_record "$id" "$out"; then _release "$id"; return 6; fi
  _release "$id"
  echo "goals.sh: goal '$id' -> $target" >&2
}

cmd_list() {
  local filter="${1:-}"
  [ -d "$GOALS_DIR" ] || return 0
  local f result id st
  for f in "$GOALS_DIR"/goal-*.md; do
    [ -e "$f" ] || continue
    # Skip salvage-aside files (cmd_close moves corrupt originals to
    # goal-<id>.corrupt-<ts>.md, which still matches the glob) — otherwise every
    # salvaged entry would emit a permanent un-clearable CORRUPT row.
    case "$f" in *.corrupt-*.md) continue;; esac
    # One awk process per file (perf), then schema-validate the reconstructed record.
    result="$(awk 'BEGIN{f=0} /^---$/{f++; next} f==1{print} f>=2{exit}' "$f" \
      | sed 's/^\([a-z_][a-z0-9_]*\): /"\1": /' | paste -sd, -)"
    if [ -z "$result" ]; then echo "$(basename "$f")	CORRUPT"; continue; fi
    rec="$(printf '{%s}' "$result" | _validate_schema)" || { echo "$(basename "$f")	CORRUPT"; continue; }
    id="$(echo "$rec" | jq -r '.goal_id')"
    st="$(echo "$rec" | jq -r '.status')"
    if [ -z "$filter" ] || [ "$filter" = "$st" ]; then printf '%s\t%s\n' "$id" "$st"; fi
  done
}

# ================================================================================
# Session 3 — Stage 3 (collision detection) + Stage 4 (roadmap-addition gate)
# Composes (does NOT rebuild): the file-collision pause-gate lives in
# .claude/rules/continuation-collision-safety.md (its 4-signal + 3-query resume
# gate). On a declared_touches overlap this code EMITS that rule's pause banner
# and DEFERS — it never reimplements the 3-query gate. The roadmap-addition gate
# composes /reduce-to-first-principles + /map-feedback-loops; this code only
# EMITS the ready-to-run invocation block — it never reimplements the skills.
# ================================================================================

# --- ledger-wide global lock ----------------------------------------------------
# The per-id lock (state.sh pattern) serialises same-id read-modify-write but
# CANNOT serialise "enumerate all active goals -> decide -> create a new one":
# the new id does not exist yet, so there is no per-id lock to take. spawn-check
# needs the whole check-then-write window atomic against another concurrent
# spawn (spec §4 / §5 — "an mkdir-lock around the collision-check-then-ledger-
# write"). LEDGER_LOCK_ID contains a '.', so _validate_id ([a-z0-9-] only) can
# never produce it and no real goal can ever own .lock-.ledger — it is a
# reserved pseudo-id, safe to pass to the existing _acquire/_release verbatim
# (compose, don't rebuild). Lock order is always global-then-per-id (cmd_new,
# called by spawn-check under the global lock, takes only its per-id lock and
# never the global one) so the nesting cannot deadlock.
#
# ATOMICITY SCOPE (code-council Session 3, IMPORTANT): the ledger lock serialises
# spawn-check vs spawn-check ONLY. Bare `new` does NOT take the ledger lock — it
# is the unguarded legacy path (Session 2; still called by master-continuation
# §5C). The collision-check-then-create window is atomic against another
# spawn-check, NOT against a concurrent bare `new`. Session 4 routes the newvibe
# spawn path through spawn-check so the unguarded `new` is off the autonomous
# path; until then `new` is the deliberate escape hatch, not a covered case.
LEDGER_LOCK_ID=".ledger"
_acquire_ledger() { _acquire "$LEDGER_LOCK_ID"; }
_release_ledger() { _release "$LEDGER_LOCK_ID"; }

# --- lineage walk (cyclic parent_goal_id guard — spec §5) -----------------------
# Echoes goal_ids from $1 up to the root, one per line. Visited-set guards a
# cyclic parent_goal_id (A->B->A); a depth cap is belt-and-braces in case the
# visited-set logic itself ever regresses. Tolerant: a missing/corrupt ancestor
# stops the walk and warns on stderr rather than failing — a partial lineage is
# strictly better than none for the alignment use-case.
_walk_lineage() {
  local cur="$1" depth=0 seen=" " rec
  while [ -n "$cur" ] && [ "$cur" != "null" ]; do
    case "$seen" in
      *" $cur "*)
        echo "goals.sh: cyclic parent_goal_id at '$cur' — lineage truncated" >&2
        return 0;;
    esac
    depth=$((depth + 1))
    if [ "$depth" -gt 100 ]; then
      echo "goals.sh: lineage depth >100 at '$cur' — truncated (possible cycle the visited-set missed)" >&2
      return 0
    fi
    echo "$cur"
    seen="$seen$cur "
    rec="$(_load_record "$cur" 2>/dev/null)" || {
      echo "goals.sh: lineage stop — '$cur' not found/corrupt" >&2; return 0; }
    cur="$(echo "$rec" | jq -r '.parent_goal_id // ""')"
    [ "$cur" = "null" ] && cur=""
  done
  return 0
}

# JSON array of the proposed goal's ancestor ids (parent + up). These are
# EXCLUDED from the contradiction/overlap scan: a child goal naturally extends
# and touches the same files as its own parent chain — that is continuation,
# not a parallel collision. Only NON-lineage active goals are real conflicts.
_ancestor_ids() { _walk_lineage "$1" | jq -Rsc 'split("\n")|map(select(length>0))'; }

cmd_lineage() {
  local id="${1:-}" out='[]' g rec
  _validate_id "$id" || return $?
  _load_record "$id" >/dev/null 2>&1 || { echo "goals.sh lineage: '$id' not found/corrupt" >&2; return 4; }
  while read -r g; do
    [ -z "$g" ] && continue
    rec="$(_load_record "$g" 2>/dev/null)" || continue
    out="$(echo "$out" | jq -c --argjson r "$rec" \
      '. + [{goal_id:$r.goal_id, intended_end:$r.intended_end, status:$r.status, parent_goal_id:$r.parent_goal_id}]')"
  done < <(_walk_lineage "$id")
  echo "$out" | jq .
}

# --- semantic contradiction (the lightweight SECOND layer) ----------------------
# Spec §4: declared_touches overlap is the deterministic PRIMARY gate; this
# meaning-comparison is the lightweight second layer. Deliberately conservative:
# fires only when the two intended_ends carry OPPOSING polarity verbs AND share
# a salient token. Known limitation (honest): it MISSES contradictions phrased
# without these verb classes (false-negatives accepted — the operator + the
# touches gate are primary); it is tuned to almost never false-POSITIVE because
# a false BLOCK is the expensive error. Not an NLP model — a transparent rule.
_salient_tokens() {
  printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9_/.-' '\n' \
    | awk 'length>=4 && $0 !~ /^(this|that|with|from|into|when|then|than|will|must|have|been|does|done|onto|over|under|after|before|while|where|which|their|there|these|those|goal|file|files|code|test|tests|step|stage|session|should|would|could|about|each|every|some|same|such|only|also|than|then)$/'
}
_ie_contradicts() {
  local a b ra aa rb ab shared
  a="$(printf '%s' "$1" | tr 'A-Z' 'a-z')"
  b="$(printf '%s' "$2" | tr 'A-Z' 'a-z')"
  local RM='(remove|removes|removing|delete|deletes|drop|drops|disable|disables|deactivate|revert|reverts|undo|undoes|deprecate|deprecates|kill|strip|strips|rollback|roll back|tear down|teardown)'
  local AD='(add|adds|adding|extend|extends|enable|enables|activate|keep|keeps|restore|restores|introduce|introduces|expand|expands|preserve|preserves|retain|retains|reinstate|re-enable)'
  echo "$a" | grep -qE "$RM" && ra=1 || ra=0
  echo "$a" | grep -qE "$AD" && aa=1 || aa=0
  echo "$b" | grep -qE "$RM" && rb=1 || rb=0
  echo "$b" | grep -qE "$AD" && ab=1 || ab=0
  if { [ "$ra" = 1 ] && [ "$ab" = 1 ]; } || { [ "$aa" = 1 ] && [ "$rb" = 1 ]; }; then
    shared="$(comm -12 <(_salient_tokens "$1" | sort -u) <(_salient_tokens "$2" | sort -u) | head -1)"
    [ -n "$shared" ] && return 0
  fi
  return 1
}

# --- the scan -------------------------------------------------------------------
# $1 proposed_intended_end  $2 proposed_declared_touches(JSON)  $3 exclude_ids(JSON)
# Emits, one finding per line: "BLOCK<TAB>goal_id<TAB>their_intended_end"
#                           or "WARN<TAB>goal_id<TAB>overlap_json"
# Order matches spec §4: declared_touches overlap is the DETERMINISTIC PRIMARY
# gate — it is computed FIRST and ALWAYS (no short-circuit). The semantic
# contradiction check is the LIGHTWEIGHT SECOND layer, run after. A peer may
# emit BOTH a WARN and a BLOCK line; _emit_collision_verdict ranks BLOCK over
# WARN at verdict time (it greps '^BLOCK' first), so contradiction still
# outranks file-overlap for the final verdict without the deterministic gate
# being skipped (code-council Session 3, spec-validator IMPORTANT).
# CORRUPTION IS FAIL-CLOSED: an unreadable/corrupt active peer (or a cmd_list
# CORRUPT row) cannot be ruled out as a contradictor, so it emits a loud BLOCK
# rather than being silently dropped — mirrors cmd_close's "never treat a
# corrupt-but-present active entry as absent" doctrine (code-council Session 3,
# CRITICAL: a corrupt sole-contradictor must not return a false CLEAN).
_collision_scan() {
  local pie="$1" pdt="$2" excl="$3" gid st rec tie tdt ov n
  while IFS="$(printf '\t')" read -r gid st; do
    [ -z "$gid" ] && continue
    if echo "$excl" | jq -e --arg g "$gid" 'index($g) != null' >/dev/null 2>&1; then continue; fi
    rec="$(_load_record "$gid" 2>/dev/null)" || {
      # Unexaminable active peer — fail closed (cannot rule out a contradiction).
      printf 'BLOCK\t%s\t%s\n' "$gid" "(unreadable/corrupt active goal — cannot rule out a contradiction; inspect manually)"
      continue
    }
    # Sanitise the displayed intended_end: a stored TAB/newline would otherwise
    # truncate the operator-facing escalation banner via the \t-delimited
    # protocol + awk -F'\t' (code-council Session 3, IMPORTANT — banner fidelity).
    tie="$(echo "$rec" | jq -r '.intended_end' | tr '\t\n' '  ')"
    tdt="$(echo "$rec" | jq -c '.declared_touches // []')"
    # PRIMARY (deterministic) — always computed, never short-circuited.
    ov="$(jq -nc --argjson a "$pdt" --argjson b "$tdt" '$a - ($a - $b) | unique' 2>/dev/null || echo '[]')"
    n="$(echo "$ov" | jq 'length' 2>/dev/null || echo 0)"; n="${n:-0}"
    case "$n" in ''|*[!0-9]*) n=0;; esac
    [ "$n" -gt 0 ] && printf 'WARN\t%s\t%s\n' "$gid" "$ov"
    # SECOND layer (heuristic) — emitted as BLOCK; outranks WARN at verdict time.
    _ie_contradicts "$pie" "$tie" && printf 'BLOCK\t%s\t%s\n' "$gid" "$tie"
  done < <(cmd_list active)
}

# Emits the verdict to stdout; returns 0 clean | 10 warn | 11 block.
_emit_collision_verdict() {
  local scan="$1"
  if [ -z "$scan" ]; then
    echo "goals.sh: collision check CLEAN — no conflicting active goal" >&2
    return 0
  fi
  if echo "$scan" | grep -q '^BLOCK'; then
    echo "════ GOAL COLLISION — BLOCK + ESCALATE TO OPERATOR ════"
    echo "The proposed goal's intended_end CONTRADICTS an active goal. Spawn is blocked."
    echo "$scan" | awk -F'\t' '$1=="BLOCK"{printf "  ✗ contradicts active goal: %s\n    its intended_end: %s\n",$2,$3}'
    echo ""
    echo "Reconcile or abandon one goal before this chain spawns. Do NOT auto-resolve —"
    echo "a contradictory-aim collision is exactly the case the council reserved for the operator."
    echo "If this BLOCK is unexpected: check STDERR above for a 'cyclic/truncated"
    echo "parent_goal_id' or 'lineage stop' warning — a corrupt/cyclic ancestor can"
    echo "truncate the lineage-exclusion set and surface a BLOCK against your own"
    echo "chain (a lineage artefact, not a real parallel conflict)."
    return 11
  fi
  echo "════ FILE-LEVEL COLLISION — PAUSE (defer to continuation-collision-safety.md) ════"
  echo "$scan" | awk -F'\t' '$1=="WARN"{printf "  ⚠ declared_touches overlap with active goal %s: %s\n",$2,$3}'
  cat <<'BANNER'

> Write this pause banner into the spawned continuation, ABOVE any STOP header
> (full procedure: .claude/rules/continuation-collision-safety.md — do not skip its 3-query gate):
>
> ## ⛔ PAUSED — WAIT FOR THE OVERLAPPING ACTIVE GOAL(S) TO CLOSE
> Running in parallel on the same files = guaranteed merge conflict.
> First run:  git fetch origin main
> Resume gate — ALL 3 numbered checks must pass (per .claude/rules/continuation-collision-safety.md):
>   1. git log origin/main --oneline | grep -iE "<overlapping goal's milestone signal>"   # expect ≥1
>   2. git ls-remote origin | grep -iE "<overlapping branch pattern>"                       # expect nothing
>   3. gh pr list --state merged --search "<overlapping goal pattern>" --limit 10           # expect merged
> Do NOT proceed until all 3 pass; then re-read the target files (they may have changed).
BANNER
  return 10
}

# Lock-free ADVISORY verdict (no write). The authoritative atomic path is
# spawn-check; this is for a dry pre-check that tolerates a slightly racy
# snapshot (documented as advisory — never the gate that guards a write).
cmd_check_collision() {
  local pie="${1:-}" pdt="${2:-[]}" parent="${3:-}" excl='[]' scan
  [ -z "$pie" ] && { echo "goals.sh check-collision: need <intended_end> [declared_touches_json] [parent_goal_id]" >&2; return 2; }
  [ -z "$pdt" ] && pdt='[]'
  echo "$pdt" | jq -e 'type=="array"' >/dev/null 2>&1 || { echo "goals.sh check-collision: declared_touches must be a JSON array" >&2; return 2; }
  if [ -n "$parent" ]; then _validate_id "$parent" || return 2; excl="$(_ancestor_ids "$parent")"; fi
  # Fail closed if the ledger dir can't be enumerated — "no active goals" and
  # "could not read the ledger" must NOT both collapse to CLEAN (code-council
  # Session 3, IMPORTANT). An absent dir = genuinely zero goals = legitimately
  # clean; a present-but-unreadable dir = enumeration failure = fail closed.
  if [ -e "$GOALS_DIR" ] && { [ ! -d "$GOALS_DIR" ] || [ ! -r "$GOALS_DIR" ]; }; then
    echo "goals.sh check-collision: $GOALS_DIR present but not a readable dir — failing closed (no clean verdict)" >&2
    return 6
  fi
  scan="$(_collision_scan "$pie" "$pdt" "$excl")"
  _emit_collision_verdict "$scan"
}

# ATOMIC collision-check-THEN-create under the ledger-wide lock (spec §4/§5).
# Clean -> creates via cmd_new (its own per-id lock; no deadlock — see
# LEDGER_LOCK_ID note) and prints the new goal_id. WARN(10)/BLOCK(11) -> NO
# entry created, verdict on stdout. This is the guarded analogue of `new`;
# Session 4 wires the newvibe spawn path to call THIS instead of bare `new`.
cmd_spawn_check() {
  local slug="${1:-}" pie="${2:-}" own="${3:-}" parent="${4:-}" pdt="${5:-[]}"
  if [ -z "$slug" ] || [ -z "$pie" ] || [ -z "$own" ]; then
    echo "goals.sh spawn-check: need <slug> <intended_end> <owning_artefact> [parent_goal_id] [declared_touches_json]" >&2
    return 2
  fi
  [ -z "$pdt" ] && pdt='[]'
  echo "$pdt" | jq -e 'type=="array"' >/dev/null 2>&1 || { echo "goals.sh spawn-check: declared_touches must be a JSON array" >&2; return 2; }
  [ -n "$parent" ] && { _validate_id "$parent" || return 2; }
  mkdir -p "$GOALS_DIR"
  # Fail closed: after mkdir -p, the dir must be a readable directory. If it is
  # not (perms, a file in the way, a races unlink), do NOT proceed — an empty
  # scan would otherwise yield a false CLEAN and create the entry (code-council
  # Session 3, IMPORTANT — enumeration-failure must not equal clean).
  if [ ! -d "$GOALS_DIR" ] || [ ! -r "$GOALS_DIR" ]; then
    echo "goals.sh spawn-check: $GOALS_DIR not a readable dir after mkdir -p — failing closed (no entry created)" >&2
    return 6
  fi
  _acquire_ledger || return $?
  local excl='[]' scan vrc nid crc
  [ -n "$parent" ] && excl="$(_ancestor_ids "$parent")"
  scan="$(_collision_scan "$pie" "$pdt" "$excl")"
  _emit_collision_verdict "$scan"; vrc=$?
  if [ "$vrc" -ne 0 ]; then _release_ledger; return "$vrc"; fi
  nid="$(cmd_new "$slug" "$pie" "$own" "$parent" "$pdt")"; crc=$?
  _release_ledger
  if [ "$crc" -ne 0 ] || [ -z "$nid" ]; then
    echo "goals.sh spawn-check: collision CLEAN but 'new' failed (rc=$crc) — no entry created" >&2
    return 6
  fi
  echo "$nid"
}

# --- Stage 4: the goal-triggered roadmap-addition gate (emitter only) -----------
# Builds NOTHING new — composes /reduce-to-first-principles + /map-feedback-loops
# (full procedure: .claude/skills/_shared/roadmap-addition-gate.md). Shell cannot
# invoke skills, so this prints the ready-to-run, parameter-filled gate block for
# the session to execute. Operator-authored ROADMAP edits are EXEMPT (see doc).
cmd_roadmap_gate() {
  local add="${1:-}"
  [ -z "$add" ] && { echo "goals.sh roadmap-gate: need \"<proposed-roadmap-addition>\"" >&2; return 2; }
  # Heredoc delimiters are QUOTED (<<'EOF') so the body is NOT subjected to
  # parameter/command expansion; the user-controlled $add is emitted via
  # `printf '%s'` between segments. Defence-in-depth: an unquoted heredoc here
  # would not actually execute $(...) inside $add (bash does not re-scan an
  # expanded parameter's value), but quoting removes the question entirely and
  # matches the existing <<'BANNER' precedent (code-council Session 3).
  cat <<'EOF'
GOAL-TRIGGERED ROADMAP-ADDITION GATE — run BOTH steps, in order.
Full procedure + rationale: .claude/skills/_shared/roadmap-addition-gate.md
EXEMPT: an operator hand-editing ROADMAP.md. This gate fires ONLY when a goal
automatically proposes a roadmap addition.

STEP 1 — first-principles reduction (must clear before Step 2):
  /reduce-to-first-principles
    subject:        "Should we add the following to the roadmap? —
EOF
  printf '                     %s"\n' "$add"
  cat <<'EOF'
    input_type:     proposal
    default_action: "write the addition straight into ROADMAP.md without a reduction"
  PROCEED iff framing_verdict ∈ {SOUND, ADDS_CONSTRAINTS}.
  SMUGGLES_CONCLUSIONS -> REJECT; surface the smuggled conclusion; do NOT touch ROADMAP.md.

STEP 2 — second-order projection (only if Step 1 cleared):
  /map-feedback-loops
    input_mode:           decision
EOF
  printf '    decision:             "add %s to ROADMAP NOW and commit resources to it"\n' "$add"
  cat <<'EOF'
    target_system:        "<your project> — in: ROADMAP milestones, the goal-ledger, propagation pipeline; out: any downstream consumers"
    system_current_state: "<≥2 current stocks — e.g. N active ROADMAP milestones; M in-flight programmes>"
    projection_horizon:   "3 months"
  PROCEED iff NO blocking second-order conflict / double-count / archetype trap is projected.

WRITE the addition into ROADMAP.md IFF BOTH steps cleared. Otherwise do NOT add it; record why.
EOF
}

action="${1:-}"; shift 2>/dev/null || true
case "$action" in
  new)            cmd_new "${1:-}" "${2:-}" "${3:-}" "${4:-}" "${5:-}";;
  read)           cmd_read "${1:-}" "${2:-}";;
  set)            cmd_set "${1:-}" "${2:-}" "${3:-}";;
  set-list)       cmd_set_list "${1:-}" "${2:-}" "${3:-}";;
  achieve)        cmd_achieve "${1:-}";;
  abandon)        cmd_close "${1:-}" "abandoned";;
  reap)           cmd_close "${1:-}" "abandoned";;
  list)           cmd_list "${1:-}";;
  lineage)        cmd_lineage "${1:-}";;
  check-collision) cmd_check_collision "${1:-}" "${2:-[]}" "${3:-}";;
  spawn-check)    cmd_spawn_check "${1:-}" "${2:-}" "${3:-}" "${4:-}" "${5:-[]}";;
  roadmap-gate)   cmd_roadmap_gate "${1:-}";;
  *)
    echo "Usage: goals.sh {new|read|set|set-list|achieve|abandon|reap|list|lineage|check-collision|spawn-check|roadmap-gate} ..." >&2
    exit 2;;
esac
exit $?
