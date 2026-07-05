# Connect your second brain (Obsidian) — full setup

This wires your project to an [Obsidian](https://obsidian.md) vault so Claude has
durable, cross-session memory: each session writes a summary into your vault, and
reads your recent notes back at the start of the next one.

There are **two layers**. The first works with nothing but a vault. The second
adds searchable cross-session recall using your own Supabase — and everything
below is generic: no account but *yours* is ever involved.

Prefer to be walked through it? Just say **"connect my second brain"** in Claude
Code and it will run these steps with you.

---

## Layer 1 — Local capture (works immediately, no Supabase)

1. **Install Obsidian** (free) and open (or create) a vault folder.
2. **Point the template at it.** Copy the example config to your local one:
   ```bash
   cp .claude/obsidian-second-brain.example.md .claude/obsidian-second-brain.local.md
   ```
   Open the copy and set `vault_path:` to your vault folder. (The `.local.md`
   file is gitignored — it never leaves your machine.)
3. **Make sure the capture hook runs at session end.** `/setup` already wires the
   Stop-hook chain (which includes `vault-capture.sh`); if you skipped setup, add
   `.claude/hooks/vault-capture.sh` to the `Stop` hooks in
   `.claude/settings.local.json`.

That's it for Layer 1. From now on, every session appends a short summary to your
vault's daily note. Nothing else required.

---

## Layer 2 — Searchable cross-session recall (your own Supabase)

This upserts every vault note into a `knowledge_items` table in **your** Supabase,
so the start-of-session briefing can surface your most recent notes and Claude can
search them.

1. **Create the table in your Supabase** (one command, safe to re-run):
   ```bash
   supabase db push
   ```
   This applies the shipped migration
   `supabase/migrations/…_obsidian_knowledge_items.sql`, which creates the
   `knowledge_items` table, its search index, the write-canary function, and
   read-only row-level security. (Or paste that file into the Supabase SQL editor.)
2. **Fill in your Supabase URL** in `.claude/obsidian-second-brain.local.md`:
   set `supabase_url:` to `https://YOUR-PROJECT-REF.supabase.co` (Project
   Settings → API → Project URL).
3. **Store your service-role key on your Mac's Keychain, once** (it stays there —
   never in a file, never committed):
   ```bash
   security add-generic-password -s 'project-supabase-service-role-jwt' \
     -a 'service_role' -w 'YOUR_SERVICE_ROLE_JWT'
   ```
   (Find the key in Supabase → Project Settings → API → `service_role` secret.)
4. **Run the sync** — by hand any time:
   ```bash
   SUPABASE_URL="https://YOUR-PROJECT-REF.supabase.co" bash bin/vault-sync.sh
   ```
   or just say **"sync my vault"**.

### Automate it (optional)

You don't need macOS launchd for this — the template ships a scheduler (see the
README "Scheduled & recurring agents" walkthrough). Point it at `/vault-sync` on
whatever cadence you like (e.g. every 10 minutes) and the sync runs itself.

---

## Verify it's working

```bash
echo '{"hook_event_name":"SessionStart","cwd":"'$(pwd)'"}' \
  | bash .claude/hooks/sessionstart-context-aggregator.sh \
  | jq -r '.hookSpecificOutput.additionalContext // .additionalContext // empty' \
  | grep -A 10 "Recent vault activity"
```

You should see your recent notes. If it says the vault read failed, check
`~/.claude/sessionstart-vault.log` for the reason (usually the Keychain key or the
`supabase_url` value).

---

## One vault, many projects?

If you keep several projects in a single vault + Supabase, set `vault_scope_slug:`
in each project's `.local.md`. The start-of-session block then only shows notes
whose path contains that slug, so each project sees its own recent activity — not
everything at once. Using one vault per project? Leave it as-is.

---

## The pieces (for reference)

| Piece | Role |
|---|---|
| your Obsidian vault | where your markdown notes live |
| `knowledge_items` (your Supabase) | searchable index the sync writes to |
| `supabase/migrations/…_obsidian_knowledge_items.sql` | creates that table |
| `bin/vault-sync.sh` | reads the vault, upserts notes → the table |
| `.claude/hooks/vault-capture.sh` | Stop hook; writes the session summary to the day's note |
| `.claude/hooks/sessionstart-context-aggregator.sh` | reads the table at session start, shows recent activity |
| `obsidian-second-brain` skill | search, frontmatter, and note operations over the vault |
| `vault-optimizer` skill | audits the vault's structure and discoverability |
