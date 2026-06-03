# File Editing & Mutation Safety Rules

## Pre-Edit Protocol

1. **Always re-read a file before editing** — never edit from memory or stale context
2. **Verify column names** before writing SQL or REST queries against any table:
   ```sql
   SELECT column_name FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = '<table>'
   AND column_name ILIKE '%<search_term>%';
   ```
3. **Check existing implementations** before creating new functions or utilities

## Post-Mutation Protocol

After ANY mutation to production systems (n8n nodes, RPCs, edge functions, views, tables):
1. Document the change in `.claude/memory/fix-audit-trail.md` with before/after state and rollback command
2. Verify the change works with a targeted query or test
3. Log to session progress file

## n8n Code Node Editing

When editing n8n Code nodes:
- Verify the execution mode matches the use case (see n8n-patterns rule)
- Test with `n8n_test_workflow` after changes
- Check for paired-item chain breaks (any node making fresh HTTP calls breaks lineage)

## Edge Function Deployment

- Always specify `--project-ref <your-project-ref>`
- Use `get_publishable_keys` to get current anon key for testing
- Test with `curl` after deployment to verify
