---
description: "Promote vault fragments to structured spec and trigger KI research pipeline"
argument-hint: <note path or topic name>
---

# /graduate — Vault-to-KI Bridge

The key pipeline command. Promotes raw vault content to structured specs, tags source notes, assesses PROFILE.yaml impact, and optionally triggers the KI research pipeline.

**Invokes**: `obsidian-second-brain` skill (v2.0)

**Full pipeline**: raw thought → structured spec → KI ingest → crossref → proposed actions → WhatsApp + vault deposit

---

## What It Does

Takes one or more vault notes (specified by path, topic, or cluster from /emerge), synthesizes them into a structured specification, writes it to both the vault and repo, and optionally triggers W-KI-INGEST for full pipeline processing.

---

## Process

### Step 0 — Resolve Vault
Read `.claude/obsidian-second-brain.local.md` for vault path. **Required** — this command creates files in the vault.

### Step 1 — Identify Source Material

Based on `$ARGUMENTS`:

**If file path** (e.g., `ideas/agent-marketplace.md`):
- Read that specific vault note

**If topic** (e.g., `"agent marketplace"`):
- Search vault for the topic (keyword + tags + wikilinks)
- Present matching notes
- Ask: "Which notes should I graduate? (enter numbers, or 'all')"

**If cluster reference from /emerge** (e.g., `cluster 1` or `"Agent Marketplace cluster"`):
- Read all notes identified in that cluster

**If no argument**:
- Ask: "What should I graduate? Provide a note path, topic name, or say '/emerge' to find clusters first."

### Step 2 — Read & Preserve Source Notes

For each source note:
- Read full content
- Extract frontmatter (created date, tags, existing links)
- Preserve attribution: which note contributed what content

### Step 3 — Generate Structured Spec

Synthesize the source notes into a structured document:

```markdown
---
created: {today ISO}
source: vault-graduation
source_notes:
  - {path to source note 1}
  - {path to source note 2}
status: graduated
tags: [graduated, {venture tags from sources}]
---

# {Clear, Descriptive Title}

## Problem Statement
{What problem does this solve? Synthesized from source notes.}

## Proposed Solution
{What is the idea? Core concept distilled from all source material.}

## Strategic Alignment
{How does this fit with NewEarth AI's mission and active roadmap?}

## Key Decisions Made
{Any decisions extracted from source notes tagged #decision}

## Open Questions
{Unresolved questions from source notes, plus new ones identified during synthesis}

## Scope Estimate
{TRIVIAL | MODERATE | COMPLEX — with brief justification}

## Suggested Next Steps
1. {First actionable step}
2. {Second step}
3. ...
```

### Step 4 — Write Graduated Spec

**Two locations** (entity-aware):
1. **Vault**: Write to entity folder if source note is entity-owned, otherwise general:
   - Entity-owned: `{vault_path}/NewEarth AI/ventures/{slug}/graduated/{kebab-case-title}-spec.md`
   - General: `{vault_path}/graduated/{kebab-case-title}-spec.md`
   - Create `graduated/` subfolder inside entity folder on first use
2. **Repo**: `specs/{kebab-case-title}.md`

Both get the same content.

### Step 5 — Tag Source Notes

For each source note, update it:
- Add `#graduated` tag to frontmatter tags array
- Add `#status/graduated` tag
- Append wikilink: `\n\n> Graduated to [[graduated/{spec-name}-spec]] on {date}`
- If note had `#status/raw` or `#status/evolving`, replace with `#status/graduated`

### Step 6 — PROFILE.yaml Impact Assessment

Read all PROFILE.yaml files. For each profile, check:
- Does the graduated idea introduce new keywords not in `keywords.*`?
- Does it relate to any `active_focus` item?
- Does it address any `pain_points`?
- Does it affect the `roadmap`?

Present proposals (do NOT auto-modify):

```
PROFILE IMPACT:
  {venture-1-slug}: Add keyword "agent marketplace" to keywords.strategic
  {your-org-slug}: Add active_focus item "Agent marketplace exploration"
  No impact: {client-1-slug}, {venture-2-slug}, {venture-3-slug}
```

### Step 7 — KI Pipeline Trigger (Optional)

Check if `ki_ingest_webhook` parameter is configured (non-empty).

If configured, present:
```
This graduation could benefit from KI research.

Trigger W-KI-INGEST with:
  job_id: KI-{YYYYMMDD}-{6random}
  source_type: vault_graduation
  Content: {spec title} ({word count} words)

This will:
  1. Summarize and extract takeaways from the graduated spec
  2. Cross-reference against all 9 venture profiles
  3. Propose actions via WhatsApp

Trigger KI research? (y/n)
```

**If yes**:
1. Generate job_id: `KI-{YYYYMMDD}-{6 random alphanumeric}`
2. Create `knowledge_items` record via Supabase MCP:
   ```sql
   INSERT INTO knowledge_items (job_id, source_url, source_type, status, ingested_at)
   VALUES ('{job_id}', 'obsidian://graduated/{spec-name}', 'vault_graduation', 'pending', NOW());
   ```
3. Note: The actual webhook POST to W-KI-INGEST with embedded content would be done via n8n MCP or curl. If neither is available, create the Supabase record and flag for manual processing.

**If no**: Skip. The spec exists locally and can be triggered later.

**If webhook not configured**: Report "KI trigger not configured. Spec created locally only."

### Step 8 — Report

```
GRADUATION COMPLETE
━━━━━━━━━━━━━━━━━━
Source notes graduated: {N}
  - {note1 path} → tagged #graduated
  - {note2 path} → tagged #graduated

Spec created:
  Vault: graduated/{name}-spec.md
  Repo:  specs/{name}.md

PROFILE proposals: {N} suggested changes (not applied)
  {list}

KI pipeline: {triggered (job_id: KI-...) | skipped by user | not configured}

Next steps:
  - Review the spec: specs/{name}.md
  - Apply PROFILE changes if you agree (manual)
  - Track KI processing: check knowledge_items for job_id {id}
```

---

## Graceful Degradation

| Condition | Behavior |
|-----------|----------|
| No vault configured | STOP — this command requires vault access |
| Source note not found | Report "Note not found at {path}" |
| No PROFILE.yaml files | Skip Step 6 (impact assessment) |
| KI webhook not configured | Skip Step 7, create spec locally only |
| Supabase MCP unavailable | Skip KI record creation, create spec locally |
| Source note has no frontmatter | Still graduate, but warn "Note has no frontmatter — adding tags to content instead" |
