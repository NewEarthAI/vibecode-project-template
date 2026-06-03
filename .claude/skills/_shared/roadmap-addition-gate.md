# Goal-Triggered Roadmap-Addition Gate

**Origin**: Goal-Ledger Build Programme — Session 3 (Stage 4). Spec:
`specs/12_GOAL_LEDGER_BUILD_PROGRAMME.md` §5. Plan: `GOAL-FEATURE-INTEGRATION-PLAN-2026-05-19.md`
§4 Stage 4 + §3.5. Council: `council/sessions/2026-05-19-goal-feature-integration.md` (Q6).

**Composition**: builds nothing new. It composes two existing framing-audit
primitives — `/reduce-to-first-principles` and `/map-feedback-loops` (DECISION
mode). The shell emitter `bash .claude/skills/_shared/goals.sh roadmap-gate "<X>"`
prints this gate's two invocations with the addition interpolated; this document
is the authority for *why*, *when it fires*, and *what each verdict means*.

---

## The principle

`ROADMAP.md` is the single source of truth for what matters (North Star → Systems
→ Projects → Milestones). A goal that cannot map to an existing milestone may
warrant a new roadmap item — but a goal-triggered automatic addition does **not**
go straight into `ROADMAP.md`. It must first clear two checks in sequence. This
is the operator's stated requirement made concrete: **no roadmap addition without
first-principles + systems thinking behind it.**

"100% aligned" here does NOT mean every goal must already exist as a milestone
(that would block legitimate exploratory/infra work — most of this project's
output). It means every goal is *traceably accounted for*: it advances a named
milestone, OR it carries an explicit justification AND proposes an addition that
has passed this gate. No goal drifts unaccounted; no goal silently contradicts
the roadmap.

---

## When this gate fires — and when it does NOT

| Scenario | Gate fires? |
|----------|-------------|
| A goal-ledger entry has no `roadmap_ref`, its work is real, and the session concludes a new roadmap item is warranted to account for it | **YES** — run both steps before writing `ROADMAP.md` |
| An autonomous chain (newvibe/autovibe) programmatically proposes a roadmap addition | **YES** |
| The operator hand-edits `ROADMAP.md` directly (types a new item, reorders, re-scopes) | **NO — EXEMPT** (council Q6: operator-authored edits are exempt) |
| A goal maps cleanly to an existing milestone (`roadmap_ref` set, no addition proposed) | **NO** — nothing is being added |
| Ticking/annotating an existing milestone via the roadmap-writeback contract | **NO** — that is write-back, not addition |

**How to tell operator-authored from goal-triggered**: the addition's *origin*.
If the trigger is a goal/automation concluding "this needs a roadmap item", the
gate fires. If a human is editing `ROADMAP.md` as a deliberate authoring act, it
is exempt — the human IS the judgment the gate would otherwise supply. When
genuinely ambiguous, treat it as goal-triggered (fail safe — running the gate on
an operator edit costs two skill invocations; skipping it on a goal-triggered
addition is the failure this gate exists to prevent).

---

## The two-step gate (run in order; Step 1 is a hard precondition for Step 2)

### Step 1 — first-principles reduction

```
/reduce-to-first-principles
  subject:        "Should we add the following to the roadmap? — <X>"
  input_type:     proposal
  default_action: "write the addition straight into ROADMAP.md without a reduction"
```

| `framing_verdict` | Action |
|-------------------|--------|
| `SOUND` | Proceed to Step 2. |
| `ADDS_CONSTRAINTS` | Proceed to Step 2 **only after** surfacing the added constraints/presuppositions and confirming they are intended. The reframed addition (constraints made explicit) is what enters Step 2. |
| `SMUGGLES_CONCLUSIONS` | **REJECT.** The addition's framing pre-answers the question — typically a duplicate of an existing milestone, or a *means* dressed up as an *end*. Surface the smuggled conclusion. Do **not** write `ROADMAP.md`. Do not run Step 2. |

### Step 2 — second-order projection (only if Step 1 cleared)

```
/map-feedback-loops
  input_mode:           decision
  decision:             "add '<X>' to ROADMAP NOW and commit resources to it"
  target_system:        "<your project> — in: ROADMAP milestones, the goal-ledger, the
                          propagation pipeline; out: client runtime repos"
  system_current_state: "<≥2 current stocks — e.g. count of active ROADMAP milestones;
                          count of in-flight programmes; current propagation backlog>"
  projection_horizon:   "3 months"
```

Proceed to write the addition **iff** the projection surfaces **no blocking
second-order effect** — no conflict with, double-count of, or archetype trap
(e.g. shifting-the-burden, success-to-the-successful) against milestones already
on the roadmap. A projected non-blocking caveat may proceed *with the caveat
recorded alongside the new item*.

### The write

Write `<X>` into `ROADMAP.md` **iff BOTH steps cleared**. Otherwise do not add
it; record the rejecting verdict (which step, which verdict, the reason) so the
next session does not silently re-propose the same rejected addition.

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct |
|--------------|--------------|---------|
| Running Step 2 when Step 1 returned `SMUGGLES_CONCLUSIONS` | Projecting the second-order effects of a wrongly-framed addition wastes the projection and can rubber-stamp a bad item | Step 1 is a hard gate; a smuggled-conclusion verdict ends the gate |
| Treating an operator hand-edit as goal-triggered and blocking it | The operator IS the judgment; gating their direct authoring is friction with no value | Operator-authored ROADMAP edits are exempt |
| Self-grading "the addition seems fine" instead of running the skills | The whole point is machine-checkable framing audit, not vibes | Always run both invocations; record both verdicts |
| Silently dropping a rejected addition | The next session re-proposes it; the rejection is invisible | Record the rejecting step + verdict + reason |
| Using a `target_system` with no boundary in Step 2 | `/map-feedback-loops` DECISION-mode below-MVI → hallucinated CLD | The `target_system` line above carries explicit `in:`/`out:` entities — keep them |

---

## Composition with existing rules

| Rule / artefact | Relationship |
|-----------------|--------------|
| `.claude/rules/framing-audit-mandate.md` | This gate is one concrete place the mandate's primitives are non-optionally applied (multi-phase / load-bearing: a roadmap commitment) |
| `.claude/skills/reduce-to-first-principles/` | Step 1 — invoked, never reimplemented |
| `.claude/skills/map-feedback-loops/` (DECISION mode) | Step 2 — invoked, never reimplemented |
| `goals.sh roadmap-gate` | The thin emitter that prints this gate's filled-in invocations |
| `.claude/rules/goal-ledger-programme-alignment.md` | Programme contract clause 4 — this gate is part of Session 3's verification surface |
| roadmap write-back (continuation §5D) | Disjoint: write-back ticks/annotates existing items; this gate governs *adding new* ones |

---

## Dogfood record

The gate's first real use is the council's own §9.5 recommendation — adding an
"Autonomous Orchestration" Project to `ROADMAP.md` (spec §11 deliberately
withheld that addition until this gate shipped). The Session 3 run of that
addition through this gate is recorded in
`council/sessions/2026-05-19-goal-feature-integration.md` (Session 3 addendum)
and the spec §9 manifest row.
