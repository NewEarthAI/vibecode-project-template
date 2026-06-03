# Severity Modes — Review Depth Matrix

> Reference for `newearth-security`. Maps the skill's three operating modes onto how deep a review goes
> and which severity floor it reports at. Prevents the two failure modes: over-scanning a docs edit, and
> under-scanning a production trust-boundary change.
> **Source pattern**: `snyk/studio-recipes` 4-mode severity matrix (ABSORB-PATTERN, 2026-05-22 council).

## Next Review

**2026-08-22** (90-day cadence per Amendment 16). Re-verify the mode-to-depth mapping still matches the
conductor's Operating Modes table and that the Snyk-derived severity floors remain sensible defaults.

---

## The four modes

The skill's `SKILL.md` defines three *operating* modes; this matrix adds a fourth *production-audit*
posture that raises the bar for live-surface changes.

| Mode | Trigger | Depth | Severity floor reported | Output |
|------|---------|-------|-------------------------|--------|
| **1 — Secure-by-default** | while writing code | write secure patterns inline; no scan | n/a (no report) | secure code, silently |
| **2 — Passive detection** | working on other tasks | grep-level pattern scan only (Tier 1-2) | **HIGH only** | one-line warnings |
| **3 — Full audit** | explicit `/security-review` | all 4 tiers + data-flow trace | **HIGH + MEDIUM** | structured report + tool-status block |
| **4 — Production audit** | change touches a live trust boundary (auth, payments, RLS, edge fn, partner-facing flow) | all 4 tiers + STRIDE/DREAD + runtime verification | **HIGH + MEDIUM + scored LOW** | structured report; LOW shown WITH DREAD score so operator can accept-or-fix explicitly |

Mode 4 is not a separate trigger phrase — it is Mode 3 with the bar raised, auto-selected when the diff
touches a production trust surface. It mirrors the `loading-state-invariants.md` doctrine that
production-surface changes get runtime verification, not just static review.

---

## Severity floor — why it differs by mode

| Floor | Rationale |
|-------|-----------|
| **HIGH only** (Mode 2) | Passive mode runs constantly in the background. Reporting MEDIUM here would be alert fatigue — the operator is mid-other-task. Only a confirmed exploit interrupts. |
| **HIGH + MEDIUM** (Mode 3) | An explicit audit is the moment to surface "verify X is sanitised" items. MEDIUM findings hand the operator a verification task. LOW stays suppressed (noise). |
| **HIGH + MEDIUM + scored LOW** (Mode 4) | On a production trust boundary, an accepted LOW must be an *explicit* decision, not a silent suppression. LOW findings appear WITH their DREAD score so the operator consciously accepts the residual risk. |

---

## Mode selection logic (reviewer applies before scanning)

```
if change is a live trust boundary (auth / payments / RLS / edge fn / partner-facing):
    → Mode 4 (production audit)
elif operator explicitly asked for a security review:
    → Mode 3 (full audit)
elif actively writing new code:
    → Mode 1 (secure-by-default) + Mode 2 passive watch
else:
    → Mode 2 (passive detection)
```

The trust-boundary trigger list is the conductor's Tier 4 table + the
`loading-state-invariants.md` production surfaces (auth, drawer, checkout/payment paths).

---

## Anti-patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Full STRIDE/DREAD pass on a comment edit | wastes the operator's attention; trains them to ignore the skill | Mode 1/2 for non-boundary edits |
| Reporting MEDIUM findings in passive mode | alert fatigue mid-task | Mode 2 floor is HIGH-only |
| Silently suppressing a LOW on a payments-path change | the operator never got to accept the risk | Mode 4 shows scored LOWs explicitly |
| Treating "no tools available" as a clean Mode-3 pass | hides coverage gap | tool-status block (Amendment 18) makes the gap visible |

---

## How this composes

- The conductor `SKILL.md` Operating Modes table is modes 1-3; this file adds mode 4 + the severity floors.
- `security-categories.md` confidence schema decides what counts as HIGH/MEDIUM/LOW; this file decides
  which of those a given mode *reports*.
- `stride-dread.md` is the method Mode 4 invokes for scored-LOW visibility.
