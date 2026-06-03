# Claude Code Project Template — Changelog

All notable changes to the template are documented here.

## 2026-06-02 — feat(setup): /setup now onboards new operators to the understand-anything suite (+ a soft pointer to /topology)

A new operator running `/setup` (especially a first-timer being handed the template) now gets walked
through the **understand-anything** plugin — the friendly "map of your project" tool (clickable graph
+ guided tour + plain-English explainer; Lum1104's marketplace plugin, `/understand`). New **Step 9.5**
(before the closing Next Steps): checks if the plugin is installed (mirrors the Step 0.1 hookify check),
offers the two-command marketplace install if absent, and times the first `/understand` run honestly —
run it now on any existing code/systems they're bringing in (where it's most valuable), or once they've
written their first code if starting from scratch (the suite needs existing source to map). All
user-facing wording is plain-English (a non-technical friend reads it). A `+1` line lands in the Step 10
next-steps list too.

Also surfaces — in plain words — that the deeper **Intent-Actual-Gap mechanism** (`/topology`, shipped
in the same 2026-06-02 release) is already in their project: a live map of the *whole* system (code +
databases + automations + config) that flags intent-vs-actual drift, framed as "more than you need on
day one, there for when you grow into it." The understand-anything suite is the on-ramp; `/topology` is
the deeper engine.

## 2026-06-02 — feat: Intent-Actual-Gap Mechanism — first-ever template release (7 skills + 3 doctrines + contract)

Origin: the First-Principles Systems-Thinker workshop's flagship mechanism — keeping a system's *intended* design and its *actual* state cheaply visible and cheaply reconcilable for any operator (human or AI). Built + proven on BuyBox-AI across milestones M1-M4 (deep research → 3 doctrines → the topology mapper → the drift comparator, Test B proven live). This is its first propagation out of the workshop. M5 Path B+ (council 2026-06-02): the two built parts (topology + reconciliation) propagate now; intent-capture is a named future milestone (M6), NOT shipped here — the mechanism is honestly "two of three parts", not complete.

### What lands (57 files, all NEW — none were in the template)

**7 skills** (`.claude/skills/`):
- **topology-substrate** — the canonical per-repo system-map JSON + 7 atomic read/write helpers (the write surface the emitters target; READ-only `read-topology` self-validates).
- **4 emitters** that populate the map from real sources: **supabase-live** (Postgres `pg_depend`/RLS/RPC via the supabase MCP), **n8n-cloud** (cloud workflows via the n8n MCP), **code** (TS/edge-functions via the Understand-Anything AST library), **repo-config** (in-repo n8n JSON + vercel + package config).
- **topology-health-check** — the operator-facing READ layer (`/topology health`): coverage + freshness + per-kind counts + anomaly flags. Includes the M5 **sustain-staleness-gate** (the 30-day-sustain freshness guard — oldest-covered-emitter-wins, degenerate-stack-safe, catches stale/future-dated/type-violation) + its 15-assertion eval.
- **topology-reconcile** — the drift comparator (`/topology reconcile`, Doctrine 06): surfaces intent-vs-actual drift ranked by impact with a named action; 48 assertions; Test B proven live on BuyBox-AI.

**3 doctrines** (`docs/operational-doctrine/`): 04 intent-capture, 05 topology-from-source, 06 conservation-law-verification (600/638/635 lines; each triple-gate-passed; the three-way split earns separability via Test D, pairwise Jaccard < 23%).

**1 alignment contract** (`.claude/rules/intent-actual-gap-mechanism-alignment.md`) — the 10-clause programme contract (auto-loads on programme-class work).

**1 shared library** (`.claude/skills/_shared/sustain-log-schema.md`) — the per-entity 30-day-sustain log schema (makes the sustain verifiable; rolling-window rule + theatre-of-trust guard).

**1 command** (`.claude/commands/topology.md`) — `/topology {status|health|reconcile}`.

### Generalisation applied (the skills are well-architected — logic generic, business-specifics parameterised)

- **n8n-cloud-emitter/references/entity-scope.json** — shipped as a GENERIC placeholder (`entity: "<ENTITY>"`, `mcp_server: "mcp__n8n-mcp-<instance>"`, empty tags) with a clone-and-fill note. The BuyBox-AI tag set was NOT shipped.
- **The two live emitters' entity defaults** — the `BuyBox-AI` fallback became `your-entity` (an obvious placeholder, so an unconfigured entity flags itself rather than silently mislabelling its map as BuyBox-AI).
- **MCP names + project ids in scripts/queries** — `mcp__supabase-buyboxai__` → `mcp__supabase-<project>__`, `mcp__n8n-mcp-honeybird__` → `mcp__n8n-mcp-<instance>__`, the project ref → `<project-ref>`. Eval fixtures' self-contained synthetic data left intact.
- SKILL.md / reference PROSE that cites BuyBox-AI as the *proof* entity is left as proof-narration (acceptable — it documents where the mechanism was verified, not where it must run).

### Verified post-generalisation (in the template clone)
All evals re-run on the template copies and green: supabase-live (canonical-shape), n8n-cloud (canonical-shape), topology-reconcile (36 assertions), sustain-staleness-gate (15 assertions). The generalisation is non-breaking.

Synced from: First-Principles Systems-Thinker workshop @ 3aeb52b

## 2026-06-02 — docs(autovibe): full autovibe → template sync (now current; closes known drift)

Origin: the 2026-06-02 dev-prod work synced only autovibe **Phase 5.5** to the template (written self-contained). The template's `autovibe/SKILL.md` was otherwise materially behind Agency-Main, so every new project bootstrapped from the template inherited a half-current orchestrator — it knew the staging-first gate but not run-observability or the framing-audit gate. This entry closes that drift; the template autovibe is now current.

### What lands (3 sections ported, generalised)

- **Framing Audit (mandatory — two checkpoints)** — ported cleanly (no generalisation needed). Inserted before Phase 5.5. References the generic `.claude/rules/framing-audit-mandate.md` + the five framing primitives, all already template-managed. Planned mode runs a goal audit (checkpoint 1) and a plan audit via the council Reframer (checkpoint 2); direct mode runs neither (not-for-trivia).
- **Kernel Registration** — ported as an **OPTIONAL** section: applies only if the project has a kernel substrate (`agent_sessions` table + `autovibe_register`/`autovibe_transition` RPCs; `session_outcomes` + `record_session_outcome` for outcome recording). If absent, autovibe runs without it — a missing RPC is NOT a halt when the substrate was never installed. MCP name generalised to `mcp__supabase-{{project}}__`. Includes the lifecycle transition table, permitted-transition state machine, HALT-on-register-failure discipline, `v_autovibe_runs` observability view, 90-min orphan watchdog, and the Session Outcome Recording subsection (under the same optional umbrella).
- **Phase 4.8 — Autofire Continuation** — ported as a short **OPT-IN** stub. The gates (ship-signal clean, verifier PASS, kill-switch, destructive-keyword scan, chain-guard) ship with the skill dir; the **transport** that spawns the next session is org-specific and is NOT templatized — points at `.claude/skills/autovibe/references/newvibe-integration-guide.md` for per-repo wiring. No org-specific workflow internals inlined.

### Hygiene
- Removed three pre-existing operator-specific references from the autovibe SKILL.md (a `/Users/<operator>` plan path + two "operator name" prose mentions) — the file is now identifier-clean.

### Coupling
The `dev-prod` skill + Phase 5.5 + the deploy-guard hook were already synced (2026-06-02). This is an autovibe-body-only sync; dev-prod was verified still-current and not re-pushed.

Synced from: Agency-Main @ continuations/AUTOVIBE-TEMPLATE-SYNC-MASTER-CONTINUATION-2026-06-02.md

---

## 2026-06-02 — feat(dev-prod): production-deploy guard hook (hardens Phase 5.5, fail-closed)

Origin: Agency-Main built a PreToolUse safety hook that turns the dev-prod Phase 5.5 staging-first gate from *honoured* (orchestrator procedure) into *enforced* (physical block) for the autonomy path. Code-council (4 lenses) returned BLOCKING on the first draft — it read `status` but the real autovibe state file writes `phase`, so it would have passed its self-test and silently no-opped in production. All findings fixed; the hook is fail-CLOSED on every uncertainty and was dogfood-hardened twice (it fired on its own commits, surfacing a commit-message false-positive now fixed via quote-strip + newline-collapse).

### What lands

**Hook (1 new) — `dev-prod-deploy-guard.sh`:**
- `.claude/hooks/dev-prod-deploy-guard.sh` — blocks an **autonomous** (autovibe-active) production deploy lacking the `AUTOVIBE_PROD_DIRECT` override; **warns** (not blocks) manual deploys. Fires on prod Supabase MCP writes (`apply_migration`/`deploy_edge_function`/`execute_sql`-DDL) + Bash (prod ref, `supabase db push/execute`, `supabase functions deploy`, `git push` reaching main). Self-test 14/14.
- **Per-project config required**: edit the `PROD_MCP_PATTERN` + `PROD_REF` block (ships with self-consistent `EXAMPLE`/`EXAMPLEPRODREF0000000` placeholders so the self-test passes out of the box; replace with your real prod values).
- Added to the **never-disable** safety list in `hook-profile-gating.md` (no `HOOK_*` kill-switch).
- **Architecture note**: MCP tool-name detection is exact + covers the real deploy path; Bash command-string detection is heuristic + fail-safe (over-blocks at worst, never under-blocks). Don't expect a regex to understand shell intent.

### Auto-Setup Required (`mcp_permission` / hook registration)
This hook must be registered in `settings.json` PreToolUse under TWO matchers to function:
- `mcp__supabase-<your-prod-project>__*` → `bash .claude/hooks/dev-prod-deploy-guard.sh` (timeout 5)
- `Bash` → same command (timeout 5)
`/setup` and `/update-latest` should wire these; until then it's a manual paste.

### Coupling
Coupled with the `dev-prod` skill + autovibe Phase 5.5 (the gate it enforces). Push/update the three together.

**Failure precedent prevented**: an autonomous shipping run reaching production directly with no enforced gate — caught + fixed at the BLOCKING council before fleet-wide.

Synced from: Agency-Main @ PR #92

---

## 2026-06-02 — feat(dev-prod): dev-prod skill + /autovibe Phase 5.5 hard staging-first gate

Origin: Agency-Main proved NewEarth's dev/prod separation live (Supabase prod-vs-staging + n8n prod-vs-dev) and codified the pattern as a reusable skill, then wired a hard staging-first gate into `/autovibe` so an autonomous run cannot reach production directly. Both land in the template so every future project starts with the discipline — but with all real identifiers stripped to placeholders (a fresh project wires its own entities).

### What lands on first-setup (or on next `/update-latest`)

**Skill (1 new) — `dev-prod`:**
- `.claude/skills/dev-prod/SKILL.md` — environment-routing + promote + rollback procedure + pre-promotion checklist (incl. exhaustive hardcoded-prod-ref grep) + the /autovibe gate contract summary. Encoded-preference. skill-creator validation PASS 15/0 in source project.
- `.claude/skills/dev-prod/references/entity-routing.md` — per-entity registry, **all-stub with `{{placeholders}}`** on the template (machine-readable `STATUS:` token; gate reads token, not prose). Projects fill in real refs as each entity is separated + proven.
- `.claude/skills/dev-prod/references/autovibe-gate-wiring.md` — the Phase 5.5 gate contract (fail-closed entity resolution, truthy-flag + externally-attributed + write-then-verify override, `failed`-not-`waiting` halt).
- `.claude/skills/dev-prod/references/staging-wake.md` — wake an auto-paused Supabase staging project (preventative token handling).
- `.claude/skills/dev-prod/evals/evals.json` — 6 evals incl. stub hard-stop + record-write-failure halt + hardcoded-ref catch.

**Skill (1 updated) — `autovibe`:**
- `.claude/skills/autovibe/SKILL.md` — added **§Phase 5.5 — Staging-First Gate** (self-contained: invokes the `dev-prod` skill; kernel transitions conditional on the kernel-registration layer being present) + a `dev-prod` composition-inventory row.

### Coupling (non-negotiable)
`autovibe` + `dev-prod` are a coupled pair — Phase 5.5 invokes the dev-prod skill. **Push them to the template together; never one without the other.**

### Known drift (flagged honestly)
The template's `autovibe/SKILL.md` is otherwise behind Agency-Main's: it lacks the kernel-registration table (Spec 12 Addendum I) and the framing-audit section. Phase 5.5 was written self-contained so it works without them. A future full autovibe sync should bring those across (out of scope for this push).

**Failure precedent prevented**: an autonomous shipping run reaching production directly with no staging-first gate — the "staging-first observed for humans but not for autonomous deployments" failure mode. Code-council (4 lenses) caught a gate-honesty defect + 11 other findings in the source project; all fixed before this push.

Synced from: Agency-Main @ 9dc289f

---

## 2026-05-31 — feat(obsidian): full Obsidian parity for /setup — entity discipline + Stop-chain gate + vault commands + autopilot skills

Origin: Agency-Main inventory vs BuyBox showed a three-item Obsidian discipline gap (entity registry, entity-discipline doctrine, session-end-continuation-gate hook). Pulled BuyBox's entity layer into Agency-Main, then propagated the *machinery* (not BuyBox's project-specific entity cards) to this template so every future project setup starts with Obsidian discipline parity — entity registry contract, full Stop-chain wiring, vault command suite, and the autopilot skills already in fleet use.

### What lands on first-setup (or on next `/update-latest`)

**Rules (3 new):**
- `.claude/rules/entity-discipline.md` — canonical identity-layer doctrine (six rules: repo-rooted registry, one card per entity, mandatory `is_not:` clauses, wikilink-in-prose, etc.). Auto-loads on seven surfaces (Master-Continuation-Prompt, prime, prompt-forge, daily-plan, clientprojectupdate, council, reflect).
- `.claude/rules/kairos-readiness.md` — substrate doctrine; every new memory-pattern writes persistent state to Supabase with stable queryable schema (not local-only).
- `.claude/rules/symlink-discipline.md` — local convenience layer, not source of truth; cross-machine memory + worktree dependencies use symlinks correctly.

**Hook (1 new):**
- `.claude/hooks/session-end-continuation-gate.sh` — Stop-hook gate that writes an auto-continuation file when session ends with uncovered work (uncommitted files OR unpushed commits) AND no continuation was written in the last 6 hours. Runs AFTER session-summarizer (git state captured) and BEFORE vault-capture (Obsidian propagation). Never commits, never pushes, never merges — safe by construction.

**Skills (2 new):**
- `.claude/skills/obsidian-vault-autopilot/` — Bootstrap + Verify modes for Obsidian autopilot (per-machine config, Keychain protocol, persona detection, grid verification).
- `.claude/skills/vault-review/` — cadence meta-runner that surfaces overdue `/drift` / `/emerge` / `/graduate` invocations.

**Commands (5 new):**
- `.claude/commands/{challenge,emerge,trace,vault-review,vault-sync}.md` — the vault command surface. `/challenge` (single-belief stress test), `/emerge` (30-day idea-cluster graduation), `/trace` (evolution timeline), `/vault-review` (cadence runner), `/vault-sync` (KI deposit pull).
- `.claude/commands/drift.md` — 14-day recurring-theme surfacing (project tokens generalised to `{org-folder}` / `{venture-slug}` / `{client-slug}`).
- `.claude/commands/graduate.md` — research note → project conversion (project tokens generalised to `{venture-N-slug}` / `{your-org-slug}` / `{client-N-slug}`).

**Top-level (1 new):**
- `entities/README.md` — the entity-registry contract (frontmatter schema, what-goes-here / what-does-not, portability invariant) with a generic stub Index ready to fill in.

**bin scripts (5 new):**
- `bin/{activate-vault-autopilot,memory-health-check,enable-cross-machine-memory,setup-claude-memory,import-claude-memory,vault-sync}.sh` — the operational bin surface. activate-vault-autopilot + vault-sync had agency-specific tokens (supabase-newearthai, cross-repo example list) generalised to `{your-agency-instance}` / `{venture-N}` / `{client-N}` placeholders.

### Setup wiring updated

- `.claude/commands/setup.md` Stop-chain block expanded from `session-summarizer` only to the full four-hook chain (`session-summarizer` → `session-end-continuation-gate` → `vault-capture` → `auto-sync-artifacts`) — matches BuyBox + Agency-Main fleet pattern.
- `chmod +x` block extended to make all four Stop hooks executable.

### What did NOT propagate

- Agency-Main's nine seed entity cards (Justin, Cassandra, NewEarth AI, BuyBox AI, GoodBuy Properties, Golden Pocket, Nirvana Freight, Honeybird Homes, MidAtlantic Home) stay local — they are project-specific. A new project sets up empty `entities/` with the README contract, then populates its own cards on first need.
- BuyBox's project-specific rule files (drawer/buyer-modal/jv-intake/matching-engine/pml-lifecycle/etc.) — they belong in BuyBox alone.

### Verification (run on a fresh clone)

| Probe | Expected |
|---|---|
| `ls .claude/rules/entity-discipline.md` | present |
| `ls .claude/hooks/session-end-continuation-gate.sh` | present + executable |
| `ls .claude/skills/obsidian-vault-autopilot/SKILL.md` | present |
| `ls .claude/skills/vault-review/SKILL.md` | present |
| `ls entities/README.md` | present |
| `ls entities/*.md \| wc -l` | `1` (README only — no project entities until you add them) |
| `grep -c "session-end-continuation-gate" .claude/commands/setup.md` | `≥2` (JSON block + chmod) |
| `grep -rE 'dispodaddy\|honeybird\|nirvana\|buybox\|homepros\|trevor\|cassandra\|justin' .claude/commands/{drift,graduate}.md bin/{activate-vault-autopilot,vault-sync,setup-claude-memory}.sh \| wc -l` | `0` (post-scrub clean) |

Synced from: NewEarth AI Agency-Main @ commit (this push's parent on Agency-Main side)

---

## 2026-05-25 — feat(coordination): ARM the worktree janitor + auto-surface /where + session heartbeat (fleet-wide)

Origin: BuyBox operator runs 3-4 concurrent code chats sharing one project folder; leftover git worktrees re-accumulated (23) because the janitor could never prove a worktree was dead. The coordination layer was half-wired — the *seeing* (`/where`) worked, the *cleaning* was permanently asleep. This sync arms the cleanup so residual worktrees self-clear, auto-surfaces fleet/collision state at every session start, and ships it fleet-wide so every project inherits it. Built + verified on BuyBox branch `feat/session-coordination-arm-janitor`.

### The mechanism — session heartbeat (NOT PID)

A SessionStart hook now writes a per-worktree UTC-timestamp heartbeat; the janitor reads it. PID was the wrong signal — a SessionStart hook is a throwaway subprocess whose `$$` dies instantly, so PID-liveness would mark every worktree dead and delete live work. Timestamp-freshness is the correct cross-boundary signal (mirrors `cross-chat-collision-detect.sh`'s existing timestamp-marker choice).

**Critical wiring invariant**: writer and reader resolve the heartbeat dir via `git rev-parse --git-common-dir` (the shared `.git`, identical for every worktree) → its parent. A worktree's own `.claude/worktrees/` is a DIFFERENT physical dir from the primary's; using `--show-toplevel` would have silently mis-filed every heartbeat. Verified live: a heartbeat written from a linked worktree lands in the PRIMARY's shared dir, absent from the worktree-local dir.

- **UPDATED** `.claude/hooks/sessionstart-context-aggregator.sh` — adds `resolve_primary_root()` (shared common-dir parent), `emit_heartbeat()` (atomic temp+mv write, status rides the visible "Session context loaded: …· heartbeat: <basename> @ <time>" line so a broken writer is visible EVERY session), and `emit_fleet_collision_section()` (composes `where.sh`, exit-1=collision → LOUD ⚠️ hoisted to the TOP of the briefing; exit-0 → quiet 🟢 all-clear). Self-test extended 7→11 (T8 path-agreement, T9 heartbeat write, T10 visible-line ride, T11 fleet verdict).

- **UPDATED** `.claude/skills/where/scripts/sweep-stale-worktrees.sh` — **ARMED.** Check 4 rewritten PID→heartbeat-freshness. A worktree untouched by any session for >48h (`--stale-hours N`) is heartbeat-STALE and — only with clean ∧ merged ∧ commit-older-than-N-days — eligible for removal. **--apply human-invoke-only** (automated surfaces show the dry-run "WOULD remove" list). **Grace option b**: no heartbeat file = LIVE, never auto-removed (the heartbeat file IS the "born into the heartbeat era" marker, so pre-existing worktrees stay manual-only with zero unreliable mtime guessing). **Fail-safe parse**: empty/garbage/future-dated heartbeat → LIVE, never ancient-eligible. New 9-case `--self-test`. Threshold (48h + grace policy) was the one load-bearing decision; reasoned through Devil's-Advocate / Edge-Case / Reliability lenses + operator-approved before the deletion logic shipped (council sub-agents were unavailable this session).

- **UPDATED** `.claude/skills/where/scripts/where.sh` — brought current with the post-2026-05-19 continuation-intent + forgotten-branch flags (template was 134 lines behind).

- **UPDATED** `.claude/skills/where/SKILL.md` — Companion note rewritten from "permanently fail-safe PID, removes nothing" to the armed-heartbeat reality.

- **NEW** `.claude/hooks/cross-chat-collision-detect.sh` — PreToolUse Write/Edit warn (the write-time counterpart to the session-start auto-/where). Was BuyBox-local; now template-managed. Register in committed `settings.json` `hooks.PreToolUse` for fleet-wide effect.

- **UPDATED** `.claude/rules/worktree-discipline.md` — "Composes with" section documents the armed coordination layer.

- **UPDATED** `.claude/rules/session-environment-policy.md` — References note explains why terminal-only code work is what makes the heartbeat trustworthy.

### Adopter wiring

The SessionStart hook (`sessionstart-context-aggregator.sh`) is already registered by `/setup` Step 8 — so the heartbeat + auto-/where are live on adoption with no extra step. To also get the write-time collision warn, register `cross-chat-collision-detect.sh` in committed `settings.json` `hooks.PreToolUse`:

```json
{ "matcher": "Write|Edit",
  "hooks": [{ "type": "command",
    "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/cross-chat-collision-detect.sh",
    "timeout": 5 }] }
```

### Verification (run on this template repo)

- `bash .claude/hooks/sessionstart-context-aggregator.sh --self-test` → ALL PASS (11/11)
- `bash .claude/skills/where/scripts/sweep-stale-worktrees.sh --self-test` → ALL PASS (9/9)

## 2026-05-24 — fix(hooks)+feat(setup): de-Nirvana-ise VPS probe + bundle obsidian-autopilot read-side into /setup

Origin: a 3-way fleet alignment (Nirvana ↔ BuyBox ↔ Agency-Main) ran on 2026-05-24 to lock the LLM-Wiki + Obsidian autopilot architecture (project repos = read+capture only; Agency-Main = central LLM-Wiki compiler). The architecture was unanimously agreed (Nirvana PR #200, BuyBox PR #928), and BuyBox then asked Nirvana to push the obsidian-autopilot read-side UP to the template so every future project inherits it by default (Nirvana PR #202). Pre-flight inventory showed 6 of 7 files already lived in the template at byte-identical sizes — so the actual remaining work was two surgical changes: a hook-side bug fix and a /setup wiring gap.

### Bug-1 fix — sessionstart-context-aggregator.sh VPS probe de-Nirvana-ised

`.claude/hooks/sessionstart-context-aggregator.sh` carried 5 hard-coded references to `nirvana-agent` (a Nirvana-only VPS ssh-config alias) in the pre-flight emit. Every project that ran the template-generated hook reported `nirvana-vps=n/a` or attempted to probe a Nirvana host — that's noise for non-Nirvana projects.

- **UPDATED** `.claude/hooks/sessionstart-context-aggregator.sh` — VPS probe is now opt-in per project. Reads `preflight_vps_host: <ssh-alias>` from `.claude/obsidian-second-brain.local.md` (gitignored, per-machine). Unset = silent skip, `vps=n/a` in the one-liner. Output column renamed from `nirvana-vps=` to `vps=` (generic). Smoke-passed: hook emits clean JSON with `vps=n/a` on machines without the config — no behaviour regression on Nirvana (Nirvana adds `preflight_vps_host: nirvana-agent` to its own `.local.md`).

### Feature — /setup now bundles the obsidian-autopilot read-side

The previous `/update-latest` (step 5-PRE) invoked `bootstrap-obsidian.sh` for existing projects, but `/setup` (the first-time recipe for a fresh repo) had ZERO references to bootstrap or to the SessionStart context-aggregator hook. So a fresh project arrived with all the files but none of the wiring — until it later ran `/update-latest`. Closes the gap.

- **UPDATED** `.claude/commands/setup.md` — appended new Step 8 "Obsidian autopilot read-side wiring (mandatory)" with 4 sub-steps:
  - 8.1 — Run `bootstrap-obsidian.sh` (idempotent; auto-detects per-repo slug from folder name).
  - 8.2 — Register `sessionstart-context-aggregator.sh` in `.claude/settings.local.json` SessionStart hooks block (gitignored machine-local file, written via Python JSON-merge — the only correct place because writing to the shared `settings.json` is agent-blocked).
  - 8.3 — Stamp `.claude/template-source.md` with current template-version pin + a Held-Files Ledger section stub (greppable header so future Claude sessions can find it).
  - 8.4 — Hermetic smoke-test of the SessionStart hook output. FAIL = surface to operator, setup is INCOMPLETE.

### Verification recipe (run on a fresh repo created from this template + /setup'd)

| Probe | Expected |
|---|---|
| `ls .claude/scripts/bootstrap-obsidian.sh` | present + executable |
| `ls .claude/obsidian-second-brain.example.md` | present |
| `ls .claude/obsidian-second-brain.local.md` | present (generated by bootstrap) |
| `ls .claude/hooks/sessionstart-context-aggregator.sh` | present |
| `python3 -c "import json; s=json.load(open('.claude/settings.local.json')); print(any('sessionstart-context-aggregator' in h.get('command','') for h in s['hooks']['SessionStart'][0]['hooks']))"` | `True` |
| `grep -c "Held-Files Ledger" .claude/template-source.md` | `≥1` |
| Open a fresh session — visible repo-state briefing + 📓 vault feed at top? | YES |

All 7 must pass on a fresh repo for the bundle to be considered "set up perfectly". Anything less is a regression — revert the affected setup step.

### Cross-references (the 3-way fleet alignment chain)

- BuyBox PR #927 — Nirvana parity report to BuyBox
- BuyBox PR #928 — BuyBox response (architecture agreement)
- BuyBox PR #930 — BuyBox 4-step mechanical alignment
- Nirvana PR #200 — Nirvana reply locking architecture + correcting `bin/vault-sync.sh` location
- Nirvana PR #202 — BuyBox → Nirvana template-push request (this changelog entry's origin)
- Nirvana template-push PR — this commit
- Agency-Main PR #66 — central compiler verification + final fleet decision (still in-flight)

---

## 2026-05-23 — accumulated hook + hookify + command + doctrine updates

Forward sync of 23 TEMPLATE-MANAGED files that drifted since the 2026-05-22 newearth-security sync. The changes accumulated across several work streams (accounting Phase 1 + invoicing reframe, n8n-backup-freeze recovery, CC-2.0 vs n8n audit, make-git-invisible plan, obsidian-vault-autopilot skill, Phase 4.7 V1.1 master-continuation pattern). No new skills introduced — refinements to existing infrastructure.

- **UPDATED** `.claude/HOOKS-AND-RULES-STANDARDIZATION.md` — refreshed substitution-pattern doctrine
- **UPDATED** `.claude/agents/council/reframer.md` — council Reframer agent definition
- **UPDATED** `.claude/commands/{daily-plan,design-review,present,prime,push-to-template,reflect,setup}.md` — command refinements (subset of doctrine evolution); `push-to-template.md` retains project-specific tokens INTENTIONALLY as the substitution registry
- **UPDATED** `.claude/hookify.{auto-council-on-plan,auto-review-on-execute,github-file-contents,mcp-server-guard,n8n-use-essentials,n8n-workflow-delete-block,subagent-cost-guard}.local.md` — hookify rule updates
- **ADDED** `.claude/hookify.roadmap-freshness.local.md` — new hookify rule (was missing from template)
- **UPDATED** `.claude/hooks/{auto-sync-artifacts,commit-guardian,roadmap-writeback-verifier,session-summarizer,sessionstart-context-aggregator,vault-capture}.sh` — hook script updates including the new `emit_newearth_security_toggle_section` function in `sessionstart-context-aggregator.sh` (banner-on-disabled, silent-on-enabled, surfaces is-enabled.sh stderr on indeterminate exit)

**Generalisation pass**: 4 files received in-template substitutions for project-specific tokens — `daily-plan.md` (journal-distribution targets templated to `{{client-N-slug}}` / `{{org}}` / `{{client-N-repo}}`), `reflect.md` (example tool matcher templated to `mcp__supabase-{{project}}__apply_migration`), `setup.md` (n8n-mcp-honeybird example genericised to `n8n-mcp-myinstance`), `hookify.github-file-contents.local.md` (repo-mapping list templated to `{{repo-N}}` / `{{user_home}}` / `{{path-to-clone-N}}`). The `HOOKS-AND-RULES-STANDARDIZATION.md` and `push-to-template.md` doctrine files intentionally retain project-specific tokens as illustrative "before" examples.

**Failure precedent prevented**: stale template state diverging silently from the parent project as accumulated micro-updates land on `main` without per-update sync. Forward-sync cadence keeps adopter projects on the current doctrine.

Synced from: NewEarth AI Agency-Main @ commit 76bb864

## 2026-05-22 — `/newearth-security` suite (V1.0 + V1.1)

The confidence-calibrated security-review skill suite, matured through two ship waves and a 9-agent code-council. Adopting repos get a stack-aware security reviewer (Supabase/n8n/Next.js/Edge Functions) that only reports HIGH-confidence findings with confirmed attacker-controlled input, gated by a 3-layer toggle (env var > filesystem flag > settings.local.json) so it can be muted per-session, per-repo, or per-machine without disabling the companion security skills.

- **ADDED** `.claude/skills/newearth-security/` — conductor SKILL.md + 9 references (security-categories, prompt-injection-defence, owasp-standards [OWASP LLM Top 10 2025], stride-dread, severity-modes, dependency-health, supabase-security, n8n-security, toggle) + `scripts/is-enabled.sh` (3-layer toggle, jq-parsed, exit-code 0/1/2/3 contract) + `scripts/self-test.sh` (20 cases, all pass as child processes) + evals.json
- **UPDATED** `.claude/skills/security-threat-model/SKILL.md` — refactored from a 46-line stub to a substantive STRIDE+DREAD + OWASP LLM Top 10 threat-modelling skill that references the shared newearth-security reference library
- **UPDATED** `.claude/skills/security-scan-agentshield/SKILL.md` + `LOCAL-ADAPTATIONS.md` — fixed a CRITICAL silent-exit-0 bug (the `if ! cmd; then rc=$?` exit-code mask) caught by code-council; the Guard 2 path now fails loud on a scan error

**Failure precedent prevented**: a confidence-calibrated security skill that fires inappropriately is friction, not protection (hence the toggle); and a tool wrapper that captures `$?` after `if ! cmd` silently reports scan failures as clean (shell-portability.md rule 1) — both addressed here.

**Toggle env var**: `NEWEARTH_SECURITY_ENABLED` (kept branded — this template is NewEarth's; adopting NewEarth entities share the name).

Synced from: NewEarth AI Agency @ 4639bb0 (PR #51 V1.0 + PR #53 V1.1). 7-day soak gate (council Amendment 13) waived by operator 2026-05-22.

## 2026-05-22 — obsidian-wiki Phase 3: `llm-wiki` + `cross-linker` + `tag-taxonomy`

Phase 3 of the obsidian-wiki (`ar9av/obsidian-wiki`, 1.4k★, MIT) selective cherry-pick programme. Audited all 36 upstream skills; absorbed the 3 highest-leverage, queued 5, skipped 27. Same verbatim-upstream + per-project-LOCAL-ADAPTATIONS pattern as the 2026-05-21 `claude-history-ingest` absorption — the 3 form a coherent set (the two operational skills reference `llm-wiki`'s shared protocols).

- **ADDED** `.claude/skills/llm-wiki/` — keystone skill: Karpathy LLM-Wiki three-layer pattern (raw sources → wiki → schema) + the shared protocols (Config Resolution, Retrieval Primitives, Link Format) the other two reference. `SKILL.md` + `references/karpathy-pattern.md` verbatim upstream (pinned commit `6f20faa`); `LOCAL-ADAPTATIONS.md` carries the per-project overrides + a first-install preamble.
- **ADDED** `.claude/skills/cross-linker/` — write-heavy: auto-discovers + inserts missing `[[wikilinks]]` between wiki pages. Fills the "wikilinks are the agent retrieval path" gap.
- **ADDED** `.claude/skills/tag-taxonomy/` — write-heavy: controlled-vocabulary tag enforcement across wiki pages. Fills the tag-hygiene gap.

**Safety (from a 6-agent code-council, ADVISORY)**: the two write-heavy skills carry a 4-agent-consensus finding — their quarantine write-boundary is advisory prose in the LOCAL-ADAPTATIONS sidecar that the verbatim `SKILL.md` never references (the upstream config walk-up could misroute writes onto curated notes). Each LOCAL-ADAPTATIONS therefore ships an **UNENFORCED-CONTROL banner** (install-only until the vault root is pinned + a path-guard hook exists) + a **first-run dry-run gate**. Also applied: pinned upstream SHA (no bare-`main` re-pull), disabled the unused `${QMD_CLI:-qmd}` shell block (arbitrary-binary surface), corrected the `tag-taxonomy` dependency (Config Resolution Protocol only).

**Per-project install**: replace the vault root / quarantine subpath in each `LOCAL-ADAPTATIONS.md` (the recommended quarantine is a PARA `Fleeting/wiki-ingest/` subpath) and remove the first-install preamble. Do NOT run the write-heavy skills until their boundary is pinned.

Synced from: NewEarth AI Agency (obsidian-wiki Phase 3, PR #56 @ 4a5cd17)

---

## 2026-05-22 — ECC selective absorptions: `security-scan-agentshield` LOCAL-ADAPTATIONS + new `hook-profile-gating` rule

Phase 2 of an ECC (`affaan-m/everything-claude-code`, 188k★ Anthropic hackathon winner, MIT-licensed) selective cherry-pick programme. Two artefacts absorbed; three other candidates deferred to keep the absorption surface tight and the collision-audit honest.

- **ADDED** `.claude/skills/security-scan-agentshield/LOCAL-ADAPTATIONS.md` — the sibling overrides file for the previously-absorbed `security-scan-agentshield` skill (a verbatim wrapper of ECC's `skills/security-scan/`, which wraps `ecc-agentshield@1.4.0` npm — 1282 tests / 102 rules across CLAUDE.md prompt injection, settings.json permission audit, mcp.json supply-chain, hook command injection). Template-clean (per-project allowlist + trigger-wiring decisions documented as deferred). The SKILL.md itself was added in an earlier sync; this PR completes the install with the missing LOCAL-ADAPTATIONS sibling so future projects pulling via `/update-latest` get the full diff-able-update contract.
- **ADDED** `.claude/rules/hook-profile-gating.md` — codifies a per-hook kill-switch convention generalised from ECC's hook scripts. Env-var naming: `HOOK_<UPPER_STEM>` (no `_DISABLED` suffix — matches the `AUTOVIBE_AUTOFIRE` feature-flag shape exactly). Accepted disable values: `{0, false, no, off, disabled}` — 5 case-insensitive values, exact match with autovibe. **Mandatory safety-hook exclusion list** (6 entries — `bash-guardian`, `sql-guardian`, `supabase-migration-guard`, `commit-guardian`, `worktree-guard`, `dashboard-review-gate` — NEVER candidates for the convention). **Mandatory session-start visibility**: every retrofitted hook MUST emit a one-line stderr warning when disabled, so a forgotten `.zshrc` export does not silently degrade the session.
- **UPDATED** `.claude/hooks/framing-audit-activation.sh` — the first worked retrofit of the convention. 14-line pre-PYCODE block at the top of the bash script that reads `HOOK_FRAMING_AUDIT_ACTIVATION`, lowercases the value, matches against the accepted disable list, and either early-returns with a visible stderr warning or falls through to the existing python invocation. Smoke-validated across all 5 disable variants + 5 enable variants. Self-test still ALL PASS (15/15).

**Validation**: a 5-agent strategic council deliberated the plan v1 → v2 (Capability Scout caught that the security-scan-agentshield skill had been absorbed in a prior session — the plan amended from "verbatim install" to "shore-up only"; Reliability Engineer surfaced two NSF flags that drove the safety-hook exclusion list + session-start visibility mandate). A 4-agent code-council then reviewed the staged diff and produced ADVISORY with 3 IMPORTANT findings (audit memo doc-bug on env-var naming, `dashboard-review-gate.sh` missing from the safety-exclusion list, `disable` synonym divergence from autovibe precedent). All three applied before merge.

**Deferred** (operator decisions per the audit memo's decommission triggers): a trigger schedule for `security-scan-agentshield` (graveyard-risk without one; recommended path is a weekly `/daily-plan` cadence), a sentinel smoke fixture, ECC's `code-reviewer` pre-report gate language (overlaps existing code-council Step 3.5 validator), ECC's `architect` 4-step structure (overlaps code-council architect lens), ECC's `planner` independently-mergeable-phases discipline (already in autovibe).

**Cherry-pick discipline**: per the parent continuation policy, ≤3 absorptions per session, collision-audit before any `.claude/skills/` write. This sync ships 2 (and the audit memo records why 3 candidates were deferred).

**License attribution**: ECC monorepo is MIT — © 2026 Affaan Mustafa. The `ecc-agentshield` npm package is published from `affaan-m/agentshield`; verify the package's license metadata at install time.

Synced from: NewEarth AI Agency @ 884a1b1

---

## 2026-05-21 — `claude-history-ingest` skill added

Imported `claude-history-ingest` skill from upstream `ar9av/obsidian-wiki` (1,421★, MIT-licensed, Karpathy LLM-Wiki pattern). This is a **pure file-transform** skill — distils Claude Code session history (`~/.claude/projects/*/<session-uuid>.jsonl` + memory files) into structured Obsidian wiki pages with provenance markers, lifecycle frontmatter, and manifest-based delta tracking. No external LLM call required; the in-session Claude is the execution engine.

- **ADDED** `.claude/skills/claude-history-ingest/SKILL.md` — verbatim from upstream for diff-able updates against future upstream changes
- **ADDED** `.claude/skills/claude-history-ingest/references/claude-data-format.md` — verbatim upstream format spec for `~/.claude/projects/` JSONL + memory file structure
- **ADDED** `.claude/skills/claude-history-ingest/LOCAL-ADAPTATIONS.md` — per-project override template covering: vault quarantine subpath (PARA / Johnny Decimal / custom), sensitive-info skip extension (composes with `operational-guardrails.md`), composition with existing context-load hooks (`sessionstart-context-aggregator.sh`, `vault-capture.sh`, `session-summarizer.sh`)
- **UPDATED** `.claude/template-source.md` — added the skill row to the TEMPLATE-MANAGED Skills table; bumped `version` + `last_sync` to `2026-05-21-claude-history-ingest-skill`

**Validation precedent**: smoke-passed end-to-end with full schema conformance (6 frontmatter fields, summary ≤200 chars, 11 provenance markers across 30-line distilled page, sensitive-info skip verified, idempotent append mode confirmed). See the source project's smoke memo for details.

**Failure precedent prevented**: prior to this skill, Claude Code session history accumulated in `~/.claude/projects/*/` as unstructured JSONL with no automated path into a queryable knowledge base. Wiki pages got built ad-hoc, schemas drifted, sensitive-info handling was inconsistent. This skill standardises the distillation pattern with manifest-based idempotence and inline provenance markers.

**Per-project install**: copy SKILL.md + references/ verbatim; edit LOCAL-ADAPTATIONS.md to set the vault quarantine subpath (recommended: PARA `05 - Fleeting/wiki-ingest/`) before first invocation. See the LOCAL-ADAPTATIONS.md per-project install checklist.

Synced from: NewEarth AI Agency @ 87ad819

---

## 2026-05-23 — Obsidian autopilot: one-command setup via /update-latest

- New 📄 `.claude/scripts/bootstrap-obsidian.sh` — idempotent obsidian setup script. Auto-detects the per-repo slug from folder name (`Nirvana-Freight` → `nirvana-freight`, `BuyBox-AI` → `buybox`, `Agency-Main` → no slug / full vault). Creates `.claude/obsidian-second-brain.local.md` with three shared agency values pre-filled. Verifies macOS Keychain entry. Smoke-tests the SessionStart vault block end-to-end. Safe to re-run — idempotent.
- 📓 `/update-latest` now invokes the bootstrap script automatically in Step 5-PRE. **Net effect**: a brand-new repo gains FULL obsidian autopilot (read side) by running `/update-latest` once. No copy-paste, no manual edit of `.local.md`, no manual slug selection. Operator only intervenes if the macOS Keychain entry is missing on this Mac (script prints exact provisioning command + exits non-zero).
- Replaces the prior recipe of "copy `.example.md` to `.local.md` and edit four values" with zero-touch setup. The example file stays in the template as a fallback / manual-setup reference.

## 2026-05-23 — Obsidian autopilot per-repo scope filter + example config

- `sessionstart-context-aggregator.sh emit_vault_section` is now slug-parameterised. The hook reads an optional `vault_scope_slug:` field from `.claude/obsidian-second-brain.local.md`; when present, the SessionStart vault block is filtered to rows whose `source_path` contains the slug (case-insensitive). When absent, the block returns the full agency vault (Agency-Main parent-repo behaviour). The section header reflects the scope: "📓 Recent vault activity — &lt;slug&gt;-scoped" when filtered, plain otherwise.
- New `.claude/obsidian-second-brain.example.md` template-managed file — operators copy to `.local.md`, fill in vault_path + supabase_url + keychain_item + their per-repo scope slug. Includes the three-leg setup recipe (Stop chain wiring → memory distillation → MEMORY.md slim-down) so a new repo can self-configure to full parity.
- Origin: 2026-05-23 BuyBox Leg 2 ship. The operator directive was "BuyBox SessionStart must read ONLY BuyBox-derived vault rows" — each downstream repo benefits from the same per-repo discipline so cross-repo sessions don't drown each other's vault blocks. Nirvana Freight + Honeybird operator repo are the next adopters.
- Re-syncs via /update-latest are safe: existing per-machine `.local.md` files without the new `vault_scope_slug` field still work (the hook falls back to the unfiltered behaviour). Repos that want scope filtering add the one line.

## 2026-05-21 — worktree-guard escape-hatch flag renamed to ALLOW_PARALLEL_WORKTREE

- The per-command escape-hatch env flag is now the brand-neutral `ALLOW_PARALLEL_WORKTREE` (was the BuyBox-branded name). Fleet-consistent — one flag everywhere; re-syncs no longer leak branding. Repos that already adopted the branded flag: re-run /update-latest to converge (a repo that independently chose ALLOW_PARALLEL_WORKTREE is already aligned — no-op).


## 2026-05-21 — worktree-guard fix: block only at command boundary (not phrase mentions)

- The enforcement detector matched the worktree-add phrase ANYWHERE in a command, so a commit message / grep / echo that merely mentioned it got blocked (bit a downstream repo's own commit). Now matches only at a command boundary, optionally preceded by env-var prefixes (the escape hatch). 3 new self-test regression cases; 9/9 pass.


## 2026-05-21 — Single-folder enforcement: cold-open flip + fail-closed worktree-guard

- `worktree-guard.sh` upgraded from passive reminder to **fail-closed enforcement**: a bare `git worktree add` is denied (`permissionDecision: deny`); genuine parallel work opts in per-command with `BUYBOX_PARALLEL_WORKTREE=1 git worktree add ...` (flag in the command string, not shell env). Self-test 6/6 (bare/prefixed=deny, sanctioned/non-git/switch/remove=allow).
- `master-continuation-prompt` + `prompt-forge` cold-open Step 0 flipped from "fresh worktree" to "feature branch in the one folder" (`git switch -c <branch> origin/main`, stash-first for dirty WIP). Verification gate now BANS mandating a worktree.
- Fleet enforcement requires registering the hook in committed `.claude/settings.json` PreToolUse (Bash matcher).

## 2026-05-21 — New rule: check for a contradicting standing decision before mandating a workflow

Before encoding a workflow-DEFAULT into durable infrastructure (a skill's setup block, a rule file, the template, a hook), grep `continuations/` + `.claude/rules/` for a standing operator decision or pending continuation the new default would CONTRADICT. Durable infra propagates to every future session AND every future project, so a default that fights a standing-but-unexecuted decision hardens the wrong behaviour into the substrate.

- **NEW** `.claude/rules/check-standing-decision-before-mandating-workflow.md` — the 30-second grep check + reconcile-don't-propagate discipline. Contradiction-mirror of the existing `dont-conflate-inflight-programme.md` (subsumption claims) + `doctrine-currency-check.md` (is cited doctrine current). Generalised — no project-specific commit hashes or PR numbers; the failure precedent is described by mechanism (a worktree-mandating default shipped while a single-folder decision sat pending) rather than instance.
- **UPDATED** `.claude/template-source.md` — registered the new rule in the TEMPLATE-MANAGED table.

---
## 2026-05-21 — Cold-Open Session Start: mandatory worktree-setup block in continuation + forge outputs

Every continuation prompt and every forged prompt that touches a git repo must now carry an explicit Step 0 fresh-worktree-setup block, so a cold-open chat on ANY machine reaches the verification step with zero questions back. Prevents the failure where a handoff documents WHAT to do but not WHERE to set up — leaving the cold-open chat to guess and land in a cloud-synced (`.git`-corrupting) or temp (`git`-auto-locking) directory, or the dirty primary clone.

- **UPDATED** `.claude/skills/master-continuation-prompt/SKILL.md` — the 14-section template's "HOW TO USE THIS PROMPT" block becomes "HOW TO USE — COLD-OPEN SESSION START" with a concrete Step 0 (git fetch + git worktree add `<safe-dir>/{slug}` origin/main + git switch -c + node_modules symlink if applicable + git log -3 sanity check) + Steps 1-4 (read / verify / plan / execute). New Step 3 Quality-Validation Must-Pass gate rejects any continuation whose setup block lacks concrete commands or leaves placeholders unresolved.
- **UPDATED** `.claude/skills/prompt-forge/SKILL.md` — new Component 10 "Cold-Open Session Start" after Component 9 Context Bridge. REQUIRED when execution_scale touches a git repo; omitted for read-only research prompts. Same Step 0 worktree discipline + banned-path rules (cloud-synced dirs corrupt `.git`; temp dirs auto-lock; use a real non-synced working directory).

Both generalised per template convention — no project-specific rule-file names, memory-entry names, or commit hashes; banned-path rules phrased generically rather than naming a project's specific worktree-discipline file.

Composes with: the existing Step 1G Cold-Read Safety Gate (which already forbids session-scoped paths) — Step 0 is the positive counterpart that tells the cold-open chat the correct path to USE, where 1G forbids the wrong ones.

---
## 2026-05-20 — Master-Continuation-Prompt: Step 1H Doctrine-Currency Check

Adds a new MANDATORY gate to the continuation-authoring flow that runs after Step 1G Cold-Read Safety, before emit. It is the executable form of `.claude/rules/doctrine-currency-check.md` (which has been passive since authoring). The gate fires for every doctrine reference in a continuation that supports a NEGATIVE recommendation (a problem still exists, a trap is still live, a feature is still missing) and forces a triple-cite against current code BEFORE emit. If the doctrine and current code disagree, the continuation MUST either restate against current reality + queue a separate doctrine-update PR, OR halt and surface the disagreement to the operator. Silent emit with a stale claim is BANNED.

- **UPDATED** `.claude/skills/master-continuation-prompt/SKILL.md` — new Step 1H section inserted between Step 1G Cold-Read Safety Gate and Step 2 Generate; new §14 verification-block checklist line under "Doctrine-Currency (Step 1H — author self-certifies before emit; cold session sees this line)" parallel to the existing Cold-Read Safety line. Failure precedent embedded in-skill (generalised — date + description, no project-specific commit hashes per template convention).

Composes with:
- Step 1D.5 Framing Audit — audits the framing's correctness
- Step 1G Cold-Read Safety Gate — audits cold-read completeness
- Step 1H Doctrine-Currency Check — audits citation freshness against current code (NEW)

Origin: a 2026-05-20 continuation revision in a downstream repo propagated a stale doctrine claim (a code cast described as "still live" had been removed nearly a month earlier). The revision shipped, then was corrected in a follow-up commit once a parallel chat reading the actual code surfaced the staleness; a third commit was needed to mark the rule file's described trap section HISTORICAL. All three commits would have been avoided if a doctrine-currency gate had run at continuation authoring time. The skill change converts the failure mode into a structural impossibility — `doctrine-currency-check.md` named the discipline but had no enforcing step; this step is that enforcement, propagated to every repo running `/update-latest`.

Verification: project-side commit `0be021ba` (the source of this change) lands the same content in BuyBox-AI and has been deployed; template version is the generalised mirror (no project-specific hashes / repo names in the precedent text — same date + same lesson + same scenario shape).

---
## 2026-05-19 — Goal-Ledger fix-forward (post-council factory-install completion)

Follow-up to the Goal-Ledger Build Programme propagation (commit `a757a57`). A
post-propagation `/council --extended` deliberation (7 agents, 7/7 FIX-FORWARD)
surfaced three confirmed propagation gaps + two latent edge cases the in-session
work missed. Operator expanded scope: ensure any repo running `/update-latest`
gets a factory-installed integration story across goal-ledger ↔ autovibe ↔
autofire/newvibe ↔ synthesis programme ↔ `/define-destination`.

- **UPDATED** `.claude/skills/master-continuation-prompt/SKILL.md` — §5A optional `goal_id` stamp paragraph + §5C reaper handshake (the CREATOR side of the goal-ledger). Without this, the template's master-continuation never stamps `goal_id`, and a receiving repo's Gate 8 always reads `linkage_status:"no-id"`. Surgical merge — preserved template's existing Step 1G Cold-Read Safety Gate and other template-side additions.
- **UPDATED** `.claude/commands/setup.md` — new Step 7.7.8 (seed `.claude/goals/` + README at setup time, no entries) + new Step 7.7.9 (factory-install integration verification — five verification commands, one per integration surface: `/define-destination` Step 7.5, autovibe `state.sh write goal_id`, newvibe-dispatch-lib Gate 8, Stage 4 roadmap-addition gate, master-continuation §5A/§5C) + new Step 7.7.10 (newvibe autofire placeholder configuration — operator-gated opt-in walk-through).
- **UPDATED** `.claude/skills/autovibe/references/newvibe-integration-guide.md` — new §7.0 "Replace the three dispatch constants BEFORE arming" — names `NV_N8N_HOST` / `NV_WEBHOOK_PATH` / `NV_WORKFLOW_ID` at lines 49-51 of dispatch-lib.sh with example values, verification command, and the loud-but-silent-in-aggregate failure mode if skipped.
- **UPDATED** `.claude/skills/autovibe/scripts/newvibe-dispatch-lib.sh` — two edge-case patches per Edge Case Finder (council 2026-05-19): (1) `nv_read_goal_id` now scopes its search to the HTML-comment frontmatter region (above the first Markdown `# ` heading) so a documentation example like `<!-- goal_id: example -->` in body prose is NOT mis-read as a real ledger link (Scenario 7); (2) new Gate L1 at the top of `nv_dispatch_live` — pre-checks for any remaining `{{...}}` placeholder in the three dispatch constants and fail-fast-loud with a human-readable resolution message pointing to integration-guide §7.0 (Scenario 1 — the silent retry-loop on unfilled placeholders).

Verification: 30/30 self-tests PASS post-patch (no regressions on the prior 30 cases). The factory-install integration table in setup.md step 7.7.9 reads directly off-disk via `grep -q` — verifiable mechanically at every /setup run.

Source: First-Principles Workshop. Council session: `council/sessions/2026-05-19-...` (workshop-side). Empirical fact-check ran before the council deliberated — three gaps confirmed pre-council; two more surfaced by Edge Case Finder during deliberation.

---


## 2026-05-19 — SessionStart hook now surfaces shared-vault context (Obsidian autopilot, read half)

The SessionStart context aggregator gains `emit_vault_section()` — every session in any
template-derived repo now opens with the 5 most-recently-updated shared-vault notes, the
read half of the Obsidian autopilot (the write half is `vault-sync.sh`). This is what makes
a child repo "Obsidian-enabled": a single shared parent vault, surfaced into every repo's
session start, with no per-repo vault and no per-repo sync.

- **UPDATED** `.claude/hooks/sessionstart-context-aggregator.sh` — added `emit_vault_section()`
  (defined after `emit_preflight_section`, invoked in `build_briefing`). **Config-driven**:
  the knowledge-database URL and the Keychain item holding the read credential are read from
  the per-machine, gitignored `.claude/obsidian-second-brain.local.md` — so the hook file
  itself carries no project-specific reference and works for any adopter. Silent-skips
  (degrades, never blocks the briefing) when no obsidian config exists, the config lacks
  `supabase_url:`/`keychain_item:`, the Keychain credential is absent, or curl/jq fails;
  3-second budget. `bash -n` clean; 3/3 functional tests pass (live DB read + 2 silent-skip
  paths).

**Receive-side setup**: a repo gets the vault section by running `/update-latest` (pulls this
hook) PLUS having a `.claude/obsidian-second-brain.local.md` with `supabase_url:` +
`keychain_item:` and the matching credential in the macOS Keychain. Until that per-machine
config exists the hook silently runs without the section — no breakage.

Synced from: NewEarth AI Agency @ d107673 (origin of `emit_vault_section`; generalised to
config-driven for the template)

---

## 2026-05-19 — Goal-Ledger Build Programme COMPLETE (Sessions 2 + 3 + 4 propagated; hold lifted by BuyBox-AI proof)

The four-session Goal-Ledger Build Programme (workshop spec/12) is complete. This entry propagates Sessions 2 + 3 (built workshop-only by deliberate hold) + Session 4 (newvibe Gate 8 + recovery runbook + artefact-grounding audit). The propagation hold is **lifted by the BuyBox-AI proving record** — a real autonomous chain ran end-to-end through the ledger at 19:22:19Z (Gate 8 fired with `linkage_status:"active"`, autofire-dispatched landed 1 second later). Proving record: `council/proving/2026-05-19-goal-ledger-buybox-full-chain.md` (workshop) — the load-bearing artefact for this push.

- **NEW** `.claude/skills/_shared/goals.sh` — the goal-ledger helper. 12 subcommands (`new`, `read`, `set`, `set-list`, `achieve`, `abandon`, `reap`, `list`, `lineage`, `check-collision`, `spawn-check`, `roadmap-gate`). FROZEN §4 11-key schema. mkdir-lock + jq-tmp-mv concurrency. `declared_touches` overlap = PRIMARY collision gate (deterministic); semantic contradiction = SECOND layer; BLOCK > WARN. Stage 4 `roadmap-gate` emitter composes `/reduce-to-first-principles` → `/map-feedback-loops` (operator hand-edits to ROADMAP are EXEMPT). 30/30 self-tests at workshop.
- **NEW** `.claude/goals/README.md` — schema doc + helper subcommand reference + integration-point map.
- **NEW** `.claude/skills/_shared/roadmap-addition-gate.md` — Stage 4 gate doctrine (full procedure + rationale).
- **NEW** `.claude/skills/autovibe/references/goal-ledger-recovery-runbook.md` — operator paths for stuck ledger lock (exit 5) / corrupt record salvage (exit 6) / phantom-active recovery + exit-code cheat sheet. 104 lines.
- **UPDATED** `.claude/skills/autovibe/scripts/newvibe-dispatch-lib.sh` — Gate 8 added (the goal-ledger read step inside `nv_autofire`, ADVISORY ONLY, never blocks dispatch). Two new helpers: `nv_read_goal_id` (extracts goal_id from continuation frontmatter) + `nv_goal_status` (classifies the goal_id against the local ledger; 8-output enum). Self-test extended 17 → 30 cases incl. all 8 status branches (active/achieved/abandoned/paused/missing/corrupt/no-helper/no-id) and integration-into-nv_autofire.

Verification: dedicated `/code-council --thorough` (9 agents) on the Gate 8 hook-edit diff returned BLOCKING (2 CRITICAL + 4 IMPORTANT with cross-lens consensus) → all 6 fixed in-session → PASS. Record: `council/code-reviews/2026-05-19-goal-ledger-session-4-newvibe-hooks.md` (workshop). `/audit-artefact-grounding` on the ledger as a standing artefact returned `keep` at HIGH confidence — all 6 axes pass, no composition contradictions, propagation_flag `upstream`. Record: `council/audits/2026-05-19-goal-ledger-system-grounding.md` (workshop).

Source: First-Principles Workshop. Programme spec: `specs/12_GOAL_LEDGER_BUILD_PROGRAMME.md` (workshop). Plan v3 / final continuation: `GOAL-FEATURE-INTEGRATION-PLAN-2026-05-19.md`.

---

## 2026-05-19 — Session-Coordination Layer (universal parallel-session safety)

- **NEW** `.claude/commands/where.md` + `.claude/skills/where/` — `/where`: one plain-English answer to "where is all my work?" across every repo. Live git-truth (no written registry, cannot lie), composes `verify-shipped`'s `walk-worktrees.sh` as single source of truth, net-new file-level collision detection keyed on worktree path (catches detached worktrees). Plus `sweep-stale-worktrees.sh` — a guarded janitor: removes a worktree ONLY if clean ∧ merged ∧ old ∧ owning-process-dead, with a disk-pressure preflight FIRST, dry-run default, and a hard-enforced snapshot-before-remove. Permanently fail-safe (removes nothing) until a project adds a PID-writer convention. Template-generic: no hard-coded repo paths — resolved via `.claude/where-repos.txt`, `WHERE_REPOS`, or current-repo fallback.
- **NEW** `.claude/skills/ship/scripts/rebase-conflict-guard.sh` — unattended HARD STOP (exit 3) on any code-file conflict during a rebase/merge (the `git checkout --ours/--theirs` reversed-semantics data-loss class). Docs-only conflicts may auto-resolve WITH logging. Fails closed if `git diff` errors mid-operation.
- **NEW** `.claude/skills/ship/scripts/verify-push-landed.sh` — `git ls-remote` SHA-match: "pushed" is asserted ONLY when the remote branch SHA equals local HEAD. Closes the "pushed reported when nothing pushed" class.
- **UPDATED** `.claude/skills/ship/SKILL.md` + `modes/quick.md` + `modes/pr.md` + `modes/hotfix.md` + `scripts/auto-rollback.sh` — the two guards above wired as active gates (passive doctrine → enforced step); auto-rollback no longer claims "pushed" on `git push` exit 0 alone, and distinguishes verify-exit-2 (unreachable) from exit-1 (SHA mismatch).
- **UPDATED** `.claude/skills/autovibe/SKILL.md` — one ALWAYS doctrine bullet: autovibe's composed `/ship` path carries the two unattended-safety gates; a "pushed/merged" claim without them is UNVERIFIED.
- **NEW** `.claude/rules/session-environment-policy.md` — desktop app = chat/plan/research only; terminal = all agentic code work. The single load-bearing assumption the layer relies on. Operator-reversible.
- **NEW** `.claude/rules/dont-conflate-inflight-programme.md` — read an in-flight programme's spec + run the two-question overlap test before claiming it subsumes a new need (same-noun ≠ same-need).
- **NEW** `.claude/hooks/parallel-chat-conflict-canary.sh` — generic worktree-collision SessionStart canary (warn-only, always exits 0). **Operator-installable, NOT auto-registered** — opt in by adding it to your settings SessionStart with `timeout: 5`.

Verification: code-council ran twice (R1 BLOCKING 4 CRITICAL → remediate → R2 BLOCKING 1 new regression CRITICAL + 1 IMPORTANT → remediate → PASS); every fix behaviourally verified (16 smokes incl. sweep `--apply` on a throwaway, verify-push exit-1, bash-3.2 no-hang). Source: First-Principles Workshop @ a14912f. Council: `council/sessions/2026-05-19-session-coordination-layer.md`.

---

## 2026-05-19 — NewVibe integration guide: two-layer routing model + agent hard-block reality

The two facts that cost a full setup session in an adopting repo (and required cross-repo help to recover) — now documented so no future adopter re-pays for them. Generalised; zero project-specific content.

- **UPDATED** `.claude/skills/autovibe/references/newvibe-integration-guide.md` §3 — new **Agent hard-block reality** callout: `settings.local.json` is normally agent-writable, but when the change *constitutes arming an autonomous self-dispatching loop* (autofire Stop hook + `NEWVIBE_AUTOFIRE_PERSIST` + arm flag) the auto-mode safety classifier hard-blocks it as a security-boundary action, and an in-conversation "yes" cannot clear it. Same for the `nv_detect_slug` slug-arm edit. NewVibe wiring is operator-hand work, never agent work — stated explicitly.
- **UPDATED** same guide §5 — corrected the misleading reference-REPO_MAP note (it listed org slugs as if wired; the shipped `nv_detect_slug` worked example contains only the BuyBox arms) + new **§5a two-layer routing model**: Layer 1 in-repo slug *detection* (fails first, silently, at `slug-undetected`) vs Layer 2 off-repo n8n slug *routing* (owner-only). Adopters now told both are separate, separately-owned steps and Layer 2 gates the first real fire.

**Failure precedent prevented**: 2026-05-19 — an adopting repo discovered NewVibe code was synced but non-operational; the two-layer model and the agent-hard-block reality were nowhere in the guide and had to be supplied from a second repo's live experience. Both are now in the template.

Synced from: Nirvana Freight

---

## 2026-05-19 — Autofire safety: runaway cap 5→2 + Strategic-Continuity refusal gate

Pairs with the persistent-autofire opt-in below — persist removes a brake, so two replacement brakes ship with it (any repo).

- **UPDATED** `.claude/skills/autovibe/scripts/newvibe-chain-guard.sh` — `MAX_CHAIN_DEPTH` 5 → **2** (conservative default: bound autonomous-chain blast radius — max 2 chained hops, then hard-refuse, fail-conservative on any parse error). Self-test ALL PASS 11/11: T3 expectation corrected to the cap-2 REFUSE case + new **T3b** cap-2 allow-boundary test (the suite is honest-green at the new cap, not silenced).
- **UPDATED** `.claude/skills/master-continuation-prompt/SKILL.md` — Step 1G gains **check 5, Strategic-Continuity refusal**: an autofire-chained continuation MUST name a live `ROADMAP.md` NOW/NEXT item OR an explicitly-still-relevant outstanding continuation; if neither is true, its next-action MUST be replaced with a hard `STOP — surface to operator`. "Figure out the next best thing" with no ROADMAP anchor is BANNED from emitting an auto-proceed instruction. The depth cap bounds *how many* hops; this bounds *whether each hop is still the right work*. §14 self-cert line updated.

**Why both**: a self-chaining loop with no human in it and no ROADMAP-alignment gate (autofire has none — it chains whatever canonical continuation exists) can wander off-roadmap indefinitely. The cap is the blunt blast-radius bound; the Strategic-Continuity gate is the precise drift-prevention. Conservative defaults — adopters can raise the cap deliberately.

Synced from: BuyBox-AI @ c262d3bf

---

## 2026-05-19 — Cold-Read Safety Gate + opt-in persistent autofire (both structural, any repo)

Two failure classes from a real session, fixed structurally so neither recurs in any repo.

- **UPDATED** `.claude/skills/master-continuation-prompt/SKILL.md` — new mandatory **Step 1G Cold-Read Safety Gate** (runs after authoring, before emit) + matching self-cert line in the §14 template. Four checks: (1) no session-scoped artefact paths (banned: `tool-results` / `.claude/projects/` / "this session" / "above" file refs — must be a repo-committed path OR a reproduce-from-scratch instruction); (2) no conversation-only load-bearing facts (locked verdicts cite committed files by path); (3) automation/loop state (autofire arm/persist/kill-switch/chain trigger) stated in-file when autofire-chained; (4) zero-memory-reader test. Composes with Step 1D.5 framing audit (that audits the *frame*; this audits *cold-read completeness*). Because autovibe Phase 4.7 invokes this skill, every autofire-chained hand-off now inherits the gate — both gap classes are prevented at authoring time, not caught later by luck.
- **UPDATED** `.claude/skills/autovibe/scripts/newvibe-dispatch-lib.sh` — opt-in `NEWVIBE_AUTOFIRE_PERSIST=1` guards the single-fire arm-flag consume. **Default OFF → zero behaviour change for every adopter** (single-fire remains the safe default); when explicitly set per-machine, the armed flag is not consumed on dispatch so the loop self-chains on every clean ship until the kill-switch or runaway-depth cap fires. Self-test ALL PASS 17/17.

**Failure precedent prevented**: 2026-05-19 — a hand-off referenced three captured data pools as "on disk in the session tool-results" (a path only the authoring session had) and omitted that the autonomous loop was single-fire (a fact only in chat). Both were caught by a post-hoc `/reduce-to-first-principles` audit; Step 1G moves the catch to before-emit, every time, no audit required. The persist guard closes the "loop silently dies after one leg" half.

**Pre-existing template-hygiene note (not introduced here)**: the autovibe dispatch lib's self-test T9 comment still carries a "BuyBox repo / Justin's Mac" example string — predates this change; flagged for a future client-agnostic pass, not fixed in this scoped sync.

Synced from: BuyBox-AI @ 792869ec + 65f73bea

---

## 2026-05-19 — NewVibe hardened: a misnamed continuation can no longer jam autofire (any repo, forever)

Root-cause fix for the class behind every "autofire isn't working" report this week. `nv_find_latest_continuation` blindly took the NEWEST `AUTOVIBE-*-MASTER.md` by mtime — so a single hand-misnamed continuation (no `-HHMM-` field) permanently *starved* a perfectly valid older one, and every autofire skipped at the verifier. BuyBox lost 44 consecutive autofires to exactly this on 2026-05-19 while a valid continuation sat beside it, ignored.

- **UPDATED** `.claude/skills/autovibe/scripts/newvibe-dispatch-lib.sh` — `nv_find_latest_continuation` now walks newest→older and returns the first **canonically-named** master (case-glob mirroring `CANONICAL_RE`'s date/time shape; locale-independent pure shell, no regex tool — cannot recur the §-locale class). A structurally-misnamed continuation is now *harmless*: skipped, never selected. New regression test **T13** locks it (a newer-malformed file must not starve an older-canonical one). Self-test pins `LC_ALL=C`.
- **UPDATED** `.claude/skills/autovibe/scripts/newvibe-chain-guard.sh` + `.claude/skills/autovibe/scripts/newvibe-dryrun-matrix.sh` — self-tests / matrix now pin `LC_ALL=C` so the whole NewVibe suite runs in the hooks' real non-interactive environment. An ambient UTF-8 locale previously produced false-green suites — that is exactly what hid the verifier locale bug for days.

**Failure precedent prevented**: 2026-05-19 — BuyBox autofire armed and firing 44× in minutes, every attempt `verifier-exit-3`, because a chat hand-wrote `AUTOVIBE-2026-05-19-arv-next-wave-remainder-MASTER.md` (no time field) and the selector kept grabbing it instead of the valid `…-0012-justin-buybox-ai-MASTER.md` right beside it. With this fix the malformed file is ignored and the valid one is found — in every repo, automatically, via `/update-latest`. Combined with the V1-doc fix and the verifier locale fix (both earlier today), the three failure classes that plagued NewVibe this week are now structurally closed.

Synced from: NewEarth AI Agency @ c8344a9

---

## 2026-05-19 — define-destination v1.1: the `/goal` completion-condition emitter

`define-destination` gains a Step 7.5 that turns an authored destination into a ready-to-paste Claude Code `/goal` completion condition — derived from the nearest **unmet artefact-checkable** milestone in Element 5's backward chain (NOT Element 2, which is often a real-world metric no single session can demonstrate), declining honestly when no milestone is artefact-checkable, never fabricating a check. The `/goal` evaluator reads only conversation-surfaced text and cannot run tools, so the emitted condition must name a concrete executable check the working session runs and surfaces — closing the `/goal`-evaluator-false-positive failure mode at the emit point.

- **UPDATED** `.claude/skills/define-destination/SKILL.md` (v1.0 → v1.1) — new Step 7.5 (select nearest unmet milestone + empty-chain & order-sanity guards; artefact-checkable classification with a runtime-dependent borderline rule + worked examples; 7.5.2b decline-list computation; named-executable-check requirement; DRAFT paste-string marker) + a `goal_completion_condition` output-schema block + Test 11 + Verification-Gate row + halt-path note.
- **UPDATED** `.claude/skills/define-destination/evals/evals.json` — `behaviour-010` (artefact-checkable branch) + `behaviour-010b` (honest-decline branch).

Hardened by a 6-agent `/code-council` (ADVISORY → all 6 confirmed IMPORTANT findings remediated before push). `DESTINATION.md` itself remains per-project content — never templatised; only the skill propagates.

Synced from: First Principles Systems Thinker (Goal-Ledger Build Programme Session 1, `8402cb6`)

## 2026-05-19 — NewVibe verifier fixed: byte-safe section regex (autofire was silently dead)

`verify-continuation.sh` — the structural-lint gate every autofire dispatch must pass — used a raw multibyte `§` inside its section-counting regex (`^## §?[0-9]+`). BSD grep in the C locale (which the autofire hooks' non-interactive shells default to) parses that byte-wise, so `§?` meant "byte `c2` required, byte `a7` optional" — it never matched a plain `## 1.` header. Every continuation counted 0 sections → exit 4 → autofire skipped on every repo. The hooks were correctly wired; the verifier they gate on was silently failing.

- **UPDATED** `.claude/skills/autovibe/scripts/verify-continuation.sh` — both `§`-bearing regexes (the section count and the Current Branch check) switched from the multibyte `§?` to the byte-safe `[^0-9 ]{0,2}` (zero-to-two non-digit, non-space bytes — consumes the 2-byte `§` or nothing; identical behaviour under the C and UTF-8 locales). The `--self-test` now pins `LC_ALL=C` so it reproduces the hooks' non-interactive C-locale environment — an ambient UTF-8 locale was masking the bug — plus a new T11 case asserts a `## §N. Current Branch` header passes under C.

**Failure precedent prevented**: 2026-05-19 — a BuyBox session found autofire wired correctly end-to-end but functionally dead: the dry-run matrix scored 5/11, every failure a downstream `verifier-exit-4`. Root cause was a multibyte literal in a regex run under BSD grep + the C locale. The verifier self-test had reported "10/10 PASS" in prior sessions only because those shells carried a UTF-8 locale. Fixing the one verifier took the dry-run matrix to 11/11.

Synced from: NewEarth AI Agency @ ae92ec4

---

## 2026-05-19 — shell-portability: interactive grep shim + non-ASCII regex traps

Two new shell-scripting traps, both about the gap between where code is tested and where it runs. Surfaced by the 2026-05-19 NewVibe continuation-verifier outage — a verifier whose `--self-test` reported `ALL PASS (10/10)` for multiple sessions while autofire was in fact silently dead in every adopting repo.

- **UPDATED** `.claude/rules/shell-portability.md` — added Section 7: Claude Code's interactive Bash shell defines `grep` as a function shimming to a bundled `ugrep`; shell functions do not reach child processes, so scripts and hooks run the real BSD `grep`. A self-test pasted into the interactive shell exercises a different program than the hook that depends on it — run self-tests as a child `bash` process or they false-pass.
- **UPDATED** `.claude/rules/shell-portability.md` — added Section 8: a raw non-ASCII character (e.g. `§`) embedded in a regex is locale-fragile — BSD grep parses it byte-wise under the `C` locale that Claude Code's non-interactive shells default to, matching nothing. Fix is an ASCII-only byte-count-bounded bracket expression.

**Failure precedent prevented**: 2026-05-19 — a continuation verifier's `§?` literal counted zero sections in every continuation under the `C` locale, so every autofire dispatch skipped with `verifier-exit-4`. The bug hid behind a self-test that passed interactively (where `grep` is the `ugrep` shim) and failed only as a child process (real BSD grep).

Synced from: NewEarth AI Agency / BuyBox-AI @ 2d695743

---

## 2026-05-19 — NewVibe autofire doc corrected: V2 SSH-Execute, not V1 /schedule cloud routines

The autovibe `SKILL.md` still documented Phase 4.8 autofire as the retired V1 mechanism — "Autofire Continuation via /schedule" (Anthropic hosted cloud routines). Adopting repos read the *doc*, not the hook source, so sessions trying to autofire went to `claude.ai/code/routines`, installed the Claude GitHub App, and chased claude.ai connectors — burning whole sessions on the wrong substrate while the working V2 hooks sat installed and unused. This corrects the doc to V2 and adds explicit, unmissable "NOT cloud routines" guidance.

- **UPDATED** `.claude/skills/autovibe/SKILL.md` — Phase 4.8 rewritten: heading is now "Autofire Continuation via SSH-Execute (hook-enforced)"; a prominent box states autofire does NOT use cloud routines / `/schedule` / `CronCreate` / the Claude GitHub App / claude.ai connectors, and that autofire chains the NEXT session after a clean ship — it is not a launch button (to work now, just `/autovibe`). Includes an "if a session is confused" decision tree. Phase 4.6 gains a hook-enforced note. V1 `/schedule` mentions: 10 → 0.
- **UPDATED** `.claude/skills/autovibe/references/newvibe-integration-guide.md` — §0 gains a loud "NewVibe autofire is NOT a cloud routine" banner naming every wrong-path surface.

**Failure precedent prevented**: 2026-05-18/19 — BuyBox and Nirvana sessions burned multiple sessions arming claude.ai cloud routines, installing the GitHub App, and chasing SSH connectors, because the template's autovibe `SKILL.md` documented the retired `/schedule` mechanism. The V2 hooks had already shipped; only the doc lagged.

Synced from: NewEarth AI Agency @ ae92ec4

---

## 2026-05-18 — Operational doctrine docs now propagate

The three operational doctrines the diagnostic framing-audit skills operationalise are now template-managed. Previously the skills shipped but their `operationalises:` frontmatter pointed at a `docs/operational-doctrine/` path that did not exist in receiving repos — a dangling reference. `docs/operational-doctrine/` is now a carve-out from the `docs/` never-push rule.

- **NEW** `docs/operational-doctrine/01_theory-of-constraints.md` — operationalised by `/diagnose-bottleneck`.
- **NEW** `docs/operational-doctrine/02_systems-thinking.md` — operationalised by `/map-feedback-loops`.
- **NEW** `docs/operational-doctrine/03_decision-quality.md` — operationalised by `/decide-under-uncertainty`.

All three are generic (no project-specific content) and were triple-gate verified during the Operational Intelligence Synthesis Programme.

Synced from: First Principles Systems Thinker (2bf180f)

---

## 2026-05-18 — Define-Destination: the generative primitive + Branch D propagation

The framing-audit skill suite was entirely diagnostic — every primitive audits a framing that already exists. Nothing AUTHORED the destination a project steers toward. This change adds the generative complement and wires it into the project lifecycle.

- **NEW** `.claude/skills/define-destination/` — the destination-authoring skill (SKILL.md + evals/evals.json). Walks a validated six-part recipe (a three-way scope gate plus five content elements: end-state as conditions, a third-party-observable binary test, a still-true-later clause, a could-the-test-lie clause, a calibrated backward chain) and writes `DESTINATION.md` at the project root. Generative skill — does NOT carry the anti-anchoring guard; it is the one skill permitted to WRITE the `generative_primitive` provenance tag. 10 behavioural tests; 8 anti-patterns; refuse-to-overwrite + archive safety. `DESTINATION.md` itself is per-project content — never templatised.
- **UPDATED** `.claude/skills/_shared/anti-anchoring-guard.md` + `.claude/rules/diagnostic-skill-anti-anchoring.md` — added the 4th `hypothesis_provenance` value `generative_primitive` and Branch D (bounded-tag standard guard: a generative skill's non-deterministic output cannot pass validate-upstream, so Branch D treats it as operator-authored intent after a `project_root` + `generated_at` bounds check that closes the cross-repo laundering hole).
- **UPDATED** the 6 framing-audit diagnostic skills (`reduce-to-first-principles`, `check-commensurability`, `map-feedback-loops`, `audit-artefact-grounding`, `diagnose-bottleneck`, `decide-under-uncertainty`) — `generative_primitive` + Branch D propagated to every enum restatement, MVI table, procedure branch, output schema, and a Branch-D behavioural test each.
- **UPDATED** `.claude/skills/daily-plan-generator/SKILL.md` — new Step 2.5 (Destination Glance): surfaces the destination before the task list; stateless git-based staleness signal; loud-on-absence/corruption handling; drift decision rule.
- **UPDATED** `.claude/commands/setup.md` — new Step 7.7.0: the ROADMAP wizard invokes `/define-destination` and emits `DESTINATION.md`.

Verified by a 6-agent `/code-council` (ADVISORY — all 13 confirmed findings fixed) and a real-decision test (PASS — the recipe applied to the BuyBox AI buyer-tagging decision produces a substantively different, better-grounded recommendation).

Synced from: First Principles Systems Thinker (33a40af)

---

## 2026-05-18 — Framing-audit step in 4 entry-point skills (Mandatory Framing-Audit Programme, Session 2)

Layer 3 of the Mandatory Framing-Audit Programme — a named, non-skippable framing-audit step baked into the procedure of the four skills that start multi-phase work, so a wrong frame cannot enter at the top and propagate through every downstream phase. Layers 1 + 2 (Session 1) cover the other ~20 skills passively; these four needed the step inline.

- **UPDATED** `.claude/commands/plan.md` — new Phase 1.5 (Framing Audit), before codebase-intelligence gathering; framing-audit verdict line in the plan template + a Failure Condition.
- **UPDATED** `.claude/skills/prompt-forge/SKILL.md` — new step 1.1a (Framing Audit), before the Inference Audit; sixth Quality Test question.
- **UPDATED** `.claude/skills/master-continuation-prompt/SKILL.md` — new Step 1D.5 (Framing Audit), before the Inference Audit; Must-Pass checklist line.
- **UPDATED** `.claude/skills/autovibe/SKILL.md` + `.claude/skills/autovibe/modes/planned.md` — two-checkpoint design: a goal-audit step (planned mode step 2a, before plan-drafting) plus the existing `/council` Reframer made explicit as the plan-level checkpoint; crash-resume note + pre-completion gate.

Each step cites `.claude/rules/framing-audit-mandate.md` and the five framing-audit primitives — never copies a primitive procedure inline. Reviewed by a 6-agent /code-council — BLOCKING verdict (one critical gap: the steps were silent on the audit primitive returning a non-verdict), all 7 confirmed findings fixed before propagation.

Synced from: First Principles Systems Thinker (d136641)

---

## 2026-05-18 — Framing-audit mandate rule + auto-fire hook (Mandatory Framing-Audit Programme, Session 1)

Layers 1 + 2 of the Mandatory Framing-Audit Programme — the programme that makes the framing-audit skill suite (shipped 2026-05-18, Synthesis Programme Session 10) unavoidable instead of optional. The rule mandates a framing audit before load-bearing decisions; the hook announces that mandate in every session and nudges the matching primitive at decision moments.

- **NEW** `.claude/rules/framing-audit-mandate.md` — always-on mandate rule. Defines when a framing audit is compulsory (build-vs-buy, architecture decisions, comparison-based verdicts, multi-phase orchestration starts, artefact creation/audit, operator pushback) and the explicit not-for-trivia scope. Cites the five framing-audit primitives — never copies them. Contextual auto-load predicate.
- **NEW** `.claude/hooks/framing-audit-activation.sh` — SessionStart + UserPromptSubmit hook (one file, branches on event). SessionStart injects the mandate banner every session with a heartbeat marker; UserPromptSubmit pattern-matches six decision/comparison/framing classes and emits at most one nudge, silent otherwise. Never blocks (exit 0 always). Built-in `--self-test` — 15 cases, all pass.
- **UPDATED** `.claude/settings.json` — registers the hook under SessionStart and UserPromptSubmit.

Reviewed by a 6-agent /code-council — ADVISORY verdict, every confirmed finding fixed before propagation.

Synced from: First Principles Systems Thinker workshop @ d282cd6 (Programme Session 1)

---

## 2026-05-18 — NewVibe template-portable: CA-1 dedup fix + Pocock composition

Follow-up to the 2026-05-17 NewVibe autofire landing. Carries the CA-1 dedup bug-fix, the autovibe planned-mode Pocock-skill composition reference, and two portability fixes so the NewVibe files carry zero NewEarth-only assumptions.

- **UPDATED** `.claude/skills/autovibe/scripts/newvibe-dispatch-lib.sh` — CA-1: `would-dispatch` removed from the dispatch-once dedup regex (a dry-run does nothing, so it must not dedup a later real dispatch); the `autofire-dispatched` log entry no longer hardcodes a `target_machine` (the n8n REPO_MAP decides the machine — the dispatching session cannot know it). Self-test T6 fixture updated to a real dispatch status to match.
- **UPDATED** `.claude/skills/autovibe/scripts/newvibe-dryrun-matrix.sh` — scenario F now asserts CA-1 behaviour: a re-run after a `would-dispatch` is not deduped, it re-evaluates.
- **UPDATED** `.claude/skills/autovibe/scripts/post-handoff-writer.sh` — generated continuation skeleton: canary-check comment + NewClaw-composition pointer generalised so adopting repos' continuations carry no NewEarth-only references.
- **UPDATED** `.claude/skills/autovibe/modes/planned.md` — adds the Pocock-skill composition quick-reference (phase → skill → auto-trigger → skip-when); generalises the plan-output path to `~/.claude/plans/`.
- **UPDATED** `.claude/commands/setup.md` — adds Step 7.6.7 (NewVibe autonomous-shipping setup): installs the orchestration layer always, asks the autofire opt-in question, wires the two hooks + `.gitignore` + slug + self-tests in-repo, and surfaces the operator-gated n8n REPO_MAP + per-machine credential checklist. `/autovibe` added to the Step 10 next-steps list.

**Failure precedent prevented**: CA-1 (council 2026-05-18) — the dedup regex counted a `would-dispatch` dry-run as a real dispatch, so the first genuine armed autofire after any dry-run was silently skipped.

Synced from: NewEarth AI Agency @ fc3d024

---

## 2026-05-18 — framing-audit skill suite (Synthesis Programme Session 10)

The complete framing-audit skill suite — five callable primitives that catch the failure class where a protocol gate silently drifts from its purpose and a council converges inside the drifted frame (the 2026-05-14 Hermes failure). Verified by the Hermes re-run acceptance test before propagation.

- **NEW** `.claude/skills/reduce-to-first-principles/` — Primitive 1. First-principles reduction of a claim / proposal / protocol gate: the irreducible question + a delta table of what the framing added (constraints, presuppositions, smuggled conclusions). 4-component anti-anchoring pattern; 14 tests.
- **NEW** `.claude/skills/check-commensurability/` — Primitive 3. Five-rung commensurability ladder check for any comparison-based decision, plus a Hands-On Calibration Gate that fires when a qualifying external competitor sits on the unproven side. 20 tests.
- **NEW** `.claude/skills/audit-artefact-grounding/` — Primitive 5. First-principles grounding audit of one Claude Code artefact: an A1-A9 protocol over a 6-axis rubric, keep / refactor / deprecate verdict + propagation flag. Composes Primitives 1-4 (trigger-gated).
- **NEW** `.claude/skills/_shared/frame-vs-input-classifier.md` — Primitive 4. Procedural library: classifies operator pushback as frame-criticism vs input-criticism.
- **NEW** `.claude/skills/_shared/framing-audit-suite-handoff.md` — handoff-back document: the Hermes failure story, the suite map, the re-run acceptance test result, the 5-gap status, and per-repo wiring guidance for Agency-Main / BuyBox AI / Nirvana Freight.
- **UPDATED** `.claude/skills/map-feedback-loops/` — Primitive 2. v1.0 → v1.2 DECISION mode (second-order projection of a named decision — feedback loops, compounding effects, delayed consequences).
- **UPDATED** `.claude/agents/council/reframer.md` — inline analytical primitives 5-8 replaced with thin citation-stamped summaries pointing to the now-shipped suite skills; primitives 1-4, the Multi-Phase Position Audit, and the `[GAP-3 FIX]` markers preserved.
- **UPDATED** `.claude/skills/skill-auditor-merger/SKILL.md` — added a 7-test "Tests — Required Before Skill Ships" self-verification block and a Step 2.1 non-commensurability note (the weighted aggregate is a within-skill summary, not a cross-skill ranking).
- **UPDATED** `.claude/skills/_shared/anti-anchoring-guard.md` — re-synced (the suite's shared library; carries the aliasing convention + `not_applicable` verdict value the new skills depend on).

To inherit: run `/update-latest`. New adopters should read `framing-audit-suite-handoff.md` first — it explains why the suite exists and how to wire it.

Synced from: First Principles Systems Thinker (a330c64)

---

## 2026-05-18 — diagnostic-skill mechanical-runnability self-check

- **UPDATED** `.claude/rules/diagnostic-skill-anti-anchoring.md` — added a "Mechanical-Runnability Self-Check" section (spec-time/authoring-time gate, runs before any diagnostic skill ships). Check 1: an example is not an algorithm — a step that only gives a worked case has no rule for non-canonical inputs; state the general mechanically-checkable test first, then the example as illustration. Check 2: every halt/exit point needs a fully-defined output envelope — late halts after the main analysis are the ones most often missed; enumerate all halt points in one table with verdict value, mandatory fields, and disposition of any pre-halt analysis result. Both failure modes caught in the Primitive 5 `/audit-artefact-grounding` code-council (2026-05-18).

Synced from: First Principles Systems Thinker (d20df5a)

---

## 2026-05-18 — caveman always-on token compression

- **NEW** `.claude/hookify.caveman-always-on.local.md` — always-on caveman prose-compression hookify rule (`prompt` event, fires every turn, injects the caveman directive). Makes caveman always-on — no per-session opt-in — mirroring how layman-mode is enforced. Code/SQL/sub-agent-prompts verbatim; destructive-action confirmations stay full-length (Auto-Clarity Exception).
- **UPDATED** `.claude/rules/token-savers-composition.md` — L2 caveman marked ALWAYS-ON; "per-session opt-in" line replaced with "L1 + L2 both always-on via always-fires hookify `prompt` rules".

Synced from: First Principles Systems Thinker (5b68a43)

---

## 2026-05-17 — NewVibe autofire — autonomous session-to-session shipping

NewVibe is the self-launching half of the autonomous-shipping orchestrator: after a session ships cleanly, two hooks dispatch a fresh Claude session that resumes the next phase of work — no human pasting a continuation. This sync brings the full NewVibe autofire mechanism plus a per-repo integration guide to the template. Autofire is shell-enforced (it fires from hooks, never from a chat remembering a step) and fail-closed at three independent gates.

- **ADDED** `.claude/hooks/newvibe-autofire-stop.sh` — Stop-event hook; the autofire trigger. Silent no-op on every non-ship turn.
- **ADDED** `.claude/hooks/newvibe-precompact-handoff.sh` — PreCompact-event hook; writes a handoff continuation when the context window fills.
- **ADDED** `.claude/skills/autovibe/scripts/newvibe-dispatch-lib.sh` — the gated dispatch library (kill-switch, runaway cap, single-fire arm flag, verifier, sha re-check, lock). Org-specific n8n values templatised as `{{...}}` placeholders; the slug REPO_MAP left as a worked example.
- **ADDED** `.claude/skills/autovibe/scripts/newvibe-chain-guard.sh` — runaway-loop cap (refuses past chain depth 5).
- **ADDED** `.claude/skills/autovibe/scripts/verify-continuation.sh` — structural lint gate a continuation must pass before dispatch.
- **ADDED** `.claude/skills/autovibe/scripts/newvibe-dryrun-matrix.sh` — end-to-end integration test; self-contained, exercises the real wired hooks.
- **ADDED** `.claude/skills/autovibe/references/newvibe-integration-guide.md` — full per-repo wiring runbook with `[ORG-SPECIFIC]` markers, the safety model, and a troubleshooting table.
- **UPDATED** `.claude/skills/autovibe/scripts/post-handoff-writer.sh` — refreshed to current; one project-specific comment generalised.
- **UPDATED** `.claude/skills/autovibe/SKILL.md` — reference link to the integration guide.

All 48 NewVibe self-tests pass on the generalised template copies (chain-guard 10/10, dispatch-lib 17/17, verify-continuation 10/10, integration matrix 11/11).

### Auto-Setup Required

The two hooks need per-repo registration in `.claude/settings.local.json`:
- `newvibe-autofire-stop.sh` → the `Stop` hooks chain (timeout 20)
- `newvibe-precompact-handoff.sh` → the `PreCompact` hooks chain (timeout 20)

See `.claude/skills/autovibe/references/newvibe-integration-guide.md` §3 for the exact JSON shape and the full six-step integration checklist.

**Capability enabled**: any repo derived from this template can wire NewVibe autofire and run multi-session work that ships itself end to end, supervised by the operator via the single-use arm flag.

Synced from: NewEarth AI Agency-Main @ 85512e9

---

## 2026-05-17 — /code-council sub-agent name fix (3 of 6 agents were silently failing)

The Step 3 agent table in the /code-council skill named three sub-agents with a non-existent `code-council/` path prefix. The runtime registers those agents under bare names, so Security Auditor, Spec Validator, and Performance Reviewer all 404'd on the first launch of every council run — half the panel lost unless the operator noticed and relaunched. A six-lens review silently degraded to three.

- **UPDATED** `.claude/skills/code-council/SKILL.md` — Step 3 agent table rows 3/4/6: `code-council/security-auditor` → `security-auditor`, `code-council/spec-validator` → `spec-validator`, `code-council/performance-reviewer` → `performance-reviewer`. Rows 1/2/5 (`pr-review-toolkit:*`) were already correct, and the Step 3.5 validator-routing line already used the bare `performance-reviewer`.

**Failure precedent prevented**: 2026-05-17 — a /code-council run during synthesis-programme Session 6 Day 2 launched 6 agents; 3 returned "Agent type 'code-council/security-auditor' not found" and had to be relaunched with corrected names mid-review.

Synced from: First Principles Systems Thinker workshop @ 10880d6

---

## 2026-05-17 — Compaction-aware state check (agentic-loop-guards Pre-Exit Checklist)

Closes the symmetric twin of premature completion. The Pre-Exit Verification Checklist already guards over-claiming ("done" with no evidence); it had no guard against under-claiming — wrongly concluding work was never done because a compacted session hid it from in-context memory. Both directions are silent failures. A wrongly-disclaimed completion produces a redo of finished work or a false "this never shipped" report.

- **UPDATED** `.claude/rules/agentic-loop-guards.md` — new Pre-Exit Verification Checklist item 7 "Compaction-aware state check (claim AND disclaim)". Before asserting completion state in EITHER direction in a compacted session, verify against `git log --oneline` + file-existence: git history survives compaction, conversational memory does not. Includes a generalised failure precedent.

Synced from: First Principles Systems Thinker workshop

---

## 2026-05-17 — vault-optimizer skill (vault discoverability audit)

New skill. Audits a markdown vault for broken **discoverability** — routing tables that have drifted from folder reality, notes unreachable from the root, missing or stale folder indexes, misplaced files. Walks the discovery chain a co-worker Claude actually follows (root CLAUDE.md → routing entry → folder index → file). Classifies folder roles by reading content, never by assuming names, so it runs on any vault.

Merged-and-slimmed from the BenAI Obsidian OS plugin (`os-optimizer`, v3.8.0) via `skill-auditor-merger` — extract-only: kept 1 of 9 source frameworks (architecture & discoverability) plus content-based role discovery. The context-rot and reflection passes were dropped after a first-principles return-on-effort review found them substantially redundant with `refactor-claude-md`, `/challenge`, `/drift`, `/emerge`. Delegates CLAUDE.md and memory-index hygiene to `refactor-claude-md` / `refactor-memory-md` rather than re-implementing them.

- **NEW** `.claude/skills/vault-optimizer/SKILL.md` — orchestrator (245 lines): verify vault → role discovery → discoverability pass → before/after report
- **NEW** `.claude/skills/vault-optimizer/references/role-discovery.md` — content-based folder-role classification with a persisted registry
- **NEW** `.claude/skills/vault-optimizer/references/discoverability-pass.md` — 8-check pass: routing truthfulness, folder-index presence, ≤3-hop reachability, misplacement, reorg proposals, orientation
- **NEW** `.claude/skills/vault-optimizer/evals/evals.json` — 6 evals (3 trigger, 3 route-away to /challenge, refactor-claude-md, vault-review)

Synced from: NewEarth AI Agency (c5b9e5f)

## 2026-05-16 — Roadmap Write-Back Enforcement (canonical phase + warn-only Stop-hook + symmetry check)

Closes the done-but-untracked + ticked-but-false defect class: sessions that complete roadmap-relevant work but never tick the roadmap, and the inverse — items ticked "done" against an artefact that merely exists but carries no verdict. The fix is a single canonical phase every daily-plan-class skill delegates to verbatim, an evidence-gate that verifies a *verdict* (not pointer-existence), and a warn-only Stop-hook backstop. Project-shape aware: works whether a project has one daily-plan skill or two.

- **ADDED** `.claude/skills/_shared/roadmap-writeback-phase.md` — canonical W0–W6 deep module (evidence-verify-VERDICT-not-existence keystone, mkdir-lock, stable-slug + optimistic-concurrency, `[~]` reason-tag+age, synchronous projection sync + sentinel, revert re-validation). Single source; all daily-plan skills delegate here.
- **ADDED** `.claude/hooks/roadmap-writeback-verifier.sh` — warn-only Stop hook (fail-open, always exit 0), verbatim honesty clause, time-window-free change-set trigger predicate, per-machine self-check. Register in the Stop chain BEFORE any backgrounded projection sync.
- **ADDED** `bin/verify-writeback-symmetry.sh` — re-runnable symmetry gate; discovers present daily-plan skills (1 = delegation+non-fork; 2+ = mutual symmetry). Required-artefact in the shipping PR.
- **UPDATED** `.claude/skills/daily-plan-generator/SKILL.md` (v5.5) — named `Phase: Roadmap Write-Back` delegating to the canonical spec (named, never numbered — phase numbers collide across siblings).
- **UPDATED** `.claude/skills/master-continuation-prompt/SKILL.md` (v2.1) — roadmap write-back is part of Step 5 authoring; emits `ROADMAP-REFS:` block; 2 anti-pattern rows.

**Failure precedent prevented**: a parent project's 2026-05-15 session shipped ~15 updates + a council with zero roadmap write-back (caught only by hand), and a follow-up tick marked an evaluation "done" against a blank-template artefact with no verdict. Both classes are now structurally prevented.

## Auto-Setup Required

- `shell_hook`: register `.claude/hooks/roadmap-writeback-verifier.sh` in the Stop hooks chain, positioned BEFORE any vault/projection-sync Stop hook.
- `chmod_executable`: `.claude/hooks/roadmap-writeback-verifier.sh` and `bin/verify-writeback-symmetry.sh`.

Synced from: {{project_name}} @ cfb0ff0

---

## 2026-05-15 — cost-spike-diagnostic v2.0 + companion doctrine (sync from Nirvana)

A two-day investigation into a $1,500+ ZAR silent OpenAI spend on the Nirvana Freight client project produced a high-reusability cost-debugging skill plus three doctrine artefacts. Published to the template because every NewEarth AI client project that calls a per-call-billed external API (OpenAI, Claude, Mistral, Twilio, vision OCR, payment gateways, geocoding) needs this safety net.

**Origin (two incidents in 48h):**

- **2026-05-14**: diagnosed a PostgreSQL `lpad((nextval())::text, 4, '0')` column-default truncation bug on `data_conflicts.conflict_id`. Once the sequence crossed 9,999 (which happened silently 29 days earlier), every 10 consecutive sequence values collapsed to the same 4-character suffix, producing PK collisions inside `classify_media_final` which rolled back the entire function. The lpad fix moved ~$1-2/day.
- **2026-05-15**: a day-after audit using the hourly OpenAI usage CSV proved the lpad fix moved roughly ZERO dollars at the billing-API level — the call rate stayed flat at 130-150 calls/hour for 30 consecutive hours including the 12h after the fix. The actual $60-80/day burner was a separate Supabase `pod-ocr-backfill` cron firing every 2 minutes against a 4,500-record stale POD backlog where most upstream Wassenger storage URLs had expired. ~98% of OpenAI calls wasted.

**Files added (NEW):**

- **`.claude/skills/cost-spike-diagnostic/SKILL.md`** (v2.0.0) — Seven-phase methodology: inventory→attribute→fingerprint→cross-reference→escalate-to-concrete-evidence→root-cause→fix-and-verify. v2 specifically adds:
  - Phase 1a/1b/1c split (inventory callers → enumerate cron/scheduler firers → classify LIVE vs BACKFILL)
  - Phase 7 mandates BOTH database-state verification AND hour-by-hour billing-API rate comparison
  - Two new anti-patterns from 2026-05-15 (cron-multiplier blindspot, DB-as-proxy-for-API-rate-illusion)
- **`.claude/skills/cost-spike-diagnostic/evals/evals.json`** — 5 evaluation cases (4 should_trigger=true covering general spike + day-after + backfill + cron-blindspot; 1 should_trigger=false on a schema-change task to guard against false-positives)
- **`.claude/skills/cost-spike-diagnostic/CONTEXT.md`** — Origin story + intended-use document. Captures the two incidents, the doctrine that ships with the skill, the failure-mode catalogue, and pointers to the planned LLM dashboard repos (`https://github.com/NewEarthAI/llm-performance-tracker.git`, `https://github.com/NewEarthAI/litellm.git`). Travels with the skill — read first when pulling into a new project.

- **`.claude/rules/sql-defensive-defaults.md`** — Two PostgreSQL bug classes the skill's Phase 6 root-cause table flags: (1) string-truncation by lpad/rpad/substring on counter-derived column defaults; (2) non-essential side-effect INSERTs inside plpgsql not wrapped in BEGIN ... EXCEPTION. The two patterns that produced the 2026-05-14 lpad cascade.

- **`.claude/rules/rpc-replacement-safety.md`** — Never overwrite a Supabase plpgsql function with CREATE OR REPLACE without first extracting the live pg_proc source and diffing. Migration files drift from deployed functions. Composes with sql-defensive-defaults.md.

- **`.claude/hookify.no-backfill-without-permission.local.md`** — Active enforcement of the operator's standing rule: "no backfilling against billed APIs without explicit prior dollar-figure OK". Fires PreToolUse on `apply_migration` / `execute_sql` / `deploy_edge_function` when SQL contains backfill-shaped patterns (cron names like backfill/catch-up/rehydrate/reprocess/reclassify, `net.http_post` loops to LLM API URLs, `cron.alter_job(... active := true ...)` on a paused backfill). Surfaces a 7-item approval checklist requiring the operator to name a dollar figure in the current session.

- **`.claude/hookify.sql-defensive-defaults-gate.local.md`** — Active enforcement of sql-defensive-defaults.md. Fires PreToolUse on apply_migration / execute_sql with patterns matching `lpad(...nextval...)` (string-truncation timebomb) or `CREATE OR REPLACE FUNCTION` with unguarded secondary INSERTs. Surfaces pre-deploy checklists with the 2026-05-14 failure precedent.

**Operational guardrails inherited (already in template — see `operational-guardrails.md`):**

Backfill activation joins the Confident Mode HARD STOP list (alongside `git push`, DROP, DELETE, production deploy, etc.) in the Nirvana project's copy. When you pull this template update into a project, add the corresponding line to your project-specific operational-guardrails.md.

**Companion memory file (NOT pushed to template — lives in `~/.claude/projects/<project>/memory/`):**

The user-instruction-class memory `feedback_no_backfilling_without_permission.md` captures the operator's standing rule verbatim with banned phrases. Each project that adopts the cost-spike-diagnostic skill should clone this memory into its own project-memory folder for the per-project Claude session to auto-load.

**Validation:**

The lpad fix held overnight (verified 2026-05-15 — Nirvana database confirms classify_media_final's EXCEPTION-wrap is in place, conflict_id column default uses raw nextval() with no truncation). The pod-ocr-backfill cron is paused (`active=false`); bleed stopped within minutes. cost-spike-diagnostic v2's grade jumped from C (62.5/100) to estimated B+ post-audit; pending field validation across other client projects.

**Future-coupled work (planned in the agency repo):**

- Per-workflow / per-edge-function OpenAI API keys (instead of one shared "Nirvana Freight - AI Workbook" key across all workloads)
- LLM usage monitoring dashboard candidates: `https://github.com/NewEarthAI/llm-performance-tracker.git` and `https://github.com/NewEarthAI/litellm.git` (the LiteLLM gateway approach is structurally superior — every call gets metadata-tagged for attribution regardless of which API key is used)
- Doctrine: whenever Claude touches anything API-key-related in a vibe-code session, create a brand-new key fully named after the exact use case

Synced from: nirvana-freight-fleet-insights-automation @ c69634b4

---

## 2026-05-13 — NewEarth Design Suite v2 Phase 3.0 (three-layer architecture + /design-review entry point)

Phase 3.0 of the NewEarth Design Suite v2 build (per 8-agent extended council 2026-05-13) lands the L2 anti-slop overlay (`design-taste-frontend`), wires the mandatory L1/L2 contract directive into the orchestrator skills, refits `/design-review` as the full-stack entry point, and collapses the slash-command picker to two doors: `/design-review` (audit) and `/newearth-ui-design` (build). Specialty design skills become libraries underneath.

**Architecture (three-layer):**

- **L1 — Brand identity** — `PRODUCT.md` + `DESIGN.md` at repo root (authored via `impeccable teach` in a future phase; both files use the upstream YAML schema from Bakaus/impeccable)
- **L2 — Anti-slop overlay** — `design-taste-frontend` skill (MIT, Leonxlnx 2026), upstream defaults 8/6/4 (DESIGN_VARIANCE / MOTION_INTENSITY / VISUAL_DENSITY)
- **L3 — House signature + specialty** — `newearth-ui-design` + `data-table-design` + `kpi-dashboard-design` + `brand-visual-identity`

**Files added (NEW):**

- **`.claude/skills/design-taste-frontend/`** — L2 anti-slop overlay, verbatim from upstream `Leonxlnx/taste-skill`. SKILL.md (226 lines) + LICENSE (MIT). Single NewEarth modification: `user-invocable: false` harness-routing line. Dial baselines 8/6/4.
- **`.claude/commands/design-review.md`** — explicit `/design-review` slash-command entry point. Documents the 5 input shapes (live URL, attached screenshot, screenshot file path, code path, Figma export) and the "make this perfect" quality-push trigger.
- **`.claude/skills/newearth-ui-design/scripts/preflight-contract-files.sh`** — A6 pre-flight script, 14 lines bash. Asserts L1+L2 contract files exist + non-empty. Exits non-zero with operator-readable error if any missing. Wires into `/verify-hooks` or any pre-commit gate.

**Files updated:**

- **`.claude/skills/design-review/SKILL.md`** v1.0 → v2.0 (183 → 305 lines). NEW Mandatory Design Suite Contract section at top of body (A1 halt-loud pattern). NEW Auto-loaded libraries table documenting the L2 + specialty L3 skills loaded on each invocation. NEW Input Routing table covering all 5 input shapes. NEW 5-pass application order (L1 → L2 → L3 absolute → L3 specialty → cross-layer reconciliation). NEW Layer Compliance Summary in output format with per-issue layer tags. NEW `allowed-tools: WebFetch` for URL loads. Triggers expanded to catch "make this perfect", "screenshot review", "review this URL".
- **`.claude/skills/newearth-ui-design/SKILL.md`** — A1 Mandatory Layer Contract directive in body forces READ of `PRODUCT.md` + `DESIGN.md` + `design-taste-frontend/SKILL.md` before any output. HALT-with-loud-error path if any contract missing. Supersedes legacy `composition:` frontmatter as a load mechanism. Frontmatter gains `user-invocable: true` + note marking it as the build entry point.
- **`.claude/skills/newearth-ui-design/references/anti-vibe-coded.md`** (467 → 589 lines). Appends 6 net-new bans from `design-taste-frontend` (deduped against existing 16 house rules): #17 z-index hygiene, #18 transform/opacity-only animation, #19 never `window.addEventListener('scroll', ...)`, #20 grain/noise filters never on scrolling containers, #21 no warm/cool gray fluctuation within one project, #22 no `<Card>` wrappers on high-density data when `VISUAL_DENSITY > 7`. New L2 Composition Rules section documents the layering order + stricter-rule-wins conflict resolution.
- **`.claude/skills/kpi-dashboard-design/SKILL.md`** — `user-invocable: false` annotation. Now an L3 library auto-loaded by `/design-review` and `/newearth-ui-design` when a KPI surface is detected. No content change otherwise.
- **`.claude/skills/data-table-design/SKILL.md`** — `user-invocable: false` annotation. Now an L3 library auto-loaded when a tabular surface is detected.
- **`.claude/skills/brand-visual-identity/SKILL.md`** — `user-invocable: true` → `false`. Now an L3 library auto-loaded when brand-token questions arise.

**Slash-command picker effect:** 4 specialty skills disappear from the picker (operator never invokes them directly — they pull themselves in via the two entry points). The picker shrinks to the two design doors plus the genuinely-separate dashboard tools (`/build-dashboard`, `/grafana-dashboards`, `/llm-monitoring-dashboard`, `/dashboard-health`).

**Synced from**: Agency-Main `phase3-design-suite` branch (PR #23) @ dc7c36f. 4 commits: L2 install + A1 wire (1f98f8f) → A6 + A8 + A12 robustness layer (a68f84b) → `/design-review` v2 full-stack entry point (94567fd) → picker collapse + library annotations (dc7c36f).

**Mental rule going forward**: if a skill answers "how should this UI look" → it's a library under `/design-review` + `/newearth-ui-design`. If a skill answers "build me this specific platform artefact" or "is the data accurate" → it stays its own command.

---

## 2026-05-12 — doctrine-currency-check: triple-cite before propagating stale sub-agent citations

Closes the silent-failure class where a sub-agent quotes a project rule file to support a NEGATIVE decision (REMOVE / EXCLUDE / DEPRECATE / CANCEL) and the citation propagates to multiple downstream surfaces (council session, memory, ROADMAP, continuation) before anyone verifies the doctrine is current. Caught at session time by operator scepticism; codified now so it doesn't recur.

- **ADDED** `.claude/rules/doctrine-currency-check.md` — defines the triple-cite check: when a sub-agent cites a project rule / doctrine doc / ROADMAP line to support a NEGATIVE decision, the orchestrator MUST corroborate via (1) ROADMAP recency check on the affected feature, (2) git log on the affected paths within last 3 months, (3) live code reference grep for active usage. Any one contradicting the doctrine = stale, withhold propagation, surface to operator. Cost: ~30s + 3 greps at synthesis time vs N-surface retraction later. Composes with `council-protocol.md` auto-resolution citation discipline, `agentic-loop-guards.md` retroactive-edit ban, and `research-before-threshold-lock.md` (sister doctrine for numerical thresholds).

**Failure precedent prevented**: 2026-05-12 — a sub-agent's Capability Scout report cited a 9-day-stale doctrine line saying a still-active vendor integration was "being CANCELED". The citation propagated to 4 surfaces (council session auto-resolution AR4, memory file, ROADMAP row, v2 master continuation) before the operator caught it. Live state showed the vendor was actively cached in production code with a shipped PR (and measured money-win) 9 days prior. Each downstream surface was easier to write than to retract; cost of the 4-surface retraction was 5 file edits across 3 worktrees + 1 PR.

Synced from: BuyBox-AI workshop @ 2026-05-12

---

## 2026-05-12 — Template sync chain laser-precision: auto-commit + auto-rebase + auto-push + receive-side auto-wiring

Closes the manual-step gaps in the template sync loop. Before today, `/push-to-template` left the operator to run `git add -A && git commit && git push` by hand; sibling-project conflicts (the CHANGELOG.md case that hit 2026-05-12 mid-day) required hand-resolution; and template-pushed hookify rules with non-Bash matchers needed manual `settings.local.json` edits on the receive side. All three gaps closed.

- **REWRITTEN** `.claude/commands/push-to-template.md` (61 → 220 lines) — adds (a) laser-precision placeholder strip list covering tool names, project identity, NSM labels, timezone markers, with mandatory pre-write generalisation verification gate; (b) strict-exclusion list (ROADMAP/MEMORY/continuations/council/specs/strategy/project code NEVER pushed even if listed as template-managed); (c) Step 8 auto-commit + auto-rebase-on-conflict (CHANGELOG-merge convention) + auto-push to GitHub with 3-retry fetch-first loop cap; (d) Auto-Setup-Needs declaration system that lets hookify rules declare their per-project wiring requirements (consumed by /setup + /update-latest).

- **UPDATED** `.claude/commands/setup.md` — Step 7.6.5 added: scans installed `.claude/hookify.*.local.md` files for non-Bash matchers (e.g., `Agent`, `mcp__*__execute_sql`), auto-registers each unique (event, matcher) pair in `settings.local.json` PreToolUse / PostToolUse / Stop hooks chain pointing at hookify-context-injector.sh. Includes verification step (simulated tool dispatch through the chain confirming the rule fires). Step 7.6.6 makes all hook scripts executable. Known-matchers table seeded with the Agent matcher shipped 2026-05-12 (the `code-review-identity-load` hookify rule).

- **UPDATED** `.claude/commands/update-latest.md` — Step 5c2 added: when `/update-latest` pulls a new `hookify.*.local.md` file, runs the same auto-wiring logic that `/setup` Step 7.6.5 runs at first-install. Avoids duplicate registration if a matcher already exists. Surfaces wired matchers + any conflicts to the user.

**Why all three skills updated together**: the sync loop has push, receive-fresh, and receive-update endpoints. Laser precision means all three honour the same auto-setup-needs contract. Updating only push leaves receive-side hookify rules silently dormant; updating only receive leaves push-side conflicts requiring manual `git push`.

**Failure precedent prevented**: 2026-05-12 mid-day — the code-review-identity sync required (1) manual `git add -A && git commit && git push`, (2) fetch-first rejection because Agency-Main's autovibe-Phase-4.6 sync hit `main` 13 minutes earlier, (3) manual `git pull --rebase` triggering a CHANGELOG.md conflict, (4) hand-resolution of the conflict markers, (5) manual rebase-continue, (6) re-push. All six steps now run inside `/push-to-template` Step 8 with the CHANGELOG-merge convention baked in. The Agent-matcher registration for the code-review-identity hookify rule also went into machine-local settings only — siblings pulling via `/update-latest` would have had the rule file but no matcher firing it; the new Step 5c2 closes that gap.

Synced from: BuyBox-AI workshop @ 2026-05-12

---

## 2026-05-12 — autovibe Phase 4.6 + 4.7 + 4.8 (autofire continuation via /schedule)

Closes a multi-week sync gap: Agency-Main has had the full Builder/Verifier/Firer trio for chat-to-chat autofire since 2026-05-08, but the autovibe SKILL.md push to the template never carried the Phase 4.6/4.7/4.8 sections OR the `verify-continuation.sh` script. Child projects pulling from template were stuck on the manual-paste handoff. This PR closes the gap.

**Files updated:**

- `.claude/skills/autovibe/SKILL.md` — 325 → 562 lines. Adds three new phases:
  - **Phase 4.6 — Context-Budget Gate**: fires handoff at 40% context window usage, INDEPENDENT of task completion. Solves "Claude burns through 1M tokens mid-work" by writing a `CONTEXT-HANDOFF-MASTER.md` variant continuation.
  - **Phase 4.7 — Conversation-Level Rich Master Continuation** (Pillar C'): Claude self-invokes `master-continuation-prompt` skill to write canonical MASTER continuation. Fires from conversation, NOT bash — bypasses the Skill-from-bash architectural constraint.
  - **Phase 4.8 — Autofire via /schedule** (Pillar D'): closes the manual-paste gap. After Phase 4.7 writes the MASTER file and the verifier passes, Phase 4.8 invokes `Skill schedule` to fire a fresh Claude Code session ~5 minutes in the future with the MASTER file path baked in. The next session opens itself.

- `.claude/skills/autovibe/scripts/verify-continuation.sh` (NEW, 196 lines) — Pillar D' Verifier. Structural lint gate that runs BEFORE Phase 4.8 spawns a fresh chat. 8 exit codes (PASS / MISSING / SIZE / FILENAME / STRUCTURE / SLUG_COLLISION / DESTRUCTIVE_KEYWORD). Bash 3.2 portable, lean (no Claude --print subprocess). 8/8 self-tests pass.

- `.claude/skills/autovibe/scripts/post-handoff-writer.sh` — updated to v3 (latest Agency-Main version). 10/10 self-tests pass. Adds T9 truncated-MASTER detection + T10 DRAFT recovery fallback.

**Architecture** (Builder / Verifier / Firer trio):
- Builder = Phase 4.7 (writes canonical MASTER) — already shipped on template
- Verifier = `verify-continuation.sh` (this PR adds it)
- Firer = `Skill schedule` invocation, gated by verifier exit code (this PR wires it)

**Six gates before autofire fires** (any failure → skip + log to `phase47-log.jsonl`):
1. Phase 4.7 succeeded (latest log entry status = "written")
2. `ship_signal == "clean"` (NOT rollback, admin_merge, smoke_unverifiable)
3. Mode != hotfix
4. Verifier PASSes
5. Kill-switch off (`AUTOVIBE_AUTOFIRE` env not in {0, false, no, off, disabled})
6. Original intent has no destructive keywords (delete, drop table, destroy, recursive-force-delete, force.push, --no-verify, truncate)

**Kill switch** for users who want to disable autofire for a session: `export AUTOVIBE_AUTOFIRE=off`.

**Failure precedent**: child projects (Nirvana, BuyBox) ran `/update-latest`, got the older 325-line autovibe SKILL.md, and were missing the entire autofire system. Discovered 2026-05-12 when a Nirvana session asked "did the agency repo just push autofire to template? autovibe is meant to ssh into new chats" — surfaced that the push from Agency to template had been silently broken since 2026-05-08.

**Composition**: pairs with the existing `master-continuation-prompt` skill (Phase 4.7 invokes it) and the `schedule` skill (Phase 4.8 invokes it). Both already in the template; this PR adds the connector logic.

Synced from: Agency-Main @ HEAD 2026-05-12

---

## 2026-05-12 — Universal code-review-identity enforcement (4-layer defence-in-depth)

The reviewer-identity rule (anti-sycophancy preamble + 7 principles + Karpathy Self-Check Razors) was claimed "auto-loaded on any review work" by 6+ rule files, but in practice loaded only via compositional reference — silently absent on diffs touching domains that didn't reference it. Four enforcement layers added so future review sessions inherit the identity gate by default.

- **UPDATED** `.claude/rules/code-review-identity.md` — appended Self-Check Razors section. Two one-line tests applied to every diff: (1) trace-to-request — every changed line must trace directly to the user's stated request, flag scope-creep regardless of code quality; (2) senior-engineer overcomplication — if 200 lines could be 50, that IS the finding. Derived from forrestchang/andrej-karpathy-skills (Karpathy's 2025 LLM-pitfalls observations).

- **UPDATED** `.claude/rules/code-review-domain-routing.md` — added BASELINE row at top of the routing table. Loads `.claude/rules/code-review-identity.md` on EVERY review invocation regardless of file pattern. Identity preamble fires first; domain-specific rules layer on top. Closes the silent-absence gap where the rule was claimed auto-loaded but only fired via compositional reference.

- **UPDATED** `.claude/commands/code-council.md` — added Pre-flight (mandatory) block. Before launching ANY review agent, Read `.claude/rules/code-review-identity.md` and include its full content as DOMAIN CONTEXT prefix in every parallel agent prompt. HALT-on-missing semantics.

- **UPDATED** `.claude/commands/code-forge.md` — added Pre-flight (mandatory) block. Before spawning the fresh-context `claude -p` subprocess, Read the identity rule and inject as system-prompt-level identity prefix. A fresh Claude subprocess has NO project-rule auto-load by default; explicit injection is mandatory.

- **UPDATED** `.claude/skills/autovibe/SKILL.md` — added ALWAYS clause: when composing `/code-council` or `/code-forge`, verify the orchestrator has Read the identity rule per each command's Pre-flight block. Halt and re-Read if absent.

- **ADDED** `.claude/hookify.code-review-identity-load.local.md` — new hookify rule fires PreToolUse on `Agent` tool matcher, injects the identity gate as additional context on every Agent dispatch. Defence-in-depth layer 3 catches the failure mode where layers 1+2 are bypassed (subagent dispatched outside the documented commands). Composes with existing `hookify-context-injector.sh` runtime — zero new shell scripts. Each project's `settings.local.json` must register the `Agent` matcher in PreToolUse hooks chain (per-machine, gitignored).

**Failure precedent prevented**: 2026-04-20 PR #173 drawer resilience — 6-agent code-council issued PASS on a drawer that crashed on open in production. Principle 5 (false negatives > false positives) + Razor 1 (trace-to-request) would have flagged it; neither fired because the rule was not loaded.

**Verification end-to-end**: simulated Agent tool dispatch for `silent-failure-hunter` subagent through hookify chain — full identity gate text injected. Negative test (Bash tool) correctly silent. All 5 scriptable probes (routing baseline row visible, both command Pre-flight blocks present, autovibe adherence clause, hookify file parseable) pass.

Synced from: BuyBox-AI workshop @ 03f8cc7e

---

## 2026-05-12 — Session 2 reflect: three universal patterns (template-push edge case + doctrine line-count recovery + post-Write artefact verification)

Three MEDIUM-confidence patterns codified from a workshop project's Session 2 reflect (Operational Intelligence Synthesis Programme). All three are editorial/procedural; none are hook-worthy (0-3/10 hook scores).

- **UPDATED** `.claude/skills/template-push/SKILL.md` Edge Cases — "Template repo has uncommitted changes" now distinguishes two sub-cases. **Sub-case A** (prior-session work with prepared CHANGELOG entry + clear "Synced from: {project}" attribution) = do NOT halt; complete the prior commit cleanly under their attribution, then add the new files as a separate commit. **Sub-case B** (in-progress local work without CHANGELOG entry) = halt as before. Decision rule prevents the stall pattern when two projects push to template on the same day. Failure precedent: 2026-05-11 sync found a sibling project's CHANGELOG-entered work uncommitted; halting would have stalled both syncs.

- **UPDATED** `.claude/rules/doctrine-verification-gate.md` — new "When Line-Count Targets Are Not Yet Hit" section. Narrative padding flagged as anti-pattern (dilutes Gate 2 Anti-Pattern Coverage and Application Checklist Actionability axes). Operational appendix is preferred recovery path: worked examples instantiate frameworks AND provide 3-5 detection signals per example. Failure precedent: doctrine 544 → 616 lines via 8 worked archetype examples; operational density up, not down.

- **UPDATED** `.claude/rules/agentic-loop-guards.md` — Pre-Exit Verification Checklist item #6 added: "Stated-target artefact verification". Three commands (`wc -l` for line count, `grep -c "^## "` for section count, `grep -ic "<keyword>"` for mandatory terminology) run immediately post-Write while authoring context is fresh. Surfaces gaps 3-5× cheaper than downstream verification (Phase 6 / code-council / operator review). Failure precedent: doctrine 544 vs ≥600 caught post-Write, fixed in 5 minutes; same gap at downstream verification would have cost 15-20 minutes context re-acquisition.

**Why all three ship together**: Session 2 of a multi-session programme proved the three patterns concurrently. Editorial / procedural / verification disciplines compose; shipping one without the others leaves matching failure modes uncovered.

Synced from: First Principles Systems Thinker workshop @ facfab6

---

## 2026-05-12 — e2e-test wait_for truncation anti-pattern

One-line anti-patterns table addition surfaced from a production e2e smoke session against a dense React + cmdk app. The `wait_for` tool returns a saved-file pointer when the response exceeds the token limit; without documented response, testers re-snapshot blindly and burn another tool call against the same truncated tree.

- **UPDATED** `.claude/skills/e2e-test/SKILL.md` — added anti-pattern row to the existing table directing the reader to grep the saved file with a narrow pattern (illustrative example shown) rather than re-snapshot. Composes with the existing token-efficiency guidance already in the skill.

---

## 2026-05-11 — doctrine-verification-gate + diagnostic-skill-anti-anchoring (synthesis programme Session 1 extraction)

Two universal rule files extracted from Session 1 of the Operational Intelligence Synthesis Programme. Both are pattern-codifications that prevent failure modes only visible once doctrine-class artefacts (markdown frameworks for operational decisions) are authored. Generic by design — references to specific programme paths replaced with project-agnostic language.

- **NEW** `.claude/rules/doctrine-verification-gate.md` — Triple-layered quality mechanism for any operational doctrine doc (`docs/operational-doctrine/*.md` or equivalent surface). Gate 1: deletion-as-re-invention test (forward-looking, sidesteps day-1-no-consumers timing bias of grep-based deletion testing). Gate 2: doctrine-specific code-council rubric (5 weighted axes — Falsifiability 40, Scope Boundary 15, Anti-Pattern Coverage 15, Application Checklist 15, Triple Gate Conformance 15; replaces standard markdown rubber-stamp PASS). Gate 3: real-decision test with counterfactual + STRONG-PASS upgrade path for second-party-nominated cases (closes self-grading sycophancy hole identified by Devil's Advocate + Edge Case Finder convergence). Composes with `code-review-identity.md`, `agentic-loop-guards.md`, `pre-completion-pocock-check.md`, `output-chunking.md`.

- **NEW** `.claude/rules/diagnostic-skill-anti-anchoring.md` — Four-component pattern for any diagnostic / classification / identification skill that accepts user-supplied hypotheses. Component 1: Minimum Viable Input thresholds with structured below-MVI errors. Component 2: anti-anchoring guard (independent location BEFORE comparing to operator's named hypothesis; three verdict classes — Agreed / Disagreed / Inconclusive). Component 3: mandatory counterfactual statement (default_action / skill_recommendation / difference / skill_leverage); counterfactual gate self-flags ADVISORY-pending when recommendation matches default. Component 4: falsifiability marker on HIGH-confidence output (downgrades to MEDIUM if absent). Seven required test cases before any diagnostic skill ships. Composes with `doctrine-verification-gate.md` and `code-review-identity.md`.

**Why both ship together**: a doctrine doc and the skill operationalising it are paired artefacts. The verification gate sets the quality bar for the doctrine; the anti-anchoring pattern sets the design bar for the skill. Without both, a doctrine ships with no diagnostic skill, OR a diagnostic skill ships without the patterns that make it non-sycophantic. Co-shipping prevents the asymmetric-rollout failure mode.

**Failure precedent (forecast, not retrospective)**: a future client project authors operational doctrine without these rules, then code-council returns rubber-stamp PASS because no doctrine rubric exists, then a diagnostic skill on the doctrine becomes a hypothesis-confirmation machine for the operator's biased framing. Both rules land BEFORE that failure surfaces in a client project.

Synced from: First Principles Systems Thinker workshop @ 3dfda33

---

## 2026-05-11 — master-continuation-prompt programme detection + render_excalidraw load timeout

Two coordinated additions completing the multi-session programme infrastructure begun on 2026-05-10.

- **UPDATED** `.claude/skills/master-continuation-prompt/SKILL.md` — adds "Programme Detection" sub-step inside Step 0 + three optional frontmatter fields (`programme_name`, `programme_contract`, `programme_session`) inside Step 5A. When a continuation is one session within a multi-session programme (≥3 sequential sessions sharing a verification standard), three independent surfaces now enforce the alignment contract on the next session: (1) frontmatter pointer (machine-readable by daily-plan + autovibe), (2) §11 Must-Follow first-bullet directive, (3) §14 State Verification first command that halts the session if the contract file is absent. Generic example arc names used in the documentation; pairs with `.claude/skills/prompt-forge/SKILL.md` § "Mode: programme-launchpad" (which authors the contract once at programme birth) and `.claude/rules/multi-session-programme-contract-template.md` (the 10-clause skeleton both skills rely on). Master-continuation-prompt deliberately does NOT author new contracts — one author, N readers, drift-prevention through read/write asymmetry.

- **UPDATED** `.claude/skills/diagram/references/render_excalidraw.py` — bumps Excalidraw library load timeout from 30 seconds to 120 seconds. Bugfix observed in BuyBox-AI on slow networks + cold CPU runs where the 30 s ceiling fired before `window.__moduleReady === true` flipped, producing spurious render failures on otherwise-valid diagrams.

**Why this completes the programme-launchpad rollout**: the 2026-05-10 push wired prompt-forge to AUTHOR multi-session programme contracts but left master-continuation-prompt unaware of them. Every continuation generated mid-programme would have silently produced a standard 14-section handoff with no pointer to the alignment contract — meaning the next session would skip the verification gate. This update closes the loop so the 4-artefact programme-launchpad deliverable (programme spec + alignment contract + memory entry + CLAUDE.md pointer) survives every session boundary, not just session 1.

**Failure precedent (BuyBox-AI 2026-05-11)**: user explicitly flagged the gap — "I think we need to ensure this is part of the /Master-Continuation-Prompts and /prompt-forge". Cross-reference audit confirmed prompt-forge already pointed at the contract template (line 427) but master-continuation-prompt had zero references. Asymmetric wiring caught before any production continuation was generated through the broken half.

Synced from: BuyBox-AI @ 2026-05-11

---

## 2026-05-10 — prompt-forge programme-launchpad mode + multi-session programme contract template

Two coordinated additions for multi-session programmes (work spanning ≥3 sessions with a shared verification standard).

- **UPDATED** `.claude/skills/prompt-forge/SKILL.md` (v1.0 → v1.1) — adds "Mode: programme-launchpad". When a brief describes multi-session work, the skill now produces 4 coordinated artefacts instead of one forged prompt: programme spec (with session 1 prompt embedded inline + N-session forecast), alignment contract auto-loading on programme-class work, MEMORY.md In-Flight Work entry, and CLAUDE.md In-Flight Programme pointer. Token cap raised to <2,500 words for programme specs (decomposition + verification + forecast cannot compress further). Single-session forged prompts still target <800. Auto-detection heuristic + Quick Reference table updated.

- **NEW** `.claude/rules/multi-session-programme-contract-template.md` — generic 10-clause skeleton for deriving alignment contracts. Clauses: read spec first, declared scope, compose-not-rebuild, programme verification gate, Strategic Alignment footer, manifest update, layman voice carve-out, anti-sycophancy enforcement (Devil's Advocate + code-review-identity + pocock-grill), plan-then-execute, output chunking. Composes with `council-protocol.md`, `output-chunking.md`, `pre-completion-pocock-check.md`, `layman-mode.md`.

**Failure precedent** (origin of this addition): a 6,000-word brief proposing synthesis of 40+ business / systems / decision-theory frameworks into reusable operational doctrine. Standard prompt-forge mode would have produced an unexecutable single-prompt; programme-launchpad mode produces drift-prevention scaffolding so sessions 2-N inherit the programme's verification standard without re-litigation.

Synced from: First Principles Systems Thinker workshop @ 63f9fd3

---

## 2026-05-10 — prime.md: guard bare git bash injections against fresh-clone failure

`.claude/commands/prime.md` previously ran `git ls-files`, `git log -10 --oneline`, and `git status` as unguarded bash injections (`!`cmd``). In a fresh template clone where the user has not yet run `git init`, all three fail with `fatal: not a git repository`, aborting the `/prime` command entirely with no usable output.

**Fix**: every `!`git ...`` is now wrapped: `!`git rev-parse --git-dir >/dev/null 2>&1 && <cmd> || echo "(not a git repo yet — ...)"`. The command degrades gracefully in fresh clones; commit history / status sections show a friendly hint to run `git init` rather than a fatal error.

**Failure precedent (2026-05-10)**: fresh clone at `~/Desktop/1st_princples_systems_thinker/` ran `/prime` immediately after `/setup` and got `Error: Shell command failed for pattern "!`git status`": fatal: not a git repository`. Whole `/prime` aborted. User correctly identified this should be prevented in the template forever.

**Broader principle worth codifying** (not pushed in this sync): every `!`cmd`` bash injection in a `.claude/commands/*.md` file must have an environment-failure fallback (`|| echo "..."` or guard-then-run). Candidate doctrine rule for a future push.

---

## 2026-05-10 — operational-guardrails.md: Rule 12b — branch-stale file-not-found check

New rule between §12 (verify file paths in continuations) and §13 (re-verify file state before plan execution) in `.claude/rules/operational-guardrails.md`.

**Problem**: when user references a file by path (`/autovibe <continuation>`, `/execute <plan>`, or in chat) and the current branch is stale, the file may not exist on disk EVEN THOUGH it lives on `origin/main` or a sibling branch. The naïve response is to ask the user "did you mean a different file?" — wastes a round-trip when `git log --all` would answer in 1 second.

**Rule**: BEFORE asking the user, run `git fetch --all --quiet && git log --all --source --oneline --since="14 days ago" -- <file>`. If the file appears on a sibling ref, surface the location + commit and read via `git show <ref>:<file>`.

**Why universal**: applies to any worktree-using GitHub-PR workflow. The cost-of-asking principle is enshrined in the system prompt; this rule operationalises it for the file-not-found case.

**Failure precedent (BuyBox-AI 2026-05-10)**: `/autovibe` invocation referenced a continuation file that existed on `origin/main` (PR #571) but the current branch was 76 commits behind. Clarifying question to user wasted a round-trip.

**NOT pushed in this sync** (project-specific):
- BuyBox-AI doc-only Vercel admin-merge carve-out — depends on a project-local "BuyBox-AI CI" section that the template doesn't have. Generalisation would require creating a new "Project CI" section in the template. Deferred until 2+ projects need it.

---

## 2026-05-08 — Pre-flight + Output-Chunking + Pocock Test-First Pair

Four artefacts from a `/apply-insights` run on Agency-Main hub. All ship to template because they're stack-agnostic operational discipline that benefits every downstream project.

**Updated — Hooks:**
- `.claude/hooks/sessionstart-context-aggregator.sh` — adds `emit_preflight_section()` (~70 LoC). Every session start now prints a one-liner: `gh=ok  supabase-cli=ok  mcp-servers=N  nirvana-vps=warm` with a visible warning line when any check degrades. Non-blocking by design — never aborts the briefing. Probes: `gh auth status`, `command -v supabase`, MCP server count from repo-root or `~/.mcp.json`, nirvana-agent VPS reachability via 2-second SSH probe (only if SSH config has the alias). Self-test ALL PASS (7/7).

**Added — Rules:**
- `.claude/rules/output-chunking.md` — codifies manifest-first discipline for long deliverables. When a single response is likely to exceed ~3,000 tokens (council bodies, master continuation prompts, multi-file skill scaffolds, multi-table SQL migrations, long-form research synthesis), emit a manifest first, then write each artefact via the Write tool — never inline. Includes when-fires / when-doesn't tables, composition notes for `caveman` and `master-continuation-prompt`, anti-pattern catch-list.
- `.claude/rules/tdd-design-companion.md` — Pocock TDD distinctives that pair with `superpowers:test-driven-development`. Three sections: (1) anti-horizontal-slicing — one test → one implementation → repeat, never all-tests-then-all-impl; (2) deep modules — small interface, lots of implementation, deletion test; (3) interface design for testability — accept dependencies, return results not side effects, small surface. Includes anti-pattern catch-list.
- `.claude/rules/pocock-implicit-activation.md` — composition rule that names which Pocock-class skill applies to which work-class (bug, plan stress-test, refactor, unfamiliar code, test-writing, token-budget). Defines four-step check: classify → decide invoke/soft-mention/skip → compose with existing skills → note the consideration. Pairs with optional `pocock-implicit-activation.sh` hook (NOT shipped in this push — opt-in, see Agency-Main hub for source).

**Rationale:**
2026-05-08 `/insights` review (209 sessions analysed). Two recurring frictions:
- **Pipelines stalled mid-task** because Supabase CLI was unauthenticated, gh hit auth error, or VPS was unreachable — caught only after the operation that depended on the surface failed. Pre-flight surfaces the blocker in the SessionStart envelope so the model knows BEFORE attempting the operation.
- **`output_token_limit_exceeded` on 4+ sessions** producing partial transcripts with no recoverable artefact (master continuation prompts, multi-file skills, long council reports). Manifest-first cuts the deliverable into Write tool calls.

**Impact for child projects:**
After `/update-latest`, every session opens with the pre-flight one-liner. No additional setup required — the existing SessionStart hook composition picks up the new section automatically. Output-chunking, tdd-design-companion, and pocock-implicit-activation are ambient context (every session loads `.claude/rules/`). Test-first discipline now reaches every project that pulls from this template — closing a gap where the rules existed only in the originating hub.

---

## 2026-05-08 — operational-guardrails.md: divergent-main recovery after multi-worktree admin-merge

New H2 section in `.claude/rules/operational-guardrails.md` — "Recovery from a divergent local main after `gh pr merge --squash --admin --delete-branch`". Documents the failure mode where the post-merge local `git checkout main` fails because main is held in a sibling worktree, then a manual end-log commit on the main-holding worktree creates a SHA-divergent local main against origin/main even though the content is logically identical. `git reset --hard` is bash-guardian-blocked.

**Non-destructive reconciliation** (3 commands, under 30 seconds, loss-free):
1. `git checkout --detach` — preserves the divergent SHA on the reflog
2. `git branch -f main origin/main` — metadata-only ref-write, allowed by guardrails
3. `git checkout main` — back on main, now matching origin

Edge note: `gh pr merge --delete-branch` ALSO silently skips the REMOTE branch deletion when the post-merge checkout fails. Verify with `git ls-remote origin <branch>` and explicitly delete if still listed.

Composes with the existing 2026-05-07 "Recovery from a bad commit" section — together they cover both the wrong-commit-on-feature-branch case and the divergent-main-after-merge case, both bash-guardian-safe.

Captured via `/reflect` from a 2026-05-08 session. Universal git/gh discipline — applies to any project running bash-guardian + multi-worktree development.

---

## 2026-05-07 (later) — /verify-shipped v1.0 + v1.1 fleet-audit skill + autovibe/daily-plan composition

New top-of-stack shipping-confidence skill that catches the silent-killer drift surface no other skill in the family covers: edge-function source-vs-deployed mismatch (Cedar Hurst doctrine pattern — `loading-state-invariants.md` Invariant 7) and migration file-vs-applied mismatch. v1.0 + v1.1 shipped same day (BuyBox-AI PR #492 + #497).

**`.claude/skills/verify-shipped/`** (new — 8 files, 857 lines insertions on the v1.1 PR alone):

- `SKILL.md` — orchestration recipe across 6 layers (5 live, Layer 4 Vercel queued v1.2 with auth-surface decided). Phase 0 acquires atomic-mkdir parallel-session lock (5-min TTL + negative-age clock-skew guard) and trap-on-INT/TERM that writes `interrupted: true` state before releasing. Phase 7 cross-references Layer 2 STALE_LOCAL against Layer 3 MERGED_NOT_CLEANED + applies suppress-file filter. Phase 8 writes extended state schema (`schema_version: v1.1` with `fleet_integrity_score`).
- `scripts/walk-worktrees.sh` — Layer 1 worktree walk. Bash 3.2 portable. Portable timeout wrapper. Single global stash count (refs/stash is shared across worktrees; per-worktree would inflate by N×worktrees).
- `scripts/walk-branches.sh` — Layer 2 branch fleet walk. Mirrors walk-worktrees.sh patterns: same `to_int()` numeric normaliser, same numeric-test discipline, same suppress-CLEAN-on-high-fleet rule. Reads cached origin refs (caller responsible for fresh fetch). 2.7s on a ~80-branch fleet.
- `scripts/read-state.sh` — state-file read primitive (used by autovibe Phase 4.5 + daily-plan Step 1D + verify-shipped's own lock-fallback path). Dual-read with legacy fallback. Default 24h staleness threshold; `--max-age 0` bypasses BOTH staleness AND interrupted-state checks (lock-fallback contract — without this, retry-storm against still-held lock). Critical TZ=UTC fix for BSD `date -j -f` parsing (without it, SAST UTC+2 produces 3-hour age on a 1-hour-old stamp).
- `references/edge-fn-drift.md` + `references/migration-drift.md` — Layer 5 + Layer 6 recipes (v1.0).
- `references/pr-fleet.md` — Layer 3 PR-fleet recipe (v1.1). gh CLI based. Classifies CONFLICTS / FAILING_CI / STALE_OPEN_PR / DRAFT_AGED / MERGED_NOT_CLEANED. Filters Playwright FAILURE/CANCELLED to INFO (sanctioned-flake admin-merge heuristic per `operational-guardrails.md`).
- `references/integration.md` — composition contract for autovibe + daily-plan + ship + suppress-file format spec + atomic-mkdir lock contract. State-file v1.1 schema (extends v1.0 with `interrupted`, `session_uuid`, `fleet_integrity_score`, `suppressed_count`).
- `references/v2-queued.md` — Layer 4 (Vercel deploy-lag) spec for v1.2 with AUTH_DECISION captured (CLI-only path; no env-var fallback; per `/ship` precedent).

**`.claude/skills/autovibe/SKILL.md`** — new Phase 4.5 (Post-Ship Fleet Audit) inserted between Phase 4 (Post-Push Doc) and Phase 5 (Session Learning Gate). Tries cached state first (`read-state.sh --max-age 60` post-ship freshness window); invokes `Skill verify-shipped quick` on miss. Drift produces user-facing punch-list with prefix `🚧 shipped, but here's what else is loose:`. **Never blocks** — graceful degradation on Skill-tool-failure, MCP unavailability, or any non-parseable result. Adds new row to Session Learning Gate trigger criteria: "Phase 4.5 fleet audit detected post-ship drift" — fires `/reflect` so the drift becomes cross-session learning.

**`.claude/skills/daily-plan-generator/SKILL.md`** — new Step 1D (Fleet Audit, Phase 1.5 from /verify-shipped composition) inserted between Step 1C (Carry-Forward Verification Gate) and Step 2 (Silent Strategy Review). Renders `🚢 Shipping integrity: N/10` header + integrates fleet findings into Step 3 NSM-impact ranking as candidate work items (production drift = score 78, work-in-progress unblock = 65, housekeeping = 50). Tie-break by `severity × age_hours / urgency_decay`. Suppressed findings appear in header count but NOT as work items.

**Code-council on v1.1 (silent-failure-hunter sub-agent)**: 2 CRITICAL + 3 IMPORTANT + 2 SUGGESTION findings. CRITICAL #1 was lock-age clock-skew producing negative arithmetic that bypassed the >300s stuck-lock check; CRITICAL #2 was the `--max-age 0` + interrupted-state retry storm against still-held lock — composition-induced silent failure where each contract was correct in isolation but composition produced the bug. Both fixed inline pre-merge.

**Why universal**: every project pulling this template needs a fleet-state audit when shipping multiple features in parallel across worktrees. The Cedar Hurst class (merged but not deployed) is layout-agnostic. autovibe + daily-plan are already in the template; v1.1 wires the composition cleanly so dependent projects get the full audit chain on `/update-latest`.

**Reference implementation**: BuyBox-AI PR #492 (v1.0 sha `b8c9391f`) + PR #497 (v1.1 sha `9600356a`), both admin-merged 2026-05-07 within 2 hours of each other.

**Generalisation applied**: `mcp__supabase-buyboxai__*` → `mcp__supabase-{{project}}__*`; `--project-ref rkjbdjxihppklvlbfywp` → `--project-ref {{supabase_project_ref}}`. Cedar Hurst doctrine references kept as failure-precedent doctrine (parallel to how /ship references the 2026-04-19 incident).

---

## 2026-05-07 — bash-guardian recovery sequence + skill-naming pre-flight

Two universal learnings extracted from a session where (a) a misordered `git add -A` pulled unrelated files into a commit + force-push was bash-guardian-blocked, and (b) a new skill was authored as `verify-fleet` only to be renamed `verify-shipped` mid-session after a logistics-client namespace collision surfaced.

**`.claude/rules/operational-guardrails.md`** — new section "Recovery from a bad commit on a just-pushed feature branch (verified 2026-05-07)". Six-step non-destructive recovery: stash good fix → `git pull --ff-only` (re-applies bad commit) → `git revert <bad-sha>` → restore stash → real-fix commit → plain push. Edge case for untracked-file conflicts: `mv` aside to `/tmp/<repo>-checkout-aside/` for the duration. Survives bash-guardian (no force-push, no reset --hard required). Recovery time under 90 seconds once technique is identified.

**`.claude/skills/skill-creator/SKILL.md`** — new section "Naming Pre-Flight (do this BEFORE the workflow's first commit)" inserted before the 8-step Unified Workflow. Three checks: cross-client namespace check (`find ~/code ~/Documents/GitHub` for sibling projects with the proposed name), sister-skill family check (`/verify-*` / `/debug-*` / `/refactor-*` patterns), mental-model lay-test (verb matches user invocation phrasing). Includes pointer to the operational-guardrails recovery section for post-commit rename failures.

**Why universal**: bash-guardian is in every project that pulls this template; force-push + reset --hard blocks apply identically. Skill-naming collisions happen any time an operator maintains multiple Claude Code projects in parallel — the mental-model check is layout-agnostic.

**Reference implementation**: BuyBox-AI PR #492 (verify-shipped v1.0 ship). Commit `b54085f5`.

---

## 2026-05-03 (later 3) — data-table-design skill (agency UI standard)

New companion skill in the UI-design family — codifies the rule set extracted from a three-round UX-feedback session on BuyBox-AI's seller pipeline table that ended with "make every future agency table this neat by default."

**`.claude/skills/data-table-design/SKILL.md`** — seven non-negotiable rules:

1. Headers ALWAYS centred (single anchor point per column, kills cognitive tax of mixed-alignment headers)
2. Cells centred by default (numbers, currency, percentages, badges, icons, counts, codes — everything except long text)
3. Long-text streams LEFT (addresses, owner names, notes, descriptions, AI summaries, dates) — left-align matches reading order; truncation is honest from the left
4. Right-alignment BANNED — financial-print convention creates a header-left + value-right visual disconnect that non-finance users read as "messed up"
5. `inline-flex` (NOT `flex`) for cell content wrappers + multi-child header wrappers — block-level wrapper takes full cell width, children pin to flex-start; `inline-flex` makes the wrapper itself an inline element so it inherits parent's text-align
6. Subtle vertical dividers (15% opacity, `border-border/15`) in body rows ONLY — never on header row, gives the eye a track without going data-dense
7. USPS Pub 28 address formatting + ordinal-aware title-casing — verbose suffixes abbreviated (Trail→Trl, Street→St, Road→Rd, Avenue→Ave, etc.), ordinals lowercase ("42ND" → "42nd"), McNames re-capitalised ("MCCLELLAN" → "McClellan"), state codes + cardinal directions stay ALL-CAPS

Plus a FEMA-style code-to-label pattern for any classification field (X / B / C → "Low Risk", A* → "High Risk · AE", V* → "Coastal · VE", D → "Pending", junk values → dash) with technical code in tooltip.

**`.claude/skills/data-table-design/evals/evals.json`** — 3 eval prompts (2 should-trigger, 1 should-not-trigger) covering "fix misaligned table" / "build new table" / "build a card grid" (negative case).

**`.claude/skills/brand-visual-identity/SKILL.md`** — added cross-reference in description so users finding brand-visual-identity also discover data-table-design.

**Why universal**: alignment rules are layout-physics, not project-specific. USPS Pub 28 is U.S. mail standard. The 15%-opacity divider opacity is a brand-token-agnostic visual convention. Any agency project rendering rows × columns of business data benefits.

**Reference implementation**: BuyBox-AI seller pipeline `src/components/pipeline/DataTable.tsx` + `src/components/pipeline/columns/columnDefs.tsx` + `src/lib/formatters.ts` (29 lock-in tests). When porting to a new project, copy `formatters.ts` verbatim (zero changes needed) then adapt the alignment helper to the target project's column-id naming.

---

## 2026-05-03 (later 2) — agent-research file-output workers + verifier-appendix discipline + autovibe research-only pivot

Three HIGH-confidence patterns extracted from a project-side `/reflect` after a 10-worker `/agent-research` velocity research session. All patterns universal (work in any project running multi-worker research swarms or autovibe-style top-of-stack orchestration).

**agent-research SKILL.md** — two related additions:
- **Phase 2 file-output worker pattern**: when N ≥ 8 workers OR worker output expected > 2K tokens, modify the worker prompt to write FULL output to a per-worker file at `{output_path}/w{N}-{topic_slug}.md` and return only a 200-word summary inline. Lead reads files lazily during Phase 3 synthesis. ~10× main-context token savings.
- **Phase 4 verifier-appendix discipline (PASS-WITH-CAVEATS handling)**: when the verifier returns PASS-WITH-CAVEATS, do NOT silently edit the synthesis. Apply targeted inline edits AND append a "VERIFIER FINDINGS INTEGRATED" section listing corrections, strengths, and downstream-quotation risks. Preserves audit trail for downstream challenge rounds + council deliberations.

**autovibe SKILL.md** — one addition between Mode Detection and Foundation-First Shipping:
- **Research-only continuation pivot**: when `/autovibe <continuation-file>` is invoked on a research-only continuation (no code to ship), pivot to `/agent-research` rather than force-fit the plan → council → execute → ship loop. Detection signals: continuation file says "no code changes in this session" / "pure research", deliverable mentions SCQA / hazard-ratio matrix / "research workers", original master prompt was authored by `/agent-research` previously. One-sentence layman heads-up + invoke `/agent-research` with the continuation's worker spec as the prompt.

Hook-worthiness gate scored all three patterns ≤6/10 — expertise documentation is the right level, no PreToolUse/PostToolUse hooks proposed.

## 2026-05-03 (later) — council Reframer-Missing Fallback Protocol

Single addition captured from a project-side `/reflect` after a `/council --extended` invocation produced "Agent type 'council/reframer' not found" because the registry didn't have it (only flat-name agents like `optimist-strategist`). The orchestrator substituted Phase 0 inline using the same context bundle + analytical framework, produced a SKIP-PHASE-1 verdict citing prior precedent, and the resulting PR shipped + merged in the same session with zero rework.

**council SKILL.md** — two related changes:
- Error Handling table: new row for "Reframer agent NOT registered (subagent_type lookup fails)" → orchestrator (main Claude) performs Phase 0 INLINE using the same prompt template + context bundle. Cite the substitution explicitly in the synthesis. Distinct from the existing "Reframer fails" row (where the agent is registered but errors at runtime).
- Phase 0 — new Step 0.1.5 "Reframer-Agent-Missing Fallback" — formalises the inline-substitution protocol: apply Step 0.1 context bundle, run the full Reframer framework (upstream audit + success metric validation + scope diagnosis + reversibility + Rumelt strategy lens + recent-precedent check), produce verdict (PROCEED AS STATED / REFRAME SUGGESTED / SKIP-PHASE-1 PRECEDENT), cite substitution explicitly, continue to Step 0.3. Includes precedent rows (2026-04-17 sp1-polish + 2026-05-03 grade-tooltip) and a guard rule: do NOT substitute when the proposal is genuinely novel without doctrine precedent — escalate to user instead.

**Why this is in the template**: the Reframer-missing failure mode is environment-dependent (some agent registries have flat names, some have nested council/* names). Without an explicit fallback, the failure derails the whole council ceremony or leaves Phase 1 running on a potentially mis-framed proposal. The inline substitution pattern is universal — every project using /council benefits.

---

## 2026-05-03 — autovibe Foundation-First Shipping + council Auto-Resolution Pattern + Strategic Alignment Footer

Three additions captured from project-side `/reflect` after a 17-MUST-HAVE-defense council session shipped its foundation cleanly via the foundation-first split.

**autovibe SKILL.md** — new "Foundation-First Shipping" section. When `/council --extended` returns ADVISORY-SHIP with 10+ MUST-HAVE defenses AND Pragmatist's estimate spans 3+ sessions, ship the foundation PR (plan amendments + URL/contract specs + additive migrations + v2 execution continuation + ROADMAP/memory entries) this session, queue implementation for next session. Detection signal: 3 of 4 council-agent thresholds (3+ Devil's Advocate CRITICAL, 3+ Reliability NON-SHIPPABLE, 3+ Edge Case time-bombs, Pragmatist <70% confidence). Prevents the thin-shell intermediate state the council just rejected from becoming permanent on doctrine-perimeter files.

**council-protocol.md** — two new sections:
- "Strategic Alignment Footer" (mandatory format every synthesis ends with — ROADMAP item(s) advanced, ROADMAP item(s) rejected, justification if neither). Was project-only; promoted to template after pattern proved across multiple projects.
- "Auto-Resolution Pattern" — when user signals autonomous mode + quality-direction, synthesiser auto-resolves council questions per recipe (doctrine → repo precedent → industry best practice → Reframer+Devils consensus → quality default) rather than presenting menus. Document resolutions in session file as "Operator's Auto-Resolution" table — auditable + reversible. Used across multiple sessions in 2026-05 to convert blocking back-and-forths into one autonomous synthesis pass.

**No new hooks** — both patterns are workflow doctrine (passive enforcement via auto-load on relevant PRs), not tool-call interception.

---

## 2026-04-30 (later 2) — agentic OS chat-handover infrastructure (Pillars A' + B')

Adds the chat-to-chat handover rails. Every fresh chat now starts with live repo state injected; every autovibe completion now writes a structural draft continuation for the next chat.

**Three files** (1 new hook, 1 new autovibe script, 1 wired-in update):

- `.claude/hooks/sessionstart-context-aggregator.sh` (NEW) — Pillar A' SessionStart hook. On session start, composes the existing `prime-lite/scripts/brief.sh` (untouched, trusted base) and appends `MEMORY.md` index (head -80, three-tier path resolution) plus open PRs (`gh pr list` with exit-code-aware rate-limit handling). Wraps in JSON envelope per Claude Code SessionStart contract. Includes a heartbeat at the head of `additionalContext`: `**Session context loaded: N sections, X bytes**` — missing heartbeat = hook didn't fire (Reliability Engineer non-shippable flag from council session 2026-04-30-agentic-os-architecture-pillars-extended.md). 7-test self-test (`--self-test` flag, ALL PASS).

- `.claude/skills/autovibe/scripts/post-handoff-writer.sh` (NEW) — Pillar B' chain-handoff writer. After autovibe Phase 4 (post-ship documentation) completes, writes a structural draft continuation at `continuations/AUTOVIBE-{SESSION_TS}-{SLUG}-DRAFT.md`. Filename uses session start timestamp (NOT current time — Edge Case Finder edge 10 mitigation). Idempotent: same session re-running post-ship → same filename → existence check skips rather than overwrites (Edge Case Finder M-4 — never destroys hand-edited continuations). Skeleton ALWAYS includes a "Verification gate (do FIRST)" section with concrete `gh pr view` + `git log` checks for the cited PR + commit (Edge Case Finder edge 6 — autovibe-success-with-silent-regressions mitigation). Visible heartbeat: `Continuation written to: <path>` or `Continuation skipped: <reason>`. 8-test self-test (`--self-test` flag, ALL PASS).

- `.claude/skills/autovibe/scripts/post-ship.sh` (UPDATED) — adds 8-line tail block invoking `post-handoff-writer.sh` opportunistically (`|| echo "post-ship: post-handoff-writer.sh failed" >&2`) so a writer failure never blocks autovibe completion. The post-ship `exit 0` invariant is preserved.

**Manual registration step (one paste, post-merge)**:
The SessionStart hook must be registered in `.claude/settings.json` for it to fire (operational-guardrails.md Rule 13 blocks agent writes to shared `settings.json`):

```json
"SessionStart": [
  {
    "matcher": "*",
    "hooks": [
      {
        "type": "command",
        "command": "bash .claude/hooks/sessionstart-context-aggregator.sh",
        "timeout": 10
      }
    ]
  }
]
```

After registration, every new chat starts with the heartbeat + live state at the top of context.

**Why this matters**:
The 2026-04-29 17-minute outage post-mortem traced the root cause to silently-failed hooks + cross-chat blindness. Pillar A' addresses cross-chat blindness by injecting live state at every session start. Pillar B' addresses chat-handover quality by writing a structural draft after every autovibe completion that the next chat picks up + verifies before acting.

**Council session**: extended 8-agent deliberation at `council/sessions/2026-04-30-agentic-os-architecture-pillars-extended.md`. Reframer Phase 0 reframed the original "3-pillar architecture" proposal to "smallest enforcement layer over existing primitives" trio — A' / B' / C' — verified the layman rule (Pillar C') already existed, and dropped 3× over-scoping.

**v2 deferred**: auto-spawn fresh chats via `/schedule` after autovibe completes (Pillar B's auto-spawn — gated until handoff quality is proven over 30 days); rich-narrative continuation via `master-continuation-prompt` skill auto-invocation at chat orchestrator level.

---

## 2026-04-30 (later) — layman-mode hookify reinforcement (NEW)

Adds `.claude/hookify.layman-mode.local.md` — a SessionStart hookify rule that injects the layman-mode principles into Claude's context at the start of every session. Pairs with the `.claude/rules/layman-mode.md` rule (already loaded via `@`-import in `CLAUDE.md`).

**Two-layer enforcement now active**:
- **Tier 1**: rule file loaded into Claude's system prompt via `CLAUDE.md @`-import (every chat)
- **Tier 3**: hookify SessionStart inject-context — re-emphasises the rule at session start so Claude sees it twice before drafting its first response

Same architecture as `.claude/hookify.confident-mode.local.md`. No CLAUDE.md changes needed (the hookify rule auto-discovers).

---

## 2026-04-30 — layman-mode.md voice rule (NEW)

Adds `.claude/rules/layman-mode.md` — global voice rule for every assistant chat response addressed to Justin. Auto-loaded via `@`-import in `CLAUDE.md` (not contextual routing — global by design).

**What ships** (1 file, ~120 lines):

- `.claude/rules/layman-mode.md` — five principles (plain English defined inline; shortest answer first; decide-don't-menu; Commonwealth spelling in prose only; numbers stay precise) + hard carve-outs for code/SQL/sub-agent prompts/rule files/code-review outputs + `/dev` toggle (single-response, auto-reverts) + quotability self-check + 4 inline good/bad examples covering database outage, architectural choice, hook explanation, structured-plan output.

**Why this rule**: Justin is a tech-savvy South African non-developer building enterprise SaaS for non-technical clients. Pre-existing memory entries on voice (brand-voice, don't-ask, expertise, daily-plan-layman) covered ~80% of the desired behaviour but weren't consistently followed. This rule consolidates and supersedes them — single canonical home + the genuinely-new pieces (Commonwealth spelling lock, inline-define format, length default, quotability test, `/dev` escape hatch).

**Origin**: BuyBox-AI 2026-04-30. A diagram intended to be layman-friendly contained `npm run typecheck`, `lint`, `flaky`, `smoke`, `poll`, `<ts>` — all undefined. Justin's response: "I don't even know what to check." Council deliberation (Reframer + Devil's Advocate + Edge-Case-Finder) sharpened the spec from 3 enforcement options down to "rule file + CLAUDE.md `@`-import" alone. Hook-based and settings-level enforcement deferred to v2 if v1 proves insufficient after a week of use.

**Pull into existing projects** via `/update-latest`.

---

## 2026-04-28 — saas-multi-tenant-auth skill (NEW)

Enterprise-grade multi-tenant authentication + sub-user bootstrap for Supabase + React + TanStack Query projects. Distilled from BuyBox-AI's CM.32 four-phase ship (2026-04-19 through 2026-04-21, zero post-merge regressions).

**What ships** (22 files, 216KB at `.claude/skills/saas-multi-tenant-auth/`):

- `SKILL.md` — discovery layer with the six-tier shipping plan, twelve doctrinal pillars, anti-patterns table, pre-flight checklist
- 8 references (`references/`):
  - `doctrine.md` — full depth on each of the 12 pillars with named failure precedents
  - `tier-1-foundation.md` through `tier-6-hardening.md` — per-tier shipping detail with verification gates
  - `verification-gates.md` — exact SQL/test recipes per tier-gate
  - `pitfalls.md` — 12-entry failure-mode index ("users can see each other's data" → diagnostic sequence)
- 5 SQL templates (`templates/0*.sql`) — parameterized migration scaffolds for foundation, invites, team mgmt, audit log, pen tests
- 5 TS templates — `send-invite-edge-function.ts`, `accept-invite-edge-function.ts`, `useAuth.tsx`, `useOrganization.ts`, `error-classifier.ts`
- `scripts/audit-current-state.sh` — assesses where a project sits in the 6-tier plan
- `evals/evals.json` — 7 evals (5 should-trigger, 2 should-NOT)

**The 12 doctrinal pillars** (each with named failure precedent):

1. `security_invoker=true` on every multi-tenant view — Postgres views default to BYPASSING base-table RLS
2. No `FOR ALL` policies on mutation-eligible tables — silent permission drift
3. No `qual = true` SELECT policies on tenant tables — `dd_deal_reviews` cross-tenant leak
4. JWT-derived identity (`auth.uid()` / `caller.id`), NEVER from request body — audit-trail forgery prevention
5. Atomic invite claim via RPC + partial unique index — two-tab race condition prevention
6. Owner-transfer is promote-BEFORE-demote in single tx — last-owner trigger blocks reverse order
7. Append-only audit log = RLS deny + structural triggers + permission revoke (belt + suspenders + REVOKE)
8. Helper function MUST be `STABLE` — N×N RLS perf collapse otherwise
9. `_v2` policies with explicit sunset date — bounded coexistence
10. Pagination-safe duplicate check (no `auth.admin.listUsers()`) — 50-user/page silent miss
11. Org-switch invalidates ALL org-scoped queries + JWT refresh + window event broadcast — stale data prevention
12. Every 4xx renders specific actionable UI state — `FunctionsHttpError.context` is RAW Response (not pre-parsed body)

**Trigger phrases**: "Set up multi-tenant auth", "Add organizations/teams", "Build SaaS-ready auth with sub-users", "Create user invitation system", "Add RBAC with audit log", "Harden single-tenant app for SaaS launch".

**Composes with**: `saas-platforms` (strategy layer) → this skill (operational layer) → `master-security-review` (post-ship audit).

**Validation**: schema validation passed (`quick_validate.py: Skill is valid!`); 14 mechanism vs 4 instance markers indicating pattern-focused language; zero hardcoded UUIDs (only `<<<USER-A-UUID>>>` placeholders); 7 evaluation prompts including should-NOT-trigger negatives for non-Supabase / mobile-only / Stripe-billing scenarios.

---

## 2026-04-26 — newearth-ui-design v1.5: silverEdge Button (Mode G)

Third silver button tier between `silverOutline` (solid line) and `silver`/Mode E (brushed fill). 1px metallic-gradient ring around a neutral-fill button, same mask-composite trick as Mode A on cards. Static rendering — only motion is a 300ms opacity transition on hover/focus (65% → 100%). The "shimmer" perception comes from the gradient's 135° diagonal angle, not from any animation.

**Why this exists**: synthesised after auditing two 21st.dev community shadcn components:
- `liquid-metal-button` (johuniq) — REJECTED. WebGL fragment shader running continuously violates the static-silver rule ("Animated silver → reads as NFT/crypto landing page"). Bundle weight + GPU cost + accessibility risk.
- `gradient-borders-button` (Shatlyk1011) — STRUCTURE ADOPTED. The pattern (radial gradient ring + neutral fill) is correct; the purple→sky radial was replaced with the locked silver tokens (`#D4D7DC → #B8BCC2 → #D4D7DC`) and slate neutrals with `--ne-bg-base`.

**Files modified**:
- `.claude/skills/newearth-ui-design/SKILL.md` — v1.4 → v1.5. New trigger phrases ("silver edge button" / "shimmery silver border button" / "silver ring button" / "gradient border button"). Button.tsx asset description rewritten to reflect three silver tiers.
- `.claude/skills/newearth-ui-design/assets/tokens.css` — New `.ne-button-silver-edge` utility class (mask-composite ring, 65% rest opacity, fades to 100% on hover/focus). Disabled state cascades from base `disabled:opacity-50` via alpha compositing.
- `.claude/skills/newearth-ui-design/assets/component-templates/Button.tsx` — New `silverEdge` cva variant. Header docstring expanded to document the three-tier silver-button spectrum.
- `.claude/skills/newearth-ui-design/references/silver-signature.md` — Six modes → seven modes. Full Mode G section with CSS, React usage, three-tier spectrum table, density rule (max 2 per viewport, looser than Mode E's 1), 5 anti-patterns. Combination Rules extended with F+G and E+G entries. Implementation Checklist updated.

**Three-tier silver button spectrum**:

| Variant | Visual weight | Primary use | Density |
|---------|--------------|-------------|---------|
| `silverOutline` | Light — solid 1px silver line, transparent fill | Utility silver companion to Mode E | No hard cap |
| `silverEdge` (Mode G) | Medium — gradient metallic ring, neutral fill | Premium secondary OR quieter primary | Max 2 per viewport |
| `silver` (Mode E) | Heavy — brushed-silver fill | Premium hero/anchor primary CTA | Max 1 per viewport |

**Not for Atelier Dark** — Atelier signature is bronze, not silver. A future Atelier `bronzeEdge` button would be the parallel.

**Project integration**: `/update-latest` pulls the four updated files. The new variant is opt-in — projects don't auto-adopt it. Use `<Button variant="silverEdge">View Proposal</Button>` where you want a premium cue without consuming the Mode E density budget. The mask-composite ring picks up `rounded-md` from the base classes via `border-radius: inherit` on the `::before`.

---

## 2026-04-26 — deploy-vercel v3.0 + loading-state-invariants rule + competitive-intelligence skill

Three pushes from a single conversation. The throughline: every project should hit production reliably within an hour of `git init`, with regression-prevention machinery installed from day one.

**Files added**:
- `.claude/skills/competitive-intelligence/` — Universal competitor-intel super-skill (supersedes 7 prior external skills). JTBD profiling + scoring rubric + SWOT + decisions log + positioning integration. 7 bundled scaffold templates. Use in any agency/SaaS project that needs decision-grade competitor or market research aligned to a Strategic Intelligence skeleton.
- `.claude/rules/loading-state-invariants.md` — 6 invariants codifying the 2026-04-25 incident class: hashed-asset cache headers, wide-view LIST anti-pattern, statement-timeout-as-P0, human-readable error toasts, instant cached-chunk navigation, and `staleTime: 0` justification rule. Includes diagnostic order (canary log → planner stats → cache → auth context — top-down regression-resolution checklist) and regression-prevention surface map.
- `.claude/skills/deploy-vercel/references/vercel.json.template` — Drop-in `vercel.json` with `/assets/(.*)` immutable cache + 6 security headers + SPA rewrite (negative-lookahead on `/assets/`). Inline comments explain each rule's failure precedent.
- `.claude/skills/deploy-vercel/references/list-canary-self-healing.sql.template` — Postgres migration: `analyze_list_tables()` RPC + `list_canary_check()` RPC with self-heal-on-red + daily cron + hourly cron + idempotent re-runs. Replace 4 placeholders. Max time-to-recovery: 60 minutes.

**Files modified**:
- `.claude/skills/deploy-vercel/SKILL.md` — v2.0 → v3.0. Added 8 sections: SETUP (vercel.json, build/typecheck config, DB readiness via canary, zero-regression CI), per-change DEPLOY GATES (7 gates with verification commands), the 1-Hour Reliable Deploy Checklist (minute-by-minute for new projects), anti-patterns table, composition map with `/ship` + loading-state-invariants + supabase-postgres-best-practices + site-speed-boost. Triggers expanded.
- `.claude/rules/code-review-domain-routing.md` — Added Loading-State / Perf domain row routing on `vercel.json`, `vite.config.*`, `src/App.*`, primary list-data hooks, and `pg_cron` migrations.

**Why each is universal**:
- competitive-intelligence: every project doing market positioning needs the same 7-document scaffold (JTBD, rubric, SWOT, decisions log, positioning, monitor, signals).
- loading-state-invariants: every React+Supabase+Vercel project is exposed to all six failure modes; the diagnostic order applies regardless of schema.
- deploy-vercel v3.0: every Vercel-hosted project benefits from the immutable-assets rule, the typecheck gate, and the 1-hour reliable-deploy machinery. The canary template replaces 4 placeholders to project-fit.

**Project integration**: `/update-latest` pulls all five into the project. The `code-review-domain-routing.md` change auto-loads the loading-state rule on relevant PRs without further config.

---

## 2026-04-26 — newearth-ui-design v1.4: silver Button + silver PageHeader (Modes E + F)

Two opt-in premium variants added to the silver-signature system. Silver was previously reserved for cards (Mode A border, Mode B top stripe), interactions (Mode C hover ring), and structure (Mode D divider). Modes E + F extend the signature to action and page anchor surfaces — gated to "brand moment" contexts (proposals, landing heroes, report covers) so the signature stays scarce.

**Files added**:
- `.claude/skills/newearth-ui-design/assets/component-templates/Button.tsx` — Default brand-color button + opt-in `variant="silver"` (brushed silver fill with inner highlight) + `variant="silverOutline"` (silver hairline border, transparent fill). Reuses locked silver tokens. Density rule: at most ONE silver button per visible viewport.
- `.claude/skills/newearth-ui-design/assets/component-templates/PageHeader.tsx` — Page-level header with eyebrow / title / subtitle / actions slots. Opt-in `variant="silver"` adds a 2px brushed silver bottom-edge stripe (header analogue of card Mode B, repositioned to bottom). Opt-in `silverTitle` renders the title with a silver text gradient — reserved for the project's single strongest page.

**Files modified**:
- `.claude/skills/newearth-ui-design/references/silver-signature.md` — Renamed "Four Silver Applications" → "Six Silver Applications". Added Mode E (Silver Button) + Mode F (Silver Header Stripe) with CSS implementations, React usage, when-to-apply tables, and anti-patterns. Softened the legacy "Button | NO" line in Mode A's application table to point readers at Mode E.
- `.claude/skills/newearth-ui-design/SKILL.md` — Asset table extended with Button.tsx + PageHeader.tsx rows. Two new trigger phrases added ("silver button" / "silvery button" / "premium primary action"; "silver header" / "silver bottom stripe" / "brand-anchor page header"). Version 1.3 → 1.4.

**Why opt-in, not default**: Silver is a scarcity signature. Default buttons remain brand-color and default headers remain monochrome — silver variants compose on top for explicit premium contexts. Density discipline (one silver button per viewport, one silver header per project) is documented as a rule, not just a suggestion.

**Composition**: `<PageHeader variant="silver">` + `<Button variant="silver">` is the recommended matched-pair recipe for a proposal hero or landing primary action.

---

## 2026-04-26 — 2 new skills: b2b-saas-marketing + site-speed-boost

Two universally-useful skills pushed from BuyBox-AI. Both are stack-aware but client-agnostic.

**Files added**:
- `.claude/skills/b2b-saas-marketing/SKILL.md` — B2B SaaS marketing expert (Russian-language). Covers demand generation (inbound, ABM, MQL scoring), growth marketing (PLG, freemium/trial optimization, expansion, viral/referral loops), and marketing ops (HubSpot/Marketo/Pardot, CRM hygiene, attribution, analytics). Useful for any SaaS-shaped project.
- `.claude/skills/site-speed-boost/` (SKILL.md + evals/evals.json) — Systematic 6-phase perf diagnosis + optimization for React + Supabase + Vercel apps: browser measurement → network waterfall → DB EXPLAIN → targeted fixes (indexes, views, query consolidation, React Query tuning) → deploy → verify. Validated empirically (Pipeline 2,397ms → 585ms DB; 6.3s → 2.7s browser). The `db_tool` parameter default is generalized as `mcp__supabase-{project}__execute_sql` — set per-project.

**Why universal, not domain-specific**:
- b2b-saas-marketing is pure expertise, no project paths/schemas/IDs.
- site-speed-boost generalizes the React+Supabase+Vercel diagnostic flow that any project on this stack will need; only project-specific identifier (MCP server name) is parameterized.

**Project integration**: drop into `.claude/skills/`, set the `db_tool` parameter for site-speed-boost in your project's CLAUDE.md or invoke args, no other config required.

---

## 2026-04-24 — 2 new rules from comp-quality + parallel-session-collision reflection

Two universal patterns captured from a reflection on a session that (a) narrowly avoided shipping a small-N statistical bug + citing a retired industry rule, and (b) narrowly avoided a parallel-session merge collision. Both benefit any Claude Code / Cursor project working with numerical thresholds in doctrine or with parallel sessions on the same codebase.

**Files added**:
- `.claude/rules/research-before-threshold-lock.md` — Research-before-lock pattern for numerical thresholds + industry rule citations. Two documented failure modes: (1) asymptotic statistical constants at small N (e.g., MAD × 1.4826 is biased 18-33% at N=3-5; Park-Kim-Wang 2020 provides the finite-sample Cₙ bias-correction table), (2) zombie industry rules (example: Fannie Mae's widely-cited 10/15/25% adjustment caps were retired Dec 2014 via LL-2015-02). Includes `/agent-research` worker templates for small-N correctness, primary-source current-status verification, and regulated-industry cross-check.
- `.claude/rules/continuation-collision-safety.md` — Pause-gate pattern for continuations when parallel sessions may modify the same files. Three-query resume gate (`git log` / `git ls-remote` / `gh pr list`) with short-circuit ordering. Detection protocol, banner structure template, anti-patterns, and an illustrative failure scenario. Enforces MEMORY.md + project-memory update to reflect PAUSED state.

**Why universal, not domain-specific**:
- Research-before-threshold-lock: every project that codifies numerical constants or cites industry rules (statistics, finance, regulated industries) is exposed to the same two failure modes. Pattern is stack-agnostic.
- Continuation-collision-safety: every project with multiple Claude sessions, worktrees, or concurrent human+agent work benefits from the 3-query pause gate. No project-specific paths, schemas, or tool names.

**Project integration**: both rules are auto-loaded by Claude via the `.claude/rules/` discovery mechanism. Adding them to the rules folder in a project makes them available as ambient context. For hard enforcement, consider pairing with a hookify rule on `PreToolUse` Edit of doctrine files (not shipped here — per `hook-efficiency.md` triple-gate mandate, these patterns are expertise-only documentation).

---

## 2026-04-23 (latest-2) — autovibe Session Learning Gate + pre-orchestration fetch

Two additions to `/autovibe` for cross-session learning compounding + fresh-refs discipline. Both token-efficient. This is the final piece of the reflection system that now compounds: every substantive autovibe session auto-proposes learnings → user approves → universal learnings auto-flow to template → next project's first session already inherits the pattern.

**Files modified**:
- `.claude/skills/autovibe/SKILL.md` — new "Session Learning Gate" section. After post-push doc, auto-invokes `/reflect` ONLY IF the session produced learnings worth capturing (ran `/council`, exited plan mode, received user correction, shipped ≥2 PRs, `/code-council` non-PASS, or composed-skill mid-session recovery). Gate skips silently on trivial sessions — preserves token budget. When fires, `/reflect` Step 5 approval still gates writes; Step 7 auto-propagates universal learnings to template.
- `.claude/skills/autovibe/SKILL.md` — new "Pre-orchestration Fetch" section. Documents `preflight.sh` Gate 5 behavior.
- `.claude/skills/autovibe/scripts/preflight.sh` — Gate 5 added: `git fetch origin main --prune --quiet`. Single fetch, no merge. NOT a pull — separate cadence from `/daily-plan`. Non-blocking on network/auth failures.

**Why generic, not domain-specific**: every Claude Code / Cursor project with git worktrees benefits from fresh refs + substantive-only reflection propagation. No project-specific paths, schemas, or tool names. Works identically on any stack that already runs `/autovibe`.

---

## 2026-04-23 (latest) — pre-push-branch-verify hook (silent branch-switch defense)

One new shell hook addressing a failure mode caught during a BuyBox-AI ship cascade: a parallel session silently `git checkout`'d a different branch in the primary worktree, and the next `/ship` push targeted the WRONG remote ref. The push succeeded (git accepts refspec push regardless of current branch) but lineage divergence wasn't visible until 4 commands later. With a `--force-with-lease` push, this would have been catastrophic.

Universal because: every Claude Code project with multiple sessions / worktrees / remote branches is exposed to the same failure mode. The hook is hard-gated for token efficiency — zero context cost on 99% of Bash calls.

**Files modified**:
- `.claude/hooks/pre-push-branch-verify.sh` — new PreToolUse Bash hook. Triple-gated:
  - Gate 1: matcher = `Bash`
  - Gate 2: bash substring check for `"git push"` in raw JSON, bails in <2ms
  - Gate 3: parses `<branch>` arg from `git push <remote> <branch>` (handles `-u`, refspec form `local:remote`, `--force-with-lease`); compares to `git rev-parse --abbrev-ref HEAD`
  - WARN only — never blocks (refspec relay + hotfix relay-pushes are sometimes legitimate)
  - 0 tokens emitted on non-mismatch; ~80 tokens injected only on actual mismatch
  - Smoke-tested 7 scenarios: ls/git-status/bare-push/matching-push/mismatched-push/refspec-form/with-flags

**Project integration**: Append this entry to `.claude/settings.local.json` (or shared `settings.json`) PreToolUse Bash array:

```json
{"type":"command","command":"bash $CLAUDE_PROJECT_DIR/.claude/hooks/pre-push-branch-verify.sh","timeout":5}
```

Pairs naturally with existing `worktree-guard.sh` (which catches stale `.git/*.lock` files and reminds about worktrees on `git checkout`/`rebase`/`merge`/`cherry-pick`/`reset --hard`/`branch -D`). Together they cover both halves of the multi-session-collision problem: pre-switch (worktree-guard) + pre-push (this hook).

---

## 2026-04-23 (later) — Council-before-Implementation pattern + node_modules worktree symlink + /reflect token-efficiency hardening

Three universal patterns extracted from a BuyBox-AI session that shipped PRs #235 (Strategy Grades chip), #239 (325× counts perf), #240 (audit trail), #241 (rule captures). The session produced 4 PRs in one sitting with zero regressions; these are the learnings that generalize to any Claude Code / Cursor / Supabase / n8n / Vercel / GitHub / PostHog / Sentry / React project.

**Files modified**:
- `.claude/rules/council-protocol.md` — new section "Council-before-Implementation Pattern (laser-precision gate)". When user signals "elite / premium / no regression / mission-critical" OR rejects ExitPlanMode OR invokes `/council --extended` with no argument, run extended council on the PLAN FILE before ExitPlanMode. v1→v2 amendment cycle catches BLOCKING issues cheaply (8 agents + validators) vs. shipping-a-bug cost. Zero-cost discipline — LLM-judged signal, no hook needed.
- `.claude/rules/git-worktrees.md` — new section "node_modules in worktrees". `git worktree add` does NOT populate `node_modules`; symlink from primary clone is the fast path for same-tip branches (instant, zero download, zero disk). Documented `git stash -u` symlink gotcha + cleanup gotcha (rm symlink before worktree remove).
- `.claude/commands/reflect.md` — Step 3.5 token-efficiency mandate + Step 7 push-to-template propagation. Hook-worthiness threshold raised from 7 to 8 (token-bloat defense per hook-efficiency.md triple-gate pattern). New Step 7 explicitly propagates universal learnings to the template repo via `/push-to-template` — prevents cross-project tax where patterns stay local when they'd benefit every future project.

**Why generic, not domain-specific**: All three patterns hit any project. Council-before-Implementation is tool-agnostic (any /council-capable workflow). node_modules symlink works on any JS/TS project with git worktrees. /reflect token-efficiency is universal discipline against hook bloat. No project-specific references; safe for all template consumers.

---

## 2026-04-23 (earlier) — Bulletproof drawer regression perimeter skill + newearth-ui-design composition hook

New skill encoding eight hard-won patterns from a 4-hour BuyBox-AI debugging session that shipped as PRs #228, #229, #231, #234 (three drawer-regression fixes + Playwright perimeter). The shared premise: drawers and detail-modals accumulate write surfaces (inline edits, popover editors, state-mutation buttons) and each one is a silent-regression opportunity. Single `.update(updates as any)` cast, one click that doesn't bubble, one Escape that closes the wrong parent — user loses trust in the tool. The skill lays down a small number of Playwright tests that exercise every write surface end-to-end, fail loudly when any pipeline step breaks, and are idempotent + bulletproof (no graceful skips).

**Files added**:
- `.claude/skills/bulletproof-drawer-perimeter/SKILL.md` — 364-line skill codifying eight patterns (virtualized-table cell[1] click, drawer scope via role=dialog, two-click display→edit toggle, idempotent round-trip, REST PATCH cleanup, serial mode for realtime, storageState auth token capture, zero-skip discipline) + six anti-patterns (input:focus races, duplicate-text matches, UI cleanup in realtime components, toHaveCount(0) for popover unmount, assuming fast pipeline loads, redundant tests per surface when one hook covers all). Classification: encoded-preference. Template-pushable (no hardcoded project refs). Validated on BuyBox-AI seller drawer 2026-04-23 — 3 tests PASS in 20.9s.
- `.claude/skills/bulletproof-drawer-perimeter/examples/round-trip-test-template.ts` — fully parameterized copy-paste Playwright spec. Replace `{{TABLE}}`, `{{FIELD_LABEL}}`, `{{SUPABASE_URL_VAR}}` etc. Three tests: A1 primary-field round-trip, B1 inline-reason Escape invariant, B2 top-level Escape complement.
- `.claude/skills/bulletproof-drawer-perimeter/evals/evals.json` — 3 realistic prompts (2 should-trigger, 1 should-NOT-trigger). Tests whether description correctly routes "drawer regressions are killing me" vs generic "smoke test the landing page."

**Files modified**:
- `.claude/skills/newearth-ui-design/SKILL.md` — added composition entry: "bulletproof-drawer-perimeter — invoke after building any drawer/modal with write surfaces." So when a future session invokes newearth-ui-design to build a drawer, it knows to chain the regression-perimeter skill. Design ships the UI; perimeter ships the guard.

**Why generic, not domain-specific**: The eight patterns hit any app combining Radix + React Query + Supabase Realtime. Nirvana's logistics drawers (FuelLifecycleDrawer, ExcessDieselDrawer, BookingLifecycleDrawer) and BuyBox's property drawer both use shadcn Sheet → `role="dialog"` in DOM → the skill's selectors work identically. No logistics-vs-property split; domain variance lives in examples.

**Incident provenance**: Pattern 1 (virtualized-table cell[1] click) = 30 min lost diagnosing non-opening drawers. Pattern 5 (REST PATCH cleanup) = debug-revealed that Radix popover close + React Query realtime refetch race makes UI cleanup "element detached from DOM" flaky. Pattern 8 (zero-skip discipline) = user-taught: "bulletproof, locked down, why skipping?" — graceful skip masks data dependencies and provides zero regression signal.

---

## 2026-04-20 — Zero-regression phase 1: typecheck CI gate + code-council verification hook + /ship self-test canary

Three executable guards for the silent-compile-time-bug incident class. Installed after a post-incident 8-agent council deliberation in BuyBox-AI (PR #180). The shared root cause: `npx tsc --noEmit` is a silent no-op on any repo with root-tsconfig project references + `"files": []` — CI was green on PRs for weeks while checking literally zero files.

**Files added**:
- `.claude/rules/typecheck-and-review-gates.md` — new rule documenting the silent-no-op failure mode, the `npm run typecheck` replacement, the scope-bug example from real production incident, and a hard admin-merge-never policy for typecheck failures (with decision tree for other CI red states). Generalized from BuyBox-AI — anonymous component names, no project-specific file inventory.
- `.claude/hooks/code-council-verification.sh` — new SubagentStop hook (113 lines, triple-gated per `hook-efficiency.md`). When a reviewer-class subagent (security-auditor, performance-reviewer, spec-validator, code-reviewer family, master-code-reviewer, etc.) issues a PASS verdict without any verification artifact (VERIFIED: line, terminal code block, file:line citation, or screenshot reference), the hook auto-downgrades the verdict to ADVISORY via `hookSpecificOutput.additionalContext`. Rationale: diff-only review can issue clean PASS on code that crashes at runtime if the bug straddles a scope boundary (declaration in one function, usage in a sibling function — both pre-dating the diff). This happened in BuyBox-AI: a 6-agent code-council returned PASS on a drawer that `ReferenceError`'d on open.
- `.claude/skills/ship/scripts/self-test.sh` — new two-canary guard for `/ship` preflight. Canary 1 verifies the configured tsconfig includes ≥20 files (`tsc --listFilesOnly` output count — a `"files": []` config lists 0-1). Canary 2 injects a deliberate `const x: string = 42` type error and verifies `tsc --noEmit --strict` rejects it. Exit 0 = guard healthy, 1 = guard broken (halt /ship), 2 = bootstrap skip (no node_modules — non-fatal). Prefers `tsconfig.app.json`, falls back to `tsconfig.json`.

**Files modified**:
- `.github/workflows/ci.yml` — split into dedicated `typecheck` job (using `npm run typecheck`) + `check` job (lint + test). Removes silent-no-op `npx tsc --noEmit` from `check`. Requires projects to define `"typecheck"` in package.json scripts. Branch-protection-ready: mark `typecheck` as a required status check.
- `.claude/skills/ship/scripts/preflight.sh` — adds self-test invocation as gate 2 (after path-check, before any real work). Gate 6 (typecheck) now prefers `npm run typecheck` if defined in package.json, falling back to bare `npx tsc --noEmit` for older projects with a single tsconfig.json. Preserves existing `~/.claude-ship-snapshots/` snap dir (not project-prefixed).

**Project registration required** (not in template — hook registration is per-machine via `.claude/settings.local.json` OR team-wide via a manual human commit to shared `.claude/settings.json` since agents are guardrail-blocked from shared-settings writes):

```json
"SubagentStop": [
  {"matcher": "*", "hooks": [
    {"type": "command", "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/code-council-verification.sh", "timeout": 10}
  ]}
]
```

**Branch protection required for `typecheck`**:
```bash
gh api -X PATCH repos/{ORG}/{REPO}/branches/main/protection/required_status_checks \
  -f 'contexts[]=check' -f 'contexts[]=typecheck' -f 'contexts[]=Vercel' \
  -F strict=true
```

**Incident class this prevents**: Scope bugs (declaration + usage across sibling functions in the same file) that are invisible to diff-only code review, combined with a silent-no-op typecheck that claims "clean" while checking nothing. Symptom: ReferenceError crashes a surface that multiple PRs touched without noticing, because playwright test flakes were admin-merged. Self-test canary prevents the worse failure mode: shipping with confidence that a working guard has your back when actually the guard itself is broken.

---

## 2026-04-20 (earlier) — Supabase migration-guard + release hooks + Rule 5 parallel-session drift check

Adds a PreToolUse hook that gates every Supabase MCP mutation (`execute_sql` + `apply_migration`) through three layered gates: (1) settings matcher narrows to Supabase tools, (2) raw-string substring bail runs in <2ms on 95% of calls to preserve the token-efficiency contract required by `hook-efficiency.md`, (3) jq + regex only runs when Gate 2 sees a mutation keyword. Inside the slow path: branch check (main / hotfix only), behind-origin check, SQL pattern rules R1 (`security_invoker` view without `-- policies-checked:` comment), R2 (`CREATE TABLE` without `ENABLE ROW LEVEL SECURITY`), R3 (`UPDATE … IS NULL` backfill without paired `CREATE TRIGGER`), and an atomic-mkdir lock keyed by `$PPID`.

**Files added**:
- `.claude/hooks/supabase-migration-guard.sh` — 200-line PreToolUse hook. Triple-gated for token efficiency. Code-council hardened (4-agent review surfaced: jq-before-bail violating the triple-gate contract, R3 regex line-oriented silently failing on multi-line migrations, `\S+` non-portable on BSD grep, bash 3.2 case-pattern bug with embedded double quotes, numeric normalization gap per `shell-portability.md` §6, lock acquired before reason-check orphaning on blocked calls).
- `.claude/hooks/supabase-migration-release.sh` — 28-line PostToolUse hook. Removes lock iff holder's SESSION_ID matches (uses `$PPID` fallback — formula MUST match guard.sh exactly or locks never release).
- `.claude/rules/agentic-loop-guards.md` — adds Rule 5 (Parallel-session drift check) requiring `git fetch origin` + `gh pr list --merged` before claiming "all green" on anything touching shared state. Adds Supabase extension: also run `list_migrations` + `get_logs(service='postgres')` to catch raw `execute_sql` DDL that sibling sessions apply without git commits.

**Registration required in each project's `settings.local.json`** (not in template — per-machine file):
```json
"PreToolUse": [
  {"matcher": "mcp__*supabase*__execute_sql", "hooks": [
    {"type": "command", "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/sql-guardian.sh", "timeout": 5},
    {"type": "command", "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/supabase-migration-guard.sh", "timeout": 8}
  ]},
  {"matcher": "mcp__*supabase*__apply_migration", "hooks": [
    {"type": "command", "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/supabase-migration-guard.sh", "timeout": 8}
  ]}
],
"PostToolUse": [
  {"matcher": "mcp__*supabase*__execute_sql", "hooks": [{"type": "command", "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/supabase-migration-release.sh", "timeout": 3}]},
  {"matcher": "mcp__*supabase*__apply_migration", "hooks": [{"type": "command", "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/supabase-migration-release.sh", "timeout": 3}]}
]
```

**Incident class this prevents**: parallel-session Supabase collisions where one session uses raw `execute_sql` to flip a view to `security_invoker=true` without updating joined-table SELECT policies — caller gets NULL for every authenticated row, drawer crashes on NULL dereference, live site goes down. Hook blocks unless author includes `-- policies-checked: <table-list>` comment forcing them to do the `pg_policies` check.

**Escape comments supported** (all use `[^[:space:]]+` instead of `\S+` for BSD portability):
- `-- policies-checked: <comma-separated tables>` — bypass R1 after confirming joined-table policies exist
- `-- rls-exempt: <reason>` — bypass R2 for genuinely public config/lookup tables
- `-- backfill-only-see: <trigger-name>` — bypass R3 when the forward trigger already exists from a prior migration

**Timing** (measured on macOS bash 3.2): cold-cache first call 68ms, warm calls 31-35ms. Gate 2 raw-substring bail saves one jq invocation (~20-50ms). Subsequent jq + regex phase only runs when mutation keyword is present.

**Companion rule addition**: `agentic-loop-guards.md` Rule 5 closes the cross-session drift gap — but only catches work applied via `apply_migration` (which writes to `supabase_migrations.schema_migrations`). Raw `execute_sql` DDL leaves no migration-log trace, so the rule suggests `get_logs(service='postgres')` as a supplementary grep for DDL statements when deeper detection needed.

---

## 2026-04-19 — `/autovibe` + `prime-lite` skills (top-of-stack autonomous shipping orchestrator)

Adds the autonomous-shipping orchestrator that consumes the `/ship` skill landed earlier today. One invocation handles `plan → council → amend → execute → code-council → ship` for substantive work, OR routes trivia (typos, comments) directly to `/ship quick`. Closes the manual-orchestration tax that drove the parent project's "I'm tired of these problems happening" frustration.

**Files added** (20 total):
- `.claude/skills/autovibe/` — orchestrator (16 files): `SKILL.md`, 5 scripts (`orchestrate.sh`, `triage.sh`, `state.sh`, `preflight.sh`, `post-ship.sh`), 2 modes (`direct.md`, `planned.md`), 2 references (`invocation-contract.md`, `decisions-locked.md`), 6 evals (`01-direct-typo` through `06-hotfix-refusal`)
- `.claude/skills/prime-lite/` — reusable repo-state context briefing primitive (3 files: `SKILL.md`, `scripts/brief.sh`, `evals/01-budget.md`). Verified at 863 words / 1353ms on a real worktree. Composable building block — Autovibe's first step, also reusable by future orchestrators.
- `.claude/commands/autovibe.md` — command wrapper

**Architectural principles enforced**:
- **Compose-don't-rebuild**: autovibe NEVER reimplements `/ship` logic (verified by negative-grep guard for `git push|gh pr create|gh pr merge`)
- **Hotfix refusal**: `/ship hotfix` performs auto-rollback WITHOUT confirmation on smoke fail — safe for human, unsafe for orchestrator. Autovibe exits 9 with manual-takeover recommendation if hotfix conditions detected.
- **Dual-invocation parity**: same code path serves `/autovibe "X"` (human) and programmatic call sites (`AUTOVIBE_FORMAT=json`). Only output serializer differs.
- **State-file-as-contract**: orchestration state lives in `.claude/autovibe-state.json` (atomic-mkdir lock at `.claude/autovibe-state.lock/`, 30-min TTL, 60-min future-skew tolerance). Same primitive as `/ship`'s lock pattern.

**Code-council hardened pre-merge** (5 CRITICAL + 4 IMPORTANT fixed before push to template):
- **C1**: trap on EXIT removed — would have released the lock on every `exit 0`, but orchestrate.sh exits 0 after the 5-second preflight phase while the conversation continues for the 30-min handoff. Now `INT/TERM` only; lock released explicitly by `post-ship.sh` or via TTL takeover.
- **C2/C3/C5**: `state.sh` rewritten with `jq` instead of grep/sed. Three CRITICALs collapsed into one fix (corruption from quotes/newlines, silent-noop on null fields, command injection via stale-intent re-exec). Added: `write-num` for numeric/null fields, key-shape validation regex, atomic temp-file write, symlink TOCTOU defense.
- **C4**: empty-default guard on iso-to-epoch — prevents arithmetic crash under `set -uo pipefail`.
- **I4**: heredoc command injection — `$AV_INTENT` was interpolated into unquoted heredocs; malicious intent like `fix bug $(touch /tmp/pwn)` would execute. Now `_sanitize_md` strips backticks/`$`/`\` before any markdown insertion. Verified: post-ship.sh on malicious intent produces literal text in markdown with NO command exec.
- **I7**: memory-write reasons accumulated (was OR-chain losing combined signals). Multi-signal ship outcomes (e.g., exit 4 + signal=rollback) now write joined reason: `"non-zero ship exit (4);auto-rollback fired"`.
- **I11**: symlink TOCTOU defense — `state.sh` refuses if `LOCK_DIR` pre-exists as symlink before mkdir.
- **I14**: ROADMAP closure regex fixed — was `\b([A-Z]{1,5}|[0-9]+[A-Z]?)\.[0-9]+\b` excluding bare `A2` despite docstring claiming support. Split into dotted (INFRA.1, CM.10) + bare (A2, B3) regexes.

**Locked design decisions** (revisable in `references/decisions-locked.md`):
- D1 form factor: layered command + skill (preserves separation of concerns)
- D2 plan-mode trigger list: Supabase migrations/RLS, n8n workflows, edge functions, auth, hooks, skills/agents/council, src/integrations, >2 files OR >200-line diff. Trivia (typo/comment/console.log/ROADMAP reorder) routes direct.
- D3 ship-mode mapping: direct→quick, planned→pr, hotfix NEVER auto
- D4 forge gate: <4 words OR (<8 AND no verb/object) — REVISED from continuation spec `<20 OR no verb/object` which fired on every invocation
- D5 crash recovery: atomic-mkdir lock + 30-min TTL (vs ship's 10-min — autovibe runs longer)

**Required dependency**: `jq` (system-installed on macOS at `/usr/bin/jq`). Required for safe JSON state ops; preflight refuses if missing.

**Strategic alignment**: Closes the cumulative-incident-tax loop (rental-comps phantom-writer 2026-04-19, ship-skill wrong-path forge, two-clone divergence). Unblocks Acquisitions Co-Pilot V0/V1 autonomous flows. Supports INFRA.1 (single-clone discipline enforced by preflight).

Source PR: https://github.com/NewEarthAI/BuyBox-AI/pull/133

---

## 2026-04-19 (later) — `/ship` skill: code-council BLOCKING fixes (5 CRITICAL + 4 IMPORTANT)

Code council (6-agent + 11-validator) review of the `/ship` skill that landed earlier today returned BLOCKING. All 9 confirmed findings fixed in this sync. **Projects that already pulled the prior `/ship` skill should re-run `/update-latest` to get these fixes** — the prior version contained: a force-push-to-main on auto-rollback, silent word-split in snapshot.sh that corrupted the recovery contract, silent gh-auth-fallback in detect-mode that bypassed PR review gates, a Python -c shell-injection vector via `$CLAUDE_PROJECT_DIR`, a non-functional `trap` claim that misled users about zombie-lock recovery, and a `--format=json` contract documented but not implemented.

**Fixed (CRITICAL):**
- **C1 (trap honesty)**: dropped the false claim that `trap 'lock.sh release' INT TERM EXIT` is registered in every script. Claude Code's Bash tool calls are independent subshells — traditional traps cannot fire across calls. The actual recovery is the **10-min TTL** in `lock.sh` plus the **explicit `rm -rf` recovery command** in the exit-5 collision message. Documentation in SKILL.md, all mode docs, and failure-inventory C2 entry now matches the implementation.
- **C2 (force-push-main)**: `auto-rollback.sh` now uses **plain `git push origin "$branch"`** instead of `--force-with-lease`. A revert is always a fast-forward; force was unnecessary AND violated the project-template "NEVER force-push main" rule. Recovery on rejection: open a revert PR via `gh pr create` (surfaced inline in the script's error message).
- **C3 (snapshot word-split)**: `snapshot.sh` now uses `git status --porcelain=v1 -z` with `while IFS= read -r -d ''` for null-delimited iteration. Files with spaces, newlines, or quotes in paths are correctly captured. Rename/copy entries (R/C) are detected and the second null-record is consumed. MANIFEST.md now reports `files_captured: N / expected` with status (`complete` / `partial-by-design` / `PARTIAL with copy failures`).
- **C4 (detect-mode silent gh fallback)**: `detect-mode.sh` now runs `gh auth status` pre-check (matching the pattern in `ci-watch.sh` and `smoke.sh`). Auth-expired or rate-limited gh failures route to `ambiguous` with explicit recovery message rather than silently misclassifying dirty branches as `quick`. The asymmetric-safety-posture across sibling scripts is now consistent.
- **C5 (--format=json contract)**: each mode doc (`quick.md`, `pr.md`, `hotfix.md`) now has an explicit "Flag handling" section instructing the orchestrator (Claude) to suppress prose and emit ONLY JSON when `--format=json` is passed. `hotfix.md` gained 3 missing JSON output schemas (success / auto-rollback fired / auto-rollback conflict).

**Fixed (IMPORTANT):**
- **I1 (Python `-c` shell injection)**: `auto-rollback.sh` state-file update now uses heredoc + `os.environ` instead of shell-substituting variables into a Python `-c` source string. Eliminates RCE path via adversarial `$CLAUDE_PROJECT_DIR`.
- **I2 (ci-watch arg parse)**: `ci-watch.sh` now collects positional + flag args separately. `bash ci-watch.sh --timeout 10` (no PR given) no longer passes "--timeout" to gh as a target.
- **I3 (stream-order)**: `auto-rollback.sh` redirections changed from `2>&1 >&2` (swap streams) to `>&2 2>&1` (canonical merge-to-stderr).
- **I4 (A5 eval gap)**: added `evals/07-path-check-symlink.md` covering the `~/code/`-itself-a-symlink-into-iCloud edge case (the only failure-inventory item with zero prior eval coverage), with 3 counter-scenario variants.

**Verification on push side**: all 8 scripts pass `bash -n`; zero residual project-specific identifiers (sed-generalized); detect-mode dry-run against 3 active worktrees correctly classifies (`quick`, `pr`, `pr`); snapshot null-delim iteration captures 23/31 entries cleanly with correct `partial-by-design` status; lock evals 6a/6c/6d return expected exit codes (5, 6, 6).

**Scoping note**: `--force-with-lease` is retained ONLY in `pr` mode's amend flow and in `failure-inventory.md` Section B as documentation of when force IS appropriate (intentional history rewrite). `quick` mode and `auto-rollback.sh` use plain `git push` exclusively.

---

## 2026-04-19 — Council agent calibration (Reframer + Capability Scout + Pragmatist)

Three council agents rebalanced after observed failure modes in a multi-hour session: over-conservative reframing on sysadmin tasks + pre-AI hour-count anchoring cascading through synthesis. Edits are surgical (additive calibration layers, original charters intact). Validated via meta-recursive extended-council review — calibrated agents self-applied their new frameworks to their own edits and arrived at PROCEED.

**Updated — Reframer** (`.claude/agents/council/reframer.md`):
- Decision-Class Calibration table (Strategic / Architecture / Tactical / Sysadmin / Security) with graduated reframe thresholds. Strategic/Security = LOW threshold (reframe liberally); Tactical/Sysadmin = VERY HIGH threshold (almost always proceed).
- 3-bar Reframe Threshold gate: misalignment must be SIGNIFICANT + reframe must CHANGE the decision + expected benefit must EXCEED reframe cost. All three bars required.
- Anti-patterns list: "archive before delete on verifiably worthless data," "reframe from specific decision to broader policy question when the user just needs to unblock THIS hour," "apply strategic frameworks (Rumelt, Standard Kit) to sysadmin/tactical choices."
- Output structure: "Reframe Proposal" section OMITTED entirely when no reframe warranted. Clean PROCEED AS STATED is a successful output.
- Frontmatter examples rebalanced: added 2 proceed-as-stated cases (sysadmin cleanup, tactical admin-merge) to counter anchor bias from reframe-positive-only examples.

**Updated — Capability Scout** (`.claude/agents/council/capability-scout.md`):
- Reference Class Durations table (14 task types) with observed wall-clock anchors for AI-amplified stack work: edge functions 15-30 min, n8n ≤20 nodes 30-60 min, n8n ≥40 nodes 2-4 sessions, multi-file refactor 15-30 min, sysadmin cleanup 5-15 min, PR merge 2-5 min, etc.
- Burden-of-proof REVERSED: default to reference-class lower bound; other agents must defend higher numbers with specifics (credentials, novel integration, tuning, production observation).
- Parallelization factor made explicit: with `build-with-agent-team`, divide wall-clock by N parallel agents for embarrassingly-parallel work.
- Verification window split into subtypes: Fast (5-15 min Playwright + logs — default for UI/CRUD), Tuning (1-5 days — ML thresholds only), Production observation (1-4 weeks — novel UX / high-stakes only).
- OAuth row notes async 3rd-party wait separately from active time.
- Staleness footer: `Last calibrated: 2026-04-19` + caveat that numbers are stack-specific to Supabase/n8n/Vercel/GitHub/Playwright MCPs + Sonnet/Opus 4.x. Adopters with different stacks should re-observe, not blindly adopt.

**Updated — Pragmatist** (`.claude/agents/council/pragmatist.md`):
- Analytical Framework item 1 now mandates STACK-NATIVE execution reality assessment using Capability Scout's Reference Class Durations as the anchor, NOT pre-AI engineer-hours. Explicit self-check: "If you find yourself generating an hour-count that feels like 'what a team of 2 would take,' you're anchoring pre-AI — restate in session-hours."
- Added Decision-Class Calibration section (mirrors Reframer's table) with Pragmatist-specific stances per class. Anti-pattern called out: don't manufacture 5-section output for binary sysadmin tasks.
- Communication style updated: numbers in session-hours + wall-clock minutes; when stating >1h for a reference-class task, show your work (what specifically exceeds the class range).

**Rationale:**

Without calibration, the council structurally under-weighted AI-amplified velocity. Pragmatist generated pre-AI hour anchors; Capability Scout had to correct them every session; Reframer over-reframed sysadmin decisions into policy questions. Fix-at-source (Pragmatist) + translation layer (Scout) + frame-validation gate (Reframer) now share a single decision-class mental model. Remaining 5 council agents kept as-is — revisit only if drift reappears in next 2-3 deliberations.

**Calibration ownership:** The Reference Class Durations table is stack-specific. Adopting projects with materially different tooling should re-observe their own velocity before trusting the numbers. Quarterly re-calibration recommended.

---

## 2026-04-19 — `/ship` skill: autonomous code-ship workflow with council-audited safety

Added the full `/ship` skill (quick/pr/hotfix modes) that supersedes `/vercel:deploy` for any project pulling the template. Designed via extended council (8 agents) + dry-run plan gate + 4 non-shippable fixes from reliability + edge-case audits. All additions are generic — no project-specific identifiers; snapshot directory parameterized as `~/.claude-ship-snapshots/`; chronic-flake CI heuristic requires the adopting project to document its own precedent PRs in local overrides.

**Added — Skill:**
- `.claude/skills/ship/SKILL.md` — frontmatter, dispatch table, ASCII mode-detection decision tree, dual-use invocation model (human + future Autovibe orchestrator, same code path), lock contract, composition inventory, NEVER/ALWAYS constraints, rollback path
- `.claude/skills/ship/modes/quick.md` — commit + push on feature branch with `--force-with-lease`; inherits commit-guardian; emits rollback hint
- `.claude/skills/ship/modes/pr.md` — PR flow with `gh pr create` + `ci-watch.sh` (timeout ceiling) + admin-merge heuristic on chronic CI flake + post-merge smoke + auto-rollback wiring
- `.claude/skills/ship/modes/hotfix.md` — forces T3 verify-pipeline fresh (never state-skips); auto-rollback fires without confirmation (confident cascade on explicit invocation); always snapshots pre-destructive
- `.claude/skills/ship/scripts/path-check.sh` — iCloud/OneDrive/Dropbox/tmp detection + `~/code/` redirect + symlink-into-cloud detection (wolf-in-sheep's-clothing case)
- `.claude/skills/ship/scripts/detect-mode.sh` — git-state classifier → quick/pr/hotfix/ambiguous/detached/hotfix-guard; handles detached HEAD + main-branch guard as distinct exits
- `.claude/skills/ship/scripts/preflight.sh` — disk ≥5GB on data volume, path-check, stale `.git/*.lock` scan, snapshot-dir 7-day TTL cleanup, portable `npx tsc --noEmit` gate with timeout/gtimeout/unwrapped fallback
- `.claude/skills/ship/scripts/lock.sh` — atomic `mkdir`-based lock (NOT JSON-write; POSIX-guaranteed on APFS), 10-min TTL + 60-min future-tolerance for clock-skew corruption detection, PR/commit-sha scoped (different commits proceed in parallel), exit codes 0/5/6
- `.claude/skills/ship/scripts/snapshot.sh` — tracked + untracked file capture to `~/.claude-ship-snapshots/<ts>-<repo>-<tag>/` with MANIFEST + recovery command
- `.claude/skills/ship/scripts/ci-watch.sh` — `gh pr checks --watch --fail-fast` wrapped with portable timeout (timeout → gtimeout → manual-kill); distinct exit 9 for "CI status UNKNOWN" (never map to pass/fail)
- `.claude/skills/ship/scripts/smoke.sh` — Vercel auth pre-check via `vercel whoami` (401 vs 502 disambiguation), configurable `--min-wait` for cold-start propagation, `--retries 3 --backoff 10`, sha-header match + unverifiable exit 9 (no rollback on missing telemetry)
- `.claude/skills/ship/scripts/auto-rollback.sh` — `git revert` + push with `--force-with-lease`, enumerates post-merge commits BEFORE reverting, surfaces 3 recovery paths on conflict (abort+manual / nuclear reset / snapshot restore), updates `.claude/ship-state.json` with `exit_code: 4 rollback_sha rollback_reason`
- `.claude/skills/ship/references/failure-inventory.md` — ~20 failure modes seeded from the design session (A: filesystem; B: git ops; C: lock/state; D: CI/deploy; E: process). Growth contract: novel resolutions append + write `feedback_ship_<slug>.md` auto-memory
- `.claude/skills/ship/evals/` — 6 scenario files: quick happy, iCloud redirect exit-6, pr full flow, admin-merge on chronic flake, hotfix smoke-fail auto-revert + 3 counter-scenarios, lock parallel-safety (6a-6e)

**Added — Rules:**
- `.claude/rules/shell-portability.md` — shell-scripting traps (pipes eat `$?`, `grep -c PATTERN || echo 0` double-echo on miss, macOS `timeout` portability template, `mkdir`-atomic lock primitive, zsh reserved variable names, `[` integer-expression silent failure under `set -uo pipefail`). All patterns surfaced during real /ship implementation and dry-run verification.

**Updated — Rules:**
- `.claude/rules/operational-guardrails.md` — Rule 14 (shell cwd does NOT persist across Bash tool calls; prepend `cd` to every command when default cwd is iCloud-rooted). Rule 15 (agent writes to shared `.claude/settings.json` blocked by self-modification guardrail; use `settings.local.json` per-machine OR surface as manual human commit).

**Updated — Planning:**
- `.claude/planning-protocol.md` — Phase 2 adds "Real-State Validation" gate: when a plan introduces a heuristic/classifier/decision tree, enumerate ACTUAL current instances it will process and dry-run against each before first real use. Forcing function: the Pragmatist council agent's critical question "has the heuristic been run against real state?" caught a shell-quoting bug (`grep -c ... || echo 0` double-echoing) in the first implementation pass that would have shipped a silent misclassifier.

**Added — Hooks:**
- `.claude/hooks/worktree-guard.sh` — PreToolUse Bash hook. Triple-gated (matcher + raw substring fast-path + conditional). Warns on branch-modifying git ops when multiple worktrees active; scans stale `.git/*.lock` (>10min) on `git worktree add`. <5ms on 95%+ of calls. Companion to `/ship`'s iCloud-redirect; projects register in `.claude/settings.json` PreToolUse Bash array.

**Updated — Config:**
- `.claude/template-source.md` — registered all new files in TEMPLATE-MANAGED table; bumped version to `2026-04-19-ship`.

---

## 2026-04-19 — Git-Write Safety Infrastructure (Disk + Rebase + Snapshot)

Added three guardrails and two hookify rules preventing the specific failure modes observed during a 3-hour debugging session where APFS disk pressure + iCloud corruption + rebase semantic confusion combined to corrupt `.git/index` across 12 worktrees. All additions are generic (no project-specific identifiers).

**Updated — Rules:**
- `.claude/rules/operational-guardrails.md` — added Rule 13 + 3 new sections:
  - Rule 13 (Re-verify file state before executing a plan authored earlier) — multi-worktree drift detection + diagnostic rule "state drift before hostile process."
  - **Disk Pressure — Pre-flight Before Git Writes** — mandates `df /System/Volumes/Data` check (≥90% = halt) before any branch-modifying git op. APFS CoW degrades past 90% and can corrupt `.git/index` mid-write.
  - **`git checkout --ours/--theirs` — Rebase vs Merge Semantics (REVERSED)** — codifies the #1 misapplied git command. Code-file conflicts during rebase must halt for human review; docs-only conflicts may auto-resolve with proof.
  - **Snapshot Before Destructive Ops** — copy at-risk files to `~/{{repo_stem}}-snapshots/<ts>/` before `git reset --hard`, `git worktree remove --force`, `git branch -D`, or `rm -rf` of uncommitted paths.

**Added — Hookify rules** (triple-gated per `hook-efficiency.md`, <15ms on git Bash calls):
- `.claude/hookify.disk-pressure-pre-git-write.local.md` — PreToolUse Bash context-inject when git write op attempted with data volume ≥90% full. Hook score 9/10.
- `.claude/hookify.rebase-ours-theirs-guard.local.md` — PreToolUse Bash context-inject when `git checkout --ours/--theirs` invoked on code file during rebase. Hook score 8/10.

**Rationale:**

The disk-pressure hook alone would have prevented the entire cascade. Every downstream failure (iCloud thrash, rebase confusion, hook escalation) was amplified by git being unable to complete writes. A 15ms pre-check per git Bash call is cheap insurance.

The rebase semantic guard prevents the single highest-frequency autonomous-agent mistake: applying `--ours`/`--theirs` with merge-semantics intuition during a rebase (where they mean the opposite). This is a context-inject hook (not a block) — users can proceed after acknowledgement.

Both rules are generic across projects. The BuyBox-specific Playwright-admin-merge heuristic was intentionally kept out of the template push (lives in the project-local rule file only).

---

## 2026-04-18 — E2E Skill v2.0 + Negative-Control Discipline

Promoted e2e-test skill from v1.2 → v2.0 with **Negative-Control Discipline** — a mandatory protocol preventing the #1 regression-test failure mode: tests that go green against broken code because they cleared the failure state before asserting.

**Updated — Skills:**
- `.claude/skills/e2e-test/SKILL.md` — v1.2 → v2.0 (~470 line skill)
  - New section: **Negative-Control Discipline (MANDATORY for regression tests)** — 6-step protocol requiring every new regression test be proven to fail on the pre-fix commit before being trusted. Includes red-flag checklist for test PRs.
  - New anti-pattern rows: "Write test that clears the failure state before asserting" and "Ship a test without proving it fails on broken code."
  - Frontmatter: adds `auth_email` / `auth_password` parameters (env-var defaults).
  - Auth-aware orchestration sections (Phase 3.7 Authentication, AUTH micro-pattern).
  - API validation micro-pattern (200 + Content-Type:json + parseable body).
  - Snapshot-first discipline reinforced throughout.

**Rationale:**
2026-04-18 — A submit-flow smoke test sat green for 3+ weeks while the exact stale-localStorage bug it was supposed to catch shipped to production. The test called `localStorage.removeItem(...)` BEFORE asserting the mode selector rendered — clearing the very failure state a regression test must preserve. Rewriting it to SEED the stale state exposed the bug on the old commit and confirmed the fix on the new one. This discipline is now baked into the skill so no future test ships without negative-control proof.

**Impact for child projects:**
After `/update-latest`, any new regression test should produce a commit message footer documenting negative-control: `Verified: test fails on $PARENT_SHA, passes on HEAD`.

---

## 2026-04-18 — Code Council v2.0 (validation pass + consensus + PR posting)

Major quality upgrade to `/code-council`. The v1.0 skill produced raw findings from 6-9 agents with self-reported confidence — ~30% of flagged issues were false positives (most commonly pre-existing code mistaken for new). v2.0 closes that gap structurally and adds GitHub posting.

**Architecture changes:**
- **Step 2 (diff-hunk-first context)**: Agents now receive `git diff -U50` hunks (with 50 lines of surrounding context) instead of full file contents. Full files included only for files ≤200 lines. Kills pre-existing-code false positives at the source.
- **Step 3 (prompt template hardening)**: Every finding must now include (a) severity per explicit calibration table, (b) evidence — quoted diff lines OR quoted rule OR specific reference, and (c) a scope check for CLAUDE.md rule citations.
- **Step 3.5 (validation pass — NEW)**: Every CRITICAL/IMPORTANT finding is independently validated by a fresh subagent that sees only the finding + hunk + CLAUDE.md excerpt. Three hard gates: (1) evidence must exist, (2) flagged line must be on a `+` line in the diff (`git blame` confirm), (3) CLAUDE.md rule scope must match file path. Verdict: CONFIRMED / REJECTED / NUANCED (demoted one severity).
- **Step 3.75 (consensus amplification — NEW)**: Findings flagged by 2+ independent agents (same `file:line_range`, semantically equivalent failure mode) receive a confidence boost. 3+ agents with any CRITICAL original → promote to CRITICAL. Multi-agent agreement is the strongest signal in the system; v1.0 wasted it.
- **Step 5.5 (--pr <number> mode — NEW)**: Posts CONFIRMED findings as inline PR comments via `gh api`. Includes committable suggestion blocks for ≤5-line fixes. Skips closed/draft PRs and PRs Claude has already commented on. Falls through to `gh` CLI on any GitHub MCP auth failure (never retries MCP).

**Verdict logic now operates on POST-validation findings only**:
- BLOCKING = ≥1 CONFIRMED CRITICAL at revised confidence ≥ 90%
- ADVISORY = ≥1 CONFIRMED IMPORTANT, none reach blocking threshold
- PASS = no CONFIRMED findings at revised confidence ≥ 80%
- REJECTED findings never enter verdict math

**Session file changes:**
- New "Validation Pass" section tracks Confirmed / Rejected / Nuanced counts + full list of what would have been false positives
- Synthesis shows consensus counts with `[CONSENSUS: X agents]` tags

**Anti-patterns added (10 total):** Skipping validation, skipping consensus, giving full files instead of hunks, posting to PR without validation, retrying GitHub MCP on auth failure.

**Updated — Skills:**
- `.claude/skills/code-council/SKILL.md` — v1.0 → **v2.0** (288 → 574 lines)

**Tracked in manifest (were untracked in prior commit):**
- `.claude/agents/code-council/security-auditor.md`
- `.claude/agents/code-council/spec-validator.md`
- `.claude/agents/code-council/performance-reviewer.md`

Without the agent files tracked, child repos running `/update-latest` would pull the SKILL.md but fail at launch because `/code-council` spawns `code-council/security-auditor`, `code-council/spec-validator`, and `code-council/performance-reviewer` subagents.

**Verified generic:** No project-specific IDs, client slugs, or infrastructure references in any upgraded file.

**Migration notes:** This is a drop-in upgrade — no settings.local.json changes, no new hooks, no permission changes. Existing `/code-council` invocations continue to work with the new quality gates automatically active.

---

## 2026-04-16 — Code Review Council & Forge (multi-lens + fresh-context)

Propagated the `/code-council` and `/code-forge` code review tools from the hub. These were already referenced by `auto-council-on-plan` and `auto-review-on-execute` hookify rules (shipped 2026-04-15) but the underlying commands and skills were missing — child repos could trigger the rules but the dispatched commands would 404.

**Added — Commands:**
- `.claude/commands/code-council.md` — /code-council entry point (6-9 parallel agents, PASS/ADVISORY/BLOCKING verdict)
- `.claude/commands/code-forge.md` — /code-forge entry point (fresh-context `claude -p` subprocess review)

**Added — Skills:**
- `.claude/skills/code-council/SKILL.md` — Multi-lens deliberation engine (v1.0, standard 6 / thorough 9 agents)
- `.claude/skills/code-forge/SKILL.md` — Fresh-context non-sycophantic reviewer (v1.0, subprocess-based)

**Added — Rule dependencies (required by both skills at runtime):**
- `.claude/rules/code-review-identity.md` — Anti-sycophancy identity preamble (7 principles)
- `.claude/rules/code-review-domain-routing.md` — File-pattern → domain rule routing table; generalized `newearthai-*` skill references to `master-*` skill names to match template naming

**Verified generic:** No project-specific IDs, client slugs, Supabase refs, or n8n instance names in any pushed file.

---

## 2026-04-15 — Token Efficiency Refactor (council-reviewed, 8-agent extended)

Major hookify system refactor: 64% reduction in rule lines, zero-injection Bash calls, new enforcement coverage.

**Deleted (9 dead-letter rules — never fired):**
- `.claude/hookify.auto-rules.local.md` — SessionStart not wired
- `.claude/hookify.confident-mode.local.md` — SessionStart not wired (HARD STOP migrated to operational-guardrails.md)
- `.claude/hookify.plan-mode-enforcer.local.md` — UserPromptSubmit not wired
- `.claude/hookify.e2e-suggest.local.md` — PostToolUse injector not wired
- `.claude/hookify.mutation-verify-reminder.local.md` — PostToolUse injector not wired
- `.claude/hookify.progress-logger.local.md` — PostToolUse injector not wired
- `.claude/hookify.deploy-gate-push.local.md` — event "bash" wrong case
- `.claude/hookify.credential-access-guard.local.md` — legacy frontmatter
- `.claude/hookify.filesystem-safety.local.md` — coverage merged into bash-guardian.sh

**Compressed (paragraphs → checklists):**
- `.claude/hookify.supabase-auto-load.local.md` (74→14 lines)
- `.claude/hookify.n8n-auto-load.local.md` (61→18 lines)
- `.claude/hookify.completion-verifier.local.md` (48→18 lines)
- `.claude/hookify.plan-mode-exit-gate.local.md` (63→23 lines)
- `.claude/hookify.supabase-destructive-sql.local.md` (47→15 lines)
- `.claude/hookify.supabase-migration-safety.local.md` (47→13 lines)
- `.claude/hookify.n8n-http-error-handling.local.md` (53→21 lines)
- `.claude/hookify.n8n-fetch-blocker.local.md` (39→17 lines)
- `.claude/hookify.n8n-executions-full.local.md` (38→17 lines)
- `.claude/hookify.n8n-error-branch-required.local.md` (38→13 lines)
- `.claude/hookify.supabase-list-tables-block.local.md` (38→9 lines)
- `.claude/hookify.supabase-select-star.local.md` (36→13 lines)
- `.claude/hookify.safe-bash-enforcer.local.md` (36→13 lines)
- `.claude/hookify.n8n-update-safety.local.md` (36→11 lines)
- `.claude/hookify.task-context-injector.local.md` (51→17 lines)

**New/updated shell hooks:**
- `.claude/hooks/sql-guardian.sh` — added SELECT * blocking (hard block, exit 2)
- `.claude/hooks/bash-guardian.sh` — added chmod -R warning, shell redirect warning
- `.claude/rules/operational-guardrails.md` — added Confident Mode HARD STOP table

**New files:**
- `.claudeignore` — blocks irrelevant archives/screenshots from codebase exploration
- `.claude/template-source.md` — managed file manifest with deletion tracking

**Disabled (misfiring triggers):**
- `.claude/hookify.n8n-code-return.local.md` — Bash matcher fires on all Bash, not just n8n

**Updated commands:**
- `.claude/commands/update-latest.md` — Step 4b: delete deprecated files from child repos

---

## 2026-04-12 — sql-guardian: allow non-destructive DDL operations

DO $$ blocks and DROP VIEW were hard-blocked, preventing autonomous view rebuilds and migrations. Now:
- **DO $$ blocks**: if they contain destructive keywords (DROP TABLE, TRUNCATE, DELETE FROM) → still blocked. Non-destructive dynamic SQL (CREATE/REPLACE VIEW, ALTER) → allowed with context warning.
- **DROP VIEW**: changed from hard-block to allow-with-warning. Views are recreatable; not destructive like DROP TABLE.

**Modified files**:
- `.claude/hooks/sql-guardian.sh` — lines 54-65 (DO $$ handling) and 85-89 (DROP VIEW handling) updated from block→warn

---

## 2026-04-12 — Daily plan generator v5.0: Session housekeeping

Adds Phase 0 (runs before plan generation) with three automated housekeeping steps:
- **0A — Git Sync Checkpoint**: Detects uncommitted changes, unpushed commits, and approved-but-unmerged PRs. Offers to commit/push so all Macs stay in sync. Advisory, never blocks.
- **0B — Roadmap Activity Sync**: Maps recent git commits to roadmap activity table entries (configurable via `roadmap_activity_table` parameter). Keeps admin portal feed current without manual updates. Skips silently if parameter not set.
- **0C — Pull Latest**: Runs `git pull --ff-only origin main` to incorporate work from other Macs. Warns on divergence, never force-pulls.

**Modified files**:
- `.claude/skills/daily-plan-generator/SKILL.md` — v4.0 → v5.0. Added Phase 0 block, two new parameters (`roadmap_activity_table`, `roadmap_items_table`)
- `.claude/commands/daily-plan.md` — Updated "What Happens" to document Phase 0, bumped skill version reference

---

## 2026-04-11 — Zero-regression e2e infrastructure (NEW)

Initial push of the zero-regression-every-again infrastructure forged on BuyBox-AI PR #53 and battle-tested through 8 iterations of CI unblocking. Enables strict TypeScript, lint enforcement, and Playwright smoke tests on every PR via Vercel preview deployment_status triggers.

**New files**:
- `.github/workflows/ci.yml` — single `check` job: `npm ci` + `lint` + `tsc --noEmit` + `vitest`. Triggered on `pull_request` + `merge_group`. Dep-review-action intentionally NOT included (requires GitHub Advanced Security / Dependency Graph, not enabled on most new projects).
- `.github/workflows/e2e.yml` — `playwright` job running `mcr.microsoft.com/playwright:v1.59.1-noble` container. Triggered on `deployment_status.state == 'success'` when environment is `Preview`, plus `merge_group`. Expects GitHub Secrets: `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`, `E2E_USER_EMAIL`, `E2E_USER_PASSWORD`. Artifacts: `playwright-report/` on failure.
- `playwright.config.ts` — testDir `./tests/e2e`, baseURL from `BASE_URL` env, bumped timeouts (expect 15s, test 45s, action 15s, navigation 30s — needed for cold Vercel preview auth hydration), chromium-only, retries 2 on CI.
- `playwright/global-setup.ts` — Supabase REST auth pre-flight. Fetches a session token and writes `playwright/.auth/user.json` injected into every test context. ESM-compatible (`fileURLToPath(import.meta.url)` for `__dirname`).
- `tests/e2e/sanity.smoke.spec.ts` — always-passing sentinel that ensures the job has ≥1 test to run when all project-specific suites are skipped.
- `tests/e2e/README.md` — pattern guide for adding project-specific smoke tests: naming, `@smoke` tag, `data-testid` selectors, auth pattern, temporary skip convention.

**Modified / added**:
- `eslint.config.js` — extends `tseslint.configs.recommended` with project-sensible ignores (`dist`, `supabase/functions/**`, `playwright/**`, `tests/e2e/**`, `specs/**/*.js`) and demotes `@typescript-eslint/no-explicit-any` to a warning (it is a gradient, not a bug class; strict projects can still grep for warnings).

### Branch protection required checks

After setup, set required status contexts to `["check", "playwright"]` on the default branch. The `check` job catches build-time regressions (types, lint, unit); the `playwright` job catches runtime regressions via real smoke tests against the Vercel preview. Both must pass to merge.

### Known follow-ups

- Project-specific `.smoke.spec.ts` files should be added per page. Start with auth, dashboard, and main-feature-flow. Use `data-testid` attributes on critical values (price, id, count, title) so selectors stay stable under refactors.
- If the `@playwright/test` package version drifts from the docker image tag in `e2e.yml`, browser binary mismatch errors happen. Keep them in sync (both were v1.59.1 at time of push).
- The 7 BuyBox-specific smoke test suites (auth, buyer-modal, calculator, dashboard, drawer, pipeline, submit) are currently `test.describe.skip()`-wrapped in the source project pending an auth-hydration wait-pattern fix. They are NOT pushed to the template — projects should write their own. See BuyBox issue #64 for the un-skip work.

---

## 2026-04-11 — Council-reviewed guardian hardening (bash-guardian + sql-guardian)

Sync from BuyBox-AI after `/verify-hooks` audit and extended council review
(6 agents: Reframer, Optimist, Devil's Advocate, Neutral, Pragmatist, Edge
Case Finder) surfaced 4 critical silent-failure bugs and 6 significant edge
cases in the guardians. Fixes verified with 15/15 synthetic smoke tests
and live session runtime verification.

### `.claude/hooks/bash-guardian.sh` — 3 fixes

- **Close `-fu` combined-flag force-push bypass**: regex now matches
  `git push -fu`, `git push -uf`, `git push -f`, `git push --force`,
  and `git push --force-with-lease` (previously only `-f\b` or `--force`).
- **Remove broad `pkill`/`killall` block**: pkill is the intentional
  escape hatch when a hook hangs. Blocking it removes recovery.
  `kill -9` remains blocked (narrower, less recovery-critical).
- **Word-boundary anchor on `kill -9` regex**: `(^|[^a-zA-Z0-9_])kill\s+(-9|-KILL)\b`
  so `pkill -9` no longer collides with the kill block.

### `.claude/hooks/sql-guardian.sh` — 3 fixes

- **Block DELETE with tautological WHERE**: `WHERE 1=1`, `WHERE TRUE`,
  `WHERE 't'`, `WHERE (1=1)` — previously passed the "has WHERE" check
  but matches every row (silent full-table wipe).
- **Block DELETE with self-referencing subquery**:
  `WHERE id IN (SELECT id FROM <same_table>)` — matches every row.
- **Block PL/pgSQL dynamic SQL patterns**: `DO $$`, `EXECUTE FORMAT`,
  `EXECUTE '` — these construct destructive SQL at runtime, bypassing
  all static pattern checks.

### Verification

- 15/15 synthetic smoke tests pass (BuyBox-AI session)
- Live runtime: deferred-tool list confirmed project deny list overrides
  user-level allow entries mid-session (empirical proof of
  deny-beats-allow precedence across settings layers)
- Council session preserved at `council/sessions/2026-04-11-hooks-hardening-plan-review.md`

---

## 2026-04-11 — Auto-sync session artifacts hook

### NEW — `.claude/hooks/auto-sync-artifacts.sh`

Stop hook that auto-commits and pushes metadata/artifact files (memories, plans, continuations, session logs, specs, docs) to origin when a Claude Code session ends. Source code changes remain explicit-only. Prevents context loss from abrupt session termination (truncation, budget, crash). Runs after session-summarizer.sh. No-ops if nothing changed.

Register in `settings.local.json` Stop hooks (after session-summarizer.sh):
```json
{ "type": "command", "command": "bash .claude/hooks/auto-sync-artifacts.sh", "timeout": 30 }
```

---

## 2026-04-10 — newearth-ui-design v1.2: progressive disclosure reference

### ADDED — `references/progressive-disclosure.md`

4-level depth pattern for data-dense drawers: Verdict (Level 0) > Sections (Level 1) > Inline Reveal (Level 2) > Deep Dive (Level 3). Domain-neutral vocabulary with Logistics/PropTech/SaaS cross-domain table. 5 anti-patterns, implementation checklist, closing discipline rules. Validated against Stripe Dashboard, Linear, and Vercel. Bumps skill to v1.2 with new trigger phrases.

---

## 2026-04-10 — Add newearth-ui-design skill + lovable-to-vercel-migration v2.1 + skill-creator A.U.D.N. template scan

### NEW — `.claude/skills/newearth-ui-design/` (18 files)

NewEarth AI's house UI/UX design system for React/Vite/Tailwind/shadcn-ui projects. Captures agency-level design values as a standalone skill that composes with the existing `tailwind-shadcn-system`, `brand-visual-identity`, and `design-review` skills via explicit `do-not-trigger` entries. Agency commitment: these aesthetic values are locked as NewEarth house style across every future client project.

**What the skill provides:**
- **Design tokens** (`assets/tokens.css`) — Complete CSS variable system with light mode, required dark mode (warm ink `#0D0D0E` + inset-highlight shadows), and optional Atelier Dark editorial preset (5-color palette: ink/oxide/parchment/verdigris/bronze + triple type system: PP Editorial New + Söhne + Berkeley Mono). Parameterized for `{{primary_color}}` and `{{primary_color_foreground}}`.
- **Locked neutral palette** — Warm off-white stack (`#FBFBFA` / `#F7F6F3` / `#EAEAEA` / `#E8E7E3`) — distinctive from the cool-gray default most dashboards use. Pairs with cool silver for temperature contrast.
- **Silver signature** — NewEarth fingerprint via 4 modes: (A) hairline metallic border on premium cards, (B) top-edge stripe for hero surfaces, (C) universal silver hover ring (`#C0C3C7/40`), (D) silver section dividers. Uses CSS `mask-composite` for gradient borders.
- **Semantic color palette** — `#B42318 / #B54708 / #067647 / #175CD3` (Untitled UI family) replaces Tailwind defaults for enterprise-grade feel. Used ONLY for operational state signals (severity, confidence, variance, compliance) — never decoratively.
- **6 Hard Rules** (enforced by audit scripts):
  1. No `rounded-2xl` or `rounded-3xl` — cap at `rounded-xl` (12px)
  2. No `backdrop-blur-*` on content surfaces (glassmorphism ban)
  3. No emoji in UI copy, code, or commits
  4. No unsemantic color on Card components
  5. No `Inter`/`Roboto`/`Arial` as primary typeface — DM Sans default
  6. Dark mode required for every project
- **4 component templates** — Card (with `interactive` + `premium` props), KpiCard (hero number display with variance indicator), Drawer (shadcn-ui Sheet wrapper + collapsible DrawerSection), Badge (CVA with 6 semantic variants)
- **3 POSIX grep audit scripts** — `audit-forbidden-patterns.sh`, `audit-colors.sh`, `audit-hover-consistency.sh`. No ripgrep dependency — portable to any Unix. Validated against production codebase and caught 80+ real design debt items.
- **8 reference documents** — design-tokens, silver-signature, color-discipline, anti-vibe-coded (with Client Brand Override Protocol), component-recipes (11 patterns), composition-map, dark-mode, atelier-dark-preset
- **10 eval cases** — 7 should-trigger, 3 should-NOT-trigger

**Client Brand Override Protocol**: Hard Rules are agency DEFAULTS, not absolutes. When a client's documented brand guidelines legitimately conflict with a rule (e.g., client brand book requires `rounded-2xl` on CTAs as a signature element), override is allowed when documented in `clients/{slug}/design-overrides.md` with agency owner approval, scoped to that specific client.

**Composition with existing template skills** (explicit `do-not-trigger` entries):
- Generic Tailwind/shadcn work → use `tailwind-shadcn-system`
- Extract client brand colors from website → use `brand-visual-identity`
- General UI review with accessibility rules → use `design-review`
- Website SEO/legal/security audit → use `audit-website`
- Bold creative marketing hero direction → use `frontend-design` plugin

**When NOT to use**: Long-session operational dashboards where Atelier Dark would cause fatigue. Use default monochrome mode. Atelier Dark is reserved for proposals, hero pages, agency internal tools.

### NEW — `.claude/skills/lovable-to-vercel-migration/SKILL.md` (v2.1)

Complete Lovable-to-Vercel production migration protocol with zero-downtime DNS cutover. Previously battle-tested on BuyBox-AI (April 2026). Now includes:

- **Phase 1.3a Design System Preservation Check** — explicit pre-flight audit confirming `newearth-ui-design` files (tokens.css, component templates, audit scripts) are preserved through the migration untouched
- **Phase 5 Post-Migration Design Audit** — run the three newearth-ui-design audit scripts against the migrated codebase to establish a baseline and detect any migration-introduced design regressions
- **3 new anti-patterns** preventing design system edits during migration: editing tokens.css/component className during migration, fixing audit findings during migration, deleting `newearth-ui-design/` thinking it's Lovable-specific

Philosophy: migration is a CDN swap (deployment concern), not a redesign (source-code concern). They are orthogonal and must stay sequenced separately.

### UPDATED — `.claude/skills/skill-creator/SKILL.md` (Step 2 A.U.D.N.)

A.U.D.N. (ADD/UPDATE/DELETE/NOOP) decision check now MANDATES scanning BOTH the local `.claude/skills/` directory AND the template repo's `.claude/skills/` directory before concluding ADD. Previously the step only enumerated local skills, which meant skills could be built in a project without knowing they overlapped with template skills that bootstrap every future project.

**New decision thresholds:**
- >70% concept overlap with an existing skill (local OR template) → **UPDATE** that skill, do not ADD a new one
- 30-70% overlap → consider ADD with explicit `do-not-trigger` entries pointing at the overlapping skills
- <30% overlap → ADD is safe

Includes bash snippet for auto-resolving the template path from `.claude/template-source.md` and scanning both locations.

This rule was added in response to a real incident where a skill was built locally without scanning the template and turned out to overlap with three existing template skills, requiring extended council review (6 agents) to resolve. The cost of one minute of template scanning before writing prevents hours of refactoring afterward.

Synced from: Agency-Main (Nirvana project)

---

## 2026-04-13 — Council 5/8 upgrade + Obsidian Second Brain + vault-capture hook

- **UPGRADE** `.claude/rules/council-protocol.md` — Standard council 3→5 agents (added Capability Scout + Reliability Engineer). Extended 6→8. Added Stack-Aware Deliberation, No-Pre-Filter Discipline, Stack Reality + Operate-Cost sections in session docs.
- **UPGRADE** `.claude/skills/council/SKILL.md` — Updated all agent counts, config tables, synthesis templates (Stack Reality + Operate-Cost sections), confidence spread tables (5/8 columns).
- **NEW** `.claude/agents/council/capability-scout.md` — Gray lens: inventory-before-build, estimate translation, anchor-bias detection. BUILD cost discipline.
- **NEW** `.claude/agents/council/reliability-engineer.md` — Yellow lens: failure visibility audit, auth-refresh blast radius, MTTR, surface count delta, bus factor. OPERATE cost discipline.
- **NEW** `.claude/hooks/vault-capture.sh` — Stop hook: auto-captures session summaries to Obsidian vault daily notes. mkdir-based locking (macOS compatible), dedup protection, cold start counter, atomic append.
- **NEW** `.claude/skills/obsidian-second-brain/SKILL.md` — Core vault operations: path resolution, note search, frontmatter parsing, MOC updates, KI bridge. Backs /drift, /emerge, /graduate, /challenge, /trace, /vault-sync, /vault-review.

---

## 2026-04-13 — DigitalOcean infrastructure self-healing skill

- **NEW** `.claude/skills/digitalocean-infra/SKILL.md` — DigitalOcean droplet health diagnostics + self-healing (v1.0). 5 modes: health (default), metrics, remediate, snapshot, resize. SSH-based checks for disk, memory, Docker containers, n8n API, SQLite DB size, cron guards, firewall. 4 auto-remediation actions (container restart, disk cleanup, SQLite VACUUM, cron fix) with guards (retry limits, disk space checks). VPS Registry for multi-droplet support. Built from real 24h n8n outage incident (2026-04-13). Validation: 13/13 passed. Source: REWRITE of bobmatnyc/claude-mpm-skills digitalocean-management (F grade) + digitalocean-compute (F grade) via /skill-auditor-merger.
- **NEW** `.claude/skills/digitalocean-infra/evals/evals.json` — 6 evals (4 positive, 2 negative).

---

## 2026-04-09 — n8n Execute Workflow patterns + safe-bash v1.2

- **UPGRADE** `.claude/rules/n8n-patterns.md` — Merged Execute Workflow Node patterns from BuyBox field testing: workflowId `__rl` format, callerPolicy project ownership, flat-fields-only data passing, webhook `$json.body` gotcha. Kept template's PUT API and Platform Disambiguation sections. All IDs genericized.
- **UPGRADE** `.claude/skills/safe-bash/SKILL.md` — v1.1 → v1.2. Added Command Allowlist (5 categories), Dangerous Command Denylist (7 patterns), 3 inline task scripts, expanded metacharacter table (+heredoc, +newline), expanded audit log format (9 fields), Deterministic Artifacts section (JSON normalization + hash-based git commit), enhanced anti-patterns table.

---

## 2026-04-09 — Auto-reflect hookify rule + council Rumelt lens in SKILL.md

- **NEW** `.claude/hookify.auto-reflect.local.md` — Smart auto-reflect on session end. Fires on Stop event with a 2-of-6 trigger criteria gate: user corrections, new discoveries, significant code shipped, council sessions, stale memory detected, or explicit "remember" instruction. Skips trivial sessions (0-1 triggers). Runs full `/reflect` skill when 2+ triggers are met.
- **UPGRADE** `.claude/skills/council/SKILL.md` — Added Rumelt Strategy Lens to Phase 0 Reframer prompt (was in rules/council-protocol.md but missing from the skill's Reframer invocation template).

---

## 2026-04-07 — Deploy-Vercel skill + push gate hook + council Rumelt lens

- **NEW** `.claude/skills/deploy-vercel/SKILL.md` — 5-gate Vercel deploy pipeline (build → commit → push → preview → merge). Templatized for any Vercel-hosted project. Council-reviewed v2.0.
- **NEW** `.claude/hookify.deploy-gate-push.local.md` — PreToolUse warn hook on `git push`: reminds to confirm build passed, never push to main. Guidance only (not a block).
- **UPGRADE** `.claude/rules/council-protocol.md` — Added Rumelt Strategy Lens to Phase 0 Reframer (Diagnosis → Guiding Policies → Actions + Standard Kit Test).
- **UPGRADE** `.claude/hookify.playwright-full-page.local.md` — Richer guidance: added Playwright MCP matcher, "Better alternatives" list, "when fullPage IS appropriate" section.

---

## 2026-04-07 — Agent Research v2.1: field-tested verification fixes

- **UPGRADE** `.claude/skills/agent-research/SKILL.md` — v2.0 → v2.1. Merged 6 fixes from BuyBox field testing:
  - Worker type differentiation (Web Research, Codebase Analysis, Document Audit) with tool/output expectations
  - Verifier WebSearch fallback — can independently corroborate when cited URLs are blocked
  - SOURCED vs SYNTHESIS labeling — workers must distinguish citations from inferences
  - Source accessibility pre-flight — Lead checks for paywalled domains before routing workers
  - Output format variants — `GAP_TABLE` for plan verification, `BRIEF` for lookups
  - Confidence calibration rubric — HIGH=3+ sources, MEDIUM=1-2, LOW=inference (shared across workers)
  - 3 new anti-patterns added

Synced from: BuyBox-AI

---

## 2026-04-06 — Add audit-website + backend-to-frontend-handoff-docs skills, fix pydantic-ai paths

- **NEW** `.claude/skills/audit-website/SKILL.md` — 230+ rule website health audit (SEO, performance, security, accessibility, legal, E-E-A-T). SquirrelScan-powered. paths: `clients/**`
- **NEW** `.claude/skills/backend-to-frontend-handoff-docs/SKILL.md` — Structured API handoff docs for frontend integration (Supabase RPCs, Edge Functions, webhooks). paths: `clients/**`
- **FIX** `.claude/skills/pydantic-ai-agent-builder/SKILL.md` — Added missing paths: `**/*.py`

Synced from: Agency-Main

---

## 2026-04-05c — Shell injection in 5 skills: live system state before prompt

Added `!` backtick shell injection blocks to 5 high-value skills. Commands execute before the prompt reaches the model, injecting live git status, file metrics, and system state. Only works in local skills (MCP/plugin skills silently skip `!` blocks).

- **UPDATED** `.claude/skills/daily-plan-generator/SKILL.md` — date, git log, git diff/status, recent continuations
- **UPDATED** `.claude/skills/master-continuation-prompt/SKILL.md` — date, git log, git diff/status, current branch
- **UPDATED** `.claude/skills/compress-roadmap/SKILL.md` — ROADMAP line count, blockquote section count
- **UPDATED** `.claude/skills/refactor-memory-md/SKILL.md` — MEMORY.md line count, topic file count
- **UPDATED** `.claude/skills/refactor-claude-md/SKILL.md` — CLAUDE.md line count, rules file count

Security prerequisite: API keys migrated to macOS Keychain (2026-04-05b) — shell injection is safe because secrets are no longer in env vars.

Synced from: Agency-Main

---

## 2026-04-05b — MCP Keychain launcher: eliminate plaintext API keys from settings.json

Added `mcp-launcher.sh` — a single parameterized script that fetches API keys from macOS Keychain at MCP server startup instead of reading them from plaintext in `settings.json`. Supports env-based injection (Supabase, n8n, GitHub, Airtable) and arg-based injection (Redis, Wassenger) via `{{KEYCHAIN}}` placeholder. Graceful fallback for servers without keychain entries.

- **NEW** `.claude/mcp-launcher.sh` — Keychain-backed MCP server launcher. Eliminates all plaintext secrets from `~/.claude/settings.json`.

Security context: source audit found plaintext keys + `dangerouslySkipPermissions` + future shell injection = credential exfiltration vector. This migration is the prerequisite gate for shell injection in skills (`!` blocks).

Synced from: Agency-Main

---

## 2026-04-05 — Skills paths frontmatter: conditional skill activation based on file context

Added `paths` frontmatter to 8 domain-specific skills so they only surface when working on relevant files. Reduces skill listing noise and cognitive load. Based on Claude Code source audit finding: skills without `paths` are always visible; with `paths` they only activate when matching files are opened/edited.

- **UPDATED** `.claude/skills/landing-page-mvp/SKILL.md` — paths: `clients/**`
- **UPDATED** `.claude/skills/n8nspace/SKILL.md` — paths: `infrastructure/**`, `deployment/**`
- **UPDATED** `.claude/skills/postgresql-code-review/SKILL.md` — paths: `supabase/**`, `**/migrations/**`, `**/*.sql`
- **UPDATED** `.claude/skills/ssh-claude-setup/SKILL.md` — paths: `infrastructure/**`, `deployment/**`
- **UPDATED** `.claude/skills/tailwind-shadcn-system/SKILL.md` — paths: `clients/**/*.tsx`, `clients/**/*.jsx`, `**/*.css`
- **UPDATED** `.claude/skills/design-review/SKILL.md` — paths: `clients/**/*.tsx`, `clients/**/*.jsx`, `clients/**/*.html`
- **UPDATED** `.claude/skills/brand-visual-identity/SKILL.md` — paths: `clients/**`
- **UPDATED** `.claude/skills/better-auth-security/SKILL.md` — paths: `**/auth/**`, `**/better-auth/**`

Source: Claude Code source audit (35/50 lessons, 1,902 files) → 6-agent extended council → phased implementation. Paths use gitignore-style globs; `**` = unconditional (defeats purpose). Patterns generalized for template use.

Synced from: Agency-Main

---

## 2026-04-03 — Guided Tour skill: three-layer contextual guidance for React dashboards

- **NEW** `.claude/skills/guided-tour/SKILL.md` — Complete scaffolding skill for driver.js guided tours, SOP page guides, and info tooltips. Research-backed (Chameleon 550M, NNGroup, DISC psychology): 4-step micro-tours (74% completion), 9 guardrails (anchor polling, completion gating, force replay, iOS safety, double-tap guard, z-index management), 4 tour types (page, contextual, tab, demo), parameterized styling, and anti-pattern documentation.
- **NEW** `.claude/skills/guided-tour/evals/evals.json` — 8 evaluation cases (6 should-trigger, 2 should-not-trigger) covering page tours, demo tours, tooltips, SOPs, and completion rate optimization.

Synced from: nirvana-freight-fleet-insights-automation

---

## 2026-04-02 — Autonomous plan→council→execute→review pipeline

- **UPDATED** `.claude/hookify.auto-council-on-plan.local.md` — Rewritten from soft suggestion to mandatory 6-step autonomous pipeline. On ExitPlanMode: council --extended → /amend-plan → /execute → code review dispatch → commit/push → /e2e-test. User only approves the push; everything else runs autonomously.
- **UPDATED** `.claude/hookify.auto-review-on-execute.local.md` — Rewritten from optional review checklist to pipeline safety net. On Stop: verifies all 6 pipeline steps completed, resumes from where it left off if any were skipped.

Synced from: nirvana-freight-fleet-insights-automation (e34b5b6)

---

## 2026-04-01b — Hookify context injector: .local.md rules now actually fire

Root cause fix: 36 hookify `.local.md` rules existed but had no execution mechanism. The rules defined `addContext`/`warn` actions but nothing read them at runtime. Now they work.

- **NEW** `.claude/hooks/hookify-context-injector.sh` — Universal shell hook that scans all `hookify.*.local.md` files, matches on event type + tool name, and outputs matching rule content as stdout (which Claude Code injects as context). Supports glob/regex tool matchers and `|` alternation.
- **FIX** `.claude/hookify.task-context-injector.local.md` — `tool_matcher: Task` → `tool_matcher: Agent` (Claude Code uses "Agent" not "Task")
- **FIX** `.claude/hookify.auto-council-on-plan.local.md` — Softened from "MANDATORY" to "consider running" with skip criteria. Hard mandates cause friction; the hook provides context, Claude decides.
- **UPDATED** `.claude/HOOKS-AND-RULES-STANDARDIZATION.md` — Corrected architecture docs: Layer 1 (hookify rules) managed by `hookify-context-injector.sh`, not a plugin. Updated setup example with full `settings.local.json` registration for all matchers. Updated file tree.

**Setup required**: Register `hookify-context-injector.sh` in `settings.local.json` for each tool matcher (Bash, ExitPlanMode, Agent, mcp__supabase-*, mcp__n8n-mcp-*, mcp__github__*) and Stop event. See HOOKS-AND-RULES-STANDARDIZATION.md Step 3.

Synced from: NewEarth AI Agency — Main

---

## 2026-04-01 — Plan→Council→Review workflow automation

- **NEW** `.claude/hookify.auto-council-on-plan.local.md` — PostToolUse hook on ExitPlanMode that suggests running `/council --extended` to review the plan before implementation
- **NEW** `.claude/hookify.auto-review-on-execute.local.md` — Stop hook with smart dispatch review tree: detects changed file types via `git diff --stat`, dispatches 2-6 reviewers (always code-reviewer + silent-failure-hunter, conditionally adds SQL/security/design reviewers)
- **NEW** `.claude/commands/amend-plan.md` — `/amend-plan` command that bridges council session output to plan amendments, classifying recommendations as CRITICAL/SIGNIFICANT/MINOR and inserting machine-readable `[COUNCIL AMENDMENT]` markers

Synced from: NewEarth AI Agency — Main

---

## 2026-03-31 — Skill Synthesis: 11 elite skills replace 53 community installs

Source: 4 audit reports (code review, security, frontend, backend) + 6-agent extended council on skill awareness architecture.

**5 NEW master/merged skills** (each with companion awareness, evals, anti-patterns):
- **NEW** `.claude/skills/master-code-reviewer/` — Quantitative 10-point scoring, P0-P3 severity with deduction formula, LLM code smell detection, n8n impact analysis, SOLID review, Question Approach technique. With n8n-review.md reference.
- **NEW** `.claude/skills/master-security-review/` — Confidence-calibrated (HIGH/MEDIUM/LOW with suppression), 3 operating modes (secure-by-default, passive, full audit), 4-tier review (automated→pattern→data flow→architecture). With Supabase + n8n security reference files.
- **NEW** `.claude/skills/tailwind-shadcn-system/` — Four-Step CSS Architecture, v3→v4 migration table, OKLCH tokens, shadcn composition rules, RHF+Zod forms, WCAG thresholds.
- **NEW** `.claude/skills/design-review/` — Priority-weighted categories (CRITICAL→LOW), numeric thresholds (4.5:1 contrast, 44px touch, CLS<0.1), iterative screenshot→fix→verify loop.
- **NEW** `.claude/skills/brand-visual-identity/` — Manual token definition + automated Playwright extraction workflow, safety boundaries, multi-format output (CSS vars, Tailwind, JSON, python-pptx).

**6 IMPROVED independent skills** (Layer 0 trigger descriptions + Layer 1 upward pointers to masters):
- **UPDATED** `.claude/skills/postgresql-code-review/` — Added Supabase RLS patterns, auth.uid(), SECURITY DEFINER/INVOKER, upward pointer to master-code-reviewer.
- **UPDATED** `.claude/skills/requesting-code-review/` — Replaced embedded template with master cross-reference.
- **UPDATED** `.claude/skills/receiving-code-review/` — Added upward pointer, trigger boundaries.
- **UPDATED** `.claude/skills/security-threat-model/` — Added upward pointer to master-security-review.
- **UPDATED** `.claude/skills/better-auth-security/` — Added upward pointer, trigger boundaries.
- **UPDATED** `.claude/skills/security-scan-agentshield/` — Added upward pointer, orthogonal scope clarified.

**Companion awareness architecture** (council-approved): Every master skill has condition-action companion instructions. Every independent has an upward pointer. Skills form a coherent network, not a flat collection.

Synced from: Agency-Main (skill synthesis sprint)

---

## 2026-03-31 — Compact-reminder hook + hook efficiency standards

- **NEW** `.claude/settings.json` — Shared project hooks. First hook: PostToolUse on TaskUpdate — injects `/compact` reminder when a task is marked completed. Uses jq command (zero LLM tokens), 5s timeout, early-exit for non-completed updates.
- **NEW** `.claude/rules/hook-efficiency.md` — Standards for all hooks: minimal token footprint (jq > prompt > agent), narrow matchers, context injection over blocking, timeout discipline, optimal timing guidance, composability rules. Anti-pattern table for common mistakes.

Synced from: BuyBox-AI project

---

## 2026-03-31 — /reflect command with hook-worthiness gate

- **NEW** `.claude/commands/reflect.md` — Self-improvement reflection command with Step 3.5 hook-worthiness gate. Patterns scored 7+/10 on the matrix (irreversible, pre-exec, detectable, time-critical, not-covered) get proposed as hookify rules alongside expertise YAML entries. Prevents high-leverage learnings from becoming passive documentation when they should be active enforcement.

Synced from: nirvana-freight-fleet-insights-automation (b885926)

---

## 2026-03-27 — Daily Plan Generator v4.0: Continuation Scanning

- **UPDATED** `.claude/skills/daily-plan-generator/SKILL.md` — v3.1→v4.0: Step 1A (Continuation & Prompt Audit), Error Handling table, 4 new anti-patterns
- **UPDATED** `.claude/skills/daily-plan-generator/evals/evals.json` — 5→7 evals: continuation scanning + agent team

Synced from: [source project] (e866328)

---

## 2026-03-27 — Agentic loop guards, CLAUDE.md hierarchy standard, completion-verifier v2

Source: KI-TIER1 analysis of Claude Certified Architect Guide (relevance 0.86).

- **NEW** `.claude/rules/agentic-loop-guards.md` — Stop-reason inference table (transcript-based), pre-exit verification checklist, agent termination protocol (copy-paste block for agent definitions), broad-goal sub-agent principle with classification table. Prevents premature agent termination and unverified completion claims.
- **NEW** `.claude/rules/claude-md-hierarchy.md` — Documents the 3-layer CLAUDE.md standard: Layer 1 (root, <100 lines), Layer 2 (.claude/rules/), Layer 3 (specs/, disposable). Includes anti-patterns. Formalizes existing best practice as template standard.
- **UPDATED** `.claude/hookify.completion-verifier.local.md` — Added Section 0: Stop-Reason Inference before existing 5 checks. Detects truncation signals, unresolved tool errors, and incomplete multi-step plans. If truncation detected, skips verification checks and generates CONTINUATION NEEDED block instead.

## 2026-03-26 — /apply-insights friction eradication: 5 fixes from 110-session analysis

Council-reviewed (6-agent extended). From /insights analysis of 110 sessions, 37 wrong_approach events.

- **`.claude/rules/n8n-patterns.md`** — Added "Workflow PUT API Requirements" section (MUST include/strip fields, execution save settings, webhookId preservation, activation API). Added "Platform Disambiguation" section (n8n vs Make.com MCP tool separation). Prevents deployment failures and wrong-platform tool calls.
- **`.claude/rules/operational-guardrails.md`** — Added rule 8: Continuation file pre-check (MUST verify file exists before acting, ask user if missing). Added rule 9: Parallel session awareness (git log check before investigating). Prevents stalled sessions and duplicate investigation.
- **`.claude/hookify.auto-rules.local.md`** — Removed 5 phantom entries (referenced rules with no file on disk). Added 8 orphaned rules to reference table (audit-readonly-enforcer, n8n-code-escape-guard, n8n-http-error-handling, n8n-error-branch-required, e2e-suggest, mutation-verify-reminder, roadmap-multi-update). Removed context-hygiene phantom from Session Hooks.

## 2026-03-26 — Master Continuation Prompt v2.0 (prompt-forge principles)

### Updated
- **`.claude/skills/master-continuation-prompt/SKILL.md`** — v1.0 → v2.0: Applies prompt-forge research principles. Adds CLASSIFICATION block, Inference Audit (Step 1E), Layer Placement Triage (Step 1F), Decision Criteria (Section 4), Novelty Flags (Section 5), machine-checkable verification (Section 14), sub-agent context injection block. Philosophy rewritten with minimum sufficiency principle and three authority layers. Template expanded 12→14 sections. Output never duplicates CLAUDE.md content.

---

## 2026-03-26 — Skill Auditor & Merger (external skill ingestion pipeline)

- **NEW** `.claude/skills/skill-auditor-merger/SKILL.md` — Level 4 Orchestration skill (431 lines). Ingests external skills from any source (local path, GitHub URL, npx, skills.sh), audits bidirectionally (AGAINST standards + FOR superior patterns), produces merged version better than both. 7-dimension scoring rubric, 7-action deterministic merge map (KEEP/UPGRADE/ABSORB/REWRITE/SUPPLEMENT/DROP/INCOMPATIBLE), batch mode with approval gate, preflight dependency check, overwrite guard, scoped auto-fix. Requires `skill-creator`.
- **NEW** `.claude/skills/skill-auditor-merger/evals/evals.json` — 5 eval cases (4 trigger, 1 negative).
- Council-validated: 6-agent extended council session confirmed architecture is sound, 3 critical safety fixes applied (preflight check, overwrite guard, auto-fix scope constraint).

## 2026-03-26 — Prompt Forge skill (enterprise-grade prompt transformation)

### New Skill
- **`.claude/skills/prompt-forge/`** — Transforms raw user intent into structurally optimal prompts for new Claude Code sessions. Encodes 5 principles, 9 structural components, and 8 failure mode prevention patterns from primary research (Anthropic docs, agentic patterns, community discoveries). Features: inference audit, strategic interview protocol, conditional component inclusion, minimum-sufficiency compression pass, quality scorecard. Supports 4 execution scales (single, sub-agents, agent-team, plan-then-execute) with auto-detection. Classification: capability-uplift. 423 lines, 5 evals.

### Files
- `.claude/skills/prompt-forge/SKILL.md` — Main skill
- `.claude/skills/prompt-forge/evals/evals.json` — 5 test cases (3 trigger, 2 negative)

Synced from: [source project] @ prompt engineering deep research session

---

## 2026-03-26 — Supabase/PostgreSQL skill suite (3 skills, 61 reference files)

### New Skills
- **`.claude/skills/supabase-postgres-best-practices/`** — Supabase official Postgres performance rules. 34 reference files across 8 categories (query, connections, RLS, schema, locking, data access, monitoring, advanced). Adapted with v4.0 frontmatter, classification, and scope boundaries.
- **`.claude/skills/postgresql-patterns/`** — Query patterns, anti-patterns, and code review checklists. 12 reference files covering JSONB, arrays, window functions, FTS, CTEs, custom types, index strategies, EXPLAIN analysis, and schema/security/function review checklists. Merged from `postgresql-optimization` + `postgresql-code-review` (GitHub/awesome-copilot).
- **`.claude/skills/postgresql-internals/`** — Deep PostgreSQL engine internals. 15 reference files covering process architecture, memory management, MVCC/VACUUM, WAL/checkpoints, replication, storage layout, monitoring, backup/recovery. Adapted from PlanetScale `postgres` skill with vendor content removed.

### Design Decisions
- **Nav-menu architecture**: Each SKILL.md is a ~200-token index pointing to on-demand reference files (not inlined). Saves 15,000+ tokens vs monolithic approach.
- **Explicit scope boundaries**: Each skill documents what it covers and what to use instead for adjacent needs. Prevents global skills from overriding project-specific rules.
- **Schema-agnostic**: Zero hardcoded project refs, table names, or credentials. Safe for all downstream projects.
- **Council-reviewed**: 6-agent Extended Council deliberated on consolidation strategy (session: `council/sessions/2026-03-26-supabase-skill-consolidation-plan.md`).

Synced from: [source project] @ skill consolidation session

---

## 2026-03-22 — Council v4.0 Phase 0 architecture + 4 dashboard skills

### Updated
- **`.claude/skills/council/SKILL.md`** — v3.0 → v4.0: Phase 0 Reframer architecture (runs FIRST in extended mode), AskUserQuestion for reframe approval, expanded context loading
- **`.claude/rules/council-protocol.md`** — Phase 0 context loading docs, reframe approval flow, session file structure

### New Skills
- **`.claude/skills/kpi-dashboard-design/`** — KPI framework: SMART criteria, 3-tier audience hierarchy, visualization patterns
- **`.claude/skills/build-dashboard/`** — Self-contained HTML dashboard builder with Chart.js
- **`.claude/skills/grafana-dashboards/`** — Grafana dashboard creation patterns
- **`.claude/skills/llm-monitoring-dashboard/`** — LLM usage monitoring: token/cost/latency tracking, multi-provider

Synced from: [source project] @ 4bb127a

---

## 2026-03-21 — Major sync: council agents, landing-page-mvp, hookify rules, community skills manifest

### New Skills
- **`.claude/skills/landing-page-mvp/`** — NEW (9 files). GSAP-powered cinematic landing page architect v2.2. 8 aesthetic presets (A-H) with coupled motion, color, and typography. Includes quality gate script, eval criteria, and full reference docs.

### Council Agents (5 expanded)
- **`devils-advocate.md`** — Expanded from 42→99 lines. Full analytical framework, communication guidelines, output structure.
- **`neutral-analyst.md`** — Added Council Synthesis Mode (confidence spread table, synthesis verdict). 72→88 lines.
- **`edge-case-finder.md`** — Expanded from 38→83 lines. 5-domain analytical framework, severity categorization.
- **`pragmatist.md`** — Expanded from 43→62 lines. Full "How You Communicate" section, 6-point analytical framework.
- **`optimist-strategist.md`** — Minor updates. Replaced "The Accelerant" with "The Invitation" section.

### Hookify Rules
- **`hookify.credential-access-guard.local.md`** — NEW. Blocks direct SELECT on credential/secret fields in any Supabase project. Generic pattern-based trigger.
- **`hookify.auto-rules.local.md`** — Updated session hooks and warning hooks sections.
- **`hookify.filesystem-safety.local.md`** — Reformatted with SMART WARN header, clearer Always Permitted section.
- **`hookify.supabase-destructive-sql.local.md`** — Upgraded to checklist format with self-validation.
- **`hookify.supabase-migration-safety.local.md`** — Interactive 8-item checklist format, clearer HARD STOP thresholds.

### Skills Updated
- **`n8nspace/SKILL.md`** — v2.0→v2.1. Added Section H (6-step health verification), enhanced anti-patterns (16 total), generalized VPS registry with placeholders.
- **`ssh-claude-setup/SKILL.md`** — Added org_slug parameter, generalized launchd references, improved API workflow phases.

### Commands Updated
- **`prime.md`** — Added agency/BRIEFING.md reference in core docs section.
- **`compress-roadmap.md`** — Minor timestamp update.
- **`council.md`** — Enhanced evidence reference for vault/ROADMAP integration.

### Other
- **`planning-protocol.md`** — Fully generalized from project-specific to template-ready. Generic technology layers, multi-stakeholder focus, placeholder patterns.
- **`skills-lock.json`** — NEW. Community skills manifest (13 skills from 5 GitHub repos: marketing, design, UI/UX, Playwright, superpowers).
- **Source**: [source agency hub]. Hub vs template distinction applied — hub-specific items excluded.

---

## 2026-03-21 — Shell hook hardening: cwd anchor + PATH safety + background git block

- **`.claude/hooks/bash-guardian.sh`** — 3 additions: (1) cwd anchor via `git rev-parse --show-toplevel` so git checks work regardless of subprocess working directory, (2) `PATH` export for `jq` availability under `set -e`, (3) NEW block: git working-tree commands in background mode (prevents index corruption from parallel git processes). Also blocks `git status -uall` (memory explosion).
- **`.claude/hooks/commit-guardian.sh`** — cwd anchor + PATH safety. No logic changes — existing staged-file checks now work correctly when hook runs from non-root cwd.
- **`.claude/hooks/sql-guardian.sh`** — cwd anchor + PATH safety. No logic changes. Keeps generic `*execute_sql*` tool matcher (works with any Supabase project).
- **`.claude/hooks/session-summarizer.sh`** — cwd anchor + PATH safety. Replaced fragile `SCRIPT_DIR` derivation with `git rev-parse --show-toplevel`. Removed emoji from warnings for cleaner cross-platform output.
- **Source**: [source project] — production git incidents. Extended council session (6 agents) reviewed and approved all changes.

---

## 2026-03-15 — Daily Plan Generator v3.1: Council-reviewed quality fixes

- **`.claude/skills/daily-plan-generator/SKILL.md`** — v3.0 → v3.1. Three improvements from extended council session (5 agents):
  - **ROADMAP staleness warning** (Step 1): Detects when ROADMAP.md commit age diverges 3+ days from overall repo activity. Warns user that plan may not reflect current work state. Catches repos where ClickUp/external tracker is SOT but ROADMAP feeds the plan.
  - **Vault Pulse project filter** (Step 1B.2): Added `entity_slug` filter to vault deposit query. Previously showed deposits from ALL projects regardless of context — created false urgency.
  - **Scoring tiebreaker** (Step 3): When scores are within 5 points, prefer the task in the project with higher completion %. Consistent with existing >80% completion bonus. Eliminates arbitrary ordering at the 64-65 point boundary.
- **Source**: Agency-Main extended council session `council/sessions/2026-03-15-daily-plan-skill-perfection.md` (5 agents, unanimous on all 3 fixes)

---

## 2026-03-14 — Council v3.0: 6th agent (Reframer) + token efficiency upgrades

- **`.claude/agents/council/reframer.md`** — NEW. The Reframer: questions whether the proposal is asking the right question. Catches proxy metric drift, sunk cost framing, scope collapse, reversibility misclassification. 4-axis framework (upstream audit, metric validation, scope diagnosis, reversibility). Anti-pattern guard: "Don't reframe for sport."
- **`.claude/agents/council/devils-advocate.md`** — Compressed from ~100 lines to ~45. Same 5 analytical axes, denser format. Added confidence % mandate.
- **`.claude/agents/council/neutral-analyst.md`** — Removed "Council Synthesis Mode" section (synthesis is main Claude's job per SKILL.md Step 3, not the agent's). Added confidence % mandate.
- **`.claude/agents/council/optimist-strategist.md`** — "The Invitation" → "The Accelerant" (highest-ROI next action). Added confidence % to Key Assumptions.
- **`.claude/agents/council/pragmatist.md`** — Added Communication Style section requiring specific numbers (hours, dollars, dependencies). Added confidence % mandate.
- **`.claude/agents/council/edge-case-finder.md`** — Added confidence % mandate and cross-agent awareness.
- **`.claude/skills/council/SKILL.md`** — v2.1 → v3.0. Extended council 5→6 agents. Added OUTPUT CONSTRAINT (1 conclusion + 1 question per agent). Added FRAME CHECK synthesis section. Added 72-HOUR ACTION BRIEF appendix. Confidence spread table now 6 columns.
- **`.claude/rules/council-protocol.md`** — Extended council 5→6 agents. Added Reframer row (Teal, Frame validity).

## 2026-03-14 — Auto-rules truthfulness fix + commit-guardian.sh upgrade

- **`.claude/hookify.auto-rules.local.md`** — UPDATED. Removed 5 phantom entries (documented rules with no files): `context-hygiene`, `github-local-first`, `commit-quality-gate`, `plan-quality-gate`, `memory-freshness`. Added `e2e-suggest` to Context Hooks. Moved `commit-guardian.sh` to Shell Hooks (was incorrectly in Block Hooks — it's a shell script, not a hookify rule). Removed dead `{{ACTIVE/BLOCKED_MCP_SERVERS}}` template variables. Added Block Hooks — Disabled section for `mcp-server-guard`.
- **`.claude/hooks/commit-guardian.sh`** — UPDATED. Broader file type coverage (all files, not just JS/TS). Added credentials/secrets file detection. Fixed self-referential false positive via `-- ':!*.sh'` pathspec exclude. Restructured checks: .env → secrets → debug artifacts → large files.

## 2026-03-13 — Refactor Memory MD v1.0: Memory system optimization skill

- **`.claude/skills/refactor-memory-md/SKILL.md`** — NEW. 7-step memory system audit and refactoring workflow. Addresses MEMORY.md's 200-line silent truncation limit. Audits 5 dimensions (frontmatter quality, freshness, duplication, type correctness, actionability). Cross-references against CLAUDE.md and rules files to eliminate duplicate content. Archive policy (never delete, move to `memory/archive/`). Type-aware staleness (feedback/user = durable, project/reference = decay). Targets ≤150 lines with 50-line growth buffer.
- **`.claude/skills/refactor-memory-md/evals/evals.json`** — NEW. 5 eval cases (3 should-trigger, 2 negative).
- **`.claude/commands/refactor-memory-md.md`** — NEW. `/refactor-memory-md` slash command.

## 2026-03-13 — Council Skill v2.1: Auto-detect proposal + quality mandate support

- **`.claude/skills/council/SKILL.md`** — v2.0 → v2.1. Auto-detect proposal from conversation context instead of always asking. Added quality mandate auto-apply support (reads project-specific council quality mandate memory if one exists). Prevents unnecessary "What should the council evaluate?" prompts when the answer is obvious from the preceding message or active plan.

## 2026-03-12 — daily-plan-generator v3.0: Vault Pulse + skill-creator compliance

- **`.claude/skills/daily-plan-generator/SKILL.md`** — Upgraded v2.0 → v3.0. Added Vault Pulse section (Step 1B: Obsidian Second Brain health check with cadence tracking). Added `allowed-tools`, `user-invocable`, `classification` frontmatter fields per skill-creator v4.0 standards. Fixed vague term ("appropriate" → concrete instruction). Added `vault_pulse_enabled` and `vault_cadence_file` parameters. Added 4 Vault Pulse anti-patterns. Updated validated_on with Obsidian scenarios.
- **`.claude/skills/daily-plan-generator/evals/evals.json`** — NEW. 5 eval cases (3 should_trigger, 2 should_not_trigger) per skill-creator Level 4 Orchestration requirements. Tests: first-run generation, resume existing plan, Vault Pulse integration, negative cases for implementation requests and /prime boundary.

## 2026-03-12 — Diagram Skill v1.2: containerId Ban, Render Blocker, Spacing Formula

Fixes three quality gaps discovered when generating a comprehensive 30+ element architecture diagram.

### Changed Files
- **`.claude/skills/diagram/SKILL.md`** — v1.1 → v1.2
  - **New Step 7**: Multi-Section Spacing Formula — Y-band allocation rules for vertical multi-section layouts
  - **Render-validate upgraded to BLOCKER**: Must complete before presenting diagram to user (was just "MANDATORY" suggestion)
  - **`containerId` banned**: Added to anti-patterns — use free-floating positional text instead (containerId silently fails to render when shape dimensions are too small)
  - **Fixed render command**: `uv run python` → `python3`
  - **Removed stale checklist item**: Text-container bidirectional binding replaced by "No containerId" rule

---

## 2026-03-10b — SSH Claude Setup Skill: Remote Execution via n8n

Adds the SSH remote execution setup skill for connecting Macs to n8n via reverse SSH tunnels through a VPS.

### New Files
- **`.claude/skills/ssh-claude-setup/SKILL.md`** — 7-phase setup guide: preflight checks, port assignment, VPS config, reverse tunnel, launchd persistence, n8n credential, workflow integration, e2e testing
- **`.claude/skills/ssh-claude-setup/evals/evals.json`** — 3 eval cases (setup, troubleshooting, negative)

### Key Features
- **Full architecture**: n8n Docker → VPS host → reverse tunnel → Mac → Claude Code
- **Security**: UFW rules block public access, only Docker subnet can reach tunnel ports
- **Persistence**: launchd plist with KeepAlive + RunAtLoad + AUTOSSH_GATETIME=0
- **Troubleshooting**: 8 common issues with fixes, debug command reference
- **10 anti-patterns**: Docker localhost confusion, tunnel binding, n8n SSH field names, bot loops
- **Generalized**: All project-specific IPs, URLs, workflow IDs use `{{placeholders}}`

---

## 2026-03-10 — Council v2.0: Extended Mode (5-Agent) + Failure Conditions in Plans

Upgrades the council from 3 fixed agents to 3-5 agents with `--extended` flag. Adds Failure Conditions section to the `/plan` template for bidirectional "done" verification.

### New Files
- **`.claude/agents/council/pragmatist.md`** — Orange lens agent: execution reality, shipping velocity, resource constraints
- **`.claude/agents/council/edge-case-finder.md`** — Purple lens agent: specific failure modes, boundary conditions, silent failures

### Updated Files
- **`.claude/skills/council/SKILL.md`** — v1.0 → v2.0: `--extended` flag, 5-agent config, auto-suggest for high-stakes proposals, extended synthesis format (EXECUTION REALITY + CRITICAL EDGE CASES + 5-column confidence spread)
- **`.claude/skills/council/evals/evals.json`** — 8 → 12 evals: extended invocation, extended debate, auto-suggest triggers, no-save with extended
- **`.claude/rules/council-protocol.md`** — Added Extended Council section, 5-agent table, `/council --extended` in tool differentiation
- **`.claude/commands/plan.md`** — Added Failure Conditions section to plan template (between Acceptance Criteria and Confidence Score)

### Key Features
- **Extended mode** — `--extended` flag adds Pragmatist + Edge Case Finder for 5-agent deliberation
- **Auto-suggest** — Detects high-stakes proposals (implementation, budget >$500, architecture) and suggests extended mode
- **Role boundary** — Edge Case Finder complements (not duplicates) Devil's Advocate: implementation-level fault injection vs strategic risk
- **Failure Conditions** — Plans now define explicit "FAILS IF" criteria for bidirectional done verification

---

## 2026-03-06b — AI Council: Multi-Perspective Deliberation Engine

New `/council` command and skill that gathers 3 council agents (Optimist Strategist, Devil's Advocate, Neutral Analyst) for structured multi-perspective evaluation. Built with skill-creator v4.0 pipeline (100% eval pass rate, blind comparison 29/30 vs 12/30 base).

### New Files
- **`.claude/agents/council/devils-advocate.md`** — Red lens agent: stress-tests assumptions, surfaces blind spots
- **`.claude/agents/council/optimist-strategist.md`** — Green lens agent: maps upside potential, success conditions
- **`.claude/agents/council/neutral-analyst.md`** — Blue lens agent: synthesizes perspectives, produces confidence spread
- **`.claude/skills/council/SKILL.md`** — Orchestration skill with 3 modes: standard (parallel eval), debate (agents challenge each other), premortem (assume failure, work backward). Classification: capability-uplift.
- **`.claude/skills/council/evals/evals.json`** — 8 eval cases (5 positive + 3 negative boundary tests)
- **`.claude/commands/council.md`** — Command entry point with mode detection from argument prefix
- **`.claude/rules/council-protocol.md`** — Protocol documentation: when to use, tool differentiation, session format
- **`council/sessions/.gitkeep`** — Session persistence directory (default ON, `--no-save` to skip)

### Key Features
- **Parallel agent execution** — all 3 agents launched simultaneously in fresh context windows
- **Structured synthesis** — consensus, divergence, confidence spread table, integrated recommendation
- **Session persistence** — full deliberation audit trail in `council/sessions/YYYY-MM-DD-slug.md`
- **Tool differentiation** — clear boundaries with `/challenge` (single belief), `/agentresearch` (research), `/build-with-agent-team` (coding)

---

## 2026-03-06 — Apply-Insights Skill: Post-/insights Friction Eradication Engine

New skill and command for systematically turning `/insights` friction data into shipped fixes. Built with skill-creator v4.0 methodology (A.U.D.N., classification, evals).

### New Files
- **`.claude/commands/apply-insights.md`** — Lightweight `/apply-insights` command trigger (30 lines)
- **`.claude/skills/apply-insights/SKILL.md`** — Full 4-step AUDIT→ANALYZE→IMPLEMENT→PROPAGATE methodology (433 lines). Includes scope filter (hub/app/client repo awareness), impact scoring formula, enforcement layer decision tree, 9 anti-patterns, and template propagation protocol.

### Key Features
- **Scope filter** (Step 2-PRE) — prevents cross-repo contamination when insights spans multiple projects
- **Infrastructure audit** (Step 1) — finds dead hooks, orphaned rules, broken registrations before touching insights data
- **Impact scoring** — `(Frequency × Severity) ÷ Effort × template_multiplier` with configurable threshold
- **Enforcement layer decision tree** — always selects cheapest effective layer (settings.json → shell hook → hookify → rules file)
- **Template propagation** (Step 4) — generalizes and pushes fixes via `/push-to-template`

---

## 2026-03-05c — Unified Skill-Creator Suite v4.0: Evals, Benchmarks, Classification

Major upgrade merging the official Anthropic skill-creator evaluation framework with the existing custom A.U.D.N. lifecycle. Adds rigorous testing, blind comparison, iterative description optimization, and dual-skill classification.

### Updated Files (Skill Core)
- **`.claude/skills/skill-creator/SKILL.md`** — v3.0 to v4.0. Unified 8-step workflow: Extract Pattern, A.U.D.N. Decision, Classify Skill (NEW), Generate Skill, Write Evals (NEW), Test & Benchmark (NEW), Validate & Confirm (merged), Store. Added dual-skill classification (Capability Uplift vs Encoded Preference), eval development guide, benchmark mode, description optimization loop, quick commands table.
- **`.claude/skills/skill-creator/ABSTRACTION_RULES.md`** — v3.0 to v4.0. Added "Skill Classification & Eval-Informed Abstraction" section with failure-to-fix mapping table, decommissioning guidance for Capability Uplift skills.
- **`.claude/skills/skill-creator/TEMPLATES.md`** — v4.0 to v5.0. Added eval template (evals.json scaffold), benchmark results template, eval writing rules (discriminating expectations, concrete assertions).

### New Files (Evaluation Scripts)
- **`.claude/skills/skill-creator/scripts/utils.py`** — Shared utilities: `claude -p` CLI runner, frontmatter parser, trigger detector, stats calculator
- **`.claude/skills/skill-creator/scripts/run_eval.py`** — Parallel eval execution via `claude -p` with stream-json output parsing
- **`.claude/skills/skill-creator/scripts/run_loop.py`** — Iterative optimization loop with stratified train/test split
- **`.claude/skills/skill-creator/scripts/improve_description.py`** — Description optimization using `claude -p` CLI (adapted from Anthropic's direct SDK approach)
- **`.claude/skills/skill-creator/scripts/aggregate_benchmark.py`** — Benchmark aggregation with mean/stddev/min/max stats
- **`.claude/skills/skill-creator/scripts/generate_report.py`** — Dark-themed HTML report generator for optimization loop results
- **`.claude/skills/skill-creator/scripts/quick_validate.py`** — Schema validation supporting 18 frontmatter fields (6 Anthropic + 12 extended)
- **`.claude/skills/skill-creator/scripts/__init__.py`** — Package init

### New Files (Eval Viewer)
- **`.claude/skills/skill-creator/eval-viewer/viewer.html`** — Drag-and-drop JSON result viewer (dark theme, client-side JS, no server needed)
- **`.claude/skills/skill-creator/eval-viewer/generate_review.py`** — Review HTML generator from grading/comparison/eval results

### New Files (Reference)
- **`.claude/skills/skill-creator/references/schemas.md`** — JSON schemas for 8 data formats: evals.json, grading.json, metrics.json, timing.json, benchmark.json, comparison.json, analysis.json, history.json

### New Files (Agents)
- **`.claude/agents/skill-creator/grader.md`** — Evidence-based eval output grading (7-step process, PASS/FAIL with burden of proof)
- **`.claude/agents/skill-creator/comparator.md`** — Blind A/B comparison (Content + Structure rubric, 1-5 scoring)
- **`.claude/agents/skill-creator/analyzer.md`** — Post-hoc analysis with prioritized improvement suggestions by category

### Key Capabilities
- **Dual-Skill Classification**: Capability Uplift (model can't do consistently) vs Encoded Preference (needs workflow fidelity)
- **Multi-Agent Evaluation**: Grader grades, Comparator compares blind, Analyzer recommends improvements
- **Benchmark Tracking**: Pass rate, elapsed time, token usage across multiple runs
- **Description Optimization Loop**: Iterative eval/improve/re-eval with train/test split to prevent overfitting
- **CLI-First Execution**: All scripts use `claude -p` CLI (no direct API keys needed)
- **Static HTML Viewer**: Results as HTML opened with macOS `open` command (no server)

### Design Notes
- Merge strategy: Verification Supremacy (Anthropic's testing standards) + Workflow Sovereignty (custom A.U.D.N. lifecycle, abstraction rules, templates)
- All 17 files are fully project-agnostic — zero hardcoded IDs, client names, or MCP server names
- `validate.sh` (existing) is unchanged — still used for abstraction quality checks (Python scripts don't cover this)
- Skills using the framework store evals at `{skill-dir}/evals/evals.json` and benchmarks at `{skill-dir}/benchmarks/`

Synced from: [source agency hub]

---

## 2026-03-05b — Bash Guardian: Case-Insensitive Pattern Matching

### Updated Files
- **`.claude/hooks/bash-guardian.sh`** — Added uppercase conversion (`tr '[:lower:]' '[:upper:]'`) for case-insensitive destructive pattern matching. Commands like `RM -RF` or `Git Push --Force` are now caught. +3 lines.

Synced from: [source agency hub]

---

## 2026-03-05 — Insights Friction Eradication (Session Integrity + Operational Guardrails)

Based on analysis of 104 Claude Code sessions identifying 22 wrong-approach events, 4+ tooling failures, and 2+ context-loss incidents.

### New Files
- **`.claude/rules/operational-guardrails.md`** — 7 rules preventing wrong-first-approach: directory verification, column name verification, git state verification, n8n JSON format, template genericity, continuation prompt taxonomy. Loaded automatically every session as ambient context.
- **`.claude/hookify.completion-verifier.local.md`** — Stop event hookify rule forcing Claude to self-verify claimed work before session exit. Checks git state, deployment success, continuation accuracy, and memory updates. Prevents silently-failed operations from propagating as "complete" across sessions.

### Updated Files
- **`.claude/hooks/session-summarizer.sh`** — Added git state verification block (+27 lines): captures uncommitted changes and unpushed commits at session end, writes warnings into session summary file for next-session awareness.
- **`.claude/hookify.auto-rules.local.md`** — Added completion-verifier to Session Hooks table. Added Shell Hooks reference table documenting bash-guardian, sql-guardian, and session-summarizer registration in settings.local.json.

### Design Notes
- Operational guardrails is a RULES file (ambient context), not a hookify rule. It prevents Claude from starting in the wrong direction, rather than catching mistakes after they happen.
- Completion verifier complements (not replaces) the session-summarizer shell hook: summarizer captures state passively for the next session; verifier forces active self-audit in the current session.
- Item 8 (stack awareness) is intentionally omitted from template — it's project-specific.

---

## 2026-03-04b — E2E Test v1.2: Zero-Permission Model + n8n Parallel Branch Warning

### Updated Skills
- **UPDATED** `.claude/skills/e2e-test/SKILL.md` (v1.1 → v1.2, 451 → 463 lines). Two categories of changes:
  - **Permission Model** — New section at top of skill enforcing zero-permission execution. E2E tests run autonomously without any user prompts: no permission to navigate/click/screenshot, no "should I proceed?" between journeys, no pause on failures. 6 locations updated throughout the skill to replace "ask user" patterns with "log and continue" behavior. Rationale: e2e tests are invoked as part of approved plan execution — the user consented by running `/e2e-test`.
  - **Safety Boundaries** — "DIAGNOSE + ASK" changed to "DIAGNOSE + REPORT" for code defects. Code defect handler now marks step as FAILED and continues instead of pausing for user approval. Data precondition failures SKIP the journey and log instead of asking.

### Updated Rules
- **UPDATED** `.claude/rules/n8n-patterns.md` (69 → 80 lines). Two critical additions:
  - **Code Node v2 return pattern fix** — `runOnceForEachItem` must return a SINGLE OBJECT (`return {json: {key: value}}`), NOT an array. Returning `[{json: ...}]` causes `"A 'json' property isn't an object"` error. This is a breaking change from v1 behavior.
  - **Parallel Branches Are Sequential** — New section documenting that n8n does NOT truly parallel-execute branches. First branch runs fully before second starts. "Fire-and-forget" parallel branches actually run LAST and can OVERWRITE final state. Solution: make status updates SEQUENTIAL in main path.

### Design Notes
- Zero-permission model is universally applicable — not project-specific. Any e2e test invoked via `/e2e-test` implies user consent.
- n8n parallel branch behavior is a platform-level gotcha discovered in production (status updates in parallel branch overwrote main path results).
- Both files contain zero project-specific content (verified: no hardcoded IDs, tool names, or domain references).

Synced from: [source project]

---

## 2026-03-04 — Presentation Skill: Professional Document Engine (Dual-Track HTML/PPTX)

New skill: **Presentation** — generates professional presentations, proposals, reports, SOPs, case studies, and more. Dual-track output: broadcast-quality single-file HTML and corporate Slide Master-linked PPTX.

### New Files

**Skill Core:**
- `.claude/skills/presentation/SKILL.md` — Core skill (361 lines, progressive disclosure)
- `.claude/commands/present.md` — `/present` slash command with 7 flags

**Reference Guides (loaded on-demand):**
- `.claude/skills/presentation/references/html-engine.md` — Single-file HTML presentation engine (keyboard nav, chapter sidebar, dark/light, responsive)
- `.claude/skills/presentation/references/pptx-engine.md` — PptxGenJS PPTX generation (Slide Masters, theme-linked, charts, tables)
- `.claude/skills/presentation/references/document-archetypes.md` — 7 document templates (Proposal, Audit Report, Feedback Report, Pitch Deck, SOP, Case Study, Executive Summary)
- `.claude/skills/presentation/references/brand-system.md` — Per-client brand configuration with image upload workflow, color extraction, co-branding
- `.claude/skills/presentation/references/design-principles.md` — Visual standards, typography, color theory, anti-patterns
- `.claude/skills/presentation/references/data-ingestion.md` — Multi-source data protocols (Supabase, n8n, project files, web, conversation)

**Scripts & Templates:**
- `.claude/skills/presentation/scripts/generate_pptx.mjs` — Working PptxGenJS generator (378 lines, JSON config input)
- `.claude/skills/presentation/scripts/package.json` — NPM config (pptxgenjs dependency)
- `.claude/skills/presentation/templates/base-presentation.html` — Broadcast-quality HTML template (659 lines)

### Key Capabilities

- **7 document archetypes** with predefined content structures
- **Dual-track output**: HTML (broadcast/digital) + PPTX (corporate/editable)
- **Brand system**: JSON config per client, image upload workflow, website scraping, co-branding
- **Data integration**: Pulls from Supabase, n8n, project files, web, conversation
- **Diagram integration**: Uses the diagram skill for visual slides (Excalidraw -> PNG -> embed)
- **PptxGenJS generator**: Slide Master-linked layouts, theme-aware colors/fonts, charts, tables
- **HTML engine**: Single-file portable, keyboard navigation, chapter sidebar, dark/light toggle

---

## 2026-03-03 — Hookify Plugin v0.1.2: Complete Engine Fix + Template-Source Table

### Plugin Fixes (`plugins/hookify/`)

This is a **complete re-fix** of the v0.1.1 patches from 2026-02-23, which were never properly applied to the plugin cache. A `/verify-hooks` audit found 25/27 rules silently failing due to 3 compounding bugs.

- **FIXED** `core/rule_engine.py` — Replaced `re.sub` wildcard matching with `fnmatch` (cleaner, tested). Added `_rule_matches` guard: rules with no `tool_matcher` AND no `conditions` correctly return `False` instead of `True`. Added operators: `regex` (alias for `regex_match`), `not_equals`, `contains_any`. `not_exists` now checks empty string too (not just `None`). `equals`/`not_equals` use `str()` coercion. Kept `context_rules` separation (addContext messages have no `**[name]**` prefix).
- **FIXED** `core/config_loader.py` — Simplified to single `event=` API (removed `events=` list — tool aliases are unnecessary since `tool_matcher` handles tool-specific matching). Added `conditions_combinator` extraction from flat YAML (handles `combinator: or` at indent >= 2 within list context). Improved error handling with specific exception types.
- **FIXED** `hooks/pretooluse.py` — Changed from `load_rules(events=['PreToolUse', 'bash', 'file'])` to `load_rules(event='PreToolUse')`. Tool-specific matching is correctly handled by `tool_matcher` in rules, not event aliases.
- **FIXED** `hooks/posttooluse.py` — Same simplification: `load_rules(event='PostToolUse')`.
- **FIXED** `hooks/stop.py` — Changed from `events=['Stop', 'stop']` to `event='Stop'` (case-sensitive).
- **FIXED** `hooks/userpromptsubmit.py` — Changed from `events=['UserPromptSubmit', 'prompt']` to `event='UserPromptSubmit'`.

### Hookify Rule Fixes

- **FIXED** `.claude/hookify.safe-bash-enforcer.local.md` — Removed double-escaped regex. Was: `"rm\\s+-rf\\s+..."` (quoted, `\\s` matches literal `\s`). Now: `rm\s+-rf\s+...` (unquoted, `\s` matches whitespace). This was causing the safe-bash-enforcer to silently miss destructive commands.

### New: Template-Source Managed Files Table

- **NEW** `.claude/template-source.md` now includes a complete TEMPLATE-MANAGED files table with 8 categories: Plugin Source Code, Shell Hooks, Hookify Rules, Commands, Skills, Rules, Other, and a PROJECT-SPECIFIC exclusion list. This enables `/push-to-template` and `/update-latest` to identify which files flow between projects and the template.

### Verification

All fixes verified with comprehensive Python test script: **33/33 tests passed, 0 failed**. Tests cover:
- All 5 event types load rules correctly
- All 9 block rules produce `permissionDecision: "deny"`
- OR combinator works (n8n-executions-full, n8n-fetch-blocker)
- Warn rules produce `systemMessage` without deny
- addContext rules match on `tool_matcher` alone
- Engine wildcard/glob/exact/OR matching

---

## 2026-03-02 — Excalidraw Diagram Skill: Visual Arguing Engine

### New Skills
- **NEW** `.claude/skills/diagram/SKILL.md` (v1.0, 402 lines) — Excalidraw diagram generator that produces `.excalidraw` JSON files with isomorphic visual patterns. Core philosophy: diagrams should ARGUE, not just DISPLAY — shapes mirror concepts (fan-out for distribution, convergence for aggregation, assembly line for pipelines).
  - **10 visual patterns**: Assembly Line, Fan-Out, Convergence, Tree, Spiral/Cycle, Side-by-Side, Cloud, Gap/Break, Network, Timeline
  - **Auto-detection matrix**: Keyword scoring recommends the right pattern from topic text
  - **4 audience levels**: Technical (system names, code artifacts), Business (outcomes, KPIs), Mixed, Layperson (analogies)
  - **3 depth tiers**: Simple (5-12 nodes), Standard (8-15), Comprehensive (15-30+ with mandatory evidence artifacts)
  - **Container discipline**: <30% of text in containers — free-floating text creates hierarchy through typography
  - **Evidence artifacts**: Dark-background code snippets, JSON examples, real system names (not placeholders)
  - **Multi-zoom architecture**: Level 1 summary → Level 2 section boundaries → Level 3 detail
  - **Large diagram strategy**: Section-by-section building with namespaced IDs to stay under 32K token limit
  - **Mandatory render-validate loop**: Playwright renders PNG, agent critiques layout, fixes issues (2-4 iterations)
  - **27-item quality checklist**: Depth, conceptual, container discipline, structural, technical JSON, visual validation

### New Commands
- **NEW** `.claude/commands/diagram.md` (167 lines) — 6-phase execution protocol: Topic Detection → Pattern Recommendation → Context Research → JSON Generation → Render-Validate Loop → Delivery. Supports `--type`, `--depth`, `--audience` flags.

### New Reference Files
- **NEW** `.claude/skills/diagram/references/color-palette.md` — Semantic color system: 10 shape colors (primary, start/trigger, end/success, warning, decision, AI/LLM, error), 5 text hierarchy levels, evidence artifact colors with syntax highlighting.
- **NEW** `.claude/skills/diagram/references/element-templates.md` — Copy-paste JSON templates for every element type: free-floating text, lines, marker dots, rectangles (hero/primary/secondary), ellipses, diamonds, arrows with bidirectional bindings, evidence artifacts. Includes binding checklist.
- **NEW** `.claude/skills/diagram/references/json-schema.md` — Excalidraw JSON format reference: root structure, base element properties, text/arrow/line specifics, appState, validation checklist.
- **NEW** `.claude/skills/diagram/references/render_excalidraw.py` — Playwright-based PNG renderer (170 lines). Validates JSON, computes bounding box, launches headless Chromium, exports SVG→PNG via Excalidraw's `exportToSvg()`.
- **NEW** `.claude/skills/diagram/references/render_template.html` — Browser template loading Excalidraw from esm.sh CDN. Defines `window.renderDiagram()` for the render pipeline.
- **NEW** `.claude/skills/diagram/references/pyproject.toml` — Python deps: `playwright>=1.40.0`, Python >=3.11.

### Design Notes
- Adapted from [coleam00/excalidraw-diagram-skill](https://github.com/coleam00/excalidraw-diagram-skill) with significant enhancements: visual type auto-detection (keyword matrix), audience adaptation, project-aware context research protocol, and the Napkin AI-inspired structured thinking approach.
- Context Research Protocol table is generic — projects customize it by mapping their architecture file paths.
- Output files are standalone `.excalidraw` JSON — drag into excalidraw.com or open in Obsidian Excalidraw plugin.
- Render pipeline requires one-time setup: `cd .claude/skills/diagram/references && uv sync && uv run python -m playwright install chromium`.
- All colors from single `color-palette.md` — swap it out for brand alignment across all diagrams.
- Zero project-specific content in template version (verified: no hardcoded IDs, tool names, or domain references).

Synced from: [source project]

---

## 2026-03-02 — n8nspace v2.0: Disk Space Manager + Autonomous Guard Script

### New Skills
- **NEW** `.claude/skills/n8nspace/SKILL.md` (v2.0) — Complete n8n disk space manager for Ubuntu VPS.
  - Supports Docker Compose AND bare Node.js runtimes (auto-detected in P2 preflight)
  - 7 sections: Preflight → Snapshot → Offenders → Cleanup → binaryData Reclaim → Env Var Audit → Cron Guard Check
  - **Emergency mode** (`emergency=true`): skip age-based cleanup, full purge with n8n stop/restart
  - **Dry-run mode** (`dry_run=true`): audit what WOULD be deleted without deleting
  - **Small disk auto-adjustment**: thresholds tighten to 70%/80% on disks < 50GB
  - Custom binaryData path detection via `N8N_BINARY_DATA_STORAGE_PATH` env var
  - Section G verifies autonomous cron guard is installed and healthy
  - 12 documented anti-patterns, safety contracts, confirmation gates
  - Validated on real incidents: 90% disk + 100% disk (9GB binaryData on 25GB)

### New Scripts
- **NEW** `.claude/skills/n8nspace/scripts/n8n-disk-guard.sh` — Standalone bash script for unattended disk protection.
  - Deploy to `/usr/local/sbin/` on any n8n VPS, schedule with cron
  - Modes: retention (age-based, default 24h), emergency (auto at >=95%), dry-run
  - Auto-detects Docker Compose vs bare Node.js runtime
  - Safety: path validation (must end in `/binaryData`), permission checks
  - Cleanup chain: journal vacuum → apt clean → docker prune → binaryData
  - JSON report output to `/var/log/n8n-disk-guard-report.json`
  - Mac SSH trigger: `ssh root@YOUR_IP "/usr/local/sbin/n8n-disk-guard.sh"`

### Updated Rules
- **UPDATED** `.claude/rules/n8n-patterns.md` (+22 lines). Two critical sections added:
  - **HTTP Request Nodes Are Data Sinks** — After inserting any HTTP node, audit ALL downstream `$json` refs. HTTP responses replace upstream data silently. One of the most common n8n failure modes.
  - **Node Naming (Immutable)** — Node names are permanent identifiers via `$('NodeName')`. Never rename, never version-suffix. Track versions inside node code comments.
  - Anti-patterns table: +2 rows (`$json.field` after HTTP Request, version numbers in node names)

### Updated Hooks
- **UPDATED** `.claude/hooks/bash-guardian.sh` (+2 lines). Added uppercase conversion for case-insensitive pattern matching. Minor wording improvements to block messages.

### Design Notes
- n8nspace is universally applicable — no hardcoded IPs, project names, or tool prefixes. Uses `YOUR_N8N_IP` placeholder in SSH examples.
- Guard script is fully parameterizable via env vars (THRESH_WARN, THRESH_EMERG, RETENTION_MINUTES, BINARY_DIR).
- Skill + script are complementary: skill for interactive deep investigation (Claude Code), script for unattended daily/hourly cron.

Synced from: [source project]

---

## 2026-02-27b — E2E Test Orchestrator v1.1: 5 Real-World Improvements

### Updated Skills
- **UPDATED** `.claude/skills/e2e-test/SKILL.md` (v1.0 → v1.1, 352 → 451 lines). Five improvements from first real-world test session:
  - **Navigate to Entity micro-pattern** — Search/filter → wait → snapshot → click uid → verify detail view. Max 5 cycles, then REPORT `navigation_failure`. Prevents 8+ cycle random-clicking waste (~500 token savings).
  - **Phase 3.5: Data Preconditions** — New phase between dev server and task list. Verifies test data exists via `{{db_tool}}` before browser testing. If data missing, reports + asks user. Degrades gracefully when DB unavailable (~1000 token savings from avoided empty-state cycles).
  - **Code Defect Diagnosis** — New self-healing branch: reads source at error location (1 file, max 100 lines), identifies root cause, REPORTs as `code_defect` with error/file/line/diagnosis/recommended_fix, ASKs user before editing. 4-tier safety: NEVER auto-fix DB/workflows, DIAGNOSE+ASK for code, AUTO-RETRY transients, ALWAYS REPORT mismatches.
  - **Journey Auto-Generation** — When no JOURNEYS file exists, Agent C generates up to 5 concrete journeys from codebase analysis. Prioritized: critical path → CRUD → navigation → edge cases → data display. Each includes name, URL, steps, DB checks, preconditions.
  - **Browser Backend Table Extracted** — 15-row operation mapping table moved to `BROWSER-BACKENDS.md` (loaded on demand). SKILL.md retains compact 3-line summary (~500 token savings per run).
- Anti-patterns table expanded: +2 rows (random clicking, missing test data), row 3 revised (silent auto-fix → diagnose + ask distinction).
- Core principle updated: `NEVER: modify source code` → `NEVER: auto-fix code without asking` + `ON FAILURE: diagnose, report, ask`.

### Updated Commands
- **UPDATED** `.claude/commands/e2e-test.md` — Phase list updated from 6 to 7 phases (Phase 3.5 added). Journey auto-generation and Navigate to Entity pattern noted.

### New Files
- **NEW** `.claude/skills/e2e-test/BROWSER-BACKENDS.md` — Extracted browser backend operation mapping (15-row table, 3 backends). Loaded on demand during Phase 1 pre-flight.

### Design Notes
- All changes are universally applicable — zero project-specific content (verified: no hardcoded IDs, tool names, or project references).
- Token budget impact: ~2000 token savings per run from browser table extraction + data preconditions + Navigate to Entity pattern.
- Self-healing now has explicit "diagnose + ask" tier for source code defects — the key gap from v1.0 was treating all failures as either auto-retry or report-only, with no middle ground for fixable code bugs.

Synced from: [source project]

---

## 2026-02-27 — Self-Healing E2E Test Orchestrator

### New Skills
- **NEW** `.claude/skills/e2e-test/SKILL.md` — Self-healing end-to-end test orchestrator (351 lines). 6-phase workflow: pre-flight checks, parallel research with 3 sub-agents, dev server management, task list creation, E2E test loop with DB validation, cleanup & structured report. Supports 3 browser backends (Chrome DevTools MCP, Playwright MCP, Vercel agent-browser CLI) with auto-detection. Self-healing decision tree auto-retries transient failures (stale selectors, timeouts, dialog interruptions) but NEVER modifies source code — report-only for managed platforms. Includes responsive viewport testing (mobile/tablet/desktop), token-efficient `--quick` mode (skips research, uses JOURNEYS file), and screenshot organization by journey/date. Skill-creator v3.0 compliant: 8 parameters with defaults, 6 anti-patterns, 4 held-out validations, zero hardcoded IDs.

### New Commands
- **NEW** `.claude/commands/e2e-test.md` — Run self-healing E2E tests. Flags: `--quick` (skip research), `--journey SLUG` (single journey), `--url URL` (override target), `--responsive` (viewport testing). Loads SKILL.md and discovers JOURNEYS files by convention.

### New Hookify Rules
- **NEW** `.claude/hookify.e2e-suggest.local.md` — PostToolUse `addContext` nudge when frontend files in `src/` are modified. Suggests running `/e2e-test --quick` after component, hook, context, or route changes.

### Design Notes
- SKILL.md is a Level 4 Orchestration Skill (skill-creator hierarchy) that composes browser-automation (atomic) + DB validation + report generation. References existing skills by path — doesn't duplicate.
- JOURNEYS overlay pattern: generic SKILL.md (template-pushable) + project-specific `JOURNEYS.{project}.md` (not synced). Projects without a JOURNEYS file get auto-discovery via Phase 2 sub-agents.
- Inspired by Cole Medin's e2e-test workflow but improved: 3-backend abstraction (vs 1), Supabase MCP (vs raw psql), report-only self-healing (vs auto-fix), JOURNEYS caching for 80% token savings, escalation routing to specialist debug commands.

Synced from: [source project]

---

## 2026-02-26 — Enhanced /prime, /plan, new /execute + session-state.env fix

### Updated Commands
- **UPDATED** `.claude/commands/prime.md` — Complete rewrite (18 → 91 lines). Now a 6-step progressive disclosure workflow: project structure (git ls-files + tree), core documentation (CLAUDE.md anchor, README, architecture docs), configuration files (package.json, tsconfig, etc.), key entry points (models, schemas, services), git state (log + status), session continuity (reads 2-3 recent SESSION-*.md). Includes explicit token guards: "Do NOT read files >200 lines in full." Produces structured report under 200 lines.
- **UPDATED** `.claude/commands/plan.md` — Major enhancement (44 → 98 lines). Now a 5-phase planning process: (1) Task Understanding — classify type, assess complexity, map components. (2) Codebase Intelligence — spawn Explore agents for parallel research. (3) External Research — Context7 MCP for library docs. (4) Strategic Questions — architecture impact, edge cases, security. (5) Write Plan — enriched template with Context References, Validation Commands, Acceptance Criteria, Confidence Score (N/10). Output to `specs/` (unchanged).

### New Commands
- **NEW** `.claude/commands/execute.md` — Plan-driven implementation executor. Reads a plan from `specs/` (defaults to most recent), creates TodoWrite checklist, executes steps sequentially with per-step validation, runs testing strategy, executes validation commands, checks ROADMAP for completed NOW items, produces completion report. Completes the PIV loop: `/prime` → `/plan` → `/execute`.

### Updated Shell Hooks
- **UPDATED** `.claude/hooks/session-summarizer.sh` — Two fixes: (1) Initialize `session-state.env` with `CLIENTUPDATE_PENDING=false` on first run — previously the file was only created when ROADMAP milestones changed, leaving Invariant 10C (daily-plan-generator) unable to read the flag. (2) Fix `grep -cE` integer expression bug — `|| echo "0"` produced "0\n0" when grep found zero matches; changed to `|| true` which lets grep's own "0" output through cleanly.

### Design Notes
- `/prime`, `/plan`, `/execute` form a complete PIV loop (Prime-Implement-Validate). Each command is self-contained and project-agnostic.
- `/plan` references Context7 MCP for external docs — skip that phase if Context7 is not configured.
- `/execute` references hookify rules in its final verification checklist — degrades gracefully if hookify is not installed.
- `session-state.env` fix is backward-compatible — existing conditional write logic (ROADMAP milestone detection) works unchanged.

Synced from: [source agency hub]

---

## 2026-02-25b — Verify Hooks v2 + Bash Guardian Shell Hook

### Updated Commands
- **UPDATED** `.claude/commands/verify-hooks.md` — Major rewrite (v1 → v2). Now 8 phases: escape hatch detection, deny list coverage, shell hook content validation, hookify enforcement classification, runtime Python verification, cross-layer coverage matrix, token efficiency analysis, auto-fix. Catches `Bash(bash -c:*)` escape hatches, empty deny lists, warn-only safety rules without hard backup.

### New Shell Hooks
- **NEW** `.claude/hooks/bash-guardian.sh` — Hard enforcement (exit 2) for destructive bash patterns: recursive force delete, git push force, git reset hard, git clean, kill -9, pkill/killall, .env modification, docker rm force, chmod 777. Zero tokens on permit. Complements sql-guardian.sh.

Synced from: [source project]

---

## 2026-02-25 — CLAUDE.md Refactor Skill + Rules Infrastructure + Quality Gates

### Key Insight
Anthropic officially warns: **"Bloated CLAUDE.md files cause Claude to ignore your actual instructions!"** Recommended ceiling is 80-100 lines. This update provides the tools and process for any project to self-refactor.

### New Skills
- **`refactor-claude-md/SKILL.md`** — Research-backed 6-step process for refactoring bloated CLAUDE.md files. Classifies every section (IDENTITY/CRITICAL RULES/REFERENCE MATERIAL), designs path-scoped `.claude/rules/` files, slims root to 80-100 lines. Encodes findings from 30+ sources so projects don't need to re-run research. Validated on a production project: 405 → 92 lines (77% reduction, ~40-50% session start token savings).

### New Commands
- **`/refactor-claude-md`** — Invoke the refactor-claude-md skill. Loads skill, follows Steps 1-6, reports before/after line counts.

### New Rules Files (`.claude/rules/`)
- **`file-editing.md`** — Pre-edit protocol (re-read before editing, verify columns, check existing implementations) + post-mutation protocol (document in fix-audit-trail, verify, log). Generic — no project-specific content.
- **`tool-fallbacks.md`** — MCP server → CLI fallback table (GitHub, Supabase, n8n). "If MCP returns auth error, immediately fall back to CLI — do not retry." Generic with placeholder server names.
- **`n8n-patterns.md`** — Execution mode selection, return pattern table, sandbox limitations, common anti-patterns. Universal n8n Code node safety rules.

### New Memory Templates (`.claude/memory/`)
- **`fix-audit-trail.md`** — Structured FIX-{NNNN} template for production mutation tracking. Captures before/after state, rollback commands, cross-references incidents. 14-day rolling archive.
- **`health-log.md`** — Append-only pipeline health table (canary results, verification runs). Zero ongoing token cost.
- **`incidents.md`** — Structured INC-{NNNN} incident entries with cross-references to FIX-IDs. Zero ongoing token cost.

### Updated Skills
- **`build-with-agent-team/README.md`** — Added Worktree Isolation section. Documents `isolation: "worktree"` in Task tool for parallel agent file conflict prevention. Includes when-to-use/skip guidance.

### Design Notes
- `/refactor-claude-md` is the key deliverable — encodes the PROCESS so every project gets the same surgical treatment without re-running research or reading the full insights report.
- Rules files are generic templates. Projects customize after `/update-latest` pulls them in. Path-scoped frontmatter (`paths: ["supabase/**"]`) is documented in the skill but not pre-applied to generic rules.
- Memory templates are empty structures — append-only, not auto-loaded into context.
- PostToolUse lint gate pattern (`npx tsc --noEmit` after Write/Edit) is documented in `file-editing.md` as a recommended hook, not auto-installed (project-specific `settings.local.json` concern).

Synced from: [source project]

---

## 2026-02-24 — n8n Code Node Return Pattern Guard

### New Hook
- **`hookify.n8n-code-return.local.md`** — PreToolUse warning hook that triggers when deploying n8n Code node code via Bash (detects `jsCode` in n8n API calls). Provides a return pattern reference table for both `runOnceForEachItem` and `runOnceForAllItems` modes. Key rule: never use `return [{json: $json}]` (sandbox proxy fails validation) — use `return $input.item` for pass-through.

### Updated
- **`hookify.auto-rules.local.md`** — Added `n8n-code-return` to Block Hooks table

---

## 2026-02-24 — ROADMAP Hierarchy + Daily Plan v2.0

### Breaking Change: ROADMAP Structure
ROADMAP.md now uses a 4-level hierarchy (System → Project → Milestone → Task) instead of flat NOW/NEXT/LATER/HORIZON lanes. This provides traceable work items where every daily plan step shows its full context chain.

**Migration**: If your project has an existing flat-lane ROADMAP, restructure it:
1. Identify 3-5 Systems (functional areas)
2. Map your items to Projects within those systems
3. Break projects into Milestones with progress % and Status (DONE/NEXT/LATER)
4. Add an End State table (what "done" looks like per project)

### Updated Skills
- **`daily-plan-generator`** v1.2 → v2.0 — Hierarchy context per step, complexity tags replace time estimates, 5-10 steps (was 2-4), project completion bonus (+10 for >80%), cross-chat awareness via `git diff`, resume-on-repeat via Step 0

### New Skills
- **`compress-roadmap/SKILL.md`** — Full parameterized skill (previously only command existed)

### Updated Commands
- **`/daily-plan`** v2.0 — Hierarchy context, complexity tags, "go team" option
- **`/compress-roadmap`** — Safety rules updated for hierarchy compatibility
- **`/setup`** Step 7.7 — ROADMAP wizard generates hierarchy structure with End State table

### Updated Hookify Rules
- **`roadmap-freshness`** — References projects/milestones instead of NOW/NEXT lanes

---

## 2026-02-23 — Hookify Plugin v0.1.1: Critical Bug Fix (7 Bugs, 13+ Rules Were Broken)

### What Was Broken
The hookify plugin v0.1.0 (shipped by Anthropic) had **7 bugs** that caused **~13 of 18 rules to silently fail**. No errors were visible — hooks exited with code 0 and returned empty JSON, so Claude proceeded without any rule enforcement.

**If your project uses hookify rules, they were almost certainly NOT running.**

### The 7 Bugs (All Fixed)

| # | Bug | Impact | Fix |
|---|-----|--------|-----|
| 1 | **Python import path broken** | ALL hooks fail with ImportError. Plugin cache layout puts version dir (`0.1.0/`) between package name and code, so `from hookify.core.X` never resolves. | Changed to `from core.X` (relative imports) |
| 2 | **No SessionStart handler** | `confident-mode`, `auto-rules` never fire | Added `sessionstart.py` + `hooks.json` entry |
| 3 | **Wildcard tool_matcher broken** | Rules with `mcp__n8n-mcp-*__*` or `mcp__supabase-.*__*` never match | Added glob→regex conversion in `_matches_tool()` |
| 4 | **Event name mismatch** | Handler passes wrong event names to `load_rules()` | All handlers now pass canonical + alias events |
| 5 | **No-conditions rules never match** | `addContext` rules (plan-mode-exit-gate, progress-logger) never fire | Changed: no conditions + tool_matcher match = True |
| 6 | **combinator: or not parsed** | `n8n-fetch-blocker`, `n8n-executions-full` OR conditions evaluated as AND | Parser promotes nested `combinator:` to top-level |
| 7 | **not_exists operator missing** | Conditions like "block if mode field doesn't exist" always return False | Added `not_exists` and `exists` operators |

### Rules That Were Broken (Now Fixed)

**Block rules (hard deny):**
- `safe-bash-enforcer` — rm -rf, git push --force, etc. (Bug #1, #3, #4)
- `n8n-fetch-blocker` — blocks mode=full on n8n get_workflow (Bug #1, #3, #6, #7)
- `n8n-executions-full` — blocks mode=full on n8n executions (Bug #1, #3, #6, #7)
- `n8n-use-essentials` — blocks get_node_info (Bug #1, #3)
- `n8n-workflow-delete-block` — blocks workflow deletion (Bug #1, #3)
- `mcp-server-guard` — blocks wrong-project MCP servers (Bug #1)
- `playwright-full-page` — blocks fullPage screenshots (Bug #1)

**Warn rules (system message):**
- `supabase-destructive-sql` — DELETE/TRUNCATE/DROP checklist (Bug #1, #3)
- `supabase-migration-safety` — migration review (Bug #1, #3)
- `filesystem-safety` — dangerous bash commands (Bug #1, #4)
- `github-local-first` — prefer local git over MCP (Bug #1)

**Context rules (addContext, inject guidance):**
- `confident-mode` — SessionStart permissions model (Bug #1, #2)
- `auto-rules` — SessionStart rule index (Bug #1, #2)
- `plan-mode-exit-gate` — ExitPlanMode checklist (Bug #1, #5)
- `plan-mode-enforcer` — UserPromptSubmit plan enforcement (Bug #1, #4)
- `progress-logger` — PostToolUse mutation logging (Bug #1, #5)

### Files Changed

| File | Change |
|------|--------|
| `plugins/hookify/core/rule_engine.py` | Wildcard matching, no-conditions guard, combinator OR, not_exists/exists operators, addContext action |
| `plugins/hookify/core/config_loader.py` | Multi-event loading, combinator field on Rule dataclass, nested combinator parsing |
| `plugins/hookify/hooks/pretooluse.py` | Import fix, multi-event loading, hook_event_name |
| `plugins/hookify/hooks/posttooluse.py` | Import fix, multi-event loading, hook_event_name |
| `plugins/hookify/hooks/userpromptsubmit.py` | Import fix, event name fix |
| `plugins/hookify/hooks/stop.py` | Import fix, multi-event loading |
| `plugins/hookify/hooks/hooks.json` | Added SessionStart handler |
| `plugins/hookify/hooks/sessionstart.py` | **NEW** — SessionStart handler |

### How to Verify After Applying

Run this verification (saves to /tmp, avoids hook-on-hook recursion):
```bash
python3 -c "
import sys, os
sys.path.insert(0, os.path.expanduser('~/.claude/plugins/cache/claude-code-plugins/hookify/0.1.0'))
os.chdir('.')  # your project root with .claude/ dir
from core.config_loader import load_rules
from core.rule_engine import RuleEngine
engine = RuleEngine()
ptu = load_rules(events=['PreToolUse'])
ss = load_rules(events=['SessionStart'])
print(f'PreToolUse rules: {len(ptu)}')
print(f'SessionStart rules: {len(ss)}')
for r in ptu:
    print(f'  {r.name}: tool_matcher={r.tool_matcher}, action={r.action}')
for r in ss:
    print(f'  {r.name}: action={r.action}, msg_len={len(r.message)}')
"
```

If `SessionStart rules: 0` or `PreToolUse rules: 0`, the fixes haven't been applied to the plugin cache. Copy the fixed files from `plugins/hookify/` to `~/.claude/plugins/cache/claude-code-plugins/hookify/0.1.0/`.

### How to Apply to Existing Projects

After `/update-latest` pulls these files, copy the fixed plugin code to the cache:
```bash
cp -R plugins/hookify/core/* ~/.claude/plugins/cache/claude-code-plugins/hookify/0.1.0/core/
cp -R plugins/hookify/hooks/* ~/.claude/plugins/cache/claude-code-plugins/hookify/0.1.0/hooks/
```

Then restart Claude Code for the fixes to take effect.

### Design Notes
- Import fix (`from core.X` vs `from hookify.core.X`) is specific to how Claude Code caches plugins. The cache layout `~/.claude/plugins/cache/{marketplace}/{plugin}/{version}/` puts a version directory between the package name and the code, breaking standard Python package imports.
- All fixes are backward-compatible — existing rule files don't need changes.
- The `combinator: or` parser fix handles both flat (`combinator: or` at top level) and nested (`combinator: or` indented under conditions block) YAML styles.
- `_matches_tool()` now handles 4 patterns: exact match, `|` OR, glob `*` (converted to `.*`), and explicit regex `.*`.

Synced from: [source project]

---

## 2026-02-23 — Master Continuation Prompt: Link + Micro-Prompt Pattern

### Updated Skills
- **`.claude/skills/master-continuation-prompt/SKILL.md`** — Enhanced Step 4 (Present & Confirm) section with token-efficient link + micro-prompt pattern. Added:
  - **Output Format subsection** — Markdown link template + hyper-micro prompt template (50-70 tokens)
  - **~40x efficiency explanation** — Link + micro-prompt fetches file on-demand, reducing initial message load vs pasting full 600+ line continuation
  - **Updated Presentation Template** — New "Next session workflow" guide showing how to paste link + micro-prompt at session start
  - **Alternative path** — Option to review file before starting new session
  - **Total change:** +27 lines | Version remains 1.0 (incremental enhancement)

### Design Notes
- Pattern tested in production: used for `AGENCY-OS-ARCHITECTURE-MASTER-CONTINUATION-2026-02-23.md` in agency hub
- Efficiency gain: initial message ~50 tokens (link + micro-prompt) vs ~2000 tokens (full continuation)
- File fetching is on-demand via Read tool in new session — no context overhead
- Hyper-micro prompt template is reusable across all continuation types

Synced from: [source agency hub]

---

## 2026-02-22 — Master Continuation Prompt Generator

### New Skills
- **NEW** `.claude/skills/master-continuation-prompt/SKILL.md` — Enterprise-grade continuation prompt generator with 12-section master template, 4 continuation types (master/phase/bug/planning), 5-step workflow, quality validation checklists, anti-patterns documentation, and session lifecycle integration. Produces self-contained handoff documents for new sessions.

### New Commands
- **NEW** `.claude/commands/Master-Continuation-Prompt.md` — Slash command (`/Master-Continuation-Prompt`) that invokes the skill. Supports arguments for scope override and continuation type. Integrates with `/daily-plan` (consumer) and `/reflect` (complementary).

### Design Notes
- Skill is fully project-agnostic — uses `{{db_tool}}`, `{{workflow_tool}}` placeholders throughout
- 12-section template adapts to any tech stack (skip irrelevant sections)
- Sits at end-of-session in lifecycle: `/Master-Continuation-Prompt` → `/reflect` → `/clientprojectupdate`
- Consumed by `/daily-plan` and `/prime` at session start

Synced from: [source project]

---

## 2026-02-22 — Confident Mode (Smart Permissions)

### New Hookify Rules
- **`hookify.confident-mode.local.md`** — `action: addContext` (SessionStart). Smart two-layer permission model that auto-allows safe operations (file ops, local git, MCP reads, web fetches) while requiring confirmation for destructive operations (rm -rf, git push, DROP/TRUNCATE, messaging, deployments). Replaces the need for `--dangerously-skip-permissions` with nuanced control.

### Updated Hookify Rules
- **`hookify.auto-rules.local.md`** — Added new "Session Hooks" table with `confident-mode` entry. All existing Domain/Block/Warning hooks unchanged.

### Updated Commands
- **`/setup`** Step 7.6.1 — Now generates comprehensive `settings.local.json` with both shell hooks AND confident-mode permissions (allow/deny patterns). Auto-detects MCP servers from `.mcp.json` and generates appropriate read-only allow patterns for each server type.
- **`/update-latest`** Step 5b2 — New post-install step for confident-mode. When `hookify.confident-mode.local.md` is applied, also adds permission patterns to `settings.local.json`.

### Updated Infrastructure
- **`.gitignore`** — Added `.claude/settings.local.json` (machine-specific, should not be committed), `.claude/sessions/`, `.claude/daily-plans/`.

### Design Notes
- Confident Mode is a **two-layer system**: (1) the hookify rule provides behavioral instructions to Claude, (2) `settings.local.json` provides actual tool-level enforcement via allow/deny patterns.
- The hookify rule is generic — no project-specific MCP server names. All server patterns use wildcards (`mcp__supabase-*__*`).
- `settings.local.json` is always gitignored and machine-specific. The `/setup` and `/update-latest` commands generate it dynamically from the project's `.mcp.json`.
- Safe operations (reads, local git, file ops) proceed without prompts. Destructive operations (push, delete, drop, deploy, message) always require confirmation. Grey zone operations (targeted DELETE with WHERE, push to feature branch) use judgment.
- Existing safety hooks (`sql-guardian.sh`, `safe-bash-enforcer`, block hooks) remain active as defense-in-depth. Confident mode does NOT bypass them.

---

## 2026-02-20 — Template Push + Enhanced Safety Rules

### New Skills
- **NEW** `.claude/skills/template-push/SKILL.md` — Fully autonomous push to template repo. 7-step workflow: config → detect changes → generalize → write → metadata → git commit+push → verify. Smart direction detection skips files where template is already ahead. Generalization rules for MCP names, NSM values, project IDs, timezone markers, domain terms.

### New Commands
- **NEW** `.claude/commands/template-push.md` — Invoke the template-push skill. Shows diff summary with approve/abort. Replaces manual git workflow from `/push-to-template`.

### Updated Hookify Rules
- **UPDATED** `.claude/hookify.supabase-destructive-sql.local.md` — Enhanced with Smart WARN format, numbered self-validation checklist (6 items), explicit Always Permitted section, sql-guardian.sh cross-reference.
- **UPDATED** `.claude/hookify.supabase-migration-safety.local.md` — Enhanced with Smart WARN format, expanded checklist (8 items with conditional sub-checks), HARD STOP conditions, PostgREST reload reminder with SQL code block.
- **UPDATED** `.claude/hookify.filesystem-safety.local.md` — Added `kill -9`/`pkill`, `docker rm -f` patterns. Added Always Permitted section (git reads, package management). Better self-validation format.

Synced from: [source project] (f41b593)

---

## 2026-02-20 — Agent Team Integration + Daily Plan v1.2

### New Skills
- **`build-with-agent-team`** — Parallel Claude instances in tmux panes with contract-first coordination. Includes Phase 0 pre-flight (5 checks: prerequisites, ROADMAP alignment, planning-protocol gate, memory/conflict check, cost estimate), auto-sizing heuristic, ROADMAP context wrapper for sub-agents, and Phase 5 post-implementation protocol.

### New Commands
- **`/build-with-agent-team`** — Invoke the build-with-agent-team skill. Takes plan path + optional agent count. Phase 0 pre-flight runs before spawning.

### Updated Skills
- **`daily-plan-generator`** v1.1 → v1.2 — Added Step 6: Agent Team Offer. When a plan has 2+ steps touching different layers, offers to launch `/build-with-agent-team` with the plan. Condition-gated to avoid offering for single-layer plans.

### Updated Commands
- **`/daily-plan`** v1.1 → v1.2 — Output section updated with agent team offer. `/build-with-agent-team` added to related commands.

### Design Notes
- `build-with-agent-team` requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `~/.claude/settings.json` and `tmux` installed.
- Hook inheritance is automatic — all project-level hookify rules fire in agent pane processes (separate Claude instances in same project directory).
- Auto-sizing: 1-2 component layers → 2 agents, 3-4 → 3, 5+ → 4 max.
- Plans passed to agent teams must include: tech stack, project structure, agent build order, cross-cutting concerns table, API contract, per-agent validation scripts, acceptance criteria, known gotchas.

---

## 2026-02-19 — Autonomous Workflow System

Added the full closed-loop autonomous workflow system. This is the most significant template update since the initial release.

### New Skills
- **`daily-plan-generator`** — Generates prioritized daily work plans from ROADMAP NOW/NEXT lanes, git history, and session state. Implements three design invariants: (A) silent strategy review, (B) agent research context wrapper, (C) cross-session client update flag.

### New Commands
- **`/daily-plan`** — Invoke the daily-plan-generator skill. Writes plan to `.claude/daily-plans/PLAN-{date}.md`, shows summary, waits for `go` to execute.
- **`/compress-roadmap`** — Archive stale completed items from ROADMAP.md when it grows beyond 500 lines. Moves `## Recently Completed` entries older than 30 days to `ROADMAP-ARCHIVE-{YEAR}-Q{N}.md`.
- **`/push-to-template`** — Copy TEMPLATE-MANAGED files from current project to the template repo. Generates a diff summary and CHANGELOG entry.
- **`/update-latest`** — Pull TEMPLATE-MANAGED file updates from the template repo into current project. Shows per-file diffs with approve/skip/customize options.

### New Hookify Rules
- **`hookify.supabase-destructive-sql.local.md`** — `action: warn`. Pre-flight checklist before every `execute_sql` call. Surfaces hard-stop conditions for DELETE/TRUNCATE/DROP.
- **`hookify.supabase-migration-safety.local.md`** — `action: warn`. Migration review checklist (irreversible column drops, RLS changes, rollback plan).
- **`hookify.n8n-workflow-delete-block.local.md`** — `action: block`. Hard stop on n8n workflow delete operations.
- **`hookify.progress-logger.local.md`** — `action: addContext` (PostToolUse). After every mutation, prompts Claude to append a timestamped entry to `.claude/sessions/claude-progress-{date}.md`.

### New Shell Hook Scripts
- **`.claude/hooks/sql-guardian.sh`** — PreToolUse hard block (exit 2) for destructive SQL content: DELETE without WHERE, TRUNCATE, DROP TABLE/FUNCTION/VIEW. Catches what hookify tool_matcher cannot (query content, not just tool name).
- **`.claude/hooks/session-summarizer.sh`** — StopHook. Writes `SESSION-{date}-{hash}.md` with progress log, git commits, ROADMAP health, and CLIENTUPDATE_PENDING flag for cross-session state.

### Infrastructure Files
- **`.claude/template-source.md`** — Tracks the template repo URL and version for `/update-latest` to use.

### Design Notes
- All Supabase tool matchers use `mcp__supabase-.*__execute_sql` (regex wildcard) — works for any project's Supabase MCP server name, not just `nirvana`.
- All n8n tool matchers use `mcp__n8n-mcp-.*__*` — works for any n8n MCP server name.
- `daily-plan-generator` uses `{{nsm_label}}`, `{{nsm_current}}`, `{{nsm_target}}` parameters — customize in SKILL.md frontmatter for your project's North Star Metric.
- `.claude/sessions/` and `.claude/daily-plans/` are gitignored — session data stays local.

---

## Prior — Initial Release

- Core skills: `skill-creator`, `mcp-patterns`, `pydantic-ai-agent-builder`, `safe-bash`, `agent-research`, `project-template-setup`
- Core commands: `/prime`, `/setup`, `/plan`, `/agent-research`, `/dashboard-health`
- Hookify rules: `auto-rules`, `mcp-server-guard`, `n8n-update-safety`, `plan-mode-enforcer`, `plan-mode-exit-gate`, `safe-bash-enforcer`, `supabase-auto-load`, `supabase-select-star`, `supabase-smart-query`, `github-file-contents`, `playwright-full-page`, `n8n-auto-load`, `n8n-executions-full`, `n8n-fetch-blocker`
- Planning protocol: `.claude/planning-protocol.md`

## 2026-03-26 — Supabase Database Hygiene skill added

- **NEW** `.claude/skills/supabase-database-hygiene/` — Complete Supabase PostgreSQL disk management skill (SKILL.md + 7 reference files + evals). Covers tiered retention policies, batched DELETE patterns, unused index audit protocol, pg_repack, autovacuum tuning, pg_cron scheduling, and pre-flight safety checklist. Completes the 4-skill PostgreSQL suite.

## 2026-04-09 — Git worktree isolation rule
- Added `.claude/rules/git-worktrees.md` — mandatory worktree usage for parallel Claude Code sessions. Prevents `.git/index.lock` contention, `git reset --hard` cross-contamination, and silent file overwrites between sessions.

## 2026-05-15 — Expertise system seeded (git-workflow + code-review-lenses)
- **NEW** `.claude/expertise/git-workflow.yaml` — universal git/PR patterns populated by /reflect:
  - `step_branch_merge_orphans_fix_claims` — a fix that "merged" but doesn't fire in prod: check `gh pr view --json baseRefName`; a non-trunk base means the fix needs a separate forward-port PR
  - `cherry_pick_over_rebase_when_most_commits_absorbed` — for a conflicting many-commit PR whose base was already integration-merged, map each commit's files vs trunk; surgical cherry-pick of the 1-2 unique commits beats a full rebase
- **NEW** `.claude/expertise/code-review-lenses.yaml` — universal review lens:
  - `select_source_mismatch_silent_undefined` — typed-record access on a column NOT in the runtime SELECT returns undefined; null-guards fail closed silently and the dependent fix never fires (TypeScript does not catch it)
- Patterns are mechanism-not-instance; PR numbers and project identifiers generalized to placeholders. No hooks (all three are diagnostic heuristics, hook-score 1/10).
