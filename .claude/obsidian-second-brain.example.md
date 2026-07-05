---
# Per-machine obsidian autopilot config — EXAMPLE / TEMPLATE.
#
# To activate the SessionStart vault block on this repo + machine:
#   1. Copy this file to `.claude/obsidian-second-brain.local.md` (gitignored)
#   2. Fill in the four values below
#   3. Provision the Keychain entry on this Mac if it's not already there:
#        security add-generic-password -s '<keychain_item>' -a 'service_role' -w '<service-role-jwt>'
#
# Read by `.claude/hooks/sessionstart-context-aggregator.sh emit_vault_section`
# to surface the 5 most-recently-updated vault notes at SessionStart.
#
# The vault lives in the SHARED NewEarth Agency-Main Supabase project — every
# NewEarth repo points at the same `knowledge_items` table so sessions across
# all repos surface the same vault activity. The Keychain entry name is the
# same on every Mac that has been set up.

# Path to the local Agency vault folder. Required by vault-capture.sh (Stop
# hook) so it can append the session summary into the right daily note.
vault_path: "/Users/<you>/code/newearth-agency-main/agency/vault"

# Agency-Main Supabase URL. Same value on every NewEarth repo.
supabase_url: "https://YOUR-PROJECT-REF.supabase.co"

# macOS Keychain item name carrying the service_role JWT. Same name on every
# Mac that's been set up via the agency provisioning protocol.
keychain_item: "project-supabase-service-role-jwt"

# Per-repo scope filter (OPTIONAL — added 2026-05-23). When set, restricts
# the SessionStart vault block to rows whose source_path contains this slug
# (case-insensitive). Without it, the block returns the full agency vault.
#
# Recommended values per repo:
#   vault_scope_slug: "buybox"        # your project repo
#   vault_scope_slug: "nirvana"       # Nirvana Freight repo
#   vault_scope_slug: "my-app"        # your project's slug
#   (omit on Agency-Main parent repo — designed to see the whole vault)
#
# Why: each repo's session is most useful with its OWN recent vault activity
# rather than cross-repo noise. Operators picking up a BuyBox session don't
# need to see Nirvana fleet entries and vice versa.
vault_scope_slug: "<your-repo-slug>"
---

# Obsidian Autopilot — Per-Machine Config (Template)

This file is per-machine, gitignored when copied to `.local.md`, never
committed. Pairs with the global config at `~/.obsidian-wiki/config` (which
carries `OBSIDIAN_VAULT_PATH=` for the upstream obsidian-wiki Phase 3 skills'
Config Resolution Protocol).

## What this enables

Every SessionStart on this Mac in this repo will surface the top 5
most-recently-updated rows from the Agency `knowledge_items` table inside
the briefing — the "📓 Recent vault activity" section that the upgraded
aggregator emits.

## How to verify after setup

```bash
echo '{"hook_event_name":"SessionStart","cwd":"'$(pwd)'"}' \
  | bash .claude/hooks/sessionstart-context-aggregator.sh \
  | jq -r '.hookSpecificOutput.additionalContext // .additionalContext // empty' \
  | grep -A 10 "Recent vault activity"
```

If the section reads "_vault read failed — likely auth expired or schema
drift_", check `~/.claude/sessionstart-vault.log` for the underlying error
envelope.

## Three-leg setup recipe for new repos

1. **Leg 1 — Stop chain wiring**. Extend `.claude/settings.local.json` Stop
   chain to include `session-summarizer` → `roadmap-writeback-verifier` →
   `vault-capture` → `auto-sync-artifacts` → any project-specific hooks.
   This file enables the read side (SessionStart); Leg 1 enables the write
   side (vault gets new content from this repo's sessions).

2. **Leg 2 — Memory distillation**. Run the `claude-history-ingest` skill
   to distil this repo's memory files into atomic vault notes under
   `agency/vault/05 - Fleeting/wiki-ingest/projects/<repo-slug>/`. Target
   ≥ 20 atomic notes plus topic-synthesis pages for the rest. Vault-sync
   upserts them to `knowledge_items` automatically (cron every 10 min).

3. **Leg 3 — MEMORY.md slim-down**. Run the `refactor-memory-md` skill to
   trim the per-repo MEMORY.md down to ≤ 200 lines / ≤ 50 KB. Heavy content
   migrates to atomic vault notes from Leg 2; MEMORY.md becomes a slim
   pointer index. This is the token-savings payoff.

## Composition

- `agency/vault/` (Agency-Main repo) — where the vault markdown files live
- `knowledge_items` table (Agency Supabase) — the indexed projection
- `bin/vault-sync.sh` (Agency-Main repo) — launchd job upserting vault → DB
- `vault-capture.sh` (this repo, .claude/hooks/) — Stop hook appending session
   summary to daily notes
- `sessionstart-context-aggregator.sh` (this repo, .claude/hooks/) — reads
  knowledge_items at SessionStart and emits the vault block, filtered by
  `vault_scope_slug` if set above
