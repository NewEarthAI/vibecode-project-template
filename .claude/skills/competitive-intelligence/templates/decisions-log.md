# Strategic Decisions Log

> Append-only log of strategic decisions. Every pivot, reclassification, positioning shift, or GTM change goes here with its trigger and source.
> Over time, this becomes strategic gold — the *why* behind every shift.

**Concurrent-write protection**: single-writer only. Never append from automated hooks or background agents. If two sessions need to append simultaneously, write to sidecar file (`decisions-log-{{YYYY-MM-DD}}-{{session}}.md`) and request manual merge.

---

## Entry Format

```
## {{YYYY-MM-DD}} — {{Decision Title}}
**Trigger**: {{what learning prompted this — competitor profile, user feedback, council session, metric shift}}
**Decision**: {{what was chosen}}
**Alternatives considered**: {{what was rejected and why}}
**Source**: {{link to profile path, council session file, user conversation, metric dashboard}}
**Revisit by**: {{date or trigger condition — "when P0 count reaches 5" / "2026-Q3 planning" / "if funding round"}}
```

Keep entries dense and source-linked. Future-you will thank present-you.

---

## Log

*(Entries appended below this line. Newest at top.)*

---

## Decision Categories (for quick review)

When reading back for strategic reflection, scan by category:

- **Positioning shifts** — changes to core thesis, GTM motion, target persona
- **Competitive reclassifications** — direct ↔ indirect ↔ adjacent moves
- **Priority changes** — P0/P1/P2 reassignments
- **Integration hypotheses accepted/rejected** — partnership opportunities
- **Rubric schema bumps** — dimension changes requiring migration
- **Pivot signals** — evidence prompting a larger strategic re-think

---

## Audit Expectations

Every entry must:
- Date the decision
- Name the trigger (not just "we decided" — WHY did we decide *now*)
- Cite a source (profile path, council session file, or link)
- Set a revisit trigger (date OR event)

Unsourced decisions are noise. Source discipline keeps the log strategic.
