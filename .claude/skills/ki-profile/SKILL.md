---
name: ki-profile
description: |
  KI Pipeline profile update skill. Invoked via SSH-Execute when a CROSSREF action
  of type update_profile is approved. Reads current PROFILE.yaml, merges new learnings
  from KI content, and maintains the v2 schema structure.
  Use when: KI action_type is "update_profile".
version: 1.0
classification: encoded-preference
template_managed: true
---

# ki-profile — PROFILE.yaml Update

## Context

You are being invoked by the **KI (Knowledge Intelligence) pipeline**. A human approved a profile update action — meaning the KI content contains information that should be reflected in this project's PROFILE.yaml. This keeps the profile accurate so future CROSSREF scoring remains aligned with reality.

## Input Format

The prompt contains structured KI context:

```
[KI Job: KI-YYYYMMDD-XXXXXX] {title}

KI Context:
- Job: KI-YYYYMMDD-XXXXXX
- Source: {url}
- Crossref Score: {0-100}
- Action Type: update_profile
- Target: {profile_slug}

{description — what profile data should change and why}
```

## Instructions

1. **Find and read the current PROFILE.yaml** — Check these locations:
   - `clients/{slug}/PROFILE.yaml` (client projects)
   - `agency/profiles/{slug}.yaml` (agency profile)
   - `PROFILE.yaml` (root level)
2. **Identify what to update** based on the KI content:
   - `focus_areas` — New capabilities or focus shifts
   - `tech_stack` — New tools, libraries, or services adopted
   - `roadmap` — Completion percentage changes, new items, removed items
   - `pain_points` — New pain points discovered or existing ones resolved
   - `active_sprint` — Sprint focus changes
   - `platform_architecture` — Infrastructure or architecture changes
   - `cross_project_relationships` — New integrations or dependencies
3. **Make surgical edits** — Only change fields that the KI content directly informs. Don't rewrite sections that aren't affected.
4. **Update metadata**:
   - `last_full_sync` → current ISO timestamp
   - Add a comment noting the KI job that triggered the update

## Output Format

Output a fenced JSON block:

```json
{
  "status": "updated",
  "profile_path": "clients/{slug}/PROFILE.yaml",
  "fields_updated": [
    {
      "field": "roadmap.item_name",
      "old_value": "75%",
      "new_value": "90%",
      "reason": "KI content showed feature is nearly complete"
    }
  ],
  "fields_unchanged": "Brief note on why other fields weren't touched",
  "sync_timestamp": "2026-03-12T00:00:00Z"
}
```

## PROFILE.yaml v2 Schema Reference

Key sections (maintain this structure):
```yaml
entity:
  name, type, industry, status, description
focus_areas: [list]
tech_stack:
  core: [list]
  ai_ml: [list]
  infrastructure: [list]
roadmap:
  - name: "Item"
    completion: "75%"
    status: "in_progress"
pain_points: [list]
active_sprint:
  week_of: "YYYY-MM-DD"
  focus: "description"
  deliverables: [list]
platform_architecture:
  components: [list]
cross_project_relationships: [list]
last_full_sync: "ISO timestamp"
```

## Guidelines

- **Never delete existing data** unless it's explicitly outdated (e.g., a resolved pain point)
- Preserve YAML formatting and indentation style of the existing file
- If the KI content is ambiguous about what to update, be conservative — skip rather than guess
- Profile updates propagate to CROSSREF scoring, so accuracy matters more than completeness
- If PROFILE.yaml doesn't exist at the expected path, output an error status — don't create one from scratch
