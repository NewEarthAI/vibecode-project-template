# Persona Decision Tree — Obsidian Vault Autopilot

Per council A8 + A13: v1.0 implements **NewEarth-internal persona only**. External-adopter wizard ships in v2.0. No-Obsidian-installed flag is universal across versions.

## The Three Personas

| Persona | Who they are | Vault target | DB target | v1.0 supported? |
|---|---|---|---|---|
| **newearth-internal** | Cassandra or Justin (or future NewEarth team) working in an Agency-Main / BuyBox / Nirvana / GoodBuy / template-derived NewEarth repo | `agency/vault/` inside the repo | `supabase-newearthai` (prod `ridqdojzjotlvexfuwvx`); spoke variants → respective client Supabase (v1.2+) | ✓ YES |
| **external-adopter** | A friend or future client who cloned the template for their own venture | Adopter's own vault path (default `~/Obsidian/<project-name>/`) | Adopter's own Supabase project | ✗ NO (v2.0) |
| **no-obsidian-installed** | Operator doesn't have Obsidian app installed yet | n/a | n/a | ✓ YES (skip-or-install prompt) |

## Detection — `detect-persona.sh` (v1.0)

Three signals, evaluated in AND-OR-of-counts:

1. **agency/ directory** present at repo root → `SIG_AGENCY=1`
2. **MEMORY.md frontmatter** contains structured `agency: "newearthai"` field → `SIG_FRONTMATTER=1` (replaces free-text "NewEarth" grep per EdgeCase B-1 amendment)
3. **git remote** matches `NewEarthAI/*` or `NewEarth-AI/*` → `SIG_REMOTE=1`

Classification:
- Sum 3 → `newearth-internal`
- Sum 2 → `newearth-internal` (signal strong; confirmation prompt is final gate)
- Sum 1 → `ambiguous` (operator must clarify)
- Sum 0 → `external` (v1.0 cannot proceed; deferred to v2.0)

## Confirmation Prompt — MANDATORY (council A8)

Detection alone is **NEVER** sufficient. After `detect-persona.sh` returns a classification, the skill ALWAYS prompts:

```
I think you are a [newearth-internal | external] operator because:
  - agency/ folder: [yes | no]
  - MEMORY.md agency: "newearthai" frontmatter: [yes | no]
  - git remote NewEarthAI/*: [yes | no]

Confirm this is correct?
  [y] yes — proceed
  [n] no — the detection is wrong
  [e] explain — describe your project briefly for re-detection
```

The operator's answer is cached in `.claude/obsidian-second-brain.local.md` under the `persona:` field. Subsequent Verify runs read the cached value AND re-challenge if git-remote-URL drifts (closes CRITICAL-2 stale-persona-after-repo-repurpose).

**Why this matters**: Council CRITICAL-1 identified the canonical failure — a template-adopter clones `BuyBox-AI` as a starter for their own property-tech venture. All 3 detection signals fire TRUE (agency/ present, MEMORY mentions NewEarth, remote is `NewEarthAI/BuyBox-AI`). Without explicit confirmation, the skill silently routes the external adopter's vault to the agency DB. Confirmation prompt eliminates this entire failure class at near-zero build cost.

## NewEarth-Internal Sub-Branches (v1.0 + future)

| Sub-branch | When | Vault target | DB target | v Ship |
|---|---|---|---|---|
| Hub (Agency-Main) | Repo is Agency-Main itself | `agency/vault/` | `supabase-newearthai` prod | v1.0 |
| Spoke — BuyBox | Repo is BuyBox-AI | `agency/vault/` inside BuyBox-AI | `supabase-dispodaddy` (BuyBox DB) | v1.2 |
| Spoke — Nirvana | Repo is Nirvana | `agency/vault/` inside Nirvana | `supabase-nirvana` | v1.2 |
| Spoke — GoodBuy | Repo is GoodBuy | TBD | TBD | v1.2 |
| Staging | Operator passes `--env=staging` | (same as hub) | `iqgsthdhkbkjpdqnfisu` (staging) | v1.1 |

v1.0 implements only the Hub sub-branch. Spoke routing requires:
- Spoke `EXPECTED_REF` plumbing per council A2 (read from `clients/<slug>/CLAUDE.md`)
- Spoke routing-guard parity per council A7
- Plist label parameterisation per council A1 (`com.newearthai.vault-sync.<slug>`)

These three items ship together in v1.2 alongside the spoke composition flag (Q4 resolution).

## External Adopter — Design Target for v2.0

Per council Q3 option (c) resolution: clean-exit on Supabase signup friction. v2.0 wizard:

1. Detect external persona via signal sum 0 OR confirmation override
2. Prompt vault path (default `~/Obsidian/<project-name>/`)
3. Prompt Supabase project ref (or option (c): "create your Supabase project at supabase.com, then re-run this skill")
4. Help operator add 1 keychain entry (their service-role JWT, via `security add-generic-password -w`)
5. Generate per-Mac plist with adopter's SUPABASE_URL + EXPECTED_REF substituted (council A9)
6. Bootstrap post-verify per council A9 (forced first sync after activator)
7. 7-check verification grid

No agency-specific code paths. No agency credentials. Cross-repo data routing doctrine enforced via persona-confirmation gate (A8).

## When This Reference Loads

- `scripts/detect-persona.sh` — uses signal table
- `SKILL.md` Bootstrap step 1 — uses confirmation prompt template
- `SKILL.md` Verify mode — uses re-challenge rule
- Future v1.2 spoke composition — uses NewEarth-internal sub-branch table
- Future v2.0 wizard — uses external adopter design target
