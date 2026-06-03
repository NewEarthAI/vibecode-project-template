# Framing-Audit Mandate

**Auto-loaded on**: any session doing decision-class or framing-relevant work. Detection
signals — a build-vs-buy / adopt-vs-build question, an architecture decision, a
comparison-based verdict, the start of a multi-phase orchestration (`/autovibe`, `/council`,
`/plan`, `/prompt-forge`, `/build-with-agent-team`), creating or auditing a Claude Code
artefact (skill / rule / hook / agent / doctrine), operator pushback at a framing juncture,
or any chat that mentions first-principles or systems-thinking framing. This rule sits in
`.claude/rules/` and loads under the same contextual mechanism as the sibling programme rules
(`synthesis-programme-alignment.md`, `doctrine-verification-gate.md`).

**Every-session announcement**: the mandate itself is announced in EVERY session —
unconditionally, regardless of topic — by `.claude/hooks/framing-audit-activation.sh`
(SessionStart component), which injects the framing-audit banner at session start. The same
hook nudges the matching primitive at decision moments (UserPromptSubmit component). This is
the announce-vs-run split: the hook *announces* the mandate every session and points here;
this rule is the full doctrine, loaded contextually when framing-relevant work is in play.
Rule + hook are Layers 1 + 2 of the Mandatory Framing-Audit Programme.

**Origin**: Session 1 of the Mandatory Framing-Audit Programme — Phase 2 of the Operational
Intelligence Synthesis Programme. Spec: `specs/09_MANDATORY_FRAMING_AUDIT_PROGRAMME.md`.
Contract: `.claude/rules/mandatory-framing-audit-alignment.md`.

---

## The principle

A **framing audit** — checking that a question is the *right question* before answering it —
is **compulsory before any load-bearing decision**. The absence of first-principles + systems
thinking has been the single largest failure source in the agency's AI work: careful, thorough,
multi-agent work converges *inside a flawed frame* and produces a confident wrong answer. The
rigour on top of a wrong frame is wasted rigour.

The canonical failure (2026-05-14): an eight-agent council converged unanimously on a
build-vs-buy verdict. The comparison underneath it was estimate-vs-estimate — the weakest
possible comparison — and no agent caught it until the operator asked "are we comparing apples
to pears?". The frame was wrong; every hour of analysis on top of it was wasted.

Phase 1 of the synthesis programme built five callable framing-audit primitives. They work.
This rule makes them **non-optional**. A load-bearing decision made without the matching
framing audit is an incomplete decision — and saying so is not pedantry. It is the highest-
leverage defence the agency has against the recurring failure class.

## Announce vs. run — the scope distinction

This rule is *present* in every session — the mandate is **announced** every session. The
audit itself **runs** only on load-bearing decisions. A session that fixes a typo, looks up a
fact, or tweaks a setting does NOT run a framing audit; forcing one there is noise, and noise
gets routed around. The mandate is always loaded; the audit is conditionally run. Keeping
those two separate is what keeps the mechanism trusted instead of ignored.

## When the framing audit is COMPULSORY

Run the matching primitive — *before the decision locks* — whenever the work crosses any of
these trigger classes:

| Trigger class | Example | Primitive |
|---|---|---|
| A proposal / claim / protocol gate about to drive a decision | "should we build X?", "X is better than Y", a gate named "reproducibility check" | `/reduce-to-first-principles` |
| A comparison underpinning a verdict | "native build vs. integrate", "tool A vs. tool B" | `/check-commensurability` |
| A decision with second-order / over-time consequences | "adopt this workflow", "change this incentive" | `/map-feedback-loops` (DECISION mode) |
| Operator pushback at a framing juncture | "wait — what?", "that's not what I asked", "apples and pears" | `_shared/frame-vs-input-classifier.md` |
| Creating or auditing a Claude Code artefact (skill / rule / hook / agent / doctrine) | shipping a new skill, reviewing a rule | `/audit-artefact-grounding` |
| The start of any multi-phase orchestration | `/autovibe`, `/council`, `/plan`, `/prompt-forge`, `/build-with-agent-team` | audit the *goal's* framing with `/reduce-to-first-principles` before the phases run |

A **load-bearing decision** is one that is hard to reverse, commits resources, or sets the
frame for downstream work. Architecture choices, build-vs-buy, venture or resource
commitments, comparison-based verdicts, and the goal of any multi-phase run all qualify.

## When it does NOT fire (not for trivia)

Skip the audit — and the hook stays silent — on: typo fixes, single-line edits, settings
tweaks, factual lookups, pure-empirical questions ("did the migration apply?"), and any work
with no decision attached. The audit is for *framings*, not for *tasks*. Over-applying it is
the failure mode that makes the whole mechanism get ignored.

## How to apply

1. Identify the trigger class from the table above.
2. Invoke the matching primitive. It is a **named, non-skippable step** — not a background
   nicety, not something to "get to later".
3. Record the primitive's structured verdict (`SOUND` / `ADDS_CONSTRAINTS` /
   `SMUGGLES_CONCLUSIONS`; a commensurability rung; a frame-vs-input class; an artefact
   verdict).
4. On a verdict that flags the frame — `SMUGGLES_CONCLUSIONS`, a rung-1/2 comparison with the
   Hands-On Calibration Gate firing, a `frame-criticism` classification — **do not proceed
   inside the frame**. Reframe first, then re-run the decision.
5. On a clean verdict: proceed — the audit is now part of the decision record.

## Falsifier-record classes (what counts as a demand record)

When `/reduce-to-first-principles` asks "what is the operator-demand record this proposal
answers?" the falsifier — the evidence that would invalidate the proposal's motivation — must
come from one of the following valid record classes. The class is *equivalent* in weight; an
arc-memory-documented cross-arc gap is as load-bearing as a verbatim user quote.

| Record class | Example | Load-bearing? |
|---|---|---|
| **User quote** (verbatim) | "Chris said: 'I need to see the spread before I touch the offer'" | YES |
| **Session-log entry** | continuation §6 names the gap with timestamp + decision | YES |
| **Feedback memory file** | `feedback_<topic>.md` carries the failure precedent + fix | YES |
| **Arc-memory-documented cross-arc gap** *(added 2026-05-20)* | one arc's PROGRESS-LOG / closure-council names a gap that a sibling arc inherits; the inheriting arc's leg has no independent demand record but the cross-arc handoff IS the record | YES |
| **Doctrinal symmetry alone** ("mirrors prior leg / completes the symmetry") with NO record above | the proposal's only motivation is "Layer A had a Slice 2, so Layer B should have a Slice 2" | **NO — falsifier-not-found → DEFER** |

The arc-memory-documented cross-arc gap class was extracted 2026-05-20 from PR #841
(`docs(matrix-rehab-decouple): close Layer B arc — Slice 2 DEFERRED via framing audit`). The
closure council's framing audit named "doctrinal symmetry is not demand" as the load-bearing
distinction: if the only motivation for a build leg reduces to *"mirrors prior leg"* with no
operator-demand record, the falsifier is not present and the leg must DEFER pending a
revisit-trigger. The cross-arc gap class is the *positive* counterpart — a sibling arc's
handoff DOES create demand, even when the inheriting arc has no direct user quote.

When the only available record is doctrinal symmetry: route to DEFER with revisit-triggers,
not to council-on-implementation-options. The cost of building inside a symmetry-only frame
is the cost the canonical failure (2026-05-14) named — rigour on top of a wrong frame is
wasted rigour.

## The five primitives (cite — never copy)

This rule **names** the primitives; it never reproduces their procedures. Inline copies drift
from their source — Phase 1 Session 10 deleted exactly such copies from the Reframer agent.
The authoritative procedures live in the skill files.

| # | Primitive | What it does | Invoke when |
|---|-----------|--------------|-------------|
| 1 | `/reduce-to-first-principles` | Reduces a claim / proposal / protocol gate to its irreducible question; names what the framing added (added constraints, presuppositions, smuggled conclusions). | A framing is about to drive a decision. |
| 2 | `/map-feedback-loops` (DECISION mode) | Projects the second-order effects of a named decision — feedback loops, compounding effects, delayed consequences. | A decision whose consequences play out over time. |
| 3 | `/check-commensurability` | Classifies a comparison on a five-rung ladder (estimate-vs-estimate → controlled experiment); fires a Hands-On Calibration Gate when a qualifying external option sits on the unproven side. | Any comparison underpinning a verdict. |
| 4 | `_shared/frame-vs-input-classifier.md` | Classifies operator pushback as frame-criticism vs input-criticism; frame-criticism routes to a framing audit, not a frame-internal answer. Not user-invocable — a library cited by agents (`.claude/skills/_shared/frame-vs-input-classifier.md`). | Operator pushback lands at a framing juncture. |
| 5 | `/audit-artefact-grounding` | Audits one Claude Code artefact on a six-axis grounding rubric; returns keep / refactor / deprecate with a propagation flag. Composes Primitives 1-4. | Creating or reviewing a skill / rule / hook / agent / doctrine. |

The upgraded **Reframer** council agent (`.claude/agents/council/reframer.md`) runs the
framing audit automatically as Phase 0 of every `/council`; its Multi-Phase Position Audit
walks upstream through prior phases. The suite's handoff document —
`.claude/skills/_shared/framing-audit-suite-handoff.md` — carries the full suite map, the
2026-05-14 failure story, and the verification record.

The sibling systems-thinking skills `/diagnose-bottleneck` (flow-constraint location) and
`/decide-under-uncertainty` (option-choice once the frame is sound) handle adjacent classes —
they are not framing audits and are not mandated by this rule.

## Composition with existing rules

- `council-protocol.md` — the Reframer is the council's standing framing-audit; this rule
  extends the same discipline to non-council work.
- `pre-completion-pocock-check.md` — both are pre-completion gates; this one adds the framing
  dimension to the completion check.
- `diagnostic-skill-anti-anchoring.md` — the primitives are diagnostic-class skills carrying
  the anti-anchoring guard; when a primitive takes an operator-supplied hypothesis, that guard
  governs how the primitive treats it.
- `mandatory-framing-audit-alignment.md` — the programme contract that governs the work that
  produced this rule.

## What this rule is NOT

- **Not a blocker.** The hook never halts a tool call; this rule never halts work. It mandates
  a *step*, surfaced for the operator. Work can proceed past a stated gap if the operator
  accepts it — only a *silent* skip is forbidden.
- **Not for trivia.** See the not-for-trivia section — over-application kills the mechanism.
- **Not a copy of the skills.** It cites; the procedures live in the skill files.
- **Not retroactive.** Applies forward-only from 2026-05-18.

## References

- Programme spec: `specs/09_MANDATORY_FRAMING_AUDIT_PROGRAMME.md`
- Programme contract: `.claude/rules/mandatory-framing-audit-alignment.md`
- The hook: `.claude/hooks/framing-audit-activation.sh`
- Suite handoff: `.claude/skills/_shared/framing-audit-suite-handoff.md`
- The five primitives: `.claude/skills/{reduce-to-first-principles,check-commensurability,map-feedback-loops,audit-artefact-grounding}/` + `.claude/skills/_shared/frame-vs-input-classifier.md`
- Reframer agent: `.claude/agents/council/reframer.md`
- Council protocol: `.claude/rules/council-protocol.md`
