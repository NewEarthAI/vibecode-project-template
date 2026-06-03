---
name: code-review-identity-load
enabled: true
event: PreToolUse
tool_matcher: Agent
action: addContext
timeout: 5000
---

# Code-Review Identity Rule MUST Load Before Any Review-Class Subagent Dispatch

Fires on every `Agent` tool invocation (PreToolUse). The hookify-context-injector scans this file's frontmatter, matches the `Agent` tool, and injects the content below as additional context to the parent session BEFORE the subagent is dispatched.

Purpose: enforce that 📄 `.claude/rules/code-review-identity.md` (anti-sycophancy preamble, 7 principles, Self-Check Razors) is in scope on every review-class subagent invocation — closing the silent-failure class where the rule was claimed "auto-loaded on any review work" but actually only loaded via compositional reference from a handful of domain rules.

## Injected context

> **Reviewer-identity gate (hookify-enforced)**
>
> Before issuing any verdict, the reviewing agent MUST apply `.claude/rules/code-review-identity.md`. The 7 principles are non-negotiable: (1) project over developer, (2) no softening, (3) prior approval is not immunity, (4) direct language, (5) false negatives are worse than false positives, (6) clean code gets a clean report, (7) confidence ≥80% only. The two Self-Check Razors are mandatory: (a) trace-to-request — every changed line must trace directly to the user's stated request, and (b) senior-engineer overcomplication — if 200 lines could be 50, that IS the finding.
>
> If the subagent_type below is reviewer-class (security-auditor, performance-reviewer, spec-validator, feature-dev:code-reviewer, pr-review-toolkit:code-reviewer, superpowers:code-reviewer, code-reviewer, silent-failure-hunter, pr-test-analyzer, comment-analyzer, type-design-analyzer, master-code-reviewer), the orchestrator MUST include the full content of `.claude/rules/code-review-identity.md` in the subagent prompt's DOMAIN CONTEXT prefix. Refer to the file by path; do not paraphrase.
>
> If the Agent invocation below is NOT a reviewer-class subagent (e.g., Explore, Plan, general-purpose research), this gate is informational only — no action required.
>
> Failure precedent: 2026-04-20 PR #173 drawer resilience — 6-agent code-council issued PASS on a drawer that crashed on open in production. The identity rule's Principle 5 (false negatives > false positives) + Razor 1 (trace-to-request) would have flagged the regression; they didn't fire because the rule was not loaded. This gate closes that class.

## Why hookify-enforced (in addition to the BASELINE routing-table row + `/code-council` Pre-flight block)

Defence-in-depth. Three independent enforcement layers, any of which alone is sufficient:

1. **Routing table BASELINE row** — `code-review-domain-routing.md` lists identity as load-on-every-review.
2. **Command body Pre-flight** — `/code-council` and `/code-forge` Read the rule before subagent dispatch.
3. **Hookify hook (this file)** — fires on every Agent tool dispatch, injects the gate text.

Layer 3 catches the failure mode where layers 1 and 2 are bypassed (e.g., subagent dispatched directly without going through the `/code-council` command, or a custom workflow that composes review subagents outside the documented commands).

## Cost

Token cost: ~150 tokens of additional context on every Agent dispatch. Trivial vs. the sycophancy-prevention payoff. If telemetry later shows over-firing on non-review Agent calls (Explore, Plan, general-purpose), refine the matcher by adding a subagent_type allowlist to the hookify-context-injector — out of scope for v1 since Claude Code's PreToolUse stdin may not expose subagent_type structurally.

## Related infrastructure

- 📄 `.claude/rules/code-review-identity.md` — the doctrine being enforced
- 📄 `.claude/rules/code-review-domain-routing.md` — BASELINE row references identity
- 📄 `.claude/commands/code-council.md` — Pre-flight block Reads identity
- 📄 `.claude/commands/code-forge.md` — Pre-flight block Reads identity
- 📄 `.claude/skills/autovibe/SKILL.md` — ALWAYS clause verifies identity load when composing review commands
- 📄 `.claude/hooks/hookify-context-injector.sh` — the runtime that processes this file
- 📄 `.claude/hookify.code-council-requires-artifact.local.md` — sibling rule, Stop-event verification of PASS verdict artefacts
- 📄 `.claude/hooks/code-council-verification.sh` — SubagentStop hook, canonical reviewer-class allowlist
