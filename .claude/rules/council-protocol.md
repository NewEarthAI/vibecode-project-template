# AI Council Protocol

## Overview

The `/council` command gathers 5-8 agents for multi-perspective deliberation:

### Standard Council (5 agents — default)

| Agent | Color | Lens | Role |
|-------|-------|------|------|
| **Optimist Strategist** | Green | Best-case pathways | Maps upside potential + success conditions |
| **Devil's Advocate** | Red | Risk + assumptions | Stress-tests claims + surfaces blind spots |
| **Neutral Analyst** | Blue | Evidence + trade-offs | Synthesizes + adjudicates + maps the decision |
| **Capability Scout** | Gray | Inventory + stack translation (BUILD cost) | Checks existing skills/MCPs/commands before build; translates engineer-hours into stack-adjusted wall-clock; flags anchor-bias on pre-AI cost estimates |
| **Reliability Engineer** | Yellow | Operate cost + failure visibility (OPERATE cost) | Audits silent-failure risk, auth-refresh blast radius, MTTR, surface count delta, and bus factor; raises non-shippable flags for missing monitoring |

### Extended Council (8 agents — `--extended` flag)

Adds three additional lenses. The Reframer runs **first** (Phase 0) with expanded business context; the other two join the parallel deliberation.

| Agent | Color | Lens | Phase | Role |
|-------|-------|------|-------|------|
| **The Reframer** | Teal | Strategic framing | **Phase 0 (solo, first)** | Validates the proposal is asking the right question before council deliberates |
| **Pragmatist** | Orange | Execution reality | Phase 1 (parallel) | Grounds vision in team capacity, budget, and shipping velocity |
| **Edge Case Finder** | Purple | Failure modes | Phase 1 (parallel) | Identifies specific inputs, states, and sequences that break assumptions |

**Phase 0 context**: The Reframer receives PROFILE.yaml, ROADMAP.md, client CLAUDE.md, and recent council sessions — giving it the strategic awareness to assess framing quality. It also applies the **Rumelt Strategy Lens** (Diagnosis → Guiding Policies → Actions + Standard Kit Test) to catch proposals that jump to solutions without diagnosing the problem or introduce unnecessary complexity. If it suggests a reframe, the user is asked to approve before the council proceeds.

**When to use extended**: Architecture decisions affecting multiple systems, venture-level commitments, proposals that might be solving the wrong problem, or any decision where "works in the happy path" isn't sufficient.

## Stack-Aware Deliberation

Every council deliberation runs against the user's actual toolchain AND operate cost, not a generic software baseline. Two standard-council agents enforce this discipline in every session:

### Capability Scout (Gray) — BUILD cost discipline
- **Inventory-before-build**: installed skills, MCPs, commands, agents, hookify rules, n8n workflows, edge functions, and prior council sessions are checked before any agent recommends new construction. NIH-by-default is a bias, not a virtue.
- **Estimate translation**: Any time/effort figure surfaced by other agents is broken into (a) human work AI cannot compress (OAuth clicks, dev portal, judgment), (b) AI-compressible execution (code scaffolding, doc reading, API integration via MCP, boilerplate), and (c) real-time observation windows (testing, tuning, trust-building). Generic engineer-hours get translated into session-hour wall-clock.
- **Anchor-bias detection**: When another agent's recommendation hinges on an effort/cost figure, Capability Scout verifies the figure assumes the user's stack. If not, it restates the figure against stack-adjusted reality.

### Reliability Engineer (Yellow) — OPERATE cost discipline
- **Failure visibility audit**: For every new tool/surface, loud vs. medium vs. quiet failure classification. Quiet failures are flagged as non-shippable without monitoring.
- **Auth-refresh blast radius**: Explicit expiry calendar for every credential (n8n OAuth 90d, GitHub PAT configurable, VPS SSH tunnel on Mac sleep/wake). Fail-loud-or-quiet per surface.
- **MTTR estimates**: When it breaks at 2pm Tuesday, how long before it's running again?
- **Surface count delta**: Does this add a new system to the user's mental map, or reuse existing infrastructure? Mental-map tax is real operational cost.
- **Bus factor / operator lock-in**: Is the user the sole operator? If yes, surface it explicitly.
- **Non-shippable flags**: Any proposal with low failure visibility + high MTTR + bus factor 1 gets flagged. Synthesis must either add day-one monitoring OR acknowledge the silent-failure risk explicitly.

**Why this matters**: Build cost and operate cost are different disciplines. A "cheap to build" tool that silently fails every 90 days when OAuth expires is not cheaper than a "more expensive to build" tool with loud failure paths. Without a dedicated operate-cost lens, the council structurally under-prices the cost of ownership.

## No-Pre-Filter Discipline

All council agents — standard AND extended — must NOT pre-filter recommendations based on assumed user capacity, bandwidth, multi-venture load, cash flow constraints, or projected "can the user handle this." Give full honest analysis of each path at full quality. The user prioritizes; the council does not rank by projected manageability.

- Pragmatist may cite resource constraints the user has explicitly stated (e.g., "cash-constrained Q2" from memory), but must NOT soften recommendations on unstated capacity assumptions.
- Capability Scout reports estimates honestly (including full-spec numbers) — does not down-scope to MVP unless asked.
- Reliability Engineer reports all failure modes and required mitigations — does not defer monitoring work to "v2" for capacity reasons.
- If the user wants capacity-aware framing, they will ask for it explicitly.

Premature pattern-matching on user psychology is patronizing and produces under-scoped recommendations.

## When to Convene the Council

- Before committing to a new venture or major pivot
- When evaluating architecture decisions with long-term consequences
- When a proposal sounds "too good to be true"
- Before resource allocation decisions (budget, team time, tool investment)
- When you need structured disagreement, not just information
- When you suspect the problem framing itself might be wrong (use `--extended`)

## Tool Differentiation

| Need | Tool | Why |
|------|------|-----|
| Test one belief against docs | `/challenge` | Single-direction evidence search |
| Gather information from sources | `/agentresearch` | Parallel research workers + verification |
| Evaluate from multiple lenses | `/council` | Parallel perspective agents + synthesis |
| Deeper multi-lens with framing validation | `/council --extended` | 8 agents: Phase 0 reframe check + 7-agent parallel deliberation |
| Build with parallel coders | `/build-with-agent-team` | Contract-first implementation |

## Session Files

Council sessions persist to `council/sessions/` by default. Each file contains:
- The original proposal (and reframed version if applicable)
- Phase 0 reframer report (extended mode)
- All agent reports (5 or 8, full text)
- The synthesis with confidence spread
- Debate or pre-mortem results (if applicable)
- **Stack Reality Summary** from Capability Scout — always present
- **Operate-Cost Audit** from Reliability Engineer — always present; non-shippable flags surfaced prominently

Reference prior sessions when deliberating on related topics.

## Strategic Alignment Footer (MANDATORY)

Every council synthesis MUST end with a Strategic Alignment footer that ties the deliberation back to project roadmap and priorities. This prevents council output from becoming academically interesting but strategically unmoored.

### Format

```
## Strategic Alignment

**ROADMAP item(s) this advances**: <list specific NOW/NEXT items, or "None directly">
**ROADMAP item(s) this REJECTS**: <list items this proposal explicitly deprioritizes, or "None">
**If this advances nothing**: <justification for why the work still matters, OR a concrete ROADMAP addition that should be created>
```

### Rules

1. **Specificity**: Reference real item IDs or NOW/NEXT entries. "Aligns with X work" is insufficient — cite the actual roadmap item ID.
2. **Trade-offs**: If this proposal displaces existing work, NAME what gets pushed. Silence about trade-offs is a strategic drift signal.
3. **Escape hatch**: If the council is evaluating something genuinely orthogonal (e.g., crash recovery, infra debt), the footer can state: "Orthogonal to active ROADMAP — infra work that unblocks N items downstream." But the unblock path must be specific.
4. **Failure mode**: If you find yourself writing "this might help with…" you're hedging. The footer's purpose is forcing a clear answer.

### When to skip the footer

Only in **pre-mortem** mode, where the output is a failure-mode analysis rather than a go/no-go decision. Even then, include a "Prevention Priorities" section that names the ROADMAP items most at risk.

### Enforcement

The `completion-verifier` Stop hook checks for the footer in council session files. Missing footer = flagged at session end, must be added before the session exits cleanly.

## Council-before-Implementation Pattern (laser-precision gate)

When the user signals any of: "elite", "premium", "absolute laser precision", "no regression", "mission-critical", or rejects ExitPlanMode in favor of invoking `/council` directly —

Run `/council --extended` on the PLAN FILE before ExitPlanMode, not after ExitPlanMode on the code. Integrate amendments as v1 → v2 plan revision before any implementation tool call.

**Signal for this pattern**: user rejects ExitPlanMode OR invokes `/council --extended` with no argument (= plan file auto-detected). Treat both as "validate before commit." The Reframer's value is highest BEFORE 7 Phase-1 agents analyze a potentially wrong-framed proposal.

**Why it works**: extended council on a PLAN FILE catches BLOCKING issues cheaply (token cost of 8 agents + 6-15 validators vs. cost of shipping a bug + rolling back + re-reviewing). The v1→v2 amendment cycle has a proven track record in 2026-04 for catching URL-pattern drift, spurious gate ticks, null-vs-INSUFFICIENT conflation, false "create missing" flags on already-shipped infrastructure, and fence-breaching scope creep.

**Zero-cost discipline**: LLM-judged signal ("premium/elite/no-regression") → extended council on plan → v1→v2 amendment cycle. No hook needed — the signal detection is fuzzy and benefits from judgment, not shell heuristics.

## Auto-Resolution Pattern (when autonomous-mode signal present)

When the user has signalled autonomous mode (typically via a project-local memory entry such as `feedback_autonomous_mode_*` or equivalent rule) AND issues a quality-direction signal ("best quality + simple", "ship it clean", "do what u gotta do"), the synthesiser MUST auto-resolve all council questions per recipe rather than presenting them as a menu.

**Recipe** (apply in order until question is settled):
1. Doctrine — does an existing rule file or memory dictate the answer?
2. Repo precedent — has the codebase made this call before in similar context?
3. Industry best practice — is there a clear consensus answer?
4. Reframer + Devil's Advocate consensus — pick the path both endorsed
5. Default to "best quality" — even if slower, when the question is taste-driven

**Document the resolutions in the session file** under an "Operator's Auto-Resolution" (or named-after-the-operator) table with columns: Question | From (which agent raised it) | Decision | Reasoning. This makes the auto-resolutions auditable and lets the user reverse any specific call by editing the session file.

**When NOT to auto-resolve** (escalate to user instead):
- Genuine taste/brand/strategy decisions (not implementation)
- Decisions that displace ROADMAP NOW lane items
- Decisions that change pricing, partnership scope, or external commitments
- Decisions that affect cross-organisation integrations the user owns the relationship for

**Pattern**: skip the menu, document the resolutions, let the user reverse any specific call by editing the session file. Worked across multiple sessions in 2026-05 — converts what would have been blocking back-and-forths into one autonomous synthesis pass.
