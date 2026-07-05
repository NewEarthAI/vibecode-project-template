---
description: "Track how an idea evolved over time across vault notes, ROADMAP, and specs"
argument-hint: "<topic or tag name> [--scope business|personal|all]"
---

# /trace — Idea Evolution Timeline

Track the evolution of an idea, concept, or project across your Obsidian vault, ROADMAP, specs, and git history. Shows how thinking changed over time with strategic impact assessment.

**Invokes**: `obsidian-second-brain` skill (v2.0)

---

## What It Does

Given a topic, finds every mention across:
- Obsidian vault (all VAULT_LOCATIONS matching active scope — entity folders + content-type folders)
- Repo content (specs/, continuations/, ROADMAP.md)
- Git history (commit messages, ROADMAP diffs)

Orders everything chronologically and produces an evolution timeline with maturity assessment.

---

## Process

### Step 0 — Resolve Vault
Read `.claude/obsidian-second-brain.local.md` for vault path. Verify exists. If not configured, fall back to repo-only mode.

### Step 1 — Parse Argument
Extract topic from `$ARGUMENTS`. Accept any of:
- Tag name: `agent-marketplace` → searches for `#topic/agent-marketplace`
- Keyword phrase: `"ki pipeline"` → full-text search
- Wikilink target: `Agent Marketplace` → searches for `[[Agent Marketplace]]`

If no argument provided, ask: "What topic should I trace?"

### Step 2 — Search (Parallel)

**Vault search** (skip if no vault configured):
Search all VAULT_LOCATIONS paths matching the active `--scope` (default: `business`):
```
Grep: {keyword} across all scope-matching vault *.md files
Grep: #topic/{arg} tag
Grep: [[{arg}]] wikilinks
```

**Repo search**:
```
Grep: {keyword} in specs/
Grep: {keyword} in continuations/
Read: ROADMAP.md — find sections mentioning the topic
```

**Git search**:
```bash
git log --all --oneline --grep="{keyword}" -- ROADMAP.md specs/ continuations/
```

### Step 3 — Read & Extract
For each matching note/file:
- **Date**: from frontmatter `created:`, filename (if daily note `YYYY-MM-DD.md`), or git commit date
- **Key quotes**: 2-3 most relevant lines mentioning the topic
- **Tags**: all tags on the note
- **Wikilinks**: connections to other notes
- **ROADMAP state**: was this NOW, NEXT, or LATER at time of mention?

### Step 4 — Build Timeline
Order all findings chronologically. Group by week/month if span > 30 days.

### Step 5 — Assess & Present

```
IDEA EVOLUTION: {topic}
━━━━━━━━━━━━━━━━━━━━━━

{date} — {note title} [{source path}]
  "{key quote}"
  Tags: {tags}
  Connected to: {wikilinks or related files}
  ROADMAP state: {not mentioned / LATER / NEXT / NOW / COMPLETED}

{date} — {next entry}...

━━━━━━━━━━━━━━━━━━━━━━
EVOLUTION SUMMARY
━━━━━━━━━━━━━━━━━━━━━━
First mentioned:  {date}
Last mentioned:   {date}
Total mentions:   {N} across {M} sources
Phase transitions: {LATER→NEXT on date, NEXT→NOW on date, etc.}
Connected themes:  {other topics that frequently co-occur}

MATURITY ASSESSMENT:
  Stage: {raw idea | evolving | ready for action | implemented | abandoned}
  Momentum: {gaining | stable | losing} (based on mention frequency over time)
  Recommendation: {continue exploring | ready for /graduate | ready for /emerge | park it}
```

This command is **read-only** — it never modifies any files.

---

## Graceful Degradation

| Condition | Behavior |
|-----------|----------|
| No vault configured | Search repo only, note "vault not configured" |
| Vault empty | Search repo only, note "no vault notes found" |
| No matches anywhere | Report "No evolution found for '{topic}'" |
| Topic only in ROADMAP | Show ROADMAP-only timeline with git history |
