# Scaffold Manifest

> When the `competitive-intelligence` skill scaffolds a project's SI skeleton (Phase 0.4 option a), it copies these templates to the following paths. This manifest is the authoritative mapping.

---

## Files Written on Scaffold

| Source (inside this skill's `templates/`) | Destination (in project root) | Purpose |
|-------------------------------------------|-------------------------------|---------|
| `_template-competitor-profile.md` | `strategy/competitive-intel/_template-competitor-profile.md` | Hybrid JTBD competitor template |
| `_rubric-definitions.md` | `strategy/competitive-intel/_rubric-definitions.md` | Single-source-of-truth 0-5 scoring |
| `_research-runbook.md` | `strategy/competitive-intel/_research-runbook.md` | Source checklist, quality bar, agent-research prompt |
| `_swot-rollup-template.md` | `strategy/competitive-intel/_swot-rollup-template.md` | SWOT methodology |
| `catalog-README.md` | `strategy/competitive-intel/README.md` | Catalog index + methodology hub |
| `_template-our-profile.md` | `strategy/our-profile.md` | **Our own profile — every competitor profile cross-references this. CRITICAL: seed BEFORE first competitor research or output is ungrounded.** |
| `positioning-README.md` | `strategy/positioning/README.md` | Positioning v0.0 placeholder |
| `decisions-log.md` | `strategy/decisions-log.md` | Append-only strategic log |

---

## Directories Created

```
strategy/
├── competitive-intel/
│   ├── direct/              # (empty — populated as profiles are researched)
│   ├── indirect/            # (empty)
│   ├── adjacent/            # (empty)
│   ├── swot-rollups/        # (empty — populated when ≥3 profiles → run roll-up)
│   ├── tracking/            # (empty — populated for P0/P1 ongoing monitoring)
│   └── related/             # (empty — add pointers to sister catalogs here)
├── positioning/             # (contains README.md from template)
├── customer-avatars/        # (empty — future layer, not scaffolded by default)
└── gtm/                     # (empty — future layer, not scaffolded by default)
```

---

## Scaffold Protocol

1. Resolve `$PROJECT_ROOT` via `git rev-parse --show-toplevel` (prevents worktree misfire)
2. Show user the full file list with absolute paths
3. Single confirmation prompt
4. Write files
5. `git status` after scaffold — user confirms files are in expected working tree
6. Emit Binding Report showing the new `$SI_ROOT` state

---

## Customization After Scaffold

The bundled templates are **generic starters**. First real use should customize:

1. **Rubric dimensions** — replace the 7 generic dims in `_rubric-definitions.md` with domain-specific dims (PropTech projects might use `underwriting_ai`, `crm_integration_depth`, etc.). Keep `schema_version: 1` until dimensions stabilize; bump on changes.
2. **Persona names** — replace `{{Persona A}}` / `{{Persona B}}` in any applicability matrix with project's actual user segments.
3. **Positioning v0.0 → v0.1** — seed `positioning/README.md` with founder thesis before first competitive research session.
4. **Catalog index** — replace the `*Example*` row in `catalog-README.md` with your first real stub entry.

---

## Template Version

Current: **v1.0** (2026-04-18) — seeded from a Strategic Intelligence skeleton design pattern (hybrid JTBD + 11-dim rubric + YAML frontmatter + decisions-log append + SWOT-rollup + positioning cross-reference + direct/indirect/adjacent categorization).

When bundled templates evolve, bump the version in the skill's frontmatter `metadata.schema_version`. New projects scaffolded after a version bump get the latest. Existing projects migrate manually — no auto-overwrite.
