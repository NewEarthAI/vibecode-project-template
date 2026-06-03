# Local Adaptations — Agency-Main

**Upstream skill source**: `https://github.com/affaan-m/everything-claude-code/tree/main/skills/security-scan` (ECC, 188k★, MIT, Anthropic hackathon winner)
**Upstream npm package**: `ecc-agentshield@1.4.0` (`https://github.com/affaan-m/agentshield`)
**Imported**: prior session (skill at v1.1 in this repo before 2026-05-22); LOCAL-ADAPTATIONS authored 2026-05-22 (Phase 2 of the Obsidian Ingest + Skill Audit programme — PR #TBD)
**Diff-able-update contract**: `SKILL.md` is kept light per upstream pattern so we can `diff` against future ECC updates without losing context. Project-specific overrides live in THIS file only.

## Why this LOCAL-ADAPTATIONS exists

The SKILL.md was absorbed in a prior session at v1.1 with `source:` attribution, but no sibling LOCAL-ADAPTATIONS.md was authored. The 2026-05-22 ECC audit (PR #TBD, plan `~/.claude/plans/rosy-knitting-bengio.md`) discovered this gap and ships the missing sibling. No SKILL.md edits in this PR.

## Override 1 — Composition order with Agency-Main's existing security stack

Agency-Main has THREE pre-existing security layers. This skill adds a fourth (config-static-scan). Use them in this order on a given concern:

| Layer | Skill | Scope | When to fire |
|---|---|---|---|
| 1 | `safe-bash` | Runtime shell-command safety (argv exec, metachar rejection, audit log) | Before any shell-tool call |
| 2 | `security-threat-model` | System-level threat model (boundaries, assets, attacker capabilities) | At project scoping; revisit on architecture change |
| 3 | `newearth-security` | Application code review (Supabase RLS, edge functions, frontend XSS, n8n credentials) | Before any code merge to main on a paying-client repo |
| 4 | **`security-scan-agentshield` (this skill)** | Meta-security — `.claude/` config static scan (CLAUDE.md prompt injection, settings.json permission audit, mcp.json supply-chain, hooks/ command injection) | Before any `.claude/` config change merges |

These are ORTHOGONAL. Two or more can run on the same PR. They do NOT replace each other.

## Override 2 — Kill-switch env var (composes with hook-profile-gating rule)

The skill itself is invokable via `npx ecc-agentshield scan`. If the convention shipped in `.claude/rules/hook-profile-gating.md` becomes adopted at the trigger layer (NSF-A1 below), the kill-switch will be:

```
HOOK_SECURITY_SCAN_AGENTSHIELD=0
```

No `_DISABLED` suffix — matches `AUTOVIBE_AUTOFIRE` precedent (feature flag, not state assertion). Truthy-variant accept per the convention: `{0, false, no, off, disabled, disable}` (case-insensitive) = DISABLE. Default (unset/empty) or `1`/`true`/`yes`/`enabled` = ENABLED.

Until NSF-A1 is wired, the kill-switch is moot (no automated trigger to gate). Documented here for forward compatibility.

## Override 3 — NewEarth-specific allowlist (TBD)

Empty as of 2026-05-22. The first run of `npx ecc-agentshield scan` against this repo's `.claude/` will likely surface false positives on legitimate patterns (Wassenger tokens, n8n webhook URLs, supabase project refs in hookify rules, Google API key references). When the trigger wiring (NSF-A1) ships, populate this section with allowlist entries:

```
# Format: <file-path>:<rule-id>:<reason>
# Example:
# .claude/hooks/wassenger-context.sh:HARDCODED_TOKEN:false-positive (Wassenger sandbox token, not production)
```

## Override 4 — Re-sync command

Future updates to the upstream `ecc-agentshield` package or the ECC skill text are pulled via:

```bash
# Update the npm package (pin a specific version in the kill-switch comment)
npx --yes ecc-agentshield@latest --version

# Re-fetch the ECC skill text (verbatim, for diff inspection)
curl -fsSL "https://raw.githubusercontent.com/affaan-m/everything-claude-code/main/skills/security-scan/SKILL.md" \
  -o /tmp/ecc-security-scan-SKILL.md
diff -u .claude/skills/security-scan-agentshield/SKILL.md /tmp/ecc-security-scan-SKILL.md

# If the diff is non-trivial, refresh SKILL.md and bump the version line below.
```

## DEFERRED — NSF-A1 (no trigger schedule)

Per the 2026-05-22 5-agent council, this skill ships without an execution trigger. A security-scan tool with no trigger is graveyard risk. Three candidate triggers surfaced; the council-recommended path is the `/daily-plan` weekly cadence (timestamp-gated, runs if last scan was >7 days ago). NOT in this PR.

**Decommission trigger**: revisit at next `/daily-plan` enhancement session OR when `ecc-agentshield` npm releases v2+ with material rule changes OR when Claude Code ships a native config-security audit.

## DEFERRED — NSF-A2 (no sentinel smoke test)

The scan can silently pass on a misconfigured rule set without anyone noticing. Council-recommended mitigation: ship a known-bad fixture file (`.claude/test-fixtures/sentinel-secret.md` with a fake AWS key pattern) + a test invocation that confirms `ecc-agentshield` finds it. NOT in this PR.

**Decommission trigger**: implement when NSF-A1 trigger is wired (the two go together — no point in a sentinel if the scan doesn't run).

## License attribution

ECC (the upstream monorepo) is MIT — © 2026 Affaan Mustafa. `ecc-agentshield` (the npm package) is published from `affaan-m/agentshield`; license per the npm package metadata at install time.

## Cross-references

- `.claude/rules/hook-profile-gating.md` — the env-var disable convention this skill's kill-switch composes with (ships in the same PR as this LOCAL-ADAPTATIONS)
- `agency/memory/audit_ecc-2026-05-22.md` — the audit memo that justified shoring up this skill
- `~/.claude/plans/rosy-knitting-bengio.md` — the council-amended plan (v2) governing this PR
- PR #47 (`87ad819`) — the absorption pattern precedent
