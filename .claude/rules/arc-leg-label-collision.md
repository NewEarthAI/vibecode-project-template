# Arc-Leg-Label Collision — Re-Used Labels in Continuations

**Scope**: any session that picks up a continuation, master-prompt, or council session that names an arc leg with a generic ordinal label — "Slice N", "Phase X", "Layer Y", "Wave Z", "Track K", "Session M". When the same label has been used to mean different things on the same arc, downstream sessions silently bind the wrong meaning.

**Origin**: 2026-05-20 — the `matrix-rehab-decouple` arc accumulated three distinct meanings of "Slice 2" within a single week. Closure council on Layer B Slice 2 (📄 `council/sessions/2026-05-20-layer-b-slice-2-checklist-decouple-reframed-extended.md`) framed the deferral correctly but the LABEL "Slice 2" survived into a sibling continuation that meant something else, then into a third handoff that meant yet another thing. No code shipped wrong — but the audit trail became unreadable in 48 hours.

---

## The principle

Arc-leg labels are *positional*, not *semantic*. "Slice 2" answers the question *"the second slice of what?"*. When the answer differs between two artefacts that share an arc name, the label is a collision waiting to happen. The collision is invisible until a future session reads one artefact and binds the label to another artefact's meaning — at which point the wrong-meaning propagates into plans, councils, and ROADMAP entries with full confidence.

This rule closes the door: before writing, citing, or acting on an arc-leg label, check whether the same label has carried a different meaning on the same arc within the recent window.

## When this rule fires

Any session that is about to:

1. **Author** a continuation, master-prompt, council session, ROADMAP entry, or PR title that names an arc leg with a generic ordinal label
2. **Act on** an arc-leg label from a continuation it just read — open a PR, run a council, dispatch agents, write a plan
3. **Reference** an arc-leg label across artefacts — "as decided in Slice 2", "per the Phase 3 plan", "the Layer B Track 1 ship"

If the label is ordinal-only (Slice / Phase / Layer / Wave / Track / Session + a number) AND the arc is multi-leg, this rule fires.

## The check (mandatory before propagating an ordinal label)

Two greps and one read, in order:

```bash
# 1. Recent arc-memory mentions of the label
grep -rE "(Slice|Phase|Layer|Wave|Track|Session) ${N}\b" \
     continuations/ council/sessions/ specs/sessions/ \
     --include="*.md" -l | head -20

# 2. Recent PR titles + bodies carrying the label
gh pr list --search "Slice ${N} OR Phase ${N} OR Layer ${N}" --state all --limit 10 --json number,title,mergedAt

# 3. Read the top 3 hits for the label's actual referent in each
```

If two or more hits assign DIFFERENT meanings to the same label on the same arc, you have a collision. Either:
- **Disambiguate at the call site**: replace `"Slice 2"` with `"Slice 2 (the checklist-axis-decouple Slice 2 from PR #841 closure, not the Track 1 ship of PR #847)"`
- **Re-label going forward**: introduce a semantic suffix — `"Slice 2-checklist-axis"`, `"Slice 2-rehab-wiring"`, `"Slice 2-handoff"` — and use that suffix in every new artefact

Never silently propagate the bare ordinal label past a known collision.

## When this rule does NOT fire

- Single-leg arcs where the label is non-ordinal (`"the dedup-graveyard fix"`, `"Cedar Hurst seller-source-supremacy"`) — semantic labels are self-disambiguating
- Ordinal labels inside ONE artefact (the four "Slice 2" sub-bullets within a single plan share that plan's scope)
- Labels qualified at first use with the arc name AND a date (`"Slice 2 of the 2026-05-20 closure council"`) — qualifier carries the disambiguation

## Composes with

- `.claude/rules/framing-audit-mandate.md` — the cross-arc demand-record class extension; an arc-memory-documented collision is itself the falsifier-not-found signal for a downstream plan that cites the colliding label
- `.claude/rules/doctrine-currency-check.md` — sister discipline for stale doctrine citations; this rule is the same pattern applied to arc-leg labels rather than rule-file claims
- `.claude/rules/multi-session-arc-coordination.md` — Ritual 1 (session-start) is the right place to run the collision check when the arc qualifies
- `.claude/rules/entity-discipline.md` — same anti-conflation discipline applied to partner names; this rule extends it to arc-leg labels

## Failure precedent

**2026-05-20 — `matrix-rehab-decouple` arc "Slice 2" trifecta**:

1. **PR #841** (merged 2026-05-20 13:55 UTC) — *"docs(matrix-rehab-decouple): close Layer B arc — Slice 2 DEFERRED via framing audit"*. "Slice 2" = the checklist-axis-decouple scope that the closure council reframed as falsifier-not-found and DEFERRED. Verbatim from the closure session memory.
2. **PR #847** (merged 2026-05-20 16:20 UTC) — *"feat(matrix): Track 1 — per-strategy rehab wiring (custom + checklist visible in matrix)"*. The PR body's plan-doc carried a "Slice 2" referring to the per-strategy rehab-wiring follow-up — different scope, different deliverable, different falsifier.
3. **MULTI-ARC handoff Track 2** (same day) — carried yet another "Slice 2" referring to a downstream coordination scope.

Three distinct meanings, one label, one arc, 48 hours. Any downstream session reading "the Slice 2 deferral" without the qualifier would have bound it to the wrong artefact at ~33% rate. This rule closes the door before that recurs.

Forward-only from 2026-05-20.
