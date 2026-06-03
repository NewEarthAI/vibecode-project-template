# Doctrine-Currency Check — Triple-Cite Before Propagating Sub-Agent "REMOVE / DEPRECATE / CANCEL" Citations

**Scoped to**: every session that runs sub-agents (Agent tool, `/council`, `/agent-research`, `/code-council`, `/code-forge`, etc.) whose output may quote a project rule file, doctrine doc, or ROADMAP line to support a NEGATIVE decision (remove a candidate, exclude an option, deprecate a feature, cancel an integration, declare a path "broken" / "retired" / "obsolete").

**Auto-loaded via**: project rule load order (every session that may dispatch sub-agents).

**Origin**: 2026-05-12 — 4-surface doctrine propagation incident. A sub-agent's Capability Scout report cited 📄 `.claude/rules/data-layer.md` line saying "RealEstateAPI — being CANCELED — BatchData replacing". The citation was propagated to: (a) council session AR4 ("REMOVE REAPI from v2 continuation entirely"), (b) memory file ("REAPI is OUT"), (c) ROADMAP CM.49 row ("REAPI EXCLUDED per data-layer.md cancellation"), (d) v2 master continuation ("Reopen the REAPI debate" listed as anti-pattern). Only the operator catching it ("REAPI canceld???") surfaced the stale citation. Verified live state: REAPI was ACTIVE — 📄 `enrich-property-full` line 1819 wrote `provider='realestate_api_property'` rows to `dd_api_cache` on every miss; CM.47d PR #414 shipped 2026-05-03 with a measured +$92,510 money-win. The doctrine line had been stale for at least 9 days.

---

## The Rule

When a sub-agent quotes a project rule file, doctrine doc, or ROADMAP line to support **any** of the following decisions:

- "REMOVE X from the candidate list"
- "EXCLUDE Y"
- "X is cancelled / deprecated / retired / obsolete"
- "Y is broken / non-functional / unavailable"
- "Do not use Z / Z is anti-pattern"
- "REAPI / BatchData / Titan / RentCast / Vendor-Name is being phased out"

**The orchestrator MUST triple-cite the doctrine claim before propagating it to any downstream artefact (council session, memory file, ROADMAP, continuation, plan).**

### The triple cite

Three independent signals MUST corroborate the doctrine before a NEGATIVE decision propagates:

1. **ROADMAP recency check**: grep `specs/ROADMAP.md` + `specs/ROADMAP-ARCHIVE.md` for the affected feature / vendor / file. If the most recent mention is a SHIPPED item with a recent date (within ~30 days) that CONTRADICTS the doctrine (e.g., doctrine says "deprecated" but ROADMAP shows a shipped extension PR), the doctrine is stale.
2. **Git log signal**: `git log --since="3 months ago" --oneline -- <affected-paths>` on the doctrine's claimed-dead surfaces. Active commits on the surface within the last 90 days contradicts a "deprecated" or "cancelled" claim.
3. **Live code reference**: grep production code paths (`supabase/functions/**`, `src/**`, n8n workflow JSONs where applicable) for active usage of the feature. Cache writes, edge function deployments, env-var references, or n8n node calls within recent commits contradict a "non-functional" claim.

If ANY of (1)(2)(3) contradicts the doctrine, the doctrine is stale. The orchestrator MUST:
- **Flag the staleness inline** in the synthesis (cite the contradicting evidence)
- **Withhold propagation** to downstream artefacts pending operator confirmation
- **Surface the doctrine inconsistency** to the operator with: "doctrine says X but evidence shows Y — should the doctrine be retracted?"
- **NEVER auto-propagate** a stale citation as-if-current to memory / ROADMAP / continuations / council session bodies

---

## When this rule does NOT fire

- Sub-agent cites doctrine to support a POSITIVE decision (use X, prefer Y, the recommended path is Z) — these can propagate with normal scrutiny; the triple-cite is for NEGATIVE decisions specifically because they're harder to recover from
- Sub-agent cites a primary external source (vendor docs, USPAP, Fannie Mae publication, peer-reviewed paper) — doctrine-currency is about INTERNAL rule files being stale, not external references
- Doctrine claim is self-evidently fresh (cites a date within the last 14 days OR cites a PR that shipped within the last 14 days) — recency reduces but does not eliminate the staleness risk

---

## Triple-cite recipe (concrete)

When you spot a sub-agent NEGATIVE decision anchored on doctrine, run this BEFORE propagating:

```bash
# 1. ROADMAP recency check — grep for feature/vendor names
grep -i "<feature_or_vendor>" specs/ROADMAP.md specs/ROADMAP-ARCHIVE.md | head -10

# 2. Git log signal on affected paths (replace path with whatever the doctrine claims is dead)
git log --since="3 months ago" --oneline -- supabase/functions/ src/ specs/

# 3. Live code reference grep
grep -rln "<canonical_identifier>" supabase/ src/ --include="*.ts" --include="*.tsx" --include="*.sql" | head -10
```

If the doctrine is stale, the contradicting evidence is usually a single shipped PR (e.g., "CM.47d PR #414 shipped 2026-05-03") that nobody updated the doctrine to reflect. That's normal entropy. The bug is propagating the stale citation as if current.

---

## Failure precedent

**2026-05-12 — REAPI 4-surface propagation incident** (this rule's birthday)

| Surface | What it said | Reality | Recovery cost |
|---|---|---|---|
| Sub-agent Capability Scout | "REAPI — being CANCELED per data-layer.md" | Stale by ~9 days | 0 (single quote) |
| Council session AR4 | "REMOVE REAPI from v2 continuation entirely" | Wrong | Append-only retraction note added |
| Memory file | "REAPI is OUT (cancelled per data-layer.md)" | Wrong | Memory entry edited |
| ROADMAP CM.49 row | "REAPI EXCLUDED per data-layer.md cancellation" | Wrong | ROADMAP entry edited |
| v2 master continuation | "Reopen the REAPI debate" listed as anti-pattern | Wrong | Anti-pattern softened + candidate list extended |

Each downstream surface was easier to write than to retract. Without the operator catching the original citation, Session 2 of CM.49 would have run its council with a 4-candidate decision tree silently constrained to 3 candidates, and the data-source pick would have been suboptimal forever.

Cost of running the triple-cite once during synthesis: ~30 seconds + 3 grep commands. Cost of the 4-surface retraction: 5 file edits across 3 worktrees + 1 PR.

---

## Composes with

- 📄 `.claude/rules/council-protocol.md` — auto-resolution pattern requires citing doctrine, but doctrine itself must be current
- 📄 `.claude/rules/agentic-loop-guards.md` § Pre-Exit Verification — retroactive edits to council sessions destroy audit trail; this rule's preventative purpose IS to avoid needing retractions later
- 📄 `.claude/rules/research-before-threshold-lock.md` — sister doctrine for numerical thresholds; this rule is the doctrine-claims analogue
- 📄 `.claude/rules/operational-guardrails.md` Confident Mode — doctrine retractions are doctrine-modification class; need explicit operator OK to retract a project rule file

---

## Operator-facing summary

When in doubt: a sub-agent citing one of your own rule files to support a NEGATIVE decision is a load-bearing claim. Verify the doctrine is current via ROADMAP + git log + live code grep BEFORE the decision propagates to memory / ROADMAP / continuations / council session bodies. 30 seconds upfront saves a 4-surface retraction later.
