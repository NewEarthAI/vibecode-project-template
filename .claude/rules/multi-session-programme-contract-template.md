# Multi-Session Programme Alignment Contract — Generic Template

**Purpose**: Copy this skeleton when launching any programme that spans ≥3 related sessions sharing a verification standard, framework set, or build sequence. Replace placeholders with programme-specific values. The 10 clauses are non-negotiable; the predicates and verification gates are programme-specific.

**Composes with**: `.claude/skills/prompt-forge/SKILL.md` § "Mode: programme-launchpad". The prompt-forge skill's programme-launchpad mode produces one alignment contract per programme using this template as the body.

**Auto-load**: this template is reference-only (not auto-loaded). The DERIVED contract (`.claude/rules/<programme-name>-alignment.md`) auto-loads contextually when its predicate matches.

---

## How To Use This Template

1. Identify the programme name (e.g., "operational-intelligence-synthesis", "newclaw-rollout", "client-migration-Q3").
2. Copy this file to `.claude/rules/<programme-name>-alignment.md`.
3. Fill in the four programme-specific values:
   - **Auto-load predicate** — which file globs / topics scope the contract
   - **Verification gate** — what makes any artefact in this programme "done"
   - **MVP scope** — which framework / phase / module subset is the first wave
   - **In-scope detection criteria** — how a session knows it's programme-class work
4. Reference the spec for substantive decisions; the contract only enforces process.
5. Update the programme's spec, `MEMORY.md` "In-Flight Work" entry, and `CLAUDE.md` "In-Flight Programme" section so the contract is discoverable.

---

## The 10 Hard Clauses

Any session in scope MUST do all of the following before claiming completion. These clauses are non-negotiable across all programmes; only their parameters vary.

### 1. Read programme spec FIRST

Before any tool call that creates or modifies a programme artefact, read the programme spec in full. Failure mode prevented: a session redefining the verification gate, picking work outside the MVP scope, or merging an artefact that has not passed the programme's gate.

### 2. Declare which session this is

Each session has a single, named scope. Before substantive work, declare:

```
Programme session: {N}
Scope: {what this session is allowed to ship per programme spec}
Out of scope: {what belongs to a different session}
```

If the session number is unclear, halt and ask the operator. Do NOT guess. Failure mode prevented: scope creep — session 2 silently shipping session 3's work.

### 3. Compose with existing tools — never rebuild

The programme spec lists existing assets. Every session's first move on a new phase is: "which existing asset am I composing with right now?" If the session reaches for a tool not on the list, document why before invoking. Not-invented-here is a programme failure mode given the existing infrastructure.

### 4. Pass the programme's verification gate before merging any artefact

No artefact lands as done until the programme's verification gate passes. Standard gates include:

| Gate type | Examples |
|-----------|----------|
| Code artefacts | typecheck pass + `/code-council` PASS or ADVISORY + post-deploy smoke |
| Doctrine / strategic specs | deletion test + `/code-council` on doc-as-artefact + real-decision test (apply to one named past decision; require non-trivial insight) |
| Infrastructure / migrations | dry-run + canary + rollback path verified |

The programme spec names which gate applies. An artefact that fails any required gate is rewritten or downgraded; never silently merged. Failure mode prevented: anti-sycophancy collapse — outputs self-graded as "good enough" without machine-checkable evidence.

### 5. Strategic Alignment footer on every council / spec / continuation

Every council session, every spec file, and every continuation file MUST end with the Strategic Alignment footer (per `council-protocol.md`):

```
## Strategic Alignment
**ROADMAP item(s) this advances**: {list}
**ROADMAP item(s) this REJECTS**: {list}
**If this advances nothing**: {justification OR ROADMAP addition}
```

Failure mode prevented: programme drift — a session ships an artefact that doesn't move the project's NSM.

### 6. Manifest update before ending the session

Before any session ends, append to the programme spec's "Recently Completed" table. Update `ROADMAP.md` "Recently Completed" with the same entry. Update `MEMORY.md` "In-Flight Work" line if the programme advances. Failure mode prevented: invisible progress — a session ships work but the next session can't tell what already shipped.

### 7. Layman voice in chat; technical register in artefacts

Per `~/.claude/rules/layman-mode.md`: every chat reply applies layman voice (define jargon inline, Commonwealth spelling, decide-don't-menu, no raw paths). Doctrine docs, skill specs, council session bodies, and rule files are technical-register carve-outs and may use full technical vocabulary. Failure mode prevented: operator decision fatigue from codename overload.

### 8. Anti-sycophancy enforcement — name the tools that fire it

Every programme inherits an anti-sycophancy directive. Three existing mechanisms enforce it and MUST fire on every load-bearing decision:

- Devil's Advocate agent (in every `/council` invocation)
- Code-review identity rule (`code-review-identity.md` — auto-loaded on any review work)
- Stress-test grilling skill (`pocock-grill-with-docs` — must be invoked at every spec / doctrine authoring phase)

A session that routes around any of the three on a load-bearing decision has violated the contract. Document in the council / continuation file if any was deliberately skipped, with reason.

### 9. Plan-then-execute on every non-trivial session

Every session that ships substantive artefacts must:
1. Enter plan-mode before substantive work (per `/plan` command)
2. Produce a plan v1
3. Run `/council --extended` on the plan if the session involves a load-bearing strategic decision
4. Apply council amendments → plan v2
5. Operator approves plan v2 BEFORE execution proceeds

Skip this only for trivial work (single-line ROADMAP edits, manifest appends, typo fixes). Failure mode prevented: shipping artefacts on wrong-framed questions.

### 10. Output chunking — manifest-first for any deliverable >3,000 tokens

Per `output-chunking.md`. Multi-file scaffolds, long doctrine docs, master continuations, council bodies all hit this. Always emit a manifest first, then write each section / file via the Write tool. Never echo full long deliverables inline. Failure mode prevented: silent truncation at output-token limit, leaving a partial deliverable with no recoverable artefact.

---

## What The Derived Contract Adds On Top

A programme-specific contract derived from this template adds these four sections:

### Auto-load predicate

```
Detection signals: edits to {file globs}, council sessions whose title contains "{topic}", any chat that mentions {programme-specific keywords}.
```

### In-scope detection criteria

```
A session is in scope if ANY of these are true:
- It touches {programme spec file}
- It creates or edits a file under {programme artefact directory}
- It runs /council on a programme topic ({list})
- The operator explicitly says "this is programme work"
```

### What the contract is NOT

```
- Not a gate that blocks — a session can ship with stated gaps if operator explicitly accepts them; only silent gaps are forbidden
- Not a substitute for the programme spec — read the spec for substantive decisions
- Not retroactive — applies forward-only from contract creation date
- Not for trivia — typo fixes, layout tweaks, single-line edits skip this contract
```

### Failure precedents

```
Prospective forecasts of failure modes the contract prevents (not retrospective blame).
List 3-5 forecast failure modes the contract's clauses are designed to catch.
```

---

## Composition With Existing Workshop / Project Rules

| Existing rule | How the programme contract composes |
|---------------|-------------------------------------|
| `council-protocol.md` | Programme contract clause 5 enforces the Strategic Alignment footer the council protocol already requires; contract clause 8 names the council's Devil's Advocate as the anti-sycophancy enforcer |
| `output-chunking.md` | Programme contract clause 10 is a pointer to this rule for any programme deliverable over 3,000 tokens |
| `pre-completion-pocock-check.md` | Programme contract clause 4 (verification gate) supersedes this rule's six-question checklist when both apply; pocock-check still runs for non-programme work |
| `agentic-loop-guards.md` | Programme contract clauses 2 (declared scope) and 6 (manifest update) operationalise this rule's "claim with evidence" requirement |
| `layman-mode.md` | Programme contract clause 7 is a pointer to this rule; no override |

The programme contract is additive — it does not replace the workshop's standard rule set, it adds programme-specific enforcement on top.

---

## Anti-Patterns When Deriving A Contract

| Wrong | Why | Right |
|-------|-----|-------|
| Skipping the auto-load predicate | Contract never fires; sessions drift silently | Predicate is mandatory — pick file globs OR topic keywords OR both |
| Adding ≥15 clauses to "be thorough" | Contract becomes unreadable; clauses get ignored | 10 clauses max — programme specifics fill in the spec, not the contract |
| Letting the contract substitute for the spec | Operator reads the contract, skips the spec, misses programme-specific decisions | Contract enforces process; spec defines substance — both required |
| Auto-loading the contract on `*` matcher | Token bloat on every tool call | Predicate must be specific (path globs / file types / topic keywords) |
| Forgetting to update MEMORY.md "In-Flight Work" | Fresh chats don't see the programme is active until they touch a programme file | Memory entry is mandatory — single-pointer drift = single-point-of-failure |

---

## When NOT To Use This Template

- Single-session work — use standard prompt-forge instead
- Continuation of an existing programme — extend the existing contract, do not create a new one
- Ad-hoc R&D with no shared verification standard — no contract needed; pick artefacts case-by-case
- Trivial scaffolding (a tutorial series, a doc cleanup pass) — overhead exceeds value

A programme without a shared verification standard is not really a programme — it's a list of related sessions. Don't apply this template to those.

---

## References

- `.claude/skills/prompt-forge/SKILL.md` — § "Mode: programme-launchpad" generates derived contracts from this template
- `.claude/rules/council-protocol.md` — Strategic Alignment footer (clause 5)
- `.claude/rules/output-chunking.md` — manifest-first pattern (clause 10)
- `.claude/rules/pre-completion-pocock-check.md` — pre-completion gates (composes with clause 4)
- `~/.claude/rules/layman-mode.md` — voice carve-outs (clause 7)
