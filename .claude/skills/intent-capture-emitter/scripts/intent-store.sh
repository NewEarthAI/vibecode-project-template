#!/usr/bin/env bash
# intent-capture-emitter/scripts/intent-store.sh — the canonical intent-ledger read/write helper.
#
# Intent-Actual-Gap Mechanism Build Programme — M6 (intent-capture, the 3rd/final mechanism).
# The intent-layer SIBLING of topology-substrate/scripts/substrate.sh. It is NOT a call into
# substrate.sh: that helper's validate-schema hardcodes the topology kinds/emitters/fields, so an
# intent record fails it (Capability Scout, council 2026-06-07 A10). This file copies substrate.sh's
# lock + atomic-write + chunk + upsert-by-id PATTERNS and enforces the Doctrine 04 §6.1 intent
# schema (14 fields after the M6 falsifier addition).
#
# Schema authority: docs/operational-doctrine/04_intent-capture.md §6.1 + §6.1.1 (the falsifier
# FORMAT). 5-field provenance envelope (shared with D05/D06) + 9 authored payload fields.
#
# Concurrency: mirrors substrate.sh — atomic mkdir lock (TTL 30m, 60m clock-skew bound, symlink
# TOCTOU guard, fail-closed on unreadable epoch), jq -n -> mktemp -> mv. Whole-file lock (the
# ledger is a single JSON file).
#
# The intent store is a SEPARATE FILE from the computed layer (council A11): authored records live
# here (intent-ledger.json); the per-field change-commit map lives in intent-computed.json (emitted
# by emit.sh, not by this store) so the Doctrine 04 P2 authored/derived boundary is STRUCTURAL,
# not discipline-dependent. This helper NEVER writes a derived field into a record.
#
# Portability: macOS system bash 3.2.57 + jq 1.7. NO associative arrays, NO mapfile, NO ${var,,}.
# All structure in jq; bash only orchestrates + holds the lock. Per shell-portability.md:
# set -uo pipefail, mkdir lock, numeric normalisation before [ integer tests, namespaced locals
# (avoid zsh-reserved `status`), NO apostrophes inside inline single-quoted jq programs.
#
# Usage:
#   intent-store.sh init <entity>                          -> create empty ledger if absent (idempotent)
#   intent-store.sh write-record '<record-json>'           -> atomic single-record upsert-by-id
#   intent-store.sh bulk-write '<records-json>'            -> single locked batch upsert-by-id
#   intent-store.sh mark-emitter-ran <name> <coverage>     -> update emitters.<name> heartbeat + coverage
#   intent-store.sh read-intent ['<jq-filter>']            -> validate + print ledger (optional jq slice)
#   intent-store.sh get <topic>                            -> terminal record for a topic (supersession-walked)
#   intent-store.sh read <id>                              -> human view (conditions + binary_test + falsifier)
#   intent-store.sh slice <topic> <field,field,...>        -> only the named fields of the topic terminal
#   intent-store.sh validate-schema                        -> PASS or a violation list
#
# Exit codes: 0 ok | 2 usage/bad-arg | 4 ledger not found (run init) | 5 lock held after retry
#             6 corrupt / jq-missing / write-failed / integrity-violation
#             7 read-API resolution surfaced a conflict/broken-chain (get/slice) — a HONEST non-fatal verdict

set -uo pipefail

# --- configuration --------------------------------------------------------------
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LEDGER_PATH="${INTENT_SUBSTRATE_PATH:-$PROJECT_DIR/.understand-anything/intent-ledger.json}"
LEDGER_DIR="$(dirname "$LEDGER_PATH")"
# Init guard (council A10): a misconfigured INTENT_SUBSTRATE_PATH must never silently write to a
# wrong/escaping location. Refuse an empty or root-resolving dir, or a symlinked parent.
if [ -z "$LEDGER_DIR" ] || [ "$LEDGER_DIR" = "/" ]; then
  echo "intent-store.sh: LEDGER_DIR resolves to empty or '/' (from INTENT_SUBSTRATE_PATH='${INTENT_SUBSTRATE_PATH:-}') — refusing" >&2
  exit 6
fi
if [ -L "$LEDGER_DIR" ]; then
  echo "intent-store.sh: LEDGER_DIR '$LEDGER_DIR' is a symlink — refusing (writes/rm could escape the intended location)" >&2
  exit 6
fi
LOCK_DIR="$LEDGER_DIR/.intent-lock"
SCHEMA_VERSION="m6-v1"
TTL_MIN=30
FUTURE_TOLERANCE_MIN=60
LOCK_RETRIES=25
LOCK_SLEEP=0.2

# Frozen contract enums (single source of truth — keep in lockstep with Doctrine 04 §6.1/§6.2).
# kind = the four intent carrier kinds (D04 §6.2). The contract-kind PARSER is cut from M6 v1 (D4),
# but the enum value stays for forward-compat (a hand-written contract record is still valid).
VALID_KINDS="destination adr roadmap_item contract"
# emitter = which carrier parser produced the record. contract_parser reserved (parser cut in v1).
VALID_EMITTERS="destination_parser adr_parser roadmap_parser contract_parser manual"
VALID_STATUS="draft accepted superseded fulfilled"
VALID_COVERAGE="covered absent degenerate declared-missing"
KNOWN_EMITTER_NAMES="destination_parser adr_parser roadmap_parser"
# Top-level frozen key set.
TOPLEVEL_KEYS_JSON='["schema_version","entity","last_updated","emitters","records"]'
# Record frozen key set — the Doctrine 04 §6.1 14 fields (5 provenance + 9 payload incl. falsifier).
RECORD_KEYS_JSON='["id","kind","source_file","source_commit","timestamp","title","status","superseded_by","conditions","binary_test","falsifier","wired_to","owner","acceptance_cadence"]'

ts_now()   { date -u +%Y-%m-%dT%H:%M:%SZ; }
ts_epoch() { date -u +%s; }

if ! command -v jq >/dev/null 2>&1; then
  echo "intent-store.sh: jq not found in PATH — required dependency (brew install jq)" >&2
  exit 6
fi

# --- whole-file mkdir lock (mirrors substrate.sh _acquire) ----------------------
_acquire() {
  local attempt=0 acq now age
  mkdir -p "$LEDGER_DIR" 2>/dev/null || true
  if [ -L "$LOCK_DIR" ]; then
    echo "intent-store.sh: $LOCK_DIR is a symlink — refusing (potential TOCTOU)" >&2
    return 6
  fi
  while [ "$attempt" -le "$LOCK_RETRIES" ]; do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      date -u +%s > "$LOCK_DIR/acquired_epoch" 2>/dev/null || true
      return 0
    fi
    if [ "$attempt" -eq 0 ]; then
      acq="$(cat "$LOCK_DIR/acquired_epoch" 2>/dev/null || echo '')"
      now="$(ts_epoch)"
      if ! echo "$acq" | grep -qE '^[0-9]+$'; then
        echo "intent-store.sh: lock $LOCK_DIR present, epoch unreadable — treating as fresh, not taking over" >&2
      elif [ "$acq" -gt "$((now + FUTURE_TOLERANCE_MIN * 60))" ]; then
        echo "intent-store.sh: lock $LOCK_DIR future-dated (clock skew) — refusing; inspect/rm manually" >&2
        return 5
      else
        age=$(( (now - acq) / 60 ))
        if [ "$age" -ge "$TTL_MIN" ]; then
          rm -f "$LOCK_DIR/acquired_epoch" 2>/dev/null || true
          rmdir "$LOCK_DIR" 2>/dev/null || true
          if mkdir "$LOCK_DIR" 2>/dev/null; then
            date -u +%s > "$LOCK_DIR/acquired_epoch" 2>/dev/null || true
            echo "intent-store.sh: reclaimed stale lock (age ${age}min)" >&2
            return 0
          fi
        fi
      fi
    fi
    attempt=$((attempt + 1))
    sleep "$LOCK_SLEEP" 2>/dev/null || sleep 1
  done
  echo "intent-store.sh: lock still held after ${LOCK_RETRIES} retries — another op is stuck; inspect $LOCK_DIR" >&2
  return 5
}
_release() {
  case "$LOCK_DIR" in
    "$LEDGER_DIR"/.intent-lock) rm -rf "$LOCK_DIR" 2>/dev/null || true;;
    *) echo "intent-store.sh: _release: lock path '$LOCK_DIR' unexpected — refusing rm" >&2;;
  esac
}

# --- atomic write (mirrors substrate.sh _atomic_apply; no maps to re-derive) ----
_atomic_apply() {
  local filter="$1"; shift
  local tmp jqerr now
  now="$(ts_now)"
  if [ ! -f "$LEDGER_PATH" ]; then
    echo "intent-store.sh: ledger not found at $LEDGER_PATH (run: init <entity>)" >&2
    return 4
  fi
  tmp="$(mktemp "${LEDGER_DIR}/.intent-tmp.XXXXXX")"     || { echo "intent-store.sh: mktemp failed" >&2; return 6; }
  jqerr="$(mktemp "${LEDGER_DIR}/.intent-jqerr.XXXXXX")" || { rm -f "$tmp"; echo "intent-store.sh: mktemp failed" >&2; return 6; }
  if jq "$@" --arg _now "$now" \
       "( $filter ) | .last_updated = \$_now" \
       "$LEDGER_PATH" > "$tmp" 2>"$jqerr"; then
    if jq -e 'type == "object"' "$tmp" >/dev/null 2>&1; then
      mv "$tmp" "$LEDGER_PATH" || { echo "intent-store.sh: mv failed" >&2; rm -f "$tmp" "$jqerr"; return 6; }
      rm -f "$jqerr" 2>/dev/null || true
      return 0
    fi
    echo "intent-store.sh: post-transform output was not a JSON object — write aborted" >&2
    rm -f "$tmp" "$jqerr"; return 6
  fi
  echo "intent-store.sh: jq transform failed: $(cat "$jqerr" 2>/dev/null)" >&2
  rm -f "$tmp" "$jqerr" 2>/dev/null || true
  return 6
}

_in_list() { case " $2 " in *" $1 "*) return 0;; esac; return 1; }

# --- record input validation (batch, one jq pass) -------------------------------
# Validates ALL records in one jq pass. Same rules as validate-schema per-record, used pre-lock by
# bulk-write so an N-record batch costs one jq fork. Note: NO apostrophes in this jq program.
_validate_records_batch() {
  local records="$1" violations
  violations="$(printf '%s' "$records" | jq -r \
      --arg kinds "$VALID_KINDS" --arg emitters "$VALID_EMITTERS" --arg statuses "$VALID_STATUS" '
    ($kinds | split(" ")) as $VK | ($emitters | split(" ")) as $VE | ($statuses | split(" ")) as $VS |
    .[] | . as $r |
    ( if (($r | type) != "object") then "a record is not a JSON object" else empty end ),
    ( if (($r.id // "") == "")          then "a record is missing .id"                              else empty end ),
    ( if (($r.kind // "") == "")        then "record \($r.id // "?") missing .kind"                 else empty end ),
    ( if (($r.emitter // "") == "")     then "record \($r.id // "?") missing .emitter"              else empty end ),
    ( if (($r.status // "") == "")      then "record \($r.id // "?") missing .status"               else empty end ),
    ( if (($r.kind != null) and (($VK | index($r.kind)) == null))       then "record \($r.id // "?") invalid kind \($r.kind)"       else empty end ),
    ( if (($r.emitter != null) and (($VE | index($r.emitter)) == null)) then "record \($r.id // "?") invalid emitter \($r.emitter)" else empty end ),
    ( if (($r.status != null) and (($VS | index($r.status)) == null))   then "record \($r.id // "?") invalid status \($r.status)"   else empty end ),
    ( if ($r.status == "accepted" and (($r.wired_to // null) == null))  then "record \($r.id // "?") accepted but wired_to absent (orphan — D04 9.5; use pending)" else empty end )
  ' 2>/dev/null)"
  if [ -n "$violations" ]; then echo "$violations" >&2; return 2; fi
  return 0
}

# --- the supersession walk (council A8 — cycle + broken-pointer + conflict) ------
# A jq library injected via --argjson into the read-API programs. Given a by-id index $byid and a
# start id, walks superseded_by to the single terminal. Returns {terminal, status} where status is
# ok | cycle | broken. NO apostrophes (inline single-quoted).
JQ_WALK_DEF='
  def walk($byid; $start):
    { cur: $start, visited: [], result: null }
    | until(.result != null;
        .cur as $c
        | if ($byid[$c] == null) then .result = {terminal: null, status: "broken", at: $c}
          elif (.visited | index($c)) then .result = {terminal: null, status: "cycle", at: $c}
          else .visited += [$c]
               | ($byid[$c].superseded_by) as $nxt
               | if ($nxt == null or $nxt == "") then .result = {terminal: $c, status: "ok"}
                 else .cur = $nxt end
          end)
    | .result;
'

# --- subcommands ----------------------------------------------------------------

cmd_init() {
  local entity="${1:-}"
  [ -n "$entity" ] || { echo "intent-store.sh: init requires <entity>" >&2; return 2; }
  _acquire || return $?
  if [ -f "$LEDGER_PATH" ]; then
    _release
    echo "intent-store.sh: ledger already exists at $LEDGER_PATH (init is idempotent — no change)"
    return 0
  fi
  local tmp now
  now="$(ts_now)"
  tmp="$(mktemp "${LEDGER_DIR}/.intent-tmp.XXXXXX")" || { _release; echo "intent-store.sh: mktemp failed" >&2; return 6; }
  if jq -n --arg sv "$SCHEMA_VERSION" --arg entity "$entity" --arg now "$now" '
    {
      schema_version: $sv,
      entity: $entity,
      last_updated: $now,
      emitters: {
        "destination_parser": { last_emitted_at: null, coverage: "declared-missing" },
        "adr_parser":         { last_emitted_at: null, coverage: "declared-missing" },
        "roadmap_parser":     { last_emitted_at: null, coverage: "declared-missing" }
      },
      records: []
    }' > "$tmp" 2>/dev/null; then
    mv "$tmp" "$LEDGER_PATH" || { rm -f "$tmp"; _release; echo "intent-store.sh: mv failed" >&2; return 6; }
    _release
    echo "intent-store.sh: initialised intent ledger for '$entity' at $LEDGER_PATH"
    return 0
  fi
  rm -f "$tmp"; _release
  echo "intent-store.sh: init jq build failed" >&2
  return 6
}

# Normalise a record: ensure the optional fields default to a uniform shape. wired_to defaults to
# "pending" (D04 P3 — never an absent field on an accepted record). superseded_by defaults null.
_normalise_record_filter='
  .superseded_by      = (.superseded_by // null)
  | .wired_to         = (.wired_to // "pending")
  | .falsifier        = (.falsifier // null)
  | .conditions       = (.conditions // null)
  | .binary_test      = (.binary_test // null)
  | .owner            = (.owner // null)
  | .acceptance_cadence = (.acceptance_cadence // null)
'

cmd_write_record() {
  local record="${1:-}"
  [ -n "$record" ] || { echo "intent-store.sh: write-record requires '<record-json>'" >&2; return 2; }
  _validate_records_batch "[$record]" || return 2
  _acquire || return $?
  _atomic_apply "
    .records = ( [ .records[] | select(.id != (\$record.id)) ]
                 + [ \$record | $_normalise_record_filter ] )
  " --argjson record "$record"
  local rc=$?
  _release
  [ "$rc" -eq 0 ] && echo "intent-store.sh: wrote record $(echo "$record" | jq -r '.id')"
  return "$rc"
}

# bulk-write: one lock, one jq write. Upsert-by-id (D8: append-or-replace; reverse-before-unique_by
# so the LAST occurrence of each id wins). Supersession status is AUTHORED in the record and indexed
# as-is — the store NEVER auto-marks supersession (that would be the store deriving intent — P1).
cmd_bulk_write() {
  local records="${1:-}"
  [ -n "$records" ] || { echo "intent-store.sh: bulk-write requires '<records-json>'" >&2; return 2; }
  if ! printf '%s' "$records" | jq -e 'type == "array"' >/dev/null 2>&1; then
    echo "intent-store.sh: records must be a JSON array" >&2; return 2
  fi
  _validate_records_batch "$records" || { echo "intent-store.sh: bulk-write aborted — invalid record(s) above" >&2; return 2; }
  local count
  count="$(printf '%s' "$records" | jq 'length')"
  _acquire || return $?
  if [ ! -f "$LEDGER_PATH" ]; then _release; echo "intent-store.sh: ledger not found (run init)" >&2; return 4; fi
  _atomic_apply "
    .records = ( ( [ .records[] ] + [ \$records[] | $_normalise_record_filter ] )
                 | reverse | unique_by(.id) )
  " --argjson records "$records"
  local rc=$?
  _release
  [ "$rc" -eq 0 ] && echo "intent-store.sh: bulk-write applied ($count records)"
  return "$rc"
}

cmd_mark_emitter_ran() {
  local name="${1:-}" coverage="${2:-}"
  [ -n "$name" ] || { echo "intent-store.sh: mark-emitter-ran requires <name> <coverage>" >&2; return 2; }
  [ -n "$coverage" ] || { echo "intent-store.sh: mark-emitter-ran requires a <coverage> (one of: $VALID_COVERAGE)" >&2; return 2; }
  _in_list "$name" "$KNOWN_EMITTER_NAMES" || { echo "intent-store.sh: unknown emitter '$name' (known: $KNOWN_EMITTER_NAMES)" >&2; return 2; }
  _in_list "$coverage" "$VALID_COVERAGE"  || { echo "intent-store.sh: invalid coverage '$coverage' (one of: $VALID_COVERAGE)" >&2; return 2; }
  _acquire || return $?
  _atomic_apply '
    .emitters[$name] = { last_emitted_at: $now2, coverage: $cov }
  ' --arg name "$name" --arg cov "$coverage" --arg now2 "$(ts_now)"
  local rc=$?
  _release
  [ "$rc" -eq 0 ] && echo "intent-store.sh: emitter '$name' marked ran (coverage=$coverage)"
  return "$rc"
}

cmd_read_intent() {
  local filter="${1:-.}"
  if [ ! -f "$LEDGER_PATH" ]; then
    echo "intent-store.sh: ledger not found at $LEDGER_PATH (run: init <entity>)" >&2
    return 4
  fi
  if ! _validate_core >/dev/null 2>&1; then
    echo "intent-store.sh: ledger failed validation — refusing to serve (run validate-schema for details)" >&2
    return 6
  fi
  jq "$filter" "$LEDGER_PATH" 2>/dev/null || { echo "intent-store.sh: jq filter failed" >&2; return 6; }
}

# get(topic): supersession-walked terminal for a topic. topic matches the record id (exact) OR a
# case-insensitive substring of title (a human query convenience — NOT a machine join; the wired_to
# JOIN never uses fuzzy matching, D2). Emits a verdict object; rc 7 on conflict/broken (HONEST
# non-fatal — never silently picks a terminal).
cmd_get() {
  local topic="${1:-}"
  [ -n "$topic" ] || { echo "intent-store.sh: get requires <topic>" >&2; return 2; }
  if [ ! -f "$LEDGER_PATH" ]; then echo "intent-store.sh: ledger not found (run init)" >&2; return 4; fi
  local out verdict
  out="$(jq -c --arg topic "$topic" "
    $JQ_WALK_DEF
    (\$topic | ascii_downcase) as \$tl
    | (.records) as \$list
    | (\$list | map({key:.id, value:.}) | from_entries) as \$byid
    | [ \$list[] | select( (.id == \$topic) or ((.title // \"\") | ascii_downcase | contains(\$tl)) ) ] as \$matched
    | if (\$matched | length) == 0 then {verdict: \"not_found\", topic: \$topic}
      else
        [ \$matched[] | walk(\$byid; .id) ] as \$walks
        | (\$walks | map(select(.status==\"ok\") | .terminal) | unique) as \$terms
        | (\$walks | map(select(.status!=\"ok\"))) as \$bad
        | if (\$bad | length) > 0 then {verdict: \"supersession_chain_broken\", topic: \$topic, detail: \$bad}
          elif (\$terms | length) > 1 then {verdict: \"supersession_conflict\", topic: \$topic, terminals: \$terms}
          elif (\$terms | length) == 1 then {verdict: \"ok\", record: \$byid[\$terms[0]]}
          else {verdict: \"no_terminal\", topic: \$topic}
          end
      end
  " "$LEDGER_PATH" 2>/dev/null)" || { echo "intent-store.sh: get jq failed" >&2; return 6; }
  echo "$out"
  verdict="$(printf '%s' "$out" | jq -r '.verdict')"
  case "$verdict" in
    ok) return 0;;
    not_found|no_terminal) return 7;;
    supersession_conflict|supersession_chain_broken) return 7;;
    *) return 6;;
  esac
}

cmd_read() {
  local id="${1:-}"
  [ -n "$id" ] || { echo "intent-store.sh: read requires <id>" >&2; return 2; }
  if [ ! -f "$LEDGER_PATH" ]; then echo "intent-store.sh: ledger not found (run init)" >&2; return 4; fi
  local out
  out="$(jq -c --arg id "$id" '
    (.records | map(select(.id == $id)) | .[0]) as $r
    | if $r == null then {verdict: "not_found", id: $id}
      else {verdict: "ok", id: $r.id, title: $r.title, status: $r.status,
            conditions: $r.conditions, binary_test: $r.binary_test, falsifier: $r.falsifier,
            wired_to: $r.wired_to, owner: $r.owner}
      end
  ' "$LEDGER_PATH" 2>/dev/null)" || { echo "intent-store.sh: read jq failed" >&2; return 6; }
  echo "$out"
  [ "$(printf '%s' "$out" | jq -r '.verdict')" = "ok" ] && return 0
  return 7
}

# slice(topic, fields): only the named fields of the topic terminal — the bounded read for AI sessions.
cmd_slice() {
  local topic="${1:-}" fields="${2:-}"
  [ -n "$topic" ]  || { echo "intent-store.sh: slice requires <topic> <field,field,...>" >&2; return 2; }
  [ -n "$fields" ] || { echo "intent-store.sh: slice requires a comma-separated <fields> list" >&2; return 2; }
  local getout verdict rec
  getout="$(cmd_get "$topic")"; local grc=$?
  if [ "$grc" -ne 0 ]; then echo "$getout"; return "$grc"; fi
  rec="$(printf '%s' "$getout" | jq -c '.record')"
  printf '%s' "$rec" | jq -c --arg fields "$fields" '
    ($fields | split(",") | map(gsub("^\\s+|\\s+$";""))) as $f
    | reduce $f[] as $k ({}; . + {($k): ($rec_in[$k])})
  ' --argjson rec_in "$rec" 2>/dev/null || { echo "intent-store.sh: slice jq failed" >&2; return 6; }
  return 0
}

# --- validation engine (mirrors substrate.sh _validate_core) --------------------
_validate_core() {
  if [ ! -f "$LEDGER_PATH" ]; then echo "MISSING: $LEDGER_PATH (run init)"; return 6; fi
  if ! jq -e 'type == "object"' "$LEDGER_PATH" >/dev/null 2>&1; then echo "CORRUPT: not valid JSON / not an object"; return 6; fi
  local violations jqrc jqerr
  jqerr="$(mktemp "${LEDGER_DIR}/.intent-valerr.XXXXXX" 2>/dev/null || echo "/tmp/.intent-valerr.$$")"
  violations="$(jq -r \
      --argjson tkeys "$TOPLEVEL_KEYS_JSON" \
      --argjson rkeys "$RECORD_KEYS_JSON" \
      --arg sv "$SCHEMA_VERSION" \
      --arg kinds "$VALID_KINDS" \
      --arg emitters "$VALID_EMITTERS" \
      --arg statuses "$VALID_STATUS" \
      --arg coverage "$VALID_COVERAGE" '
    ($kinds    | split(" ")) as $VK |
    ($emitters | split(" ")) as $VE |
    ($statuses | split(" ")) as $VS |
    ($coverage | split(" ")) as $VC |
    [
      (if (keys_unsorted | sort) != ($tkeys | sort)
        then "top-level keys mismatch: got \(keys_unsorted|sort) want \($tkeys|sort)" else empty end),
      (if .schema_version != $sv then "schema_version != \($sv) (got \(.schema_version))" else empty end),
      (if (.entity // "") == "" then "entity is empty" else empty end),
      (if (.last_updated // "") == "" then "last_updated is empty" else empty end),
      (if (.records|type) != "array" then "records is not an array" else empty end),
      (if (.emitters|type) != "object" then "emitters is not an object" else empty end),

      # per-record: frozen 14-key set (the emitter field is provenance-extra, allowed once).
      ( .records[]? as $r |
        ( ($r | keys_unsorted) as $have |
          ( ($rkeys - $have) as $missing |
            if ($missing | length) > 0 then "record \($r.id // "?") missing keys \($missing)" else empty end ),
          ( ($have - ($rkeys + ["emitter"])) as $extra |
            if ($extra | length) > 0 then "record \($r.id // "?") has unexpected keys \($extra)" else empty end )
        ),
        ( if ($r.kind as $k | $VK | index($k)) == null then "record \($r.id) invalid kind \($r.kind)" else empty end ),
        ( if ($r.status as $s | $VS | index($s)) == null then "record \($r.id) invalid status \($r.status)" else empty end ),
        ( if (($r.emitter // null) != null) and (($VE | index($r.emitter)) == null) then "record \($r.id) invalid emitter \($r.emitter)" else empty end ),
        ( if $r.status == "accepted" and (($r.wired_to // null) == null) then "record \($r.id) accepted but wired_to absent (orphan — D04 9.5)" else empty end )
      ),

      # per-emitter coverage enum (type-guarded so a corrupt value yields a VIOLATION, not a jq abort)
      ( if (.emitters|type) == "object" then ( .emitters | to_entries[] |
          ( if (.value|type) != "object" then "emitter \(.key) value is not an object"
            elif ((.value.coverage // null) as $c | ($c == null) or (($VC | index($c)) == null))
              then "emitter \(.key) invalid coverage \(.value.coverage)"
            else empty end )
        ) else empty end ),

      # supersession integrity: every superseded_by must resolve to an existing record id
      # (a broken pointer is a corpus-level violation surfaced here, not just at get-time).
      ( ( [.records[].id] | map({key:., value:true}) | from_entries ) as $idset |
        .records[]? | . as $r |
        ( if (($r.superseded_by // null) != null) and ($idset[$r.superseded_by] != true)
            then "record \($r.id) superseded_by \($r.superseded_by) which is not a present record (broken chain)" else empty end )
      )
    ] | .[]
  ' "$LEDGER_PATH" 2>"$jqerr")"
  jqrc=$?
  if [ "$jqrc" -ne 0 ]; then
    echo "CORRUPT: validation engine aborted (jq exit $jqrc): $(cat "$jqerr" 2>/dev/null)"
    rm -f "$jqerr" 2>/dev/null || true
    return 6
  fi
  rm -f "$jqerr" 2>/dev/null || true
  if [ -z "$violations" ]; then echo "PASS"; return 0; fi
  echo "VIOLATIONS:"; echo "$violations"; return 6
}

cmd_validate_schema() { _validate_core; }

# --- dispatch -------------------------------------------------------------------
main() {
  local cmd="${1:-}"
  shift 2>/dev/null || true
  case "$cmd" in
    init)             cmd_init "$@";;
    write-record)     cmd_write_record "$@";;
    bulk-write)       cmd_bulk_write "$@";;
    mark-emitter-ran) cmd_mark_emitter_ran "$@";;
    read-intent)      cmd_read_intent "$@";;
    get)              cmd_get "$@";;
    read)             cmd_read "$@";;
    slice)            cmd_slice "$@";;
    validate-schema)  cmd_validate_schema "$@";;
    ''|-h|--help|help)
      grep -E '^#( |$)' "$0" | sed -E 's/^# ?//' | sed -n '1,48p'
      return 0;;
    *)
      echo "intent-store.sh: unknown command '$cmd' (run: intent-store.sh help)" >&2
      return 2;;
  esac
}

main "$@"
