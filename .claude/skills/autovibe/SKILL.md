---
name: autovibe
description: |
  Top-of-stack autonomous shipping orchestrator. One invocation handles the
  full plan→council→amend→execute→code-council→ship loop, or routes trivial
  work directly to /ship quick. Composes /ship, /council --extended,
  /amend-plan, /execute, /code-council, /prompt-forge, prime-lite. Never
  reimplements composed-skill logic; reads/writes its own state file
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

## Kernel Registration (OPTIONAL — only with a kernel substrate)

> **OPTIONAL.** This section applies **only if your project has a kernel-style observability
> substrate**: an `agent_sessions` table plus the `autovibe_register()` / `autovibe_transition()`
> RPCs (and, for outcome recording, a `session_outcomes` table + `record_session_outcome()`).
> **If that substrate is not present, skip kernel registration entirely** — autovibe runs
> without it. Do **not** treat a missing RPC as a halt condition when the substrate was never
> installed. The rest of this section assumes the substrate exists.

When the substrate is present, every autovibe run writes a complete lifecycle record so the
run is observable (speed, operator-attention cost, self-recording, throughput, handoff UX
become measurable rather than paper-only).

**Helper**: `bash .claude/skills/autovibe/scripts/autovibe-transition.sh <mode> <args>` emits
ready-to-run SQL (single-quote-escaped, status-enum-validated) prefixed with `[KERNEL-CALL]`.
Pipe its stdout into `mcp__supabase-{{project}}__execute_sql` to land the row.

**Wiring contract** — Claude calls these from the conversation layer (not from
`orchestrate.sh`). The shell subprocess has no MCP access; the conversation has both MCP
access and the lifecycle awareness needed to populate phase metadata correctly.

| Phase boundary | Action | Target status |
|---|---|---|
| **Session start** (before `orchestrate.sh` fires) | Call `autovibe_register($CLAUDE_SESSION_ID, intent, branch, profile_slug)`. Capture `run_id`. Persist it. | `registered` |
| **After triage** | `autovibe_transition(run_id, 'phase0', 'triage_complete', 'queued', {triage_outcome, mode})` | `queued` |
| **Plan start** | `autovibe_transition(run_id, 'phase1', 'plan_start', 'running', {plan_path?})` | `running` |
| **Post-council** | `autovibe_transition(run_id, 'phase2', 'council_complete', 'running', {council_path, council_verdict})` | `running` (heartbeat) |
| **Post-amend-plan** | `autovibe_transition(run_id, 'phase3', 'amend_complete', 'running', {amendments_applied})` | `running` (heartbeat) |
| **Post-execute** | `autovibe_transition(run_id, 'phase4', 'execute_complete', 'running', {files_touched_count})` | `running` (heartbeat) |
| **Post-fleet-audit** (Phase 4.5) | `autovibe_transition(run_id, 'phase4_5', 'fleet_audit_complete', 'running', {fleet_drift_count})` | `running` (heartbeat) |
| **Post-master-continuation** (Phase 4.7) | `autovibe_transition(run_id, 'phase4_7', 'continuation_written', 'running', {continuation_path})` | `running` (heartbeat) |
| **Post-code-council** | `autovibe_transition(run_id, 'phase5', 'code_council_complete', 'running', {code_council_path, code_council_verdict})` | `running` (heartbeat) |
| **Staging-first gate entered** (Phase 5.5) | `autovibe_transition(run_id, 'phase5_5', 'staging_gate_entered', 'running', {entity, ship_target})` | `running` (heartbeat) |
| **Gate pass — staging** | `autovibe_transition(run_id, 'phase5_5', 'staging_gate_pass', 'running', {ship_target:'staging'})` | `running` |
| **Prod-direct override** (truthy `AUTOVIBE_PROD_DIRECT`, write-then-verified) | `autovibe_transition(run_id, 'phase5_5', 'prod_direct_override', 'running', {reason, who})`, then SELECT the row back by `run_id` to confirm it landed BEFORE `/ship`. Follows register HALT discipline. | `running` |
| **Gate halt** (stub / unresolved entity / checklist fail / no flag) | `autovibe_transition(run_id, 'phase5_5', 'staging_gate_halt', 'failed', {reason, continuation_path})`. Write a continuation; do NOT `/ship` to production. `failed` (not `waiting`) so the orphan watchdog does not race the operator. | `failed` |
| **Ship complete** | `autovibe_transition(run_id, 'phase6', 'ship_complete', 'completed', {exit_code, pr_number, merged_sha, ship_signal})` | `completed` |
| **Ship failed** | `autovibe_transition(run_id, 'phase6', 'ship_failed', 'failed', {exit_code, error})` | `failed` |
| **User cancellation** | `autovibe_transition(run_id, 'phase6', 'user_cancel', 'cancelled', {reason})` | `cancelled` |
| **Context-budget gate fires** (Phase 4.6) | `autovibe_transition(run_id, 'phase4_6', 'budget_handoff', 'waiting', {context_budget_pct, continuation_path})` | `waiting` |

**Permitted transitions** (enforced by `autovibe_transition()` — illegal moves raise `check_violation`):
- `registered` → `{queued, running, failed, cancelled}`
- `queued` → `{running, failed, cancelled}`
- `running` → `{running, waiting, completed, failed, cancelled}`
- `waiting` → `{running, failed, cancelled}`
- Terminal states (`completed`, `failed`, `cancelled`) are immutable.

**Capture pattern** (in conversation, after calling the helper):

```
# Step 1 — emit the SQL
bash .claude/skills/autovibe/scripts/autovibe-transition.sh register "$session_uuid" "build foo feature" "main"
# stdout: [KERNEL-CALL] SELECT autovibe_register('...','build foo feature','main',NULL,NULL) AS run_id;

# Step 2 — Claude reads the emitted SQL and runs it:
mcp__supabase-{{project}}__execute_sql({ query: "<that SQL>" })
# returns: [{ "run_id": "<uuid>" }]

# Step 3 — MANDATORY: persist run_id to the durable state file before any other action.
# .claude/autovibe-state.json IS the canonical store; conversation memory is NOT (a
# context-budget handoff or session compact would lose it).
bash .claude/skills/autovibe/scripts/state.sh write agent_session_kernel_id <uuid>
```

**HALT discipline on register failure** — if `execute_sql` returns no row OR errors (network
drop, MCP timeout, auth rejection) *while the substrate exists*, Claude MUST halt the run with
exit-code-1 (preflight class). Do NOT proceed past register without `run_id`. (This does NOT
apply when the substrate was never installed — see the OPTIONAL preamble.)

**Observability** — a `v_autovibe_runs` view returns full lifecycle data:
```
SELECT run_id, status, intent, branch, duration_seconds, pr_number, merged_sha, exit_code
  FROM v_autovibe_runs
 WHERE started_at > now() - interval '24h'
 ORDER BY started_at DESC;
```

**Orphan detection** — a `pg_cron` job runs every 5 minutes; any row with
`status IN (registered, running, waiting)` and `last_heartbeat_at < now() - interval '90 minutes'`
gets auto-transitioned to `failed`. 90 minutes (not 30) so a long `/council --extended` run
(8 parallel agents) does not false-positive; `running → running` heartbeats during long phases
keep the watchdog quiet.

### Session Outcome Recording (OPTIONAL — same substrate umbrella)

If a `session_outcomes` table + `record_session_outcome()` RPC are present, autovibe also writes
regression-substrate signals at three points. The RPC is idempotent on `agent_session_id`
(UNIQUE + ON CONFLICT DO UPDATE with COALESCE) — partial-update calls accumulate fields.

| When | Mode | What gets written |
|---|---|---|
| **Phase 5 — Post-code-council** | `council` | `review_verdict` (PASS / ADVISORY / BLOCKING / NONE) |
| **Phase 6 — Ship complete** | `outcome` | `result_success=true`, `outcome_summary` (PR#, commits, signal), `retrieval_method` |
| **Phase 6 — Ship failed** | `outcome` | `result_success=false`, `outcome_summary` (exit_code, error_type) |

**Helper**: `bash .claude/skills/autovibe/scripts/record-outcome.sh {outcome|council|e2e} <args>`
emits `[KERNEL-CALL] SELECT record_session_outcome(...);`. Claude runs it via
`mcp__supabase-{{project}}__execute_sql`.

**HALT discipline on outcome-write failure**: unlike register, an outcome-write failure does
NOT halt the run — the lifecycle row is the load-bearing surface; `session_outcomes` is
additive. Log the failure and continue.

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

## Foundation-First Shipping (when council finds heavy MUST-HAVE count)

When `/council --extended` returns ADVISORY-SHIP with **10+ MUST-HAVE defenses** AND Pragmatist's honest estimate spans 3+ sessions:

**Don't compress into one session.** That forces the thin-shell intermediate state the council rejected.

**Ship the foundation PR this session**:
- Council session file (locked verdict + auto-resolved decisions)
- Contract specs (URL shapes, schema decisions, integration boundaries)
- Additive migrations (idempotent, low-risk, `NOTIFY pgrst, 'reload schema';` included)
- v2 execution continuation with all MUST-HAVE defenses as Phase 1b–N line items
- ROADMAP entry + memory file
- Typically 5 files, ~1000 lines, 100% additive, no existing code touched

**Queue implementation for next session** via the v2 execution continuation. Each MUST-HAVE defense becomes a checklist item the next session cannot skip.

**Detection signal — if 3 of 4 hold, default to foundation-first**:
- Devil's Advocate finds 3+ CRITICAL findings
- Reliability Engineer flags 3+ NON-SHIPPABLE FLAGS
- Edge Case Finder names 3+ specific time-bombs
- Pragmatist confidence on ship-date < 70%

**Failure mode prevented**: shipping all 17 defenses + the implementation in one session = high probability the implementation skips 2-3 defenses under time pressure, ships silent failures, and the council retroactively becomes theatre.

**Precedents**: 2026-05-03 PP.1 (17 defenses, 3-session split — foundation in PR #406), 2026-04-30 CM.35 Wave A foundation + Wave B v2 plan, 2026-04-23 Strategy Grades chip v1→v2.

---

## Framing Audit (mandatory — two checkpoints)

Per `.claude/rules/framing-audit-mandate.md`, a framing audit — confirming the work is the
*right question* before it is answered — is compulsory before load-bearing, multi-phase
work. `/autovibe` IS such work, so **planned mode** runs the audit at two checkpoints:

| Checkpoint | When | Audits | Defined in |
|---|---|---|---|
| 1 — goal audit | step 2a, before `EnterPlanMode` | the raw INTENT / GOAL | `modes/planned.md` step 2a |
| 2 — plan audit | step 5, the `/council --extended` Phase 0 Reframer | the DRAFTED PLAN | `modes/planned.md` step 5 |

**Two checkpoints, not one**: the Reframer (checkpoint 2) only ever sees a plan that has
*already* been drafted — a wrong frame would already have shaped the plan-writing step.
Checkpoint 1 catches a wrong frame on the goal itself, before any plan exists. Both run the
matching framing-audit primitive (`/reduce-to-first-principles`, `/check-commensurability`,
or `/map-feedback-loops` DECISION mode), record the verdict, and HALT on a flagged frame.
**Direct mode** (trivial work) runs neither — correct per the mandate rule's not-for-trivia
scope.

Cite the primitives; never copy their procedures — see `framing-audit-mandate.md` for the
full trigger table and the five primitives.

---

## Phase 5.5 — Staging-First Gate (mandatory before `/ship`)

Between Phase 5 (post-code-council) and the `/ship` phase, an autonomous run MUST pass the
**hard staging-first gate** — so an autonomous agent cannot reach production directly; the
default path is staging, and production-direct is friction-positive (explicit flag + verified,
externally-attributed log). This is the structural precondition for autonomous operation.

**Requires the `dev-prod` skill** (which owns the routing registry + the gate contract).
Do not reimplement the gate here — invoke `dev-prod`. Authoritative procedure:
`.claude/skills/dev-prod/references/autovibe-gate-wiring.md`; routing registry:
`.claude/skills/dev-prod/references/entity-routing.md`.

The contract, in brief:

1. **Resolve entity** from `profile_slug` / branch. Unresolved/unknown/ambiguous →
   **fail-closed**: halt, write continuation, never default to any entity.
2. **Read the `STATUS:` token** (not prose) in the dev-prod registry. Anything but exactly
   `wired` (or a missing staging ref) → HALT, continuation. Never `/ship` to a stub.
3. **Default ship target = staging.** `/ship` targets staging unless the override is satisfied.
4. **Pre-promotion checklist** (dev-prod SKILL.md) must pass — incl. the exhaustive
   hardcoded-prod-ref grep and the staging-healthy precondition (timeout ≠ pass).
5. **Production-direct override** requires BOTH: (a) `AUTOVIBE_PROD_DIRECT` affirmatively truthy
   (`1/true/yes/enabled`; absent or `0/false/no/off/disabled` = staging-first), AND (b) an
   externally-attributed, write-then-read-back-verified override record. The record write
   follows HALT discipline — a failed/timed-out write halts the run; never "shipped anyway."

If the project's autovibe has the kernel-registration layer, the gate emits the Phase 5.5
transitions (`staging_gate_entered/_pass`, `prod_direct_override`, `staging_gate_halt` → `failed`);
otherwise record the gate decision in the project's audit trail.

**Enforcement honesty**: this gate is procedure-level (the orchestrator honours it), NOT a hard
PreToolUse block. It is as strong as the orchestrator's adherence — a future hardening hook could
make it tamper-proof.

**Coupling (propagation):** Phase 5.5 depends on the `dev-prod` skill. Any contract change here
MUST be mirrored in `dev-prod`, and BOTH skills pushed to the template together — never one
without the other.

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
| `/council --extended` | command | Phase 0 reframer + 7-agent deliberation |
| `/amend-plan` | command | Apply council verdicts to plan |
| `/execute` | command | Plan implementation |
| `/code-council` | command | Multi-lens diff review (PASS/ADVISORY/BLOCKING) |
| `dev-prod` | skill | **Phase 5.5 staging-first gate** — entity routing + promote/rollback + prod-direct override contract. autovibe INVOKES it before `/ship`; never reimplements the gate. Coupled: push BOTH to template together. See §Phase 5.5. |
| `/ship quick` | skill | Direct-path target |
| `/ship pr` | skill | Planned-path target — full PR + CI + smoke |
| `/ship hotfix` | skill | **NEVER auto-invoked** — exit 9 if conditions detected |

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
- Use `AUTOVIBE_DRYRUN=1` for any new test scenario before live invocation

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

1. Try cached fleet state first: `bash .claude/skills/verify-shipped/scripts/read-state.sh --max-age 60` (60-second freshness window — anything older is suspect post-ship)
2. If exit 1 (missing/stale): invoke `Skill verify-shipped quick` (Layers 1+2+3+6 only — Layer 5 was just affected by this session's deploys; give 30s buffer before next audit)
3. Parse the result `exit_code`:
   - `0` (clean): log `fleet clean post-ship` to the session file; continue to Phase 5
   - `1` (drift): append the punch-list to the session file; surface to user with prefix `🚧 shipped, but here's what else is loose:`; continue to Phase 5 (do NOT halt)
   - `2` (layer error): log `fleet audit errored — continuing without fleet status`; continue to Phase 5 (graceful degradation)
   - **Any non-parseable result** (Skill tool itself failed, MCP unavailable, network failure, JSON malformed): treat as `2` — log `[INFO] fleet audit unavailable — continuing without fleet status` and continue to Phase 5. The post-ship flow MUST NOT block on `/verify-shipped` failure under any circumstance. (Per code-council 2026-05-07 IMPORTANT #2 — never-block guarantee.)
4. **Composes with Phase 5**: drift detection adds the `fleet drift detected post-ship` row to the Session Learning Gate triggers below.

**Wall-clock budget**: target <20s on a multi-worktree fleet. The hook MUST NOT block the post-ship flow significantly — graceful degradation is mandatory.

**Failure mode prevented**: ships PR #N with code that depends on PR #N-K's edge function being deployed; PR #N-K's deploy was forgotten. Without this hook, partner-facing flow breaks silently. Layer 5 of `/verify-shipped` catches the drift; Phase 4.5 surfaces it the moment the operator is most likely to act.

**State-file dependency**: see `verify-shipped/references/integration.md` for the schema + suppress-file format + lock contract.

---

## Phase 4.55 — Post-Ship Topology Re-Emit (added 2026-06-12) — scoped, never-blocking

**Why here**: a clean ship is the exact moment the system's structure is KNOWN to have changed, and the conversation still holds the MCP access the topology emitters need (the reason a session-end hook / background cron was rejected — emitters are model-driven; see `system-awareness-mandate.md` § refresh-when-it-matters). Re-emitting now means the map is fresh for ALL downstream consumers (reconcile, portal surfaces, the next session) instead of deferring the cost to the next plan-class session's gate. The plan-time refresh-when-stale gate REMAINS as the safety net — this phase just makes it rarely fire.

**When**: after Phase 4.5 returns, before Phase 4.7. Fires only on `ship_signal == "clean"`. Skip silently (one-line note) on projects that have not initialised the topology substrate.

**Scope by what the ship actually touched** (read the merged diff / ship-state):

| Ship touched | Emitter to re-run | Token cost |
|---|---|---|
| `src/**` or `supabase/functions/**` | code emitter (`.claude/skills/code-emitter/` — pure scripts) | ~free (script-side; only receipts enter context) |
| `supabase/migrations/**` applied this session | supabase-live emitter (`.claude/skills/supabase-live-emitter/`) | moderate (MCP catalogue queries pass through context) |
| n8n workflow changes | n8n-cloud emitter | moderate |
| docs/rules only | NOTHING — skip with one-line note | zero |

**Context-budget interaction (Phase 4.6)**: if estimated context usage ≥ 40%, run ONLY the script-side code emitter and SKIP the MCP-bearing emitters with a logged note (`topology-reemit-deferred: <layer> — context budget; plan-time gate covers it`). The deferred layer self-heals at the next plan-class session per the standing gate.

**Never-blocking guarantee** (mirrors Phase 4.5): any emitter failure → log `topology-reemit-failed: <reason>` to the session file, emit a one-line chat note, continue to Phase 4.7. The post-ship flow MUST NOT halt on a map refresh.

**Verification**: after a re-emit, the topology health-check's first line must read FRESH for the re-emitted layer; paste that line into the session log.

**Composes with — does not replace**: the SessionStart/plan-time hook (`system-awareness-activation.sh`) + `/topology align` deep read stay untouched; this phase only shifts WHEN the write-path usually runs (post-ship instead of next-plan).

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
3. **Spawned-agent outputs**: 7-agent council = ~50-80K tokens of agent outputs alone. /agent-research deep = similar.
4. **Compaction warning from harness**: if the harness has emitted ANY auto-compact warning during this session, treat as `>= 50% used`.
5. **Operator override**: if the operator explicitly said "context is getting full" or "let's hand off" — treat as immediate trigger.

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

## Phase 4.8 — Autofire Continuation (OPT-IN — org-specific wiring)

> **OPT-IN, and the dispatch transport is org-specific.** Phase 4.8 closes the manual-paste
> gap: after Phase 4.7 writes a canonical MASTER continuation, Phase 4.8 schedules a fresh
> session (~5 minutes out) that resumes from that file — so multi-session features fire
> themselves with no manual chat-open + paste. The **gates** below ship in the template; the
> **transport** that actually spawns the child session is environment-specific and is **not**
> templatized. Read `.claude/skills/autovibe/references/newvibe-integration-guide.md`
> (the per-repo wiring runbook, with `[ORG-SPECIFIC]` markers) before enabling autofire.

**When to fire — ALL conditions must hold** (every gate fails closed):

1. Phase 4.7 succeeded (latest `.claude/phase47-log.jsonl` entry has `status:"written"`)
2. `ship_signal == "clean"` (NOT `rollback`, `admin_merge`, `smoke_unverifiable`, or any non-zero ship exit)
3. Mode != hotfix
4. Verifier PASSes: `bash .claude/skills/autovibe/scripts/verify-continuation.sh <canonical-path>` exits 0 (capture rc by direct redirect — never `… | tail`; a pipe would mask the exit code)
5. Kill-switch off: `AUTOVIBE_AUTOFIRE` accepts any of `0`/`false`/`no`/`off`/`disabled` (case-insensitive) as DISABLE; anything else (unset, `1`, `true`, `yes`) = ENABLED
6. The original intent contains no destructive keywords (`delete`, `drop`, `destroy`, `rm -rf`, `force.push`, `--no-verify`, `truncate`)

If ANY condition fails: skip Phase 4.8, append `.claude/phase47-log.jsonl` with
`status:"autofire-skipped"` + `skip_reason:"<which-gate>"`, emit a heartbeat, continue.

**How to enable**: the gates + verifier (`verify-continuation.sh`) + chain-guard
(`newvibe-chain-guard.sh`, depth ≤ 5) ship with this skill dir. The **firer** — what actually
launches the next session — is org-specific (e.g. the in-session `/schedule` skill, a cron
tool, or a remote-execution workflow). Wire your transport per the integration guide; until a
transport is wired, autofire is a silent no-op and the next session is a normal manual paste
(Phase 4.7's MASTER file still exists, so nothing is lost).

**Kill switch** (instant disable):
```bash
export AUTOVIBE_AUTOFIRE=0                        # this shell only
echo 'export AUTOVIBE_AUTOFIRE=0' >> ~/.zshrc     # persistent
```

---

## Session Learning Gate (2026-04-23)

After post-push doc, the conversation evaluates whether the session produced cross-session learnings worth capturing. Auto-invoke `/reflect` only when worthwhile — NEVER unconditionally (token bloat on trivial sessions).

### Gate — invoke `/reflect` IF any of these are true:

- Ran `/council` or `/council --extended` during the session
- Exited plan mode (ExitPlanMode fired at least once)
- User correction received — signal phrases: "no, do X instead", "make sure no regression", "wrong approach", "stop doing Y", or rejected an ExitPlanMode
- Shipped ≥2 PRs during the session (indicates non-trivial work)
- `/code-council` returned BLOCKING or ADVISORY verdict (not PASS)
- Any composed-skill step returned a non-zero exit code that was recovered from mid-session
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

`auto-council-on-plan.local.md` hookify rule (in template repo, not installed here): **left uninstalled**. `/autovibe` is the explicit trigger. Manual `ExitPlanMode` does NOT auto-fire council. One trigger, one path.

User can revise this by installing the hookify rule and updating `references/decisions-locked.md` accordingly.

---

## Rollback (if /autovibe itself misbehaves)

1. `rm -rf .claude/skills/autovibe/` — skill unregistered, all composed skills still work standalone
2. `rm -rf .claude/autovibe-state.lock/ .claude/autovibe-state.json` — clears stale lock (also auto-clears on 30-min TTL)
3. `rm -rf .claude/skills/prime-lite/` — only if you also want prime-lite gone (it's standalone-useful)
4. Sign-off file at `specs/autovibe-design-decisions-2026-04-19.md` — left in place for audit

Zero blast radius outside `.claude/skills/autovibe/`, `.claude/skills/prime-lite/`, and the state lock files.

---

## References

- **Continuation source**: `continuations/AUTOVIBE-SKILL-DESIGN-MASTER-CONTINUATION-2026-04-19.md`
- **Decisions locked**: `references/decisions-locked.md`
- **Invocation contract**: `references/invocation-contract.md`
- **Ship contract**: `../ship/SKILL.md`
- **Council protocol**: `../../rules/council-protocol.md`
- **Memory guidance**: `CLAUDE.md` §Auto memory
