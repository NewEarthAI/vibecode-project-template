---
description: "Identify entity-aware idea clusters in the vault that are ready to become projects"
argument-hint: "[--threshold N] [--venture slug] [--scope business|personal|all]"
---

# /emerge — Entity-Aware Idea Cluster Identification

Finds clusters of related vault notes that have reached critical mass and are ready to become structured projects or venture proposals. Entity-aware: flags clusters spanning multiple entities as high strategic value.

**Invokes**: `obsidian-second-brain` skill (v2.0)

---

## What It Does

Reads ALL vault notes (not just recent — emergence is about accumulation), builds a relationship graph from tags and wikilinks, clusters related notes, and assesses which clusters are mature enough for graduation to structured specs.

---

## Process

### Step 0 — Resolve Vault
Read `.claude/obsidian-second-brain.local.md` for vault path. **Required** — this command needs vault content. If vault not configured or empty, report: "No vault content to cluster. Start writing and linking notes, then run /emerge."

### Step 1 — Parse Arguments
- `--threshold N` (default: 3) — minimum notes in a cluster to report it
- `--venture slug` (optional) — only show clusters relevant to this venture
- `--scope business|personal|all` (default: from config, falls back to `business`) — which vault areas to search

### Step 2 — Build Note Inventory (VAULT_LOCATIONS)

Read ALL vault notes matching the active scope using VAULT_LOCATIONS paths (excluding `.obsidian/` and `templates/`):
```
# Search all VAULT_LOCATIONS paths for the active scope
# For each existing folder in scope, glob *.md files
```

For each note, extract:
- **Title**: from first `# heading` or filename
- **Tags**: all `#tag/subtag` patterns
- **Wikilinks**: all `[[target]]` references
- **Frontmatter**: `created`, `status`, `venture` fields
- **Content preview**: first 300 chars (for topic detection)
- **Entity owner**: resolved via note ownership rules (folder → tag → keyword)

**Token guard**: For vaults with > 100 notes, read frontmatter + tags + wikilinks only (skip content preview for notes outside ideas/ and entity folders).

### Step 3 — Cluster Detection

Build clusters using three strategies, then merge:

**3A. Tag-based clustering**:
- Notes sharing 2+ tags (excluding common tags like `#daily`, `#idea`) are related
- Group them into tag-based clusters

**3B. Wikilink-based clustering**:
- Follow wikilink chains: if A links to B and B links to C, they form a cluster
- Bidirectional: if A links to B, B is in A's cluster even if B doesn't link back

**3C. Topic-based clustering** (using content previews):
- Identify notes mentioning the same specific concepts (not generic words)
- Notes discussing the same technology, venture idea, or problem

**3D. Entity-aware labeling**:
- For each cluster, check the entity owners of its notes
- **Single-entity cluster**: All notes belong to one entity → label with that entity
- **Cross-entity cluster**: Notes span 2+ entities → flag as **CROSS-ENTITY** (high strategic value)
- **General cluster**: All notes are unowned → label as general

**Merge**: Combine overlapping clusters. If two clusters share 2+ notes, merge them.

### Step 4 — Assess Cluster Maturity

For each cluster meeting the threshold:

| Dimension | Assessment | Scoring |
|-----------|-----------|---------|
| **Volume** | How many notes? | 3-5 = emerging, 6-10 = solid, 11+ = saturated |
| **Timespan** | First note to last note | < 7 days = flash, 7-30 = developing, 30+ = persistent |
| **Diversity** | What tag types present? | Ideas only = shallow, ideas+decisions+beliefs = deep |
| **Specificity** | Vague or actionable? | "should do AI" = vague, "per-agent pricing model" = specific |
| **Connectivity** | How linked internally? | Orphan notes = weak, dense links = strong |

**Maturity verdict**:
- **READY FOR GRADUATION**: Volume >= threshold, timespan > 14 days, has decisions/beliefs, specific enough to spec
- **STILL BREWING**: Volume >= threshold but missing specificity or decisions
- **DORMANT**: Met threshold historically but no activity in 30+ days

### Step 5 — ROADMAP Conflict Check

For each mature cluster:
```
Read: ROADMAP.md
```

Check:
- **Already in ROADMAP?** Match cluster topic against NOW/NEXT/LATER items
- **Conflicts with?** Would this cluster's project contradict any roadmap item?
- **Slot into?** Where would this naturally fit (NOW/NEXT/LATER)?
- **Dependencies?** What would need to exist first?

### Step 6 — Generate Venture Proposal (for READY clusters)

For clusters assessed as READY FOR GRADUATION:

```
VENTURE PROPOSAL: {cluster name}
  Type: {venture | project | feature | enhancement}
  Target: {existing venture slug | "new venture"}
  Core idea: {2-3 sentence synthesis of what this cluster represents}
  Estimated scope: {TRIVIAL | MODERATE | COMPLEX}
  Budget impact: {none | minimal (<$50/mo) | moderate ($50-200/mo) | significant (>$200/mo)}
  Dependencies: {what needs to exist first}
  Conflicts: {any ROADMAP conflicts detected}
  Next step: Run /graduate on this cluster
```

### Step 7 — Present Report

```
EMERGENCE REPORT
━━━━━━━━━━━━━━━━
Scope: {business|personal|all}
Notes inventoried: {total}
Clusters found: {total} ({ready} ready, {brewing} brewing, {dormant} dormant)
Cross-entity clusters: {N} (high strategic value)

━━━ READY FOR GRADUATION ━━━

CLUSTER 1: "{cluster name}" {CROSS-ENTITY if multi-entity}
  Entity scope: {entity slug | "cross-entity: slug-a × slug-b" | "general"}
  Notes: {N} spanning {timespan}
  Core notes:
    - {note title} [{path}] — {date} (owner: {entity})
    - {note title} [{path}] — {date} (owner: {entity})
  Tags: {shared tags}
  Maturity: Volume={rating} Timespan={rating} Diversity={rating} Specificity={rating}
  ROADMAP: {already listed | would slot into NEXT | conflicts with X}

  VENTURE PROPOSAL:
    {proposal block from Step 6}

CLUSTER 2: ...

━━━ STILL BREWING ━━━

- "{cluster name}" — {N} notes, needs: {what's missing — specificity? decisions? time?}

━━━ DORMANT ━━━

- "{cluster name}" — {N} notes, last activity: {date}. Revive or archive?

━━━ ORPHAN IDEAS (no cluster) ━━━

- {note title} [{path}] — {date} — no connections to other notes
  Suggestion: {add tags | link to related notes | develop further}
```

Offer: "Run `/graduate` on Cluster N? (enter cluster number or 'skip')"

This command is **read-only** — it never modifies any files.

---

## Graceful Degradation

| Condition | Behavior |
|-----------|----------|
| No vault configured | STOP — this command requires vault content |
| < 5 vault notes | Warn "Too few notes for meaningful clusters" but proceed |
| No clusters found | Report "No clusters detected — notes may need more cross-linking" |
| No ROADMAP.md | Skip conflict check, note it in report |
| Only orphan ideas | Report all as orphans, suggest tagging/linking strategies |
