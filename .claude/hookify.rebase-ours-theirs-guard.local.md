---
event: PreToolUse
matcher: Bash
type: addContext
timeout: 5000
---

# Rebase `--ours` / `--theirs` Semantic Guard

When a Bash command uses `git checkout --ours` or `git checkout --theirs` during an active rebase on a code file, inject a reminder about reversed semantics vs merge.

## Triple-Gate

1. **Matcher**: `Bash`
2. **Bash-native fast-path**: substring check for `--ours` OR `--theirs` in stdin — if absent, exit `{}` in <2ms
3. **Rebase context detection**: check `.git/rebase-merge/` or `.git/rebase-apply/` existence — if absent, exit `{}` (merge conflicts use correct intuitive semantics, no warning needed)

## Detection

After gates pass:

```bash
# Check if rebase is in progress
if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
  # Extract file path from `git checkout --ours <path>` or `git checkout --theirs <path>`
  TARGET=$(echo "$CMD" | grep -oE 'checkout --(ours|theirs) [^ ]+' | awk '{print $3}')
  # If target matches code-file pattern, inject warning
  if echo "$TARGET" | grep -qE '\.(ts|tsx|js|jsx|sql|py|rs|go)$'; then
    # inject
  fi
fi
```

## Injection

> **REBASE `--ours`/`--theirs` semantics are REVERSED from merge** — this is the most commonly misapplied git command.
>
> During **rebase**: `--ours` = upstream (main/target) · `--theirs` = the commits being replayed (your incoming branch)
> During **merge**: `--ours` = current branch · `--theirs` = branch being merged in
>
> You're auto-resolving a code-file conflict during rebase. Confirm intent:
> - Want to KEEP upstream's version and drop your branch's change? → `--ours` is correct
> - Want to KEEP your branch's change and drop upstream's? → use `--theirs` instead
> - **Not sure?** → halt, open editor, resolve manually. Auto-resolving has ~50% chance of dropping the intended side silently.
>
> Incident 2026-04-19: guardrail hook fired 3× on auto-resolved rebase conflicts with semantic confusion. See `.claude/rules/operational-guardrails.md#git-checkout---ours--theirs--rebase-vs-merge-semantics-reversed`.

Does not block — context injection only. Docs-only files (`.md`, `.yaml`) not matched (auto-resolution acceptable for provable duplicate content).
