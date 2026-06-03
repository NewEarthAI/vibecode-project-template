---
description: "Fresh-context non-sycophantic code review via claude -p subprocess"
argument-hint: "[files|diff-range|staged]"
allowed-tools: ["Read", "Glob", "Grep", "Bash", "Write"]
---

# /code-forge — Fresh-Context Code Review

Spawn a genuinely fresh Claude session to review code with no conversation history and a non-sycophantic identity. Solves context-continuity sycophancy.

**Scope**: "$ARGUMENTS"

## Pre-flight (mandatory — runs BEFORE the subprocess spawns)

Before spawning the fresh-context `claude -p` subprocess, Read `.claude/rules/code-review-identity.md` and inject its full content as the SYSTEM-PROMPT-LEVEL identity prefix in the subprocess invocation. A fresh Claude subprocess has NO session memory and NO project-rule auto-load by default — without explicit injection, the reviewer-identity preamble is silently absent and the non-sycophantic identity contract is voided.

If the file cannot be read (missing, renamed, moved), HALT and surface the failure — do not proceed with a degraded reviewer identity.

Composes with: the BASELINE row in `.claude/rules/code-review-domain-routing.md` and the `hookify.code-review-identity-load.local.md` hook.

Follow the skill instructions in `.claude/skills/code-forge/SKILL.md` exactly.
