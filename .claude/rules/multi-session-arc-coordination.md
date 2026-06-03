# Multi-Session Arc Coordination Protocol

**Origin**: 2026-05-06, after Justin asked whether the Acquisition Co-Pilot continuation prompt actually keeps parallel chats aligned. Honest answer was: NOT YET — added single-chat discipline but missing multi-chat layer.
**Pairs with**: `.claude/rules/worktree-discipline.md` (per-worktree isolation), `.claude/rules/agentic-loop-guards.md` (verification gates), master-continuation-prompt skill (impl_status frontmatter).
**Applies to**: ANY work plan with ≥3 sessions where parallel execution across multiple chats / Macs / worktrees is plausible.

---

## The principle

A multi-session arc with 10+ sessions is a coordination problem disguised as a planning problem. Justin runs ~12 worktrees and frequently has 3-6 chats active simultaneously. Without an explicit coordination protocol, two chats can:

- Both claim the same session and ship duplicate / conflicting work
- Both edit the same files in different worktrees and produce merge hell
- Build downstream sessions on assumptions that an upstream session quietly invalidated
- Mark `impl_status: completed` based on stale local state when origin has moved
- Lose track of which decisions were made vs. still open

This rule defines the coordination discipline that prevents all of these.

---

## When this rule fires

Every chat that picks up work on a multi-session arc MUST follow this protocol. The arc qualifies if ANY of these are true:

- It has a master continuation prompt at `continuations/*MASTER-CONTINUATION*.md`
- It has a session-numbered phase plan (S1, S2, S3...)
- It has a dedicated spec session directory at `specs/sessions/<date>-<slug>/`
- The work spans more than one session
- The work plan explicitly mentions parallel execution

If in doubt: assume yes. The protocol is cheap; coordination failures are expensive.

---

## The 5-Ritual Discipline

### Ritual 1 — Session-Start (BEFORE doing anything)

Before reading the substantive content of the continuation prompt:

```bash
# 1. Pull latest state from origin (the only source of truth)
cd <arc_worktree>
git fetch --all --prune
git pull origin <arc_branch_or_main>

# 2. Read the arc's PROGRESS-LOG in full
cat specs/sessions/<arc-slug>/PROGRESS-LOG.md

# 3. Re-read the continuation prompt's impl_status block at HEAD (not local cache)
git show HEAD:continuations/<MASTER-CONTINUATION-FILE>.md | head -10

# 4. Survey recent activity across the arc
git log --oneline -30 --all --since="14 days ago" -- specs/sessions/<arc-slug>/ continuations/<MASTER-CONTINUATION-FILE>.md
gh pr list --state all --search "<arc-keyword>" --limit 20

# 5. Survey completed deliverables
ls -la council/sessions/2026-*-<arc-slug>* 2>/dev/null
ls -la specs/sessions/<arc-slug>/forges/ 2>/dev/null
```

If any of these surfaces something unexpected — a session you thought was open is actually claimed, a forge you thought existed isn't there, a council verdict reversed an architectural decision — STOP and reconcile before proceeding.

### Ritual 2 — Session-Claim (BEFORE writing any artefact)

Once you've identified your session candidate, claim it visibly:

```bash
# 1. Append to PROGRESS-LOG.md
cat >> specs/sessions/<arc-slug>/PROGRESS-LOG.md <<EOF

## [<session-id>-<your-fingerprint>] | CLAIM | $(date '+%Y-%m-%d %H:%M %Z')
- Session: <e.g., S1 — Council architecture lock-in>
- Picked up by: chat-<short-id-or-description>
- Worktree: <absolute path>
- Branch: <branch name>
- Expected output: <list of artefacts you intend to produce>
- Status: in_progress

EOF

# 2. Commit + push immediately so other chats see the claim
git add specs/sessions/<arc-slug>/PROGRESS-LOG.md
git commit -m "log: <session-id> claim by chat-<short-id>"
git push origin HEAD

# 3. Verify push succeeded — only proceed if origin shows your claim
git fetch && git log origin/HEAD --oneline -1
```

If `git push` fails because someone else pushed first: re-pull, re-read PROGRESS-LOG, check if their claim conflicts with yours. If yes, pick a different session per §Parallel Safety. If no, retry your claim.

**The push-before-work discipline is non-negotiable.** A claim that exists only on your local machine is invisible to other chats and offers zero coordination value.

### Ritual 3 — Mid-Session Heartbeat (after each significant milestone) — [SINGLE-MAC NOTE: optional for solo-Mac arcs]

**Single-Mac calibration (per Justin 2026-05-06)**: When the operator runs a single Mac with sequential chats (not multi-Mac parallel), heartbeat cadence relaxes to "after each artefact write" rather than "every 30 min." Silence is only treated as orphan after >2 hours of no commits AND no chat-active signal. The full heartbeat discipline only re-engages when a second Mac comes online.

A "significant milestone" is anything other chats need to know about:

- Council verdict reached
- Forge spec authored
- Migration applied
- Edge function deployed
- Build wave PR opened
- Blocked on Justin's decision
- Discovered a constraint that affects other sessions

For each milestone:

```bash
cat >> specs/sessions/<arc-slug>/PROGRESS-LOG.md <<EOF

## [<session-id>-<fingerprint>] | MILESTONE | $(date '+%Y-%m-%d %H:%M %Z')
- What: <one-line description>
- Artefacts: <files/commits/PRs created>
- Affects other sessions: <YES/NO + which sessions if YES>
- Notes: <anything other chats need to know>

EOF

git add specs/sessions/<arc-slug>/PROGRESS-LOG.md
git commit -m "log: <session-id> milestone — <slug>"
git push origin HEAD
```

Heartbeat cadence: at least every 30 min of active work. Silence ≥1 hour means another chat may treat your session as stale.

### Ritual 4 — Session-End (BEFORE marking complete)

Before claiming the session is `completed`:

```bash
# 1. Run the verification commands from the continuation prompt §14 for your session
#    (e.g., test -f council/sessions/<slug>.md && grep -q "Strategic Alignment" $_)

# 2. Update impl_status in the continuation prompt
#    Edit the frontmatter block: pending → completed
#    Set impl_completed_date

# 3. Append session-end entry to PROGRESS-LOG.md
cat >> specs/sessions/<arc-slug>/PROGRESS-LOG.md <<EOF

## [<session-id>-<fingerprint>] | END | $(date '+%Y-%m-%d %H:%M %Z')
- Completed: <session description>
- Output artefacts (paths + commits + PRs):
  - <list>
- Verification: <PASS/FAIL with evidence>
- Decisions made: <list of decisions resolved this session>
- Decisions deferred: <list of decisions that emerged but were not resolved>
- Next-up suggestion: <which session should run next, given current state>
- Status: completed | blocked | needs-decision

EOF

# 4. Commit + push BOTH the impl_status update AND the log entry
git add continuations/<MASTER-CONTINUATION-FILE>.md specs/sessions/<arc-slug>/PROGRESS-LOG.md
git commit -m "complete: <session-id> + log session-end"
git push origin HEAD
```

If your session ends in `blocked` or `needs-decision` state: write the specific question/decision needed in the log entry, and route it explicitly (Justin's input vs. council vs. research). Don't leave it implicit.

### Ritual 5 — Conflict Detection (continuous, lightweight)

Throughout your session, watch for collision signals:

- `git fetch` periodically — if origin has new commits on your arc paths since you started, READ THEM before continuing
- If your worktree's branch diverges from origin (someone pushed to your branch from another machine): pause, reconcile, do NOT force-push
- If PROGRESS-LOG shows another chat working on a session that overlaps your file scope: SendMessage to coordinate, OR pause, OR pick a different scope
- If `impl_status` of YOUR session is `in_progress` but with a different `impl_session` value than yours: another chat claimed it before you. STOP your work, pick a different session, log the abandoned attempt.

---

## Parallel Safety — Generic Rules

Most arcs follow these dependency patterns. The continuation prompt for each arc should embed an arc-specific matrix — but the generic rules below apply universally.

| Session type | Can run in parallel with | CANNOT run in parallel with |
|---|---|---|
| **Architecture council** (gating) | (alone — first) | All downstream sessions |
| **Independent research** (data-only) | Other independent research | Specs that depend on its output |
| **Forge specs** (independent scope) | Other independent forges | Build waves that depend on the forge |
| **Build waves** | Other build waves IF AND ONLY IF disjoint files + disjoint DB tables + disjoint workflows | Other build waves on shared files/tables |
| **Final polish + verification gate** | (alone — last) | (nothing) |

**Sharing rules**:
- Two chats CANNOT edit the same file in two worktrees simultaneously without merge pain
- Two chats CANNOT migrate the same DB table simultaneously without race / data loss
- Two chats CANNOT modify the same n8n workflow simultaneously (last-write wins; the loser's work is silently destroyed)

**When in doubt about parallelism**: serialize. Ask Justin if uncertain. The cost of serializing two genuinely-parallel sessions is ~30 min of wall clock; the cost of corrupting work is hours-to-days of recovery.

---

## PROGRESS-LOG.md format

Every multi-session arc gets a single append-only `PROGRESS-LOG.md` at `specs/sessions/<arc-slug>/PROGRESS-LOG.md`. Format:

```markdown
# Arc Progress Log — <Arc Title>

**Arc charter**: <link to REPORT.md>
**Master continuation**: <link to MASTER-CONTINUATION.md>
**Created**: <date>
**Discipline**: append-only. Never edit prior entries. Never delete entries.

---

## [<session-id>-<fingerprint>] | <CLAIM | MILESTONE | END> | <timestamp>
- (entry content per ritual)

## [<session-id>-<fingerprint>] | <event> | <timestamp>
- ...
```

Format rules:
- **Append-only**: never edit prior entries. If you need to correct, append a new entry that supersedes.
- **One H2 per event**: makes scrolling + searching easy
- **Fingerprint = short identifier** for the chat (could be the date+time of session start, or a UUID-prefix, or "alice-mac" / "main-mac" — whatever makes it greppable)
- **Timestamps include timezone**: `+%Y-%m-%d %H:%M %Z` — Justin works across timezones
- **Status field always present**: `in_progress | completed | blocked | needs-decision | abandoned`

The log is the **source of truth** for arc state. The continuation prompt's `impl_status` is a summary of the most recent log entry per session — derived, not authoritative.

---

## Anti-patterns

| Wrong | Why | Right |
|---|---|---|
| Read the continuation, start working immediately | No survey of what other chats have done | Run Ritual 1 first, every time |
| Update `impl_status` without pushing | Other chats see stale state | Push immediately after every status change |
| Edit prior PROGRESS-LOG entries | Append-only is a discipline, not a suggestion | Append a superseding entry, leave original |
| Two chats both editing the same forge spec | Merge hell + lost work | First-claimer wins; second chat picks different scope |
| Mark `completed` without running verification commands | The verification IS the completion criterion | Run + paste verification output in END entry |
| Silent multi-hour work without heartbeat | Other chats treat session as stale, may take it over | Heartbeat ≥ every 30 min |
| Force-push to resolve divergence | Destroys the other chat's pushed work | Pause, reconcile, merge. Force-push is reserved for explicit user authorization. |
| Skip session-claim because "I'll only be 5 min" | 5 min becomes 50; meanwhile another chat claimed it | Always claim, even for short sessions |

---

## Edge cases

**Multiple Macs, single Justin**: same protocol. Each Mac is a "chat" for coordination purposes. PROGRESS-LOG fingerprint can include hostname.

**Justin manually editing files in the arc**: treat as an unauthenticated chat. Justin should append a CLAIM entry himself before editing, OR notify the chat he's collaborating with via direct message. The protocol degrades gracefully.

**Chat crashes or context-compacts mid-session**: next chat resuming should look for the last CLAIM with no matching END or ABANDON entry; assume the prior chat orphaned. Append an `ABANDONED` entry on its behalf and pick up where it left off, OR start fresh — the END entry of the new attempt should reference the abandoned one.

**Council session collides with a build wave that depends on its outcome**: NEVER. Build waves are gated on council verdict per the dependency matrix. If you find yourself wanting to start a build before its gating council, STOP — that's the protocol catching a real coordination error.

---

## Composition with existing rules

- `.claude/rules/worktree-discipline.md` — every parallel chat works in its own `~/code/<repo>-<scope>` worktree. The protocol assumes worktrees, not branches in shared trees.
- `.claude/rules/agentic-loop-guards.md` — every session-end runs the pre-exit verification checklist BEFORE writing the END entry.
- `.claude/rules/operational-guardrails.md` Rule 11 — re-verify file state before executing a plan authored earlier (multi-worktree hazard). The protocol's Ritual 1 + Ritual 5 implement this for arc work specifically.
- `master-continuation-prompt` skill §5A — `impl_status` frontmatter remains; PROGRESS-LOG is the audit trail behind it.

---

## Why this matters

Justin's quality mandate (verbatim from the originating session): *"as if you have a whole team of full-stack developers and real estate SaaS experts working together, and we don't move forward until they all agree on everything."*

A team of full-stack devs working in parallel on a 15-session arc has standups, a kanban board, an issue tracker, and merge-conflict discipline. Multiple Claude chats running in parallel have NONE of those by default. This protocol is the lightweight substitute — append-only file as kanban, git as truth, push-before-work as commit-before-merge.

Without it, the 15-session arc becomes a coordination disaster within 3 days. With it, the arc behaves like a real team would.

---

## Failure precedent

Will be added on first protocol violation. Update this file with the incident + lesson.

---

## Orphan TTL (added 2026-05-06 amendment A7)

A CLAIM with no matching END or ABANDONED entry is "orphaned" when:
- Single-Mac mode: >2 hours since last push from that session ID AND >2 hours since any commit by the operator on the arc branch
- Multi-Mac mode: >1 hour since last push from that session ID

Next chat picking up a session sees an orphaned CLAIM should:
1. Append an `ABANDONED` entry on behalf of the orphan
2. Note in their own CLAIM that they're picking up an abandoned session
3. Read any partial work the orphan committed (via `git log --oneline -- <arc-files>`) before starting fresh

## Ritual 1 enhanced — direct-edit detection (added 2026-05-06 amendment A11)

In addition to reading PROGRESS-LOG, run:

```
git log --oneline -20 -- specs/sessions/<arc-slug>/ continuations/<MASTER-CONTINUATION-FILE>.md .claude/rules/multi-session-arc-coordination.md src/lib/calculator/ supabase/migrations/
```

to surface direct edits to arc files that bypassed the protocol (Justin manually editing, hotfix chat touching arc files, etc.). Any commits since your last session that aren't matched to PROGRESS-LOG entries indicate either Justin-edits or protocol violation. Reconcile before claiming.

## Ritual 2 enhanced — `success_criteria:` block in CLAIM (added 2026-05-06 amendment A5)

Every CLAIM entry MUST include a `success_criteria:` sub-block with outcome-only criteria authored BEFORE work begins:

```
## [<session-id>-<fingerprint>] | CLAIM | <timestamp>
- Session: <name>
- Picked up by: <fingerprint>
- success_criteria:
  1. <observable outcome 1>
  2. <observable outcome 2>
  3. <observable outcome 3>
- Verification commands:
  - <command 1>
  - <command 2>
- Status: in_progress
```

Implementation before verification criteria are authored = horizontal slicing trap. CLAIM without `success_criteria:` is invalid; next chat treats as malformed and either rejects or appends a corrective entry.

## Path resolution — use `git rev-parse` (added 2026-05-06 amendment A6)

Verification commands MUST use `git rev-parse --show-toplevel` to resolve repo root, not hardcoded `/Users/justin/code/BuyBox-AI/` paths. Hardcoded paths fail when a chat opens in a different worktree path.

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
test -f "$REPO_ROOT/specs/sessions/<arc-slug>/REPORT.md"
```

## Calendar reminders (added 2026-05-06 amendment A10)

GitHub PAT rotation reminder: ~2026-07-05 (60 days from arc start). Set in your calendar / reminder app. PAT expiry mid-arc → push-fail-quiet → silent claim/coordination failures. Audit before any session past July 1.

## Single-Mac calibration (added 2026-05-06 per Justin's D6 answer)

When the operating reality is single-Mac with at most 2-3 sequential chats (the default for this project's primary operator):

- Heartbeat (Ritual 3) is OPTIONAL — heartbeat after artefact writes only, not on a 30-min timer
- Ritual 5 (conflict detection) runs only at session boundaries, not continuously
- The full multi-Mac protocol re-engages automatically when a second Mac is detected via PROGRESS-LOG fingerprint diversity

For the Acquisition Co-Pilot arc specifically (single-Mac per Justin 2026-05-06): assume single-Mac calibration unless an entry in PROGRESS-LOG indicates otherwise.


---

## Council Convergence Across Parallel Chats (added 2026-05-14)

**Observation**: when two parallel autovibe chats run independent multi-lens code-council passes on the SAME diff (typically a P0 fix), they converge on the SAME defect-set with high reliability. This is a positive validation signal for the council protocol — and it informs how to handle the second chat's findings without producing duplicate PRs.

**The pattern (canonical 2026-05-14 precedent — Killer Bee dedup-graveyard fix)**:

1. Chat A ships PR #743 (Layers 1+2+3 read-side defence) at 21:32 UTC. Chat A's session pauses for a browser smoke test against production.
2. Chat B (parallel autovibe, fresh from `feat/post-webinar-stabilisation` after PR #743 merged) runs `/code-council` on the merged code, finds a CRITICAL `silent-failure-hunter` finding: WRITE-side null-pollution in the new-property INSERT path.
3. Chat B ships PR #744 with the Layer-1b fix (filter-join discipline on `normalized_address` + `idempotency_key` construction) at 23:45 UTC, admin-merges at 21:51 UTC.
4. Chat A resumes, notices commit `8368b5f8` on the branch that it did not author, reads the commit body, recognises the parallel-chat work.
5. Chat A runs its own `/code-council` on PR #744's diff. Its `silent-failure-hunter` agent independently finds the SAME defect class (write-side null-discipline) AND surfaces 2 additional IMPORTANT findings (all-empty `portal:` idempotency-key collision + street-only `portal:<street>` collision).
6. Chat A ships PR #745 with Layer-1c + Layer-1d backstop guards. Final layer count: 5 defence layers + 2 telemetry checkpoints + 1 hard-reject guard.

**The lesson**: parallel-chat-council convergence is the council protocol working as designed. The agents don't talk to each other; they review the same code through specialised lenses; they converge on the same defects when the defects are real. Treat the sibling chat's findings as INDEPENDENT VERIFICATION of your own, not as a duplicate effort.

### How to handle parallel-chat work mid-stream

When you discover an unexpected commit on YOUR branch (or a sibling PR on the same arc):

1. **Read the commit body first**. The sibling chat's commit message typically names the defect class + the council finding it closes. If the commit body matches a defect class YOUR session was about to address, the sibling already shipped it — no duplicate work.

2. **Read the sibling chat's council session file** (if persisted to 📁 `council/code-reviews/`). The findings they DIDN'T act on are your follow-up surface — the IMPORTANTs and SUGGESTIONs they deferred.

3. **Re-run YOUR council on the sibling's diff**. Your council agents may find findings the sibling's agents didn't. (Today's session: Chat A's `silent-failure-hunter` found 2 IMPORTANTs on PR #744 that Chat B's council had not surfaced. Both became PR #745.)

4. **Union the findings**. The shipped state is `parent_PR ∪ sibling_PR ∪ your_follow-up_PR`. Each layer adds defence-in-depth without duplicating the others.

5. **Update the arc PROGRESS-LOG with a FOLLOW-UP-MERGED entry** noting the sibling chat's contribution + your follow-up's contribution. Cross-link both PR numbers + commit SHAs.

### What to avoid

- **Re-implementing the sibling's fix**: read their commit body, recognise the work is done, move on to the follow-up surface.
- **Force-pushing over the sibling's commit**: their commit is already merged; force-push to a sibling branch is a `bash-guardian.sh` HARD STOP. Pull + base your follow-up on the post-merge state.
- **Cancelling your own session because "they already did it"**: the sibling closed ONE finding. Your council may have findings they missed.

### Convergence as positive signal — when to trust it

If two independent council runs surface IDENTICAL CRITICAL findings on the same diff, treat that as ≥95% confidence the finding is real. Ship the fix immediately.

If only YOUR council surfaces a finding the sibling missed, treat as ~80% confidence — still worth shipping but worth a second look (the sibling may have implicit context yours didn't have).

If the two councils DISAGREE on a CRITICAL (one chat says ship, the other says block), treat as <50% confidence — escalate to the operator for adjudication. Disagreement on CRITICAL severity is a signal the finding is ambiguous and needs human judgement.
