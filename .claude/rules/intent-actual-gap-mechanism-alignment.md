# Intent-Actual-Gap Mechanism Build Programme — Alignment Contract

**Auto-loaded on**: any session working on the Intent-Actual-Gap Mechanism Build Programme. Detection signals — edits to `specs/13_INTENT_ACTUAL_GAP_MECHANISM_PROGRAMME.md`, `DESTINATION.md` (the success contract), any file under `docs/operational-doctrine/` numbered 04+, the three mechanism skill/substrate files once they exist, `specs/research/architecture-blueprint-research-*.md`, or any chat mentioning "intent-actual-gap", "the three verification dimensions", "Test D / schema separability", or "intent capture / topology-from-source / conservation-law" in the mechanism-building sense.

**Scoped to**: every session in the multi-session programme launched 2026-05-22. Programme spec: `specs/13_INTENT_ACTUAL_GAP_MECHANISM_PROGRAMME.md`. Success contract: `DESTINATION.md` (v2). Derived from `.claude/rules/multi-session-programme-contract-template.md`.

---

## The Hard Contract — 10 Clauses

Any session in scope MUST do all of the following before claiming completion.

### 1. Read the programme spec AND the destination FIRST
Before any tool call that creates or modifies a programme artefact, read `specs/13_INTENT_ACTUAL_GAP_MECHANISM_PROGRAMME.md` AND `DESTINATION.md` (v2) in full. The spec defines the session forecast (§3) and the verification standard (§2); the destination defines the seven Element-1 conditions, the four binary tests (A/B/C/D), and the five could-the-test-lie scenarios. **Failure mode prevented**: a session redefining the verification standard or authoring against the un-amended v1 destination.

### 2. Declare which milestone this is
Before substantive work, declare: `Programme milestone: {M2-M5}`, scope, and out-of-scope per spec §3. M2 = doctrines. M3 = first mechanism versions. M4 = proof on highest-complexity entity. M5 = propagation + sustain. If the milestone is unclear, halt and ask the operator — do NOT guess. **Failure mode prevented**: scope creep — M2 silently building mechanism code (M3's work) instead of authoring doctrines.

### 3. Compose with existing tools — never rebuild
The programme composes the doctrine-verification-gate rule, the existing systems-thinking doctrine (quality template), the synthesis-programme-alignment contract (the worked model), `pocock-grill-with-docs`, `/council --extended`, `/code-council`, and the M1 research report. A session reaching for a tool not in the spec documents why first. **Failure mode prevented**: rebuilding the triple gate or re-running the M1 research.

### 4. Pass the verification gate before merging any artefact
Per spec §2: every doctrine passes the triple verification gate (deletion test + `/code-council` PASS-or-ADVISORY + real-decision test) AND defends Test D (pairwise Jaccard schema overlap < 50%). A doctrine that fails any gate, or that defends separability on "industry precedent" (which the M1 falsifier proved does not exist), is rewritten or downgraded — never silently merged. **Failure mode prevented**: anti-sycophancy collapse — self-grading "good enough" without machine-checkable evidence.

### 5. Strategic Alignment footer on every council / spec / continuation
Per `council-protocol.md`: ROADMAP items advanced, ROADMAP items rejected, the if-this-advances-nothing justification. **Failure mode prevented**: programme drift.

### 6. Manifest update before ending the session
Append to `specs/13` §6 "Recently completed"; update `ROADMAP.md` "Recently Completed"; update the `MEMORY.md` In-Flight Work line and the in-flight memory file. **Failure mode prevented**: invisible progress.

### 7. Layman voice in chat; technical register in artefacts
Per `~/.claude/rules/layman-mode.md`. The spec, this contract, the doctrines, council bodies, and session prompts are technical-register carve-outs. **Failure mode prevented**: operator decision fatigue.

### 8. Anti-sycophancy enforcement — name the tools that fire it
Three mechanisms MUST fire on every load-bearing decision: the Devil's Advocate (in any `/council`), the code-review identity rule (`code-review-identity.md`, auto-loaded on review work), and the plan-stress-test skill (`pocock-grill-with-docs`, mandatory at every doctrine-authoring plan phase). A session routing around all three on a load-bearing decision has violated the contract. **Failure mode prevented**: a doctrine that defends the contested three-way split by assertion rather than evidence.

### 9. Plan-then-execute on every session
Enter plan mode → plan v1 → (stress-test + council if load-bearing) → operator approval → execute. Skip only for trivial work (a single-line manifest append). Doctrine authoring and mechanism building are non-trivial. **Failure mode prevented**: authoring 600-line doctrines on a wrong-framed separability assumption.

### 10. Output chunking — manifest-first for any deliverable >3,000 tokens
Per `output-chunking.md`. Doctrines (≥600 lines) always exceed the cap. Emit a manifest first, then write each file. **Failure mode prevented**: silent truncation.

---

## The programme-specific load-bearing rule: separability is EARNED, never assumed

This programme exists to build a mechanism whose central design claim — that intent capture, topology-from-source, and reconciliation are three SEPARATE composable mechanisms — has **no industry precedent** (M1 falsifier, 2026-05-22). Therefore:

- The doctrine COUNT is decided by Test D (the separability test), not pre-assumed as three. M2 Phase 1 sketches the three schemas and computes pairwise Jaccard overlap BEFORE authoring any doctrine.
- Any pair scoring ≥ 50% overlap collapses into one doctrine and triggers a `DESTINATION.md` amendment recommendation.
- No doctrine, mechanism, or session may defend the split using "industry / leading teams do it this way" as the primary argument. The defence is internal: distinct schemas, distinct update cadences, distinct operator workflows.

A session that forces three doctrines without running Test D first has violated this programme's defining discipline.

---

## In-scope detection criteria

A session is programme-class work if ANY of these are true:
- It touches `specs/13_INTENT_ACTUAL_GAP_MECHANISM_PROGRAMME.md` or `DESTINATION.md` substantively.
- It creates or edits a doctrine in `docs/operational-doctrine/` numbered 04+.
- It creates or edits one of the three mechanism skill/substrate files once they exist.
- It runs `/council` or `/code-council` on a programme topic (the three dimensions, Test D, the mechanism design).
- The operator explicitly says "this is intent-actual-gap programme work".

## What this contract is NOT

- Not a gate that blocks — a session may ship with stated gaps if the operator explicitly accepts them; only silent gaps are forbidden.
- Not a substitute for the programme spec or the destination — read both for substantive decisions.
- Not retroactive — applies forward-only from 2026-05-22.
- Not for trivia — typo fixes, single-line manifest appends skip this contract.

## Failure precedents (prospective)

- **Forecast 1**: M2 forces three doctrines without running Test D, baking in separability the M1 falsifier flagged as unproven; if the schemas overlap, three doctrines exist where two were warranted. Prevented by §4 + the separability-is-earned rule.
- **Forecast 2**: a doctrine defends the three-way split with "Spotify/Stripe do it this way" — but the M1 reality check found they do NOT. Prevented by §8 + the separability-is-earned rule.
- **Forecast 3**: M3 builds mechanism code while M2's doctrines are still uncommitted in a parallel session — merge conflict + drift. Prevented by §2 (declared milestone) + a collision check per `continuation-collision-safety.md`.
- **Forecast 4**: a session ships a doctrine without the triple gate because "it reads well". Prevented by §4 (no merge without all three gates).

---

## References

- Programme spec: `specs/13_INTENT_ACTUAL_GAP_MECHANISM_PROGRAMME.md`
- Success contract: `DESTINATION.md` (v2)
- M1 evidence base: `specs/research/architecture-blueprint-research-2026-05-22.md`
- Triple gate: `.claude/rules/doctrine-verification-gate.md`
- Contract skeleton: `.claude/rules/multi-session-programme-contract-template.md`
- Worked model: `.claude/rules/synthesis-programme-alignment.md`
- Layman voice: `~/.claude/rules/layman-mode.md`
