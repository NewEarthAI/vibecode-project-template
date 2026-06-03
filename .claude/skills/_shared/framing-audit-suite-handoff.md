# Framing-Audit Skill Suite — Handoff-Back Document

**From**: First Principles Systems Thinker workshop (the methodology workbench)
**To**: every NewEarth entity inheriting the suite — Agency-Main, BuyBox AI, Nirvana Freight
**Date**: 2026-05-18 — Operational Intelligence Synthesis Programme, Session 10 (final)
**Status**: the suite is built, verified, and propagating. This document ships with it.

This document closes the loop opened by Cassandra's 2026-05-14 Hermes failure report. The workshop was handed a mandate — *build a first-principles + systems-thinking skill suite that would have caught that failure* — and a 5-gap revision list. This is the workshop telling the agency what it did, so the suite is **understood**, not just inherited.

---

## 1. The failure this suite exists for (abbreviated)

On 2026-05-14 the agency ran a 3-phase competitor evaluation of Hermes Agent under the Pi-outperforms doctrine. Phase 1 research brief → Phase 2 Capability Scout audit → Phase 3 eight-agent extended council. All eight agents converged unanimously: BUILD NATIVE. Then Cassandra asked one question — *"are we comparing apples to pears?"* — and the verdict's foundation cracked.

The Phase 2 "reproducibility check" gate (first-principles intent: *test whether the competitor's claims hold up when run in our environment*) had silently become a build-cost estimate: a theoretical native-build cost compared against a theoretical Hermes-integration cost. **Estimate vs estimate — the weakest possible comparison, with zero hands-on data.** Eight agents converged *inside a flawed frame*. The council's own Reframer did not catch it, because the Reframer audited the proposal in front of it — it never walked back through the upstream phases that produced the proposal.

The failure is structural, not a skill-gap: framing inheritance through multi-phase orchestrations, convergence mistaken for validation, method silently substituted for gate-intent.

## 2. What shipped — the suite

Five callable framing-audit primitives, each carrying the 4-component anti-anchoring pattern (`diagnostic-skill-anti-anchoring.md`):

| Primitive | Artefact | What it does |
|-----------|----------|--------------|
| 1 | `/reduce-to-first-principles` | Reduces a claim / proposal / protocol gate to its irreducible question; names what the framing added (constraints, presuppositions, smuggled conclusions). |
| 2 | `/map-feedback-loops` (DECISION mode) | Projects the second-order effects of a named decision — feedback loops, compounding effects, delayed consequences. |
| 3 | `/check-commensurability` | Classifies a comparison on the five-rung ladder (estimate-vs-estimate → controlled experiment); fires a Hands-On Calibration Gate when a qualifying external competitor sits on the unproven side. |
| 4 | `_shared/frame-vs-input-classifier.md` | A library: classifies operator pushback as frame-criticism vs input-criticism. |
| 5 | `/audit-artefact-grounding` | Audits one Claude Code artefact (skill/rule/hook/agent/doctrine) on a 6-axis rubric; returns keep / refactor / deprecate with a propagation flag. Composes Primitives 1-4. |

**Plus**: the upgraded **Reframer agent** (Multi-Phase Position Audit — the upstream-walk the Hermes council lacked — now citing the five shipped primitives as canonical), and a refactored **skill-auditor-merger** (gained a self-test block + a non-commensurability note on its weighted score).

The suite **composes with** the existing architecture — it does not replace it. The Pi-outperforms doctrine, the council protocol, the Reframer, the Capability Scout, the Reliability Engineer all stay; the suite adds primitives they invoke.

## 3. The Hermes re-run acceptance test — the suite is verified

The suite earned its place only by catching the 2026-05-14 failure on a re-run. On 2026-05-18 the documented Hermes Phase 1/2/3 artefacts were walked through the shipped primitives (record: `council/2026-05-18-hermes-rerun-acceptance-test.md` in the workshop):

- **Phase 1** — `/reduce-to-first-principles` flagged the "in-session learning layer" scope as **inherited, not derived** (a presupposition Phase 1's research never established).
- **Phase 2** — `/check-commensurability` classified the comparison **rung 1 (estimate vs estimate)** and the Hands-On Calibration Gate **FIRED** — Hermes is a qualifying external competitor on an unproven side; a verdict cannot lock until a hands-on calibration run closes the gap.
- **Phase 3** — the upgraded Reframer's Multi-Phase Position Audit walked upstream and **named the Phase 2 gate-vs-method substitution** with its dropped content (empirical data on whether Hermes works in our environment).

**End-state**: the apples-vs-pears framing is caught at Phase 2, before Phase 3 ever fires — without the operator asking the question. **The suite is verified.** Honest caveat: this is a walk-the-documented-artefacts test, not a live VPS re-run; the live calibration interlude is the real-world remediation the suite *recommends*, not part of the test.

## 4. The 5-gap revision-list status

| Gap | Status | Detail |
|-----|--------|--------|
| 1 — Success-Criteria-Discipline rule has no Success Criteria block on itself | **CLOSED** | `/audit-artefact-grounding` run on the rule draft: axis 6 fired (`fail`); verdict `refactor`. The bounded fix (add a self-applied `## Success Criteria` block) is named in §5 below — **Agency-Main applies it before wiring the rule**. |
| 2 — the 6 meta-discoveries inducted from a single thread (Hermes) | **OPEN — handed back to Cassandra** | The re-run validated the suite against ONE thread. The workshop will NOT self-nominate other threads — that reproduces the single-source-derivation risk Gap 2 names. **Owner: Cassandra / Agency-Main. Action: nominate 1-2 other recent multi-phase threads; re-run the suite's acceptance walk against each.** |
| 3 — Reframer upstream-walk vs default-to-PROCEED contradiction | **RESOLVED** | The shipped Reframer carries the `[GAP-3 FIX]` — audit depth calibrated by decision class. Adopt the shipped version. |
| 4 — Hands-On Calibration Gate placement in Pi-outperforms | **RESOLVED — Agency-Main adopts** | See §5. |
| 5 — operator-as-frame-validator burnout | **CLOSED as a design principle** | The suite IS the automation answer — see §5. |

**Gap 5 — the suite-as-automation answer.** Before this suite, the operator (Cassandra) was the *only* frame-validator in the system; she had to escalate manually ("apples and pears") and escalate repeatedly before a frame got audited. That made the operator the Theory-of-Constraints bottleneck. The suite removes that load: framing audits are now callable primitives that fire automatically (the Reframer's Multi-Phase Position Audit runs first in every council; `/check-commensurability` fires the Calibration Gate without being asked). The operator escalates only the exceptional cases the suite does not cover — frame-validation stops being a manual reflex she must remember to apply.

## 5. Per-repo wiring

Each repo inherits the suite via `/update-latest` once, then runs the acceptance test in its own domain (the inheritance test — the suite must apply outside the thread it was derived from).

### Agency-Main (Cassandra)
1. **Adopt the upgraded Reframer** — the citation-stamped version (`[GAP-3 FIX]` + primitives 5-8 now citing the shipped skills). It replaces the 2026-05-14 inline-primitive version.
2. **Adopt the Hands-On Calibration Gate placement** (Gap 4) — place the gate in the Pi-outperforms doctrine **between Phase 2 (Capability Scout audit) and Phase 3 (the council)** — after the doctrine's Step 2 "quantify the gap" and before Step 3 "decide via the tree". `/check-commensurability` emits the `calibration_gate` signal; wire the consuming hook that blocks the Phase 3 verdict-lock on `decision == FIRES`. (Until that hook is wired the gate is honestly advisory — `enforcement_active: false`.)
3. **Refactor the Success-Criteria-Discipline rule before wiring it** (Gap 1) — add a self-applied `## Success Criteria` block (Done / Good / Bad / Verification protocol) to the rule itself; it currently mandates that block on every artefact but carries none. Then wire it as auto-loaded doctrine.
4. **Nominate 1-2 other threads for Gap 2** — re-run the suite's acceptance walk against them to retire the single-source risk.
5. **Inheritance test**: re-run the Hermes thread end-to-end with the suite installed; confirm the Phase 2 Calibration Gate fires before Phase 3.

### BuyBox AI
The suite is generic — no real-estate assumptions. Run the inheritance test on a real BuyBox decision: take a recent adopt-vs-build or vendor-comparison call (e.g. a PropTech data-provider choice) and run `/check-commensurability` on it — confirm the ladder classification and the gate behaviour are correct in a real-estate context. Run `/reduce-to-first-principles` on a recent spec's framing. The framing-audit reflex applies to any multi-phase decision, not just competitor evaluations.

### Nirvana Freight
Same inheritance test, freight domain: take a recent operational decision (a routing-rule change, a carrier-vs-in-house comparison) and run `/check-commensurability` + `/reduce-to-first-principles` on it. Confirm the suite's vocabulary is domain-neutral and the primitives apply cleanly to freight decisions.

## 6. Why this matters for NewClaw / NewMem

NewClaw and NewMem are downstream of every skill and protocol. The agency held neither build *gated* on the full suite — only the framing-audit *reflex* (the upgraded Reframer) gated them, and that shipped first. This document certifies the **full suite is now verified and ready** as their upstream framing-audit dependency: any adopt-vs-build decision inside NewClaw triggers `/check-commensurability`; any multi-phase orchestration gets the Reframer's Multi-Phase Position Audit. The Hermes failure — a locked verdict on an estimate-vs-estimate comparison — will not recur silently.

---

## Strategic Alignment

**ROADMAP item(s) this advances**: the Operational Intelligence Synthesis Programme (Session 10, final — this is the loop-closing artefact); the workshop's North Star Metric (propagation — this document ships with the first multi-repo propagation of the whole suite); the agency's Pi-outperforms doctrine (gains the Hands-On Calibration Gate placement); NewClaw + NewMem (gain a verified framing-audit dependency).

**ROADMAP item(s) this REJECTS**: inheriting the suite without understanding it (this document is the understanding); the workshop self-nominating Gap 2 threads (second-party nomination only).

**If this advanced nothing**: the receiving repos would inherit five skills with no account of why they exist or how to wire them; Agency-Main would wire the Success-Criteria-Discipline rule with its self-application gap intact; the Hands-On Calibration Gate would have no placement; and the loop with Cassandra's failure report would never close.
