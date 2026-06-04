---
name: topology-health-check
description: |
  The operator-facing READ layer for the topology substrate — the "front door" that answers, in
  seconds, what the topology map covers, how fresh each emitter is, what's missing, and whether the
  graph is internally coherent. Composes the FROZEN substrate helpers (read-topology + validate-schema)
  — read-only, NEVER writes to the substrate. Adds the judgment layer the raw `/topology status` lacks:
  configurable per-emitter staleness thresholds, a 4-way coverage report (covered / absent / degenerate /
  declared-missing, each distinct), per-kind node counts across the frozen 10-kind enum, an integrity
  relay (composes validate-schema, never re-implements orphan/dangling detection), anomaly flags
  (covered-but-empty, future-dated timestamp, unparseable timestamp), and a single compound freshness
  verdict. Plain-English chat output + a machine-readable `--json` mode for /setup wiring + integration
  assertion. The read-interface DESTINATION Test A queries first.
  Use when: an operator (human or AI) wants to see a project's topology coverage + freshness at a glance;
  "/topology health", "is my topology fresh", "what does the map cover", "what's missing from the
  topology", "topology health-check", "show me my whole system", AND/OR as the /setup "is the mechanism
  wired correctly?" confirmation, AND/OR as the integration test's read-surface assertion.
  Do NOT use for: WRITING the topology (that is the 4 emitters); editing the substrate (Session-1
  contract FROZEN — compose, do not reimplement); computing reconciliation / cloud-vs-repo drift (M4
  scope — Doctrine 06); per-emitter live runs (drive the emitter skills directly); editing the substrate
  code or the doctrines (all frozen).
allowed-tools: Bash, Read
user-invocable: true
version: 1.0
classification: capability-uplift
created: 2026-06-01
last_verified: 2026-06-01
programme: intent-actual-gap-mechanism
programme_session: M3-session-6-health-check-integration
schema_authority: ../topology-substrate/references/canonical-shape.md
---

# Topology Health-Check — the operator-facing READ layer (the front door)

> **Programme**: Intent-Actual-Gap Mechanism Build Programme, M3 Session 6 of ~6 (the FINAL M3 session
> — this CLOSES M3, the topology mechanism, part 1 of 3). Sessions 1 (substrate) + 2-5 (4 emitters) built
> the WRITE surface + the mappers. This builds the READ layer + the v1-complete proof.
>
> **The schema authority is FROZEN**: 📄 `../topology-substrate/references/canonical-shape.md`. This skill
> READS the substrate via the substrate skill's two frozen read helpers; it never writes, never edits the
> substrate code, never extends the schema. It is pure read-only judgment on top of proven primitives.

## What this is

`/topology status` (the existing command) relays the raw substrate JSON in plain English. This skill is the
**opinionated verdict layer** on top: it answers "is my topology healthy, fresh, and coherent — and if not,
exactly what do I run to fix it?" It is the front door for BOTH mechanism entry points — a fresh `/setup`
("is the mechanism wired correctly?") and a drop-in on an established huge codebase ("show me my whole
system"). It is what DESTINATION Test A's fresh session queries first.

## What it composes (FROZEN — never reimplements)

```bash
SUB=".claude/skills/topology-substrate/scripts/substrate.sh"
bash "$SUB" read-topology '<jq-filter>'   # the substrate, sliced. rc 4 = not-init'd; rc 6 = corrupt (self-validates before serving).
bash "$SUB" validate-schema               # PASS (rc 0) or a violation list (rc 6) — the FROZEN integrity engine.
```

- **ALL node data is read through `read-topology`** — never a direct `jq` against the substrate file. A
  direct read would bypass the substrate's read-path validation (it self-validates before serving). This is
  load-bearing: a hand-edited substrate with an invalid kind is caught only because `read-topology` validates.
- **Integrity is `validate-schema`** — the health-check relays its PASS / violation list. It NEVER hand-rolls
  orphan / dangling / map-drift detection (the frozen engine already re-derives the maps + checks edge
  endpoints). The health-check's job is to surface that verdict in plain English.

## How a run works (the read + judgment)

A run is `bash scripts/health-check.sh [--json]`. It:

1. **Reads the substrate** via `read-topology` (rc 4 → `UNINITIALISED` verdict + offer init; rc 6 → `CORRUPT`
   verdict + the violation summary). One read of the full envelope + slices.
2. **Coverage report** — for each of the 3 named emitters (`code`, `supabase-live`, `n8n-cloud`), the 4-way
   coverage label with DISTINCT plain-English meaning:
   - `covered` — the emitter ran and found readable source.
   - `absent` — the source type does not exist at this entity (e.g. an entity with no n8n).
   - `degenerate` — the source exists but is unreadable (access missing).
   - `declared-missing` — **the emitter is built but has not yet run on THIS substrate** (run it to populate).
     NOT a failure; NOT "not yet built". The substrate is ephemeral — a prior run's coverage is reset by
     `init`; `declared-missing` is the honest current-substrate state, and an emitter may have proven coverage
     in a prior session (cite its eval for the demonstrated capability).
   Plus the 5 `missing_emitters` markers (M4+ scope) listed honestly.
3. **Staleness** — per-emitter age = `now − last_emitted_at`, compared to a configurable threshold (defaults
   §4.3 below). **The age maths is jq-only** (`date -u +%s` for the now-epoch integer + `$ts | fromdateiso8601`
   in jq — NEVER `date -d`, which is GNU-only and FAILS on macOS bash 3.2). A breach (`age > threshold`,
   strictly greater) → `STALE — re-emit {emitter}`.
4. **Per-kind counts** — one `read-topology` slice grouped by `.kind` over the frozen 10-kind enum
   (`table view function trigger rls_policy edge_function workflow workflow_node ts_module config`).
   Size-agnostic (works on a 10× substrate).
5. **Anomaly flags** (the failure-visibility guards — a health-check that silently misreports is the worst
   outcome):
   - **covered-but-empty** — a `covered` emitter owning 0 nodes → `ANOMALOUS: emitter covered but owns 0 nodes
     — re-emit to repair`. NEVER FRESH. (A crashed emitter marked covered before writing passes validate-schema
     on an empty `nodes:[]`.)
   - **owned-but-uncovered** (the INVERSE) — an emitter owning >0 nodes whose coverage is `declared-missing` /
     `absent` → `ANOMALOUS: emitter owns N nodes but coverage says not-run`. This is the
     crash-after-`bulk-write`-before-`mark-emitter-ran` case — it must NOT be reported as "not yet run / all
     clear" (the exact crash this surface exists to catch).
   - **future-dated** — `now − last_emitted_at < 0` → `ANOMALOUS: timestamp in the future (clock skew?) —
     treat as stale`. NEVER false-FRESH.
   - **unparseable** — `fromdateiso8601` aborts on a non-strict timestamp (millisecond / offset form) →
     `TIMESTAMP_UNPARSEABLE — staleness cannot be computed for {emitter}` (wrapped `try … catch`), never a
     silent skip and never a false-CORRUPT.
   - **named-emitter-missing** — a hand-edited `emitters:{}` passes validate-schema → warn if any of the 3
     named emitters is absent.
6. **Integrity** — `validate-schema` → relay PASS or the violation list (plain English).
7. **Freshness verdict** — a single COMPOUND top-line verdict (STALE + PARTIAL can coexist — the live state
   in 24h):
   - `FRESH` — ≥1 emitter covered with ≥1 owned node, all run emitters within threshold, validate PASS, no anomalies.
   - `STALE — re-emit {list}` — ≥1 run emitter past threshold.
   - `PARTIAL — {n} of {m} emitters not yet run` — ≥1 emitter declared-missing (honest, NOT a failure).
   - **STALE + PARTIAL render BOTH** when both hold: `STALE — re-emit {list}; PARTIAL — {n} of {m} not yet run`.
   - `ANOMALOUS — {summary}` — a covered-but-empty / future-dated / unparseable / named-missing flag fired.
   - `CORRUPT — {violation summary}` — validate-schema failed (surfaced loudest).
   - `UNINITIALISED — run init + the emitters` — substrate rc 4.

## Staleness thresholds (§4.3 — first-class, configurable)

Defaults (per spec 14 §4.3 — code re-emit on commit, supabase tolerant, n8n cloud tighter):

| Emitter | Default threshold | Rationale |
|---|---|---|
| `code` | 24h | re-emit on commit; a day-old code map is suspect |
| `supabase-live` | 168h (7d) | a DB catalogue changes slowly; tolerant |
| `n8n-cloud` | 24h | live cloud workflows change often; tighter |

Override via env vars `TOPOLOGY_STALE_CODE_H`, `TOPOLOGY_STALE_SUPABASE_H`, `TOPOLOGY_STALE_N8N_H` (hours).
A default is applied to any emitter not in the table (24h). A malformed override (non-numeric) falls back to
the default without crashing (the digits-only normaliser). Tuning is v1.1.

**Integrity is read once, not twice.** `read-topology` self-validates before serving (it refuses to hand back
a corrupt substrate — rc 6 → the `CORRUPT` verdict). So once the read succeeds, the substrate is already known
valid and the health-check records `integrity: PASS` without a second full-file validation pass (a wasted parse
on a large substrate). Set `TOPOLOGY_HC_DOUBLE_VALIDATE=1` to force the belt-and-braces second `validate-schema`
call (paranoia / debugging only).

## The `--json` schema (DEFINED before implementation — integration test asserts via `jq -e`, not grep)

```json
{
  "verdict": "FRESH | STALE | PARTIAL | STALE_AND_PARTIAL | ANOMALOUS | CORRUPT | UNINITIALISED",
  "conditions": ["stale", "partial", "anomalous", ...],
  "entity": "<entity>",
  "last_updated": "<ISO 8601 | null>",
  "node_total": <int>,
  "kind_counts": { "<kind>": <int>, ... },
  "emitters": {
    "<name>": {
      "coverage": "covered | absent | degenerate | declared-missing",
      "last_emitted_at": "<ISO 8601 | null>",
      "age_hours": <number | null>,
      "threshold_hours": <int>,
      "stale": <bool>,
      "owned_node_count": <int>,
      "anomaly": "none | covered_but_empty | owned_but_uncovered | future_dated | unparseable_timestamp"
    }, ...
  },
  "missing_emitters": [ { "name": "...", "reason": "..." }, ... ],
  "named_emitters_present": <bool>,
  "integrity": "PASS | CORRUPT | UNKNOWN",
  "integrity_detail": "<violation summary | empty>"
}
```

The `verdict` is a single canonical string; `STALE_AND_PARTIAL` is the compound case. `verdict` is
**authoritative**; `conditions` is the supplementary multi-signal list (it can be empty on a non-FRESH
verdict — branch on `verdict` first). Verdict assertions use `jq -e '.verdict == "X"'` (exact), never grep.

**Anomaly values** (each routes the verdict to `ANOMALOUS`): `covered_but_empty` (coverage says covered but
the emitter owns 0 nodes — likely crashed before writing); `owned_but_uncovered` (the INVERSE — the emitter
owns nodes but coverage says declared-missing/absent — likely crashed after `bulk-write`, before
`mark-emitter-ran`); `future_dated` (timestamp in the future, clock skew); `unparseable_timestamp`
(timestamp not strict ISO-8601, staleness uncomputable).

**Early-exit shape note** (load-bearing for `/setup` consumers): on `UNINITIALISED` and `CORRUPT` verdicts,
`emitters` and `kind_counts` are `{}`, `node_total` is `0`, `last_updated`/`entity` are `null`, and
`integrity` is `UNKNOWN` (uninitialised — integrity cannot be assessed) or `CORRUPT`. The TOP-LEVEL keys are
identical across all paths, but consumers MUST branch on `.verdict` (or `.conditions`) BEFORE indexing
`.emitters.<name>` — a `jq -e '.emitters.code'` returns `null` on a fresh/corrupt substrate (the most common
`/setup` first-run state), which is correct behaviour, not a failure.

## Output (chat surface — layman voice; internals technical)

Line 1 is the freshness verdict. Then per-emitter coverage + staleness, then per-kind counts, then the
integrity verdict, then any anomaly flags. Entity-agnostic (reads the `emitters` block dynamically; no
hard-coded entity name) and size-agnostic.

## Read-only invariants (verified by the eval + code-council)

- NEVER calls `write-node` / `write-edge` / `bulk-write` / `mark-emitter-ran` / `init`.
- NEVER writes to the substrate. The only substrate subcommands it invokes are `read-topology` and
  (optionally, behind the double-validate knob) `validate-schema` — both read-only.
- Zero direct file reads of the substrate (all through `read-topology`, which validates before serving).

## Exit codes

The script's exit code reports SCRIPT health, not substrate state. EVERY substrate state — including
not-found and corrupt — is a successful health-check RUN (rc 0) whose *verdict string* carries the signal.

| rc | meaning |
|----|---------|
| 0 | the health-check ran. The verdict may be ANY value — FRESH / STALE / PARTIAL / STALE_AND_PARTIAL / ANOMALOUS / **CORRUPT** / **UNINITIALISED**. A corrupt or absent substrate is a successful *report*, not a script failure. |
| 2 | usage error (unknown argument) |
| 6 | genuine script-execution failure — `jq` not found, the substrate helper script absent, or the jq transform produced no output. NOT "substrate corrupt" (that is the `CORRUPT` verdict at rc 0). |

Note: the substrate helper's own rc 4 (not-found) and rc 6 (corrupt) are CONSUMED internally and mapped to
the `UNINITIALISED` / `CORRUPT` verdicts at rc 0 — they are never propagated as the health-check's exit code.
Branch on the verdict string, not the exit code, to read substrate state.

## The sustain-staleness gate (M5 — the 30-day sustain freshness guard)

`scripts/sustain-staleness-gate.sh [--json]` is a sibling READ-ONLY check, added in M5 (Path B+), that
answers a narrower question than the full health-check: **"is the whole map fresh enough to trust at THIS
weekly consumption event, before any drift-check runs?"** It exists because the substrate is gitignored
ephemeral state — between weekly sustain consumptions there is no loud signal that an entity's emitters
silently stopped. If they do, the map goes stale and `/topology reconcile` would compare against an old
snapshot (the §8.1 theatre-of-trust failure — the sustain reads green over a stale map). The reconcile
skill's own freshness precondition guards PER INVARIANT PAIR at compute time; THIS gate guards the WHOLE
MAP at consumption time and emits a durable verdict line for the per-entity sustain log.

Freshness rule (strict — oldest COVERED emitter wins): only `covered` emitters are age-checked (a covered
emitter has run and is expected to stay fresh); `declared-missing` / `absent` / `degenerate` emitters are
SKIPPED (correctly not-run on a degenerate stack like Nirvana — skipping them is what stops the gate
false-flagging a degenerate entity as stale). The map is `fresh_substrate` iff every covered emitter ran
within the window (default 168h / 7d, override `TOPOLOGY_SUSTAIN_STALE_H`); the OLDEST covered emitter
decides — one silently-dead scanner flags the whole map. A `covered` emitter with a null/unparseable
timestamp is `anomalous` (the symmetric cousin of the M3-S6 `owned_but_uncovered` bug — coverage claims
run, heartbeat denies it). Verdict ∈ `fresh_substrate` / `stale_substrate` / `anomalous` / `uninitialised`
/ `corrupt`.

Unlike the health-check, this gate's EXIT CODE is meaningful (it is a gate, meant to be branched on in a
consumption protocol): `0` fresh · `1` stale · `3` anomalous · `4` uninitialised · `6` corrupt/jq-or-helper-missing
· `2` usage. The `--json` line is the row source for the sustain log (`_shared/sustain-log-schema.md`).
Verified: `evals/sustain-staleness-gate.sh` (10 assertions — fresh / stale / oldest-wins / the degenerate
case reads fresh / anomaly / mixed-anomaly / zero-covered / uninitialised / corrupt / window-boundary).

## Propagation (entity-agnostic by construction)

The health-check hard-codes no entity name, no credential, no path beyond the substrate skill's helper. It
reads whatever the emitters wrote. `/push-to-template` propagates it alongside the substrate + the 4 emitters;
a downstream entity runs `/topology health` after its emitters populate. The `/setup` wiring (the health-check
as the "is the mechanism wired correctly?" confirmation) is an M5 propagation step — the output is DESIGNED for
that wiring now (honest-about-partial + entity-agnostic + size-agnostic).

## Verification record

- Eval: `evals/canonical-shape.sh` (exact-count fixture: known per-kind counts + a staled emitter at a
  specific past timestamp + a covered-but-empty emitter + a declared-missing slot + the boundary case +
  a future-dated case + an unparseable-timestamp case + a corrupt substrate; asserts via `jq -e` exact).
- Integration test: `evals/integration.sh` (the v1-complete proof — repo-config-emitter + pre-seeded
  ts_module stubs → validate PASS → health-check honest report → live-substrate structured assertion →
  UA license-attribution + no-Python grep → real-substrate isolation assert). It tracks whether the live
  assertion ran; on a machine without the BuyBox-AI substrate it prints "FIXTURE PROOF" not "v1-COMPLETE",
  so a green on a propagated/CI machine is not mistaken for the full live proof.
- Live-MCP emitter capability (the supabase-live + n8n-cloud paths the in-repo integration test does NOT
  re-run) is proven separately at the S2 supabase-live eval (1,143 nodes) + S3 n8n-cloud eval (280 nodes +
  524 edges) — see those skills' `evals/canonical-shape.sh`. The integration test defers their heavy live
  re-runs on-demand (DECISION-1 Option A) and cites these as the coverage evidence.
- Council: `council/sessions/2026-06-01-m3-session-6-health-check-integration.md` (8 agents, 13 amendments).
- Code-council: `council/code-reviews/2026-06-01-m3-session-6-health-check.md` (9 agents, BLOCKING→remediated→PASS).
