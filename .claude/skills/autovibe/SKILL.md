---
name: autovibe
description: |
  Top-of-stack autonomous shipping orchestrator. One invocation handles the
  full goal-audit→plan→execute→code-council→ship loop, or routes trivial
  work directly to /ship quick. Composes /ship, /execute, /code-council,
  /prompt-forge, prime-lite, the framing-audit primitives, and the Pocock
  toolkit. Strategy council (/council --extended) + /amend-plan retired
  from the autofire loop 2026-05-23 — rabbit-hole detours, work not
  finishing. /council itself survives as a MANUAL operator skill outside
  autovibe; /code-council (DIFF reviewer for shipped code) stays at step 7.
  Never reimplements composed-skill logic; reads/writes its own state file
  (.claude/autovibe-state.json) for crash-safe resume. Dual-use: same code
  path serves direct human invocation and programmatic call sites — only
  AUTOVIBE_FORMAT=json toggles the output serializer.
  Use when: /autovibe, "ship this end-to-end", "do the whole flow",
  "I want autonomous shipping for X".
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, Skill
user-invocable: true
version: 1.0.1
classification: encoded-orchestration
status: Phases 0-5 complete; Phase 6 (dogfood) deferred to first live invocation
---

# /autovibe — Autonomous Shipping Orchestrator

> **Philosophy**: Compose, don't rebuild. State file is the contract. Hotfix is human-only. Triage fails closed (ambiguous → planned mode). Dogfood the build.

**Supersedes**: nothing — fills the gap between manual `/plan → /council → /execute → /ship` and the unrunnable monolithic-script alternatives.

---

## Phase Status

| Phase | Component | Status |
|-------|-----------|--------|
| **0** | Decision sign-off (`specs/autovibe-design-decisions-2026-04-19.md`) | Complete |
| **1** | `prime-lite` primitive | Complete (863 words / 1353ms verified) |
| **2** | `triage.sh` D2 trigger list | Complete (7 synthetic tests pass) |
| **3** | Core orchestrator (SKILL + scripts + modes + command) | Complete (DRYRUN verified) |
| **4** | Post-push documentation step | Complete (clean=skip; rollback/admin-merge/non-zero=write) |
| **5** | 6-scenario eval harness | Complete (markdown checklists, 373 lines) |
| **6** | Dogfood: ship Autovibe with Autovibe | **Deferred** — runs on first live `/autovibe` invocation post-merge |
| **post-council** | Hardening per code-council 2026-04-19 BLOCKING verdict | Complete (jq state ops, trap fix, heredoc sanitization) |

> Note: Phase 6 deferral is **not** blocking — the orchestration contract is verified via DRYRUN and unit tests. Live dogfood validates the conversation-handoff layer that no shell harness can simulate.

---

## Dispatch

| Invocation | Action |
|---|---|
| `/autovibe "<intent>"` | Run flow per triage outcome |
| `AUTOVIBE_DRYRUN=1 /autovibe "..."` | Print every command, execute none, exit 0 |
| `AUTOVIBE_FORMAT=json /autovibe "..."` | One JSON line per phase to stdout |

The skill itself wraps `scripts/orchestrate.sh`. The shell script handles preflight + lock + triage. The CONVERSATION (this skill running in a Claude session) handles the composed-skill invocations — `Skill ship`, `/council --extended`, etc. — because skills require conversation context the shell can't provide.

---

## Mode Detection

Triage script (`scripts/triage.sh`) classifies the work:

```
triage.sh "<intent>" → stdout: plan|direct|ambiguous, stderr: reason
```

| Outcome | Branch | Ship mode |
|---|---|---|
| `direct` | `modes/direct.md` | `/ship quick` |
| `plan` | `modes/planned.md` | `/ship pr` |
| `ambiguous` | `modes/planned.md` (fail-safe escalation) | `/ship pr` |

D2 trigger list lives in `triage.sh` and `references/decisions-locked.md`. Editable by editing the `case` blocks in `triage.sh` and re-running evals.

---

## Framing Audit (mandatory — one checkpoint)

Per `.claude/rules/framing-audit-mandate.md`, a framing audit — confirming the work is the
*right question* before it is answered — is compulsory before load-bearing, multi-phase
work. `/autovibe` IS such work, so **planned mode** runs the audit at one checkpoint
before any plan is drafted:

| Checkpoint | When | Audits | Defined in |
|---|---|---|---|
| Goal audit | step 2a, before `EnterPlanMode` | the raw INTENT / GOAL | `modes/planned.md` step 2a |

The 1-minute first-principles check on the GOAL catches wrong-framings at the higher-leverage
point (before the plan, not after). Plan-side framing review is now an operator self-check
during ExitPlanMode review (step 5) rather than a council-driven Reframer pass — the strategy
council was retired from the autofire loop 2026-05-23 because the 8-agent deliberation reliably
produced rabbit-hole detours and work never actually finished. Goal audit runs the matching
primitive (`/reduce-to-first-principles`, `/check-commensurability`, or `/map-feedback-loops`
DECISION mode), records the verdict, and HALTs on a flagged frame.

**Direct mode** (trivial work) runs no framing audit — correct per the mandate rule's
not-for-trivia scope.

Cite the primitives; never copy their procedures — see `framing-audit-mandate.md` for the
full trigger table and the five primitives.

---

## Research-Only Continuation Pivot

When the user invokes `/autovibe <continuation-file>` and the file is research-only (no code to ship at the end), DO NOT run the plan → council → execute → ship loop. There is no PR target — the deliverable is a research artefact, not a code change. Forcing autovibe through means `/ship` fails with no diff.

**Pivot pattern**:
1. One-sentence layman heads-up: "/autovibe ships code via PR; this is research → using /agent-research instead"
2. Invoke `/agent-research` with the continuation's worker spec as the prompt
3. After synthesis + verification + commit, write a Round 2 + Round 3 follow-up continuation if the original spec called for multi-round design (see `agent-research` skill's "Multi-Round Research" section if shipped)

**Detection signals (any one is sufficient — fail closed to pivot if uncertain)**:
- Continuation file constraints section says "No code changes in this session" / "pure research"
- Deliverable section mentions SCQA, hazard-ratio matrix, or "research workers"
- Original master prompt was authored by `/agent-research` previously (look for `council/audits/` predecessors)
- File header contains "research" / "audit" / "synthesis" / "deep-research"

**Precedent**: 2026-05-03 velocity research session. User invoked `/autovibe continuations/VELOCITY-...`; correct pivot to `/agent-research` shipped 10-worker research + verifier + Round 2/3 continuation in single session. See commit 2098ad31 for the artefact.

---

## Foundation-First Shipping (operator self-check during ExitPlanMode review)

When the drafted plan looks heavy at ExitPlanMode review (step 5), the operator runs this self-check before accepting the plan. No council required — this is operator judgement on the plan you just read.

**Don't compress heavy plans into one session.** That forces a thin-shell intermediate state that ships silent failures.

**Detection signal — if 3 of 4 hold during plan review, default to foundation-first**:
- Plan stacks 3+ defenses (rate-limit + idempotency + reaper + audit-trail + …)
- Plan touches 3+ surfaces (edge fn + migration + n8n workflow + UI + …)
- Plan carries 3+ specific time-bombs (rate-locked APIs, partner-facing data fidelity, RLS, etc.)
- Honest ship-date confidence for one session < 70%

**Ship the foundation PR this session**:
- Contract specs (URL shapes, schema decisions, integration boundaries)
- Additive migrations (idempotent, low-risk, `NOTIFY pgrst, 'reload schema';` included)
- v2 execution continuation with all defenses as Phase 1b–N line items
- ROADMAP entry + memory file
- Typically 5 files, ~1000 lines, 100% additive, no existing code touched

**Queue implementation for next session** via the v2 execution continuation. Each defense becomes a checklist item the next session cannot skip.

**Failure mode prevented**: shipping all defenses + the implementation in one session = high probability the implementation skips 2-3 defenses under time pressure, ships silent failures, and the plan retroactively becomes theatre.

**Precedents**: 2026-05-03 PP.1 (17 defenses, 3-session split — foundation in PR #406), 2026-04-30 CM.35 Wave A foundation + Wave B v2 plan, 2026-04-23 Strategy Grades chip v1→v2. (These precedents pre-date the 2026-05-23 council retirement; they were originally triggered by council MUST-HAVE counts. The pattern survives — only the trigger mechanism changed from council verdict to operator judgement during plan review.)

---

## Invocation Model (Dual-Use)

Same code path serves both. Only output serializer differs.

| Aspect | Human default | Programmatic |
|---|---|---|
| Output | Prose to stderr | JSON lines to stdout (`AUTOVIBE_FORMAT=json`) |
| Cascade | Confident-mode (user "go" authorizes flow) | Same |
| Pre-flight | Always runs | Always runs |
| State | Writes `.claude/autovibe-state.json` | Reads/writes same file |
| Composition | Conversation invokes skills | Same — programmatic just reads json output |

---

## Exit Codes (Stable Contract)

| Code | Meaning | Source |
|---|---|---|
| 0 | Shipped — full flow + post-push doc complete | orchestrate + ship + post-push all 0 |
| 1 | Preflight failed (path/disk/locks/auth) | preflight.sh |
| 2 | Triage halted (no intent / unknown classification) | orchestrate.sh |
| 3 | Composed-step failure (council/execute/code-council) | conversation surfaces |
| 4 | `/ship` returned 1–6 | conversation passes through ship's exit |
| 5 | Lock collision — another autovibe in progress | state.sh |
| 6 | Unhealthy path (iCloud/cloud/tmp) | path-check via preflight |
| 7 | Disk full | preflight.sh |
| 8 | gh auth missing | preflight.sh |
| 9 | Hotfix-refusal — never auto-invoke `/ship hotfix` | orchestrate or conversation |

---

## Lock Contract (`.claude/autovibe-state.json` + `.claude/autovibe-state.lock/`)

**Design**: atomic `mkdir` as lock primitive (mirrors `/ship`'s pattern). The DIRECTORY is the lock; the JSON file carries metadata.

**TTL**: 30 minutes on `started_at` (autovibe runs longer than ship). Future-tolerance: 60 minutes (clock skew bound).

**Trap**: `orchestrate.sh` registers `trap 'state.sh release' INT TERM EXIT`. ^C releases cleanly.

**Schema**:
```json
{
  "session_uuid": "<claude session id>",
  "started_at": "<iso8601 UTC>",
  "phase": "initialized|planning|executing|shipping|complete|failed",
  "current_step": "preflight|triage_<outcome>|forge_needed|plan_in_progress|council_pending|execute_pending|ship_pending|post_push|complete",
  "intent": "<user intent string>",
  "branch": "<git branch>",
  "artifacts": {
    "plan_path": null,
    "council_path": null,
    "pr_number": null,
    "merged_sha": null,
    "rollback_cmd": null
  },
  "completed_at": null,
  "exit_code": null
}
```

---

## Composition Inventory (compose, don't rebuild)

| Asset | Path | Role |
|---|---|---|
| `path-check.sh` | `../ship/scripts/path-check.sh` | iCloud rejection — autovibe DELEGATES to ship's hardened version |
| `prime-lite/brief.sh` | `../prime-lite/scripts/brief.sh` | Context briefing primitive (<2000 tokens, <3s) |
| `triage.sh` | `scripts/triage.sh` | Plan-vs-direct classifier (D2 trigger list) |
| `state.sh` | `scripts/state.sh` | Lock + state management (mirrors ship's lock.sh) |
| `preflight.sh` | `scripts/preflight.sh` | Path/disk/locks/auth gates |
| `/prompt-forge` | command | Input normalization (gated by D4: <20 words OR no verb/object pair) |
| framing-audit primitives | `../reduce-to-first-principles/`, `../check-commensurability/`, `../map-feedback-loops/` | Planned-mode framing audit — goal-audit checkpoint (step 2a only). See §Framing Audit. |
| `/execute` | command | Plan implementation |
| `/code-council` | command | Multi-lens diff review on shipped code (PASS/ADVISORY/BLOCKING). Different beast from the retired strategy council — stays in the loop at step 7. |
| `/ship quick` | skill | Direct-path target |
| `/ship pr` | skill | Planned-path target — full PR + CI + smoke |
| `/ship hotfix` | skill | **NEVER auto-invoked** — exit 9 if conditions detected |
| `dev-prod` | `../dev-prod/` | **Phase 5.5 — staging-first gate** (owns the entity-routing registry + the gate contract). autovibe INVOKES it before `/ship`; never reimplements the gate. See §Phase 5.5. |

---

## Constraints

**NEVER**:
- Auto-invoke `/ship hotfix` (auto-rollback w/o confirmation; human-only)
- Reimplement `/ship` logic (compose-don't-rebuild guard checked by Phase 5 evals)
- Modify `.claude/ship-state.json` (that's `/ship`'s file; autovibe only reads it)
- Skip `/ship`'s own preflight on the grounds that "autovibe already checked" — state files are independent
- Bypass D2 mandatory-plan triggers via "I'll just do this one quick thing"

**ALWAYS**:
- `preflight.sh` before any state mutation
- `state.sh acquire` with intent string before composing
- Trap-release the lock on INT/TERM/EXIT
- Pass through `/ship`'s exit code unchanged when ship halts
- Run post-push doc step after successful ship
- When composing `/code-council` or `/code-forge`: verify the orchestrator has Read `.claude/rules/code-review-identity.md` per each command's Pre-flight block. If absent (e.g., command body modified without preserving the Pre-flight, or a degraded subprocess context), HALT before subagent dispatch and re-Read. The identity preamble + Self-Check Razors are non-skippable on every review pass. Composes with the BASELINE routing-table row + `hookify.code-review-identity-load.local.md` Agent-tool hook.
- Use `AUTOVIBE_DRYRUN=1` for any new test scenario before live invocation
- Run the planned-mode goal audit before drafting a plan — checkpoint at `modes/planned.md` step 2a audits the GOAL. Per `.claude/rules/framing-audit-mandate.md`; skipping it on load-bearing work is a contract violation. Plan-side framing review is now an operator self-check during ExitPlanMode (step 5) rather than a council-driven Reframer pass.

---

## Phase 5.5 — Staging-First Gate (before `/ship`)

Between the post-`/code-council` step and `/ship`, an autonomous run passes the **staging-first
gate** — so an autonomous agent does not reach production directly: the default ship target is
staging, and production-direct is friction-positive (an explicit flag + a verified, externally-
attributed log). **Requires the `dev-prod` skill** (which owns the routing registry + the gate
contract) — do not reimplement the gate here; invoke `dev-prod`. Wiring:
`.claude/skills/dev-prod/references/autovibe-gate-wiring.md`; registry:
`.claude/skills/dev-prod/references/entity-routing.md`.

The contract, in brief:

1. **Resolve entity** from `profile_slug` / branch. Unresolved/ambiguous → **fail-closed**: halt,
   write a continuation, never default to an entity.
2. **Read the `STATUS:` token** (not prose) in the routing registry. Anything but exactly `wired`
   (or a missing staging ref) → HALT. Never `/ship` to a stub.
3. **Default ship target = staging.** `/ship` targets staging unless the override is satisfied.
4. **Pre-promotion checklist** (dev-prod SKILL.md) must pass — incl. the hardcoded-prod-ref grep
   and the staging-healthy precondition (a timeout is NOT a pass).
5. **Production-direct override** requires BOTH: (a) `AUTOVIBE_PROD_DIRECT` affirmatively truthy
   (`1/true/yes/enabled`; absent or `0/false/no/off/disabled` = staging-first), AND (b) an
   externally-attributed, write-then-read-back-verified override record (a failed/timed-out write
   halts the run — never "shipped anyway").

**Until you wire a staging environment** (fill `entity-routing.md`), the `STATUS:` token reads
`stub` and steps 1–4 HALT — so on a fresh template Phase 5.5 is a no-op gate that records the stub
state. A project with a single environment can leave it stubbed and ship as today.

**Coupling:** Phase 5.5 depends on the `dev-prod` skill — keep the two in sync; never one without
the other.

---

## Post-Push Documentation Step (Phase 4 — pending)

After `/ship` exits 0, the conversation:

1. Reads `.claude/ship-state.json` for `commit_sha`, `pr_number`, `completed_at`
2. Computes `elapsed_time = completed_at - autovibe_state.started_at`
3. Appends one-line entry to `.claude/autovibe-sessions/<ts>.md`
4. **Memory write decision** (per CLAUDE.md memory guidance — only save what's surprising):
   - SKIP memory write on: clean ship, no rollback, no admin-merge, single-file change
   - WRITE `memory/feedback_autovibe_<ts>-<slug>.md` on: any non-zero ship exit, smoke rollback, novel code-council pattern, admin-merge bypass
5. **ROADMAP closure**: if commit msg matches a ROADMAP item ID regex (e.g., `INFRA\.1`, `A2`, `CM\.10`), append closure marker to ROADMAP-ARCHIVE

---

## Post-Ship Fleet Audit (Phase 4.5 — added 2026-05-07, v1.1)

After Phase 4 doc step, BEFORE Session Learning Gate:

1. Try cached fleet state first: `bash .claude/skills/verify-shipped/scripts/read-state.sh --max-age 300` (5-minute freshness window — covers SessionStart hook's recent fleet read while staying tight enough to detect drift from a just-completed ship). Bumped from 60s on 2026-05-08 per token-burn audit (Hotspot #5) — eliminates double-audit when SessionStart fired <5min ago.
2. If exit 1 (missing/stale): invoke `Skill verify-shipped quick` (Layers 1+2+3+6 only — Layer 5 was just affected by this session's deploys; give 30s buffer before next audit)
3. Parse the result `exit_code`:
   - `0` (clean): log `fleet clean post-ship` to the session file; continue to Phase 5
   - `1` (drift): append the punch-list to the session file; surface to user with prefix `🚧 shipped, but here's what else is loose:`; continue to Phase 5 (do NOT halt)
   - `2` (layer error): log `fleet audit errored — continuing without fleet status`; continue to Phase 5 (graceful degradation)
   - **Any non-parseable result** (Skill tool itself failed, MCP unavailable, network failure, JSON malformed): treat as `2` — log `[INFO] fleet audit unavailable — continuing without fleet status` and continue to Phase 5. The post-ship flow MUST NOT block on `/verify-shipped` failure under any circumstance. (Per code-council 2026-05-07 IMPORTANT #2 — never-block guarantee.)
4. **Composes with Phase 5**: drift detection adds the `fleet drift detected post-ship` row to the Session Learning Gate triggers below.

**Wall-clock budget**: target <20s on Justin's 50-worktree fleet. The hook MUST NOT block the post-ship flow significantly — graceful degradation is mandatory.

**Failure mode prevented (Cedar Hurst doctrine)**: ships PR #N with code that depends on PR #N-K's edge function being deployed; PR #N-K's deploy was forgotten. Without this hook, partner-facing flow breaks silently. Layer 5 of `/verify-shipped` catches the drift; Phase 4.5 surfaces it the moment Justin is most likely to act.

**State-file dependency**: see `verify-shipped/references/integration.md` for the schema + suppress-file format + lock contract.

---

## Phase 4.7 — Conversation-Level Rich Master Continuation (added 2026-05-08, Spec 25 Pillar C′)

**Architecture note**: this phase fires at CONVERSATION level (Claude self-invokes), NOT from `post-ship.sh`. This sidesteps the Skill-from-bash architectural concern — `post-ship.sh` cannot invoke a Skill (Skill tool requires conversation context), but Claude in conversation can. Phase 4.7 is therefore an instruction in this SKILL.md, executed by the model after Phase 4.5 returns, BEFORE the Session Learning Gate.

### When to fire

After Phase 4.5 fleet audit completes AND the following conditions hold:
1. `ship_signal == "clean"` (read from autovibe-state.json or post-ship.sh exit)
2. Phase 4.5 returned `exit_code == 0` OR `exit_code == 1` (drift surfaced — captured in continuation as "Current State"; do NOT skip Phase 4.7 on drift)
3. Work scope was multi-phase or multi-session-likely (heuristic: plan mode used during this autovibe run, OR /code-council ran, OR ROADMAP item ID matched in commit msg)
4. `continuations/AUTOVIBE-{ts}-{slug}-MASTER.md` does NOT yet exist (idempotency check; `{ts}` from autovibe-state.json `started_at`, `{slug}` from intent slugified)

If any condition fails: skip Phase 4.7, log skip reason to `.claude/phase47-log.jsonl`, continue to Session Learning Gate.

### How to fire (conversation-level instruction to Claude)

1. Read `autovibe-state.json` to extract `started_at` (canonical timestamp) and `intent` (canonical slug source).
2. Compute the canonical filename: `AUTOVIBE-{YYYY-MM-DD-HHMM}-{slug}-MASTER.md` where `{YYYY-MM-DD-HHMM}` derives from `started_at` ISO 8601 (mirrors `post-handoff-writer.sh` `ts_to_filename`) and `{slug}` mirrors `post-handoff-writer.sh` `slugify`.
3. Invoke `Skill master-continuation-prompt` with parameters:
   - `work_scope`: the autovibe `intent` field (one-liner)
   - `continuation_type`: `master`
   - `output_dir`: `continuations/`
   - `include_research_agents`: true
4. The skill produces a file at its own naming convention (`{SCOPE}-MASTER-CONTINUATION-{YYYY-MM-DD}.md`) — capture the output path emitted by the skill.
5. **Rename to canonical**: `mv` the skill's output to `continuations/AUTOVIBE-{ts}-{slug}-MASTER.md` (the canonical name `post-handoff-writer.sh` and SessionStart hook expect). This step solves the EC-1 filename schema mismatch identified in council session 2026-05-08.
6. Verify file exists + non-zero size.
7. Append one JSON line to `.claude/phase47-log.jsonl`:
   ```json
   {"ts":"<iso8601>","slug":"<slug>","status":"written|skipped|error","file_path":"<canonical-path>","duration_seconds":<n>,"skip_reason":"<reason if skipped>"}
   ```
   This is the NS-1 persistent counter mitigation per Reliability Engineer flag.
8. Emit heartbeat to chat: `Master continuation written to: continuations/AUTOVIBE-{ts}-{slug}-MASTER.md` OR `Master continuation skipped: <reason>`.

### Timeout guard (NS-3 mitigation)

If the Skill invocation exceeds 20 minutes wall-clock (rare — most invocations are 30-90s), abort with heartbeat: `Master continuation TIMEOUT — DRAFT fallback will fire`. Append timeout entry to phase47-log.jsonl. The DRAFT skeleton mechanism (post-handoff-writer.sh, fired from post-ship.sh) handles fallback automatically because the canonical MASTER file does NOT exist — its existence check returns false, DRAFT is written.

### Composition with post-handoff-writer.sh

post-handoff-writer.sh runs at SHELL level FROM post-ship.sh. Its idempotency check reads the canonical MASTER filename:
- If MASTER exists → SKIP DRAFT skeleton write (rich version supersedes)
- If MASTER absent (Phase 4.7 didn't fire OR failed OR timed out) → write DRAFT skeleton as graceful fallback

This means: Phase 4.7 (conversation-level) MUST run BEFORE post-ship.sh calls post-handoff-writer.sh OR Claude must trigger the post-handoff-writer.sh check AFTER Phase 4.7 completes. Current ordering in post-ship.sh: Phase 4 doc → memory write → ROADMAP closure → state mutate → post-handoff-writer.sh (LAST). If Phase 4.7 fires from CONVERSATION between Phase 4.5 and Session Learning Gate, the conversation step happens BEFORE post-ship.sh's tail block runs (because post-ship.sh runs at the START of Phase 4, not after Phase 4.7). EC-4 ordering inversion: addressable by moving the post-handoff-writer.sh invocation to AFTER Phase 4.7 completes (i.e., from a separate conversation-level step in autovibe SKILL.md, not from post-ship.sh tail).

**Safer pattern (recommended)**: Phase 4.7 invokes the skill, renames file, then conversation invokes post-handoff-writer.sh at the very end. Today's ship: post-handoff-writer.sh continues to fire from post-ship.sh tail (existing); Phase 4.7's MASTER file is written at conversation level BEFORE post-ship.sh runs (because post-ship.sh runs from /ship, which fires after autovibe Phase 4.7 in the conversation order). The MASTER existence check in post-handoff-writer.sh therefore sees the canonical MASTER file and skips DRAFT.

### Failure modes (graceful degradation)

| Mode | Behaviour |
|---|---|
| Skill not registered | Phase 4.7 logs skip, post-handoff-writer.sh writes DRAFT as normal |
| Skill returns error | Phase 4.7 logs error, post-handoff-writer.sh writes DRAFT as fallback |
| Renamed file collides with existing MASTER (idempotency-skip-but-no-file edge) | Use atomic write: rename to `.tmp` first, verify size, then mv to `.md` |
| Conversation context exhausted mid-skill | Skill output truncated; Phase 4.7 detects on size check; writes timeout-class entry to phase47-log.jsonl; falls back to DRAFT |
| Multi-worktree filename collision | Different `started_at` produces different filenames; cross-worktree is naturally namespaced |

---

## Phase 4.6 — Context-Budget Gate (added 2026-05-08, Spec 25 Piece 1)

**Purpose**: trigger session handoff to a fresh chat when context-window usage hits 40%, INDEPENDENT of task completion. Solves the "Claude burns through 1M tokens mid-work" failure mode.

**Trigger**: fires at every Phase boundary in autovibe (after Phase 0 triage, after Phase 1 plan, after Phase 2 council, after Phase 3 amend, after Phase 4 execute, after Phase 4.5 fleet audit, before Phase 4.7).

### Self-assessment heuristics (Claude estimates own context usage)

Claude does NOT see exact token counts. Use these signals:

1. **Tool-result accumulation**: estimate ~500-2000 tokens per file Read, ~3000-10000 tokens per spawned Agent return, ~200-500 tokens per Bash result. Sum since session start.
2. **Conversation turn count**: each user-assistant pair ≈ 500-2000 tokens average. Multiply by turns.
3. **Spawned-agent outputs**: /agent-research deep run = ~50-80K tokens of agent outputs alone. (Strategy council is no longer in the autofire loop as of 2026-05-23, so the prior "7-agent council = ~50-80K" budget item no longer applies to autovibe; if the operator invokes `/council` manually mid-session, treat the same.)
4. **Compaction warning from harness**: if the harness has emitted ANY auto-compact warning during this session, treat as `>= 50% used`.
5. **Operator override**: if Justin explicitly said "context is getting full" or "let's hand off" — treat as immediate trigger.

### Decision matrix

| Estimated context usage | Work-remaining? | Action |
|---|---|---|
| `< 25%` | any | Continue — no gate fires |
| `25-40%` | yes (multi-phase) | Warn at next phase boundary: "Estimated context usage ≈ 30%. If this work spans 2+ more phases, consider handoff at next clean boundary." Continue. |
| `25-40%` | no (single-phase remaining) | Continue — finish this phase, gate re-fires after next phase if context grew |
| `>= 40%` | yes (any work-remaining) | **FIRE HANDOFF** — invoke Phase 4.7 protocol immediately even if not at autovibe Phase 4 yet. Two modes: (a) **continuation mode** if mid-execution: write what's done + what's next; (b) **restart mode** if pre-execution: write the plan as if it's about to execute |
| `>= 40%` | no (work complete or near-complete) | Continue — finish, ship normally, fire Phase 4.7 at end |
| `>= 60%` | any | **HARD STOP** — handoff immediately regardless of phase. Risk of mid-write context exhaustion exceeds the cost of an early handoff. |

### Handoff protocol (when 40% gate fires mid-flow)

1. Pause current phase work
2. Write a "context-budget-handoff" continuation file at `continuations/AUTOVIBE-{ts}-{slug}-CONTEXT-HANDOFF-MASTER.md` (variant of the Phase 4.7 canonical filename)
3. Use Skill master-continuation-prompt with `continuation_type=master` and the work_scope set to "{original-intent} — context-budget handoff at phase {N}, work-state {continuation|restart}"
4. The continuation MUST include: original autovibe intent, phase reached, work completed so far (verifiable artefacts: commits, PRs, files), what's next, fresh-chat instructions
5. Emit chat heartbeat: `🚦 Context budget gate fired (40% threshold). Handoff written: {path}. Paste into fresh chat to continue.`
6. Append to phase47-log.jsonl with status="context-handoff" and original phase
7. Exit autovibe gracefully — DO NOT continue executing in this session past the handoff write

### Two handoff modes — when to use which

**Continuation mode** (mid-work):
- Trigger: 40% threshold hits during Phase 4 execute, OR during a long /code-council iteration loop
- Continuation describes: "I was X-ing; I completed A+B; remaining is C+D; the fresh chat should pick up from here"
- Fresh chat reads continuation, runs `/verify-shipped` to confirm A+B actually shipped, then resumes from C+D

**Restart mode** (pre-execution or near-pre):
- Trigger: 40% threshold hits during Phase 1 plan or Phase 2 council (rare — these phases shouldn't burn 40% on their own; usually means the operator asked for big planning that already filled context)
- Continuation describes: "I would have done X. The fresh chat should do this fresh — but with my plan as starting context"
- Fresh chat reads continuation, executes from scratch with full context budget

### Counter-flag: when NOT to fire even at 40%

- Single-phase work remaining AND <5min estimated wall-clock to complete (cost of handoff > cost of finishing)
- Operator has explicitly said "push through" or "ignore budget" in current turn
- Phase 4.7 is mid-execution (don't double-handoff during a handoff write)

### Composition with Phase 4.7

If the 40% gate fires AT or NEAR Phase 4.7's natural firing time, they collapse into one event: write the canonical MASTER file with `continuation_type=master` (no special "context-handoff" variant). The MASTER file IS the handoff.

If the 40% gate fires MUCH earlier (Phase 1 or Phase 4 mid-execute), write the special CONTEXT-HANDOFF-MASTER variant. Subsequent fresh chat resumes via /autovibe with the handoff file as input — autovibe re-classifies via triage and continues.

---

## Phase 4.8 — Autofire Continuation via NewVibe SSH dispatch (added 2026-05-08, Pillar D')

> **OPT-IN — the dispatch transport is environment-specific.** Phase 4.8 closes the
> manual-paste gap: after Phase 4.7 writes a canonical MASTER continuation, Phase 4.8
> dispatches a fresh Claude session (~5 minutes out) that resumes from that file — so
> multi-session features fire themselves with no manual chat-open + paste. The **gates**
> below ship with this skill; the **transport** that actually spawns the next session is
> the **NewVibe SSH dispatch** (an automation workflow → a secure SSH tunnel → a new Claude
> session on your machine). Until you wire that transport, autofire is a silent no-op and
> the next session is a normal manual paste — Phase 4.7's MASTER file still exists, so
> nothing is lost. Wiring runbook (with `[ORG-SPECIFIC]` markers):
> `.claude/skills/autovibe/references/newvibe-integration-guide.md`.

**Architecture** (Builder / Verifier / Firer):
- **Builder** = Phase 4.7 (writes canonical MASTER) — already shipped
- **Verifier** = `scripts/verify-continuation.sh` — structural lint gate
- **Firer** = `scripts/newvibe-dispatch-lib.sh` (SSH dispatch), gated by the verifier exit code
  + the `scripts/newvibe-chain-guard.sh` depth guard (chain depth ≤ 5)

### When to fire — ALL conditions must hold

1. Phase 4.7 succeeded (latest `.claude/phase47-log.jsonl` entry has `status:"written"`)
2. `ship_signal == "clean"` (NOT `rollback`, `admin_merge`, `smoke_unverifiable`, or any non-zero ship exit)
3. Mode != hotfix (autovibe never auto-invokes hotfix; this is belt-and-suspenders)
4. Verifier PASSes: `bash .claude/skills/autovibe/scripts/verify-continuation.sh <canonical-path>` exits 0
5. Kill-switch off: `AUTOVIBE_AUTOFIRE` env var is unset OR != "0" (default = enabled)
6. Original autovibe intent contains no destructive keywords — verifier scans the FILE; conversation should additionally scan the INTENT for: `delete`, `drop`, `destroy`, `rm -rf`, `force.push`, `--no-verify`, `truncate`

If ANY condition fails: skip Phase 4.8, append `.claude/phase47-log.jsonl` entry with `status:"autofire-skipped"` + `skip_reason:"<which-gate>"`, emit heartbeat, continue to Session Learning Gate.

### How to fire (conversation-level instructions to Claude)

1. **Kill-switch check**: read `AUTOVIBE_AUTOFIRE` env. The kill-switch accepts ANY of `0`, `false`, `no`, `off`, `disabled` (case-insensitive) as DISABLE — anything else (unset, empty, `1`, `true`, `yes`, etc.) means ENABLED. If disabled, skip with `skip_reason:"kill-switch"` AND emit a loud chat heartbeat: `⏸️ Phase 4.8 autofire SKIPPED — kill-switch active (AUTOVIBE_AUTOFIRE=<value>). Manual paste required. To re-enable: 'unset AUTOVIBE_AUTOFIRE'`. (Per code-council 2026-05-08 finding 5+8 — symmetric truthy-variant accept + visible-disable signal.)
2. **Recompute canonical path** the same way Phase 4.7 did (from `autovibe-state.json` `started_at` + slugified `intent`).
3. **Run verifier with direct-redirect rc capture** (per `.claude/rules/shell-portability.md` rule 1 + `code-council-static-analysis.md` rule 3 — pipes eat $? and `tail` would mask the verifier's exit):
   ```bash
   bash .claude/skills/autovibe/scripts/verify-continuation.sh "$CANONICAL_PATH" > /tmp/verify-cont.log 2>&1
   VERIFIER_RC=$?
   cat /tmp/verify-cont.log    # surfacing the [PASS]/[FAIL] line is fine — but AFTER capturing rc
   ```
   **NEVER** use `bash verify... 2>&1 | tail -N; rc=$?` — that captures `tail`'s rc=0, masking verifier failures. This pattern reproduces the 2026-05-06 typecheck-incident class. If `VERIFIER_RC -ne 0`, skip with `skip_reason:"verifier-exit-<N>"` and emit chat heartbeat.
4. **Intent destructive-keyword scan** (extra layer beyond verifier's file scan):
   ```bash
   echo "$INTENT" | grep -qiE '(delete|drop table|destroy|rm -rf|force.push|--no-verify|truncate)' && skip
   ```
5. **Chain-depth guard**: `bash .claude/skills/autovibe/scripts/newvibe-chain-guard.sh` — if the autofire chain is already ≥ 5 deep, skip with `skip_reason:"chain-depth"` (prevents a runaway self-firing loop).
6. **Dispatch via NewVibe SSH** (`scripts/newvibe-dispatch-lib.sh`, wired per `references/newvibe-integration-guide.md`). The transport is: your automation workflow receives a trigger → opens the secure SSH tunnel to your machine → launches a fresh Claude session whose first message is the hyper-micro-prompt from the canonical MASTER's tail section + the canonical file path link. **If no transport is wired** (the `[ORG-SPECIFIC]` markers in the integration guide are unfilled), skip with `skip_reason:"transport-unwired"` and emit the manual-paste heartbeat — nothing is lost.
7. **Capture the dispatch identifier** returned by the SSH dispatch (the workflow/run id).
8. **Append `.claude/phase47-log.jsonl`**:
   ```json
   {"ts":"<iso8601>","slug":"<slug>","status":"autofire-dispatched","dispatch_id":"<id>","canonical_path":"<path>"}
   ```
9. **Emit heartbeat to chat**:
   `🚀 Autofire dispatched: <id> — a fresh chat will SSH in and resume from <canonical-path> with no manual paste.`

### Kill switches (Reliability Engineer veto layer — defense in depth)

Every gate fails closed. Multiple independent layers:

| Gate | Mechanism | Effect when triggered |
|---|---|---|
| Env kill-switch | `AUTOVIBE_AUTOFIRE=0` in shell env | Phase 4.8 skips immediately, logs `kill-switch` |
| Verifier exit non-zero | `verify-continuation.sh` returns 1-6 | Phase 4.8 skips, logs `verifier-exit-<N>` |
| Destructive keyword in intent | `grep -iE` against intent string | Phase 4.8 skips, logs `destructive-intent` |
| Destructive keyword in file body | Verifier's own check (exit 6) | Phase 4.8 skips, logs `verifier-exit-6` |
| Non-clean ship_signal | post-ship.sh writes signal; conversation reads | Phase 4.8 skips, logs `ship-signal-<X>` |
| Hotfix mode | Triage outcome was hotfix | Phase 4.8 skips, logs `hotfix-mode` |

The user can disable Phase 4.8 instantly via:
```bash
export AUTOVIBE_AUTOFIRE=0      # this shell only
echo 'export AUTOVIBE_AUTOFIRE=0' >> ~/.zshrc   # persistent
```

### Failure modes (graceful degradation)

| Mode | Behaviour |
|---|---|
| NewVibe SSH transport not wired | Phase 4.8 logs `transport-unwired`, no autofire — next chat = manual paste (Phase 4.7's MASTER still exists) |
| SSH dispatch returns error or times out | Phase 4.8 logs `dispatch-error`, no autofire — manual fallback |
| Verifier finds destructive keyword in continuation body | Refuses; logs `verifier-exit-6-destructive` |
| Slug collision (same slug as existing MASTER) | Verifier exit 5; logs `verifier-exit-5-slug-collision` |
| Filename pattern mismatch | Verifier exit 3; logs `verifier-exit-3-filename` (file doesn't match `AUTOVIBE-{ts}-{slug}-MASTER.md`) |
| Fewer than 12 sections | Verifier exit 4; logs `verifier-exit-4-structure` (12-section template not satisfied) |
| File missing at canonical path | Verifier exit 1; logs `verifier-exit-1-missing` (Phase 4.7 must have failed earlier) |
| File < 500 bytes | Verifier exit 2; logs `verifier-exit-2-undersized` (truncated continuation) |
| `phase47-log.jsonl` write fails | Heartbeat still emitted; autofire still scheduled (logging is opportunistic — see V1.1 follow-up below) |

**V1.1 follow-up backlog** (per code-council 2026-05-08 — non-blocking):
- TOCTOU: capture `sha256sum` of canonical file at verify-time; embed in scheduled prompt; fresh chat re-verifies hash before acting (closes the 5-min window between verify-pass and fire-time)
- Log-write failure should fail-closed (no autofire) instead of opportunistic — required for decommission-trigger #1 measurability
- Self-test boundary cases: empty file (size=0), exactly-500-byte file, exactly-12-section file, glob-substring slug variants
- Exit code 1 split: usage error → exit 7 (currently overloaded with FAIL_MISSING)

### Decommission triggers

**Graduation trigger**:

0. **≥3 consecutive successful end-to-end runs**: autovibe → write continuation → autofire fresh chat → fresh chat resumes work cleanly with NO human paste needed = Phase 4.8 is proven for your setup. Treat autofire as shipped-permanently rather than experimental.

**Failure / upgrade triggers (any one fires)**:

1. **Junk-continuation rate > 20%**: 3+ consecutive autofire chains produce continuations the fresh chat couldn't act on (semantic junk slipped past structural verifier). Upgrade verifier to a `claude --print` subprocess (similar to `code-forge`).
2. **User permanently disables**: `AUTOVIBE_AUTOFIRE=0` (or any disable variant) in shell rc for >7 days = signal to remove or rework.
3. **Transport changes**: if your SSH/automation transport changes (new tunnel, new workflow host), re-wire per `references/newvibe-integration-guide.md` — the gates are transport-agnostic, only the firer moves.

### Verification gates (run after first 3 autofire chains)

The decommission trigger #1 requires measuring junk rate. After ≥3 autofire chains:

```bash
# Count autofire-dispatched entries in past 7 days
jq -c 'select(.status == "autofire-dispatched")' .claude/phase47-log.jsonl | wc -l
# Manually inspect each dispatched fresh chat's first message for "couldn't act" signals
```

If 0/3 OR 1/3 fresh chats reported confusion, V1 verifier is sufficient. If 2/3+, escalate to Claude-subprocess verifier.

---

## Session Learning Gate (2026-04-23)

After post-push doc, the conversation evaluates whether the session produced cross-session learnings worth capturing. Auto-invoke `/reflect` only when worthwhile — NEVER unconditionally (token bloat on trivial sessions).

### Gate — invoke `/reflect` IF any of these are true:

- Exited plan mode (ExitPlanMode fired at least once)
- User correction received — signal phrases: "no, do X instead", "make sure no regression", "wrong approach", "stop doing Y", or rejected an ExitPlanMode
- Shipped ≥2 PRs during the session (indicates non-trivial work)
- `/code-council` returned BLOCKING or ADVISORY verdict (not PASS) — that's the DIFF reviewer at step 7, unaffected by the 2026-05-23 strategy-council retirement
- Any composed-skill step returned a non-zero exit code that was recovered from mid-session
- Operator manually invoked `/council` mid-session (rare since the autofire retirement; if it happened, the deliberation produced a learning worth capturing)
- **Phase 4.5 fleet audit detected post-ship drift** (added 2026-05-07, v1.1) — the drift IS the cross-session learning. `/reflect` may surface a hookify rule, doctrine entry, or memory note that prevents recurrence (e.g., "always run X check before Y").

### Gate behavior

| Gate triggers | Autovibe final step |
|---|---|
| YES (≥1 criterion above) | `Skill reflect` — user still approves at Step 5; Step 7 auto-propagates universal learnings to template |
| NO | Skip silently. Exit with post-push doc complete. |

**Rationale**: typo-fix and one-file-edit sessions produce zero learnings. Running `/reflect` there burns tokens on a scan that returns empty. Gate-ed reflection preserves cross-project learning compounding without the per-session tax.

**Approval gate preserved**: even when autovibe invokes `/reflect` automatically, the Step 5 approval UI still fires. User sees the proposed changes and applies with `y all`, `y 8+ both`, `y changes only`, `edit`, or `n`. No surprise writes.

**Template propagation**: via `/reflect`'s Step 7 (added 2026-04-23, PR #243). Universal learnings flow to template repo automatically after user approves the batch. Cross-project learning is now a property of the orchestration layer, not manual user discipline.

---

## Pre-orchestration Fetch (added 2026-04-23)

`preflight.sh` Gate 5 runs `git fetch origin main --prune --quiet` before any composition. Single fetch, no merge. Keeps origin/main ref fresh for in-session comparisons (e.g., branch divergence checks, rebase target detection, admin-merge heuristics).

- **NOT a pull/merge** — merging upstream mid-session could conflict with in-progress work. Separate from `/daily-plan`'s daily sync cadence.
- **Non-blocking** — network/auth failures emit one warning line and continue. Autovibe flows that don't need fresh refs (typo fix, local-only work) proceed unaffected.
- **Token cost**: zero. Pure shell operation, no LLM involvement.

---

## Hookify Disposition

`auto-council-on-plan.local.md` hookify rule (in template repo, not installed here): **left uninstalled** AND no longer relevant — strategy council was retired from the autovibe autofire loop on 2026-05-23 because the 8-agent deliberation reliably produced rabbit-hole detours and work never actually finished. The forged prompt + master-continuation-prompt already carry the structured framing council was supposed to add. `/code-council` at step 7 (diff reviewer) is unaffected — different beast, stays in the loop. `/council` itself survives as a MANUAL operator skill outside autovibe for strategic deliberations that genuinely need multi-perspective lensing.

If a future operator wants the hook back, install the hookify rule, restore the council + amend steps to `modes/planned.md`, and update `references/decisions-locked.md`. But assess the council-free loop on real work first before tweaking back.

---

## Rollback (if /autovibe itself misbehaves)

1. `rm -rf .claude/skills/autovibe/` — skill unregistered, all composed skills still work standalone
2. `rm -rf .claude/autovibe-state.lock/ .claude/autovibe-state.json` — clears stale lock (also auto-clears on 30-min TTL)
3. `rm -rf .claude/skills/prime-lite/` — only if you also want prime-lite gone (it's standalone-useful)
4. Sign-off file at `specs/autovibe-design-decisions-2026-04-19.md` — left in place for audit

Zero blast radius outside `.claude/skills/autovibe/`, `.claude/skills/prime-lite/`, and the state lock files.

---

## References

- **Plan**: `/Users/justin/.claude/plans/elegant-zooming-sparrow.md`
- **Continuation source**: `continuations/AUTOVIBE-SKILL-DESIGN-MASTER-CONTINUATION-2026-04-19.md`
- **Decisions locked**: `references/decisions-locked.md`
- **Invocation contract**: `references/invocation-contract.md`
- **NewVibe integration guide**: `references/newvibe-integration-guide.md` — per-repo wiring for autofire (the two hooks, slug detection, the n8n substrate, the safety model). Read this to wire NewVibe autofire into a repo derived from this template.
- **Ship contract**: `../ship/SKILL.md`
- **Council protocol (manual `/council` only — not autofire)**: `../../rules/council-protocol.md`
- **Council-retired-from-autofire memory entry**: stored in the project's auto memory under `feedback_council_removed_from_autovibe_2026_05_23.md` — read for the assess-first-before-tweaking doctrine + original file change list
- **Memory guidance**: `CLAUDE.md` §Auto memory
