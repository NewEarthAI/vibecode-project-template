# Typecheck + Review Gates — Preventing Silent Compile-Time Bugs

## The Incident Class

A pre-existing scope bug can ship to production undetected for days when three forms of static analysis each claim "clean":

- Identifiers (e.g. `flagInputOpen`, `isFlagging`, `flagDeal`) declared inside `ContainerComponent` function body
- Referenced (15+ sites) inside `ChildComponent` — a **separate function in the same file**
- Runtime result: `ReferenceError: flagInputOpen is not defined` → ErrorBoundary → full-page crash
- Masked by an earlier null-cascade crash that fires first; surfaces only once the UI gets past that gate
- Merges through multiple consecutive PRs with playwright test failing the whole time

**Why a 6-agent code-council can miss it**: every reviewer reads diffs (`git diff origin/main..HEAD`). If the declaration and usage are both on `origin/main`, neither side appears in the diff. Cross-function scope boundaries are invisible to diff-only review.

**Why `npx tsc --noEmit` can miss it**: if the root `tsconfig.json` uses project references and `"files": []`, running bare `tsc --noEmit` **is a no-op and always returns exit 0**. The real checker needs `-p tsconfig.app.json` (or whichever config actually lists files).

**Why `npm run build` can miss it**: Vite uses esbuild/swc for transpilation, not full TypeScript. It skips semantic checks entirely.

## The Rule

### Typecheck command

```bash
npm run typecheck    # = tsc --noEmit -p tsconfig.app.json (or equivalent real config)
```

**Never** rely on bare `npx tsc --noEmit`. On any repo with a root tsconfig that uses project references + `"files": []`, that form checks nothing.

### Before declaring a PR ready

1. `npm run typecheck` — must exit 0 for files touched by the PR
   - If pre-existing errors in **unrelated** files appear, they are separate follow-ups; PR may still ship if only pre-existing errors remain and nothing new was introduced
   - New errors introduced by the PR are blockers
2. `npm run build` — must succeed (bundle integrity check)
3. Playwright smoke tests against a preview URL — must pass for any file in critical UI surfaces (pipeline, drawer, auth, checkout paths)

### Code-council reviewer prompts

When invoking `/code-council` or subagents, explicitly instruct:

> "For every identifier referenced in the diff, verify its declaration is in scope. If the declaration lives in a parent function and the usage is in a sibling function (common React pattern: one wrapper + one inner component in the same file), flag it as a scope bug. Always run `npm run typecheck` and treat non-zero exit as BLOCKING."

This override is required because diff-only analysis cannot catch cross-function references where both the declaration and usage pre-exist the diff.

## Technical Preventions

1. **`npm run typecheck` script in `package.json`** — runs the real TypeScript project check. Typical definition:
   ```json
   "scripts": {
     "typecheck": "tsc --noEmit -p tsconfig.app.json"
   }
   ```
2. **`typecheck` as a required CI status check** — dedicated job in `.github/workflows/ci.yml`, marked required via branch protection. Failure attribution is instant.
3. **SubagentStop hook** — `.claude/hooks/code-council-verification.sh` auto-downgrades code-council PASS verdicts to ADVISORY when they lack a verification artifact (terminal output, file:line citation, screenshot, or `VERIFIED:` prefix).
4. **`/ship` self-test canary** — `.claude/skills/ship/scripts/self-test.sh` validates the typecheck guard is actually checking files (≥20 files in config + tsc rejects a deliberate type error). Halts `/ship` if the guard infrastructure is broken.

## Logical Preventions (Reasoning Discipline)

The failure mode: a sequence of static analyses claim "clean" without ever running the code.

- "The diff is clean" → does not mean "the file is clean"
- "`tsc --noEmit` passed" → check WHICH tsconfig was used
- "`npm run build` passed" → bundling success ≠ semantic correctness under Vite
- "Council PASS/ADVISORY verdict" → review is sufficient for code-quality, **never** sufficient for "does this execute"

**Corollary**: any P0 hotfix touching a live production surface (pipeline, drawer, auth, payments) MUST be verified against a running preview deploy with real playwright smoke tests BEFORE declaring the PR ready. Static verdicts are advisory; runtime verdicts are authoritative.

## Discovering Pre-Existing Errors

The first time `npm run typecheck` runs against a real project config (after switching from bare `tsc --noEmit`), expect a burst of latent errors to surface. Typical classes:

- Library type mismatches (e.g., React PDF style type updates, Radix version drift)
- Possibly-undefined / possibly-null accesses in upload flows
- Literal-string vs union-type comparisons that produce dead branches
- Prop-type mismatches where a container component is passed where a leaf component is required
- Unsafe casts to `Record<string, unknown>` that hide real field references

**Handling**: fix in a dedicated "zero the baseline" commit (single author, single commit, no feature work mixed in). After baseline is clean, `typecheck` becomes a ratchet — it can only go down from there.

## Admin-Merge Policy — TYPECHECK FAILURES ARE NEVER ADMIN-MERGEABLE

Some projects admin-merge PRs when CI is red on flaky gates (e.g., chronically-flaky Playwright E2E). That allowance is NARROW and explicitly excludes typecheck.

### The hard rule

> A `typecheck` CI status of FAILURE is a HARD BLOCK. Admin-merge is prohibited. No exceptions — not for hotfixes, not for P0 production fires, not for "it's probably a transient."

### Why no exceptions

1. **Typecheck is NOT a flaky gate.** Unlike Playwright (network timing, auth state, viewport races), `tsc -p tsconfig.app.json` is deterministic. A failure is a real type error; a pass means the types resolve. There is no third "transient" state.
2. **The whole reason this gate exists** is the silent-no-op incident class where PRs ship with scope bugs because the gate checked zero files. Admin-muscle-memory bypassing a working gate reproduces the exact failure mode we installed the gate to prevent.
3. **"It's urgent" is not a reason to skip.** `npm run typecheck` runs in ~20-45s locally; the CI job is ~60-90s. Fixing a real type error takes less time than writing the admin-merge justification would.

### Decision tree (when CI is red on a PR)

| CI status pattern | Admin-merge allowed? | Reason |
|---|---|---|
| `typecheck` = FAILURE | **NEVER** | Real bug. Fix the type error. |
| `check` = FAILURE (lint/test) | Very rarely, with justification | Lint catches style; test catches logic. Both can occasionally flake. Document why. |
| `Vercel` (or deploy) = FAILURE | **NEVER** | Deploy is broken. Ship would brick production. |
| `playwright` = FAILURE only | Project-dependent | If chronically flaky and known-unrelated to PR content, some projects admin-merge per documented pattern. |
| `typecheck` + anything else = FAILURE | **NEVER** | Typecheck is authoritative; fix it first. |

### Enforcement

- **Branch protection**: `typecheck` job is a REQUIRED status check on `main` (configured via `gh api ... required_status_checks`). Without this, the policy is aspirational.
- **Documented rejection**: any admin-merge MUST leave a PR comment explaining which check failed and why the bypass was safe. If the comment can't name a non-typecheck failure, the merge was wrong.

### If the `typecheck` CI job ITSELF is broken

(e.g., `npm ci` fails because of a network blip, or `actions/setup-node` has an incident)

1. **Not the same thing.** A broken runner is not a type error. Re-run the job first (`gh run rerun`).
2. **If still broken**: open an issue, fix CI infra, do NOT ship the PR with a blind admin-merge.
3. **Self-test guard**: `/ship`'s preflight runs a TS canary (via `self-test.sh`) precisely so the developer knows locally when the gate is broken — before they get to admin-merge temptation.

## Related Rules

- `agentic-loop-guards.md` — pre-exit verification checklist (claim-with-evidence)
- `code-review-identity.md` — council reviewer identity / never soften critique
- `operational-guardrails.md` — git write safety and ship-it discipline
