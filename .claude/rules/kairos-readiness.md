# KAIROS-Readiness Substrate Doctrine (Q11)

**Status**: APPROVED 2026-04-26 (Q9/Q11 sequencing council, 5 agents). Recovered 2026-04-27 after PR #11 rebase loss.
**Parent invariant**: Option α (`council/sessions/2026-04-13-unified-memory-architecture-phase-c.md:32`, 8/8 council agents @ 95%+) — never violate.
**Pairs with**: `.claude/rules/symlink-discipline.md` — symlinks are the personal local-file convenience layer; this rule covers the durable shared-truth substrate. Symlinks for personal cache (Justin's Mac MEMORY.md + topic files), Supabase substrate for cross-host shared state (NewClaw / Portal / KI / Agent Suite).

## The Rule

**Every memory-layer cherry-pick or new pattern MUST write its persistent state to a Supabase table with stable, queryable schema. Never local-only state for substrate work.**

## Primary value: structured + queryable + multi-session-durable substrate

A memory pattern that lives only in local files (in `~/.claude/`, in `.obsidian/`, on a single Mac) is invisible to:
- Other Claude Code sessions on different machines
- The Portal NLC recall layer (Spec 14 W11-12)
- NewClaw Kernel agent dispatching (Spec 12)
- Cross-account state (Justin + Cassandra unified workflows)
- Any future analytics, observability, or migration tooling

Structured Supabase substrate makes the data **queryable, joinable, and exportable** regardless of what reads it.

## Secondary value: KAIROS-migration readiness (tail scenario)

If/when Anthropic ships KAIROS (the rumored markdown-daemon memory layer with 200-line/25KB budget — see specs/16 §3.12), having our memory state in structured Supabase tables means migration becomes a feature-add (export → KAIROS-format → ingest), NOT a rebuild from scratch.

This is a 1-4× near-term ROI claim with high asymmetric upside at migration. Frame it as tail-scenario value, not the primary justification — Devil's Advocate corrected the original framing (KAIROS is a markdown daemon, so Supabase ≠ KAIROS-native; the migration is still a transformation step, not a feature-add).

## Scope

**APPLIES TO**:
- New n8n workflow state tables
- New edge function persistent stores
- New RPCs that maintain state between calls
- pg_cron jobs that produce or consume state
- Any new memory-pattern adoption per specs/17 Pattern Amendment

**DOES NOT APPLY TO** (carve-out for existing infrastructure):
- The existing 21+ hookify rules in `.claude/hookify.*.local.md` — they predate this doctrine; they are local-file infrastructure by design
- The existing ~80 skills in `.claude/skills/` — same predates rationale
- `.claude/rules/*.md` files (this file included) — doctrine itself is local-file
- Per-machine session logs in `.claude/sessions/`
- MEMORY.md and topic files in `~/.claude/projects/.../memory/` — user-curated personal layer

The doctrine's edge applies to NEW patterns post-2026-04-26, not retroactively to existing local-file infrastructure.

## Enforcement: context-injection only — no automated audit

**Honesty clause (Reliability Engineer requirement)**: This is doctrine, not a hard gate. There is no PreToolUse hook that blocks new memory-pattern adoption when the pattern lacks Supabase substrate. Code-council reviewers are expected to flag violations during PR review. Future hookify rule could enforce, but this rule does not assume that enforcement exists.

Without this honesty clause, the doctrine becomes compliance theatre — Justin BELIEVES it is enforced when it is not.

## Decommission triggers

This doctrine retires when ANY of:

1. **Anthropic ships KAIROS in a form incompatible with Supabase-substrate migration**: e.g., if KAIROS demands a specific local-file schema and offers no ingestion API. (Re-evaluate at Q3 2026 mid-quarter check, calendared for 2026-07-15 per Q8 binding clause.)
2. **Anthropic ships an official Memory API that supersedes the substrate-doctrine entirely**: e.g., a managed-memory service that handles persistence + recall without Supabase tables.
3. **Q3 2026 re-eval confirms KAIROS is NOT released within 18 months**: at that point, the secondary value (migration readiness) becomes weak, but the primary value (structured + queryable substrate) still holds — doctrine STAYS but framing simplifies.

## Provenance

- Council: `council/sessions/2026-04-26-memory-layer-q9-q11-sequencing.md` (5 agents, 4/5 convergent on Frame 1)
- Pattern Amendment: `specs/17_MEMORY_PATTERN_INCORPORATION_AMENDMENT.md` §5.3 Q11 RESOLVED
- Originating reframe: Devil's Advocate correction (KAIROS-prep framing was overstated as primary value)
- Recovery: 2026-04-27 — file lost in PR #11 rebase, recreated from conversation history + memory anchor
