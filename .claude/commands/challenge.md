---
description: "Pressure-test a belief or assumption against vault, ROADMAP, specs, and profiles"
argument-hint: "<belief or question to challenge> [--scope business|personal|all]"
---

# /challenge — Belief Pressure-Testing

Cross-reference a stated belief, assumption, or plan against everything in your vault, ROADMAP, specs, and venture profiles to find contradictions, conflicts, and blind spots.

**Invokes**: `obsidian-second-brain` skill (v2.0)

---

## What It Does

Takes a belief ("We should build NewClaw before finishing KI", "Agent marketplace is a good venture") and systematically searches for evidence that supports OR contradicts it. Produces a verdict with source citations.

---

## Process

### Step 0 — Resolve Vault
Read `.claude/obsidian-second-brain.local.md` for vault path. Verify exists. If not configured, fall back to repo-only mode.

### Step 1 — Parse the Challenge
Extract the belief/assumption from `$ARGUMENTS`.

If no argument: ask "What belief or assumption should I challenge?"

Examples:
- "We should build NewClaw before finishing KI"
- "Agent marketplace is a good venture"
- "We don't need a frontend for the agency"
- "The KI pipeline should use Gemini instead of OpenAI"

### Step 2 — Extract Search Terms
From the belief, identify 3-5 key concepts to search for. E.g., for "We should build NewClaw before finishing KI":
- Search terms: `NewClaw`, `KI`, `pipeline`, `execution runtime`, `knowledge intelligence`

### Step 3 — Gather Evidence (Parallel)

**Vault** (skip if no vault):
Search all VAULT_LOCATIONS paths matching the active `--scope` (default: `business`):
```
Grep: each search term across all scope-matching vault *.md files
Grep: #belief and #decision tags across scope-matching paths
```
Prioritize notes tagged `#belief` or `#decision` — these are explicit position statements.
Skip any VAULT_LOCATIONS folder that doesn't exist (no error).

**ROADMAP**:
```
Read: ROADMAP.md — check NOW/NEXT/LATER for related items
```
Look for dependency chains, sequencing, and stated prerequisites.

**Specs**:
```
Grep: each search term in specs/
```

**Profiles**:
```
Read: all PROFILE.yaml files
```
Check `pain_points`, `active_focus`, `roadmap` items that relate to the belief.

**Continuations**:
```
Grep: each search term in continuations/
```

### Step 4 — Analyze for Contradictions

Using the gathered evidence, analyze across 6 dimensions:

1. **DIRECT CONTRADICTIONS**: Where does existing documentation/thinking directly oppose this belief?
2. **DEPENDENCY CONFLICTS**: Does this belief require something that contradicts a stated dependency order?
3. **RESOURCE CONFLICTS**: Does pursuing this conflict with budget, timeline, or team capacity stated elsewhere?
4. **STRATEGIC MISALIGNMENT**: Does this align with or contradict the agency's stated direction?
5. **IMPLICIT ASSUMPTIONS**: What is this belief assuming that isn't explicitly validated?
6. **SUPPORTING EVIDENCE**: What evidence SUPPORTS this belief?

### Step 5 — Produce Challenge Report

```
CHALLENGE REPORT
━━━━━━━━━━━━━━━━
Belief: "{user's stated belief}"

VERDICT: {SUPPORTED | PARTIALLY SUPPORTED | CONTRADICTED | INSUFFICIENT EVIDENCE}

━━━ CONTRADICTIONS ({N} found) ━━━

#1 — {contradiction title}
  Source: {file path}:{line} — "{quote}"
  Conflict: {how this contradicts the belief}
  Severity: {minor | significant | critical}

#2 — ...

━━━ SUPPORTING EVIDENCE ({N} found) ━━━

#1 — {evidence title}
  Source: {file path}:{line} — "{quote}"
  Strength: {weak | moderate | strong}

#2 — ...

━━━ IMPLICIT ASSUMPTIONS ━━━

- {assumption 1}: {validated | unvalidated | contradicted}
- {assumption 2}: ...

━━━ RECOMMENDATION ━━━

{Based on the evidence, the belief is [supported/challenged/needs more data].
 Biggest risk if proceeding: {risk}.
 Suggested action: {what to do — proceed with caution / investigate further / revise belief / park until more data}.}
```

This command is **read-only** — it never modifies any files.

---

## Graceful Degradation

| Condition | Behavior |
|-----------|----------|
| No vault configured | Search repo only — ROADMAP, specs, profiles, continuations |
| Vault empty | Search repo only |
| No evidence found | Report "INSUFFICIENT EVIDENCE" — the belief can't be confirmed or denied with current documentation |
| Only supporting evidence | Report "SUPPORTED" but note "no contradictions found — consider whether you've documented counterarguments" |
