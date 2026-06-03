# Role Discovery — classify folders by content, never by name

This is what makes `vault-optimizer` portable. Every downstream pass references abstract
**roles** (`identity`, `context`, `projects`, `decisions`, `daily`, `meetings`,
`transcripts`, `resources`, `skills`, `archive`, `folder_index_convention`). This step
discovers what folder or file in *this* vault plays each role — or records that the role
is absent. The runtime never privileges a folder name.

## How discovery works

For each role, in order, until something resolves:

1. **Read folder names + any index/README/CLAUDE files** at the top level, then two deep.
   Build a candidate list: which folders could play this role, by name and self-description?
2. **Read 3-5 sample files per candidate folder.** Does the content match the role's purpose?
3. **Score and pick.** Highest-confidence candidate wins. No candidate clears medium
   confidence → the role is `missing`.

`Context/`, `About/`, `Me/`, `Personal/`, a frontmatter section on the root CLAUDE.md —
any of these can play the `identity` role. The agent decides by reading, not by name.

## Standard roles (recognition patterns, not a required taxonomy)

| Role | Layer | What it is | Recognise it by |
|---|---|---|---|
| `identity` | curated | Who the user/operator is — role, voice, preferences | First-person bio; role/title; voice or style guidance |
| `context` | curated | Canonical knowledge of the user's world — business, strategy, brand, team | Present-tense facts about the operating environment; named entities |
| `projects` | curated | Active or recent work units | Folders matching projects named in identity/context; per-folder scope/status |
| `decisions` | curated | Persistent decision records | Date-prefixed files with decision language ("decided", "chose", "going with") |
| `daily` | session | Per-day journals or logs | Filenames matching `YYYY-MM-DD.md`; date-hierarchy folders |
| `meetings` | session | Meeting notes | Date + person/topic filenames; attendee lists, action items |
| `transcripts` | session | Raw call/voice transcripts | >100KB files with dialogue formatting |
| `resources` | curated | Reference library — prompts, frameworks, templates | Reusable assets, not project-specific |
| `skills` | curated | SOPs / playbooks the user owns | `SKILL.md` files, or markdown describing repeatable processes |
| `archive` | archive | Intentionally deactivated content | Folder named archive/old/deprecated; files marked archived in frontmatter |
| `folder_index_convention` | meta | The vault's per-folder index file name | Most-frequent index-shaped filename across folders (`README.md`, `index.md`, `Plot.md`, `CLAUDE.md`, …) |

## Custom roles (every other folder)

After standard-role discovery, **every remaining folder must be classified** — never ignored.
For each unclassified folder: read its index file if present, sample 3-5 files (first 1500
chars + headers), read the parent's index for upstream framing. Then assign:

- `name` — slug from folder name + content (a `Building/` folder of prototype work → `building`)
- `layer` — `curated` (canonical, durable) · `session` (ephemeral, time-stamped) · `archive`
  (deactivated) · `meta` (tooling/system) · `unknown` (could not classify)
- `purpose` — one line on what the folder holds
- `is_standard: false`
- `confidence` — `high` / `medium` / `low`

Custom roles are **first-class**. Passes operate on roles by *layer*, not by membership in
the standard list. A custom `building` role with `layer: curated` participates in the
discoverability pass exactly as the standard `context` role does. If a layer cannot be assigned
confidently, log a finding asking the user to clarify during the walk.

## Output — the role registry

Build it once, cache it for the run, and persist to `.claude/vault-roles.json` so future
runs start from confirmed assignments instead of re-prompting.

```json
{
  "vault_root": "./",
  "discovered_at": "2026-05-17T14:23:00Z",
  "folder_index_convention": {
    "name": "README.md",
    "confidence": "high",
    "evidence": "23 of 31 non-trivial folders have README.md",
    "coverage": 0.74
  },
  "roles": [
    {"name": "identity",  "path": "./About/me.md", "kind": "file",   "layer": "curated", "is_standard": true,  "confidence": "high",   "purpose": "Operator bio + voice"},
    {"name": "context",   "path": "./Knowledge/",  "kind": "folder", "layer": "curated", "is_standard": true,  "confidence": "high",   "purpose": "Org/strategy/brand canonical knowledge"},
    {"name": "daily",     "path": "./Journal/",    "kind": "folder", "layer": "session", "is_standard": true,  "confidence": "medium", "purpose": "Per-day journal entries"},
    {"name": "building",  "path": "./Building/",   "kind": "folder", "layer": "curated", "is_standard": false, "confidence": "high",   "purpose": "Active prototype builds"}
  ],
  "missing_standard_roles": ["decisions", "meetings", "transcripts"],
  "low_confidence_roles": ["garden"],
  "unconfirmed_custom_roles": []
}
```

## Discovery summary (show the user, one block)

Frame it as "here is the structure I see" — not "here is what is missing from a checklist".
The user's structure is the source of truth.

```markdown
## Your vault structure — {N} folders classified

| Folder | Role | Layer | Purpose | Confidence |
|---|---|---|---|---|
| ./About/me.md | identity | curated | Operator bio + voice | high |
| ./Knowledge/ | context | curated | Org/strategy/brand | high |
| ./Journal/ | daily | session | Per-day journal | medium |
| ./Building/ | building (custom) | curated | Active prototype builds | high |

Folder-index convention detected: README.md (74% coverage).
Confirmed assignments persist to .claude/vault-roles.json.
```

## Hard rules

- Passes reference roles **by layer**, never by name. The curated layer = every role with
  `layer == curated` (standard or custom). The session layer = every `layer == session`.
- **Missing roles never block a pass.** If `decisions` is missing, the discoverability
  pass proceeds without it and surfaces a finding suggesting the user create one.
- The **folder-index convention is discovered** — it could be `README.md`, `index.md`,
  `Plot.md`, or a folder-level `CLAUDE.md`. Discoverability enforces *that* name, never a
  hardcoded one. If no convention exists, discoverability proposes adopting one.
- **No pass hardcodes folder paths or file names.** Examples in the pass files are
  illustrative; the runtime resolves through this registry.
