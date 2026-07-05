---
description: "Pull pending KI research findings into the Obsidian vault"
---

# /vault-sync — KI Research Deposit Pull

Queries Supabase for pending `vault_deposit` actions from the KI pipeline and writes them as research notes in the Obsidian vault.

**Invokes**: `obsidian-second-brain` skill (v2.0)

---

## What It Does

The reverse of /graduate. When the KI pipeline processes content and finds high-relevance items (score > 0.7), it creates `vault_deposit` actions in Supabase. This command pulls those pending deposits and writes them as research notes in the vault.

**Pull model**: n8n Cloud can't write to local filesystem, so KI findings are stored in Supabase and pulled locally by this command.

**Dependency note**: `vault_deposit` actions are PROPOSED by W-KI-CROSSREF but depend on KI Phase 5 (action execution) for automatic creation. Until Phase 5 is live, deposits must be manually proposed or this command can query high-relevance knowledge_items directly.

---

## Process

### Step 0 — Resolve Vault
Read `.claude/obsidian-second-brain.local.md` for vault path. **Required**.

### Step 1 — Query Pending Deposits

**Primary query** (when Phase 5 is live):
```sql
SELECT ka.id, ka.job_id, ka.action_type, ka.title, ka.description,
       ka.target_slug, ka.priority, ka.status,
       ki.source_url, ki.source_type, ki.summary, ki.key_takeaways,
       ki.relevance_scores
FROM knowledge_actions ka
JOIN knowledge_items ki ON ka.job_id = ki.job_id
WHERE ka.action_type = 'vault_deposit'
  AND ka.status = 'proposed'
ORDER BY ka.created_at DESC
LIMIT 20;
```

**Fallback query** (before Phase 5 — find high-relevance items without vault_deposit actions):
```sql
SELECT job_id, source_url, source_type, title, summary, key_takeaways,
       relevance_scores, processed_at
FROM knowledge_items
WHERE status IN ('delivered', 'cross_referenced')
ORDER BY processed_at DESC
LIMIT 10;
```

Run via your project's Supabase MCP `execute_sql`.

### Step 2 — Present Findings

```
VAULT SYNC — {N} pending deposits

#1: "{title}" (job_id: {job_id})
    Source: {source_type} — {source_url}
    Relevance: {top venture}: {score}
    Action: {description}

#2: ...

Write all to vault? (y/select numbers/skip)
```

### Step 3 — Generate Vault Notes

For each approved deposit, create a research note:

```markdown
---
created: {today ISO}
source: ki-pipeline
job_id: {job_id}
source_type: {youtube|web_url|github_repo|vault_graduation}
source_url: {original source URL}
relevance_score: {highest score}
target_venture: {highest-scoring venture slug}
status: deposited
tags: [ki/{job_id}, venture/{target_slug}, research]
---

# Research: {title}

> KI Pipeline finding — deposited {date}
> Relevance to {venture}: {score}

## Summary
{summary from knowledge_items}

## Key Takeaways
{key_takeaways formatted as bullet points}

## Proposed Actions
{actions targeting this venture, from knowledge_actions}

## Connection Points
{Search vault for related topics, add wikilinks if found}
```

### Step 4 — Write to Vault (Entity-Aware)

Write each note to the entity folder if `target_slug` identifies an entity, otherwise general:
- **Entity-owned**: `{vault_path}/NewEarth AI/ventures/{target_slug}/research/KI-{job_id}-{topic-slug}.md`
- **Client-owned**: `{vault_path}/NewEarth AI/Clients/{target_slug}/research/KI-{job_id}-{topic-slug}.md`
- **General/Agency**: `{vault_path}/research/KI-{job_id}-{topic-slug}.md`

Create `research/` subfolder inside entity folder on first use.

### Step 5 — Update MOC

Append to `{vault_path}/MOC/research-moc.md`:
```
- [[../research/KI-{job_id}-{slug}|{title}]] — {1-line} ({date})
```

### Step 6 — Mark as Completed

Update Supabase (only for vault_deposit actions, not fallback query items):
```sql
UPDATE knowledge_actions
SET status = 'completed', completed_at = NOW()
WHERE id IN ({ids of synced actions});
```

### Step 7 — Report

```
VAULT SYNC COMPLETE
━━━━━━━━━━━━━━━━━━
Deposits written: {N}
  - research/KI-{job_id}-{slug}.md → {venture}
  - research/KI-{job_id}-{slug}.md → {venture}

MOC updated: research-moc.md (+{N} entries)
Actions marked completed: {N}

No pending deposits remaining.
```

---

## Graceful Degradation

| Condition | Behavior |
|-----------|----------|
| No vault configured | STOP — needs vault to write notes |
| Supabase MCP unavailable | STOP — needs database access to query deposits |
| No pending deposits | Report "No pending vault deposits. KI pipeline hasn't flagged any high-relevance items." |
| knowledge_actions table missing vault_deposit type | Use fallback query against knowledge_items directly |
| MOC file doesn't exist | Create it with header, then append |
