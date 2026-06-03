# {{Project}} — Competitive Intelligence Catalog

> Living catalog of competitor profiles, market SWOT roll-ups, and strategic signals.
> Every profile uses `_template-competitor-profile.md` + `_rubric-definitions.md` as its methodology backbone.
> Powered by the `competitive-intelligence` skill (Phase 0 binding + schema-versioned YAML frontmatter).

---

## How This Catalog Is Organized

```
strategy/competitive-intel/
├── README.md                              # THIS FILE — catalog index + methodology
├── _template-competitor-profile.md        # Hybrid JTBD template (YAML frontmatter + body)
├── _rubric-definitions.md                 # 0-5 scoring definitions — single source of truth
├── _research-runbook.md                   # Source checklist, quality bar, /agent-research prompt
├── _swot-rollup-template.md               # SWOT roll-up methodology
├── direct/                                # Direct competitors (same job, same persona)
├── indirect/                              # Indirect competitors (different solution, same job)
├── adjacent/                              # Adjacent / aspirational players
├── swot-rollups/                          # Market SWOT snapshots (generated on-demand)
├── tracking/                              # Delta reports for P0/P1 ongoing monitoring
└── related/                               # Pointers to sister catalogs (data-layer, etc.)
```

---

## Catalog Index

*Maintained by the `competitive-intelligence` skill. Manual edits permitted; skill will augment, not overwrite.*

| # | Company | Category | Priority | Confidence | File | Last Verified |
|---|---------|----------|----------|------------|------|---------------|
| 1 | *Example* | direct | P1 | stub | [example.md](direct/example.md) | {{YYYY-MM-DD}} |

---

## Key Findings Across All Research

*Updated when ≥3 profiles reach `confidence: complete` and a SWOT roll-up runs.*

1. *(pending — needs ≥3 complete profiles)*

---

## Positioning Cross-Reference

Differentiation hypotheses in each profile cross-reference:

- [`../positioning/README.md`](../positioning/README.md) — current positioning thesis
- [`../decisions-log.md`](../decisions-log.md) — append-only strategic decisions

If any profile's Differentiation Hypothesis conflicts with positioning → escalate to council session. Log the session in [`../decisions-log.md`](../decisions-log.md).

---

## Refresh Cadence

| Priority | Cadence | Ad-hoc Trigger |
|----------|---------|----------------|
| P0 | Monthly | Funding, leadership change, product launch, pricing change |
| P1 | Quarterly | Funding, product launch |
| P2 | Semi-annually | Category-shifting event |

Every refresh appends a Review Log entry to the profile.

---

## Schema Version

Current: `schema_version: 1` — generic 7-dim rubric.

When rubric dimensions change (add / remove / rename), bump `schema_version` in:
1. `_rubric-definitions.md`
2. `_template-competitor-profile.md`
3. All existing profiles (migrate to new rubric)

Roll-ups refuse to aggregate profiles with mixed `schema_version`.

---

## Related Catalogs

See [`related/`](related/) for sister catalogs this project may maintain (e.g., data-provider intel layer). Data-layer analysis lives separately — intentional demarcation per SI skeleton design.
