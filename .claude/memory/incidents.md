# Incidents

> Structured incident tracker. Cross-references FIX-IDs from fix-audit-trail.md.
> Append-only, NOT auto-loaded. Query with grep when debugging.

## Template

```
### INC-{NNNN}: {title}
- **Date**: {YYYY-MM-DD}
- **Severity**: {P1-critical / P2-degraded / P3-minor}
- **Symptoms**: {what user/canary observed}
- **Root Cause**: {determined after investigation}
- **Fix**: FIX-{NNNN} (link to fix-audit-trail.md entry)
- **Resolved**: {date or "OPEN"}
```

## Active Incidents

(None — incidents will be logged as they occur)

## Resolved

| INC | Date | Severity | Summary | Fix |
|-----|------|----------|---------|-----|
