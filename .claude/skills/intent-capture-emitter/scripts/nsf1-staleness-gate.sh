#!/usr/bin/env bash
# intent-capture-emitter/scripts/nsf1-staleness-gate.sh — NSF-1 (council A6), the intent-staleness
# watchdog. The SIBLING of topology-health-check/scripts/sustain-staleness-gate.sh, adapted from
# oldest-COVERED-EMITTER-vs-one-window to per-RECORD-vs-its-OWN-acceptance-cadence.
#
# WHY THIS EXISTS (Doctrine 04 §6.5 / §8.3 / §9.8 / A.11): an `accepted` intent record whose
# acceptance_cadence has elapsed with NO re-confirmation sits `accepted` + (reconciliation) `in_sync`
# forever while nobody asks whether it is still wanted. In-sync + overdue-acceptance = a STALE PROMISE,
# not a drift. The doctrine demands the overdue cadence be a SURFACED signal (operator card), never left
# to rot. This gate is that surface — LOUD + BINDING (council A6): a stale promise exits non-zero so the
# sustain consumption event does NOT pass clean until the owner re-confirms or supersedes it.
#
# This is intent-freshness, DISTINCT from reconciliation drift (§6.5): the implementation may match the
# promise exactly (reconcile says in_sync) while the promise itself has gone stale. The two cadences are
# independent — a core reason intent and reconciliation are separate mechanisms (Test D / §12).
#
# CONTRACT: READ-ONLY. Reads the intent ledger via jq. NEVER writes the ledger. NEVER runs an emitter.
# Emits a single verdict (fresh_intent | stale_intent | anomalous | no_accepted_intent | uninitialised |
# corrupt) + a machine-readable --json line for the sustain log so Test C stays verifiable.
#
# FRESHNESS RULE (per accepted record — each is INDEPENDENTLY actionable, unlike the emitter gate):
#   - Only status == "accepted" records are checked. A `draft` is not yet a binding promise;
#     `superseded` / `fulfilled` are terminal. Skipping them is what makes the gate correct on a
#     ledger of mostly-terminal records instead of false-flagging it (Doctrine 04 §6.4 status enum).
#   - cadence_days comes from each record acceptance_cadence: a cadence WORD (daily/weekly/monthly/
#     quarterly/...) maps to days; a numeric "90" / "90d" is days verbatim; NULL/empty uses the
#     default (90d, INTENT_ACCEPTANCE_DEFAULT_DAYS) — absence is a documented default, NOT an anomaly.
#   - A record is OVERDUE if (now - timestamp) > cadence_days. ALL overdue records are listed (each
#     prompts its own owner to re-confirm or supersede) — not just the oldest.
#   - An accepted record with a null/unparseable/FUTURE-dated timestamp is an ANOMALY
#     (`accepted_no_timestamp` / `accepted_future_dated`) — coverage says live, the heartbeat denies it;
#     never silently treated as fresh (the honest-degradation principle; mirrors the sibling).
#   - An accepted record with a PRESENT-BUT-UNINTELLIGIBLE acceptance_cadence is an ANOMALY
#     (`unrecognised_cadence`) — never laundered into the 90d default, which could be wildly wrong if the
#     author meant "daily". ABSENCE → default; PRESENT-BUT-GARBAGE → anomaly. (The principled split.)
#   - ZERO accepted records → `no_accepted_intent` (vacuous "fresh" over an empty check would be the
#     laundering failure — exit 4, distinct from fresh).
#
# Default cadence: 90 days (council/continuation). Override via INTENT_ACCEPTANCE_DEFAULT_DAYS.
#
# bash 3.2 + jq 1.7 portable. macOS-safe: NOW from `date -u +%s`; ALL ISO-8601 parsing via jq
# fromdateiso8601 — NEVER GNU `date -d` (absent on macOS). No apostrophes inside inline single-quoted jq.
#
# Exit codes: 0 fresh · 1 stale (BINDING) · 3 anomalous · 4 no-accepted/uninitialised · 6 corrupt/jq-missing · 2 usage.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LEDGER_PATH="${INTENT_SUBSTRATE_PATH:-$PROJECT_DIR/.understand-anything/intent-ledger.json}"

MODE="text"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) MODE="json"; shift ;;
    *) echo "nsf1-staleness-gate.sh: unknown argument '$1' (usage: nsf1-staleness-gate.sh [--json])" >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "nsf1-staleness-gate.sh: jq not found" >&2; exit 6; }

# default cadence window (days), digits-only normalised (a malformed override falls back, never crashes)
DEFAULT_DAYS="${INTENT_ACCEPTANCE_DEFAULT_DAYS:-90}"
DEFAULT_DAYS="$(printf '%s' "$DEFAULT_DAYS" | tr -dc '0-9' | head -c 6)"; DEFAULT_DAYS="${DEFAULT_DAYS:-90}"

NOW_EPOCH="$(date -u +%s)"   # macOS-safe; jq does ISO-8601 parsing via fromdateiso8601.

# ---- STEP 1 — read the ledger (missing → uninitialised; non-JSON / wrong shape → corrupt) ---------------
if [ ! -f "$LEDGER_PATH" ]; then
  if [ "$MODE" = "json" ]; then
    printf '{"verdict":"uninitialised","default_days":%s,"accepted_count":0,"detail":"intent ledger not found at %s — run init + an emitter before the sustain window opens"}\n' "$DEFAULT_DAYS" "$LEDGER_PATH"
  else
    echo "INTENT STALENESS: uninitialised — no intent ledger at $LEDGER_PATH. Run init + an emitter before opening the sustain window."
  fi
  exit 4
fi
LEDGER_JSON="$(cat "$LEDGER_PATH" 2>/dev/null)"
if [ -z "$LEDGER_JSON" ] || ! printf '%s' "$LEDGER_JSON" | jq -e 'type == "object"' >/dev/null 2>&1; then
  if [ "$MODE" = "json" ]; then
    printf '{"verdict":"corrupt","default_days":%s,"detail":"ledger is empty or not a JSON object — corrupt; do NOT consume against it"}\n' "$DEFAULT_DAYS"
  else
    echo "INTENT STALENESS: corrupt — the ledger at $LEDGER_PATH is empty or not a JSON object. Do NOT consume against it."
  fi
  exit 6
fi
# .records TYPE guard (mirror the sibling .emitters guard): a JSON object that parses but whose .records
# is not an array is a schema violation — fail loud, never judge it as if a valid record list.
RECORDS_TYPE="$(printf '%s' "$LEDGER_JSON" | jq -r '(.records // null) | type' 2>/dev/null)"
if [ "$RECORDS_TYPE" != "array" ] && [ "$RECORDS_TYPE" != "null" ]; then
  if [ "$MODE" = "json" ]; then
    printf '{"verdict":"corrupt","default_days":%s,"detail":"ledger .records is type %s, expected array — schema violation"}\n' "$DEFAULT_DAYS" "$RECORDS_TYPE"
  else
    echo "INTENT STALENESS: corrupt — the ledger .records is a $RECORDS_TYPE, not an array. Schema violation; do NOT consume against it."
  fi
  exit 6
fi

# ---- STEP 2 — judge per-accepted-record freshness in ONE jq pass ----------------------------------------
GATE_JSON="$(printf '%s' "$LEDGER_JSON" | jq -c \
  --argjson nowep "$NOW_EPOCH" \
  --argjson defdays "$DEFAULT_DAYS" '
  # epoch of an ISO-8601 string, or null if missing/unparseable (NEVER GNU date -d).
  def tsepoch($s): (try (($s // "") | fromdateiso8601) catch null);
  # acceptance_cadence -> { days, recognised }. ABSENCE -> default (recognised). PRESENT-BUT-GARBAGE ->
  # recognised:false (the caller routes it to the unrecognised_cadence anomaly). Specific tests before
  # general so "biannual" (contains "ann") is not captured by the yearly branch.
  def cadence_days($c):
    ( ($c // "") | if type == "number" then (tostring) else . end | ascii_downcase
      | gsub("^\\s+|\\s+$";"") ) as $w
    | if   $w == ""                              then { days: $defdays, recognised: true }
      elif ($w | test("^[0-9]+d?$"))             then { days: ($w | gsub("d";"") | tonumber), recognised: true }
      elif ($w | test("dai|every.?day"))         then { days: 1,   recognised: true }
      elif ($w | test("fortnight|bi.?week"))     then { days: 14,  recognised: true }
      elif ($w | test("week"))                   then { days: 7,   recognised: true }
      elif ($w | test("bi.?month|every.?other.?month")) then { days: 60, recognised: true }
      elif ($w | test("month"))                  then { days: 30,  recognised: true }
      elif ($w | test("quarter"))                then { days: 90,  recognised: true }
      elif ($w | test("semi.?ann|half.?year|bi.?ann"))  then { days: 182, recognised: true }
      elif ($w | test("bienn|every.?two.?year")) then { days: 730, recognised: true }
      elif ($w | test("ann|year"))               then { days: 365, recognised: true }
      else { days: $defdays, recognised: false } end;
  ( .records // [] ) as $recs
  | [ $recs[] | select(.status == "accepted") ] as $accepted
  | [ $recs[] | select(.status == "draft") ] as $drafts
  | [ $accepted[]
      | (cadence_days(.acceptance_cadence)) as $cd
      | { id: .id, ep: tsepoch(.timestamp), raw_ts: .timestamp,
          cadence_raw: (.acceptance_cadence // null),
          cadence_days: $cd.days, cadence_recognised: $cd.recognised,
          cadence_defaulted: ((.acceptance_cadence // "") == "") } ] as $rows
  # anomalies: bad/missing/future timestamp, OR a present-but-unintelligible cadence string.
  | [ $rows[]
      | if (.ep == null)            then { id, reason: "accepted_no_timestamp" }
        elif (.ep > $nowep)         then { id, reason: "accepted_future_dated" }
        elif (.cadence_recognised | not) then { id, reason: "unrecognised_cadence", cadence_raw }
        else empty end ] as $anomalies
  # overdue: a clean row whose age exceeds its own cadence window.
  | [ $rows[]
      | select(.ep != null and .ep <= $nowep and .cadence_recognised)
      | (.cadence_days * 86400) as $win
      | ($nowep - .ep) as $age
      | select($age > $win)
      | { id, age_days: (($age / 86400) | floor), cadence_days, cadence_raw,
          cadence_defaulted } ] as $overdue
  | {
      accepted_count: ($accepted | length),
      draft_count: ($drafts | length),
      defaulted_count: ([ $rows[] | select(.cadence_defaulted) ] | length),
      overdue: $overdue,
      anomalies: $anomalies,
      verdict:
        ( if   ($accepted | length) == 0     then "no_accepted_intent"
          elif ($anomalies | length) > 0     then "anomalous"
          elif ($overdue | length) > 0       then "stale_intent"
          else "fresh_intent" end )
    }')"
# Guard the piped jq (shell-portability §1 — a pipe eats $?): empty GATE_JSON means the judgement jq
# errored. Fail LOUD (exit 6) rather than let an empty verdict become a misleading blank output.
if [ -z "$GATE_JSON" ]; then
  echo "nsf1-staleness-gate.sh: freshness-judgement jq produced no output — the ledger has an unexpected shape" >&2
  exit 6
fi

VERDICT="$(printf '%s' "$GATE_JSON" | jq -r '.verdict')"
ACCEPTED_COUNT="$(printf '%s' "$GATE_JSON" | jq -r '.accepted_count')"
OVERDUE_N="$(printf '%s' "$GATE_JSON" | jq -r '.overdue | length')"
ANOM_N="$(printf '%s' "$GATE_JSON" | jq -r '.anomalies | length')"
# detail strings (overdue + anomalies are ALWAYS enumerated, even under an anomalous headline — nothing hidden)
OVERDUE_STR="$(printf '%s' "$GATE_JSON" | jq -r '.overdue | map("\(.id) (\(.age_days)d old > \(.cadence_days)d cadence)") | join("; ")')"
ANOM_STR="$(printf '%s' "$GATE_JSON" | jq -r '.anomalies | map("\(.id): \(.reason)") | join("; ")')"

# ---- STEP 3 — emit the verdict (a durable line for the sustain log) --------------------------------------
TS_NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [ "$MODE" = "json" ]; then
  JSON_OUT="$(printf '%s\n' "$GATE_JSON" | jq -c --arg now "$TS_NOW" --argjson defdays "$DEFAULT_DAYS" \
    '. + {observed_at:$now, default_days:$defdays}')" || { echo "nsf1-staleness-gate.sh: --json merge jq failed" >&2; exit 6; }
  [ -n "$JSON_OUT" ] || { echo "nsf1-staleness-gate.sh: --json merge produced empty output" >&2; exit 6; }
  printf '%s\n' "$JSON_OUT"
else
  case "$VERDICT" in
    fresh_intent)
      echo "INTENT STALENESS: fresh_intent — all $ACCEPTED_COUNT accepted promise(s) re-confirmed within their acceptance cadence. Safe to consume." ;;
    stale_intent)
      echo "INTENT STALENESS: stale_intent — $OVERDUE_N accepted promise(s) overdue for re-confirmation: $OVERDUE_STR. A stale promise sits accepted + in_sync while nobody asks if it is still wanted (D04 §6.5/A.11). The owner must re-confirm or supersede; this consumption event does NOT count clean until then." ;;
    anomalous)
      echo "INTENT STALENESS: anomalous — $ANOM_N accepted record(s) cannot be trustworthily aged: $ANOM_STR. Coverage says accepted; the timestamp or cadence denies it. Investigate before consuming.$( [ "$OVERDUE_N" -gt 0 ] && printf ' Also overdue: %s.' "$OVERDUE_STR" )" ;;
    no_accepted_intent)
      echo "INTENT STALENESS: no_accepted_intent — the ledger has records but ZERO are status=accepted. Nothing live to age (reporting fresh over an empty check would be laundering). Author or accept an intent before opening the sustain window." ;;
    *)
      echo "INTENT STALENESS: $VERDICT" ;;
  esac
fi

case "$VERDICT" in
  fresh_intent)        exit 0 ;;
  stale_intent)        exit 1 ;;
  anomalous)           exit 3 ;;
  no_accepted_intent)  exit 4 ;;
  *)                   exit 6 ;;
esac
