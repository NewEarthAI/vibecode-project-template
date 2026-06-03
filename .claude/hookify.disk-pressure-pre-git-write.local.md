---
event: PreToolUse
matcher: Bash
type: addContext
timeout: 5000
---

# Disk Pressure Pre-flight for Git Writes

When a Bash command contains a git write op (`add`, `commit`, `reset`, `checkout`, `worktree add`, `rebase`, `merge`, `stash`) AND the data volume is ≥90% full, inject a warning before execution.

## Triple-Gate

1. **Matcher**: `Bash` (narrow to shell calls)
2. **Bash-native fast-path**: substring check for `git ` in stdin — if absent, exit with `{}` in <2ms
3. **Git-write detection**: regex `git (add|commit|reset|checkout|worktree add|rebase|merge|stash)\b` — if no match, exit `{}`

## Detection

After the three gates pass, check disk:

```bash
PCT=$(df /System/Volumes/Data 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
if [ -n "$PCT" ] && [ "$PCT" -ge 90 ]; then
  # inject warning
fi
```

## Injection

Inject this as `additionalContext`:

> **Data volume at X% full — APFS copy-on-write degrades past 90% and can corrupt `.git/index` mid-write.** Free 5GB+ before proceeding. Safe cleanup targets: `rm -rf ~/.cache/uv` (typically 5-12GB), `npm cache clean --force`, `rm -rf ~/Library/Caches/ms-playwright`, `rm -rf ~/Library/Caches/Google`. All rebuildable.
>
> Incident 2026-04-19: 94% full caused `git reset` to hang 90s and leave `.git/index` renamed without rebuild. See `.claude/rules/operational-guardrails.md#disk-pressure---pre-flight-before-git-writes`.

Does not block — context injection only. Latency: <5ms on non-git Bash, <15ms on git Bash.
