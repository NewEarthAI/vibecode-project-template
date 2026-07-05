-- ============================================================================
-- Obsidian second-brain sync — knowledge_items substrate (standalone)
-- ============================================================================
-- What this is:
--   The single table (plus one helper function) that the Obsidian vault sync
--   writes to. `bin/vault-sync.sh` reads every note in your vault, and upserts
--   one row per note into `knowledge_items`. `/setup`'s "connect your second
--   brain" step offers to apply this migration to YOUR Supabase project.
--
-- Run it against your own Supabase:
--   supabase db push          (from the repo root, with your project linked)
--   -- or paste this file into the Supabase SQL editor and run it.
--
-- Safe to run more than once — every object is created IF NOT EXISTS.
-- Nothing here is tied to any specific project; it stands alone.
-- ============================================================================

create table if not exists public.knowledge_items (
    id             uuid primary key default gen_random_uuid(),
    -- job_id is the natural conflict target for the vault sync:
    --   'vault-sync:' || <path-relative-to-vault> || ':' || left(sha256,12)
    -- Same content -> same job_id -> no-op. Changed content -> new job_id ->
    -- a new row, so the audit trail of what a note used to say is preserved.
    job_id         text not null,
    source_type    text not null default 'vault_note',   -- 'vault_note' for synced notes
    source_path    text,                                  -- path relative to the vault root
    content_hash   text,                                  -- sha-256 over the note body
    source_title   text,                                  -- the note's title / filename
    raw_content    text,                                  -- the note body (after frontmatter)
    source_metadata jsonb default '{}'::jsonb,            -- the note's YAML frontmatter, as JSON
    status         text default 'ready',
    kind           text default 'internal',
    submitted_via  text default 'vault_sync',
    -- full-text search over title + body (kept in sync by the trigger below)
    search_vector  tsvector,
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now()
);

-- The unique index the sync upserts against (Prefer: resolution=ignore-duplicates
-- -> ON CONFLICT (job_id) DO NOTHING).
create unique index if not exists knowledge_items_job_id_key
    on public.knowledge_items (job_id);

-- Fast filtering by source type + recency (used by the SessionStart recall block).
create index if not exists idx_knowledge_items_type_updated
    on public.knowledge_items (source_type, updated_at desc);

-- Full-text search index.
create index if not exists idx_knowledge_items_search
    on public.knowledge_items using gin (search_vector);

-- Keep search_vector current on every insert/update.
create or replace function public.knowledge_items_search_vector_update()
returns trigger
language plpgsql
as $$
begin
    new.search_vector :=
        setweight(to_tsvector('english', coalesce(new.source_title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(new.raw_content, '')), 'B');
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists trg_knowledge_items_search_vector on public.knowledge_items;
create trigger trg_knowledge_items_search_vector
    before insert or update on public.knowledge_items
    for each row execute function public.knowledge_items_search_vector_update();

-- Canary: how many vault notes landed in the last N minutes. The sync calls this
-- after a batch; if it inserted rows but this returns 0, the writes aren't
-- landing and the sync fails loud instead of reporting a false success.
create or replace function public.kg_vault_canary_recent_writes(window_minutes int default 15)
returns bigint
language sql
stable
as $$
    select count(*)
    from public.knowledge_items
    where source_type = 'vault_note'
      and created_at > now() - make_interval(mins => window_minutes);
$$;

-- ── Row-level security ──────────────────────────────────────────────────────
-- Reads are open to your app's anon/authenticated roles; only the service_role
-- (used by the sync script, never shipped to a browser) may write.
alter table public.knowledge_items enable row level security;

do $$
begin
    if not exists (select 1 from pg_policies
        where schemaname='public' and tablename='knowledge_items' and policyname='knowledge_items_read_anon') then
        create policy knowledge_items_read_anon on public.knowledge_items
            for select to anon using (true);
    end if;
    if not exists (select 1 from pg_policies
        where schemaname='public' and tablename='knowledge_items' and policyname='knowledge_items_read_auth') then
        create policy knowledge_items_read_auth on public.knowledge_items
            for select to authenticated using (true);
    end if;
    if not exists (select 1 from pg_policies
        where schemaname='public' and tablename='knowledge_items' and policyname='knowledge_items_write_service') then
        create policy knowledge_items_write_service on public.knowledge_items
            for all to service_role using (true) with check (true);
    end if;
end $$;

comment on table public.knowledge_items is
    'Obsidian second-brain sync substrate. One row per vault note, upserted by bin/vault-sync.sh on job_id.';
