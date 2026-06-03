---
name: define-destination
description: |
  Authors a project's destination — a written, falsifiable statement of what
  success looks like, in a known file (DESTINATION.md), that any reader can use
  to judge whether the work is on course. The generative complement to the
  all-diagnostic framing-audit suite: the suite AUDITS an existing framing;
  this skill WRITES the destination in the first place. Walks the operator
  through a validated six-part recipe — a three-way scope gate plus five content
  elements (end-state as conditions, a third-party-observable binary test, a
  still-true-later clause, a could-the-test-lie clause, and a calibrated
  backward chain). Refuses vague input, refuses to overwrite an existing
  destination silently, and never copies a destination from another repo.
  Use when: "define the destination", "set the destination for this project",
  "destination kickoff", "what does done look like for X", "where are we
  headed", "author a destination", "what would make this effort worth having
  done", or when a project-setup wizard needs the success artefact.
  Do NOT use for: the daily destination glance (that rides inside the
  daily-plan flow, not this skill); a diagnostic framing audit of an existing
  question (use /reduce-to-first-principles); standalone daily use (rejected —
  daily surfacing is the daily-plan flow's job).
classification: capability-uplift
version: 1.0
created: 2026-05-18
operationalises: none — net-new generative primitive; the generative complement to the all-diagnostic framing-audit skill suite
spec: specs/11_DEFINE_DESTINATION_IMPLEMENTATION_PLAN.md
writes: DESTINATION.md (at project root)
allowed-tools: Read, Glob, Grep, AskUserQuestion, Write
user-invocable: true
parameters:
  - name: project_scope
    type: string
    required: true
    description: The project, venture, or effort to author a destination for; free text. Must name an actual effort with enough specificity to identify what changes — not a bare noun ("the business") and not a vague verb phrase ("improve things").
  - name: invoked_by
    type: enum
    required: false
    description: One of operator | setup_wizard — defaults to operator. setup_wizard is the project-setup wizard calling this skill for its success-artefact step. Affects only the closing message register, never the recipe.
  - name: confirm_overwrite
    type: boolean
    required: false
    description: Operator's explicit confirmation to archive the prior DESTINATION.md and author a new one. Defaults to false. The skill NEVER overwrites without this set true.
---

# /define-destination — Author a Project's Destination

**Status**: v1.0 (Define-Destination build — 2026-05-18)
**Skill spec**: `specs/11_DEFINE_DESTINATION_IMPLEMENTATION_PLAN.md` (v2 — operator-approved)
**Class**: generative workshop skill — it AUTHORS an artefact. It is NOT a diagnostic skill; it does NOT carry the anti-anchoring guard (`.claude/skills/_shared/anti-anchoring-guard.md`). It is the one skill permitted to WRITE the `generative_primitive` provenance tag that the diagnostic suite's Branch D consumes.

---

## Purpose

The framing-audit skill suite is entirely diagnostic — every primitive audits a framing that already exists (`/reduce-to-first-principles` audits a question, `/check-commensurability` audits a comparison, `/map-feedback-loops` audits a system, `/audit-artefact-grounding` audits an artefact). Nothing in the suite AUTHORS the destination a project is steering toward. This skill fills that generative gap.

It produces a **destination** — a written statement of what success looks like — into a fixed file, `DESTINATION.md`, at the project root. The destination is not a vision statement and not a task list; it is a falsifiable artefact: it states the end-state as conditions in the world, names a binary test a third party could run, and chains backward to the first step from here.

**The dominant failure mode this skill is designed against — planning theatre.** A polished destination that is adopted, propagated, and glanced at daily while producing zero navigational value: the operator *feels* oriented, but the destination is hollow (it restates outputs as if they were outcomes), or stale, or the success test is one the operator could pass while the real outcome is bad. Every element of the recipe is a guard against one variety of this failure. A skill that produces a hollow-but-polished destination has failed even when its output looks complete.

---

## When to Invoke

### Explicit triggers
- "define the destination", "set the destination for this project", "destination kickoff"
- "what does done look like for X", "where are we headed", "author a destination"
- "what would make this effort clearly worth having done?"

### Implicit triggers
- A project-setup wizard reaches its success-artefact step (`invoked_by: setup_wizard`)
- An existing repo has no `DESTINATION.md` and the operator is about to start substantive work — the adoption path for repos that never ran the setup wizard

### Anti-triggers — the skill refuses or redirects
- **The daily destination glance** — surfacing the destination before the task list is the **daily-plan flow's** job, not this skill's. This skill is for *authoring and reviewing*, not daily display.
- **A diagnostic framing audit of an existing question** — redirect to `/reduce-to-first-principles`.
- **Standalone daily use** — rejected by design (the council showed standalone daily-use destination tools get abandoned). Standalone invocation IS available for *first-time authoring* in an existing repo; it is NOT a daily habit surface.

---

## Two Modes (auto-detected)

| Mode | Trigger | Behaviour |
|------|---------|-----------|
| **author** | No `DESTINATION.md` exists at project root | Walk the six-part recipe; write a fresh `DESTINATION.md` |
| **review** | A `DESTINATION.md` already exists | Surface the current destination; REFUSE to overwrite silently. The operator chooses: (a) it still holds, unchanged → advance only the `reviewed` date; (b) it needs updating → archive the prior version and re-author; (c) abandon the review → write nothing |

Mode is detected at Step 2, never supplied by the operator. The pre-existence check is the parallel-worktree + re-invocation overwrite-collision guard.

---

## Minimum Viable Input (MVI)

The skill refuses to author a destination from input too thin to produce a real one.

### Required MVI

| Field | Validation predicate |
|-------|----------------------|
| `project_scope` | Names an actual project / venture / effort with enough specificity to identify what would structurally change if it succeeded. **General test**: could a reader, given only `project_scope`, name at least one concrete thing that would be observably different in the world on success? If no → MVI fails. A bare noun ("the business", "the app") and a vague verb phrase ("improve things", "grow") both fail this test. |

### Below-MVI handling

When MVI fails, emit the structured insufficient-input error and HALT. NEVER fabricate a destination from below-MVI input — a fabricated destination is the purest form of planning theatre.

```yaml
error: insufficient_input
skill: define-destination
missing_fields:
  - field: project_scope
    reason: <one sentence — why the supplied scope cannot anchor a destination>
example_input: |
  project_scope: "The buyer-tagging sync that pulls tagged buyers from the CRM
  into the deal-matching pipeline so dispo can match a new deal to ready buyers
  in under a minute."
recommended_action: |
  Restate project_scope so a reader can name one observable change success
  would produce, then re-invoke.
```

---

## The Validated Six-Part Recipe

The recipe is a three-way **scope gate** (Element 0) followed by five **content elements**. It is v2 — operator-approved, audited three times (`specs/11` §"Frame status"). Any change to the recipe re-runs the Step-1 `/reduce-to-first-principles` reduction; it is never a silent patch.

### Element 0 — Scope gate (three branches)

Before authoring anything, the skill asks: **does this project have a measurable end-state?** Three branches:

- **Yes** — the project has a measurable end-state → proceed to Elements 1–5; write a confirmed destination.
- **No, and not ever** — open-ended exploration, research, or learning with no measurable end-state (the workshop itself is such a project) → the skill **REFUSES to produce a destination** and routes the operator to `/reduce-to-first-principles` (on the research question) and `/map-feedback-loops` (on the inquiry's loops). It does NOT write a hollow destination to satisfy the invocation.
- **Not yet** — a venture in discovery phase: it has a direction but the success metric is not yet defined → the skill produces a **DRAFT destination**. It asks one lightweight question — "what would make this effort clearly worth having done?" — drafts Elements 1–2 as **hypotheses**, drafts Elements 3–5 on top of those hypotheses, and marks the whole artefact `status: DRAFT — UNCONFIRMED`. The operator gets a working document, not a refusal.

The artefact records which branch was taken (`scope_gate` frontmatter field), so any reader knows the gate was run.

### Element 1 — End-state as conditions, not outputs

"X is true in the world" — never "X was built / shipped / launched". An output can be 100% delivered while the success it was meant to create is absent. **General test for the adversarial guard**: if the stated end-state names an artefact and a verb of creation (built, shipped, launched, delivered, written, deployed), it is an output, not an end-state — the skill restates it as the condition the output was meant to create and asks the operator to confirm the restatement. (Example: "the buyer-tagging sync is shipped" → "dispo can match a new deal to a ready buyer in under a minute, every time, without manual lookup".)

### Element 2 — Binary success test

At least one yes/no question, answerable with no argument. **The test must be observable by a third party WITHOUT asking the operator.** **General test for the internal-consensus guard**: if the proposed binary test can only be answered by querying a person's opinion or an internal group's agreement, it is not third-party-observable — the skill asks the operator to name the external evidence that opinion or agreement would rest on, and uses that as the test. ("The founding team agrees we should continue" is NOT valid — it cannot be checked externally. "Retention ≥ 60% at 90 days" IS valid — it is a measured threshold.)

### Element 3 — Still-true-later clause

What must STILL hold at a stated interval after the end-state is reached. Guards against **time-decay** — a win that was real, then eroded. The clause names the interval explicitly (e.g. "still true 6 months after launch").

### Element 4 — Could-the-test-lie clause

The named scenario in which the Element 2 success test reads "pass" while the real outcome is bad — because the test was a poor proxy, or was gamed. Guards against **proxy-failure**. Distinct from Element 3: Element 3 asks "is the win still true *later*?"; Element 4 asks "did the test ever *mean* success at all?"

### Element 5 — Backward chain, with calibration

2–3 intermediate conditions, each the prerequisite for the next, chained from the end-state back to the first step from here. **Calibration rule**: 2–3 milestones suit a short project; for a project expected to run longer than ~3 months, name roughly one milestone per month or per phase. The skill states the calibration it used so the chain's resolution is auditable.

---

## Procedure

The procedure runs in nine steps. Each gating step has a halt condition; the skill exits with a structured verdict at the first halt. The halt envelopes are tabulated in §Halt-Path Discipline.

### Step 1 — Re-contextualise for THIS repo

Read the current repo's `CLAUDE.md` (and `ROADMAP.md` and `specs/00_VISION.md` if present) to ground the destination in *this* project's actual goals and vocabulary. **The skill always authors fresh for the repo it is invoked in. It NEVER copies a destination — or any element of one — from the template repo or another project.** When this skill is propagated to a new repo (Phase E), its first invocation there authors a destination specific to that repo; a `DESTINATION.md` is per-project content and is never templatised.

### Step 2 — Mode detection

Glob for `DESTINATION.md` at the project root. Absent → **author mode**. Present → **review mode** (go to Step 6 before any write).

### Step 3 — MVI gate

Apply the MVI predicate. If `project_scope` fails the general test, emit the structured insufficient-input error and HALT with `verdict: INSUFFICIENT_INPUT`.

### Step 4 — Element 0 scope gate

Ask the operator the scope-gate question (use `AskUserQuestion` — three options: Yes / No, and not ever / Not yet). Branch:

- **Yes** → record `scope_gate_branch: yes`; proceed to Step 5; the artefact will be `status: confirmed`.
- **No, and not ever** → record `scope_gate_branch: no_forever`; HALT with `verdict: SCOPE_REFUSAL`. Emit the structured refusal: name the two redirect skills (`/reduce-to-first-principles` on the research question, `/map-feedback-loops` on the inquiry's loops), state that no `DESTINATION.md` is written, and record that the gate was run. Do NOT write a file.
- **Not yet** → record `scope_gate_branch: not_yet`; ask the one lightweight question ("what would make this effort clearly worth having done?"); proceed to Step 5 in DRAFT sub-mode — Elements 1–2 are drafted as hypotheses, Elements 3–5 are drafted on top of them, and the artefact will be `status: DRAFT — UNCONFIRMED`.

### Step 5 — Walk Elements 1–5

Walk the operator through each element (use `AskUserQuestion` per element). Apply the guards:

- **5.1 — Element 1 (end-state).** Apply the output-vs-condition general test. If the operator supplies an output, restate it as a condition and ask them to confirm the restatement. Record `guards_fired` if the restatement fired.
- **5.2 — Element 2 (binary test).** Apply the third-party-observable general test. If the proposed test rests on internal opinion or consensus, ask for the external evidence it would rest on, and use that. Record `guards_fired` if the internal-consensus guard fired.
- **5.3 — Element 3 (still-true-later).** Require a named interval.
- **5.4 — Element 4 (could-the-test-lie).** Require a concrete named scenario, not "the test might be wrong". If the operator cannot name one, the skill proposes a candidate proxy-failure and asks the operator to confirm or refine it. **Bound**: if the operator rejects the proposed candidate without offering a refinement, do NOT loop — record the skill's proposed candidate as Element 4 with a `guards_fired` entry "Element 4 author-proposed; operator did not refine" and proceed. Element 4 is never left empty, and this step never loops without a terminating condition.
- **5.5 — Element 5 (backward chain).** Apply the calibration rule. State the calibration used.

In DRAFT sub-mode (`not_yet`), Elements 1–2 are recorded as hypotheses (prefixed `HYPOTHESIS:` in the artefact) and the guards still run.

### Step 6 — Pre-existing-file check (review mode only)

If Step 2 detected an existing `DESTINATION.md`: Read it, surface its current content to the operator, and present the three review choices (use `AskUserQuestion`):

- **(a) It still holds, unchanged** → do NOT re-author; advance only the `reviewed` date in the existing file's frontmatter to today; HALT with `verdict: PASS`, `mode: review`, `destination_file.written: false`, `destination_file.reviewed_advanced: true`, `destination_file.status` unchanged.
- **(b) It needs updating** → require `confirm_overwrite: true`. Read the existing `version` from the prior file's frontmatter — **if it is absent or non-integer, treat it as `1`** and record a `guards_fired` entry "prior-file version unreadable — archived defensively as DESTINATION.v1.md". Archive the prior file as `DESTINATION.v{version}.md`; proceed to Step 7 to write a new `DESTINATION.md` with `version` incremented. If `confirm_overwrite` is not true, HALT with `verdict: OVERWRITE_BLOCKED` and instruct the operator to re-invoke with explicit confirmation. (`confirm_overwrite` is evaluated ONLY for choice (b); it is ignored for choices (a) and (c), which neither archive nor write.)
- **(c) Abandon the review** → write nothing, touch nothing; HALT with `verdict: PASS`, `mode: review`, `destination_file.written: false`, `destination_file.reviewed_advanced: false`.

The skill NEVER overwrites or deletes an existing `DESTINATION.md` without an explicit operator confirmation AND an archived copy of the prior version.

### Step 7 — Write DESTINATION.md

Write `DESTINATION.md` at the project root in the format under §DESTINATION.md Format. The frontmatter MUST carry the `generative_primitive` provenance tag (`provenance`, `upstream_skill`, `generated_at`, `project_root`), the `reviewed` date (= `generated_at` on first authoring), the `scope_gate` branch, the `status`, and the `version`. `project_root` is the **absolute path** of the project root (the repo this skill was invoked in) — an absolute path, NEVER a bare directory name, so that two different repos that happen to share a directory name (a fork, a client clone, a test copy) cannot collide in a diagnostic skill's Branch D bounds check. The absolute path is available from the skill's execution context.

### Step 8 — Hand-off recommendations (cite, never copy)

Emit hand-off recommendations. The skill **cites these by name and never reproduces their procedures**:

| Hand-off | Purpose |
|----------|---------|
| `/reduce-to-first-principles` | Audit the destination *question* itself — feed the end-state as `proposed_reduction` with `hypothesis_provenance: generative_primitive` and a `source_hypothesis` block built from the `DESTINATION.md` frontmatter tag. |
| `/map-feedback-loops` (DECISION mode) | Project the second-order effects of the route the backward chain commits to. |
| The council pre-mortem mode (`/council ... premortem`) | Assume the destination is reached but the outcome is bad — work backward to what went wrong. The Element 4 could-the-test-lie clause is the seed for this. |

### Step 9 — Emit structured output

Emit the structured invocation result per §Output Schema.

---

## DESTINATION.md Format

```markdown
---
artefact: destination
generated_by: define-destination
provenance: generative_primitive
upstream_skill: define-destination
generated_at: <ISO date — YYYY-MM-DD>
project_root: <absolute path of the project root — NOT a bare directory name; prevents cross-repo collision in the Branch D bounds check>
reviewed: <ISO date — equals generated_at on first authoring; advanced on a confirmed review>
scope_gate: <yes | not_yet>
status: <confirmed | DRAFT — UNCONFIRMED>
version: <integer — 1 on first authoring; incremented on each re-author>
---

# Destination — <project name>

## End-state (Element 1)
<the success condition(s) in the world — not outputs. In DRAFT mode, prefixed HYPOTHESIS:>

## Binary success test (Element 2)
<at least one third-party-observable yes/no question. In DRAFT mode, prefixed HYPOTHESIS:>

## Still true later (Element 3)
<what must still hold at a named interval after the end-state is reached>

## Could the test lie? (Element 4)
<the named scenario in which the Element 2 test reads pass while the real outcome is bad>

## Backward chain (Element 5)
<2–3+ intermediate conditions, end-state → first step from here; calibration noted>

## Review log
<appended on each review: date, choice taken, one-line justification if updated>
```

A `DESTINATION.md` is per-project content. It is **never templatised** and never copied between repos — only this skill propagates.

---

## Output Schema

```yaml
skill: define-destination
version: 1.0
verdict: <PASS | DRAFT | SCOPE_REFUSAL | INSUFFICIENT_INPUT | OVERWRITE_BLOCKED>
mode: <author | review>
scope_gate_branch: <yes | no_forever | not_yet>

mvi:
  passed: <bool>
  missing: <list[string]>

destination_file:
  path: DESTINATION.md
  written: <bool>             # true ONLY when new destination CONTENT was authored; a review
                              # choice (a) that advances only the `reviewed` date is written: false
  reviewed_advanced: <bool>   # true when the `reviewed` frontmatter date was advanced to today
                              # (first authoring, or review choice (a) — a confirmed review)
  status: <confirmed | draft_unconfirmed | not_written>
                              # machine-readable form; the DESTINATION.md frontmatter `status` field
                              # is the human-readable form — `draft_unconfirmed` ↔ `DRAFT — UNCONFIRMED`
  archived_prior: <DESTINATION.v{n}.md | null>
  version: <integer | null>

recipe:                       # omitted on SCOPE_REFUSAL / INSUFFICIENT_INPUT
  element_1_end_state: <string>
  element_2_binary_test: <string>
  element_3_still_true_later: <string>
  element_4_could_the_test_lie: <string>
  element_5_backward_chain: <list[string]>
  calibration_used: <string>

provenance_tag:               # the tag written into DESTINATION.md frontmatter; omitted when no file written
  provenance: generative_primitive
  upstream_skill: define-destination
  generated_at: <ISO date>
  project_root: <string>

guards_fired: <list[string]>  # e.g. "output-as-end-state restated", "internal-consensus test challenged"

hand_offs: <list[{skill, purpose}]>

recommended_action: <string>

invocation_metadata:
  timestamp: <ISO 8601 UTC>
  skill_version: 1.0
  invocation_id: <uuid>
```

---

## Halt-Path Discipline

The procedure has FOUR halt points. Each MUST emit a complete, well-formed envelope.

| Halt point | Trigger | Envelope |
|------------|---------|----------|
| MVI failure (Step 3) | `project_scope` fails the MVI general test | `verdict: INSUFFICIENT_INPUT`; `mode: author`; `mvi.passed: false`; `mvi.missing` populated; `destination_file.written: false`; `destination_file.reviewed_advanced: false`; `recipe` omitted; structured insufficient-input error emitted |
| Scope refusal (Step 4) | Scope gate → "No, and not ever" | `verdict: SCOPE_REFUSAL`; `mode: author`; `scope_gate_branch: no_forever`; `destination_file.written: false`; `destination_file.reviewed_advanced: false`; `recipe` omitted; `hand_offs` names `/reduce-to-first-principles` + `/map-feedback-loops`; the refusal records that the gate was run |
| Overwrite blocked (Step 6) | Review choice (b) without `confirm_overwrite: true` | `verdict: OVERWRITE_BLOCKED`; `mode: review`; `destination_file.written: false`; `destination_file.reviewed_advanced: false`; `destination_file.status` unchanged; `recommended_action` instructs re-invocation with explicit confirmation |
| Review-unchanged / abandon (Step 6) | Review choice (a) or (c) | `verdict: PASS`; `mode: review`; `destination_file.written: false` (no new content authored). For **(a)** `destination_file.reviewed_advanced: true` — the `reviewed` frontmatter date is touched to today (a confirmed review). For **(c)** `destination_file.reviewed_advanced: false` — nothing changed at all. |

A clean author-mode completion emits `verdict: PASS` (`scope_gate: yes`) or `verdict: DRAFT` (`scope_gate: not_yet`), with `destination_file.written: true` and `reviewed_advanced: true`. `mode` is `author` on every halt that occurs before mode could be `review` — Step 2 (mode detection) runs before Steps 3 and 4, so `mode` is always populated.

---

## Anti-Patterns the Skill Must Refuse

| Anti-pattern | Detection signal | Defence |
|--------------|------------------|---------|
| **AP1 — Planning theatre** | A polished destination whose elements restate the `project_scope` without naming an observable change | Every element has a general test (Elements 1, 2) or a named-scenario requirement (Element 4); a destination that passes none of them is hollow |
| **AP2 — Output-as-end-state** | Element 1 names an artefact + a verb of creation | Step 5.1 output-vs-condition general test; restate as a condition and confirm |
| **AP3 — Internal-consensus test** | Element 2 rests on a person's opinion or a group's agreement | Step 5.2 third-party-observable general test; ask for the external evidence |
| **AP4 — Silent overwrite** | A `DESTINATION.md` exists and the skill writes over it without surfacing it | Step 6 pre-existence check; refuse-to-overwrite; archive on confirm |
| **AP5 — Cross-repo copy** | The destination reuses content from the template or another repo | Step 1 re-contextualisation; always author fresh for the current repo |
| **AP6 — Fabricate from thin input** | A destination produced from a bare-noun `project_scope` | Step 3 MVI gate halts BEFORE any element is authored |
| **AP7 — Force a destination on a no-forever project** | A measurable destination written for pure open-ended exploration | Step 4 scope gate; "No, and not ever" → `SCOPE_REFUSAL`, redirect, no file |
| **AP8 — Element 3/4 collapse** | Element 3 and Element 4 say the same thing | Element 3 = "still true later?"; Element 4 = "did the test ever mean success?" — distinct questions; the skill checks they are not duplicates |

---

## Hidden Risks the Skill Surfaces (Not Silent)

1. **The destination is genuinely premature** — surfaced via the `not_yet` branch as a `DRAFT — UNCONFIRMED` artefact, not a false-confident `confirmed` one.
2. **The project has no measurable end-state** — surfaced as `SCOPE_REFUSAL` with redirects, not papered over with a hollow destination.
3. **An existing destination would be lost** — surfaced at Step 6; the prior version is archived, never silently discarded.
4. **The success test could be gamed** — Element 4 names the proxy-failure scenario explicitly so the operator sees it before adopting the test.
5. **A re-authored destination silently mirrors the day's work** — review choice (b) requires an explicit one-line justification in the `Review log`; the friction is deliberate.

---

## Composition with Other Skills & Flows

| Skill / flow | Composition |
|--------------|-------------|
| `/reduce-to-first-principles`, `/map-feedback-loops`, council pre-mortem | Step 8 hand-offs — cited by name, procedures never reproduced. The destination's end-state, fed to `/reduce-to-first-principles` with `hypothesis_provenance: generative_primitive`, is accepted via the diagnostic suite's Branch D (bounded-tag standard guard). |
| `.claude/skills/_shared/anti-anchoring-guard.md` | This skill is the ONLY skill permitted to WRITE the `generative_primitive` tag (library Step 2.2 Branch D step 4). It does not CITE the library — it is generative, not diagnostic. |
| The project-setup wizard | Calls this skill (`invoked_by: setup_wizard`) for its success-artefact step (Phase C, `specs/11` §4 Component 3 Edit 1). |
| The daily-plan flow | Reads the `DESTINATION.md` `reviewed` date for the stateless staleness signal and surfaces the destination glance before the task list (Phase C, `specs/11` §4 Component 3 Edit 2). Daily surfacing is the daily-plan flow's job — NOT this skill's. |

---

## Tests — Required Before Skill Ships

Behavioural acceptance tests per `specs/11` §5. The skill cannot be considered shipped until all ten return correct behaviour.

### Test 1 — Happy path (a project with a measurable end-state)

**Input**: `project_scope` names a project with a clear measurable end-state (e.g. the buyer-tagging sync). Operator answers the scope gate "Yes".

**Expected**: scope gate → `yes`; the skill walks Elements 1–5; `DESTINATION.md` is written with `status: confirmed`, `version: 1`, the full `generative_primitive` frontmatter tag, and all five element sections populated.

**Verification**: `verdict == PASS`; `scope_gate_branch == yes`; `destination_file.written == true`; `destination_file.status == confirmed`; frontmatter carries `provenance: generative_primitive`, `generated_at`, `project_root`, `reviewed == generated_at`; all five `recipe` fields populated.

### Test 2 — Scope gate / no-forever (a pure-exploration project)

**Input**: `project_scope` is a pure open-ended exploration / research / learning effort (the workshop itself is such a project). Operator answers the scope gate "No, and not ever".

**Expected**: the skill REFUSES to produce a destination; routes to `/reduce-to-first-principles` and `/map-feedback-loops`; writes no file; the structured output records the gate was run.

**Verification**: `verdict == SCOPE_REFUSAL`; `scope_gate_branch == no_forever`; `destination_file.written == false`; `hand_offs` names both `/reduce-to-first-principles` and `/map-feedback-loops`; no hollow destination produced.

### Test 3 — Scope gate / not-yet (a discovery-phase venture)

**Input**: `project_scope` is a venture with a direction but no defined success metric. Operator answers the scope gate "Not yet".

**Expected**: the skill asks the one lightweight question; drafts Elements 1–2 as hypotheses; writes `DESTINATION.md` with `status: DRAFT — UNCONFIRMED`; Elements 1–2 are prefixed `HYPOTHESIS:`.

**Verification**: `verdict == DRAFT`; `scope_gate_branch == not_yet`; `destination_file.status == draft_unconfirmed`; frontmatter `status: DRAFT — UNCONFIRMED`; Element 1 and Element 2 sections are hypothesis-marked.

### Test 4 — Vague input (a one-line ambiguous goal)

**Input**: `project_scope` = "make the business better".

**Expected**: MVI insufficient-input error with an example template; no destination authored.

**Verification**: `verdict == INSUFFICIENT_INPUT`; `mvi.passed == false`; `mvi.missing` includes `project_scope`; output carries an `example_input` block; `destination_file.written == false`.

### Test 5 — Empty input (no project named)

**Input**: the skill invoked with `project_scope: null`.

**Expected**: structured error requesting input; no fabrication.

**Verification**: `verdict == INSUFFICIENT_INPUT`; `mvi.missing` includes `project_scope`; no `recipe` block produced.

### Test 6 — Adversarial (operator supplies an output as the end-state)

**Input**: Test 1 scope; at Element 1 the operator gives "the buyer-tagging feature is shipped" as the end-state.

**Expected**: the output-vs-condition general test fires; the skill restates "shipped" as the condition the output was meant to create and asks the operator to confirm; the recorded Element 1 is a condition, not an output.

**Verification**: `guards_fired` includes the output-as-end-state restatement; `recipe.element_1_end_state` is phrased as a condition in the world, not "X was shipped".

### Test 7 — Internal-consensus test

**Input**: Test 1 scope; at Element 2 the operator proposes "the founding team agrees we should continue" as the binary test.

**Expected**: the third-party-observable general test fires; the skill asks the operator to name the external evidence the agreement would rest on and uses that as the test.

**Verification**: `guards_fired` includes the internal-consensus challenge; `recipe.element_2_binary_test` is third-party-observable (a measured threshold or external fact), not an internal-opinion question.

### Test 8 — Pre-existing file (review mode — all three review choices)

**Input**: a repo where `DESTINATION.md` already exists (`version: 1`); the skill is re-invoked. The test exercises all three review-choice sub-cases.

**Expected**: review mode is auto-detected; the current destination is surfaced; the skill refuses to overwrite silently.
- **8a — choice (a), still holds unchanged**: no re-author; the `reviewed` frontmatter date is advanced to today; `version` unchanged; no archive created.
- **8b — choice (b), needs updating**: with `confirm_overwrite: true`, the prior file is archived as `DESTINATION.v1.md` and a new `DESTINATION.md` with `version: 2` is written. Without `confirm_overwrite`, `verdict == OVERWRITE_BLOCKED` and nothing is written. If the prior file's `version` frontmatter is unreadable, it is treated as `1` (archived defensively as `DESTINATION.v1.md`) with a `guards_fired` note.
- **8c — choice (c), abandon**: nothing is written; the `reviewed` date is NOT advanced; the file is byte-for-byte unchanged.

**Verification**: `mode == review` in all three sub-cases.
- 8a: `verdict == PASS`; `destination_file.written == false`; `destination_file.reviewed_advanced == true`; `version` unchanged; `archived_prior == null`.
- 8b (confirmed): `destination_file.archived_prior == "DESTINATION.v1.md"`; `destination_file.version == 2`; `destination_file.written == true`. 8b (unconfirmed): `verdict == OVERWRITE_BLOCKED`; `destination_file.written == false`.
- 8c: `verdict == PASS`; `destination_file.written == false`; `destination_file.reviewed_advanced == false`; the file is unchanged.

### Test 9 — Non-author-domain (a freight / real-estate project)

**Input**: `project_scope` is a freight-operations or real-estate project (NOT a synthesis-workshop context).

**Expected**: a valid six-part artefact with generic vocabulary — no workshop-specific or synthesis-programme assumptions; the recipe applies cleanly in the other domain.

**Verification**: output vocabulary is generic; the elements are domain-relevant; `DESTINATION.md` is well-formed.

### Test 10 — Hand-off (the output is accepted by the diagnostic suite)

**Input**: the `DESTINATION.md` authored by Test 1, its end-state fed to `/reduce-to-first-principles` as `proposed_reduction` with `hypothesis_provenance: generative_primitive` and a `source_hypothesis` block built from the `DESTINATION.md` frontmatter (`generated_at` + `project_root`).

**Expected**: `/reduce-to-first-principles` routes to Branch D; the bounds check passes (same project, in-window `generated_at`); the input is accepted (Branch A runs) — it is NOT blocked. This verifies the Phase A `generative_primitive` propagation end-to-end.

**Verification**: `/reduce-to-first-principles` `anti_anchoring.hypothesis_provenance == generative_primitive`; `anti_anchoring.verdict ∈ {AGREED, DISAGREED, INCONCLUSIVE}` (NOT `validate_upstream_*`, NOT a block); the destination is accepted as input.

---

## Verification Gates (Self-Check Before Returning PASS / DRAFT)

| Gate | Pass condition |
|------|----------------|
| MVI | `project_scope` passed the MVI general test; `mvi.passed: true` |
| Scope gate | Element 0 ran; `scope_gate_branch` recorded; `no_forever` → `SCOPE_REFUSAL`, no file |
| Elements complete | For `yes` / `not_yet`: all five element sections populated; DRAFT mode marks Elements 1–2 as hypotheses |
| Element distinctness | Element 3 and Element 4 are not duplicates (AP8) |
| Guards | The output-vs-condition and third-party-observable general tests ran on Elements 1 and 2; any firing recorded in `guards_fired` |
| Provenance tag | `DESTINATION.md` frontmatter carries `provenance: generative_primitive`, `upstream_skill`, `generated_at`, `project_root`, `reviewed` |
| Overwrite safety | In review mode, no write occurred without `confirm_overwrite: true` AND an archived prior version |
| Hand-offs | `hand_offs` cites `/reduce-to-first-principles`, `/map-feedback-loops`, and the council pre-mortem by name; no procedure reproduced |

If any gate fails self-check, the skill does not return `PASS` / `DRAFT` — it returns the appropriate halt verdict with the gap named.

---

## Strategic Alignment

**ROADMAP item(s) this advances**:
- The workshop North Star Metric — Propagation Rate: this skill is built to be propagated (Phase E) to ≥2 the agency entities, a direct NSM event.
- Methodology codification: a validated destination-authoring practice fills the named generative gap in the otherwise all-diagnostic framing-audit suite.

**ROADMAP item(s) this REJECTS**:
- A standalone daily-use destination command (the council showed it gets abandoned — daily surfacing is the daily-plan flow's job).
- A destination tool with no scope gate (would force hollow destinations on open-ended projects — AP1, AP7).

**If this skill advances nothing**: not applicable — it terminates in a propagated artefact (Phase E), which is the NSM itself.

---

## References

- Skill spec: `specs/11_DEFINE_DESTINATION_IMPLEMENTATION_PLAN.md` (v2 — operator-approved)
- Research brief: `specs/10_DEFINE_DESTINATION_RESEARCH_BRIEF.md`
- First council: `council/sessions/2026-05-18-define-destination-implementation.md`
- Plan-v1 review council: `council/sessions/2026-05-18-define-destination-plan-v1-review.md`
- The diagnostic suite Branch D consumer: `.claude/skills/_shared/anti-anchoring-guard.md` (Component 2 Step 2.2 Branch D)
- Authority rule for the tag: `.claude/rules/diagnostic-skill-anti-anchoring.md`
- Shape template: the framing-audit suite skills under `.claude/skills/` (`reduce-to-first-principles`, `diagnose-bottleneck`, et al.)

---

*Skill v1.0 authored 2026-05-18 in the Define-Destination build (Phase B). The generative complement to the all-diagnostic framing-audit skill suite — it authors the destination the suite audits. Net-new; no doctrine doc. Writes the `generative_primitive` provenance tag consumed by the diagnostic suite's Branch D (shipped Phase A, 2026-05-18). Plan: `specs/11_DEFINE_DESTINATION_IMPLEMENTATION_PLAN.md` v2, operator-approved.*
