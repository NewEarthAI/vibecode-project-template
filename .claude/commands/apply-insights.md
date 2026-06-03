# /apply-insights

Turn `/insights` friction data into shipped, verified fixes. Systematic 4-step orchestration: AUDIT → ANALYZE → IMPLEMENT → PROPAGATE.

**Run this AFTER `/insights`** in the SAME session (insights data must be in conversation context).

## What This Does

1. **AUDIT** — Finds free wins: dead shell hooks, orphaned hookify rules, broken registrations, missing prerequisites
2. **ANALYZE** — Classifies each friction event by root cause, checks existing coverage, filters suggestions against tech stack and infrastructure
3. **IMPLEMENT** — Scores candidates by `(Frequency × Severity) ÷ Effort`, selects cheapest enforcement layer, builds, verifies, commits individually
4. **PROPAGATE** — Generalizes template-pushable fixes, runs `/push-to-template`, produces projected impact report

## Workflow

```
/insights → review report → /apply-insights → /push-to-template (auto-prompted)
```

## Full Methodology

Read `.claude/skills/apply-insights/SKILL.md` for the complete 4-step methodology including:
- Infrastructure audit protocol (shell hooks × settings.local.json cross-reference)
- Friction classification matrix (4 root cause categories × 3 gap types)
- Suggestion evaluation filters (stack compatibility, already-using, autonomy gate, complexity gate)
- Impact scoring formula with template multiplier
- Enforcement layer decision tree (cheapest effective layer)
- Verification protocol per enforcement layer
- Template generalization rules
- Projected impact report format
