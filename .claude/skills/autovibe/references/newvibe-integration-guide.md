# NewVibe — Per-Repo Integration Guide

> **Audience**: a Claude Code session running inside a repo that has just received
> NewVibe (the `autovibe` skill + the two `newvibe-*` hooks) from the
> `claude-code-project-template`. This guide carries the *full context* needed to
> wire NewVibe correctly **for that specific repo** — not a generic copy job.
>
> **Register**: technical. This is a runbook for Claude consumption, not chat prose.
>
> **Origin**: the agency, NewVibe Phase 2 (2026-05-17). Reference implementation
> values below (`your-instance.app.n8n.cloud`, workflow `4s3mMGYcpucHbD2Tc3kci`, the
> `nv_detect_slug` REPO_MAP) are the agency's. An adopting org replaces them with
> its own — every place that needs replacing is marked **[ORG-SPECIFIC]**.

---

## 0. What NewVibe is (so the integration decisions make sense)

> ## ⚠ NewVibe autofire is NOT a cloud routine
>
> If a session is arming a **routine** at `claude.ai/code/routines`, invoking
> the **`/schedule`** skill or **`CronCreate`**, installing the **Claude GitHub
> App**, or wiring **claude.ai connectors** — it is on the WRONG path. Those are
> Anthropic's hosted-cloud scheduler; NewVibe does not use any of them. A
> session that finds itself on `claude.ai/code/onboarding` or
> `claude.ai/customize/connectors` should stop and re-read this section.
>
> NewVibe autofire = **local `Stop`/`PreCompact` hooks → an n8n SSH-Execute
> webhook → a fresh `claude -p` on the target machine.** All local: real repo,
> real hooks, real MCP servers, real project memory. That is the whole reason
> it exists — a cloud routine has none of that.
>
> And autofire is **not how you start work.** To run autonomously *now*, just
> run `/autovibe` — it needs zero autofire setup. Autofire only chains the
> *next* session after a clean ship. No prior ship = autofire correctly does
> nothing; it is not broken, and it is not something to "go set up." If there
> is nothing to chain from, just do the work (or `/ship` it).

**NewVibe** = the agency's autonomous-shipping orchestrator. Two halves:

1. **The orchestrator** — the `/autovibe` skill. Composes `/plan → /council →
   /amend-plan → /execute → /code-council → /ship` into one invocation, or routes
   trivial work straight to `/ship`. This half works the moment the skill folder
   is present — nothing to wire.

2. **Autofire** — the part this guide is about. When a ship completes cleanly and
   a master continuation exists, autofire dispatches a *fresh* Claude session (on
   the target Mac, via an n8n webhook → SSH-Execute) that resumes the next phase
   of work. No human pastes a continuation. Multi-session features ship
   themselves end-to-end.

Autofire is **shell-enforced**: it fires from two hooks (`Stop` and
`PreCompact`), never from a chat remembering to run a step. That is the whole
point of the Gate A architecture — the hooks cannot be silently dropped on a
long session the way conversational SKILL.md prose can.

**Integration = making autofire able to fire from this repo.** The orchestrator
needs nothing; autofire needs the steps below.

---

## 1. File inventory — what arrived with the template

Confirm these exist before doing anything else:

| Path | Role | Git-tracked? |
|---|---|---|
| `.claude/skills/autovibe/SKILL.md` | The orchestrator spec (Phase 4.6/4.8 = the autofire reference spec the hooks implement) | yes |
| `.claude/skills/autovibe/scripts/newvibe-dispatch-lib.sh` | The gated dispatch library — sourced by both hooks | yes |
| `.claude/skills/autovibe/scripts/newvibe-chain-guard.sh` | Runaway-loop cap (chain depth ≤ 5) | yes |
| `.claude/skills/autovibe/scripts/verify-continuation.sh` | Structural lint gate for a continuation before dispatch | yes |
| `.claude/skills/autovibe/scripts/newvibe-dryrun-matrix.sh` | End-to-end integration test (this guide's verify step) | yes |
| `.claude/skills/autovibe/scripts/post-handoff-writer.sh` | DRAFT continuation floor writer | yes |
| `.claude/hooks/newvibe-autofire-stop.sh` | `Stop`-event hook — the autofire trigger | yes |
| `.claude/hooks/newvibe-precompact-handoff.sh` | `PreCompact`-event hook — context-budget handoff | yes |

Quick check:

```bash
ls .claude/skills/autovibe/scripts/newvibe-*.sh \
   .claude/skills/autovibe/scripts/verify-continuation.sh \
   .claude/hooks/newvibe-*.sh
```

If any are missing, the template copy was incomplete — re-pull the template
before continuing. **Do not hand-write these scripts** — they passed a Phase 1
code-council and carry safety logic that must not be paraphrased.

---

## 2. The integration boundary — what is in-repo vs environment

NewVibe splits cleanly into two layers. Knowing which is which prevents wasted
effort:

| Layer | What it is | Who provisions it |
|---|---|---|
| **In-repo (steps 3–6)** | hook registration, `.gitignore`, slug detection, install verification | a Claude session in the repo — **autonomous** |
| **Environment (step 7)** | the n8n webhook + REPO_MAP, the target Mac's SSH substrate | the **operator** — needs n8n access + Mac config; NOT self-provisionable |

A repo can fully complete steps 3–6 on its own and pass every self-test. But the
first *real* autofire dispatch will only succeed once step 7's environment exists.
Until then, every dispatch path stops cleanly at the `would-dispatch` dry-run
outcome (all gates pass, nothing is curled). That is the designed-safe state.

---

## 3. Step 1 — register the two hooks

The hook *scripts* are git-tracked (they arrived with the template). The hook
*registration* lives in `.claude/settings.local.json` — per-machine, gitignored,
and therefore **not** carried by the template. This is the one step that must be
done on every machine × every repo.

> Why `settings.local.json` and not `settings.json`: agent writes to the
> committed `.claude/settings.json` are blocked by the self-modification
> guardrail. `settings.local.json` is agent-writable and per-machine — the
> correct home for a Stop hook by repo convention.

Add the `Stop` entry and the `PreCompact` block. The shape:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/newvibe-autofire-stop.sh",
            "timeout": 20
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/newvibe-precompact-handoff.sh",
            "timeout": 20
          }
        ]
      }
    ]
  }
}
```

If the repo's `settings.local.json` already has a `Stop` array (other hooks
registered), **append** the NewVibe entry to the existing `hooks` array inside
it — do not replace the array. Same for `PreCompact`. Timeout is 20 seconds: the
dispatch path is bounded (verifier + chain-guard + a 15-second `curl` cap), and
a Stop hook must never block longer than its timeout.

The hooks take effect on the next session. Until then they are inert.

---

## 4. Step 2 — `.gitignore` the runtime state

NewVibe writes four runtime-state files. **All four must be gitignored.** The
arm flag especially: committing it would arm a real autofire on every fresh
checkout of the repo — a genuine footgun.

Ensure `.gitignore` contains:

```gitignore
# NewVibe autofire runtime state (per-machine, never committed).
# The arm flag MUST stay ignored — committing it would arm a real autofire
# on every checkout.
.claude/.newvibe-autofire-armed
.claude/phase47-log.jsonl
.claude/ship-state.json
.claude/autovibe-state.json
```

| File | What it is |
|---|---|
| `.newvibe-autofire-armed` | Single-fire arm flag. Present = the next clean ship may dispatch one real autofire. Consumed (removed) on use. |
| `phase47-log.jsonl` | Append-only autofire ledger — also the chain-depth source for the runaway cap. |
| `ship-state.json` | Written by `/ship`; the Stop hook reads it for the clean-ship completion signal. |
| `autovibe-state.json` | The orchestrator's own lock/state file. |

---

## 5. Step 3 — slug wiring

Autofire dispatches by **project slug**. The dispatch library resolves the slug
in this order (`nv_detect_slug` in `newvibe-dispatch-lib.sh`):

1. The `NEWVIBE_PROJECT_SLUG` environment variable, if set.
2. A pattern match on the repo's absolute path (the REPO_MAP `case` block).
3. Otherwise empty → autofire skips with `skip_reason: "slug-undetected"` (safe).

Check what this repo resolves to:

```bash
bash -c 'source .claude/skills/autovibe/scripts/newvibe-dispatch-lib.sh
         nv_resolve_paths
         echo "slug: $(nv_detect_slug "$NV_PROJECT_ROOT")"'
```

- **Non-empty, correct slug** → done, nothing to wire.
- **Empty or wrong slug** → pick one of:
  - **[ORG-SPECIFIC]** add a `case` arm to `nv_detect_slug` matching this repo's
    path (preferred — it is then automatic for every clone/worktree), or
  - export `NEWVIBE_PROJECT_SLUG=<your-slug>` in the shell environment (per-machine).

The slug chosen here **must equal** the key used in the n8n REPO_MAP (step 7).
The slug is the contract between the repo and the dispatch substrate.

> the agency reference REPO_MAP (`nv_detect_slug`): `the app-ai`, `a-logistics-app-freight`,
> `yourproject-properties`, `golden-pocket`, and `justin-your-org` /
> `your-org` for the agency hub (the hub slug is user-aware). **[ORG-SPECIFIC]** —
> replace with your own repos.

---

## 6. Step 4 — verify the in-repo install

Run all four test harnesses. Every one must pass before declaring the in-repo
integration done:

```bash
bash .claude/skills/autovibe/scripts/newvibe-chain-guard.sh    --self-test
bash .claude/skills/autovibe/scripts/newvibe-dispatch-lib.sh   --self-test
bash .claude/skills/autovibe/scripts/verify-continuation.sh    --self-test
bash .claude/skills/autovibe/scripts/newvibe-dryrun-matrix.sh
```

Expected: `ALL PASS` from each (10/10, 17/17, 10/10, and 11/11 respectively).

The first three test the units in isolation. The fourth — the dry-run matrix —
runs the **real wired hooks** against synthetic state in a sandbox: it confirms
the `Stop` and `PreCompact` hooks resolve the library, the gates fire in order,
and an unarmed run correctly stops at `would-dispatch`. The matrix is
self-contained (it generates its own continuation fixture) so it passes in any
repo with the files from step 1 present.

If the matrix fails, the hook wiring is wrong — re-check steps 1 and 3 before
going further.

---

## 7. Step 5 — environment substrate (operator-gated)

This is the half a Claude session **cannot** self-provision. For a real autofire
to land a fresh session, two environment pieces must exist:

### 7a. The n8n dispatch workflow + REPO_MAP

Autofire POSTs to an n8n webhook that routes to an SSH-Execute step:

- **[ORG-SPECIFIC]** Webhook: `https://your-instance.app.n8n.cloud/webhook/ki-ssh-execute`
- **[ORG-SPECIFIC]** Workflow: `W-KI-SSH-EXECUTE` (id `4s3mMGYcpucHbD2Tc3kci`)

The workflow's REPO_MAP must contain an entry for this repo's slug (step 5)
mapping it to `{ repo path on the target Mac, target user }`. Without that entry,
the webhook validates but the SSH-Execute step throws on the unknown slug.

If adopting NewVibe outside the agency, the webhook host + workflow are replaced
with the org's own SSH-Execute equivalent. The dispatch contract (the JSON body)
is fixed: `{project_slug, prompt, action_type:"autofire_continuation",
session_id, target_branch, expected_sha256}`.

### 7b. The target Mac's SSH substrate

The Mac that runs the autofired `claude -p` session needs a six-layer setup:
n8n workflow reachability, an `autossh` reverse tunnel, macOS Remote Login,
`ufw` rules for the tunnel port, an OAuth token file
(`~/.claude_oauth_token`, mode 600 — Keychain is unreachable from a
non-interactive SSH session), and the SSH topology.

Full walk-through: `docs/d-prime-v2-cassandra-mac-setup.md` (the agency). Treat it
as the precondition checklist before adding any new `target_user` to the n8n
REPO_MAP. **A new Mac is a deliberate operator setup, not an autonomous step.**

Until 7a + 7b exist for this repo, autofire stays in the safe `would-dispatch`
dry-run state — correct, not broken.

---

## 8. The safety model — what to know before the first real fire

Autofire has three independent fail-closed layers plus several gates. Every gate
skips-on-doubt:

| Layer | Mechanism | Disable / effect |
|---|---|---|
| **Kill-switch** | `AUTOVIBE_AUTOFIRE` env var | Set to `0`/`false`/`no`/`off`/`disabled` → every dispatch skips immediately. `export AUTOVIBE_AUTOFIRE=0` (or add to `~/.zshrc`). |
| **Runaway cap** | `newvibe-chain-guard.sh` — chain depth from `phase47-log.jsonl`, refuses past depth 5 (6-hour window) | A self-spawning loop is stopped at hop 6. A corrupt log fails conservative (refuse). |
| **Arm flag** | `.claude/.newvibe-autofire-armed` — **single-fire** | No flag → `would-dispatch` only. The flag is consumed (removed) after each real dispatch, so every real autofire is a fresh, deliberate operator decision. |

Plus, per dispatch: continuation verifier PASS, sha256 TOCTOU re-check, an
`mkdir` lock (120-second TTL), a destructive-keyword scan of both the
continuation body and the intent string, and a dispatch-once dedup keyed on the
continuation path.

**The clean-ship completion signal** (what the `Stop` hook waits for): a
`ship-state.json` with `exit_code: 0`, `mode != hotfix`, `admin_merged != true`,
and `completed_at` within the last 20 minutes — AND a master continuation file
written at or after that ship — AND that continuation not already dispatched.
Any non-ship turn is a fast, silent no-op.

**The continuation contract** — autofire only dispatches a file that is:
`AUTOVIBE-{YYYY-MM-DD-HHMM}-{slug}-MASTER.md`, ≥ 500 bytes, ≥ 8 numbered
`## N.` sections, contains a `## N. Current Branch` section, has no destructive
keywords, and is the only file with its slug in `continuations/`.

---

## 9. Step 6 — the first dogfood (supervised)

The first real autofire on a repo is done with a human watching:

1. Confirm the kill-switch is unset and the target Mac is awake with its tunnel up.
2. Arm one fire: `touch .claude/.newvibe-autofire-armed` (single-fire — consumed on use).
3. Run a real, small code task through `/ship pr`. It writes `ship-state.json`
   with `exit_code: 0` and a recent `completed_at`; a `AUTOVIBE-*-MASTER.md`
   continuation must exist, newer than the ship.
4. The `Stop` hook detects the signal → runs every gate → POSTs the webhook → a
   fresh `claude -p` launches on the Mac.
5. **Verify**: one `autofire-dispatched` entry in `.claude/phase47-log.jsonl`;
   then inspect the autofired session's commits/PR — confirm it did real work.

**Sequencing note**: arm the flag *before* the qualifying signal exists. An
unarmed `Stop` turn that sees a clean ship + fresh continuation logs a
`would-dispatch` entry, and the dispatch-once dedup then treats that
continuation as handled. Arm first, then let the ship + continuation appear.

**If it does not fire**, check in order: arm flag present? `ship-state.json`
fresh with `exit_code: 0`? a `AUTOVIBE-*-MASTER.md` newer than the ship? Then
read `phase47-log.jsonl` for the `skip_reason`.

---

## 10. Troubleshooting — `skip_reason` values in `phase47-log.jsonl`

| `skip_reason` | Meaning | Fix |
|---|---|---|
| `slug-undetected` | `nv_detect_slug` returned empty | Step 5 — add a REPO_MAP case or set `NEWVIBE_PROJECT_SLUG` |
| `kill-switch` | `AUTOVIBE_AUTOFIRE` is disabling | `unset AUTOVIBE_AUTOFIRE` |
| `chain-depth-exceeded` | Runaway cap refused (depth > 5) | Expected protection — inspect the log for a real loop |
| `verifier-exit-N` | Continuation failed structural lint | See `verify-continuation.sh` exit codes (1–7) |
| `verifier-sha-missing` | Verifier passed but emitted no sha256 | Verifier output parsing — re-run the verifier manually |
| `branch-extract-failed` | No `## N. Current Branch` section | Add the section to the continuation generator |
| `concurrent-dispatch-lock-held` | Another dispatch holds the lock | Transient — clears on the 120-second TTL |
| `sha256-drift-since-verify` | Continuation changed between verify and dispatch | Expected protection — the file mutated mid-flight |
| `destructive-intent` | Destructive keyword in the intent string | Expected protection |
| `webhook-dispatch-failed-rc-N` / `webhook-http-NNN` | n8n webhook unreachable or non-200 | Step 7a — check the workflow + webhook |
| `not-armed` | All gates passed, no arm flag | Expected — this is the `would-dispatch` dry-run |

---

## 11. Rollback

NewVibe is contained. To remove it from a repo:

1. Remove the `Stop` and `PreCompact` NewVibe entries from `.claude/settings.local.json`.
2. Optionally remove `.claude/skills/autovibe/` and `.claude/hooks/newvibe-*.sh`.

The orchestrator (`/autovibe`) and every composed skill (`/ship`, `/council`,
etc.) keep working standalone. Blast radius is limited to the two hooks and the
`autovibe` skill folder.

---

## 12. Integration checklist

- [ ] Step 1 — both hooks present and registered in `settings.local.json` (timeout 20)
- [ ] Step 2 — all four runtime-state files gitignored (arm flag especially)
- [ ] Step 3 — `nv_detect_slug` resolves a correct, non-empty slug for this repo
- [ ] Step 4 — all four test harnesses pass (10/10, 17/17, 10/10, 11/11)
- [ ] Step 5 — n8n REPO_MAP has this repo's slug; target Mac substrate set up **(operator)**
- [ ] Step 6 — first supervised dogfood produced one `autofire-dispatched` entry + verified real work

Steps 1–4 are autonomous. Step 5 is operator-gated. Step 6 is supervised. A repo
that has done 1–4 and passes every test is correctly integrated *in-repo*; the
first real fire waits on step 5.
