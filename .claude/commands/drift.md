---
description: "Surface recurring themes across vault notes using two-pass analysis (intra-entity then cross-entity)"
argument-hint: "[--days N] [--venture slug] [--scope business|personal|all]"
---

# /drift — Two-Pass Subconscious Pattern Detection

Scans recent vault notes using a two-pass architecture: first surfaces themes within each entity independently, then synthesizes cross-entity patterns. Uses VAULT_LOCATIONS from the obsidian-second-brain skill to search all folders (entity-first and content-type).

**Invokes**: `obsidian-second-brain` skill (v2.0)

---

## What It Does

Reads recent notes across ALL vault locations (entity folders + content-type folders). Uses two-pass analysis:
1. **Pass 1 (Intra-entity)**: For each entity, surfaces themes within that entity's notes independently
2. **Pass 2 (Cross-entity)**: Compares themes across entities to find strategic connections and cross-pollination opportunities

This architecture reveals both "what's on your mind for BuyBox" AND "what patterns connect BuyBox thinking to Nirvana thinking."

---

## Process

### Step 0 — Resolve Vault
Read `.claude/obsidian-second-brain.local.md` for vault path. **Required** — this command needs vault content. If vault not configured or empty, report: "No vault content to analyze. Start writing daily notes for 2+ weeks, then run /drift again."

### Step 1 — Parse Arguments
- `--days N` (default: 30) — how far back to look
- `--venture slug` (optional) — only show drifts relevant to this venture
- `--scope business|personal|all` (default: from config, falls back to `business`) — which vault areas to search

### Step 2 — Collect Recent Notes (VAULT_LOCATIONS)

Use VAULT_LOCATIONS from the obsidian-second-brain skill to search all paths matching the active scope. For each path that exists, find notes modified within the date range:

**Content-type folders** (daily/, ideas/, strategy/, research/, graduated/):
```
Glob: {folder}/YYYY-MM-*.md files (for daily/)
find {vault_path}/{folder} -name "*.md" -mtime -{days} (for others)
```

**Entity folders** ({org-folder}/ventures/*, {org-folder}/clients/*, {org-folder}/)::
```bash
find "{vault_path}/{org-folder}/ventures/{venture-slug}" -name "*.md" -mtime -{days}
find "{vault_path}/{org-folder}/clients/{client-slug}" -name "*.md" -mtime -{days}
# ... for each entity folder that exists
```

**Personal** (only if `--scope personal` or `--scope all`):
```bash
find "{vault_path}/Personal" -name "*.md" -mtime -{days}
```

Skip any folder that doesn't exist (no error). Apply note ownership resolution to tag each note with its entity owner.

### Step 3 — Read Notes
Read all qualifying notes. For each:
- Strip YAML frontmatter
- Preserve source attribution (note path)
- Track total word count

**Token guard**: If total corpus exceeds ~50 notes, summarize older notes to first 200 chars each. Prioritize the most recent 20 notes in full.

### Step 4 — Load Profiles

Load all PROFILE.yaml files for context:
```
Glob: clients/*/PROFILE.yaml
Glob: agency/profiles/*.yaml
```

Extract `keywords`, `active_focus`, `pain_points`, `roadmap` for each profile. This context enriches both passes.

### Step 5 — Pass 1: Intra-Entity Theme Detection

For each entity that has notes in the corpus, analyze INDEPENDENTLY:

**Group notes by entity owner** (from Step 2 ownership resolution). Entities with < 2 notes get folded into "general" group. Also create a "general" group for unowned notes from `daily/`, `ideas/`, etc.

**For each entity group**, identify patterns:

**What to look for**:
- Concepts mentioned 3+ times across different notes (not just within one note)
- Questions asked repeatedly in different contexts
- Problems described from multiple angles without resolution
- Technologies or tools mentioned alongside different projects
- Strategic patterns (always gravitating toward X, repeatedly questioning Y)
- Emotional signals (frustration, excitement, curiosity around a topic)

**For each theme detected**:
- Name it (2-4 words)
- List source notes where it appears (with dates)
- Quote 2-3 key phrases
- Classify: **conscious** (writer explicitly names/tags it) vs **subconscious** (appears without writer connecting the dots)
- Cross-reference against that entity's PROFILE.yaml for alignment scoring

**If `--venture slug` was provided**: Only analyze that entity's group + general notes.

### Step 6 — Pass 2: Cross-Entity Synthesis

After completing Pass 1 for all entities, compare themes ACROSS entities:

**What to look for**:
- **Parallel themes**: Different entities circling the same concept independently (e.g., BuyBox mentions "scoring model" and Nirvana mentions "rating algorithm" — same underlying pattern)
- **Strategic connections**: Theme in one entity could solve a pain point in another
- **Shared infrastructure**: Multiple entities needing similar capabilities (shared tooling opportunity)
- **Tension points**: Where one entity's direction conflicts with another's

**For each cross-entity pattern**:
- Name the connection
- List which entities are involved and what their independent themes were
- Assess: Is this a **synergy** (work together), **shared need** (build once, use many), or **tension** (competing priorities)?
- Suggest action: align roadmaps, share solution, resolve conflict

### Step 7 — Produce Drift Report

```
DRIFT ANALYSIS — Last {N} days
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Scope: {business|personal|all}
Notes analyzed: {count} ({word count} words)
Entities: {list of entities with note counts}

━━━ PASS 1: INTRA-ENTITY THEMES ━━━

── {Entity Name} ({N} notes) ──

THEME 1: "{theme name}"
  Frequency: {N} mentions across {M} notes
  Conscious: {yes — writer tags/names this | no — appears without explicit connection}
  Notes:
    - {date} — {note title} [{path}]
    - {date} — {note title} [{path}]
  Key phrases: "{quote 1}", "{quote 2}", "{quote 3}"
  Profile alignment: {matched keywords/focus items, or "no profile match"}
  Suggestion: {explore with /trace | create a dedicated note | ready for /emerge | add to ROADMAP}

── {Next Entity} ({N} notes) ──
  ...

── General (unowned notes) ──
  ...

━━━ PASS 2: CROSS-ENTITY PATTERNS ━━━

CONNECTION 1: "{connection name}"
  Entities: {entity A} × {entity B}
  Pattern: {what they share or how they connect}
  Type: {synergy | shared need | tension}
  Action: {align roadmaps | build shared solution | resolve conflict | investigate further}

CONNECTION 2: ...

━━━ UNOWNED DRIFTS (no entity or profile match) ━━━

- "{theme}" — {N} mentions, no existing entity or profile match
  Potential: {new venture idea? personal interest? market signal? noise?}

━━━ DRIFT HEALTH ━━━
  Active drifts (3+ mentions, last 7 days): {N}
  Fading drifts (3+ mentions, none in last 14 days): {N}
  New signals (first appearance in last 7 days): {N}
  Cross-entity connections: {N}
```

This command is **read-only** — it never modifies any files.

---

## Graceful Degradation

| Condition | Behavior |
|-----------|----------|
| No vault configured | STOP — this command requires vault content |
| < 5 vault notes | Warn "Low sample size — drifts may not be meaningful" but proceed |
| No PROFILE.yaml files | Skip cross-reference step, report themes without venture matching |
| No themes detected | Report "No recurring themes found — try a longer time range or write more notes" |
