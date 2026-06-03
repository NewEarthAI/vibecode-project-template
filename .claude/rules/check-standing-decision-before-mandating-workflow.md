# Check for a Contradicting Standing Decision Before Mandating a Workflow

**Scope**: any session about to encode a WORKFLOW or DEFAULT into durable
infrastructure — a skill's "how to use" block, a rule file, the template repo,
or a hook. NOT for one-off task output (a single continuation, a single commit);
those don't propagate.

**Origin**: 2026-05-21. A session added a "Step 0 — create a worktree per job"
block into two prompt-generating skills AND pushed it to the template repo —
while a standing-but-unexecuted operator decision to retire worktree-per-job
(go single-folder) sat pending in `continuations/`. The new default directly
contradicted the standing decision. The operator caught it by asking "what's
wrong with one folder?"; three reversal commits were queued. A single grep of
`continuations/` for the workflow noun before shipping would have caught it.

---

## The principle

Durable infrastructure propagates a default to **every future session** AND —
via the template — **every future project**. Shipping a default that
contradicts a standing-but-unexecuted decision is worse than a one-off mistake:
it hardens the wrong behaviour into the substrate, where it silently re-seeds
itself on every run until someone notices and reverses it across all the
places it spread.

So: before you encode "always do X workflow" into a skill / rule / template /
hook, verify no standing decision says "stop doing X" or "do the opposite of X."

---

## When this rule fires

You are about to add or change a WORKFLOW DEFAULT in any of:

- a skill's instructions / "how to use" / setup block
- a `.claude/rules/*.md` file
- the template repo (anything `/push-to-template` would copy)
- a hook (PreToolUse / PostToolUse / SessionStart)

If the change merely produces a one-off artefact (a continuation, a single PR,
a research note), this rule does not fire — those don't propagate.

---

## The 30-second check

Before shipping the default:

```bash
# Replace <workflow-noun> with the thing you're mandating (e.g. "worktree",
# "branch", "deploy", "migration", "force-push").
grep -ril "<workflow-noun>" continuations/ .claude/rules/
```

Read any hit that is a pending continuation (`impl_status: pending`) or a
standing decision. If it says the OPPOSITE of what you're about to ship:

1. **STOP** — do not propagate.
2. Reconcile: either the standing decision is stale (then retire it explicitly
   + record why), or your new default is wrong (then don't ship it).
3. Only ship the default once it agrees with — or has explicitly superseded —
   the standing decision.

---

## Distinct from two adjacent rules

- **`dont-conflate-inflight-programme.md`** — about *subsumption* claims ("this
  existing thing already covers X"). Read before you CLAIM coverage.
- **`doctrine-currency-check.md`** — about *currency* ("is the doctrine I'm
  citing still true against current code?"). Triple-cite before propagating.
- **This rule** — the *contradiction-mirror*: "am I shipping a NEW default that
  fights a standing decision I never checked for?"

All three share a root: durable claims/defaults must be checked against the
current state of decisions + code before they propagate.

---

## What this rule is NOT

- **Not a blocker on one-off work** — only fires for durable-infra defaults.
- **Not a substitute for the framing audit** — that checks whether the question
  is right; this checks whether a default contradicts a standing answer.
- **Not retroactive** — applies forward from the moment it lands.
