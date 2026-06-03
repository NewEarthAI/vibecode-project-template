# CANONICAL — Roadmap Write-Back Phase

> **Single source of truth for the session-end roadmap write-back.** Every daily-plan-class skill in the project (always `daily-plan-generator`; optionally a second business/ops-roadmap sibling if the project has one) embeds a NAMED phase that delegates here verbatim. Symmetry across the present siblings is provable by `bin/verify-writeback-symmetry.sh`: it asserts every daily-plan skill found references THIS file by path and by the canonical phase name. Never fork this logic into a skill; amend here and all inherit.
>
> **Origin**: extracted from a parent project's extended council (6-agent, verdict PROCEED) on roadmap write-back enforcement. The deliberation that produced this contract lives in that project's `council/sessions/`; this template carries the generalised mechanism, not the project-specific session.
>
> **Architectural decision**: the markdown roadmap is the source of truth. Any queryable projection the project may have (a vault / knowledge-graph / search substrate) is DOWNSTREAM of the markdown, never the master. If the project has no such projection layer, skip the projection-sync step (W5) — everything else still applies.
>
> **Layman / register note**: this is a Claude-facing doctrine artefact — technical register is correct here (do not soften to layman in this file).

---

## Phase name (immutable identifier)

`Phase: Roadmap Write-Back`

NEVER number this phase. Phase numbers (e.g. "0B") frequently mean different things across sibling daily-plan skills; a numbered phase collides, a named phase does not. The symmetry check matches on this exact string.

## When it runs

At session end, AFTER all plan-step execution, BEFORE any Stop-hook step that backgrounds a projection sync. It is the last thing the *skill* does; the Stop hook (`.claude/hooks/roadmap-writeback-verifier.sh`) is an independent warn-only backstop that fires if this phase was skipped.

## The contract (deep module — small interface, all complexity hidden here)

INPUT: the set of plan items the session executed, each with the work actually done.
OUTPUT: for each item, exactly one of — `[x]` with an atomic evidence pointer / `[~]` with a machine-readable reason tag / left `[ ]` (untouched, not worked).
SIDE EFFECT: if a queryable projection layer exists, a synchronous roadmap→projection sync, then a last-run sentinel write. If no projection layer exists, the sentinel still records the tick set.

The caller never sees the evidence-typing, verdict extraction, concurrency control, or sync ordering. Those live entirely below.

`{{roadmap_path}}` = the project's roadmap markdown (default `ROADMAP.md`; a project may have more than one roadmap surface — apply per-item to whichever roadmap owns the item).

---

## Step W1 — Acquire the ROADMAP lock

The write-back, any roadmap-compaction tool, and any sibling session all mutate the same roadmap markdown. Use the POSIX-atomic `mkdir` lock primitive (file writes are NOT atomic on APFS/most fs; `mkdir` is):

```
LOCK_DIR="/tmp/roadmap-writeback.$(echo "$ROADMAP_PATH" | shasum | cut -c1-12).lock"
if mkdir "$LOCK_DIR" 2>/dev/null; then :; else
  # lock held — inspect age; owner metadata > 10 min old → crashed, steal;
  # future-dated > 60 min → clock-skew corruption, steal. Else DEFER:
  # do not skip — record "writeback-deferred"; the Stop hook will warn.
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT INT TERM
```

Any roadmap-compaction/archival tool MUST take the same lock.

## Step W2 — For each executed item: TYPE the evidence and extract a VERDICT (the keystone)

"Verifiably completed" is NOT "an artefact path exists". The originating failure: a blank-template findings artefact was ticked "done" with no verdict — it *existed* and passed a naive existence check. The gate verifies the artefact *says something*:

| Evidence kind | Verdict check (must PASS to permit `[x]`) | Reject → reason tag |
|---|---|---|
| Review/council session path | File contains a synthesis / `VERDICT:` / decision block. Exists-but-no-verdict = FAIL. | `(evidence-failed: review-no-verdict)` |
| Commit SHA | `git show --stat <sha>` touches ≥1 path on the item's domain allowlist (W2a). A reverted SHA (a later `Revert "...<sha>..."` exists) = FAIL. | `(evidence-failed: sha-off-domain)` / `(evidence-reverted)` |
| Test output | Contains `≥1 passed` AND `0 failed` AND is not all-skipped / `0 passed`. | `(evidence-failed: test-empty)` |
| DB row id | Row satisfies the per-item predicate (default: a "tracked/active" flag true AND the substantive body NOT NULL — guard against stub rows). | `(evidence-failed: row-stub)` |
| (none supplied) | n/a — work happened but produced no extractable artefact. | `(partial: no-artefact)` |

**Outcome polarity: fail-CLOSED on the tick, fail-OPEN on session exit.** No passing verdict → the item does NOT receive `[x]`. It is written `[~]` with the reason tag inline AND added to the loud-escalation list surfaced at the TOP of the next daily-plan. The session still exits (it does not block). A false `[x]` is structurally impossible; a stale `[~]` is recoverable and visible.

### W2a — Domain allowlist for SHA evidence

Each roadmap section declares (or inherits a default) a path-glob domain. An item's SHA must touch a path in that domain; a docs-typo SHA cited for a feature/fix FAILS. Absent an explicit per-section domain, default the allowlist to "any non-docs path" (`*.md`-only diffs cannot substantiate a non-docs completion).

## Step W3 — Atomic tick write, matched on a STABLE identifier

- Match the item by a stable identifier — an owner/section tag + a short content slug — NEVER a line number (compaction or a sibling edit moves lines).
- Optimistic concurrency: re-read the matched item's line at write time; if its text changed since W2 read it, ABORT this item's tick, record `(writeback-aborted: text-drift)`, escalate.
- The tick is ONE write: `- [x] **<tag> <item text>** … (evidence: <kind>:<pointer> · verified <UTC>)`. Never a bare `[x]` followed by a separate citation — the checkbox flip and the evidence are one atomic string.
- Idempotency: already `[x]` with a matching pointer → no-op. Already `[x]` with a *different* pointer → conflict signal: do not overwrite; record `(conflict: evidence-mismatch)`, escalate.

## Step W4 — `[~]` is never terminal

Every `[~]` carries a machine-readable reason tag (from W2, or `(blocked: <dep>)` / `(partial: <n>/<m>)`) AND an age (session count since first set). Any `[~]` older than N=3 sessions auto-escalates to the TOP of the next daily-plan as "stale partial — adjudicate". `[~]` filters as neither done nor untouched.

## Step W5 — Synchronous projection sync, THEN sentinel (skip if no projection layer)

If the project has a queryable projection (vault / knowledge-graph / search substrate): this phase runs BEFORE any Stop-hook step that backgrounds that sync. The roadmap→projection sync for the just-ticked items runs **synchronously (foreground)** — NOT backgrounded/detached. Accept the small added exit latency: the roadmap delta is tiny, and a backgrounded sync produces the ticked-but-not-synced failure this whole mechanism exists to prevent.

After the sync returns (or immediately, if there is no projection layer), write a last-run sentinel (a small JSON status file, mirroring any existing last-run-status pattern the project uses): `{ "ts": <UTC>, "roadmap_mtime": <mtime>, "synced_items": [...], "sync_rc": <code> }`. The NEXT session's W0 pre-check reads it.

## Step W0 — Pre-check (runs at the START of this phase, reads the prior sentinel)

Before W1: read the last-run sentinel. If the previous session's sync failed or its snapshot is stale vs the roadmap mtime, surface a loud one-line warning and include the affected items in this session's escalation list (recovers a silently-failed prior sync).

## Step W6 — Periodic evidence re-validation

Once per phase, grep recent git history for `Revert "..."` commits whose subject names a SHA currently cited as `[x]` evidence anywhere in the roadmap. Any hit → flip that item to `[~] (evidence-reverted)` and escalate. A reverted SHA still exists in history, so without this an item stays falsely-complete forever, contradicted by no surface.

---

## What this phase MUST NOT do

- MUST NOT auto-downgrade a human-set `[x]` from prose inference (only act on items the SESSION executed, with verified evidence, or the W6 revert check).
- MUST NOT widen any vault/projection sync allowlist to reach session-handoff/continuation directories (keep the projection layer curated).
- MUST NOT hard-block session exit (enforcement is the warn-only Stop hook).
- MUST NOT match items by line number.

## Symmetry contract

Every daily-plan-class skill the project ships MUST contain a section whose heading is exactly `## Phase: Roadmap Write-Back` whose body delegates to this file by path. `bin/verify-writeback-symmetry.sh` asserts: (1) every present daily-plan skill carries the identical heading, (2) each references this canonical path, (3) none inlines a forked copy of W0–W6. With one daily-plan skill the check still verifies delegation + non-fork; with two or more it additionally proves mutual symmetry. A failing symmetry check is a required-artefact block in the shipping PR.
