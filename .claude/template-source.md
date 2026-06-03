---
repo: https://github.com/NewEarthAI/vibecode-project-template
local_path: /Users/justin/code/template-fresh
version: 2026-05-18-newvibe-template-portable
last_sync: 2026-05-18-newvibe-template-portable
---

# Template Source

## TEMPLATE-MANAGED Files

These files flow between this project and the template repo. Use `/push-to-template` to push improvements upstream, `/update-latest` to pull updates.

**Generalization rules**: Before pushing, replace project-specific identifiers:
- `mcp__supabase-yourproject__*` → `mcp__supabase-.*__*`
- `mcp__n8n-yourinstance__*` → `mcp__n8n-mcp-.*__*`
- Project URLs, IDs, timezones → remove or templatize

### Plugin Source Code

| Project Path | Template Path | Notes |
|-------------|---------------|-------|
| *(cache)* `~/.claude/plugins/cache/claude-code-plugins/hookify/0.1.0/core/rule_engine.py` | `plugins/hookify/core/rule_engine.py` | Core engine — fnmatch wildcards, OR combinator, not_exists operator |
| *(cache)* `~/.claude/plugins/cache/claude-code-plugins/hookify/0.1.0/core/config_loader.py` | `plugins/hookify/core/config_loader.py` | YAML parser, Rule dataclass, combinator support |
| *(cache)* `~/.claude/plugins/cache/claude-code-plugins/hookify/0.1.0/hooks/pretooluse.py` | `plugins/hookify/hooks/pretooluse.py` | PreToolUse handler — loads event='PreToolUse' |
| *(cache)* `~/.claude/plugins/cache/claude-code-plugins/hookify/0.1.0/hooks/posttooluse.py` | `plugins/hookify/hooks/posttooluse.py` | PostToolUse handler |
| *(cache)* `~/.claude/plugins/cache/claude-code-plugins/hookify/0.1.0/hooks/stop.py` | `plugins/hookify/hooks/stop.py` | Stop handler |
| *(cache)* `~/.claude/plugins/cache/claude-code-plugins/hookify/0.1.0/hooks/userpromptsubmit.py` | `plugins/hookify/hooks/userpromptsubmit.py` | UserPromptSubmit handler |
| *(cache)* `~/.claude/plugins/cache/claude-code-plugins/hookify/0.1.0/hooks/sessionstart.py` | `plugins/hookify/hooks/sessionstart.py` | SessionStart handler |
| *(cache)* `~/.claude/plugins/cache/claude-code-plugins/hookify/0.1.0/plugin.json` | `plugins/hookify/plugin.json` | Plugin manifest |

### Shell Hooks

| Project Path | Template Path | Notes |
|-------------|---------------|-------|
| `.claude/hooks/bash-guardian.sh` | `.claude/hooks/bash-guardian.sh` | Blocks destructive bash commands |
| `.claude/hooks/sql-guardian.sh` | `.claude/hooks/sql-guardian.sh` | Blocks destructive SQL |
| `.claude/hooks/session-summarizer.sh` | `.claude/hooks/session-summarizer.sh` | Writes session summaries |
| `.claude/hooks/hookify-context-injector.sh` | `.claude/hooks/hookify-context-injector.sh` | Makes hookify .local.md rules fire at runtime |
| `.claude/hooks/auto-sync-artifacts.sh` | `.claude/hooks/auto-sync-artifacts.sh` | Auto-commit+push metadata artifacts on session end |
| `.claude/hooks/vault-capture.sh` | `.claude/hooks/vault-capture.sh` | Captures session summaries to Obsidian vault daily notes |
| `.claude/hooks/worktree-guard.sh` | `.claude/hooks/worktree-guard.sh` | PreToolUse Bash hook — warns on branch-modifying git ops with multiple worktrees + scans stale `.git/*.lock` on `worktree add`. Triple-gated <5ms. Added 2026-04-19 as companion to /ship skill. |
| `.claude/hooks/pre-push-branch-verify.sh` | `.claude/hooks/pre-push-branch-verify.sh` | PreToolUse Bash hook — warns when `git push <remote> <branch>` targets a different branch than current HEAD (catches silent branch-switch by parallel sessions in same worktree). Triple-gated: bails in <5ms on non-`git push` calls, ~80 tokens injected only on actual mismatch. WARN only — refspec relays + hotfix pushes are sometimes legitimate. Added 2026-04-23 after PR #237 ship-cascade caught a silent worktree branch swap mid-session. |
| `.claude/hooks/roadmap-writeback-verifier.sh` | `.claude/hooks/roadmap-writeback-verifier.sh` | Stop hook — WARN-ONLY backstop for the canonical Roadmap Write-Back phase. Fail-open (always exit 0), verbatim honesty clause, time-window-free change-set trigger predicate, per-machine self-check. Register in the Stop chain BEFORE any backgrounded projection sync. Added 2026-05-16. Auto-setup: `shell_hook` + `chmod_executable`. |
| `.claude/hooks/newvibe-autofire-stop.sh` | `.claude/hooks/newvibe-autofire-stop.sh` | Stop hook — NewVibe autofire trigger. Silent no-op every non-ship turn; on a verified clean ship + a fresh master continuation, runs the safety gates (kill-switch, runaway cap ≤ 5, single-fire arm flag) then dispatches a fresh session. Added 2026-05-17. Auto-setup: `shell_hook` (Stop) + `chmod_executable`. Per-repo wiring: `.claude/skills/autovibe/references/newvibe-integration-guide.md` §3. |
| `.claude/hooks/newvibe-precompact-handoff.sh` | `.claude/hooks/newvibe-precompact-handoff.sh` | PreCompact hook — NewVibe context-budget handoff. Fires when the harness compacts the context window; writes a handoff continuation so multi-session work survives a full context. Added 2026-05-17. Auto-setup: `shell_hook` (PreCompact) + `chmod_executable`. |
| `.claude/skills/_shared/roadmap-writeback-phase.md` | `.claude/skills/_shared/roadmap-writeback-phase.md` | Canonical Roadmap Write-Back deep module (W0–W6). Single source every daily-plan-class skill delegates to verbatim. Evidence-verify-VERDICT-not-existence keystone. Added 2026-05-16. |
| `bin/verify-writeback-symmetry.sh` | `bin/verify-writeback-symmetry.sh` | Re-runnable symmetry gate — discovers present daily-plan skills (1 = delegation+non-fork; 2+ = mutual symmetry). Required-artefact in the shipping PR. Added 2026-05-16. Auto-setup: `chmod_executable`. |

### Hookify Rules

| Project Path | Template Path | Notes |
|-------------|---------------|-------|
| `.claude/hookify.completion-verifier.local.md` | `.claude/hookify.completion-verifier.local.md` | Session exit self-verify |
| `.claude/hookify.github-file-contents.local.md` | `.claude/hookify.github-file-contents.local.md` | GitHub local-first warn |
| `.claude/hookify.mcp-server-guard.local.md` | `.claude/hookify.mcp-server-guard.local.md` | Wrong-project MCP block |
| `.claude/hookify.n8n-auto-load.local.md` | `.claude/hookify.n8n-auto-load.local.md` | n8n context loader (compressed) |
| `.claude/hookify.n8n-code-return.local.md` | `.claude/hookify.n8n-code-return.local.md` | n8n code return warn (disabled) |
| `.claude/hookify.n8n-error-branch-required.local.md` | `.claude/hookify.n8n-error-branch-required.local.md` | Error branch on full updates |
| `.claude/hookify.n8n-executions-full.local.md` | `.claude/hookify.n8n-executions-full.local.md` | Block full executions |
| `.claude/hookify.n8n-fetch-blocker.local.md` | `.claude/hookify.n8n-fetch-blocker.local.md` | Block full workflow fetch |
| `.claude/hookify.n8n-http-error-handling.local.md` | `.claude/hookify.n8n-http-error-handling.local.md` | HTTP error handling check |
| `.claude/hookify.n8n-update-safety.local.md` | `.claude/hookify.n8n-update-safety.local.md` | n8n update checklist |
| `.claude/hookify.n8n-use-essentials.local.md` | `.claude/hookify.n8n-use-essentials.local.md` | Force essentials mode |
| `.claude/hookify.n8n-workflow-delete-block.local.md` | `.claude/hookify.n8n-workflow-delete-block.local.md` | Block workflow delete |
| `.claude/hookify.plan-mode-exit-gate.local.md` | `.claude/hookify.plan-mode-exit-gate.local.md` | Plan exit gate |
| `.claude/hookify.playwright-full-page.local.md` | `.claude/hookify.playwright-full-page.local.md` | Block full-page screenshots |
| `.claude/hookify.roadmap-freshness.local.md` | `.claude/hookify.roadmap-freshness.local.md` | Roadmap freshness check |
| `.claude/hookify.safe-bash-enforcer.local.md` | `.claude/hookify.safe-bash-enforcer.local.md` | Catastrophic bash block |
| `.claude/hookify.supabase-auto-load.local.md` | `.claude/hookify.supabase-auto-load.local.md` | Supabase checklist (compressed) |
| `.claude/hookify.supabase-destructive-sql.local.md` | `.claude/hookify.supabase-destructive-sql.local.md` | Destructive SQL warn |
| `.claude/hookify.supabase-list-tables-block.local.md` | `.claude/hookify.supabase-list-tables-block.local.md` | Block list_tables |
| `.claude/hookify.supabase-migration-safety.local.md` | `.claude/hookify.supabase-migration-safety.local.md` | Migration safety warn |
| `.claude/hookify.supabase-select-star.local.md` | `.claude/hookify.supabase-select-star.local.md` | Block SELECT * |
| `.claude/hookify.task-context-injector.local.md` | `.claude/hookify.task-context-injector.local.md` | Sub-agent context |
| `.claude/hookify.auto-council-on-plan.local.md` | `.claude/hookify.auto-council-on-plan.local.md` | Autonomous pipeline on ExitPlanMode |
| `.claude/hookify.auto-review-on-execute.local.md` | `.claude/hookify.auto-review-on-execute.local.md` | Pipeline safety net on Stop |
| `.claude/hookify.disk-pressure-pre-git-write.local.md` | `.claude/hookify.disk-pressure-pre-git-write.local.md` | APFS ≥90% full halts git writes (2026-04-19) |
| `.claude/hookify.rebase-ours-theirs-guard.local.md` | `.claude/hookify.rebase-ours-theirs-guard.local.md` | Rebase vs merge --ours/--theirs reverse-semantic guard (2026-04-19) |
| `.claude/hookify.code-review-identity-load.local.md` | `.claude/hookify.code-review-identity-load.local.md` | **Reviewer-identity gate (PreToolUse Agent matcher).** Injects `.claude/rules/code-review-identity.md` (7 principles + Karpathy Self-Check Razors) as additional context on every Agent tool dispatch. Defence-in-depth layer 3 alongside the BASELINE row in `code-review-domain-routing.md` and the Pre-flight blocks in `/code-council` + `/code-forge`. Pairs with the `Agent` matcher registration in `.claude/settings.local.json` PreToolUse hooks chain. Added 2026-05-12. |

### Commands (Template-Portable)

| Project Path | Template Path | Notes |
|-------------|---------------|-------|
| `.claude/commands/Master-Continuation-Prompt.md` | `.claude/commands/Master-Continuation-Prompt.md` | Session handoff |
| `.claude/commands/adopt-autonomous-workflow.md` | `.claude/commands/adopt-autonomous-workflow.md` | Autonomous workflow |
| `.claude/commands/build-with-agent-team.md` | `.claude/commands/build-with-agent-team.md` | Agent team builder |
| `.claude/commands/compress-roadmap.md` | `.claude/commands/compress-roadmap.md` | Roadmap archiver |
| `.claude/commands/daily-plan.md` | `.claude/commands/daily-plan.md` | Daily plan generator |
| `.claude/commands/e2e-test.md` | `.claude/commands/e2e-test.md` | E2E test runner |
| `.claude/commands/present.md` | `.claude/commands/present.md` | Presentation generator |
| `.claude/commands/execute.md` | `.claude/commands/execute.md` | Plan executor |
| `.claude/commands/plan.md` | `.claude/commands/plan.md` | Plan creator |
| `.claude/commands/prime.md` | `.claude/commands/prime.md` | Codebase primer |
| `.claude/commands/push-to-template.md` | `.claude/commands/push-to-template.md` | Template push |
| `.claude/commands/setup.md` | `.claude/commands/setup.md` | Project setup |
| `.claude/commands/update-latest.md` | `.claude/commands/update-latest.md` | Template pull |
| `.claude/commands/verify-hooks.md` | `.claude/commands/verify-hooks.md` | Hooks verifier |
| `.claude/commands/refactor-memory-md.md` | `.claude/commands/refactor-memory-md.md` | Memory refactoring |
| `.claude/commands/apply-insights.md` | `.claude/commands/apply-insights.md` | Apply insights |
| `.claude/commands/amend-plan.md` | `.claude/commands/amend-plan.md` | Council→plan amendment bridge |
| `.claude/commands/reflect.md` | `.claude/commands/reflect.md` | Self-improvement reflection |
| `.claude/commands/code-council.md` | `.claude/commands/code-council.md` | /code-council entry — 6-9 parallel agents, PASS/ADVISORY/BLOCKING verdict |
| `.claude/commands/code-forge.md` | `.claude/commands/code-forge.md` | /code-forge entry — fresh-context `claude -p` subprocess review |

### Skills (Template-Portable)

| Project Path | Template Path | Notes |
|-------------|---------------|-------|
| `.claude/skills/agent-research/SKILL.md` | `.claude/skills/agent-research/SKILL.md` | Research orchestrator |
| `.claude/skills/build-with-agent-team/` | `.claude/skills/build-with-agent-team/` | Agent team skill |
| `.claude/skills/compress-roadmap/SKILL.md` | `.claude/skills/compress-roadmap/SKILL.md` | Roadmap compressor |
| `.claude/skills/daily-plan-generator/SKILL.md` | `.claude/skills/daily-plan-generator/SKILL.md` | Daily plan generator |
| `.claude/skills/e2e-test/` | `.claude/skills/e2e-test/` | E2E test skill |
| `.claude/skills/presentation/` | `.claude/skills/presentation/` | Presentation engine (HTML + PPTX) |
| `.claude/skills/master-continuation-prompt/SKILL.md` | `.claude/skills/master-continuation-prompt/SKILL.md` | Continuation prompt |
| `.claude/skills/safe-bash/SKILL.md` | `.claude/skills/safe-bash/SKILL.md` | Safe bash skill |
| `.claude/skills/skill-creator/` | `.claude/skills/skill-creator/` | Skill creator |
| `.claude/skills/diagram/` | `.claude/skills/diagram/` | Excalidraw diagrams |
| `.claude/skills/apply-insights/SKILL.md` | `.claude/skills/apply-insights/SKILL.md` | Friction eradication engine |
| `.claude/skills/refactor-memory-md/` | `.claude/skills/refactor-memory-md/` | Memory system optimization |
| `.claude/skills/skill-creator/scripts/` | `.claude/skills/skill-creator/scripts/` | Eval scripts (8 files) |
| `.claude/skills/skill-creator/eval-viewer/` | `.claude/skills/skill-creator/eval-viewer/` | Eval result viewer |
| `.claude/skills/skill-creator/references/schemas.md` | `.claude/skills/skill-creator/references/schemas.md` | Data format schemas |
| `.claude/agents/skill-creator/` | `.claude/agents/skill-creator/` | Grader, Comparator, Analyzer agents |
| `.claude/agents/council/` | `.claude/agents/council/` | Devils Advocate, Optimist Strategist, Neutral Analyst, Pragmatist, Edge Case Finder, Reframer, Capability Scout, Reliability Engineer |
| `.claude/skills/council/` | `.claude/skills/council/` | AI Council deliberation skill + evals |
| `.claude/skills/ssh-claude-setup/` | `.claude/skills/ssh-claude-setup/` | SSH remote execution setup (Mac → VPS → n8n) |
| `.claude/skills/skill-auditor-merger/` | `.claude/skills/skill-auditor-merger/` | External skill ingestion + bidirectional audit |
| `.claude/skills/prompt-forge/` | `.claude/skills/prompt-forge/` | Enterprise prompt transformation |
| `.claude/skills/supabase-postgres-best-practices/` | `.claude/skills/supabase-postgres-best-practices/` | Supabase Postgres rules (34 refs) |
| `.claude/skills/postgresql-patterns/` | `.claude/skills/postgresql-patterns/` | Query patterns + code review (12 refs) |
| `.claude/skills/postgresql-internals/` | `.claude/skills/postgresql-internals/` | Engine internals (15 refs) |
| `.claude/skills/kpi-dashboard-design/` | `.claude/skills/kpi-dashboard-design/` | KPI framework + visualization |
| `.claude/skills/build-dashboard/` | `.claude/skills/build-dashboard/` | Self-contained HTML dashboards |
| `.claude/skills/grafana-dashboards/` | `.claude/skills/grafana-dashboards/` | Grafana dashboard patterns |
| `.claude/skills/bulletproof-drawer-perimeter/` | `.claude/skills/bulletproof-drawer-perimeter/` | Playwright regression-test perimeter for drawers/modals/side-sheets — 8 patterns (cell[1] row click, role=dialog scope, 2-click toggle, idempotent round-trip, REST PATCH cleanup, serial mode, storageState token, zero-skip). Composes with ui-design-system. Added 2026-04-23 after 4-hour debugging session on a SaaS app seller drawer (PRs #228/229/231/234). |
| `.claude/skills/llm-monitoring-dashboard/` | `.claude/skills/llm-monitoring-dashboard/` | LLM usage monitoring |
| `.claude/skills/landing-page-mvp/` | `.claude/skills/landing-page-mvp/` | GSAP cinematic landing pages |
| `.claude/skills/ship/` | `.claude/skills/ship/` | Autonomous code-ship workflow (quick/pr/hotfix). Pre-flight gates (iCloud path, disk, stale-lock, tsc), atomic mkdir-lock with TTL + future-skew tolerance, snapshot before destructive, admin-merge heuristic on chronic CI flake, post-deploy smoke with Vercel auth pre-check + retry+backoff, auto-rollback on smoke fail. Dual-use (human + Autovibe orchestrator, same code path). Added 2026-04-19. Generalized: snapshot dir = `~/.claude-ship-snapshots/`; project must configure production URL + chronic-flake CI job list. |
| `.claude/skills/autovibe/` | `.claude/skills/autovibe/` | Top-of-stack autonomous shipping orchestrator. Composes /ship + /execute + /code-council + /prompt-forge + prime-lite + framing-audit primitives + Pocock toolkit. Two modes: direct (typo→/ship quick) and planned (substantive→goal-audit→plan→execute→diff-review→/ship pr). Strategy council (/council --extended) + /amend-plan RETIRED from autofire loop 2026-05-23 (rabbit-hole detours, work not finishing). /council survives as MANUAL operator skill outside autovibe; /code-council (diff reviewer for shipped code) stays at step 7. Hotfix REFUSED (human-only). Atomic-mkdir lock + jq-backed JSON state file (post-code-council hardened 2026-04-19). 6 eval scenarios. Required dep: jq. |
| `.claude/commands/autovibe.md` | `.claude/commands/autovibe.md` | /autovibe command wrapper |
| `.claude/skills/prime-lite/` | `.claude/skills/prime-lite/` | Lightweight (<2000 token, <3s) repo-state context briefing primitive for orchestrators. Composable building block — Autovibe's first step, also reusable by future orchestrators. Verified at 863 words / 1353ms on a real worktree. Added 2026-04-19. |
| `.claude/commands/council.md` | `.claude/commands/council.md` | Council command trigger |
| `.claude/skills/master-code-reviewer/` | `.claude/skills/master-code-reviewer/` | Quantitative code review with scoring |
| `.claude/skills/master-security-review/` | `.claude/skills/master-security-review/` | Confidence-calibrated security review |
| `.claude/skills/tailwind-shadcn-system/` | `.claude/skills/tailwind-shadcn-system/` | Tailwind v4 + shadcn component system |
| `.claude/skills/design-review/` | `.claude/skills/design-review/` | Priority-weighted UI/UX review |
| `.claude/skills/brand-visual-identity/` | `.claude/skills/brand-visual-identity/` | Brand token management + extraction |
| `.claude/skills/saas-multi-tenant-auth/` | `.claude/skills/saas-multi-tenant-auth/` | Enterprise-grade multi-tenant auth + sub-user bootstrap for Supabase + React + TanStack Query. Six-tier shipping plan (foundation → invitations → team mgmt → audit log → frontend → hardening) with verification gates between each. Twelve doctrinal pillars (security_invoker views, JWT-derived identity, atomic invite claim, promote-before-demote owner transfer, append-only audit via RLS+structural triggers+revoke, STABLE helper, _v2 sunset, listUsers pagination trap, org-switch JWT refresh, actionable 4xx codes). 22 files: SKILL.md + 8 references + 5 SQL templates + 5 TS templates + audit script + evals.json. Parameterized with placeholders (`{{prefix}}`, `{{org_table}}`, `{{tenant_column}}`, etc.). Distilled from a SaaS app CM.32 (4-phase ship 2026-04-19 to 2026-04-21). Composes with `saas-platforms` (strategy layer) + `better-auth-security` (alternative auth) + `master-security-review` (post-ship audit). Added 2026-04-28. |
| `.claude/rules/council-protocol.md` | `.claude/rules/council-protocol.md` | Council protocol rules (5/8 agents) |
| `.claude/skills/obsidian-second-brain/` | `.claude/skills/obsidian-second-brain/` | Vault operations: search, frontmatter, MOC, KI bridge |
| `.claude/skills/digitalocean-infra/` | `.claude/skills/digitalocean-infra/` | Droplet health + self-healing (5 modes) |
| `.claude/skills/code-council/SKILL.md` | `.claude/skills/code-council/SKILL.md` | Multi-lens code review deliberation (v1.0, 6/9 agents) |
| `.claude/skills/code-forge/SKILL.md` | `.claude/skills/code-forge/SKILL.md` | Fresh-context non-sycophantic reviewer (v1.0, subprocess) |
| `.claude/skills/competitive-intelligence/` | `.claude/skills/competitive-intelligence/` | Universal competitor-intel super-skill (supersedes 7 external skills; Phase 0 SI skeleton binding; 7 bundled scaffold templates; JTBD + rubric + SWOT + decisions-log + positioning integration). See council/sessions/2026-04-18-competitive-intelligence-super-skill.md. DO NOT PUSH until SI.0 + SI.2 validate end-to-end in a SaaS app. |
| `.claude/agents/code-council/security-auditor.md` | *(not in template — sourced from the agency)* | Auth, injection, secrets, OWASP |
| `.claude/agents/code-council/spec-validator.md` | *(not in template — sourced from the agency)* | Code-matches-spec reviewer |
| `.claude/agents/code-council/performance-reviewer.md` | *(not in template — sourced from the agency)* | N+1, allocations, latency |

### Rules (Template-Portable)

| Project Path | Template Path | Notes |
|-------------|---------------|-------|
| `.claude/rules/file-editing.md` | `.claude/rules/file-editing.md` | File editing safety |
| `.claude/rules/n8n-patterns.md` | `.claude/rules/n8n-patterns.md` | n8n conventions |
| `.claude/rules/tool-fallbacks.md` | `.claude/rules/tool-fallbacks.md` | MCP fallback rules |
| `.claude/rules/code-review-identity.md` | `.claude/rules/code-review-identity.md` | Anti-sycophancy identity preamble (7 principles) |
| `.claude/rules/code-review-domain-routing.md` | `.claude/rules/code-review-domain-routing.md` | File-pattern → domain rule routing for code-council |
| `.claude/rules/operational-guardrails.md` | `.claude/rules/operational-guardrails.md` | Git write safety: disk pressure, rebase semantics, snapshot-before-destructive (generic sections only; project Playwright heuristic kept local) |
| `.claude/rules/shell-portability.md` | `.claude/rules/shell-portability.md` | Shell-scripting traps (pipes eat $?, grep -c double-echo, macOS timeout portability, mkdir-atomic locks, zsh reserved names). Added 2026-04-19 via /ship skill build. |
| `.claude/rules/research-before-threshold-lock.md` | `.claude/rules/research-before-threshold-lock.md` | Research-before-lock for numerical thresholds + industry rule citations. Two failure modes: asymptotic statistical constants at small N (MAD×1.4826 biased 18-33% at N=3-5, Park-Kim-Wang 2020 Cₙ table), zombie industry rules (Fannie Mae 10/15/25% retired Dec 2014 LL-2015-02). Includes /agent-research worker templates. Added 2026-04-24. |
| `.claude/rules/doctrine-currency-check.md` | `.claude/rules/doctrine-currency-check.md` | Triple-cite check before propagating sub-agent citations driving NEGATIVE decisions (REMOVE / EXCLUDE / DEPRECATE / CANCEL). ROADMAP recency + git log on affected paths + live code reference grep — any one contradicting the doctrine = stale, withhold propagation. Failure precedent: 4-surface stale-doctrine propagation incident where a sub-agent's Capability Scout report cited a 9-day-stale data-layer.md "being CANCELED" line; propagated to council session AR4 + memory + ROADMAP + v2 continuation before operator caught it. Composes with council-protocol.md auto-resolution + agentic-loop-guards.md retroactive-edit ban. Added 2026-05-12. |
| `.claude/rules/continuation-collision-safety.md` | `.claude/rules/continuation-collision-safety.md` | Pause-gate pattern for continuations when parallel sessions may modify same files. Three-query resume gate (git log / ls-remote / gh pr list) with short-circuit ordering. Detection protocol, banner template, anti-patterns. Added 2026-04-24. |

### Other

| Project Path | Template Path | Notes |
|-------------|---------------|-------|
| `.claude/planning-protocol.md` | `.claude/planning-protocol.md` | Planning protocol |
| `.claude/HOOKS-AND-RULES-STANDARDIZATION.md` | `.claude/HOOKS-AND-RULES-STANDARDIZATION.md` | Three-layer enforcement guide |
| `.claudeignore` | `.claudeignore` | Token efficiency — excludes irrelevant dirs from codebase indexing |

### Zero-Regression Infrastructure (added 2026-04-11 via SaaS app PR #53)

| Project Path | Template Path | Notes |
|-------------|---------------|-------|
| `.github/workflows/ci.yml` | `.github/workflows/ci.yml` | `check` job: lint + tsc + vitest on PR + merge_group |
| `.github/workflows/e2e.yml` | `.github/workflows/e2e.yml` | `playwright` job triggered by Vercel preview `deployment_status` + `merge_group`, runs in mcr.microsoft.com/playwright:v1.59.1-noble container |
| `playwright.config.ts` | `playwright.config.ts` | Cold-preview tolerant timeouts (expect 15s, test 45s, navigation 30s), chromium-only, retries 2 on CI |
| `playwright/global-setup.ts` | `playwright/global-setup.ts` | Supabase auth pre-flight, writes storageState to playwright/.auth/user.json. ESM-compatible (fileURLToPath) |
| `tests/e2e/sanity.smoke.spec.ts` | `tests/e2e/sanity.smoke.spec.ts` | Always-passing sentinel (ensures ≥1 test in the `@smoke` grep even when suites are skipped) |
| N/A | `tests/e2e/README.md` | Pattern guide for adding project-specific smoke tests (data-testid, @smoke tag, skip convention) |
| `eslint.config.js` | `eslint.config.js` | Ignores supabase/functions/**, playwright/**, tests/e2e/**, specs/**/*.js; demotes no-explicit-any to warn |

## PROJECT-SPECIFIC Files (Never Push)

These files are project-specific and should NEVER be pushed to the template:

- `CLAUDE.md` — project-specific content
- `docs/` — project architecture
- `specs/` — project specs
- `.claude/hookify.github-local-first.local.md` — project-specific path
- `.claude/settings.local.json` — machine-specific, gitignored
- `.claude/memory/` — project-specific memory
- `.claude/sessions/` — session logs
- `.claude/plans/` — session plans
- `.claude/skills/the app-workflows/` — project domain skill
- `.claude/skills/pipeline-debug/` — project domain skill
- `.claude/skills/mcp-patterns/` — project domain skill
- `.claude/commands/pipeline-debug.md` — project-specific command
- `.claude/commands/debug-*.md` — project-specific commands
- `.claude/commands/verify-pipeline.md` — project-specific command
- `.claude/rules/data-layer.md` — project-specific data reference
- `.claude/rules/pipeline-reference.md` — project-specific pipeline reference
- `.claude/rules/supabase-safety.md` — project-specific Supabase rules
- `.claude/rules/frontend.md` — project-specific frontend rules
