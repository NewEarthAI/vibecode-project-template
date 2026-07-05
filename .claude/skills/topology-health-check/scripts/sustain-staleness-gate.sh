#!/usr/bin/env bash
# sustain-staleness-gate.sh — the M5 30-day-sustain freshness gate (Reliability NON-SHIPPABLE #1).
#
# WHY THIS EXISTS: the topology substrate is gitignored EPHEMERAL state. Between weekly sustain
# consumption events there is NO loud signal that an entity's emitters silently stopped. If they do,
# the map goes stale and the reconcile skill compares against an old snapshot — the §8.1 theatre-of-trust
# failure (the sustain reads green over a stale map). The reconcile skill's own freshness precondition
# guards PER INVARIANT PAIR at compute time; THIS gate guards the WHOLE MAP at consumption time, BEFORE
# any check runs, and emits a durable verdict line for the sustain log so Test C is verifiable.
#
# CONTRACT: READ-ONLY. Reads the frozen substrate via the frozen `read-topology` helper. NEVER writes the
# substrate. NEVER runs an emitter. Emits a single verdict (fresh_substrate | stale_substrate |
# uninitialised | corrupt | anomalous) + a machine-readable --json line.
#
# FRESHNESS RULE (strict — oldest COVERED emitter wins):
#   - Only emitters with coverage == "covered" are age-checked. A `covered` emitter is one that HAS run
#     and is therefore expected to STAY fresh; if it silently dies, that is the failure we catch.
#   - `declared-missing` / `absent` / `degenerate` emitters are SKIPPED — they are correctly not-run
#     (degenerate stack: your project has no n8n/TS), NOT stale-after-running. Skipping them is what makes the
#     gate correct on a degenerate entity instead of false-flagging it stale. (Doctrine 05 Appendix D.)
#   - The map is `fresh_substrate` IFF every covered emitter's last_emitted_at is within the window.
#     The OLDEST covered emitter decides the verdict — one silently-dead scanner flags the whole map.
#   - A `covered` emitter with a null/unparseable last_emitted_at is an ANOMALY (`covered_no_timestamp`)
#     — the symmetric cousin of the M3-S6 `owned_but_uncovered` bug: coverage claims run, timestamp denies
#     it. Anomaly is NOT silently treated as fresh.
#   - ZERO covered emitters → `uninitialised`-class (nothing has run; not a freshness pass).
#
# Window: hours; default 168 (7 days) — matches the reconcile skill's STALE_WINDOW default so the two
# guards agree. Override via TOPOLOGY_SUSTAIN_STALE_H. Sustain cadence is weekly, so 7d is the natural
# "a week was missed" threshold.
#
# bash 3.2 + jq 1.7 portable. macOS-safe: NOW from `date -u +%s`; ALL ISO-8601 parsing via jq
# fromdateiso8601 — NEVER GNU `date -d` (absent on macOS).
#
# Exit codes: 0 fresh · 1 stale · 3 anomalous · 4 uninitialised · 6 corrupt/jq-missing/helper-missing · 2 usage.

set -u

# ---- resolve paths (mirror reconcile.sh §29-33) ----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUB="$SKILL_DIR/../topology-substrate/scripts/substrate.sh"

MODE="text"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) MODE="json"; shift ;;
    *) echo "sustain-staleness-gate.sh: unknown argument '$1' (usage: sustain-staleness-gate.sh [--json])" >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "sustain-staleness-gate.sh: jq not found" >&2; exit 6; }
[ -f "$SUB" ] || { echo "sustain-staleness-gate.sh: substrate helper not found at $SUB" >&2; exit 6; }

# ---- staleness window (hours), digits-only normalised (a malformed override falls back, never crashes) ----
STALE_WINDOW_H="${TOPOLOGY_SUSTAIN_STALE_H:-168}"
STALE_WINDOW_H="$(printf '%s' "$STALE_WINDOW_H" | tr -dc '0-9' | head -c 6)"; STALE_WINDOW_H="${STALE_WINDOW_H:-168}"

NOW_EPOCH="$(date -u +%s)"   # macOS-safe; jq does ISO-8601 parsing via fromdateiso8601.

# ---- STEP 1 — read the substrate (rc 4 → uninitialised, rc 6/empty → corrupt). Mirrors reconcile.sh. -----
SUBSTRATE_JSON=""
SUBSTRATE_JSON="$(bash "$SUB" read-topology '.' 2>/dev/null)"; READ_RC=$?
if [ "$READ_RC" -eq 4 ]; then
  if [ "$MODE" = "json" ]; then
    printf '{"verdict":"uninitialised","window_hours":%s,"covered_emitters":0,"detail":"substrate not initialised — run init + emitters before the sustain window opens"}\n' "$STALE_WINDOW_H"
  else
    echo "STALENESS GATE: uninitialised — the substrate has not been initialised. Run init + the entity's emitters before opening the sustain window."
  fi
  exit 4
fi
if [ "$READ_RC" -ne 0 ] || [ -z "$SUBSTRATE_JSON" ] || ! printf '%s' "$SUBSTRATE_JSON" | jq -e . >/dev/null 2>&1; then
  if [ "$MODE" = "json" ]; then
    printf '{"verdict":"corrupt","window_hours":%s,"detail":"read-topology returned rc=%s or non-JSON — the substrate is corrupt or unreadable"}\n' "$STALE_WINDOW_H" "$READ_RC"
  else
    echo "STALENESS GATE: corrupt — read-topology returned rc=$READ_RC or non-JSON. The substrate is corrupt; do NOT consume against it."
  fi
  exit 6
fi
# .emitters TYPE guard (code-council CRITICAL): the JSON-validity check above confirms the substrate parses,
# but `( .emitters // {} )` in the jq pass only falls back on null/false — a JSON ARRAY would slip through and
# be judged on its array contents as if a valid emitter map (a silent-pass on a schema-violated substrate).
# .emitters MUST be an object (or absent → treated as {} = uninitialised, which is benign + correct).
EMITTERS_TYPE="$(printf '%s' "$SUBSTRATE_JSON" | jq -r '(.emitters // null) | type' 2>/dev/null)"
if [ "$EMITTERS_TYPE" != "object" ] && [ "$EMITTERS_TYPE" != "null" ]; then
  if [ "$MODE" = "json" ]; then
    printf '{"verdict":"corrupt","window_hours":%s,"detail":"substrate .emitters is type %s, expected object — schema violation"}\n' "$STALE_WINDOW_H" "$EMITTERS_TYPE"
  else
    echo "STALENESS GATE: corrupt — the substrate's .emitters is a $EMITTERS_TYPE, not an object. Schema violation; do NOT consume against it."
  fi
  exit 6
fi

# ---- STEP 2 — judge freshness in ONE jq pass (oldest covered emitter wins; skip non-covered) -------------
# Output: a compact JSON object the bash layer reads back for the verdict + the human/JSON rendering.
GATE_JSON="$(printf '%s' "$SUBSTRATE_JSON" | jq -c \
  --argjson nowep "$NOW_EPOCH" \
  --argjson window "$STALE_WINDOW_H" '
  # epoch of an ISO-8601 string, or null if missing/unparseable (NEVER GNU date -d).
  def tsepoch($s): (try (($s // "") | fromdateiso8601) catch null);
  ( .emitters // {} ) as $em
  # only COVERED emitters are age-checked; non-covered are correctly not-run (degenerate/declared-missing).
  | [ $em | to_entries[] | select(.value.coverage == "covered") ] as $covered
  | [ $covered[] | { name:.key, ep: tsepoch(.value.last_emitted_at), raw:.value.last_emitted_at } ] as $aged
  # ANOMALY = a covered emitter with EITHER a null/unparseable timestamp (coverage says ran, heartbeat denies)
  # OR a FUTURE-dated timestamp (clock-skew / corrupt — a negative age would otherwise read as within-window
  # = a silent fresh pass; mirrors the health-check future_dated anomaly class). Both are untrustworthy.
  | [ $aged[] | select(.ep == null or (.ep != null and .ep > $nowep)) | .name ] as $anomalies
  | [ $aged[] | select(.ep != null and .ep <= $nowep) | { name, age_seconds: ($nowep - .ep) } ] as $valid
  | ($valid | map(.age_seconds) | max) as $oldest_age
  | ($valid | sort_by(-.age_seconds) | .[0]) as $oldest
  | ($window * 3600) as $window_seconds
  | {
      covered_count: ($covered | length),
      anomalies: $anomalies,
      oldest_emitter: ($oldest.name // null),
      oldest_age_seconds: ($oldest_age // null),
      window_seconds: $window_seconds,
      verdict:
        ( if ($covered | length) == 0 then "uninitialised"
          elif ($anomalies | length) > 0 then "anomalous"
          elif $oldest_age == null then "anomalous"           # all covered emitters unparseable
          elif $oldest_age > $window_seconds then "stale_substrate"
          else "fresh_substrate" end )
    }')"
# Guard the piped jq (shell-portability §1 — a pipe eats $?): if the freshness-judgement jq errored, GATE_JSON
# is empty. Fail LOUD with exit 6 rather than letting an empty verdict flow into a misleading blank output.
if [ -z "$GATE_JSON" ]; then
  echo "sustain-staleness-gate.sh: freshness-judgement jq produced no output — the substrate has an unexpected shape" >&2
  exit 6
fi

VERDICT="$(printf '%s' "$GATE_JSON" | jq -r '.verdict')"
OLDEST_EMITTER="$(printf '%s' "$GATE_JSON" | jq -r '.oldest_emitter // "—"')"
COVERED_COUNT="$(printf '%s' "$GATE_JSON" | jq -r '.covered_count')"
ANOMALIES="$(printf '%s' "$GATE_JSON" | jq -r '.anomalies | join(", ")')"
# age in whole hours for the human line (jq does the arithmetic; bash 3.2 has no float).
OLDEST_AGE_H="$(printf '%s' "$GATE_JSON" | jq -r '((.oldest_age_seconds // 0) / 3600) | floor')"

# ---- STEP 3 — emit the verdict (a durable line for the sustain log) --------------------------------------
TS_NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [ "$MODE" = "json" ]; then
  # stamp the observation time so the sustain log line is self-dating. Guard the pipe (§1): a jq failure here
  # must NOT print a blank line that a consuming session writes as a corrupt sustain-log row — fail loud.
  JSON_OUT="$(printf '%s\n' "$GATE_JSON" | jq -c --arg now "$TS_NOW" --argjson window "$STALE_WINDOW_H" \
    '. + {observed_at:$now, window_hours:$window}')" || { echo "sustain-staleness-gate.sh: --json merge jq failed" >&2; exit 6; }
  [ -n "$JSON_OUT" ] || { echo "sustain-staleness-gate.sh: --json merge produced empty output" >&2; exit 6; }
  printf '%s\n' "$JSON_OUT"
else
  case "$VERDICT" in
    fresh_substrate)
      echo "STALENESS GATE: fresh_substrate — all $COVERED_COUNT covered scanner(s) ran within ${STALE_WINDOW_H}h (oldest: $OLDEST_EMITTER, ${OLDEST_AGE_H}h ago). Safe to consume." ;;
    stale_substrate)
      echo "STALENESS GATE: stale_substrate — '$OLDEST_EMITTER' last ran ${OLDEST_AGE_H}h ago, beyond the ${STALE_WINDOW_H}h window. The map is STALE; re-run the emitters before consuming, or this consumption event does NOT count toward the sustain." ;;
    anomalous)
      echo "STALENESS GATE: anomalous — covered scanner(s) [$ANOMALIES] claim 'covered' but carry no usable timestamp. Coverage and heartbeat disagree; investigate before consuming (the symmetric cousin of owned_but_uncovered)." ;;
    uninitialised)
      echo "STALENESS GATE: uninitialised — zero covered scanners. Nothing has run; run the entity's emitters before opening the sustain window." ;;
    *)
      echo "STALENESS GATE: $VERDICT" ;;
  esac
fi

case "$VERDICT" in
  fresh_substrate) exit 0 ;;
  stale_substrate) exit 1 ;;
  anomalous)       exit 3 ;;
  uninitialised)   exit 4 ;;
  *)               exit 6 ;;
esac
