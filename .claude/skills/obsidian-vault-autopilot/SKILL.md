---
name: obsidian-vault-autopilot
description: |
  Bootstrap, verify, and (eventually) repair the Obsidian vault autopilot — the launchd-driven, every-10-minutes sync from a per-machine markdown vault into a per-vault Supabase database. Composes with existing bin/activate-vault-autopilot.sh + bin/vault-sync.sh + bin/memory-health-check.sh. Sibling to obsidian-second-brain (which handles ongoing vault OPERATIONS — search, MOC, KI bridge). Use when "set up obsidian autopilot", "wire vault sync", "verify vault autopilot", "vault is not syncing", "fresh Mac obsidian setup", "is the vault autopilot healthy", "first-time vault setup". V1.0 ships Bootstrap + Verify modes, NewEarth-internal persona only. Repair (v1.1), Migrate (v1.2), External-adopter (v2.0) deferred. Idempotent and state-aware — re-running detects existing state and fixes only what is broken.
version: 1.0
classification: encoded-preference
created: 2026-05-22
updated: 2026-05-22
supersedes: none
spec: specs/26_OBSIDIAN_VAULT_AUTOPILOT_SKILL.md
council_session: council/sessions/2026-05-22-obsidian-vault-autopilot-skill-extended-council.md
validated_on:
  - Justin's Mac live setup (2026-05-22) — 7/7 verify-grid PASS
parameters:
  - name: vault_path
    type: path
    description: Absolute path to the Obsidian vault root (e.g., agency/vault). Read from per-machine config.
  - name: supabase_url
    type: url
    description: Per-vault Supabase project URL (e.g., https://ridqdojzjotlvexfuwvx.supabase.co for agency prod).
  - name: keychain_item
    type: string
    description: macOS Keychain service name holding the service-role JWT.
  - name: persona
    type: enum
    values: [newearth-internal, external, no-obsidian]
    default: newearth-internal
    description: V1.0 supports newearth-internal only.
  - name: repo_slug
    type: string
    description: Repo slug used to parameterise plist label (closes spoke-kills-hub gap from council A1).
allowed-tools: Read, Bash, Write, Edit
---

# Obsidian Vault Autopilot — Bootstrap + Verify

> **Scope (v1.0)**: Bootstrap + Verify modes only. NewEarth-internal persona only. Per Spec 26 A13 council amendment, Repair / Migrate / External-adopter deferred to v1.1 / v1.2 / v2.0 informed by real failure modes observed in the wild.

## When To Invoke This Skill

| Trigger | Mode |
|---|---|
| Fresh Mac, no vault config, no plist, no keychain entries | Bootstrap |
| Vault appears configured — operator wants confidence check | Verify |
| Operator says "is vault sync working?" | Verify |
| Operator says "set up obsidian on this Mac" | Bootstrap |

**Do NOT use this skill for**:
- Ongoing vault operations (search, MOC, KI bridge) — that is `obsidian-second-brain`
- Vault discoverability audit — that is `vault-optimizer`
- Vault cadence orchestration (/trace /drift /emerge) — those are dedicated commands
- Spoke-vault bootstrap (BuyBox / Nirvana / GoodBuy) — deferred to v1.2

## Pre-Flight (Run Before Any Mode)

Three checks the skill always runs first:

1. **Obsidian app installed?** — `test -d /Applications/Obsidian.app`. If NO → prompt operator: "Install Obsidian first? It is the free markdown editor that opens the vault folder ([https://obsidian.md](https://obsidian.md))." Skip-for-now exits cleanly.
2. **Working tree state** — `git status --short`. If dirty in `.claude/`, surface before any write (skill will create / modify `.claude/obsidian-second-brain.local.md`).
3. **macOS path** — TCC ceiling per council A3: if vault path is under `~/Documents/`, the launchd autopilot is unreliable (SIP-protected `/bin/bash` cannot be granted Full Disk Access). Skill marks plist as ADVISORY-only and relies on SessionStart sync only.

## Bootstrap Mode

Triggered when: no vault config OR no plist OR no required keychain entries.

### Step 1 — Persona detection (3-signal + confirmation)

> [Council A8] — explicit operator confirmation is MANDATORY. 3-signal detection alone is insufficient; closes the silent-wrong-DB-sync class (CRITICAL-1 + CRITICAL-2).

Three signals, evaluated in AND:
1. `agency/` directory present at repo root
2. Repo `MEMORY.md` or `agency/memory/MEMORY.md` frontmatter contains `agency: "newearthai"` (structured signal — replaces the loose free-text "NewEarth" grep that produced false positives per EdgeCase B-1)
3. `git remote get-url origin` matches `NewEarthAI/*` or `NewEarth-AI/*`

Invoke `scripts/detect-persona.sh` — emits one of: `newearth-internal`, `external`, `ambiguous`.

**Then ALWAYS prompt the operator**:
```
I think you are a [newearth-internal] operator because:
  - agency/ folder: present
  - MEMORY.md frontmatter agency: newearthai: yes
  - git remote NewEarthAI/*: yes

Confirm this is correct?
  [y] yes — proceed with NewEarth-internal setup
  [n] no — this is an external project (v1.0 cannot proceed; rerun in v2.0)
  [e] explain — describe the project briefly for re-detection
```

The operator's answer is cached in `.claude/obsidian-second-brain.local.md` as `persona: "newearth-internal"`. Verify mode reads the cached value and re-challenges only on git-remote-URL drift (closes CRITICAL-2 stale-persona-after-repo-repurpose).

If operator answers `n` in v1.0 → skill exits with: "External-adopter persona ships in v2.0. Set up your vault manually for now: see references/personas.md." No partial setup, no half-state.

### Step 2 — Keychain entries (operator-driven, never via this chat)

> [Council A8 / Q6] — option (a) only. The service-role JWT is RLS-bypass authority; it must never appear in any Claude transcript. Skill surfaces the exact `security add-generic-password` command for the operator to run in their own Terminal.

Check for the 4 NewEarth-internal keychain entries:

| Service name | Account | Status check |
|---|---|---|
| `claude-mcp-supabase-newearthai` | `api-key` | `security find-generic-password -s "claude-mcp-supabase-newearthai" -a "api-key" >/dev/null 2>&1` |
| `agency-supabase-newearthai-service-role-jwt` | `service_role` | (same pattern) |
| `agency-supabase-newearthai-secret-key` | `secret` | (same pattern) |
| `agency-supabase-newearthai-publishable-key` | `publishable` | (same pattern) |

Only `agency-supabase-newearthai-service-role-jwt` is strictly required to activate the autopilot — the others are forward-protection per the credentials reference.

For each missing entry, skill emits the exact command for the operator to run in **their own Terminal**:

```
security add-generic-password -U \
  -s "agency-supabase-newearthai-service-role-jwt" \
  -a "service_role" -w
```

The `-w` flag without a value prompts hidden input. Skill then waits for operator to confirm "done" before continuing. **NEVER take the JWT value via chat.** See `references/keychain-protocol.md` for the full naming map.

### Step 3 — Per-machine config

> [Council A9] — `write-per-machine-config.sh` substitutes per-Mac values into the config + (deferred — v1.1) the plist template. v1.0 writes only the config; uses existing `bin/activate-vault-autopilot.sh` for plist generation (with its hardcoded LABEL — see TCC + A1 note below).

Invoke `scripts/write-per-machine-config.sh`. Generates `.claude/obsidian-second-brain.local.md` with frontmatter:

```yaml
---
vault_path: "<absolute_vault_path>"
supabase_url: "https://ridqdojzjotlvexfuwvx.supabase.co"
keychain_item: "agency-supabase-newearthai-service-role-jwt"
persona: "newearth-internal"
repo_slug: "<basename_of_repo_root>"
---
```

The file is per-machine (gitignored at `.gitignore` line 46). Skill verifies it remains gitignored before writing.

### Step 4 — Activate launchd autopilot

> [Council A3] — if `vault_path` is under `~/Documents/`, SKIP the launchd activation and rely on SessionStart-only sync (TCC ceiling per rollout memo). Skill emits an ADVISORY in this case, not a failure.

> [Council A1] — V1.0 limitation: `bin/activate-vault-autopilot.sh` hardcodes `LABEL="com.newearthai.vault-sync"` (single-plist-per-Mac assumption). Spec 26 A1 calls for label parameterisation in v1.2 when spoke rollout begins. For v1.0 (single NewEarth-internal repo per Mac), this is acceptable.

If vault_path is NOT under `~/Documents/`:
```bash
EXPECTED_REF=<extracted_from_supabase_url> bash bin/activate-vault-autopilot.sh
```

The activator handles: plist generation, launchctl bootout/bootstrap, write→read→delete smoke test against live Supabase. Skill captures output and surfaces failures verbatim.

### Step 5 — Bootstrap post-verify

> [Council A9 / TIMING-1] — Bootstrap declares success only AFTER first end-to-end sync completes, not after activator returns. Catches plist-misconfig that smoke alone misses (smoke uses shell env; first launchd-fired run uses plist EnvironmentVariables).

After activator returns success, skill invokes:
```bash
bash bin/vault-sync.sh
```

Directly (not via launchd). This forces one full sync NOW using the same env vars launchd will provide. If this run succeeds (`exit 0` + new row in `vault_sync_log`), Bootstrap declares success. Otherwise, skill surfaces the failure and does NOT declare success.

### Step 6 — 7-check verification grid

Invoke `scripts/verify-grid.sh` (see Verify mode below). Output: PASS / ADVISORY / FAIL grid. Bootstrap declares success only on 7/7 PASS (or PASS with documented ADVISORY for TCC case per A3).

### Step 7 — Report

Final report to operator:
- Persona: newearth-internal (confirmed)
- Vault path
- Supabase target (URL + project ref)
- Keychain entries present (count)
- Launchd autopilot status (LOADED / SKIP-TCC / FAILED)
- 7-check grid result

Suggest the operator opens Obsidian at the vault path: "File → Open vault → select your-vault-folder."

## Verify Mode

Triggered when: vault config exists AND operator wants confidence check.

### The 7 Checks (encoded in `scripts/verify-grid.sh`)

1. **Repo identity** — `pwd` + `git remote -v` + `git rev-parse --abbrev-ref HEAD`. PASS if remote matches stored persona's expected pattern; ADVISORY on drift (closes CRITICAL-2 stale persona).
2. **Per-machine config** — file exists; required fields (`vault_path`, `supabase_url`, `keychain_item`, `persona`) all present.
3. **Vault path** — directory exists; ≥1 markdown file inside.
4. **Launchd autopilot loaded** — `launchctl list | grep vault-sync`. PASS = label present + last exit 0. ADVISORY if vault is `~/Documents/`-rooted AND plist absent (TCC ceiling per A3 — SessionStart-only sync is acceptable). FAIL otherwise.
5. **Last sync recent** — query `vault_sync_log` table directly: `SELECT synced_at FROM vault_sync_log WHERE machine = $hostname ORDER BY synced_at DESC LIMIT 1` (per A11). PASS if < 30 min. ADVISORY if 30-120 min. FAIL if > 120 min OR no rows.
6. **Keychain entries** — service-role JWT present (the only one strictly required). Others (PAT, secret-key, publishable-key) are ADVISORY if missing.
7. **Cross-machine memory symlink** — invoke `bin/memory-health-check.sh` (unchanged — composes via subprocess).

Output: counts PASS / ADVISORY / FAIL + per-check disposition. Returns exit 0 only on 7/7 PASS (ADVISORY-with-justification also passes; FAIL anywhere = exit 1).

### Persona re-challenge (Verify-only check)

> [Council A8] — every Verify run compares `git remote get-url origin` against stored `persona`'s expected pattern.

If stored `persona: "newearth-internal"` but current remote does NOT match `NewEarthAI/*` or `NewEarth-AI/*`:
- Emit ADVISORY: "Stored persona is newearth-internal but git remote is now `<actual>`. Re-run bootstrap to reclassify."
- Do NOT silently re-route. Do NOT auto-fix.

## Repair Mode (v1.1 — DEFERRED)

> [Council A6 + A13] — Repair authoring deferred until Cassandra's first real failure mode informs the design. Stub:
>
> When Bootstrap fails partway OR Verify reports FAIL, Repair detects each broken piece, shows a unified diff of proposed changes (per A6 dry-run gate), and requires explicit operator confirmation before any keychain / plist / config write. Loops until Verify passes OR operator aborts.
>
> v1.1 ships informed by ≥1 real-world Repair scenario.

## Migrate Mode (v1.2 — DEFERRED)

> [Council A13] — Migrate authoring deferred until spoke rollout begins. Stub:
>
> When vault dir moved OR Mac changed OR repo path changed, Migrate updates per-machine config + re-runs the full activator (not just `launchctl bootout/bootstrap`) so the plist regenerates with new paths. Closes SIG-4 (old-plist-paths after repo move).

## External-Adopter Mode (v2.0 — DEFERRED)

> [Council A13 + Q3 option (c)] — External adopter wizard deferred until external adoption demand materialises.
>
> v2.0 will: detect non-NewEarth repo → prompt for adopter's vault path + Supabase URL + 1 keychain entry → option (c) clean exit if Supabase project does not exist yet ("come back once your Supabase is ready and re-run the skill").

## Composition Map (what existing infra this skill touches)

| Touched | How |
|---|---|
| `bin/activate-vault-autopilot.sh` | Invoked in Bootstrap step 4 |
| `bin/vault-sync.sh` | Invoked in Bootstrap step 5 (forced first sync) |
| `bin/memory-health-check.sh` | Invoked in Verify check #7 |
| `.claude/obsidian-second-brain.local.md` | Created in Bootstrap step 3; read in every Verify |
| `.claude/hooks/sessionstart-context-aggregator.sh` | Reads the config file this skill creates (no direct skill ↔ hook coupling — they share the config file as substrate) |
| `obsidian-second-brain` (sibling skill) | Operates against the vault this skill installs — different concerns, same substrate |
| `verify-shipped` (existing skill) | v1.1 — optional `--layer=7` composition (per Q5 resolution) — defer |

## Failure Modes + Their Handling

| Mode | Detection | v1.0 disposition |
|---|---|---|
| Operator declines Obsidian install at pre-flight | `test -d /Applications/Obsidian.app` returns false + skip answer | Exit cleanly with note "re-run after install" |
| Persona ambiguous (3 signals partially fire) | `detect-persona.sh` returns `ambiguous` | Skill exits with "manual persona declaration needed" — DO NOT guess |
| Missing keychain entry | `security find-generic-password` returns non-zero | Surface exact `security add-generic-password` command for Terminal; wait for operator "done" |
| Activator routing assertion fails (wrong SUPABASE_URL/JWT pair) | `activate-vault-autopilot.sh` exit ≠ 0 with routing-error message | Surface activator output verbatim; do NOT retry; do NOT proceed |
| First launchd-fired sync after Bootstrap fails | `vault-sync.sh` direct invocation in step 5 returns exit ≠ 0 OR no new `vault_sync_log` row | Surface failure; do NOT declare Bootstrap success |
| TCC ceiling — vault is `~/Documents/`-rooted | Path test at pre-flight | Mark plist ADVISORY-only; rely on SessionStart sync; document in final report |
| Vault dir does not exist | `test -d "$vault_path"` returns false at step 3 | Exit with "vault path does not exist — create it first, then re-run" — DO NOT auto-create (operator decides where vault lives) |

## Anti-Patterns

| Wrong | Why | Right |
|---|---|---|
| Taking a JWT value via chat | Service-role JWT is RLS-bypass; chat transcript is non-secure | Surface `security add-generic-password` command for operator's Terminal |
| Auto-creating the vault directory | Operator decides vault location | Detect absence; exit with prompt to create + re-run |
| Skipping the persona confirmation prompt because signals are unambiguous | 3-signal detection produced silent-wrong-DB-sync class in council CRITICAL-1 | Always prompt operator after detection |
| Declaring Bootstrap success after activator returns | Activator uses shell env; plist uses its own EnvironmentVariables (TIMING-1) | Force one direct `vault-sync.sh` run + verify-grid before declaring success |
| Re-running Bootstrap on already-set-up state | Idempotent claim must hold; re-running should NOT rewrite working config | Detect state first; route to Verify if everything is in place |

## Validation

Run from project root:
```bash
bash .claude/skills/obsidian-vault-autopilot/scripts/verify-grid.sh
```

Exit 0 = 7/7 PASS. Exit 1 = at least one FAIL. Stderr describes per-check disposition.

## See Also

- `specs/26_OBSIDIAN_VAULT_AUTOPILOT_SKILL.md` v2 — the parent spec with all 14 council amendments
- `council/sessions/2026-05-22-obsidian-vault-autopilot-skill-extended-council.md` — the deliberation that produced the amendments
- `agency/memory/reference_supabase-newearthai-credentials.md` — keychain naming source-of-truth
- `agency/memory/project_obsidian-autopilot-rollout-2026-05-15.md` — TCC discovery + SessionStart workaround
- `.claude/skills/obsidian-second-brain/SKILL.md` — sibling skill for ongoing vault operations
