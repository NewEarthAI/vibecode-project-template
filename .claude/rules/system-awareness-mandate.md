# System-Awareness Alignment Mandate

**Auto-loaded on**: any session doing plan-class or build-class work. Detection signals — a
`/plan`, `/autovibe`, `/prompt-forge`, `/build-with-agent-team`, plan-mode entry, or any chat
forming a spec / architecture / build proposal (build, add, implement, design, restructure,
migrate, "should we build/change X"). This rule sits in `.claude/rules/` and loads under the
same contextual mechanism as the sibling programme rules (`framing-audit-mandate.md`,
`doctrine-verification-gate.md`).

**Every-session announcement**: the mandate itself is announced in EVERY session —
unconditionally, regardless of topic — by `.claude/hooks/system-awareness-activation.sh`
(SessionStart component), which injects the system-awareness banner at session start. The same
hook, on a plan-class prompt, injects a cheap **map-freshness snapshot** + a directive to run
the deep read (`/topology align`). This is the announce-vs-run split: the hook *announces* the
mandate every session and points here; this rule is the full doctrine, loaded contextually when
plan-class work is in play. Rule + hook + the `/topology align` read-surface are the three
pieces of the System-Awareness Alignment Gate.

**Origin**: OPERATOR-REQUESTED 2026-06-05. Spec: `specs/17_SYSTEM_AWARENESS_ALIGNMENT_GATE_PLAN.md`.
Council (8 lenses, ADVISORY → amended): `council/sessions/2026-06-06-system-awareness-alignment-gate.md`.
The **symmetric twin** of `framing-audit-mandate.md`.

---

## The principle

A **system-awareness alignment check** — confirming a plan fits *what the system actually IS,
where it is headed, and what has been committed* before the plan locks — is **compulsory before
any load-bearing plan or build**. The framing-audit gate guards the other half of the loop: it
asks *"is this the RIGHT question?"* (framing soundness). This gate asks *"does this plan fit the
REAL system?"* (structural alignment). A plan can be perfectly framed and still build **blind** —
against a system whose actual structure the chat never consulted, off the ROADMAP, or
contradicting what `DESTINATION.md` committed to.

The topology map (the machine-readable system blueprint) is the AI's queryable source-of-truth
for *what the system actually is*. Its value is **latent** until something makes a chat consult
it at the moment it matters — plan-time. This gate is that activator. A plan-class decision made
without surfacing the system's real state is an incomplete decision.

**Provenance honesty (council A7 / Devil's Advocate)**: unlike the reactive gates in this system
(each built AFTER a named, dated, costly failure), this gate is **speculative prevention** —
operator-requested, with no dated incident of a session building blind against the map. That is a
legitimate but different epistemic status. A lightweight post-propagation adoption check (does it
actually change plans?) is the spec's verification item (`specs/17` §7) so the advisory-vs-blocking
question earns evidence rather than remaining an assumption.

## Announce vs. run — the scope distinction

This rule is *present* in every session — the mandate is **announced** every session. The
alignment check itself **runs** only on plan-class work. A session that fixes a typo, looks up a
fact, or tweaks a setting does NOT run an alignment check; forcing one there is noise, and noise
gets routed around. The mandate is always loaded; the check is conditionally run.

## The honest-degradation principle (the anti-theatre core)

*Honest-partial-coverage-correctly-reported IS the complete behaviour — not a degraded one. A
check that says "alignment checked against a map that covers only the code layer and is 6 days
old; treat as PARTIAL" has succeeded. A check that says "aligned" over that same map has failed
in the exact way the topology-reconcile vacuous-green-light / theatre-of-trust failure class
names — the canonical CRITICAL where a verification tool reported in-sync over a 17-month-old
snapshot. The gate reports the COVERAGE of the check; it never launders absence, staleness,
partiality, corruption, or anomaly into a green light.*

Only ONE state licenses the word "aligned" unqualified: a FRESH map (all emitters covered, within
threshold) AND reconcile IN_SYNC across the registered invariants. Every other state surfaces the
exact coverage gap. The deterministic mapping is the R0–R7 governing-rule matrix in `/topology
align` (`specs/17` §3.3) — it is encoded, not left to per-chat judgment.

## When the alignment check is COMPULSORY

Run it — *before the plan locks* — whenever the work crosses any of these:

| Trigger class | Example | What the gate does |
|---|---|---|
| The start of a multi-phase orchestration | `/plan`, `/autovibe`, `/prompt-forge`, `/build-with-agent-team` | cheap freshness snapshot at prompt-time + the deep read (`/topology align`) on the goal before the phases run |
| A build/change against the existing system | "build X", "add an endpoint", "restructure the auth flow", "migrate the schema", "move X to Y" | the deep read — surface map health + open drift + ROADMAP + DESTINATION + goals |
| A spec / architecture / design proposal | "design the architecture for…", "spec the…" | the deep read, with the honest-degradation matrix applied |
| Plan-mode entry | `EnterPlanMode` | the deep read before the plan is finalised |

A **load-bearing plan** is one that commits to building or changing the system. The check is
**advisory** — it surfaces the alignment state; it never blocks.

## When it does NOT fire (not for trivia)

Skip the check — and the hook stays silent — on: typo fixes, single-line edits, settings tweaks,
factual lookups, pure-empirical questions, and any work with no build/plan attached. The check is
for *plans*, not for *tasks*. Over-applying it is the failure mode that makes the mechanism get
ignored.

## How to apply

1. The hook fires the cheap freshness snapshot on a plan-class prompt; the operator types nothing.
2. **Refresh-when-it-matters:** if the cheap freshness verdict is NOT FRESH (stale / partial /
   uninitialised / corrupt / unreadable), run the project's topology emitters FIRST — the
   model-driven WRITE path — so the align read evaluates a fresh map. The operator types nothing;
   Claude judges + runs it. A FRESH map skips straight to step 3. (Why model-driven, not a silent
   background cron: the emitters need Claude's tools — Supabase / n8n MCP — to collect source;
   there is no model-free runner.) **Complement (2026-06-12): `/autovibe` Phase 4.55 re-emits the
   shipped layers right after every clean ship** (the conversation still holds the MCP access
   there) — so this plan-time gate usually finds FRESH and acts as the safety net, not the
   workhorse.
3. Run the deep read — `/topology align` (Claude auto-invokes it; the operator never types it).
   It is a **named, non-skippable step** for plan-class work.
4. Read the honest verdict. The ONLY "aligned" state is FRESH + IN_SYNC; everything else names the
   coverage gap (no map / corrupt / anomalous / stale / partial / drift / no-claim).
5. On any non-aligned state, **do not assert the plan is system-validated** — surface the gap to
   the operator (absent map → offer to build it; drift → surface the named actions; partial →
   name the uncovered layers). Proceed only with the gap stated.

## The read-surface (cite — never copy the topology skills)

This rule **names** the reads; it never reproduces the topology skills' procedures (inline copies
drift from their source). `/topology align` (`specs/17` §3.3) composes the EXISTING reads:

| Read | Role |
|---|---|
| `topology-health-check/scripts/health-check.sh --json` | map freshness verdict + per-emitter coverage + node counts |
| `topology-reconcile/scripts/reconcile.sh --json` | open drift (count + named actions + affected nodes) — ESTABLISHED mode only |
| `topology-substrate/scripts/substrate.sh validate-schema` | corruption detail (CORRUPT/ANOMALOUS path) — invoked *by* `health-check.sh`, not directly; `/topology align` reads the result via health-check's `.integrity_detail` (two hops) |
| `.claude/skills/_shared/goals.sh list active` | open goals (surfaces the raw `list active` output; the per-goal `read <id> intended_end` is named in the doctrine but not called by the deep read) |
| `ROADMAP.md` NOW lane + `DESTINATION.md` Element 2 | where we are headed + what was committed |

The gate is **READ-ONLY**: it composes these reads, never writes the substrate, never runs an
emitter, never executes a drift action.

## Composition with existing rules

| Rule | How this gate composes |
|---|---|
| `framing-audit-mandate.md` | The symmetric twin. framing-audit asks "is this the RIGHT question?"; this asks "does the plan fit the REAL system?". Both advisory, both fire on plan-class prompts, both never block. **Separate hooks** (per `hook-efficiency.md` §6 — independence); each emits its own bracket-tagged envelope. On a prompt that trips both, the operator sees two one-line items — the intended composition, not noise. This rule cites framing-audit; it never reproduces its primitives. |
| `dont-conflate-inflight-programme.md` | This gate is the **plan-level** alignment twin — orthogonal to `/topology reconcile`'s **live-drift** detection and to the Intent-Actual-Gap programme. The distinction is load-bearing: this prevents a chat building the wrong-fitting thing; reconcile catches the live system having drifted from the saved map. |
| `hook-efficiency.md` | The hook is command-class, narrow-matched, exit-0-always, context-injection-over-blocking. The cheap tier is timeout-bounded and never runs the deep read inline. |
| `doctrine-verification-gate.md` | The eval-per-rule + code-council gate applied to the read-surface (`specs/17` §7). |

## What this rule is NOT

- **Not a blocker.** The hook never halts a tool call; this rule never halts work. It mandates a
  *step*, surfaced for the operator. Work can proceed past a stated gap if the operator accepts it
  — only a *silent* skip (asserting "aligned" without the check, or laundering a degraded map into
  a green light) is forbidden.
- **Not for trivia.** See the not-for-trivia section — over-application kills the mechanism.
- **Not a copy of the topology skills.** It cites; the procedures live in the skill files.
- **Not the live-drift mechanism.** `/topology reconcile` owns live-drift; this gate owns
  plan-level alignment. Do not conflate them.
- **Not retroactive.** Applies forward-only from 2026-06-06.

## When it fails (operate-cost — bus-factor-1)

- Hook not firing on a plan-class prompt → QUIET failure; the `--self-test` (incl. the
  false-negative corpus) is the guard. Re-run `bash .claude/hooks/system-awareness-activation.sh
  --self-test`.
- Cheap freshness read times out / substrate absent → the hook degrades to an honest injected
  message ("system map unreadable / not yet built — running full read"), NEVER a false-green,
  NEVER silent on a plan-class match.
- `/topology align` reads compose health-check + reconcile (both exit 0 always, verdict-carrying);
  a dependency error surfaces as an honest degraded message, never a false "aligned".

## References

- Spec: `specs/17_SYSTEM_AWARENESS_ALIGNMENT_GATE_PLAN.md`
- Council: `council/sessions/2026-06-06-system-awareness-alignment-gate.md`
- The twin: `.claude/rules/framing-audit-mandate.md` + `.claude/hooks/framing-audit-activation.sh`
- The hook: `.claude/hooks/system-awareness-activation.sh`
- The read-surface: `.claude/skills/system-awareness-gate/` (`/topology align` in `.claude/commands/topology.md`)
- The composed reads: `.claude/skills/topology-health-check/`, `.claude/skills/topology-reconcile/`,
  `.claude/skills/topology-substrate/`, `.claude/skills/_shared/goals.sh`
- ROADMAP item: `ROADMAP.md` lines 159-169 (System: Operator Leverage)
