# Output Chunking — Manifest-First for Long Deliverables

**Origin**: 2026-05-08 `/apply-insights` run. Recurring friction: `output_token_limit_exceeded` errors on long council reports, multi-file skill scaffolding, master continuation prompts. Several sessions terminated mid-deliverable with goals undeterminable from the transcript.

**Pairs with**: `caveman` skill (token-saver — composes; chunking is structural, caveman is per-token), `master-continuation-prompt` skill (target deliverable that hits the cap most often), `agentic-loop-guards.md` (claim-with-evidence — chunking failure = silent partial deliverable).

---

## The principle

If a single response is likely to exceed roughly 3,000 tokens of user-visible text, **emit a manifest first, then write each section/file via the Write tool**. Never produce the full deliverable inline.

The cap exists. Hitting it produces a partial response that the user must mentally reconstruct, OR an explicit error transcript with no usable artefact. Both outcomes are worse than two extra tool calls.

---

## When this rule fires

| Deliverable class | Action |
|---|---|
| Multi-file skill scaffold (≥3 files) | Manifest first, then one Write per file |
| Master continuation prompt (full template) | Manifest first, then write sections to a file |
| Council session body (3+ agents, full reports) | Manifest first, then append per-agent section |
| ADR + parent Spec lockstep update | Manifest first, then Edit each file |
| Multi-table SQL migration with RLS + indexes + comments | Manifest first, then write to migration file |
| Long-form research synthesis (≥4 sources, ≥1000-word output) | Manifest first, then write to docs file |

| Deliverable class — DOES NOT fire | Why |
|---|---|
| Single-paragraph chat reply | Always inline |
| Code review verdict (per-finding format) | Bounded by finding count; usually under cap |
| Tool call narration (one-and-one pattern) | Layman mode already enforces brevity |
| Diff/patch (Edit tool) | Already structurally chunked by Edit's old/new pairs |

---

## The manifest format

Before producing the deliverable, output a short manifest that names every artefact you intend to produce, in order:

```
MANIFEST — {deliverable name}
1. {filename or section} — {one-line purpose} (~{rough tokens})
2. {filename or section} — {one-line purpose} (~{rough tokens})
3. {filename or section} — {one-line purpose} (~{rough tokens})
Total estimate: ~{sum} tokens across {N} writes.
Proceeding to write each file.
```

Then issue Write/Edit tool calls one per artefact. Do NOT echo the file contents back inline after writing — the Edit/Write result already confirms success.

---

## What goes in the chat vs what goes in a file

| In chat (always) | In a file (when long) |
|---|---|
| The manifest | Council session body |
| One-line confirmation per file written (`✓ wrote 📄 X.md`) | Master continuation prompt |
| Final summary (1-3 sentences: what shipped, what's next) | Skill SKILL.md + helpers |
| Errors and verification artefacts | Long-form research synthesis |

---

## Composition with other rules

- **`caveman` (token-saver)**: caveman compresses prose. Chunking is independent — caveman applies inside each chunk, chunking decides whether to split. Both fire.
- **`agentic-loop-guards.md` § Pre-Exit Verification**: a chunked deliverable must include a closing summary that names which files were written. Without that, the deliverable can be partial without anyone noticing.
- **`master-continuation-prompt` skill**: this rule's primary beneficiary. Continuation prompts SHOULD always be written to a file, never echoed inline.
- **`council-protocol.md` § Session files**: council sessions persist to `council/sessions/`. The skill already chunks; this rule simply codifies the discipline so non-skill council work follows the same pattern.

---

## Anti-pattern catch-list

- Writing a 5,000-word council report inline → likely truncated; should have been written to `council/sessions/{date}-{topic}.md`.
- Producing a multi-file skill in a single response → middle files often missing or partial; manifest first, then per-file Writes.
- Echoing a file's full contents back after writing it → wastes the cap on redundant output. The Edit/Write tool result is sufficient confirmation.
- "Let me write all of this out:" followed by 3,000+ tokens of code blocks → manifest-first would have caught this before the first character.

---

## Failure precedent

2026-05-08 — `/insights` review surfaced four sessions that terminated on `output_token_limit_exceeded` with no recoverable artefact. Two were master continuation prompts attempted inline; one was a multi-file skill creator output; one was a long council body. All four would have completed cleanly with a manifest-first approach.

This rule lands BEFORE the next likely failure rather than after.
