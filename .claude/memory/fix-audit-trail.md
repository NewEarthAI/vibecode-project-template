# Fix Audit Trail

> Every confident-mode fix to production systems gets a structured entry here.
> Claude checks this file FIRST when debugging errors (grep by Layer/Target).
> Entries older than 14 days compress to one-line archive rows.

## Template

```
### FIX-{NNNN}: {title}
- **Date**: {YYYY-MM-DD}
- **Layer**: {n8n node / RPC / edge fn / view / table / frontend}
- **Target**: {exact name — workflow ID, function name, table.column, etc.}
- **Before**: {minimal diff — 5-15 lines showing previous state}
- **After**: {what was deployed/changed}
- **Rollback**: {concrete, copy-pasteable revert command or SQL}
- **Relates to**: INC-{NNNN} or N/A
```

## Rules
- Capture before state BEFORE making the change
- Keep diffs minimal (5-15 lines, not full files)
- Rollback must be copy-pasteable
- Entries > 14 days old: compress to `| FIX-NNNN | date | layer | target | one-line summary |`

---

## Active Fixes

(None yet — entries will be added as fixes are made)

---

## Archive (> 14 days)

| FIX | Date | Layer | Target | Summary |
|-----|------|-------|--------|---------|
