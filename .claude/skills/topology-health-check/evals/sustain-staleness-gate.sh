#!/usr/bin/env bash
# Behavioural eval for sustain-staleness-gate.sh — the M5 sustain freshness gate.
# Builds synthetic substrate fixtures (NEVER a fabricated live map), runs the gate against each via a
# fake `read-topology` shim, and asserts the verdict + exit code. bash 3.2 + jq 1.7 portable.
#
# The gate resolves the substrate helper at $SKILL_DIR/../topology-substrate/scripts/substrate.sh and
# calls `read-topology '.'`. We cannot mutate the frozen helper, so each case writes a fixture to a temp
# dir and runs the gate with a SHIM substrate.sh on PATH-resolution: we copy the gate into a temp skill
# tree whose sibling topology-substrate/scripts/substrate.sh is a 3-line shim echoing the fixture.

set -u
PASS=0; FAIL=0
GATE_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/sustain-staleness-gate.sh"
[ -f "$GATE_SRC" ] || { echo "FATAL: gate script not found at $GATE_SRC"; exit 2; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# build a temp skill tree: <work>/health-check/scripts/gate.sh  +  <work>/topology-substrate/scripts/substrate.sh (shim)
mkdir -p "$WORK/health-check/scripts" "$WORK/topology-substrate/scripts"
cp "$GATE_SRC" "$WORK/health-check/scripts/gate.sh"
GATE="$WORK/health-check/scripts/gate.sh"
SHIM="$WORK/topology-substrate/scripts/substrate.sh"

# the shim reads-topology by echoing $FIXTURE (or exits rc 4 if $FIXTURE is the literal "UNINIT").
cat > "$SHIM" <<'SHIM_EOF'
#!/usr/bin/env bash
# test shim — only implements `read-topology`.
if [ "${1:-}" = "read-topology" ]; then
  [ "${FIXTURE:-}" = "UNINIT" ] && exit 4
  [ "${FIXTURE:-}" = "CORRUPT" ] && { printf '%s' "not-json{{{"; exit 0; }
  printf '%s' "${FIXTURE:-}"
  exit 0
fi
exit 2
SHIM_EOF
chmod +x "$SHIM"

# ISO-8601 helpers (macOS-safe: use jq to produce a timestamp N seconds in the past from a known epoch).
# We can't use `date -d`; produce ages by passing explicit ISO strings computed from NOW via jq.
NOW_EP="$(date -u +%s)"
iso_ago() {  # $1 = seconds ago → ISO-8601 UTC
  jq -rn --argjson now "$NOW_EP" --argjson back "$1" '($now - $back) | todateiso8601'
}
FRESH_TS="$(iso_ago 3600)"        # 1h ago — well within 168h
STALE_TS="$(iso_ago $((200*3600)))"  # 200h ago — beyond 168h

run() {  # $1 = test name, $2 = fixture json (or UNINIT/CORRUPT), $3 = expected verdict, $4 = expected rc
  local name="$1" fixture="$2" exp_verdict="$3" exp_rc="$4"
  local out rc
  out="$(FIXTURE="$fixture" bash "$GATE" --json 2>/dev/null)"; rc=$?
  local got_verdict
  got_verdict="$(printf '%s' "$out" | jq -r '.verdict' 2>/dev/null)"
  if [ "$got_verdict" = "$exp_verdict" ] && [ "$rc" -eq "$exp_rc" ]; then
    echo "  PASS  $name → $got_verdict (rc=$rc)"; PASS=$((PASS+1))
  else
    echo "  FAIL  $name → got '$got_verdict' rc=$rc, expected '$exp_verdict' rc=$exp_rc"
    echo "        out: $out"; FAIL=$((FAIL+1))
  fi
}

echo "=== sustain-staleness-gate behavioural eval (window default 168h) ==="

# CASE 1 — fresh: one covered emitter, ran 1h ago → fresh_substrate, rc 0
run "fresh: single covered scanner 1h old" \
  "$(jq -n --arg ts "$FRESH_TS" '{emitters:{code:{last_emitted_at:$ts,coverage:"covered"}}}')" \
  "fresh_substrate" 0

# CASE 2 — stale: one covered emitter, ran 200h ago → stale_substrate, rc 1 (the silent-scanner-death catch)
run "stale: single covered scanner 200h old" \
  "$(jq -n --arg ts "$STALE_TS" '{emitters:{code:{last_emitted_at:$ts,coverage:"covered"}}}')" \
  "stale_substrate" 1

# CASE 3 — oldest-wins: two covered, one fresh one stale → stale_substrate (the OLDEST decides)
run "oldest-wins: fresh + stale covered → stale" \
  "$(jq -n --arg f "$FRESH_TS" --arg s "$STALE_TS" '{emitters:{code:{last_emitted_at:$f,coverage:"covered"},"supabase-live":{last_emitted_at:$s,coverage:"covered"}}}')" \
  "stale_substrate" 1

# CASE 4 — DEGENERATE BUSINESS: one covered+fresh, others declared-missing/absent → fresh (skip non-covered)
#   This is the your project case: n8n/code absent, supabase covered+fresh. Must NOT false-flag stale.
run "degenerate: covered-fresh + declared-missing + absent → fresh (skip non-covered)" \
  "$(jq -n --arg f "$FRESH_TS" '{emitters:{"supabase-live":{last_emitted_at:$f,coverage:"covered"},"n8n-cloud":{last_emitted_at:null,coverage:"declared-missing"},code:{last_emitted_at:null,coverage:"absent"}}}')" \
  "fresh_substrate" 0

# CASE 5 — anomaly: covered but null timestamp → anomalous, rc 3 (coverage claims run, heartbeat denies)
run "anomaly: covered but null last_emitted_at → anomalous" \
  "$(jq -n '{emitters:{code:{last_emitted_at:null,coverage:"covered"}}}')" \
  "anomalous" 3

# CASE 6 — anomaly mixed: one covered-fresh + one covered-null → anomalous (the null covered one wins)
run "anomaly-mixed: covered-fresh + covered-null → anomalous" \
  "$(jq -n --arg f "$FRESH_TS" '{emitters:{code:{last_emitted_at:$f,coverage:"covered"},"supabase-live":{last_emitted_at:null,coverage:"covered"}}}')" \
  "anomalous" 3

# CASE 7 — zero covered: all declared-missing → uninitialised, rc 4 (nothing has run; not a fresh pass)
run "zero-covered: all declared-missing → uninitialised" \
  "$(jq -n '{emitters:{code:{last_emitted_at:null,coverage:"declared-missing"},"supabase-live":{last_emitted_at:null,coverage:"declared-missing"}}}')" \
  "uninitialised" 4

# CASE 8 — substrate not initialised (helper rc 4) → uninitialised, rc 4
run "helper-rc4: substrate uninitialised → uninitialised" "UNINIT" "uninitialised" 4

# CASE 9 — corrupt substrate (non-JSON) → corrupt, rc 6
run "corrupt: helper returns non-JSON → corrupt" "CORRUPT" "corrupt" 6

# CASE 10 — boundary (fresh side): comfortably inside the window (167h, a 1h margin so the few-second gap
# between this fixture's NOW and the gate's NOW cannot tip it over the 168h edge — the edge itself is racy
# by design, so we test NEAR-edge-inside, not on-the-second-edge). Proves the within-window path.
EDGE_TS="$(iso_ago $((167*3600)))"
run "boundary: 167h (1h inside window) → fresh" \
  "$(jq -n --arg ts "$EDGE_TS" '{emitters:{code:{last_emitted_at:$ts,coverage:"covered"}}}')" \
  "fresh_substrate" 0

# CASE 12 — boundary (stale side): comfortably beyond the window (169h, a 1h margin) → stale. Together with
# CASE 10 this brackets the 168h edge from both sides with margin, catching a > vs >= flip without the
# on-the-second race. (The exact-second edge is not asserted — it is inherently racy by the eval/gate NOW gap.)
OVER_TS="$(iso_ago $((169*3600)))"
run "boundary: 169h (1h beyond window) → stale" \
  "$(jq -n --arg ts "$OVER_TS" '{emitters:{code:{last_emitted_at:$ts,coverage:"covered"}}}')" \
  "stale_substrate" 1

# CASE 13 — FUTURE-dated timestamp (clock-skew/corrupt) → anomalous, NOT a silent fresh pass (code-council)
FUTURE_TS="$(jq -rn --argjson now "$NOW_EP" '($now + 86400) | todateiso8601')"  # 1 day in the future
run "future-dated: covered scanner timestamped tomorrow → anomalous (not fresh)" \
  "$(jq -n --arg ts "$FUTURE_TS" '{emitters:{code:{last_emitted_at:$ts,coverage:"covered"}}}')" \
  "anomalous" 3

# CASE 14 — .emitters as a JSON ARRAY (schema violation) → corrupt, NOT judged on array contents (code-council)
run "emitters-array: covered+fresh entry in an ARRAY → corrupt (type guard, not a silent fresh pass)" \
  "$(jq -n --arg f "$FRESH_TS" '{emitters:[{last_emitted_at:$f,coverage:"covered"}]}')" \
  "corrupt" 6

# CASE 15 — .emitters absent entirely → uninitialised (the // {} fallback is benign + correct)
run "emitters-absent: no .emitters key → uninitialised" \
  "$(jq -n '{schema_version:"1",nodes:[]}')" \
  "uninitialised" 4

# CASE 16 — malformed window override (letters) → falls back to 168h, a 1h-old map still fresh
run_with_window() {  # like run() but sets TOPOLOGY_SUSTAIN_STALE_H
  local name="$1" fixture="$2" win="$3" exp_verdict="$4" exp_rc="$5" out rc got
  out="$(FIXTURE="$fixture" TOPOLOGY_SUSTAIN_STALE_H="$win" bash "$GATE" --json 2>/dev/null)"; rc=$?
  got="$(printf '%s' "$out" | jq -r '.verdict' 2>/dev/null)"
  if [ "$got" = "$exp_verdict" ] && [ "$rc" -eq "$exp_rc" ]; then
    echo "  PASS  $name → $got (rc=$rc)"; PASS=$((PASS+1))
  else
    echo "  FAIL  $name → got '$got' rc=$rc, expected '$exp_verdict' rc=$exp_rc"; echo "        out: $out"; FAIL=$((FAIL+1))
  fi
}
run_with_window "window-override-garbage: 'abc' falls back to 168h → 1h-old map fresh" \
  "$(jq -n --arg ts "$FRESH_TS" '{emitters:{code:{last_emitted_at:$ts,coverage:"covered"}}}')" \
  "abc" "fresh_substrate" 0

echo ""
echo "=== sustain-staleness-gate: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && echo "all $PASS assertions green" || echo "FAILURES PRESENT"
[ "$FAIL" -eq 0 ]
