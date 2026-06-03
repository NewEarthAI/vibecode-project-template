# Don't Conflate an In-Flight Programme Without Reading Its Spec

**Scope**: any session that is about to claim an existing in-flight programme, skill, rule,
or artefact already covers / subsumes / "is" the thing a new request needs — especially when
the only thing connecting them is a shared noun ("ledger", "memory", "coordination",
"pipeline", "registry").

**Origin**: 2026-05-19. Asked to design a session-coordination layer (git/worktree
legibility for parallel chats), the orchestrator asserted in a v1 design that the in-flight
Goal-Ledger Build Programme "IS the shared-logbook component — extend it." Wrong: the
Goal-Ledger tracks autonomous-chain goal/intent for goal-collision detection; it does NOT
track git branch / worktree / dirty-state / drift / push-confirmation / plain-English
location. The conflation was a pattern-match on a shared noun, not a reading of the
programme's spec. The framing-audit Phase 0 precedent-check caught it before damage; the
operator struck it and asked the guard be generalised to every NewEarth entity.

---

## The rule

Before claiming any existing programme / skill / rule / artefact covers a new need:

1. **READ its spec / SKILL.md** — not its MEMORY.md one-liner, not its name. The actual
   defining document.
2. **Run the overlap test** — two questions, both must pass to claim subsumption:
   - *Re-invention*: would removing the existing artefact force this new need to be
     re-invented? If no, they are not the same thing.
   - *Irreducible-question match*: do the two artefacts' irreducible questions actually
     match — not "are they topically adjacent"? Same-genus ≠ same-species.
3. **If they only share a noun, they are probably different.** Default to "separate" and
   make the asserter prove subsumption, not the other way round.

The framing-audit Phase 0 / `/reduce-to-first-principles` precedent-check is the backstop
that catches a conflation that slipped through — but the conflation should not be introduced
in the first place. This rule is the up-front discipline; the framing audit is the net.

## Why this recurs everywhere

Any repo with in-flight programmes surfaced in MEMORY.md has this hazard: an active
programme looks topically adjacent to many new requests. Asserting subsumption without
reading the spec (a) risks colliding with or scope-creeping an active multi-session
programme's declared NEXT session, and (b) silently mis-scopes the new work. This is
generic, not project-specific — hence template-bound to every NewEarth entity.

## What this rule is NOT

- **Not "never reuse"** — reuse is good; the rule is *read before you claim reuse*.
- **Not a blocker** — it adds a read + a two-question test, not a halt.
- **Not for unrelated work** — only fires when a subsumption claim is about to be made
  against an in-flight programme/artefact.

## References

- Framing-audit mandate (`.claude/rules/framing-audit-mandate.md`) — the Phase 0 backstop
- `/reduce-to-first-principles` — the precedent-check that caught the 2026-05-19 instance
