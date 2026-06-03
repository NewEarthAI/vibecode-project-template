---
name: obsidian-second-brain
description: |
  Core vault operations for the Obsidian Second Brain layer. Provides vault discovery,
  note search (tag/keyword/date/wikilink), frontmatter parsing, note creation, MOC
  updates, and KI pipeline bridge. Backs 7 commands: /trace (idea evolution), /drift
  (two-pass pattern detection), /emerge (entity-aware cluster identification), /graduate
  (promotion to spec + KI trigger), /challenge (contradiction detection), /vault-sync
  (KI deposit pull), /vault-review (cadence orchestrator).
  Supports hybrid vault structure (entity-first + content-type folders), scope filtering
  (business/personal/all), and note ownership resolution.
  Use when: "vault", "obsidian", "daily notes", "second brain", "trace idea",
  "find patterns in notes", "graduate note", "challenge assumption".
version: 2.0
classification: encoded-preference
created: 2026-03-06
updated: 2026-03-10
template_managed: false
parameters:
  - name: vault_path
    type: path
    description: |
      Absolute path to the Obsidian vault root. Read from per-machine config:
      .claude/obsidian-second-brain.local.md (YAML frontmatter vault_path field).
      Each Mac has its own config. Never hardcode.
  - name: profile_dir
    type: path
    default: "clients"
    description: "Path to PROFILE.yaml files relative to repo root (clients/ and agency/profiles/)"
  - name: ki_ingest_webhook
    type: string
    default: ""
    description: "W-KI-INGEST webhook URL for graduation pipeline. Empty = KI trigger disabled."
  - name: relevance_threshold
    type: number
    default: 0.7
    description: "Minimum relevance score for KI->vault reverse deposits"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, TodoWrite
validated_on:
  - "Vault with hybrid structure (entity-first + content-type folders)"
  - "Works with empty vault (graceful degradation — reports 'no vault notes found')"
  - "Works across multiple Macs via per-machine config file"
  - "Scope filtering correctly isolates business/personal/all notes"
---

# Obsidian Second Brain

Provides vault access utilities for all `/trace`, `/drift`, `/emerge`, `/graduate`, `/challenge`, and `/vault-sync` commands.

**Setup**: Create `.claude/obsidian-second-brain.local.md` with YAML frontmatter:
```yaml
---
vault_path: "/Users/yourname/Documents/Obsidian Vault"
---
```

---

## Step 0 — Resolve Vault Path

Every command invocation starts here:

1. Read `.claude/obsidian-second-brain.local.md` — extract `vault_path` from YAML frontmatter
2. If file not found: report "No vault config. Create `.claude/obsidian-second-brain.local.md` with vault_path in frontmatter." and STOP
3. Expand `~` to `$HOME` if present
4. Verify directory exists: `ls {resolved_path}/` — if not found, report and STOP
5. Count notes: `find {resolved_path} -name "*.md" -not -path "*/.obsidian/*" | wc -l`
6. If < 5 notes: warn "Vault has {N} notes. Commands work best with 2+ weeks of daily writing."

**Store resolved path** for use in subsequent steps. Never re-read the config mid-command.

Also read `default_scope` from the config (default: `business` if not specified).

---

## VAULT_LOCATIONS — Search Path Registry

The vault uses a hybrid structure: content-type folders (`daily/`, `ideas/`) AND entity-first folders (`{OrgName}/ventures/{slug}/`). This registry maps logical categories to actual paths so all commands search comprehensively.

```yaml
VAULT_LOCATIONS:
  business_content:    # Content-type folders (general business notes)
    - daily/
    - ideas/
    - strategy/
    - research/
    - graduated/
  business_entities:   # Entity-first folders (venture/client-specific notes)
    # CUSTOMIZE: Replace with your org name, ventures, and clients
    # - {OrgName}/ventures/{venture-slug}/
    # - {OrgName}/Clients/{client-slug}/
    # - {OrgName}/          # Org-level notes (direct children only)
  personal:
    - Personal/
  meta:                # Not searched by commands (Obsidian infrastructure)
    - MOC/
    - templates/
```

**How commands use this**: Instead of hardcoding paths like `find {vault_path}/ideas`, commands resolve paths from VAULT_LOCATIONS based on the active scope. If a folder doesn't exist yet, skip it gracefully (no error).

**Adding new entities**: When a new venture or client is added, update the `business_entities` list here. Commands will automatically discover notes in the new folder.

---

## Note Ownership Resolution

Determines which entity a note "belongs to" for two-pass analysis and entity-aware clustering:

1. **Folder** (highest priority): Note path contains an entity folder → owned by that entity
   - `{OrgName}/ventures/{slug}/idea.md` → owned by `{slug}`
   - `{OrgName}/Clients/{slug}/notes.md` → owned by `{slug}`
   - `{OrgName}/meeting-notes.md` → owned by org (top level)
2. **Tag**: Note has `#venture/{slug}` or `#client/{slug}` tag → owned by that entity
   - A note in `ideas/` tagged `#venture/{slug}` → owned by `{slug}`
3. **Keyword** (soft): Note body mentions entity name → soft association (used for cross-referencing, not ownership)
4. **Personal**: Note in `Personal/` → scope `personal` (excluded from business analysis unless `--scope all`)
5. **Unowned**: Note in `daily/`, `ideas/`, etc. with no entity tags → general business (included in all business analysis, not attributed to any specific entity)

**Resolution order**: Folder beats tag beats keyword. A note can only have ONE owner but can have soft associations with multiple entities.

---

## Scope Filtering — `--scope` Flag

All vault commands accept `--scope` to control which notes are included:

| Flag | Searches | Use Case |
|------|----------|----------|
| `--scope business` | `business_content` + `business_entities` | Default — all work-related notes |
| `--scope personal` | `personal` only | Personal reflection without business context |
| `--scope all` | Everything except `meta` | Full vault analysis including personal |

**Default**: Read from `default_scope` in `.claude/obsidian-second-brain.local.md` (falls back to `business`).

**Implementation**: Commands load notes from VAULT_LOCATIONS paths matching the active scope, then filter results. Missing folders are silently skipped.

---

## Step 1 — Note Search

Search the vault by multiple strategies (use whichever the calling command needs):

### 1A. By keyword
```bash
Grep pattern="{keyword}" path="{vault_path}" glob="*.md"
```
Returns file paths + matching lines. Exclude `.obsidian/` directory.

### 1B. By tag
```bash
Grep pattern="#tag/{subtag}" path="{vault_path}" glob="*.md"
```
Tags use the `#namespace/value` convention: `#venture/{slug}`, `#topic/{name}`, `#status/graduated`.

### 1C. By wikilink
```bash
Grep pattern="\[\[{target}\]\]" path="{vault_path}" glob="*.md"
```

### 1D. By date range (daily notes)
```bash
Glob pattern="daily/YYYY-MM-*.md" path="{vault_path}"
```
Filter results by filename date within the requested range.

### 1E. By modification time
```bash
find {vault_path}/{subfolder} -name "*.md" -mtime -{days}
```

---

## Step 2 — Frontmatter Parsing

Every vault note should have YAML frontmatter. Extract it:

1. Read the note file
2. Extract content between first `---` and second `---`
3. Parse YAML fields: `created`, `tags`, `status`, `venture`, etc.
4. If no frontmatter: treat as unstructured note (still searchable by content)

---

## Step 3 — Profile Loading

Load venture profiles for cross-referencing:

```bash
Glob pattern="clients/*/PROFILE.yaml" path="{repo_root}"
Glob pattern="agency/profiles/*.yaml" path="{repo_root}"
```

Read each PROFILE.yaml. Extract for comparison:
- `keywords.core`, `keywords.technical`, `keywords.strategic`
- `active_focus` items
- `pain_points` list
- `roadmap.now` items
- `slug` for venture identification

---

## Step 4 — Note Creation

When writing new vault notes (used by /graduate, /vault-sync):

1. Generate frontmatter with: `created`, `tags`, `status`, `source` (if KI deposit), `owner` (entity slug if applicable)
2. **Determine write location** using note ownership:
   - If note is entity-owned (from entity folder or has entity tag), write to entity subfolder:
     - `{vault_path}/{OrgName}/ventures/{slug}/graduated/{name}-spec.md`
     - `{vault_path}/{OrgName}/ventures/{slug}/research/KI-{job_id}-{topic}.md`
   - If note is general (no entity ownership), write to content-type folder:
     - Ideas: `{vault_path}/ideas/{kebab-case-title}.md`
     - Graduated: `{vault_path}/graduated/{kebab-case-title}-spec.md`
     - Research deposits: `{vault_path}/research/KI-{job_id}-{topic-slug}.md`
   - Create subfolders (graduated/, research/) inside entity folders on first use
3. Use wikilinks for connections: `[[related-note]]`
4. Append entry to relevant MOC file

**NEVER** modify files in `{vault_path}/.obsidian/` — that's Obsidian's config directory.

---

## Step 5 — MOC Update

When creating a new note that should appear in a Map of Content:

1. Determine which MOC: `ideas-moc.md` (ideas), `research-moc.md` (KI deposits), `ventures-moc.md` (venture notes)
2. Read the MOC file
3. Append a wikilink entry: `- [[../path/to/note|Display Title]] — {1-line description} ({date})`
4. Write the updated MOC

---

## Step 6 — KI Bridge (used by /graduate)

Format vault content for W-KI-INGEST webhook:

```json
{
  "job_id": "KI-{YYYYMMDD}-{6alphanum}",
  "source_url": "obsidian://graduated/{spec-name}",
  "source_type": "vault_graduation",
  "content": "{full graduated spec content}",
  "vault_metadata": {
    "source_notes": ["daily/2026-03-01.md", "ideas/topic.md"],
    "graduated_at": "{ISO timestamp}",
    "tags": ["#venture/slug", "#graduated"]
  }
}
```

Generate job_id: `KI-` + today's date `YYYYMMDD` + `-` + 6 random alphanumeric chars.

**POST** to `{{ki_ingest_webhook}}` only when:
- Parameter is non-empty
- User explicitly approves the KI trigger
- Content has been graduated (not raw notes)

---

## Tagging Conventions

All commands should use these tag namespaces consistently:

| Tag | Purpose | Example |
|-----|---------|---------|
| `#venture/{slug}` | Links note to a venture | `#venture/my-project` |
| `#topic/{name}` | Topic thread (for /trace) | `#topic/agent-marketplace` |
| `#ki/{job_id}` | KI pipeline link | `#ki/KI-20260306-a7b3x9` |
| `#status/{state}` | Lifecycle tracking | `#status/raw`, `#status/evolving`, `#status/graduated`, `#status/abandoned` |
| `#idea` | Raw idea | `#idea` |
| `#brainstorm` | Brainstorm session | `#brainstorm` |
| `#decision` | Decision record | `#decision` |
| `#belief` | Testable belief/assumption (for /challenge) | `#belief` |
| `#priority/{level}` | Priority annotation | `#priority/high` |
| `#daily` | Daily note | `#daily` |

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Hardcode vault path | Different per Mac | Read from `.claude/obsidian-second-brain.local.md` |
| Hardcode search paths | Misses entity folders | Use VAULT_LOCATIONS registry |
| Read entire vault at once | Token explosion for large vaults | Search by tag/date/keyword first, read targeted notes |
| Modify `.obsidian/` config | Breaks Obsidian app settings | Only touch `.md` files in the vault |
| Create deeply nested folders | Obsidian works best flat-ish | Max 2 levels inside entity folders |
| Assume daily notes exist | User may not write daily | Graceful degradation: report "no notes found in range" |
| Write notes without frontmatter | Notes become unsearchable by metadata | Every note gets YAML frontmatter |
| Use absolute paths in wikilinks | Breaks when vault moves | Use relative `[[note-name]]` wikilinks |
| POST to KI without user approval | Unexpected pipeline triggers | Always ask before triggering /graduate → KI |
| Ignore empty vault | Confusing errors | Count notes in Step 0, warn clearly if < 5 |
| Mix personal and business without scope | Leaks context between domains | Always respect `--scope` flag |
| Error on missing folder | Entity folders may not exist yet | Skip missing folders silently |

---

*Skill version: 2.0 | Template-managed | Created 2026-03-06 | Updated 2026-04-13*
