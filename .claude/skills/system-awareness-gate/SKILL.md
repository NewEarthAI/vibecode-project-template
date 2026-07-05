---
name: system-awareness-gate
description: The plan-level system-alignment gate — the symmetric twin of the framing-audit gate. Where framing-audit asks "is this the RIGHT question?", this asks "does this plan fit the REAL system?" by surfacing the topology map + ROADMAP + DESTINATION + open goals at plan-time and applying an honest-degradation matrix that never launders an absent/stale/partial/corrupt map into a green light. Use when forming a plan/spec/build against an existing system; auto-fired by the system-awareness-activation hook on plan-class prompts. Invoked as `/topology align`.
---

# System-Awareness Alignment Gate

The activator for the latent topology map: it makes a planning session actually CONSULT the system's real state
at the moment it matters (plan-time), and reports the COVERAGE of that check honestly. Advisory — never blocks.

## The three pieces (a trio, not a pair)

| Piece | File | Role |
|---|---|---|
| Rule | `.claude/rules/system-awareness-mandate.md` | The doctrine (auto-loads on plan-class work) + the honest-degradation principle. |
| Hook | `.claude/hooks/system-awareness-activation.sh` | SessionStart announce + UserPromptSubmit cheap **freshness** snapshot + a directive to auto-run the deep read. Path B (no cache). |
| Read-surface | `scripts/topology-align.sh` (`/topology align`) | The deep read: the four-anchor composition + the R0–R7 honest-degradation matrix. |

Why a trio (not the framing-audit pair): the framing-audit hook is pure-regex-on-prompt (zero file reads); this
gate's payload must READ the substrate. The deterministic honest-degradation matrix needs a home that is encoded,
not left to per-chat judgment — that home is the read-surface. (Spec 17 §1; council 2026-06-06 PROCEED.)

## The honest-degradation matrix (R0–R7) — the anti-theatre core

`/topology align` composes `health-check --json` (map freshness) × `reconcile --json` (open drift) and maps the
cross-product to an honest verdict. **Only R7 (FRESH map + IN_SYNC reconcile) licenses the word "aligned".**

| Rule | Condition | Verdict |
|---|---|---|
| R1 | health UNINITIALISED | `NO_MAP` (FROM-SCRATCH; offer to build) |
| R2 | health CORRUPT | `MAP_CORRUPT` (rc-primary) |
| R3 | health ANOMALOUS (reconcile not DRIFT) | `MAP_ANOMALOUS` (IN_SYNC SUPPRESSED — agreement not reliable) |
| R3b | health ANOMALOUS + reconcile DRIFT | `MAP_ANOMALOUS_DRIFT` (drift real but the map is unreliable; verify the affected emitter before acting) |
| R4 | reconcile degraded (UNINITIALISED/CORRUPT/INCONCLUSIVE/UNVERIFIABLE/no-invariants/null) | `NO_CLAIM` (+ "double-degraded" when health is also stale/partial) |
| R5 | reconcile DRIFT | `DRIFT` (+ named actions; + health staleness prefix) |
| R6 | reconcile PARTIAL, or health stale/partial + reconcile IN_SYNC | `PARTIAL_IN_SYNC` (with concrete coverage ratio) |
| R7 | health FRESH + reconcile IN_SYNC | `ALIGNED` — the sole licensed state |
| R0 | anything else (unknown enum) | `UNEXPECTED` — never "aligned" |

A built-in invariant guard refuses to emit `licensed_aligned:true` on any rule other than R7.

## Dual-mode

- **ESTABLISHED** (substrate exists): full read — map health + open drift + ROADMAP + DESTINATION + goals.
- **FROM-SCRATCH** (`UNINITIALISED`): honest "NO system map yet — checked against written intent only" + a
  build-the-map offer (`/topology` emitters). Never fakes a map.

## Verification

- Read-surface: `bash .claude/skills/system-awareness-gate/evals/matrix.sh` — 30 checks incl. a 72-cell universal
  sweep proving only FRESH×IN_SYNC licenses "aligned". Uses the DI seam (`TOPOLOGY_ALIGN_HEALTH_JSON` +
  `TOPOLOGY_ALIGN_RECONCILE_JSON`) — no live substrate needed.
  - **DI-seam is eval-only.** `TOPOLOGY_ALIGN_HEALTH_JSON` / `TOPOLOGY_ALIGN_RECONCILE_JSON` bypass the live
    reads (a fixture can force any rule, including R7). They exist for the eval and MUST NEVER be set in
    production — a set health/reconcile env var means the verdict is reading a fixture, not the real substrate.
    (`TOPOLOGY_ALIGN_ROADMAP` / `_DESTINATION` / `_GOALS_JSON` are likewise test/propagation overrides only.)
- Hook: `bash .claude/hooks/system-awareness-activation.sh --self-test` — 19 cases (fires on plan-class incl. the
  false-negative corpus restructure/migrate/move-X-to-Y, the slash-command entry points, and the `let's build`
  regex; silent on trivia/skip-listed).

## Composition

- The **symmetric twin** of `framing-audit-mandate.md` + `framing-audit-activation.sh`. Separate hooks
  (independence, per `hook-efficiency.md` §6); both advisory; both fire on plan-class prompts.
- Orthogonal to `/topology reconcile` (live-drift) and the Intent-Actual-Gap programme (plan-level vs live-drift —
  the distinction is load-bearing, per `dont-conflate-inflight-programme.md`).
- Composes — never rebuilds — the topology reads (`topology-health-check`, `topology-reconcile`,
  `topology-substrate`) and `_shared/goals.sh`.

## Receiving-repo setup (after `/update-latest` pulls this gate)

The gate's reads stay INERT until the hook is registered on TWO events the generic hook-install
does NOT cover: **SessionStart** + **UserPromptSubmit**. `/update-latest` Step 5c3 handles this —
it auto-wires the per-machine `settings.local.json` (which an agent IS allowed to write) and then
surfaces the committed `settings.json` block for a human (which an agent is NOT allowed to write).

If wiring by hand, the entry (add to BOTH the `SessionStart` and `UserPromptSubmit` arrays under
`hooks`) is:

```json
{ "matcher": "*", "hooks": [ { "type": "command", "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/system-awareness-activation.sh", "timeout": 10 } ] }
```

Verify after wiring:
- `bash .claude/hooks/system-awareness-activation.sh --self-test` → ALL PASS (19/19)
- `bash .claude/skills/system-awareness-gate/evals/matrix.sh` → ALL PASS (30 checks)

The committed `settings.json` write is agent-blocked by design — so on a fresh pull the gate is
live on the current machine immediately (via `settings.local.json`), and a human enables it
team-wide by pasting the same block into the committed `settings.json` and committing it.

## References

- Spec: `specs/17_SYSTEM_AWARENESS_ALIGNMENT_GATE_PLAN.md`
- Council: `council/sessions/2026-06-06-system-awareness-alignment-gate.md`
- ROADMAP item: `ROADMAP.md` lines 159-169 (System: Operator Leverage)
