---
description: "Multi-lens code review with 6-9 parallel agents producing a PASS/ADVISORY/BLOCKING verdict"
argument-hint: "[files|diff-range] [--thorough] [--spec path] [--no-save]"
allowed-tools: ["Read", "Glob", "Grep", "Bash", "Agent", "Write"]
---

# /code-council — Multi-Lens Code Review

Launch 6 specialized code review agents in parallel (or 9 with --thorough) to evaluate changes from security, performance, spec compliance, test coverage, error handling, and code quality perspectives.

**Arguments**: "$ARGUMENTS"

## Pre-flight (mandatory — runs BEFORE any subagent dispatch)

Before launching ANY review agent, Read `.claude/rules/code-review-identity.md` into the orchestrator context AND include its full content as DOMAIN CONTEXT prefix in every parallel agent prompt. The identity preamble + Self-Check Razors must fire on EVERY council invocation, not just when a compositional rule happens to load them.

If the file cannot be read (missing, renamed, moved), HALT and surface the failure — do not proceed with a degraded reviewer identity.

Composes with: the BASELINE row in `.claude/rules/code-review-domain-routing.md` (which routes the same file to every review domain), and the `hookify.code-review-identity-load.local.md` hook (which re-injects the identity gate at Agent-tool dispatch time).

Follow the skill instructions in `.claude/skills/code-council/SKILL.md` exactly.
